this.Offers = new Meteor.Collection(null)

this.BASE_CURRENCY = 'MKR'
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
    }
    if (this.type === 'bid') {
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

Offers.syncOffer = function (id) {
  var data = Dapple['maker-otc'].objects.otc.offers(id)
  var idx = id.toString()
  var sell_how_much = data[0]
  var sell_which_token = formattedString(data[1])
  var buy_how_much = data[2]
  var buy_which_token = formattedString(data[3])
  var owner = data[4]
  var active = data[5] // TODO unused

  if (active) {
    Offers.updateOffer(idx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, owner, Status.CONFIRMED)
  } else {
    Offers.remove(idx)
  }
}

Offers.updateOffer = function (idx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, owner, status) {
  var baseOffer = {
    owner: owner,
    status: status
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

Offers.newOffer = function (sell_how_much, sell_which_token, buy_how_much, buy_which_token) {
  var offerTx = Dapple['maker-otc'].objects.otc.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token, { gas: 300000 })
  console.log('offer!', offerTx, sell_how_much, sell_which_token, buy_how_much, buy_which_token)
  Offers.updateOffer(offerTx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, web3.eth.defaultAccount, Status.PENDING)
}

Offers.buyOffer = function (idx) {
  var id = parseInt(idx, 10)
  var tx = Dapple['maker-otc'].objects.otc.buy(id)
  console.log('buy!', id, tx)
  Offers.update(idx, { $set: { status: Status.BOUGHT } })
}

Offers.cancelOffer = function (idx) {
  var id = parseInt(idx, 10)
  var tx = Dapple['maker-otc'].objects.otc.cancel(id, { gas: 100000 })
  console.log('cancel!', id, tx)
  Offers.update(idx, { $set: { status: Status.CANCELLED } })
}
