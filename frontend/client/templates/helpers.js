Template.registerHelper('baseCurrency', function (value) {
  return BASE_CURRENCY;
})

Template.registerHelper('equals', function (a, b) {
  return a === b;
})

Template.registerHelper('checked_eq', function(x, y) {
  return (x === y) ? { checked: 'checked' } : null
})

Template.registerHelper('formatNumber', function(number, format){
    if(format instanceof Spacebars.kw)
        format = null;

    if(number instanceof String)
        number = new Bignumber(number, 10);

    if(number instanceof BigNumber)
        number = number.toNumber();

    format = format || '0,0.0[0000]';

    if(!_.isFinite(number))
        number = numeral().unformat(number);

    if(_.isFinite(number))
        return numeral(number).format(format);
});

Template.registerHelper('formatBalance', function(wei, format){
  if(format instanceof Spacebars.kw)
      format = null;
  format = format || '0,0.00[0000]';

  return EthTools.formatBalance(wei, format)
});

Template.registerHelper('formatPrice', function(order){
  var format = '0,0.00[0000]'
  if (order.currency === "ETH") {
    var usd = EthTools.ticker.findOne('usd')
    if (usd) {
      var price = new BigNumber(order.price, 10)
      var value = price.times(usd.price)
      return EthTools.formatBalance(value, format)
    }
  } else if (order.currency === "DAI") {
    var price = new BigNumber(order.price, 10)
    var value = price.times(0.73) // TODO DAI exchange rate
    return EthTools.formatBalance(value, format)
  }
});
