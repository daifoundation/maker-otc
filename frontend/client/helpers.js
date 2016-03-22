Template.registerHelper('baseCurrency', function (value) {
  return BASE_CURRENCY;
})

Template.registerHelper('formatPrice', function (value) {
  return Math.round(value * 100) / 100;
})
