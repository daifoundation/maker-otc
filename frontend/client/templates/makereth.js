Template.makereth.viewmodel({
  type: 'deposit',
  amount: '',
  maxAmount: function () {
    if (this.type() === 'deposit') {
      return web3.fromWei(Session.get('ETHBalance'))
    } else {
      return web3.fromWei(Tokens.findOne('ETH').balance)
    }
  },
  canDeposit: function () {
    try {
      var amount = new BigNumber(this.amount())
      var maxAmount = new BigNumber(this.maxAmount())
      return amount.gt(0) && amount.lte(maxAmount)
    } catch (e) {
      return false
    }
  },
  deposit: function (event) {
    event.preventDefault()

    var options = { from: Session.get('address'), gas: 3141592 }
    if (this.type() === 'deposit') {
      options['value'] = web3.toWei(this.amount())
      Dapple['makerjs'].getToken('ETH').deposit(options)
    } else {
      Dapple['makerjs'].getToken('ETH').withdraw(web3.toWei(this.amount()), options)
    }
  }
})
