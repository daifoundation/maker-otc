Template.currencySelector.viewmodel({
  autorun: function () {
    this.quoteCurrency(Session.get('quoteCurrency'))
    this.baseCurrency(Session.get('baseCurrency'))
  },
  currencies: [ 'ETH', 'MKR', 'DAI' ],
  quoteCurrency: '',
  baseCurrency: '',
  quoteHelper: '',
  baseHelper: '',
  quoteChange: function () {
    try {
      var _this = this
      Dapple['makerjs'].getToken(_this.quoteCurrency(), function (error, token) {
        if (!error) {
          try {
            token.totalSupply()
            _this.quoteHelper('')
            localStorage.setItem('quoteCurrency', _this.quoteCurrency())
            Session.set('quoteCurrency', _this.quoteCurrency())
            Tokens.sync()
          } catch (e) {
            _this.quoteHelper('token not found')
          }
        }
      })
    } catch (e) {
      this.quoteHelper('token not found')
    }
  },
  baseChange: function () {
    try {
      var _this = this
      Dapple['makerjs'].getToken(_this.baseCurrency(), function (error, token) {
        if (!error) {
          try {
            token.totalSupply()
            _this.baseHelper('')
            localStorage.setItem('baseCurrency', _this.baseCurrency())
            Session.set('baseCurrency', _this.baseCurrency())
            Tokens.sync()
          } catch (e) {
            _this.baseHelper('token not found')
          }
        }
      })
    } catch (e) {
      this.baseHelper('token not found')
    }
  }
})
