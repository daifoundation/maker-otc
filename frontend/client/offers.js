Offers = new Meteor.Collection(null)

BASE_CURRENCY = "MKR"

function formattedString(str) {
  return web3.toAscii(str).replace(/\0[\s\S]*$/g,'').trim()
}

function updateOffer(id) {
  var data = MakerOTC.offers(id)
  var idx = id.toString()
  var sell_how_much = data[0].toNumber()
  var sell_which_token = formattedString(data[1])
  var buy_how_much = data[2].toNumber()
  var buy_which_token = formattedString(data[3])
  var owner = data[4]
  var active = data[5]
  var editable = (owner === web3.eth.accounts[0])

  if (sell_which_token === BASE_CURRENCY) {
    Offers.insert({
      _id: idx,
      type: "ask",
      currency: buy_which_token,
      volume: sell_how_much,
      price: buy_how_much / sell_how_much,
      owner: owner,
      editable: editable
    })
  } else if (buy_which_token === BASE_CURRENCY) {
    Offers.insert({
      _id: idx,
      type: "bid",
      currency: sell_which_token,
      volume: buy_how_much,
      price: sell_how_much / buy_how_much,
      owner: owner,
      editable: editable
    })
  } else {
    Offers.remove({_id: idx})
  }
}

Meteor.startup(function() {
  var last_offer_id = MakerOTC.last_offer_id().toNumber()
  console.log("last_offer_id", last_offer_id)
  for (var id = 1; id <= last_offer_id; id++ ) {
    updateOffer(id)
  }

  var event = MakerOTC.ItemUpdate(function(error, result) {
    if (!error) {
      var id = result.args.id.toNumber();
      console.log("Offer updated", id, result);
      updateOffer(id)
    }
  });
})
