Offers = new Meteor.Collection(null)

function formattedString(str) {
  return web3.toAscii(str).replace(/\0[\s\S]*$/g,'').trim()
}

Meteor.startup(function() {
  var last_offer_id = MakerOTC.last_offer_id().toNumber()
  console.log("last_offer_id", last_offer_id)
  for (var idx = 1; idx <= last_offer_id; idx++ ) {
    var data = MakerOTC.offers(idx)
    var sell_how_much = data[0].toNumber()
    var sell_which_token = formattedString(data[1])
    var buy_how_much = data[2].toNumber()
    var buy_which_token = formattedString(data[3])
    var owner = data[4]
    var active = data[5]

    if (sell_which_token === "MKR") {
      Offers.insert({
        idx: idx,
        type: "ask",
        currency: buy_which_token,
        volume: sell_how_much,
        price: buy_how_much / sell_how_much,
        owner: owner
      })
    } else if (buy_which_token === "MKR") {
      Offers.insert({
        idx: idx,
        type: "bid",
        currency: sell_which_token,
        volume: buy_how_much,
        price: sell_how_much / buy_how_much,
        owner: owner
      })
    } else {
      console.log("unknown pair", sell_which_token, buy_which_token)
    }
  }
})
