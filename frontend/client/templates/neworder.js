Template.neworder.viewmodel({
  type: 'buy',
  fancyType: function () {
    return this.type() === 'buy' ? 'Bid' : 'Ask'
  },
  currency: 'ETH',
  price: '0',
  amount: '0',
  calcTotal: function (event) {
    try {
      var price = new BigNumber(this.price())
      var amount = new BigNumber(this.amount())
      var total = price.times(amount)
      total.isNaN() ? this.total('0') : this.total(total.toString(10))
    } catch (e) {
      this.total('0')
    }
  },
  total: '0',
  calcAmount: function (event) {
    try {
      var price = new BigNumber(this.price())
      var amount = new BigNumber(this.amount())
      var total = new BigNumber(this.total())
      if (total.isZero() && price.isZero() && (amount.isNaN() || amount.isNegative())) {
        this.amount('0')
      } else if (!total.isZero() || !price.isZero()) {
        amount = total.div(price)
        amount.isNaN() ? this.amount('0') : this.amount(amount.toString(10))
      }
    } catch (e) {
      this.amount('0')
    }
  },
  maxAmount: function () {
    var token = Tokens.findOne('MKR')
    var balance = new BigNumber(token.balance)
    var allowance = new BigNumber(token.allowance)
    return this.type() === 'sell' ? web3.fromWei(BigNumber.min(balance, allowance).toString(10)) : '9e999'
  },
  maxTotal: function () {
    // Only allow change of total if price is well-defined
    try {
      var price = new BigNumber(this.price())
      if ((price.isNaN() || price.isZero() || price.isNegative())) {
        return '0'
      }
    } catch (e) {
      return '0'
    }
    // If price is well-defined, take minimum of balance and allowance of currency, if 'buy', otherwise Infinity
    var token = Tokens.findOne(this.currency())
    var balance = new BigNumber(token.balance)
    var allowance = new BigNumber(token.allowance)
    return this.type() === 'buy' ? web3.fromWei(BigNumber.min(balance, allowance).toString(10)) : '9e999'
  },
  canSubmit: function () {
    try {
      var type = this.type()
      var price = new BigNumber(this.price())
      var amount = new BigNumber(this.amount())
      var maxAmount = new BigNumber(this.maxAmount())
      var total = new BigNumber(this.total())
      var maxTotal = new BigNumber(this.maxTotal())
      return price.gt(0) && amount.gt(0) && total.gt(0) && (type !== 'buy' || total.lte(maxTotal)) && (type !== 'sell' || amount.lte(maxAmount))
    } catch (e) {
      return false
    }
  },
  submit: function (event) {
    event.preventDefault()

    var sell_how_much, sell_which_token, buy_how_much, buy_which_token
    if (this.type() === 'buy') {
      sell_how_much = web3.toWei(this.total())
      sell_which_token = this.currency()
      buy_how_much = web3.toWei(this.amount())
      buy_which_token = BASE_CURRENCY
    } else {
      sell_how_much = web3.toWei(this.amount())
      sell_which_token = BASE_CURRENCY
      buy_how_much = web3.toWei(this.total())
      buy_which_token = this.currency()
    }
    Offers.newOffer(sell_how_much, sell_which_token, buy_how_much, buy_which_token)
  }
})
