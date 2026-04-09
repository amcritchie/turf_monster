// Phantom deep link protocol for mobile browsers
// Flow: generate keypair → fetch nonce → save state → redirect to Phantom app

function startPhantomDeepLink(linkMode) {
  var cluster = document.body.dataset.solanaCluster || 'devnet';
  var callbackUrl = window.location.origin + '/auth/phantom/callback';

  // Generate x25519 keypair for NaCl box encryption
  var dappKeyPair = nacl.box.keyPair();

  // Fetch nonce from server, then redirect to Phantom connect
  fetch('/auth/solana/nonce')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      // Save state to localStorage (persists across redirects)
      localStorage.setItem('phantom_dl_secret', encodeBase58(dappKeyPair.secretKey));
      localStorage.setItem('phantom_dl_pubkey', encodeBase58(dappKeyPair.publicKey));
      localStorage.setItem('phantom_dl_nonce', data.nonce);
      localStorage.setItem('phantom_dl_nonce_at', Date.now().toString());
      localStorage.setItem('phantom_dl_step', 'connect');
      localStorage.setItem('phantom_dl_link_mode', linkMode ? 'true' : 'false');
      localStorage.setItem('phantom_dl_cluster', cluster);

      // Build Phantom connect deep link
      var params = new URLSearchParams({
        app_url: window.location.origin,
        dapp_encryption_public_key: encodeBase58(dappKeyPair.publicKey),
        redirect_link: callbackUrl,
        cluster: cluster
      });

      window.location.href = 'https://phantom.app/ul/v1/connect?' + params.toString();
    })
    .catch(function(err) {
      alert('Failed to start Phantom connection: ' + err.message);
    });
}

window.startPhantomDeepLink = startPhantomDeepLink;
