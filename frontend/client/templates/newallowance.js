Template.newallowance.viewmodel({
  value: '',
  allowance: '',
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
  },
  canChange: function () {
    try {
      return this.value() !== '' && this.value() !== web3.fromWei(this.allowance())
    } catch (e) {
      return false
    }
  },
  change: function (event) {
    event.preventDefault()

    var contract_address = Dapple['maker-otc'].objects.otc.address
    var options = { from: Session.get('address'), gas: 3141592 }

    Dapple['makerjs'].getToken(this.templateInstance.data.token._id).approve(contract_address, web3.toWei(this.value()), options)
  }
})
