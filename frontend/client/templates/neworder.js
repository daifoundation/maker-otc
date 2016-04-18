Session.setDefault('ordertype', 'buy')
Session.setDefault('currency', 'ETH')
Session.setDefault('price', 0)
Session.setDefault('amount', 0)
Session.setDefault('total', 0)

var totalMax = function () {
  var ordertype = Session.get('ordertype')
  var currency = Session.get('currency')
  var balance = new BigNumber(Session.get(currency + 'Balance'))
  var allowance = new BigNumber(Session.get(currency + 'Allowance'))
  return ordertype === 'buy' ? web3.fromWei(BigNumber.min(balance, allowance).toString(10)) : Infinity
}

var amountMax = function () {
  var ordertype = Session.get('ordertype')
  var balance = new BigNumber(Session.get('MKRBalance'))
  var allowance = new BigNumber(Session.get('MKRAllowance'))
  return ordertype === 'sell' ? web3.fromWei(BigNumber.min(balance, allowance).toString(10)) : Infinity
}

Template.neworder.helpers({
  myOrders: function () {
    return Offers.find({ owner: web3.eth.defaultAccount })
  },
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
    var price = Session.get('price')
    var amount = Session.get('amount')
    var total = Session.get('total')
    if (price > 0 && amount > 0 && total > 0 && (ordertype !== 'buy' || total < totalMax()) && (ordertype !== 'sell' || amount <= amountMax())) {
      return ''
    } else {
      return 'disabled'
    }
  },
  allowanceButtonState: function () {
    var ETHAllowance = Session.get('ETHAllowance')
    var MKRAllowance = Session.get('MKRAllowance')
    var DAIAllowance = Session.get('DAIAllowance')

    var newETHAllowance = Session.get('newETHAllowance')
    var newMKRAllowance = Session.get('newMKRAllowance')
    var newDAIAllowance = Session.get('newDAIAllowance')

    if (ETHAllowance !== newETHAllowance || MKRAllowance !== newMKRAllowance || DAIAllowance !== newDAIAllowance) {
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
    return false
  },
  'change #newETHAllowance,#newMKRAllowance,#newDAIAllowance': function () {
    Session.set('newETHAllowance', web3.toWei($('#newETHAllowance').val()))
    Session.set('newMKRAllowance', web3.toWei($('#newMKRAllowance').val()))
    Session.set('newDAIAllowance', web3.toWei($('#newDAIAllowance').val()))
  },
  'click #changeAllowance': function (event) {
    event.preventDefault()

    var contract_address = Dapple['maker-otc'].objects.otc.address
    var options = { from: web3.eth.coinbase, gas: 3141592 }

    // Get new allowances
    var newETHAllowance = Session.get('newETHAllowance')
    var newMKRAllowance = Session.get('newMKRAllowance')
    var newDAIAllowance = Session.get('newDAIAllowance')

    // Do only what is necessary
    if (!Session.equals('ETHAllowance', newETHAllowance)) {
      Dapple['makerjs'].getToken('ETH').approve(contract_address, newETHAllowance, options)
    }
    if (!Session.equals('MKRAllowance', newMKRAllowance)) {
      Dapple['makerjs'].getToken('MKR').approve(contract_address, newMKRAllowance, options)
    }
    if (!Session.equals('DAIAllowance', newDAIAllowance)) {
      Dapple['makerjs'].getToken('DAI').approve(contract_address, newDAIAllowance, options)
    }
  }
})
