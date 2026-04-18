// Wallet Provider Abstraction
// Abstracts wallet operations behind a common interface so Phantom, keypair-based
// bots, and future providers all share the same API surface.

// --- PhantomProvider ---
// Wraps window.phantom.solana. Delegates all calls to the browser extension.
var PhantomProvider = {
  name: 'phantom',

  isAvailable: function() {
    return !!(window.phantom && window.phantom.solana && window.phantom.solana.isPhantom);
  },

  _provider: function() {
    return window.phantom && window.phantom.solana;
  },

  connect: function(opts) {
    var p = this._provider();
    if (!p) return Promise.reject(new Error('Phantom not available'));
    return p.connect(opts);
  },

  signMessage: function(encoded, encoding) {
    var p = this._provider();
    if (!p) return Promise.reject(new Error('Phantom not available'));
    return p.signMessage(encoded, encoding);
  },

  signTransaction: function(tx) {
    var p = this._provider();
    if (!p) return Promise.reject(new Error('Phantom not available'));
    return p.signTransaction(tx);
  },

  on: function(event, callback) {
    var p = this._provider();
    if (p && p.on) p.on(event, callback);
  },

  disconnect: function() {
    var p = this._provider();
    if (!p) return Promise.resolve();
    return p.disconnect();
  },

  get publicKey() {
    var p = this._provider();
    return p ? p.publicKey : null;
  }
};


// --- KeypairProvider ---
// Loads an Ed25519 keypair from window.__WALLET_KEYPAIR_SECRET (Uint8Array of 64-byte secret key).
// Uses tweetnacl for signing. Designed for Playwright tests and bot agents.
var KeypairProvider = {
  name: 'keypair',
  _keypair: null,
  _publicKeyObj: null,

  isAvailable: function() {
    return !!(window.__WALLET_KEYPAIR_SECRET);
  },

  _ensureKeypair: function() {
    if (this._keypair) return Promise.resolve(this._keypair);
    var secret = window.__WALLET_KEYPAIR_SECRET;
    if (!secret) return Promise.reject(new Error('No keypair secret set'));

    var self = this;

    // tweetnacl should already be loaded on the page (CDN in head)
    if (typeof nacl !== 'undefined' && nacl.sign) {
      // secret is the full 64-byte secretKey (seed + pubkey)
      self._keypair = { publicKey: secret.slice(32), secretKey: secret };
      self._publicKeyObj = self._makePublicKey(self._keypair.publicKey);
      return Promise.resolve(self._keypair);
    }

    // Lazy-load tweetnacl if not present
    return new Promise(function(resolve, reject) {
      var s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/tweetnacl@1.0.3/nacl-fast.min.js';
      s.onload = function() {
        self._keypair = { publicKey: secret.slice(32), secretKey: secret };
        self._publicKeyObj = self._makePublicKey(self._keypair.publicKey);
        resolve(self._keypair);
      };
      s.onerror = reject;
      (document.head || document.documentElement).appendChild(s);
    });
  },

  _makePublicKey: function(bytes) {
    return {
      toBytes: function() { return bytes; },
      toBase58: function() { return window.encodeBase58(bytes); },
      toString: function() { return window.encodeBase58(bytes); }
    };
  },

  connect: function() {
    var self = this;
    return this._ensureKeypair().then(function() {
      return { publicKey: self._publicKeyObj };
    });
  },

  signMessage: function(encoded) {
    return this._ensureKeypair().then(function(kp) {
      var signature = nacl.sign.detached(encoded, kp.secretKey);
      return { signature: signature };
    });
  },

  signTransaction: function(tx) {
    return this._ensureKeypair().then(function(kp) {
      // solanaWeb3 must be loaded on the page
      var solKp = solanaWeb3.Keypair.fromSecretKey(kp.secretKey);
      tx.partialSign(solKp);
      return tx;
    });
  },

  on: function() {
    // No-op — keypair provider doesn't emit events
  },

  disconnect: function() {
    this._keypair = null;
    this._publicKeyObj = null;
    return Promise.resolve();
  },

  get publicKey() {
    return this._publicKeyObj || null;
  }
};


// --- Registry ---
// window.walletProvider — detect best provider, get by name, check availability
var walletProvider = {
  // Returns the best available provider: KeypairProvider if configured, else PhantomProvider
  detect: function() {
    if (KeypairProvider.isAvailable()) return KeypairProvider;
    if (PhantomProvider.isAvailable()) return PhantomProvider;
    return null;
  },

  // Get a specific provider by name
  get: function(name) {
    if (name === 'phantom') return PhantomProvider;
    if (name === 'keypair') return KeypairProvider;
    return null;
  },

  // True if any provider is available
  isAvailable: function() {
    return KeypairProvider.isAvailable() || PhantomProvider.isAvailable();
  },

  // Check if mobile (no extension expected)
  isMobile: function() {
    return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) ||
           (navigator.maxTouchPoints > 1 && /Macintosh/.test(navigator.userAgent));
  }
};

window.walletProvider = walletProvider;
