// console.log('package-post-init start')
Dapple['init'] = function (env) {
  if (env === 'test' || env === 'morden') {
    Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments['morden'])
    Dapple['makerjs'] = new Dapple.Maker(web3, 'morden')
  } else if (env === 'live' || env === 'main') {
    Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments['live'])
    Dapple['makerjs'] = new Dapple.Maker(web3, 'live')
  } else if (env === 'private' || env === 'default') {
    Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments['default'])
  }
  if (_.contains(web3.eth.accounts, localStorage.getItem('address'))) {
    web3.eth.defaultAccount = localStorage.getItem('address')
  } else if (!_.contains(web3.eth.accounts, web3.eth.defaultAccount)) {
    if (web3.eth.accounts.length > 0) {
      web3.eth.defaultAccount = web3.eth.accounts[0]
    } else {
      web3.eth.defaultAccount = undefined
    }
  }
  if (env !== false) {
    var code = web3.eth.getCode(Dapple['maker-otc'].objects.otc.address, function (error, code) {
      Session.set('contractExists', !error && typeof code === 'string' && code !== '' && code !== '0x')
    })
  }
}

console.log('DAPPLE', Dapple)
// console.log('package-post-init done')
