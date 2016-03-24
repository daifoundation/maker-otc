Offers = new Meteor.Collection(null)

BASE_CURRENCY = "MKR"
Status = {
  PENDING: "pending",
  CONFIRMED: "confirmed",
  CANCELLED: "cancelled",
  BOUGHT: "bought",
}

function formattedString(str) {
  return web3.toAscii(str).replace(/\0[\s\S]*$/g,'').trim()
}

Offers.helpers({
  canCancel: function() {
    return (this.status === Status.CONFIRMED) && (this.owner === web3.eth.defaultAccount)
  },
  value: function() {
    return this.price * 0.73 // TODO fake
  }
})

Offers.syncOffer = function(id) {
  var data = MakerOTC.offers(id)
  var idx = id.toString()
  var sell_how_much = data[0]
  var sell_which_token = formattedString(data[1])
  var buy_how_much = data[2]
  var buy_which_token = formattedString(data[3])
  var owner = data[4]
  var active = data[5] // TODO unused

  if (active) {
    Offers.updateOffer(idx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, owner, Status.CONFIRMED)
  } else {
    Offers.remove({_id: idx})
  }
}

Offers.updateOffer = function(idx, sell_how_much, sell_which_token, buy_how_much, buy_which_token, owner, status) {
  var baseOffer = {
    owner: owner,
    status: status
  }

  if(!(sell_how_much instanceof BigNumber)) {
    sell_how_much = new BigNumber(sell_how_much)
  }
  if(!(buy_how_much instanceof BigNumber)) {
    buy_how_much = new BigNumber(buy_how_much)
  }

  if (sell_which_token === BASE_CURRENCY) {
    var sellOffer = _.extend(baseOffer, {
      type: "ask",
      currency: buy_which_token,
      volume: sell_how_much.toString(),
      price: web3.toWei(buy_how_much.dividedBy(sell_how_much)).toString()
    })
    Offers.upsert(idx, {$set: sellOffer})
  } else if (buy_which_token === BASE_CURRENCY) {
    var buyOffer = _.extend(baseOffer, {
      type: "bid",
      currency: sell_which_token,
      volume: buy_how_much.toString(),
      price: web3.toWei(sell_how_much.dividedBy(buy_how_much)).toString()
    })
    Offers.upsert(idx, {$set: buyOffer})
  } else {
    console.warn("Offers.updateOffer: No base currency found")
  }
}

Offers.newOffer = function(sell_how_much, sell_which_token, buy_how_much, buy_which_token) {
  var offerTx = MakerOTC.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token, {gas: 300000})
  console.log("offer!", offerTx, sell_how_much, sell_which_token, buy_how_much, buy_which_token)
  // TODO is this the best way to use idx?
  var idx = MakerOTC.last_offer_id().toNumber() + 1
  Offers.updateOffer(idx.toString(), sell_how_much, sell_which_token, buy_how_much, buy_which_token, web3.eth.defaultAccount, Status.PENDING)
}

Offers.buyOffer = function(idx) {
  var id = parseInt(idx)
  var tx = MakerOTC.buy(id, {gas: 100000})
  console.log("buy!", id, tx)
  Offers.update({_id: idx}, {$set: {status: Status.BOUGHT}})
}

Offers.cancelOffer = function(idx) {
  var id = parseInt(idx)
  var tx = MakerOTC.cancel(id, {gas: 100000})
  console.log("cancel!", id, tx)
  Offers.update({_id: idx}, {$set: {status: Status.CANCELLED}})
}

Meteor.startup(function() {
  var last_offer_id = MakerOTC.last_offer_id().toNumber()
  console.log("last_offer_id", last_offer_id)
  for (var id = 1; id <= last_offer_id; id++ ) {
    Offers.syncOffer(id)
  }

  var event = MakerOTC.ItemUpdate(function(error, result) {
    if (!error) {
      var id = result.args.id.toNumber();
      console.log("Offer updated", id, result);
      Offers.syncOffer(id)
    }
  });
})
