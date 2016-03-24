Template.registerHelper('baseCurrency', function (value) {
  return BASE_CURRENCY;
})

Template.registerHelper('equals', function (a, b) {
  return a === b;
})

Template.registerHelper('checked_eq', function(x, y) {
  return (x === y) ? { checked: 'checked' } : null
})

/**
Formats a number.
    {{formatNumber myNumber "0,0.0[0000]"}}
@method (formatNumber)
@param {String} number
@param {String} format       the format string
@return {String} The formatted number
**/
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
