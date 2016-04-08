/*
 * Network check
 * https://github.com/ethereum/meteor-dapp-wallet/blob/90ad8148d042ef7c28610115e97acfa6449442e3/app/client/lib/ethereum/walletInterface.js#L32-L46
 */

Session.setDefault('network', false)

// CHECK FOR NETWORK
web3.eth.getBlock(0, function (e, res) {
  if (!e) {
    switch (res.hash) {
      case '0x0cd786a2425d16f152c658316c423e6ce1181e15c3295826d7c9904cba9ce303':
        Session.set('network', 'test')
        break
      case '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3':
        Session.set('network', 'main')
        break
      default:
        Session.set('network', 'private')
    }
  }
})

Session.setDefault('syncing', false)

web3.eth.isSyncing(function (error, sync) {
  if (!error) {
    Session.set('syncing', sync !== false)

    // Stop all app activity
    if (sync === true) {
      // We use `true`, so it stops all filters, but not the web3.eth.syncing polling
      web3.reset(true)

    // show sync info
    } else if (sync) {
      Session.set('startingBlock', sync.startingBlock)
      Session.set('currentBlock', sync.currentBlock)
      Session.set('highestBlock', sync.highestBlock)
    } else {
      // run your app init function...
    }
  }
})

Session.setDefault('address', false)

if (web3.eth.accounts.length > 0) {
  Session.set('address', web3.eth.defaultAccount)
}
