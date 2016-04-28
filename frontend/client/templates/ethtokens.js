var TRANSACTION_TYPE = 'ethtokens'

Template.ethtokens.viewmodel({
  type: 'deposit',
  amount: '',
  lastError: '',
  pending: function () {
    return Transactions.findType(TRANSACTION_TYPE)
  },
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

    var _this = this
    _this.lastError('')
    var options = { gas: 3141592 }

    if (_this.type() === 'deposit') {
      options['value'] = web3.toWei(_this.amount())
      Dapple['makerjs'].getToken('ETH').deposit(options, function (error, tx) {
        if (!error) {
          Transactions.add(TRANSACTION_TYPE, tx, { type: 'deposit', amount: _this.amount() })
        } else {
          _this.lastError(error.toString())
        }
      })
    } else {
      Dapple['makerjs'].getToken('ETH').withdraw(web3.toWei(_this.amount()), options, function (error, tx) {
        if (!error) {
          Transactions.add(TRANSACTION_TYPE, tx, { type: 'withdraw', amount: _this.amount() })
        } else {
          _this.lastError(error.toString())
        }
      })
    }
  }
})
