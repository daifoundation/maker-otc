Template.newallowance.viewmodel({
  value: '',
  canChange: function () {
    try {
      return this.value() !== '' && web3.toWei(this.value()) !== this.templateInstance.data.token.allowance
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
