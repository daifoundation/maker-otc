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
  var open = Transactions.find().fetch()

  // Sync all open transactions non-blocking and asynchronously
  var syncTransaction = function (index) {
    if (index >= 0 && index < open.length) {
      var document = open[index]
      web3.eth.getTransactionReceipt(document.tx, function (error, result) {
        if (!error && result != null) {
          Transactions.remove({ tx: document.tx })
        }
        // Sync next transaction
        syncTransaction(index + 1)
      })
    }
  }
  syncTransaction(0)
}
