console.log('package-pre-init start')
dapple = {}
web3 = new Web3()

// TODO mist integration
var providerUrl = 'http://localhost:8545'

// connect to local node
web3.setProvider(new web3.providers.HttpProvider(providerUrl))
console.log('package-pre-init done')
