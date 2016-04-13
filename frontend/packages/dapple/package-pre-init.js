// console.log('package-pre-init start')
if (typeof web3 !== 'undefined') {
  web3 = new Web3(web3.currentProvider)
} else {
  web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"))
}

// TODO select address
if (web3.isConnected() && typeof web3.eth.defaultAccount === 'undefined' && typeof web3.eth.accounts !== 'undefined' && web3.eth.accounts.length > 0) {
  web3.eth.defaultAccount = web3.eth.accounts[0]
}
// console.log('package-pre-init done')
