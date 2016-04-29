Template.offermodal.onRendered(function () {
  $('#offerModal,#cancelModal').on('hidden.bs.modal', function () {
    if (!($('#offerModal').data('bs.modal') || { isShown: false }).isShown) {
      Session.set('selectedOffer', undefined)
    }
  })
})

Template.offermodal.viewmodel({
  volume: '',
  total: '',
  autorun: function () {
    if (Template.currentData().offer) {
      var volume = web3.fromWei(new BigNumber(Template.currentData().offer.volume))
      var total = web3.fromWei(new BigNumber(Template.currentData().offer.total))
      this.volume(volume.toString(10))
      this.total(total.toString(10))
    }
  },
  maxVolume: function () {
    try {
      if (Template.currentData().offer.type === 'bid') {
        // Calculate max volume, since we want to sell MKR, we need to check how much MKR we can sell
        var token = Tokens.findOne(BASE_CURRENCY)
        if (!token) {
          return '0'
        } else {
          var volume = new BigNumber(Template.currentData().offer.volume)
          var balance = new BigNumber(token.balance)
          var allowance = new BigNumber(token.allowance)
          return web3.fromWei(BigNumber.min(balance, allowance, volume)).toString(10)
        }
      } else {
        // Derive from max total
        var maxTotal = new BigNumber(this.maxTotal())
        var price = web3.fromWei(new BigNumber(Template.currentData().offer.price))
        return maxTotal.div(price).toString(10)
      }
    } catch (e) {
      return '0'
    }
  },
  maxTotal: function () {
    try {
      var price = web3.fromWei(new BigNumber(Template.currentData().offer.price))
      if (Template.currentData().offer.type === 'bid') {
        // Derive total from max volume
        var maxVolume = new BigNumber(this.maxVolume())
        return price.times(maxVolume).toString(10)
      } else {
        // Calculate max total, since we want to buy MKR, we need to check how much of the currency is available
        var token = Tokens.findOne(Template.currentData().offer.currency)
        if (!token) {
          return '0'
        } else {
          var total = new BigNumber(Template.currentData().offer.total)
          var balance = new BigNumber(token.balance)
          var allowance = new BigNumber(token.allowance)
          return web3.fromWei(BigNumber.min(balance, allowance, total)).toString(10)
        }
      }
    } catch (e) {
      return '0'
    }
  },
  calcVolume: function () {
    try {
      var price = web3.fromWei(new BigNumber(this.templateInstance.data.offer.price))
      var total = new BigNumber(this.total())
      this.volume(total.div(price).toString(10))
    } catch (e) {
      this.volume('0')
    }
  },
  calcTotal: function () {
    try {
      var price = web3.fromWei(new BigNumber(this.templateInstance.data.offer.price))
      var volume = new BigNumber(this.volume())
      this.total(price.times(volume))
    } catch (e) {
      this.total('0')
    }
  },
  canCancel: function () {
    if (!Template.currentData().offer) {
      return false
    } else {
      return Template.currentData().offer.status === Status.CONFIRMED && Session.equals('address', Template.currentData().offer.owner)
    }
  },
  cancel: function () {
    var _id = this.templateInstance.data.offer._id
    Offers.cancelOffer(_id)
  },
  canBuy: function () {
    try {
      var volume = new BigNumber(this.volume())
      var total = new BigNumber(this.total())
      return !total.isNaN() && total.gt(0) && total.lte(new BigNumber(this.maxTotal())) && !volume.isNaN() && volume.gt(0) && volume.lte(new BigNumber(this.maxVolume()))
    } catch (e) {
      return false
    }
  },
  buy: function () {
    var _id = this.templateInstance.data.offer._id
    if (this.templateInstance.data.offer.type === 'bid') {
      Offers.buyOffer(_id, web3.toWei(new BigNumber(this.total())))
    } else {
      Offers.buyOffer(_id, web3.toWei(new BigNumber(this.volume())))
    }
  }
})
