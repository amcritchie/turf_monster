// Solana Alpine stores and components
// Extracted from shared/_solana_modal, _phantom_watcher, _solana_wallet_connect

// --- Solana Modal Store ---
// Global modal for onchain operation feedback (processing/success/error)
document.addEventListener('alpine:init', function() {
  var cluster = document.body.dataset.solanaCluster || 'devnet';
  var clusterParam = cluster === 'devnet' ? '?cluster=devnet' : '';

  Alpine.store('solanaModal', {
    visible: false,
    state: 'processing', // processing | success | error
    title: '',
    message: '',
    txSignature: null,
    errorMessage: null,
    onClose: null,
    countdown: 0,
    _countdownTimer: null,
    seedsEarned: 0,
    seedsTotal: 0,
    seedsLevel: 0,

    show: function(title, message) {
      this.visible = true;
      this.state = 'processing';
      this.title = title;
      this.message = message;
      this.txSignature = null;
      this.errorMessage = null;
      this.onClose = null;
      this.countdown = 0;
      this.seedsEarned = 0;
      this.seedsTotal = 0;
      this.seedsLevel = 0;
      this._clearCountdown();
    },

    success: function(tx, message, autoCloseSeconds) {
      this.state = 'success';
      this.txSignature = tx;
      if (message) this.message = message;
      var seconds = autoCloseSeconds || 5;
      this.countdown = seconds;
      this._clearCountdown();
      var self = this;
      this._countdownTimer = setInterval(function() {
        self.countdown--;
        if (self.countdown <= 0) {
          self._clearCountdown();
          self.close();
        }
      }, 1000);
    },

    _clearCountdown: function() {
      if (this._countdownTimer) {
        clearInterval(this._countdownTimer);
        this._countdownTimer = null;
      }
    },

    error: function(msg, title) {
      this.state = 'error';
      this.errorMessage = msg;
      if (title) this.title = title;
    },

    close: function() {
      this._clearCountdown();
      var cb = this.onClose;
      this.visible = false;
      this.state = 'processing';
      this.title = '';
      this.message = '';
      this.txSignature = null;
      this.errorMessage = null;
      this.countdown = 0;
      this.seedsEarned = 0;
      this.seedsTotal = 0;
      this.seedsLevel = 0;
      if (cb) cb();
      this.onClose = null;
    },

    get explorerUrl() {
      if (!this.txSignature) return null;
      return 'https://explorer.solana.com/tx/' + this.txSignature + clusterParam;
    }
  });

  // --- Wallet Watcher Store ---
  // Detects wallet switches and re-authenticates silently
  Alpine.store('wallet', {
    address: null,
    watching: false,

    init: function() {
      var provider = walletProvider.detect();
      var serverAddr = this._serverAddress();
      if (!provider || !serverAddr) return;

      var self = this;

      // Silent probe — detect current wallet without popup
      provider.connect({ onlyIfTrusted: true })
        .then(function(resp) {
          self.address = resp.publicKey.toBase58();
          if (self.address !== serverAddr) {
            self._reauth(self.address);
          }
        })
        .catch(function() {}); // Not previously approved — no action

      // Listen for wallet switches (Phantom-specific, no-op for keypair)
      provider.on('accountChanged', function(publicKey) {
        if (publicKey) {
          var newAddr = publicKey.toBase58();
          self.address = newAddr;
          if (newAddr !== self._serverAddress()) {
            self._reauth(newAddr);
          }
        } else {
          window.location.href = '/logout';
        }
      });

      this.watching = true;
    },

    _serverAddress: function() { return document.body.dataset.walletAddress || ''; },

    _reauth: function(pubkeyB58) {
      var provider = walletProvider.detect();
      if (!provider) return;
      fetch('/auth/solana/nonce')
        .then(function(r) { return r.json(); })
        .then(function(data) {
          var nonce = data.nonce;
          var domain = window.location.host;
          var message = domain + ' wants you to sign in with your Solana account:\n' + pubkeyB58 + '\n\nSign in to Turf Monster\n\nNonce: ' + nonce;
          var encoded = new TextEncoder().encode(message);
          return provider.signMessage(encoded, 'utf8').then(function(signed) {
            var signatureB58 = encodeBase58(signed.signature);
            var csrf = document.querySelector('meta[name="csrf-token"]').content;
            return fetch('/auth/solana/verify', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
              body: JSON.stringify({ message: message, signature: signatureB58, pubkey: pubkeyB58 })
            });
          });
        })
        .then(function(r) { return r.json(); })
        .then(function(result) {
          if (result.success) {
            if (result.new_user) {
              localStorage.setItem('show_profile_modal', 'true');
            }
            window.location.reload();
          }
        })
        .catch(function() {});
    }
  });
});

