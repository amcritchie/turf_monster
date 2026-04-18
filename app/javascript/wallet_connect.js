// Wallet connect component — used by x-data="solanaWalletConnect(...)"
// Extracted from application.html.erb inline script

window.solanaWalletConnect = function(linkMode) {
  return {
    connecting: false,
    error: null,
    statusText: 'Connect Wallet',
    walletAvailable: window.walletProvider.isAvailable(),
    isMobile: window.walletProvider.isMobile(),
    async connect() {
      this.connecting = true;
      this.error = null;
      try {
        var provider = window.walletProvider.detect();
        if (!provider) throw new Error('No wallet available');
        this.statusText = 'Connecting...';
        var resp = await provider.connect();
        var pubkeyB58 = resp.publicKey.toBase58();
        this.statusText = 'Fetching nonce...';
        var data = await (await fetch('/auth/solana/nonce')).json();
        var domain = window.location.host;
        var message = domain + ' wants you to sign in with your Solana account:\n' + pubkeyB58 + '\n\nSign in to Turf Monster\n\nNonce: ' + data.nonce;
        this.statusText = 'Sign message in wallet...';
        var signed = await provider.signMessage(new TextEncoder().encode(message), 'utf8');
        var signatureB58 = encodeBase58(signed.signature);
        this.statusText = 'Verifying...';
        var verifyUrl = linkMode ? '/account/link_solana' : '/auth/solana/verify';
        var result = await (await fetch(verifyUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '' },
          body: JSON.stringify({ message: message, signature: signatureB58, pubkey: pubkeyB58 })
        })).json();
        if (result.success) {
          if (result.new_user) localStorage.setItem('show_profile_modal', 'true');
          window.location.href = result.redirect || '/';
        } else {
          this.error = result.error || 'Verification failed';
          this.statusText = 'Connect Wallet';
          this.connecting = false;
        }
      } catch (e) {
        this.error = (e.code === 4001) ? 'Signature rejected' : (e.message || 'Connection failed');
        this.statusText = 'Connect Wallet';
        this.connecting = false;
      }
    }
  };
};

// Confetti helper
window.fireSuccessConfetti = function() {
  if (typeof confetti === 'undefined') return;
  var colors = window.CONFETTI_COLORS || ['#4BAF50', '#8E82FE', '#06D6A0', '#FF7C47', '#FFD700', '#00BFFF', '#FF6B9D', '#C084FC'];
  confetti({ particleCount: 150, spread: 100, origin: { x: 0.5, y: 0.5 }, colors: colors, zIndex: 99, startVelocity: 45, gravity: 0.8, ticks: 300, scalar: 1.2 });
  setTimeout(function() { confetti({ particleCount: 80, angle: 60, spread: 60, origin: { x: 0, y: 0.6 }, colors: colors, zIndex: 99, startVelocity: 55, gravity: 1, ticks: 250 }); }, 150);
  setTimeout(function() { confetti({ particleCount: 80, angle: 120, spread: 60, origin: { x: 1, y: 0.6 }, colors: colors, zIndex: 99, startVelocity: 55, gravity: 1, ticks: 250 }); }, 150);
  setTimeout(function() { confetti({ particleCount: 100, spread: 160, origin: { x: 0.5, y: 0.3 }, colors: colors, zIndex: 99, startVelocity: 30, gravity: 1.2, ticks: 200, scalar: 0.8 }); }, 400);
};
