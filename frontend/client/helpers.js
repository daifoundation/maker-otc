Template.registerHelper('baseCurrency', function (value) {
  return BASE_CURRENCY;
})

Template.registerHelper('formatPrice', function (value) {
  return Math.round(value * 100) / 100;
})

Template.registerHelper('equals', function (a, b) {
  return a === b;
})

Template.registerHelper('checked_eq', function(x, y) {
  return (x === y) ? { checked: 'checked' } : null
})
