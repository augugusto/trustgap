/**
 * {{NOMBRE}} — Main application logic.
 *
 * Wire-up: wallet connection → on-chain reads → verification.
 */

let provider = null;
let signer = null;
let account = null;

// ── Wallet connection ──────────────────────────────────────────

async function connectWallet() {
  if (!window.ethereum) {
    showError('No Ethereum wallet detected. Install MetaMask or a compatible wallet.');
    return;
  }

  try {
    // Request accounts
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    account = accounts[0];

    // Create provider and signer
    provider = new ethers.providers.Web3Provider(window.ethereum);
    signer = provider.getSigner();

    // Check chain
    const network = await provider.getNetwork();
    if (network.chainId !== DEFAULT_CHAIN_ID) {
      showError(
        'Wrong network. Please switch to ' + DEFAULT_CHAIN_NAME +
        ' (Chain ID: ' + DEFAULT_CHAIN_ID + ').'
      );
      return;
    }

    // Update UI
    document.getElementById('wallet-address').textContent =
      account.slice(0, 6) + '...' + account.slice(-4);
    document.getElementById('connect-btn').classList.add('hidden');
    document.getElementById('wallet-info').classList.remove('hidden');
    document.getElementById('error-box').classList.add('hidden');

    // Run verification
    await runVerification();

  } catch (err) {
    if (err.code === 4001) {
      showError('Wallet connection rejected.');
    } else {
      showError('Failed to connect: ' + err.message);
    }
  }
}

// ── Event listeners ────────────────────────────────────────────

function setupWalletEvents() {
  if (!window.ethereum) return;

  // Account change → reload (cleanest invalidation)
  window.ethereum.on('accountsChanged', function (accounts) {
    if (accounts.length > 0) {
      window.location.reload();
    } else {
      // Disconnected
      account = null;
      provider = null;
      document.getElementById('wallet-info').classList.add('hidden');
      document.getElementById('connect-btn').classList.remove('hidden');
      document.getElementById('badge').classList.add('hidden');
    }
  });

  // Chain change → reload
  window.ethereum.on('chainChanged', function () {
    window.location.reload();
  });
}

// ── Verificarion ───────────────────────────────────────────────

async function runVerification() {
  const resultEl = document.getElementById('badge');
  const detailsEl = document.getElementById('verification-details');

  resultEl.classList.remove('hidden', 'verified', 'unverified', 'loading');
  resultEl.classList.add('loading');
  resultEl.textContent = 'Verifying...';

  const result = await verifyDeployment(EXPECTED_CID, provider);

  resultEl.classList.remove('loading');

  if (result.verified) {
    resultEl.classList.add('verified');
    resultEl.innerHTML = '&#10003; Verified — This deployment was approved by the DAO';
  } else {
    resultEl.classList.add('unverified');
    resultEl.innerHTML = '&#10007; Not Verified — ' + (result.error || 'Unknown error');
  }

  // Show details
  if (result.expected) {
    detailsEl.innerHTML =
      '<p><strong>Expected CID:</strong> <code>' + result.expected + '</code></p>' +
      '<p><strong>On-chain CID:</strong> <code>' + (result.onChain || 'none') + '</code></p>';
    if (result.error) {
      detailsEl.innerHTML += '<p class="error-text">' + result.error + '</p>';
    }
  }

  // Show member count if available
  if (CONTRACTS.daoShare) {
    try {
      const memberCount = await getMemberCount(provider);
      detailsEl.innerHTML +=
        '<p><strong>DAO Members:</strong> ' + memberCount + '</p>';
    } catch (_) {
      // Non-critical — skip
    }
  }
}

// ── UI helpers ──────────────────────────────────────────────────

function showError(message) {
  const el = document.getElementById('error-box');
  el.textContent = message;
  el.classList.remove('hidden');
}

// ── Init ────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', function () {
  document.getElementById('connect-btn').addEventListener('click', connectWallet);
  setupWalletEvents();

  // If already connected (e.g., page reload after chain change), auto-verify
  if (window.ethereum && window.ethereum.selectedAddress) {
    connectWallet();
  }
});
