Template.orderRow.events({
  'click .cancel': function (event, template) {
    event.preventDefault()
    var _id = template.data.order._id
    Offers.cancelOffer(_id)
  },
  'click .confirmed>.buy': function (event, template) {
    event.preventDefault()
    var _id = template.data.order._id
    Offers.buyOffer(_id)
  }
})
