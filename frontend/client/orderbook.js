var buyOrders = [{
  price: 0.85,
  currency: "ETH",
  value: "$8.02",
  volume: 30,
}, {
  price: 0.79,
  currency: "ETH",
  value: "$7.85",
  volume: 7,
}, {
  price: 6.86,
  currency: "DAI",
  value: "$6.82",
  volume: 150,
}, {
  price: 6.5,
  currency: "DAI",
  value: "$6.43",
  volume: 200,
}];

var sellOrders = [{
  price: 1.05,
  currency: "ETH",
  value: "$10.85",
  volume: 120,
}, {
  price: 1.53,
  currency: "ETH",
  value: "$14.65",
  volume: 200,
}, {
  price: 2,
  currency: "ETH",
  value: "$19.13",
  volume: 300,
}];

Template.orderbook.helpers({
  buyOrders: function () {
    return Offers.find({type: "bid"})
  },
  sellOrders: function () {
    return Offers.find({type: "ask"})
  }
})
