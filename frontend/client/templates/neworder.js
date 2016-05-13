Template.neworder.viewmodel({
  autorun: function () {
    Transactions.observeRemoved('newoffer', function (document) {
      Offers.remove(document.tx)
    })
  },
  lastError: '',
  type: 'buy',
  fancyType: function () {
    return this.type() === 'buy' ? 'Bid' : 'Ask'
  },
  sellCurrency: function () {
    if (this.type() === 'buy') {
      return Session.get('quoteCurrency')
    } else {
      return Session.get('baseCurrency')
    }
  },
  price: '0',
  priceDefined: function () {
    try {
      var price = new BigNumber(this.price())
      return !price.isNaN() && price.gt(0)
    } catch (e) {
      return false
    }
  },
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
    if (this.type() === 'sell') {
      var token = Tokens.findOne(Session.get('baseCurrency'))
      if (!token) {
        return '0'
      } else {
        var balance = new BigNumber(token.balance)
        var allowance = new BigNumber(token.allowance)
        return web3.fromWei(BigNumber.min(balance, allowance).toString(10))
      }
    } else {
      return '9e999'
    }
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
    if (this.type() === 'buy') {
      var token = Tokens.findOne(Session.get('quoteCurrency'))
      if (!token) {
        return '0'
      } else {
        var balance = new BigNumber(token.balance)
        var allowance = new BigNumber(token.allowance)
        return web3.fromWei(BigNumber.min(balance, allowance).toString(10))
      }
    } else {
      return '9e999'
    }
  },
  hasBalance: function (currency) {
    try {
      var token = Tokens.findOne(currency)
      var balance = new BigNumber(token.balance)
      return token && balance.gte(web3.toWei(new BigNumber(this.type() === 'sell' ? this.amount() : this.total())))
    } catch (e) {
      return false
    }
  },
  hasAllowance: function (currency) {
    try {
      var token = Tokens.findOne(currency)
      var allowance = new BigNumber(token.allowance)
      return token && allowance.gte(web3.toWei(new BigNumber(this.type() === 'sell' ? this.amount() : this.total())))
    } catch (e) {
      return false
    }
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
  preventDefault: function (event) {
    event.preventDefault()
  },
  submit: function (event) {
    event.preventDefault()

    var _this = this
    _this.lastError('')
    var sell_how_much, sell_which_token, buy_how_much, buy_which_token
    if (this.type() === 'buy') {
      sell_how_much = web3.toWei(this.total())
      sell_which_token = Session.get('quoteCurrency')
      buy_how_much = web3.toWei(this.amount())
      buy_which_token = Session.get('baseCurrency')
    } else {
      sell_how_much = web3.toWei(this.amount())
      sell_which_token = Session.get('baseCurrency')
      buy_how_much = web3.toWei(this.total())
      buy_which_token = Session.get('quoteCurrency')
    }
    Offers.newOffer(sell_how_much, sell_which_token, buy_how_much, buy_which_token, function (error, tx) {
      if (error != null) {
        _this.lastError(error.toString())
      }
    })
  }
})
