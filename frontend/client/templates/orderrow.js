Template.orderRow.events({
  'click .cancel': function (event, template) {
    event.preventDefault()
    var _id = template.data.order._id
    Offers.cancelOffer(_id)
    return false
  },
  'click .confirmed>.buy': function (event, template) {
    event.preventDefault()
    var _id = template.data.order._id
    console.log("BUY", _id)
    Offers.buyOffer(_id)
    return false
  }
})
