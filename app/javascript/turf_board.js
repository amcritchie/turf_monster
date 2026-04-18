// Turf board utilities
// selectionBoard stays inline in _turf_totals_board.html.erb (Alpine timing constraint)

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
