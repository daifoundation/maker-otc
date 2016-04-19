Session.setDefault('depositType', 'deposit')
Session.setDefault('depositAmount', '0')

var amountMax = function () {
  var depositType = Session.get('depositType')
  if (depositType === 'deposit') {
    return web3.fromWei(Session.get('ETHBalance'))
  } else {
    return web3.fromWei(Tokens.findOne('ETH').balance)
  }
}

Template.makereth.helpers({
  'depositType': function () {
    return Session.get('depositType')
  },
  'amountMax': amountMax,
  'buttonState': function () {
    var depositType = Session.get('depositType')
    var amount = new BigNumber(Session.get('depositAmount'))
    if (depositType && amount.gt(0) && amount.lte(new BigNumber(amountMax()))) {
      return ''
    } else {
      return 'disabled'
    }
  }
})

Template.makereth.events({
  'change .radios': function () {
    var depositType = $('input:radio[name="depositType"]:checked').val()
    Session.set('depositType', depositType)
  },
  'change input[name="depositAmount"]': function () {
    var depositAmount = $('input[name="depositAmount"]').val()
    Session.set('depositAmount', depositAmount)
  },
  'click #deposit': function (event) {
    event.preventDefault()

    var depositType = Session.get('depositType')
    var depositAmount = Session.get('depositAmount')
    var options = { from: Session.get('address'), gas: 3141592 }

    if (depositType === 'deposit') {
      options['value'] = web3.toWei(depositAmount) 
      Dapple['makerjs'].getToken('ETH').deposit(options)
    } else {
      Dapple['makerjs'].getToken('ETH').withdraw(web3.toWei(depositAmount), options)
    }
  }
})
