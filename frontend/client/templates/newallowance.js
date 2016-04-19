Template.newallowance.helpers({
  buttonState: function () {
    var state = 'disabled'
    Tokens.find().forEach(function (token) {
      if (state === 'disabled' && token.allowance !== token.newAllowance) {
        state = ''
      }
    })
    return state
  }
})

Template.newallowance.events({
  'change input[type="number"], keyup input[type="number"], mouseup input[type="number"]': function (event) {
    var target = $(event.target)
    Tokens.update(target.data('token'), { $set: { newAllowance: web3.toWei(target.val()) } })
  },
  'click #changeAllowance': function (event) {
    event.preventDefault()

    var contract_address = Dapple['maker-otc'].objects.otc.address
    var options = { from: Session.get('address'), gas: 3141592 }

    Tokens.find().forEach(function (token) {
      if (token.allowance !== token.newAllowance) {
        Dapple['makerjs'].getToken(token._id).approve(contract_address, token.newAllowance, options)
      }
    })
  }
})
