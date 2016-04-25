Template.offermodal.helpers({
  total: function (price, volume) {
    try {
      return web3.fromWei(new BigNumber(price)).times(new BigNumber(volume)).toString(10)
    } catch (e) {
      return '-'
    }
  }
})

Template.offermodal.events({
  'click .btn-primary': function () {
    var _id = Template.currentData().offer._id
    Offers.buyOffer(_id)
  },
  'click .btn-danger': function () {
    var _id = Template.currentData().offer._id
    Offers.cancelOffer(_id)
  }
})
