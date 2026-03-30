module ApplicationHelper
  CONTEST_BADGE_STYLES = {
    "open"    => "bg-mint-900/30 text-mint border-mint-700",
    "locked"  => "bg-yellow-900/50 text-yellow-400 border-yellow-700",
    "settled" => "bg-gray-800 text-gray-400 border-gray-600",
    "draft"   => "bg-violet-900/30 text-violet border-violet-700"
  }.freeze

  def contest_badge_classes(status)
    CONTEST_BADGE_STYLES[status] || ""
  end

  def dollars(amount)
    "$#{sprintf('%.2f', amount)}"
  end
end
