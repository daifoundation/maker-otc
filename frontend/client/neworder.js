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
    Session.set("price", price)
    Session.set("total", Session.get("amount") * price)
  },
  'change .amount, keyup .amount, mouseup .amount': function () {
    var amount = $('input[name="amount"]').val()
    Session.set("amount", amount)
    Session.set("total", amount * Session.get("price"))
  },
  'change .total, keyup .total, mouseup .total': function () {
    var total = $('input[name="total"]').val()
    Session.set("total", total)
    Session.set("amount", total / Session.get("price"))
  },
  'click #submitorder': function () {
    event.preventDefault()
    var sell_how_much, sell_which_token, buy_how_much, buy_which_token
    if (Session.get("ordertype") == "buy") {
      sell_how_much = Session.get("total")
      sell_which_token = Session.get("currency")
      buy_how_much = Session.get("amount")
      buy_which_token = BASE_CURRENCY
    } else {
      sell_how_much = Session.get("amount")
      sell_which_token = BASE_CURRENCY
      buy_how_much = Session.get("total")
      buy_which_token = Session.get("currency")
    }
    var offerTx = MakerOTC.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token, {gas: 300000})
    console.log("offer!", offerTx, sell_how_much, sell_which_token, buy_how_much, buy_which_token)
    // TODO pending offer
    return false
  }
})
