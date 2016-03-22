Template.registerHelper('formatPrice', function (value) {
  return Math.round(value * 100) / 100;
})
