Template.orderbook.helpers({
  buyOrders: function () {
    return Offers.find({ type: 'bid' })
  },
  sellOrders: function () {
    return Offers.find({ type: 'ask' })
  }
})
