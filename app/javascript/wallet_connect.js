// Confetti helper — used after successful onchain transactions
// solanaWalletConnect stays inline in application.html.erb (Alpine timing constraint)

window.fireSuccessConfetti = function() {
  if (typeof confetti === 'undefined') return;
  var colors = window.CONFETTI_COLORS || ['#4BAF50', '#8E82FE', '#06D6A0', '#FF7C47', '#FFD700', '#00BFFF', '#FF6B9D', '#C084FC'];
  confetti({ particleCount: 150, spread: 100, origin: { x: 0.5, y: 0.5 }, colors: colors, zIndex: 99, startVelocity: 45, gravity: 0.8, ticks: 300, scalar: 1.2 });
  setTimeout(function() { confetti({ particleCount: 80, angle: 60, spread: 60, origin: { x: 0, y: 0.6 }, colors: colors, zIndex: 99, startVelocity: 55, gravity: 1, ticks: 250 }); }, 150);
  setTimeout(function() { confetti({ particleCount: 80, angle: 120, spread: 60, origin: { x: 1, y: 0.6 }, colors: colors, zIndex: 99, startVelocity: 55, gravity: 1, ticks: 250 }); }, 150);
  setTimeout(function() { confetti({ particleCount: 100, spread: 160, origin: { x: 0.5, y: 0.3 }, colors: colors, zIndex: 99, startVelocity: 30, gravity: 1.2, ticks: 200, scalar: 0.8 }); }, 400);
};
