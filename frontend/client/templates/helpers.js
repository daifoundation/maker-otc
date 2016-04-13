Template.registerHelper('contractExists', function () {
  var network = Session.get('network')
  var isConnected = Session.get('isConnected')
  if (network === false || isConnected === false) {
    return false
  }
  var code = web3.eth.getCode(Dapple['maker-otc'].objects.otc.address)
  return typeof code === 'string' && code !== '' && code !== '0x'
})

Template.registerHelper('network', function () {
  return Session.get('network')
})

Template.registerHelper('contractHref', function () {
  var network = Session.get('network')
  return 'https://' + (network === 'test' ? 'testnet.' : '') + 'etherscan.io/address/' + Dapple['maker-otc'].objects.otc.address
})

Template.registerHelper('ready', function () {
  return Session.get('isConnected') && !Session.get('syncing')
})

Template.registerHelper('syncing', function () {
  return Session.get('syncing')
})

Template.registerHelper('isConnected', function () {
  return Session.get('isConnected')
})

Template.registerHelper('syncingPercentage', function () {
  var startingBlock = Session.get('startingBlock')
  var currentBlock = Session.get('currentBlock')
  var highestBlock = Session.get('highestBlock')
  return Math.round(100 * (currentBlock - startingBlock) / (highestBlock - startingBlock))
})

Template.registerHelper('address', function () {
  return Session.get('address')
})

Template.registerHelper('ETHBalance', function () {
  return Session.get('ETHBalance')
})

Template.registerHelper('MKRBalance', function () {
  return Session.get('MKRBalance')
})

Template.registerHelper('DAIBalance', function () {
  return Session.get('DAIBalance')
})

Template.registerHelper('baseCurrency', function (value) {
  return BASE_CURRENCY
})

Template.registerHelper('equals', function (a, b) {
  return a === b
})

Template.registerHelper('formatBalance', function (wei, format) {
  if (format instanceof Spacebars.kw) {
    format = null
  }
  format = format || '0,0.00[0000]'

  return EthTools.formatBalance(wei, format)
})

Template.registerHelper('formatPrice', function (order) {
  var format = '0,0.00[0000]'
  var price = new BigNumber(order.price, 10)
  if (order.currency === 'ETH') {
    var usd = EthTools.ticker.findOne('usd')
    if (usd) {
      var usd_value = price.times(usd.price)
      return EthTools.formatBalance(usd_value, format)
    }
  } else if (order.currency === 'DAI') {
    var value = price.times(0.73) // TODO DAI exchange rate
    return EthTools.formatBalance(value, format)
  }
})
