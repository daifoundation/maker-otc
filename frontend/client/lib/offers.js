this.Offers = new Meteor.Collection(null)
this.Trades = new Meteor.Collection(null)

this.BASE_CURRENCY = 'MKR'
this.PRICE_CURRENCY = 'USD'
this.Status = {
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  CANCELLED: 'cancelled',
  BOUGHT: 'bought'
}

function formattedString (str) {
  return web3.toAscii(str).replace(/\0[\s\S]*$/g, '').trim()
}

Offers.helpers({
  canBuy: function () {
    // Check if order is confirmed and user has enough funds
    if (this.status !== Status.CONFIRMED) {
      return false
    } else if (this.type === 'bid') {
      // Since allowance can be larger than the balance,
      // check if both the MKR balance and allowance are greater than or equal to the offer's volume
      // TODO: add support for partial orders
      var MKRToken = Tokens.findOne('MKR')
      var MKRBalance = new BigNumber(MKRToken.balance)
      var MKRAllowance = new BigNumber(MKRToken.allowance)
      return BigNumber.min(MKRBalance, MKRAllowance).gte(new BigNumber(this.volume))
    } else {
      // Since allowance can be larger than the balance,
      // check if both the balance and allowance are greater than or equal to the offer's volume times its price
      // TODO: add support for partial orders, take transaction gas cost into account
      var token = Tokens.findOne(this.currency)
      var balance = new BigNumber(token.balance)
      var allowance = new BigNumber(token.allowance)
      var volume = new BigNumber(this.volume)
      var price = new BigNumber(this.price)
      return BigNumber.min(balance, allowance).gte(volume.times(web3.fromWei(price)))
    }
  },
  canCancel: function () {
    return (this.status === Status.CONFIRMED) && Session.equals('address', this.owner)
  }
})

/**
 * Syncs up all offers and trades
 */
Offers.sync = function () {
  Offers.remove({})
  var last_offer_id = Dapple['maker-otc'].objects.otc.last_offer_id().toNumber()
  console.log('last_offer_id', last_offer_id)
  if (last_offer_id > 0) {
    Session.set('loading', true)
    Session.set('loadingProgress', 0)
    Offers.syncOffer(last_offer_id, last_offer_id)
  }

  Dapple['maker-otc'].objects.otc.Trade({}, { fromBlock: 0 }, function (error, trade) {
    if (!error) {
      // Transform arguments
      var args = {
        buy_how_much: trade.args.buy_how_much.toString(10),
        buy_which_token: web3.toAscii(trade.args.buy_which_token).replace(/\0[\s\S]*$/g, '').trim(),
        sell_how_much: trade.args.sell_how_much.toString(10),
        sell_which_token: web3.toAscii(trade.args.sell_which_token).replace(/\0[\s\S]*$/g, '').trim()
      }
      web3.eth.getBlock(trade.blockNumber, function (error, block) {
        if (!error) {
          Trades.upsert(trade.transactionHash, _.extend(block, trade, { args: args }))
        }
      })
    }
  })
}

/**
 * Syncs up a single offer
 */
Offers.syncOffer = function (id, max) {
  Dapple['maker-otc'].objects.otc.offers(id, function (error, data) {
    if (!error) {
      var idx = id.toString()
      var sell_how_much = data[0]
      var sell_which_token = formattedString(data[1])
      var buy_how_much = data[2]
      var buy_which_token = formattedString(data[3])
      var owner = data[4]
      var active = data[5]

      if (active) {
        Offers.updateOffer(idx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, owner, Status.CONFIRMED)
      } else {
        Offers.remove(idx)
        if (Session.equals('selectedOffer', idx)) {
          $('#offerModal').modal('hide')
        }
      }
      if (max > 0 && id > 1) {
        Session.set('loadingProgress', Math.round(100 * (max - id) / max))
        Offers.syncOffer(id - 1, max)
      } else if (max > 0) {
        Session.set('loading', false)
      }
    }
  })
}

Offers.updateOffer = function (idx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, owner, status) {
  var baseOffer = {
    owner: owner,
    status: status
  }

  if (status === Status.PENDING) {
    baseOffer.helper = 'Your new order is being placed...'
    Transactions.add('offer', idx, { id: idx, status: status })
  }

  if (!(sell_how_much instanceof BigNumber)) {
    sell_how_much = new BigNumber(sell_how_much)
  }
  if (!(buy_how_much instanceof BigNumber)) {
    buy_how_much = new BigNumber(buy_how_much)
  }

  if (sell_which_token === BASE_CURRENCY) {
    var sellOffer = _.extend(baseOffer, {
      type: 'ask',
      currency: buy_which_token,
      volume: sell_how_much.toString(10),
      price: web3.toWei(buy_how_much.dividedBy(sell_how_much)).toString()
    })
    Offers.upsert(idx, { $set: sellOffer })
  } else if (buy_which_token === BASE_CURRENCY) {
    var buyOffer = _.extend(baseOffer, {
      type: 'bid',
      currency: sell_which_token,
      volume: buy_how_much.toString(10),
      price: web3.toWei(sell_how_much.dividedBy(buy_how_much)).toString()
    })
    Offers.upsert(idx, { $set: buyOffer })
  } else {
    console.warn('Offers.updateOffer: No base currency found')
  }
}

Offers.newOffer = function (sell_how_much, sell_which_token, buy_how_much, buy_which_token, callback) {
  Dapple['maker-otc'].objects.otc.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token, { gas: 3141592 }, function (error, tx) {
    callback(error, tx)
    if (!error) {
      Offers.updateOffer(tx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, web3.eth.defaultAccount, Status.PENDING)
    }
  })
}

Offers.buyOffer = function (idx) {
  var id = parseInt(idx, 10)
  Offers.update(idx, { $unset: { helper: '' } })
  Dapple['maker-otc'].objects.otc.buy(id, { gas: 3141592 }, function (error, tx) {
    if (!error) {
      Transactions.add('offer', tx, { id: idx, status: Status.BOUGHT })
      Offers.update(idx, { $set: { tx: tx, status: Status.BOUGHT, helper: 'Your buy / sell order is being processed...' } })
    } else {
      Offers.update(idx, { $set: { helper: error.toString() } })
    }
  })
}

Offers.cancelOffer = function (idx) {
  var id = parseInt(idx, 10)
  Offers.update(idx, { $unset: { helper: '' } })
  Dapple['maker-otc'].objects.otc.cancel(id, { gas: 3141592 }, function (error, tx) {
    if (!error) {
      Transactions.add('offer', tx, { id: idx, status: Status.CANCELLED })
      Offers.update(idx, { $set: { tx: tx, status: Status.CANCELLED, helper: 'Your order is being cancelled...' } })
    } else {
      Offers.update(idx, { $set: { helper: error.toString() } })
    }
  })
}

Transactions.observeRemoved('offer', function (document) {
  switch (document.object.status) {
    case Status.CANCELLED:
    case Status.BOUGHT:
      Offers.syncOffer(document.object.id)
      // If it worked and it was successfully bought / cancelled, the following will do nothing since the object got removed
      Offers.update(document.object.id, { $set: { helper: document.object.status + ': Error during Contract Execution' } })
      break
    case Status.PENDING:
      // The ItemUpdate event will be triggered on successful generation, which will delete the object; otherwise set helper
      Offers.update(document.object.id, { $set: { helper: 'Error during Contract Execution' } })
      Meteor.setTimeout(function () {
        Offers.remove(document.object.id)
      }, 5000)
      break
  }
})
