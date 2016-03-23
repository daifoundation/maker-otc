Template.orderRow.events({
  'click .cancel': function (event, template) {
    event.preventDefault()
    var _id = template.data.order._id;
    var id = parseInt(_id)
    Offers.update({_id: _id}, {$set: {cancelled: true}})
    var cancelTx = MakerOTC.cancel(id, {gas: 100000})
    // TODO locally mark as deleted
    console.log("cancel!", id, cancelTx)
    return false
  }
})
