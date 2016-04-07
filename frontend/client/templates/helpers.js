Template.registerHelper('contractExists', function () {
  var code = web3.eth.getCode(MakerOTC.address)
  return typeof code === 'string' && code !== '' && code !== '0x'
})

Template.registerHelper('network', function () {
  return Session.get('network')
})

Template.registerHelper('ready', function () {
  return web3.isConnected() && !Session.get('syncing')
})

Template.registerHelper('syncing', function () {
  return Session.get('syncing')
})

Template.registerHelper('isConnected', function () {
  return web3.isConnected()
})

Template.registerHelper('syncingPercentage', function () {
  var startingBlock = Session.get('startingBlock')
  var currentBlock = Session.get('currentBlock')
  var highestBlock = Session.get('highestBlock')
  return Math.round((currentBlock - startingBlock) / (highestBlock - startingBlock))
})

Template.registerHelper('address', function () {
  return Session.get('address')
})

Template.registerHelper('ethBalance', function (address) {
  return web3.isAddress(address) ? web3.fromWei(web3.eth.getBalance(address)) : '-'
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
