Template.orderRow.events({
  'click .cancel': function (event, template) {
    event.preventDefault()
    event.stopPropagation()
    var _id = template.data.order._id
    Session.set('selectedOffer', _id)
    $('#cancelModal').modal('show')
  },
  'click tr': function (event, template) {
    event.preventDefault()
    var _id = template.data.order._id
    Session.set('selectedOffer', _id)
    $('#offerModal').modal('show')
  }
})
