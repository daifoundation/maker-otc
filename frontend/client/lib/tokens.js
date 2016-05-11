this.Tokens = new Meteor.Collection(null)

Session.set('quoteCurrency', 'ETH')
Session.set('baseCurrency', 'MKR')

/**
 * Syncs the quote and base currencies' balances and allowances of selected account,
 * usually called for each new block
 */
Tokens.sync = function () {
  var network = Session.get('network')
  var address = web3.eth.defaultAccount
  web3.eth.getBalance(address, function (error, balance) {
    var newETHBalance = balance.toString(10)
    if (!error && !Session.equals('ETHBalance', newETHBalance)) {
      Session.set('ETHBalance', newETHBalance)
    }
  })

  var ALL_TOKENS = _.uniq([ Session.get('quoteCurrency'), Session.get('baseCurrency') ])

  if (network !== 'private') {
    var contract_address = Dapple['maker-otc'].objects.otc.address

    // Sync token balances and allowances asynchronously
    ALL_TOKENS.forEach(function (token_id) {
      Dapple['makerjs'].getToken(token_id, function (error, token) {
        if (!error) {
          token.balanceOf(address, function (error, balance) {
            if (!error) {
              Tokens.upsert(token_id, { $set: { balance: balance.toString(10) } })
            }
          })
          token.allowance(address, contract_address, function (error, allowance) {
            if (!error) {
              Tokens.upsert(token_id, { $set: { allowance: allowance.toString(10) } })
            }
          })
        }
      })
    })
  } else {
    ALL_TOKENS.forEach(function (token) {
      Tokens.upsert(token, { $set: { balance: '0', allowance: '0' } })
    })
  }
}
