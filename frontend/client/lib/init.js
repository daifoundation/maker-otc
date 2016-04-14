/**
 * Network check
 * https://github.com/ethereum/meteor-dapp-wallet/blob/90ad8148d042ef7c28610115e97acfa6449442e3/app/client/lib/ethereum/walletInterface.js#L32-L46
 */

Session.set('network', false)

// CHECK FOR NETWORK
function checkNetwork () {
  if (web3.isConnected()) {
    web3.eth.getBlock(0, function (e, res) {
      var network = false
      if (!e) {
        switch (res.hash) {
          case '0x0cd786a2425d16f152c658316c423e6ce1181e15c3295826d7c9904cba9ce303':
            network = 'test'
            break
          case '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3':
            network = 'main'
            break
          default:
            network = 'private'
        }
      }
      if (!Session.equals('network', network)) {
        Dapple.init(network)
        if (!_.contains(web3.eth.accounts, web3.eth.defaultAccount)) {
          if (web3.eth.accounts.length > 0) {
            web3.eth.defaultAccount = web3.eth.accounts[0]
          } else {
            web3.eth.defaultAccount = undefined
          }
        }
        Session.set('isConnected', true)
        Session.set('network', network)
        Session.set('address', web3.eth.defaultAccount)
        syncBalance()
        syncOffers()
      }
    })
  } else {
    Session.set('network', false)
  }
}

/**
 * Syncs up all offers in the otc object
 */
Session.set('loading', false)

function syncOffers () {
  Offers.remove({})
  var last_offer_id = Dapple['maker-otc'].objects.otc.last_offer_id().toNumber()
  console.log('last_offer_id', last_offer_id)
  Session.set('loading', true)
  Session.set('loadingProgress', 0)
  for (var id = 1; id <= last_offer_id; id++) {
    Offers.syncOffer(id)
    Session.set('loadingProgress', Math.round(100 * (id / last_offer_id)))
  }
  Session.set('loading', false)
}

/**
 * Syncs the ETH, MKR and DAI balances of Session.get('address')
 * usually called for each new block
 */
function syncBalance () {
  var network = Session.get('network')
  var address = Session.get('address')
  var newETHBalance = web3.eth.getBalance(address).toString(10)
  if (!Session.equals('ETHBalance', newETHBalance)) {
    Session.set('ETHBalance', newETHBalance)
  }
  if (network !== 'private') {
    var newMKRBalance = Dapple['makerjs'].getToken('MKR').balanceOf(address).toString(10)
    if (!Session.equals('MKRBalance', newMKRBalance)) {
      Session.set('MKRBalance', newMKRBalance)
    }
    var newDAIBalance = Dapple['makerjs'].getToken('DAI').balanceOf(address).toString(10)
    if (!Session.equals('DAIBalance', newDAIBalance)) {
      Session.set('DAIBalance', newDAIBalance)
    }
  } else {
    Session.set('MKRBalance', '0')
    Session.set('DAIBalance', '0')
  }
}

Session.set('syncing', false)
Session.set('isConnected', false)

/**
 * Startup code
 */
Meteor.startup(function () {
  if (web3.isConnected()) {
    // Initial synchronous network check
    // Asynchronous check often causes Meteor 'cannot flush during autorun' error
    var network = false
    try {
      switch (web3.eth.getBlock(0).hash) {
        case '0x0cd786a2425d16f152c658316c423e6ce1181e15c3295826d7c9904cba9ce303':
          network = 'test'
          break
        case '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3':
          network = 'main'
          break
        default:
          network = 'private'
      }
    } catch (e) { }
    if (!Session.equals('network', network)) {
      Dapple.init(network)
      if (!_.contains(web3.eth.accounts, web3.eth.defaultAccount)) {
        if (web3.eth.accounts.length > 0) {
          web3.eth.defaultAccount = web3.eth.accounts[0]
        } else {
          web3.eth.defaultAccount = undefined
        }
      }
      Session.set('isConnected', true)
      Session.set('network', network)
      Session.set('address', web3.eth.defaultAccount)
      syncBalance()
      syncOffers()
    }
  }

  web3.eth.filter('latest', syncBalance)

  web3.eth.isSyncing(function (error, sync) {
    if (!error) {
      Session.set('syncing', sync !== false)

      // Stop all app activity
      if (sync === true) {
        // We use `true`, so it stops all filters, but not the web3.eth.syncing polling
        checkNetwork()
        web3.reset(true)

      // show sync info
      } else if (sync) {
        Session.set('startingBlock', sync.startingBlock)
        Session.set('currentBlock', sync.currentBlock)
        Session.set('highestBlock', sync.highestBlock)
      } else {
        checkNetwork()
        web3.eth.filter('latest', syncBalance)
      }
    }
  })

  Meteor.setInterval(function () {
    var before = Session.get('isConnected')
    var after = web3.isConnected()
    if (before !== after) {
      Session.set('isConnected', after)
      checkNetwork()
    }
  }, 2000)

  Dapple['maker-otc'].objects.otc.ItemUpdate(function (error, result) {
    if (!error) {
      var id = result.args.id.toNumber()
      console.log('Offer updated', id, result)
      Offers.syncOffer(id)
      Offers.remove(result.transactionHash)
    }
  })
})
