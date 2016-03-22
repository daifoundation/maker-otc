Template.orderRow.events({
  'click .cancel': function (event, template) {
    event.preventDefault()
    var id = parseInt(template.data.order._id)
    var cancelTx = MakerOTC.cancel(id, {gas: 100000})
    // TODO locally mark as deleted
    console.log("cancel!", id, cancelTx)
    return false
  }
})
