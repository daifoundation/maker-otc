this.Tokens = new Meteor.Collection(null)

var ALL_TOKENS = ['ETH', 'MKR', 'DAI']

/**
 * Syncs the ETH, MKR and DAI balances of Session.get('address')
 * usually called for each new block
 */
Tokens.sync = function () {
  var network = Session.get('network')
  var address = Session.get('address')
  var newETHBalance = web3.eth.getBalance(address).toString(10)
  if (!Session.equals('ETHBalance', newETHBalance)) {
    Session.set('ETHBalance', newETHBalance)
  }

  if (network !== 'private') {
    var contract_address = Dapple['maker-otc'].objects.otc.address

    ALL_TOKENS.forEach(function (token) {
      var balance = Dapple['makerjs'].getToken(token).balanceOf(address).toString(10)
      var allowance = Dapple['makerjs'].getToken(token).allowance(address, contract_address).toString(10)
      Tokens.upsert(token, { $set: { balance: balance, allowance: allowance }, $setOnInsert: { newAllowance: allowance } })
    })
  } else {
    ALL_TOKENS.forEach(function (token) {
      Tokens.upsert(token, { $set: { balance: '0', allowance: '0' }, $setOnInsert: { newAllowance: '0' } })
    })
  }
}
