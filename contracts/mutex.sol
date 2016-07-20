contract MutexUser {
    bool private lock;
    modifier exclusive {
        if (lock) throw;
        lock = true;
        _
        lock = false;
    }
}
