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
      var args = {}
      if (formattedString(trade.args.buy_which_token) === BASE_CURRENCY) {
        args.type = 'bid'
        args.currency = formattedString(trade.args.sell_which_token)
        args.volume = trade.args.buy_how_much.toString(10)
        args.price = web3.toWei(trade.args.sell_how_much.div(trade.args.buy_how_much)).toString(10)
      } else {
        args.type = 'ask'
        args.currency = formattedString(trade.args.buy_which_token)
        args.volume = trade.args.sell_how_much.toString(10)
        args.price = web3.toWei(trade.args.buy_how_much.div(trade.args.sell_how_much)).toString(10)
      }
      // Get block for timestamp
      web3.eth.getBlock(trade.blockNumber, function (error, block) {
        if (!error) {
          Trades.upsert(trade.transactionHash, _.extend(block, trade, args))
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

Offers.buyOffer = function (_id, _quantity) {
  var id = parseInt(_id, 10)
  var quantity = _quantity.toNumber()
  Offers.update(_id, { $unset: { helper: '' } })
  Dapple['maker-otc'].objects.otc.buyPartial(id.toString(10), quantity, { gas: 3141592 }, function (error, tx) {
    if (!error) {
      Transactions.add('offer', tx, { id: _id, status: Status.BOUGHT })
      Offers.update(_id, { $set: { tx: tx, status: Status.BOUGHT, helper: 'Your buy / sell order is being processed...' } })
    } else {
      Offers.update(_id, { $set: { helper: error.toString() } })
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
      if (document.receipt.logs.length === 0) {
        Offers.update(document.object.id, { $set: { helper: document.object.status + ': Error during Contract Execution' } })
      } else {
        Offers.update(document.object.id, { $unset: { helper: '' } })
      }
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
