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
      Dapple['makerjs'].getToken(this.quoteCurrency()).totalSupply()
      this.quoteHelper('')
      Session.set('quoteCurrency', this.quoteCurrency())
      Tokens.sync()
    } catch (e) {
      this.quoteHelper('token not found')
    }
  },
  baseChange: function () {
    try {
      Dapple['makerjs'].getToken(this.baseCurrency()).totalSupply()
      this.baseHelper('')
      Session.set('baseCurrency', this.baseCurrency())
      Tokens.sync()
    } catch (e) {
      this.baseHelper('token not found')
    }
  }
})
