/**
 * Network check
 * https://github.com/ethereum/meteor-dapp-wallet/blob/90ad8148d042ef7c28610115e97acfa6449442e3/app/client/lib/ethereum/walletInterface.js#L32-L46
 */

Session.set('network', false)

// CHECK FOR NETWORK
function checkNetwork () {
  var isConnected = web3.isConnected()
  if (!Session.equals('isConnected', isConnected)) {
    if (isConnected === true) {
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
          Session.set('network', network)
          Session.set('address', web3.eth.defaultAccount)
          Tokens.sync()
          Session.set('isConnected', isConnected)
          syncOffers()
        }
      })
    } else {
      Session.set('isConnected', isConnected)
      Session.set('network', false)
    }
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
  if (last_offer_id > 0) {
    Session.set('loading', true)
    Session.set('loadingProgress', 0)
    Offers.syncOffer(last_offer_id, last_offer_id)
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
      Session.set('network', network)
      Session.set('address', web3.eth.defaultAccount)
      Tokens.sync()
      Session.set('isConnected', true)
      syncOffers()
    }
  }

  web3.eth.filter('latest', Tokens.sync)

  web3.eth.isSyncing(function (error, sync) {
    if (!error) {
      Session.set('syncing', sync !== false)

      // Stop all app activity
      if (sync === true) {
        // We use `true`, so it stops all filters, but not the web3.eth.syncing polling
        web3.reset(true)
        checkNetwork()
      // show sync info
      } else if (sync) {
        Session.set('startingBlock', sync.startingBlock)
        Session.set('currentBlock', sync.currentBlock)
        Session.set('highestBlock', sync.highestBlock)
      } else {
        checkNetwork()
        web3.eth.filter('latest', Tokens.sync)
      }
    }
  })

  Meteor.setInterval(checkNetwork, 2000)

  Dapple['maker-otc'].objects.otc.ItemUpdate(function (error, result) {
    if (!error) {
      var id = result.args.id.toNumber()
      console.log('Offer updated', id, result)
      Offers.syncOffer(id)
      Offers.remove(result.transactionHash)
    }
  })
})
