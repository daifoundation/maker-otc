Template.newallowance.viewmodel({
  TRANSACTION_TYPE: function () {
    return 'allowance_' + this.templateInstance.data.token._id
  },
  value: '',
  allowance: function () {
    return Template.currentData().token.allowance
  },
  pending: function () {
    return Transactions.findType(this.TRANSACTION_TYPE())
  },
  lastError: '',
  autorun: function () {
    // Initialize value
    this.value(web3.fromWei(this.templateInstance.data.token.allowance))
  },
  canChange: function () {
    try {
      return this.pending().length === 0 && this.value() !== '' && this.value() !== web3.fromWei(this.allowance())
    } catch (e) {
      return false
    }
  },
  change: function (event) {
    event.preventDefault()

    var _this = this
    _this.lastError('')

    var contract_address = Dapple['maker-otc'].objects.otc.address
    var options = { gas: 3141592 }

    Dapple['makerjs'].getToken(_this.templateInstance.data.token._id).approve(contract_address, web3.toWei(_this.value()), options, function (error, tx) {
      if (!error) {
        Transactions.add(_this.TRANSACTION_TYPE(), tx, { value: _this.value(), token: _this.templateInstance.data.token._id })
      } else {
        _this.lastError(error.toString())
      }
    })
  }
})
