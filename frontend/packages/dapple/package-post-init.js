// console.log('package-post-init start')
Dapple['init'] = function (env) {
  if (env === 'test' || env === 'morden') {
    Dapple.env = 'morden'
    Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments['morden'])
    Dapple['makerjs'] = new Dapple.Maker(web3, 'morden')
  } else if (env === 'live' || env === 'main') {
    Dapple.env = 'live'
    Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments['live'])
    Dapple['makerjs'] = new Dapple.Maker(web3, 'live')
  } else if (env === 'private' || env === 'default') {
    Dapple['maker-otc'].class(web3, Dapple['maker-otc'].environments['default'])
  }
  if (env !== false) {
    // Check if contract exists on new environment
    var code = web3.eth.getCode(Dapple['maker-otc'].objects.otc.address, function (error, code) {
      Session.set('contractExists', !error && typeof code === 'string' && code !== '' && code !== '0x')
    })
  }
}

var tokens = {
  'morden': {
    'ETH': '0xfbc7f6b58daa9f99816b6cc77d2a7f4b327fa7bc',
    'DAI': '0xa6581e37bb19afddd5c11f1d4e5fb16b359eb9fc',
    'MKR': '0xffb1c99b389ba527a9194b1606b3565a07da3eef',
    'DGD': '0x3c6f5633b30aa3817fa50b17e5bd30fb49bddd95'
  },
  'live': {
    'ETH': '0xd654bdd32fc99471455e86c2e7f7d7b6437e9179',
    'DAI': '0x0000000000000000000000000000000000000000',
    'MKR': '0xc66ea802717bfb9833400264dd12c2bceaa34a6d',
    'DGD': '0xe0b7927c4af23765cb51314a0e0521a9645f0e2a'
  }
}

Dapple.getTokens = function () {
  return [ 'ETH', 'MKR', 'DAI', 'DGD' ]
}

Dapple.getTokenAddress = function (symbol) {
  return tokens[Dapple.env][symbol]
}

Dapple.getTokenByAddress = function (address) {
  return _.invert(tokens[Dapple.env])[address]
}

Dapple.getToken = function (symbol, callback) {
  if (!(Dapple.env in tokens)) {
    callback('Unknown environment', null)
    return
  }
  if (!(symbol in tokens[Dapple.env])) {
    callback('Unknown token "' + symbol + '"', null)
    return
  }
  var tokenClass = 'DSTokenFrontend'
  if (symbol === 'ETH') {
    tokenClass = 'DSEthToken';
  }
  var address = Dapple.getTokenAddress(symbol)
  var _this = Dapple['makerjs']
  try {
    _this.dappsys.classes[tokenClass].at(address, function (error, token) {
      if (!error) {
        token.abi = _this.dappsys.classes[tokenClass].abi;
        callback(false, token)
      } else {
        callback(error, token)
      }
    })
  } catch (e) {
    callback(e, null)
  }
}

console.log('DAPPLE', Dapple)
// console.log('package-post-init done')
