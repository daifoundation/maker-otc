document.addEventListener("DOMContentLoaded", redraw)

function redraw() {
  ReactDOM.render(
    renderBuyOrders(),
    document.getElementById("buy-orders")
  )
  ReactDOM.render(
    renderSellOrders(),
    document.getElementById("sell-orders")
  )
}

// Indentation is easier if children is an array.
var tag = function(type, props, children) {
  return React.createElement.apply(
    null, [type, props].concat(children || [])
  )
}

var state = Immutable.Map({
  buyOrders: [{
    bid: 0.85,
    currency: "ETH",
    value: "$8.02",
    volume: 30,
  }, {
    bid: 0.79,
    currency: "ETH",
    value: "$7.85",
    volume: 7,
  }, {
    bid: 6.86,
    currency: "DAI",
    value: "$6.82",
    volume: 150,
  }, {
    bid: 6.5,
    currency: "DAI",
    value: "$6.43",
    volume: 200,
  }],

  sellOrders: [{
    ask: 1.05,
    currency: "ETH",
    value: "$10.85",
    volume: 120,
  }, {
    ask: 1.53,
    currency: "ETH",
    value: "$14.65",
    volume: 200,
  }, {
    ask: 2,
    currency: "ETH",
    value: "$19.13",
    volume: 300,
  }],
})

function change(f) {
  state = f(state)
  redraw()
}

function renderBuyOrders() {
  return tag("table", {}, [
    tag("thead", {}, [
      tag("tr", {}, [
	tag("th", {}, ["Bid"]),
	tag("th"),
	tag("th", {}, ["Value"]),
	tag("th", {}, ["Volume"]),
      ])
    ]),
    tag("thead", {}, [
      state.get("buyOrders").map(function(order) {
	return tag("tr", {}, [
	  tag("td", {}, [order.bid]),
	  tag("td", {}, [order.currency]),
	  tag("td", {}, ["~" + order.value]),
	  tag("td", {}, [order.volume + " MKR"]),
	])
      })
    ])    
  ])
}

function renderSellOrders() {
  return tag("table", {}, [
    tag("thead", {}, [
      tag("tr", {}, [
	tag("th", {}, ["Ask"]),
	tag("th"),
	tag("th", {}, ["Value"]),
	tag("th", {}, ["Volume"]),
      ])
    ]),
    tag("thead", {}, [
      state.get("sellOrders").map(function(order) {
	return tag("tr", {}, [
	  tag("td", {}, [order.ask]),
	  tag("td", {}, [order.currency]),
	  tag("td", {}, ["~" + order.value]),
	  tag("td", {}, [order.volume + " MKR"]),
	])
      })
    ])    
  ])
}