// --- Confetti Helper ---
window.fireSuccessConfetti = function() {
  if (typeof confetti === 'undefined') return;
  var colors = window.CONFETTI_COLORS || ['#4BAF50', '#8E82FE', '#06D6A0', '#FF7C47', '#FFD700', '#00BFFF', '#FF6B9D', '#C084FC'];
  confetti({ particleCount: 150, spread: 100, origin: { x: 0.5, y: 0.5 }, colors: colors, zIndex: 99, startVelocity: 45, gravity: 0.8, ticks: 300, scalar: 1.2 });
  setTimeout(function() {
    confetti({ particleCount: 80, angle: 60, spread: 60, origin: { x: 0, y: 0.6 }, colors: colors, zIndex: 99, startVelocity: 55, gravity: 1, ticks: 250 });
  }, 150);
  setTimeout(function() {
    confetti({ particleCount: 80, angle: 120, spread: 60, origin: { x: 1, y: 0.6 }, colors: colors, zIndex: 99, startVelocity: 55, gravity: 1, ticks: 250 });
  }, 150);
  setTimeout(function() {
    confetti({ particleCount: 100, spread: 160, origin: { x: 0.5, y: 0.3 }, colors: colors, zIndex: 99, startVelocity: 30, gravity: 1.2, ticks: 200, scalar: 0.8 });
  }, 400);
};

// --- Wallet Connect Component ---
window.solanaWalletConnect = function(linkMode) {
  return {
    connecting: false,
    error: null,
    statusText: 'Connect Wallet',
    walletAvailable: walletProvider.isAvailable(),
    isMobile: walletProvider.isMobile(),

    async connect() {
      this.connecting = true;
      this.error = null;

      try {
        var provider = walletProvider.detect();
        if (!provider) throw new Error('No wallet available');

        this.statusText = 'Connecting...';
        var resp = await provider.connect();
        var publicKey = resp.publicKey;
        var pubkeyB58 = publicKey.toBase58();

        this.statusText = 'Fetching nonce...';
        var nonceResp = await fetch('/auth/solana/nonce');
        var data = await nonceResp.json();
        var nonce = data.nonce;

        var domain = window.location.host;
        var message = domain + ' wants you to sign in with your Solana account:\n' + pubkeyB58 + '\n\nSign in to Turf Monster\n\nNonce: ' + nonce;

        this.statusText = 'Sign message in wallet...';
        var encodedMessage = new TextEncoder().encode(message);
        var signedMessage = await provider.signMessage(encodedMessage, 'utf8');
        var signatureB58 = encodeBase58(signedMessage.signature);

        this.statusText = 'Verifying...';
        var verifyUrl = linkMode ? '/account/link_solana' : '/auth/solana/verify';
        var verifyResp = await fetch(verifyUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
          },
          body: JSON.stringify({ message: message, signature: signatureB58, pubkey: pubkeyB58 })
        });

        var result = await verifyResp.json();

        if (result.success) {
          if (result.new_user) {
            localStorage.setItem('show_profile_modal', 'true');
          }
          window.location.href = result.redirect || '/';
        } else {
          this.error = result.error || 'Verification failed';
          this.statusText = 'Connect Wallet';
          this.connecting = false;
        }
      } catch (e) {
        if (e.code === 4001) {
          this.error = 'Signature rejected';
        } else {
          this.error = e.message || 'Connection failed';
        }
        this.statusText = 'Connect Wallet';
        this.connecting = false;
      }
    }
  };
};
