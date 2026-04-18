// Selection board — matchup picking and entry confirmation
// Extracted from contests/_turf_totals_board.html.erb
// Config is read from <script type="application/json" id="board-config"> in the view

// Auto-shrink long team names
function shrinkTeamNames() {
  document.querySelectorAll('.team-name').forEach(function(el) {
    el.style.fontSize = '';
    if (el.scrollWidth > el.clientWidth) {
      el.style.fontSize = '0.7rem';
    }
  });
}
window.shrinkTeamNames = shrinkTeamNames;

document.addEventListener('turbo:load', shrinkTeamNames);
document.addEventListener('alpine:initialized', function() { setTimeout(shrinkTeamNames, 100); });

window.selectionBoard = function() {
  var configEl = document.getElementById('board-config');
  if (!configEl) { console.error('board-config element not found'); return {}; }
  var cfg = JSON.parse(configEl.textContent);

  var matchupData = cfg.matchupData;

  return {
    selections: cfg.cartSelections,
    selectionOrder: cfg.cartSelectionOrder,
    cartOpen: Object.keys(cfg.cartSelections).length > 0,
    blurDismissed: false,
    shakeKey: 0,
    submitting: false,
    error: null,
    errorTimer: null,
    contestId: cfg.contestSlug,
    csrfToken: document.querySelector('meta[name="csrf-token"]')?.content,
    loggedIn: cfg.loggedIn,
    entryFeeCents: cfg.entryFeeCents,
    userWallet: cfg.userWallet,
    contestOnchain: cfg.contestOnchain,
    contestName: cfg.contestName,
    picksRequired: cfg.picksRequired,
    sortMode: 'game',
    sortDir: 'asc',
    filterText: '',
    pickUrgent: false,
    redirectModal: null,
    redirectCountdown: 0,
    redirectInterval: null,

    toggleSort(mode) {
      if (mode === 'turfScore' && this.sortMode === 'turfScore') {
        this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
      } else {
        this.sortMode = mode;
        this.sortDir = 'asc';
      }
    },

    matchesFilter: function() {
      var names = Array.from(arguments);
      if (!this.filterText) return true;
      var q = this.filterText.toLowerCase();
      return names.some(function(n) { return n.toLowerCase().includes(q); });
    },

    get selectionCount() {
      return Object.keys(this.selections).length;
    },

    get selectionSlots() {
      return this.selectionOrder.filter(id => this.selections[id]).map(matchupId => ({
        matchupId: matchupId,
        name: matchupData[matchupId]?.name || matchupId,
        emoji: matchupData[matchupId]?.emoji || '',
        opName: matchupData[matchupId]?.opName || '',
        turfScore: matchupData[matchupId]?.turfScore || ''
      }));
    },

    toggleSelection(matchupId) {
      if (matchupData[matchupId]?.locked) return;

      var oldSelections = Object.assign({}, this.selections);
      var oldOrder = this.selectionOrder.slice();

      if (this.selections[matchupId]) {
        var wasFull = this.selectionCount === this.picksRequired;
        var newSelections = Object.assign({}, this.selections);
        delete newSelections[matchupId];
        this.selections = newSelections;
        this.selectionOrder = this.selectionOrder.filter(function(id) { return id !== matchupId; });
        this.blurDismissed = false;
        if (wasFull) this.pickUrgent = true;
        if (this.selectionCount === 0) this.cartOpen = false;
      } else if (this.selectionCount < this.picksRequired) {
        this.selections = Object.assign({}, this.selections, { [matchupId]: true });
        this.selectionOrder = this.selectionOrder.concat([matchupId]);
        if (this.selectionCount === this.picksRequired) this.pickUrgent = false;
        if (!this.cartOpen) this.cartOpen = true;
        this.triggerShake(matchupId);
      } else {
        // Replace oldest
        var removedId = this.selectionOrder[0];
        var newSel = Object.assign({}, this.selections);
        delete newSel[removedId];
        newSel[matchupId] = true;
        this.selections = newSel;
        this.selectionOrder = this.selectionOrder.slice(1).concat([matchupId]);
        this.blurDismissed = false;
        this.triggerShake(matchupId);
      }

      if (!this.loggedIn) return;

      var self = this;
      fetch('/contests/' + this.contestId + '/toggle_selection', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ matchup_id: matchupId })
      })
      .then(function(resp) { return resp.json().then(function(data) { return { ok: resp.ok, data: data }; }); })
      .then(function(result) {
        if (!result.ok) {
          self.selections = oldSelections;
          self.selectionOrder = oldOrder;
          self.showError(result.data.error || 'Failed to save selection');
        }
      })
      .catch(function() {
        self.selections = oldSelections;
        self.selectionOrder = oldOrder;
        self.showError('Network error. Selection not saved.');
      });
    },

    removeSelection(matchupId) {
      this.toggleSelection(matchupId);
    },

    triggerShake(matchupId) {
      this.shakeKey++;
      this._shakeMatchupId = matchupId;
      var self = this;
      setTimeout(function() { self._shakeMatchupId = null; }, 400);
    },

    isShaking(matchupId) {
      return this._shakeMatchupId === matchupId;
    },

    showRedirectModal(title, message, icon, url, seconds, cta) {
      this.redirectModal = { title: title, message: message, icon: icon, url: url, seconds: seconds, cta: cta };
      this.redirectCountdown = seconds;
      if (this.redirectInterval) clearInterval(this.redirectInterval);
      var self = this;
      this.redirectInterval = setInterval(function() {
        self.redirectCountdown--;
        if (self.redirectCountdown <= 0) {
          clearInterval(self.redirectInterval);
          self.redirectInterval = null;
          window.location.href = url;
        }
      }, 1000);
    },

    goNow() {
      if (this.redirectInterval) clearInterval(this.redirectInterval);
      this.redirectInterval = null;
      if (this.redirectModal) window.location.href = this.redirectModal.url;
    },

    setHoldSuccess() {
      document.querySelectorAll('.hold-btn').forEach(function(el) {
        el.classList.remove('process');
        el.classList.add('success');
      });
    },

    setHoldError() {
      document.querySelectorAll('.hold-btn').forEach(function(el) {
        el.classList.remove('success', 'process');
        el.classList.add('error');
      });
    },

    async runHoldValidations() {
      // 1. Fresh geo check (server-side re-detection)
      try {
        var res = await fetch('/geo/check', { headers: { 'Accept': 'application/json' } });
        var geo = await res.json();
        if (geo.blocked) {
          this.setHoldError();
          this.showRedirectModal('Location Restricted', 'Contest entries are not available in ' + (geo.state || 'your state') + '.', '\uD83D\uDCCD', '/', 5, 'OK');
          return false;
        }
      } catch(e) {
        // Geo check failed — allow through (don't block on network error)
      }

      // 2. Login check
      if (!this.loggedIn) {
        this.setHoldError();
        this.showRedirectModal('Log In Required', 'Create an account or log in to enter the contest.', '\uD83D\uDD12', '/login', 5);
        return false;
      }

      return true;
    },

    async confirmEntry() {
      if (!this.loggedIn) {
        this.setHoldError();
        this.showRedirectModal('Log In Required', 'Create an account or log in to enter the contest.', '\uD83D\uDD12', '/login', 5);
        return;
      }

      // Require both: contest is onchain, browser wallet available, AND user has a web3 wallet linked
      var directOnchain = this.contestOnchain && window.walletProvider.isAvailable() && cfg.phantomWallet;

      this.setHoldSuccess();
      this.submitting = true;

      var seedsPerLevel = cfg.seedsPerLevel;
      var updateLevelPath = cfg.updateLevelPath;

      try {
        if (directOnchain) {
          // === Direct onchain path: wallet signs USDC transfer ===
          var provider = window.walletProvider.detect();
          Alpine.store('solanaModal').show('Sign Entry', 'Approve in your wallet...');

          var resp = await provider.connect();
          var pubkeyB58 = resp.publicKey.toBase58();

          // Verify the connected wallet matches the logged-in user
          if (this.userWallet && pubkeyB58 !== this.userWallet) {
            throw new Error('Wrong wallet connected. Switch to ' + this.userWallet.substring(0, 8) + '..., or reconnect your wallet on the Account page.');
          }

          // 1. Get nonce + sign identity message
          var nonceResp = await fetch('/auth/solana/nonce');
          var nonceData = await nonceResp.json();
          var nonce = nonceData.nonce;

          var domain = window.location.host;
          var message = domain + ' wants you to sign in with your Solana account:\n' + pubkeyB58 + '\n\nEnter contest: ' + this.contestName + '\n\nNonce: ' + nonce;
          var encoded = new TextEncoder().encode(message);
          var signed = await provider.signMessage(encoded, 'utf8');
          var signatureB58 = encodeBase58(signed.signature);

          // 2. POST /prepare_entry — server builds & partial-signs tx
          Alpine.store('solanaModal').show('Preparing Transaction', 'Building onchain transaction...');
          var prepareResp = await fetch('/contests/' + this.contestId + '/prepare_entry', {
            method: 'POST',
            headers: { 'X-CSRF-Token': this.csrfToken, 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify({ message: message, signature: signatureB58, pubkey: pubkeyB58 })
          });
          var prepareData = await prepareResp.json();
          if (!prepareData.success) throw new Error(prepareData.error || 'Failed to prepare entry');

          // 3. Deserialize, have wallet sign, and submit
          Alpine.store('solanaModal').show('Sign Transaction', 'Approve the USDC transfer in your wallet...');
          var txBytes = Uint8Array.from(atob(prepareData.serialized_tx), function(c) { return c.charCodeAt(0); });
          var tx = solanaWeb3.Transaction.from(txBytes);
          var signedTx = await provider.signTransaction(tx);

          Alpine.store('solanaModal').show('Confirming Onchain', 'Submitting transaction to Solana...');
          var connection = new solanaWeb3.Connection(solanaWeb3.clusterApiUrl('devnet'), 'confirmed');
          var txSig = await connection.sendRawTransaction(signedTx.serialize(), { skipPreflight: true, maxRetries: 3 });

          Alpine.store('solanaModal').show('Confirming Onchain', 'Waiting for Solana confirmation...');
          await connection.confirmTransaction(txSig, 'confirmed');

          // 4. POST /confirm_onchain_entry — confirm in DB
          Alpine.store('solanaModal').show('Confirming Entry', 'Saving entry...');
          var confirmResp = await fetch('/contests/' + this.contestId + '/confirm_onchain_entry', {
            method: 'POST',
            headers: { 'X-CSRF-Token': this.csrfToken, 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify({ tx_signature: txSig, entry_id: prepareData.entry_id, entry_pda: prepareData.entry_pda })
          });
          var confirmData = await confirmResp.json();
          if (!confirmData.success) throw new Error(confirmData.error || 'Failed to confirm entry');

          if (confirmData.seeds_earned) {
            var m = Alpine.store('solanaModal');
            m.seedsEarned = confirmData.seeds_earned;
            m.seedsTotal = confirmData.seeds_total;
            m.seedsLevel = confirmData.seeds_level;

            // Cache seeds data for navbar progress bar
            localStorage.setItem('seedsNavbar', JSON.stringify({
              seeds_total: confirmData.seeds_total,
              level: confirmData.seeds_level,
              toward_next: confirmData.seeds_total % seedsPerLevel,
              progress: Math.round((confirmData.seeds_total % seedsPerLevel) / seedsPerLevel * 100)
            }));

            // Detect level-up: did seeds cross a boundary?
            var oldSeeds = confirmData.seeds_total - confirmData.seeds_earned;
            var oldLevel = Math.floor(oldSeeds / seedsPerLevel) + 1;
            var newLevel = Math.floor(confirmData.seeds_total / seedsPerLevel) + 1;
            var newPct = Math.round((confirmData.seeds_total % seedsPerLevel) / seedsPerLevel * 100);
            if (newLevel > oldLevel) {
              var oldPct = Math.round((oldSeeds % seedsPerLevel) / seedsPerLevel * 100);
              localStorage.setItem('seedsLevelUp', JSON.stringify({
                oldLevel: oldLevel,
                newLevel: newLevel,
                oldPct: oldPct,
                oldToward: oldSeeds % seedsPerLevel
              }));
              window.dispatchEvent(new CustomEvent('navbar-seeds-update', { detail: { levelUp: true, oldPct: oldPct, newLevel: newLevel, progress: newPct } }));
              fetch(updateLevelPath, {
                method: 'PATCH',
                headers: { 'X-CSRF-Token': this.csrfToken, 'Content-Type': 'application/json' },
                body: JSON.stringify({ seeds_total: confirmData.seeds_total })
              }).catch(function(err) { console.warn('Level update failed:', err); });
            } else {
              window.dispatchEvent(new CustomEvent('navbar-seeds-update', { detail: { levelUp: false, level: newLevel, progress: newPct } }));
            }
          }
          Alpine.store('solanaModal').success(txSig, 'Entry submitted onchain');
          refreshBalanceDelayed();
          Alpine.store('solanaModal').onClose = function() { window.location.href = confirmData.redirect || '/'; };

        } else {
          // === Standard path: managed wallet or non-onchain contest ===
          Alpine.store('solanaModal').show('Submitting Entry', 'Processing your entry...');

          var response = await fetch('/contests/' + this.contestId + '/enter', {
            method: 'POST',
            headers: { 'X-CSRF-Token': this.csrfToken, 'Accept': 'application/json' }
          });

          var data = await response.json();

          if (data.success) {
            if (data.tx_signature) {
              Alpine.store('solanaModal').success(data.tx_signature, 'Entry submitted onchain');
              refreshBalanceDelayed();
              Alpine.store('solanaModal').onClose = function() { window.location.href = data.redirect || '/'; };
            } else {
              if (Alpine.store('solanaModal').visible) Alpine.store('solanaModal').close();
              window.location.href = data.redirect || '/';
            }
          } else {
            if (Alpine.store('solanaModal').visible) {
              Alpine.store('solanaModal').error(data.error || 'Something went wrong');
            } else {
              this.showError(data.error || 'Something went wrong');
            }
            this.submitting = false;
          }
        }
      } catch (err) {
        var msg = parseSolanaError(err.message || 'Failed to sign entry');
        if (Alpine.store('solanaModal').visible) {
          Alpine.store('solanaModal').error(msg);
        } else {
          this.showError(msg);
        }
        this.submitting = false;
      }
    },

    showError(message) {
      this.error = message;
      if (this.errorTimer) clearTimeout(this.errorTimer);
      var self = this;
      this.errorTimer = setTimeout(function() { self.dismissError(); }, 5000);
    },

    async clearSelections() {
      this.selections = {};
      this.selectionOrder = [];
      this.cartOpen = false;
      this.blurDismissed = false;
      this.pickUrgent = false;

      if (!this.loggedIn) return;

      try {
        await fetch('/contests/' + this.contestId + '/clear_picks', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': this.csrfToken,
            'Accept': 'application/json'
          }
        });
      } catch (err) {
        // silent
      }
    },

    dismissError() {
      this.error = null;
      if (this.errorTimer) {
        clearTimeout(this.errorTimer);
        this.errorTimer = null;
      }
    }
  };
};
