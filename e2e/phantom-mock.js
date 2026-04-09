/**
 * Phantom wallet mock for Playwright E2E tests.
 *
 * Injects a fake `window.phantom.solana` provider that uses real Ed25519
 * signing via tweetnacl CDN — so the server's `verify_solana_signature!`
 * works unchanged.
 *
 * Usage:
 *   const { setupPhantomMock, MOCK_PUBKEY_B58 } = require('./phantom-mock');
 *   await setupPhantomMock(page);              // seed byte 1 = alex
 *   await setupPhantomMock(page, { seedByte: 2 }); // different wallet
 */

// Pre-computed from deterministic seed (last byte = 1)
const MOCK_PUBKEY_B58 = "6ASf5EcmmEHTgDJ4X4ZT5vT6iHVJBXPg5AN5YoTCpGWt";

/**
 * Inject Phantom mock into the page via addInitScript.
 * Runs before any page scripts — Alpine's walletAvailable check passes immediately.
 */
async function setupPhantomMock(page, { seedByte = 1 } = {}) {
  await page.addInitScript((seedByte) => {
    // --- Deterministic seed ---
    const seed = new Uint8Array(32);
    seed[31] = seedByte;

    // --- Base58 encoder (Bitcoin alphabet) ---
    const B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    function encodeBase58(bytes) {
      let n = BigInt(0);
      for (const b of bytes) n = n * 256n + BigInt(b);
      let r = "";
      while (n > 0n) {
        r = B58[Number(n % 58n)] + r;
        n = n / 58n;
      }
      for (const b of bytes) {
        if (b !== 0) break;
        r = "1" + r;
      }
      return r || "1";
    }

    // --- Lazy tweetnacl loader ---
    let _keypair = null;
    let _naclLoaded = false;

    function loadTweetnacl() {
      if (_naclLoaded) return Promise.resolve();
      if (typeof nacl !== "undefined" && nacl.sign) {
        _naclLoaded = true;
        return Promise.resolve();
      }
      return new Promise((resolve, reject) => {
        const s = document.createElement("script");
        s.src = "https://cdn.jsdelivr.net/npm/tweetnacl@1.0.3/nacl-fast.min.js";
        s.onload = () => {
          _naclLoaded = true;
          resolve();
        };
        s.onerror = reject;
        (document.head || document.documentElement).appendChild(s);
      });
    }

    async function getKeypair() {
      if (_keypair) return _keypair;
      await loadTweetnacl();
      _keypair = nacl.sign.keyPair.fromSeed(seed);
      return _keypair;
    }

    // --- Public key helper ---
    function makePublicKey(bytes) {
      return {
        toBytes: () => bytes,
        toBase58: () => encodeBase58(bytes),
        toString: () => encodeBase58(bytes),
      };
    }

    // --- Phantom provider mock ---
    const solana = {
      isPhantom: true,
      isConnected: false,
      publicKey: null,

      async connect() {
        const kp = await getKeypair();
        this.isConnected = true;
        this.publicKey = makePublicKey(kp.publicKey);
        return { publicKey: this.publicKey };
      },

      async disconnect() {
        this.isConnected = false;
        this.publicKey = null;
      },

      async signMessage(message) {
        const kp = await getKeypair();
        const signature = nacl.sign.detached(message, kp.secretKey);
        return { signature };
      },

      async signTransaction(tx) {
        const kp = await getKeypair();
        // solanaWeb3 is loaded from the page's CDN
        const solKp = solanaWeb3.Keypair.fromSecretKey(kp.secretKey);
        tx.partialSign(solKp);
        return tx;
      },

      on() {},
      off() {},
    };

    window.phantom = { solana };

    // --- Inject dummy CSRF meta tag ---
    // Test env has allow_forgery_protection=false so Rails skips csrf_meta_tags.
    // The wallet connect JS needs it (no optional chaining on .content).
    document.addEventListener("DOMContentLoaded", () => {
      if (!document.querySelector('meta[name="csrf-token"]')) {
        const meta = document.createElement("meta");
        meta.name = "csrf-token";
        meta.content = "test-csrf-token";
        document.head.appendChild(meta);
      }
    }, { once: true });
  }, seedByte);
}

module.exports = { MOCK_PUBKEY_B58, setupPhantomMock };
