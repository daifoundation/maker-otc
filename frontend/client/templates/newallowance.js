Template.newallowance.viewmodel({
  value: '',
  allowance: '',
  lastMsg: '',
  lastTx: '',
  autorun: function () {
    // Initialize value and allowance
    var _id = this.templateInstance.data.token._id
    this.value(web3.fromWei(this.templateInstance.data.token.allowance))
    this.allowance(this.templateInstance.data.token.allowance)

    // Update allowance manually on change, because the form is not automatically reactive to Collection changes
    var _this = this
    Tokens.find().observeChanges({
      changed: function (id, fields) {
        if (id === _id && fields.hasOwnProperty('allowance')) {
          _this.allowance(fields.allowance)
        }
      }
    })
    web3.eth.filter('latest', function (error, result) {
      if (!error) {
        var lastTx = _this.lastTx()
        if (lastTx !== '') {
          web3.eth.getTransactionReceipt(lastTx, function (error, result) {
            if (!error && result != null) {
              _this.lastTx('')
              _this.lastMsg('')
            }
          })
        }
      }
    })
  },
  canChange: function () {
    try {
      return this.lastTx() === '' && this.value() !== '' && this.value() !== web3.fromWei(this.allowance())
    } catch (e) {
      return false
    }
  },
  change: function (event) {
    event.preventDefault()

    var _this = this
    _this.lastMsg('')
    var contract_address = Dapple['maker-otc'].objects.otc.address
    var options = { gas: 3141592 }

    Dapple['makerjs'].getToken(this.templateInstance.data.token._id).approve(contract_address, web3.toWei(this.value()), options, function (error, tx) {
      if (!error) {
        _this.lastTx(tx)
        _this.lastMsg('Pending: ' + _this.value() + ' ' + _this.templateInstance.data.token._id)
      } else {
        _this.lastMsg(error.toString())
      }
    })
  }
})
