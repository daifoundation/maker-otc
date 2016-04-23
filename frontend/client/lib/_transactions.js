this.Transactions = new Meteor.Collection(null)

Transactions.add = function (type, transaction_hash, object) {
  Transactions.insert({ type: type, tx: transaction_hash, object: object })
}

Transactions.findType = function (type) {
  return Transactions.find({ type: type }).map(function (value) {
    return value.object
  })
}

Transactions.observeRemoved = function (type, callback) {
  return Transactions.find({ type: type }).observe({ removed: callback })
}

Transactions.sync = function () {
  Transactions.find().forEach(function (document) {
    web3.eth.getTransactionReceipt(document.tx, function (error, result) {
      console.debug('transaction: ', document, error, result)
      if (!error && result != null) {
        Transactions.remove({ tx: document.tx })
      }
    })
  })
}
