Template.makereth.viewmodel({
  type: 'deposit',
  amount: '',
  lastError: '',
  lastTx: '',
  pending: {},
  isPending: function () {
    // Subscribe
    this.lastTx()

    return !_.isEmpty(this.pending())
  },
  pendingList: function () {
    // Subscribe
    this.lastTx()

    return _.sortBy(_.values(this.pending()), 'timestamp')
  },
  autorun: function () {
    var _this = this
    web3.eth.filter('latest', function (error, result) {
      if (!error) {
        _.each(_this.pending(), function (value) {
          web3.eth.getTransactionReceipt(value.tx, function (error, result) {
            if (!error && result != null) {
              delete _this.pending()[value.tx]
              _this.lastTx(value.tx + '-done')
            }
          })
        })
      }
    })
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
          _this.pending()[tx] = { tx: tx, type: 'deposit', amount: _this.amount(), timestamp: new Date().getTime() }
          _this.lastTx(tx)
        } else {
          _this.lastError(error.toString())
        }
      })
    } else {
      Dapple['makerjs'].getToken('ETH').withdraw(web3.toWei(_this.amount()), options, function (error, tx) {
        if (!error) {
          _this.pending()[tx] = { tx: tx, type: 'withdraw', amount: _this.amount(), timestamp: new Date().getTime() }
          _this.lastTx(tx)
        } else {
          _this.lastError(error.toString())
        }
      })
    }
  }
})
