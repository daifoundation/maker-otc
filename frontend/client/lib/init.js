/**
 * Network check
 * https://github.com/ethereum/meteor-dapp-wallet/blob/90ad8148d042ef7c28610115e97acfa6449442e3/app/client/lib/ethereum/walletInterface.js#L32-L46
 */

Session.setDefault('network', false)

// CHECK FOR NETWORK
function checkNetwork () {
  if (web3.isConnected()) {
    web3.eth.getBlock(0, function (e, res) {
      var before = Session.get('network')
      var after = false
      if (!e) {
        switch (res.hash) {
          case '0x0cd786a2425d16f152c658316c423e6ce1181e15c3295826d7c9904cba9ce303':
            after = 'test'
            break
          case '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3':
            after = 'main'
            break
          default:
            after = 'private'
        }
      }
      if (before !== after) {
        var environment = 'default'
        switch (after) {
          case 'test':
            environment = 'morden'
            break
          case 'main':
            environment = 'main'
            break
        }
        Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments[environment])
        if (!_.contains(web3.eth.accounts, web3.eth.defaultAccount)) {
          if (web3.eth.accounts.length > 0) {
            web3.eth.defaultAccount = web3.eth.accounts[0]
          } else {
            web3.eth.defaultAccount = undefined
          }
        }
        Session.set('isConnected', true)
        Session.set('network', after)
        Session.set('address', web3.eth.defaultAccount)
        syncOffers()
      }
    })
  } else {
    Session.set('network', false)
  }
}

function syncOffers () {
  Offers.remove({})
  var last_offer_id = Dapple['maker-otc'].objects.otc.last_offer_id().toNumber()
  console.log('last_offer_id', last_offer_id)
  for (var id = 1; id <= last_offer_id; id++) {
    Offers.syncOffer(id)
  }
}

Session.setDefault('syncing', false)
Session.setDefault('isConnected', false)

/**
 * Startup code
 */
Meteor.startup(function () {
  if (web3.isConnected()) {
    // Initial synchronous network check
    // Asynchronous check often causes Meteor errors 'cannot flush during autorun'
    var before = Session.get('network')
    var after = false
    try {
      switch (web3.eth.getBlock(0).hash) {
        case '0x0cd786a2425d16f152c658316c423e6ce1181e15c3295826d7c9904cba9ce303':
          after = 'test'
          break
        case '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3':
          after = 'main'
          break
        default:
          after = 'private'
      }
    } catch (e) { }
    if (before !== after) {
      var environment = 'default'
      switch (after) {
        case 'test':
          environment = 'morden'
          break
        case 'main':
          environment = 'main'
          break
      }
      Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments[environment])
      if (!_.contains(web3.eth.accounts, web3.eth.defaultAccount)) {
        if (web3.eth.accounts.length > 0) {
          web3.eth.defaultAccount = web3.eth.accounts[0]
        } else {
          web3.eth.defaultAccount = undefined
        }
      }
      Session.set('isConnected', true)
      Session.set('network', after)
      Session.set('address', web3.eth.defaultAccount)
      syncOffers()
    }
  }

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
      }
    }
  })

  Meteor.setInterval(function () {
    var before = Session.get('isConnected')
    var after = web3.isConnected()
    if (before !== after) {
      Session.set('isConnected', after)
      if (after === true) {
        checkNetwork()
      } else {
        Session.set('network', false)
      }
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

/**
 * Token Interface
 * https://github.com/ethereum/meteor-dapp-wallet/blob/74414d36c2453a468116d5884e28eaa6eb1723e5/app/client/lib/ethereum/tokenInterface.js
 */
// "0x11485c5f164d6a67a72eee9093b2581d1c304094"

// Token Interface

var tokenInterface = [
  {
    "type": "function",
    "name": "name",
    "constant": true,
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string"
      }
    ]
  },
  {
    "type": "function",
    "name": "decimals",
    "constant": true,
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8"
      }
    ]
  },
  {
    "type": "function",
    "name": "balanceOf",
    "constant": true,
    "inputs": [
      {
        "name": "",
        "type": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ]
  },
  {
    "type": "function",
    "name": "symbol",
    "constant": true,
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string"
      }
    ]
  },
  {
    "type": "function",
    "name": "transfer",
    "constant": false,
    "inputs": [
      {
        "name": "_to",
        "type": "address"
      },
      {
        "name": "_value",
        "type": "uint256"
      }
    ],
    "outputs": []
  },
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_supply",
        "type": "uint256"
      },
      {
        "name": "_name",
        "type": "string"
      },
      {
        "name": "_decimals",
        "type": "uint8"
      },
      {
        "name": "_symbol",
        "type": "string"
      }
    ]
  },
  {
    "name": "Transfer",
    "type": "event",
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "name": "from",
        "type": "address"
      },
      {
        "indexed": true,
        "name": "to",
        "type": "address"
      },
      {
        "indexed": false,
        "name": "value",
        "type": "uint256"
      }
    ]
  }
]

this.TokenContract = web3.eth.contract(tokenInterface)
