// Shared Solana/crypto utilities — single source of truth for Base58, fetch helpers
const B58_ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

export function encodeBase58(bytes) {
  const digits = [0];
  for (let i = 0; i < bytes.length; i++) {
    let carry = bytes[i];
    for (let j = 0; j < digits.length; j++) {
      carry += digits[j] << 8;
      digits[j] = carry % 58;
      carry = (carry / 58) | 0;
    }
    while (carry) { digits.push(carry % 58); carry = (carry / 58) | 0; }
  }
  let str = '';
  for (let i = 0; i < bytes.length && bytes[i] === 0; i++) str += '1';
  for (let i = digits.length - 1; i >= 0; i--) str += B58_ALPHABET[digits[i]];
  return str;
}

export function decodeBase58(str) {
  const bytes = [];
  for (let i = 0; i < str.length; i++) {
    const idx = B58_ALPHABET.indexOf(str[i]);
    if (idx < 0) throw new Error('Invalid base58 character');
    let carry = idx;
    for (let j = 0; j < bytes.length; j++) {
      carry += bytes[j] * 58;
      bytes[j] = carry & 0xff;
      carry >>= 8;
    }
    while (carry) { bytes.push(carry & 0xff); carry >>= 8; }
  }
  for (let i = 0; i < str.length && str[i] === '1'; i++) bytes.push(0);
  return new Uint8Array(bytes.reverse());
}

// Deduplication-safe fetch — prevents concurrent requests for the same key
const _lockedKeys = {};
export function lockedFetch(key, url, opts) {
  if (_lockedKeys[key]) return Promise.resolve(null);
  _lockedKeys[key] = true;
  return fetch(url, opts).finally(function() { delete _lockedKeys[key]; });
}

// Balance display refresh
export function refreshBalance() {
  return lockedFetch('balance', '/admin/usdc_balance', {
    headers: { 'Accept': 'application/json' }, cache: 'no-store'
  })
    .then(function(r) { return r && r.json(); })
    .then(function(data) {
      if (!data) return;
      var formatted = '$' + Math.floor(parseFloat(data.balance));
      document.querySelectorAll('[data-balance-display]').forEach(function(el) {
        el.textContent = formatted;
      });
    })
    .catch(function() {});
}

export function refreshBalanceDelayed(ms) {
  var delay = ms || 10000;
  var btns = document.querySelectorAll('[data-balance-refresh]');
  btns.forEach(function(btn) {
    var svg = btn.querySelector('svg');
    if (svg) svg.classList.add('animate-spin');
  });
  setTimeout(function() {
    refreshBalance().finally(function() {
      btns.forEach(function(btn) {
        var svg = btn.querySelector('svg');
        if (svg) svg.classList.remove('animate-spin');
      });
    });
  }, delay);
}

// Confetti color palette — shared across solana modal & seeds bar
export const CONFETTI_COLORS = ['#4BAF50', '#8E82FE', '#06D6A0', '#FF7C47', '#FFD700', '#00BFFF', '#FF6B9D', '#C084FC'];

// Attach to window for backward compatibility with inline scripts/onclick handlers
window.lockedFetch = lockedFetch;
window.refreshBalance = refreshBalance;
window.refreshBalanceDelayed = refreshBalanceDelayed;
window.encodeBase58 = encodeBase58;
window.decodeBase58 = decodeBase58;
window.CONFETTI_COLORS = CONFETTI_COLORS;
