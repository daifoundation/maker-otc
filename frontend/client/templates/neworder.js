Session.setDefault('ordertype', 'buy')
Session.setDefault('currency', 'ETH')
Session.setDefault('price', 0)
Session.setDefault('amount', 0)
Session.setDefault('total', 0)

var totalMax = function () {
  var ordertype = Session.get('ordertype')
  var currency = Session.get('currency')
  var token = Tokens.findOne(currency)
  var balance = new BigNumber(token.balance)
  var allowance = new BigNumber(token.allowance)
  return ordertype === 'buy' ? web3.fromWei(BigNumber.min(balance, allowance).toString(10)) : Infinity
}

var amountMax = function () {
  var ordertype = Session.get('ordertype')
  var token = Tokens.findOne('MKR')
  var balance = new BigNumber(token.balance)
  var allowance = new BigNumber(token.allowance)
  return ordertype === 'sell' ? web3.fromWei(BigNumber.min(balance, allowance).toString(10)) : Infinity
}

Template.neworder.helpers({
  ordertype: function () {
    return Session.get('ordertype')
  },
  currency: function () {
    return Session.get('currency')
  },
  price: function () {
    return Session.get('price')
  },
  amount: function () {
    return Session.get('amount')
  },
  total: function () {
    return Session.get('total')
  },
  totalMax: totalMax,
  amountMax: amountMax,
  buttonState: function () {
    var ordertype = Session.get('ordertype')
    var price = new BigNumber(Session.get('price'))
    var amount = new BigNumber(Session.get('amount'))
    var total = new BigNumber(Session.get('total'))
    if (price.gt(0) && amount.gt(0) && total.gt(0) && (ordertype !== 'buy' || total.lte(new BigNumber(totalMax()))) && (ordertype !== 'sell' || amount.lte(new BigNumber(amountMax())))) {
      return ''
    } else {
      return 'disabled'
    }
  }
})

Template.neworder.events({
  'change .ordertype': function () {
    var ordertype = $('input:radio[name="ordertype"]:checked').val()
    Session.set('ordertype', ordertype)
  },
  'change .currency': function () {
    var currency = $('input:radio[name="currency"]:checked').val()
    Session.set('currency', currency)
  },
  'change .price, keyup .price, mouseup .price': function () {
    var price = $('input[name="price"]').val()
    var amount = Session.get('amount')
    Session.set('price', price)
    Session.set('total', amount * price)
  },
  'change .amount, keyup .amount, mouseup .amount': function () {
    var amount = $('input[name="amount"]').val()
    var price = Session.get('price')
    Session.set('amount', amount)
    Session.set('total', amount * price)
  },
  'change .total, keyup .total, mouseup .total': function () {
    var total = $('input[name="total"]').val()
    var price = Session.get('price')
    Session.set('total', total)
    if (price > 0) {
      Session.set('amount', total / price)
    } else {
      Session.set('amount', 0)
    }
  },
  'click #submitorder': function (event) {
    event.preventDefault()

    var sell_how_much, sell_which_token, buy_how_much, buy_which_token
    if (Session.get('ordertype') === 'buy') {
      sell_how_much = web3.toWei(Session.get('total'))
      sell_which_token = Session.get('currency')
      buy_how_much = web3.toWei(Session.get('amount'))
      buy_which_token = BASE_CURRENCY
    } else {
      sell_how_much = web3.toWei(Session.get('amount'))
      sell_which_token = BASE_CURRENCY
      buy_how_much = web3.toWei(Session.get('total'))
      buy_which_token = Session.get('currency')
    }
    Offers.newOffer(sell_how_much, sell_which_token, buy_how_much, buy_which_token)
  }
})
