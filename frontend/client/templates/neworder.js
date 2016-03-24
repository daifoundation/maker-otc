Session.setDefault("ordertype", "buy");
Session.setDefault("currency", "ETH");
Session.setDefault("price", 0);
Session.setDefault("amount", 0);
Session.setDefault("total", 0);

Template.neworder.helpers({
  ordertype: function () {
    return Session.get("ordertype")
  },
  currency: function () {
    return Session.get("currency")
  },
  price: function () {
    return Session.get("price")
  },
  amount: function () {
    return Session.get("amount")
  },
  total: function () {
    return Session.get("total")
  },
  buttonState: function () {
    if (Session.get("price") > 0 && Session.get("amount") > 0 && Session.get("total") > 0) {
      return ""
    } else {
      return "disabled"
    }
  }
})

Template.neworder.events({
  'change .ordertype': function () {
    var ordertype = $('input:radio[name="ordertype"]:checked').val()
    Session.set("ordertype", ordertype)
  },
  'change .currency': function () {
    var currency = $('input:radio[name="currency"]:checked').val()
    Session.set("currency", currency)
  },
  'change .price, keyup .price, mouseup .price': function () {
    var price = $('input[name="price"]').val()
    var amount = Session.get("amount")
    Session.set("price", price)
    Session.set("total", amount * price)
  },
  'change .amount, keyup .amount, mouseup .amount': function () {
    var amount = $('input[name="amount"]').val()
    var price = Session.get("price")
    Session.set("amount", amount)
    Session.set("total", amount * price)
  },
  'change .total, keyup .total, mouseup .total': function () {
    var total = $('input[name="total"]').val()
    var price = Session.get("price")
    Session.set("total", total)
    if (price > 0) {
      Session.set("amount", total / price)
    } else {
      Session.set("amount", 0);
    }
  },
  'click #submitorder': function () {
    event.preventDefault()
    var sell_how_much, sell_which_token, buy_how_much, buy_which_token
    if (Session.get("ordertype") == "buy") {
      sell_how_much = web3.toWei(Session.get("total"))
      sell_which_token = Session.get("currency")
      buy_how_much = web3.toWei(Session.get("amount"))
      buy_which_token = BASE_CURRENCY
    } else {
      sell_how_much = web3.toWei(Session.get("amount"))
      sell_which_token = BASE_CURRENCY
      buy_how_much = web3.toWei(Session.get("total"))
      buy_which_token = Session.get("currency")
    }
    Offers.newOffer(sell_how_much, sell_which_token, buy_how_much, buy_which_token)
    return false
  }
})
