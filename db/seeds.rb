puts "Seeding Turf Picks..."

# Users
alex = User.find_or_create_by!(email: "alex@mcritchie.studio") do |u|
  u.name = "Alex McRitchie"
  u.balance_cents = 100_000
  u.password = "password"
  u.admin = true
end
alex.update!(password: "password") if alex.password_digest.blank?
alex.update!(admin: true) unless alex.admin?

mason = User.find_or_create_by!(email: "mason@mcritchie.studio") do |u|
  u.name = "Mason McRitchie"
  u.balance_cents = 100_000
  u.password = "password"
end
mason.update!(password: "password") if mason.password_digest.blank?

mack = User.find_or_create_by!(email: "mack@mcritchie.studio") do |u|
  u.name = "Mack McRitchie"
  u.balance_cents = 100_000
  u.password = "password"
end
mack.update!(password: "password") if mack.password_digest.blank?

turf = User.find_or_create_by!(email: "turf@mcritchie.studio") do |u|
  u.name = "Turf Monster"
  u.balance_cents = 100_000
  u.password = "password"
end
turf.update!(password: "password") if turf.password_digest.blank?

# Wallet-only test user (no email) — legacy Ethereum
wallet_user = User.find_or_create_by!(wallet_address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045") do |u|
  u.name = "vitalik.eth"
  u.balance_cents = 100_000
  u.password = SecureRandom.hex(16)
end

# Generate custodial Solana wallets for email users (if they don't have one yet)
[alex, mason, mack, turf].each do |user|
  user.generate_custodial_wallet! unless user.solana_connected?
end

# Give email users some promotional credits for testing
[alex, mason, mack, turf].each do |user|
  user.update!(promotional_cents: 20) if user.promotional_cents == 0
end

puts "  Created #{User.count} users"

# ─── Teams (all 48 World Cup 2026) ──────────────────────────────
# 42 confirmed + 6 TBD playoff spots (decided March 26-31, 2026)
TEAMS_DATA = [
  # Group A
  { name: "Mexico", short_name: "MEX", location: "Mexico", emoji: "🇲🇽", color_primary: "#006847", color_secondary: "#CE1126", group: "A" },
  { name: "South Korea", short_name: "KOR", location: "South Korea", emoji: "🇰🇷", color_primary: "#CD2E3A", color_secondary: "#0047A0", group: "A" },
  { name: "South Africa", short_name: "RSA", location: "South Africa", emoji: "🇿🇦", color_primary: "#007A4D", color_secondary: "#FFB612", group: "A" },
  { name: "TBD (UEFA Playoff D)", short_name: "UPD", location: "TBD", emoji: "🏳️", color_primary: "#666666", color_secondary: "#999999", group: "A" },
  # Group B
  { name: "Canada", short_name: "CAN", location: "Canada", emoji: "🇨🇦", color_primary: "#FF0000", color_secondary: "#FFFFFF", group: "B" },
  { name: "TBD (UEFA Playoff A)", short_name: "UPA", location: "TBD", emoji: "🏳️", color_primary: "#666666", color_secondary: "#999999", group: "B" },
  { name: "Qatar", short_name: "QAT", location: "Qatar", emoji: "🇶🇦", color_primary: "#8A1538", color_secondary: "#FFFFFF", group: "B" },
  { name: "Switzerland", short_name: "SUI", location: "Switzerland", emoji: "🇨🇭", color_primary: "#FF0000", color_secondary: "#FFFFFF", group: "B" },
  # Group C
  { name: "Brazil", short_name: "BRA", location: "Brazil", emoji: "🇧🇷", color_primary: "#009C3B", color_secondary: "#FFDF00", group: "C" },
  { name: "Morocco", short_name: "MAR", location: "Morocco", emoji: "🇲🇦", color_primary: "#C1272D", color_secondary: "#006233", group: "C" },
  { name: "Haiti", short_name: "HAI", location: "Haiti", emoji: "🇭🇹", color_primary: "#00209F", color_secondary: "#D21034", group: "C" },
  { name: "Scotland", short_name: "SCO", location: "Scotland", emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿", color_primary: "#003399", color_secondary: "#FFFFFF", group: "C" },
  # Group D
  { name: "United States", short_name: "USA", location: "United States", emoji: "🇺🇸", color_primary: "#002868", color_secondary: "#BF0A30", group: "D" },
  { name: "Paraguay", short_name: "PAR", location: "Paraguay", emoji: "🇵🇾", color_primary: "#D52B1E", color_secondary: "#0038A8", group: "D" },
  { name: "Australia", short_name: "AUS", location: "Australia", emoji: "🇦🇺", color_primary: "#00843D", color_secondary: "#FFCD00", group: "D" },
  { name: "TBD (UEFA Playoff C)", short_name: "UPC", location: "TBD", emoji: "🏳️", color_primary: "#666666", color_secondary: "#999999", group: "D" },
  # Group E
  { name: "Germany", short_name: "GER", location: "Germany", emoji: "🇩🇪", color_primary: "#000000", color_secondary: "#DD0000", group: "E" },
  { name: "Curaçao", short_name: "CUW", location: "Curaçao", emoji: "🇨🇼", color_primary: "#003DA5", color_secondary: "#F9E814", group: "E" },
  { name: "Ivory Coast", short_name: "CIV", location: "Ivory Coast", emoji: "🇨🇮", color_primary: "#FF8200", color_secondary: "#009A44", group: "E" },
  { name: "Ecuador", short_name: "ECU", location: "Ecuador", emoji: "🇪🇨", color_primary: "#FFD100", color_secondary: "#003DA5", group: "E" },
  # Group F
  { name: "Netherlands", short_name: "NED", location: "Netherlands", emoji: "🇳🇱", color_primary: "#FF6600", color_secondary: "#FFFFFF", group: "F" },
  { name: "Japan", short_name: "JPN", location: "Japan", emoji: "🇯🇵", color_primary: "#000080", color_secondary: "#FFFFFF", group: "F" },
  { name: "TBD (UEFA Playoff B)", short_name: "UPB", location: "TBD", emoji: "🏳️", color_primary: "#666666", color_secondary: "#999999", group: "F" },
  { name: "Tunisia", short_name: "TUN", location: "Tunisia", emoji: "🇹🇳", color_primary: "#E70013", color_secondary: "#FFFFFF", group: "F" },
  # Group G
  { name: "Belgium", short_name: "BEL", location: "Belgium", emoji: "🇧🇪", color_primary: "#ED2939", color_secondary: "#FAE042", group: "G" },
  { name: "Egypt", short_name: "EGY", location: "Egypt", emoji: "🇪🇬", color_primary: "#CE1126", color_secondary: "#FFFFFF", group: "G" },
  { name: "Iran", short_name: "IRN", location: "Iran", emoji: "🇮🇷", color_primary: "#239F40", color_secondary: "#DA0000", group: "G" },
  { name: "New Zealand", short_name: "NZL", location: "New Zealand", emoji: "🇳🇿", color_primary: "#000000", color_secondary: "#FFFFFF", group: "G" },
  # Group H
  { name: "Spain", short_name: "ESP", location: "Spain", emoji: "🇪🇸", color_primary: "#AA151B", color_secondary: "#F1BF00", group: "H" },
  { name: "Cape Verde", short_name: "CPV", location: "Cape Verde", emoji: "🇨🇻", color_primary: "#003893", color_secondary: "#CF2028", group: "H" },
  { name: "Saudi Arabia", short_name: "KSA", location: "Saudi Arabia", emoji: "🇸🇦", color_primary: "#006C35", color_secondary: "#FFFFFF", group: "H" },
  { name: "Uruguay", short_name: "URU", location: "Uruguay", emoji: "🇺🇾", color_primary: "#5CBFEB", color_secondary: "#FFFFFF", group: "H" },
  # Group I
  { name: "France", short_name: "FRA", location: "France", emoji: "🇫🇷", color_primary: "#002395", color_secondary: "#FFFFFF", group: "I" },
  { name: "Senegal", short_name: "SEN", location: "Senegal", emoji: "🇸🇳", color_primary: "#00853F", color_secondary: "#FDEF42", group: "I" },
  { name: "TBD (IC Playoff 2)", short_name: "IC2", location: "TBD", emoji: "🏳️", color_primary: "#666666", color_secondary: "#999999", group: "I" },
  { name: "Norway", short_name: "NOR", location: "Norway", emoji: "🇳🇴", color_primary: "#EF2B2D", color_secondary: "#002868", group: "I" },
  # Group J
  { name: "Argentina", short_name: "ARG", location: "Argentina", emoji: "🇦🇷", color_primary: "#75AADB", color_secondary: "#FFFFFF", group: "J" },
  { name: "Algeria", short_name: "ALG", location: "Algeria", emoji: "🇩🇿", color_primary: "#006633", color_secondary: "#FFFFFF", group: "J" },
  { name: "Austria", short_name: "AUT", location: "Austria", emoji: "🇦🇹", color_primary: "#ED2939", color_secondary: "#FFFFFF", group: "J" },
  { name: "Jordan", short_name: "JOR", location: "Jordan", emoji: "🇯🇴", color_primary: "#000000", color_secondary: "#007A3D", group: "J" },
  # Group K
  { name: "Portugal", short_name: "POR", location: "Portugal", emoji: "🇵🇹", color_primary: "#006600", color_secondary: "#FF0000", group: "K" },
  { name: "TBD (IC Playoff 1)", short_name: "IC1", location: "TBD", emoji: "🏳️", color_primary: "#666666", color_secondary: "#999999", group: "K" },
  { name: "Uzbekistan", short_name: "UZB", location: "Uzbekistan", emoji: "🇺🇿", color_primary: "#0099CC", color_secondary: "#1EB53A", group: "K" },
  { name: "Colombia", short_name: "COL", location: "Colombia", emoji: "🇨🇴", color_primary: "#FCD116", color_secondary: "#003893", group: "K" },
  # Group L
  { name: "England", short_name: "ENG", location: "England", emoji: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", color_primary: "#FFFFFF", color_secondary: "#CF081F", group: "L" },
  { name: "Croatia", short_name: "CRO", location: "Croatia", emoji: "🇭🇷", color_primary: "#FF0000", color_secondary: "#FFFFFF", group: "L" },
  { name: "Ghana", short_name: "GHA", location: "Ghana", emoji: "🇬🇭", color_primary: "#006B3F", color_secondary: "#FCD116", group: "L" },
  { name: "Panama", short_name: "PAN", location: "Panama", emoji: "🇵🇦", color_primary: "#DA121A", color_secondary: "#003893", group: "L" },
]

teams = {}
TEAMS_DATA.each do |data|
  team = Team.find_or_create_by!(slug: data[:name].parameterize) do |t|
    t.name = data[:name]
    t.short_name = data[:short_name]
    t.location = data[:location]
    t.emoji = data[:emoji]
    t.color_primary = data[:color_primary]
    t.color_secondary = data[:color_secondary]
  end
  teams[data[:short_name]] = team
end

puts "  Created #{Team.count} teams"

# ─── Games (all 72 group stage matches) ──────────────────────────
# Times are ET (EDT in June = UTC-4)
def et(year, month, day, hour, min = 0)
  Time.new(year, month, day, hour, min, 0, "-04:00")
end

GAMES_DATA = [
  # ── Matchday 1 ──────────────────────────────────────────────────
  # June 11
  { home: "MEX", away: "RSA", kickoff_at: et(2026, 6, 11, 15, 0),  venue: "Estadio Azteca, Mexico City",            group: "A" },
  { home: "KOR", away: "UPD", kickoff_at: et(2026, 6, 11, 22, 0),  venue: "Estadio Akron, Guadalajara",             group: "A" },
  # June 12
  { home: "CAN", away: "UPA", kickoff_at: et(2026, 6, 12, 15, 0),  venue: "BMO Field, Toronto",                     group: "B" },
  { home: "USA", away: "PAR", kickoff_at: et(2026, 6, 12, 21, 0),  venue: "SoFi Stadium, Los Angeles",              group: "D" },
  # June 13
  { home: "AUS", away: "UPC", kickoff_at: et(2026, 6, 13, 0, 0),   venue: "BC Place, Vancouver",                    group: "D" },
  { home: "QAT", away: "SUI", kickoff_at: et(2026, 6, 13, 15, 0),  venue: "Levi's Stadium, San Francisco",          group: "B" },
  { home: "BRA", away: "MAR", kickoff_at: et(2026, 6, 13, 18, 0),  venue: "MetLife Stadium, East Rutherford",       group: "C" },
  { home: "HAI", away: "SCO", kickoff_at: et(2026, 6, 13, 21, 0),  venue: "Gillette Stadium, Foxborough",           group: "C" },
  # June 14
  { home: "GER", away: "CUW", kickoff_at: et(2026, 6, 14, 13, 0),  venue: "NRG Stadium, Houston",                   group: "E" },
  { home: "NED", away: "JPN", kickoff_at: et(2026, 6, 14, 16, 0),  venue: "AT&T Stadium, Arlington",                group: "F" },
  { home: "CIV", away: "ECU", kickoff_at: et(2026, 6, 14, 19, 0),  venue: "Lincoln Financial Field, Philadelphia",  group: "E" },
  { home: "UPB", away: "TUN", kickoff_at: et(2026, 6, 14, 22, 0),  venue: "Estadio BBVA, Monterrey",                group: "F" },
  # June 15
  { home: "ESP", away: "CPV", kickoff_at: et(2026, 6, 15, 12, 0),  venue: "Mercedes-Benz Stadium, Atlanta",         group: "H" },
  { home: "BEL", away: "EGY", kickoff_at: et(2026, 6, 15, 15, 0),  venue: "Lumen Field, Seattle",                   group: "G" },
  { home: "KSA", away: "URU", kickoff_at: et(2026, 6, 15, 18, 0),  venue: "Hard Rock Stadium, Miami",               group: "H" },
  { home: "IRN", away: "NZL", kickoff_at: et(2026, 6, 15, 21, 0),  venue: "SoFi Stadium, Los Angeles",              group: "G" },
  # June 16
  { home: "FRA", away: "SEN", kickoff_at: et(2026, 6, 16, 15, 0),  venue: "MetLife Stadium, East Rutherford",       group: "I" },
  { home: "IC2", away: "NOR", kickoff_at: et(2026, 6, 16, 18, 0),  venue: "Gillette Stadium, Foxborough",           group: "I" },
  { home: "ARG", away: "ALG", kickoff_at: et(2026, 6, 16, 21, 0),  venue: "Arrowhead Stadium, Kansas City",         group: "J" },
  { home: "AUT", away: "JOR", kickoff_at: et(2026, 6, 17, 0, 0),   venue: "Levi's Stadium, San Francisco",          group: "J" },
  # June 17
  { home: "POR", away: "IC1", kickoff_at: et(2026, 6, 17, 13, 0),  venue: "NRG Stadium, Houston",                   group: "K" },
  { home: "ENG", away: "CRO", kickoff_at: et(2026, 6, 17, 16, 0),  venue: "AT&T Stadium, Arlington",                group: "L" },
  { home: "GHA", away: "PAN", kickoff_at: et(2026, 6, 17, 19, 0),  venue: "BMO Field, Toronto",                     group: "L" },
  { home: "UZB", away: "COL", kickoff_at: et(2026, 6, 17, 22, 0),  venue: "Estadio Azteca, Mexico City",            group: "K" },

  # ── Matchday 2 ──────────────────────────────────────────────────
  # June 18
  { home: "UPD", away: "RSA", kickoff_at: et(2026, 6, 18, 12, 0),  venue: "Mercedes-Benz Stadium, Atlanta",         group: "A" },
  { home: "SUI", away: "UPA", kickoff_at: et(2026, 6, 18, 15, 0),  venue: "SoFi Stadium, Los Angeles",              group: "B" },
  { home: "CAN", away: "QAT", kickoff_at: et(2026, 6, 18, 18, 0),  venue: "BC Place, Vancouver",                    group: "B" },
  { home: "MEX", away: "KOR", kickoff_at: et(2026, 6, 18, 21, 0),  venue: "Estadio Akron, Guadalajara",             group: "A" },
  # June 19
  { home: "USA", away: "AUS", kickoff_at: et(2026, 6, 19, 15, 0),  venue: "Lumen Field, Seattle",                   group: "D" },
  { home: "SCO", away: "MAR", kickoff_at: et(2026, 6, 19, 18, 0),  venue: "Gillette Stadium, Foxborough",           group: "C" },
  { home: "BRA", away: "HAI", kickoff_at: et(2026, 6, 19, 21, 0),  venue: "Lincoln Financial Field, Philadelphia",  group: "C" },
  { home: "UPC", away: "PAR", kickoff_at: et(2026, 6, 20, 0, 0),   venue: "Levi's Stadium, San Francisco",          group: "D" },
  # June 20
  { home: "NED", away: "UPB", kickoff_at: et(2026, 6, 20, 13, 0),  venue: "NRG Stadium, Houston",                   group: "F" },
  { home: "GER", away: "CIV", kickoff_at: et(2026, 6, 20, 16, 0),  venue: "BMO Field, Toronto",                     group: "E" },
  { home: "ECU", away: "CUW", kickoff_at: et(2026, 6, 20, 20, 0),  venue: "Arrowhead Stadium, Kansas City",         group: "E" },
  { home: "TUN", away: "JPN", kickoff_at: et(2026, 6, 21, 0, 0),   venue: "Estadio BBVA, Monterrey",                group: "F" },
  # June 21
  { home: "ESP", away: "KSA", kickoff_at: et(2026, 6, 21, 12, 0),  venue: "Mercedes-Benz Stadium, Atlanta",         group: "H" },
  { home: "BEL", away: "IRN", kickoff_at: et(2026, 6, 21, 15, 0),  venue: "SoFi Stadium, Los Angeles",              group: "G" },
  { home: "URU", away: "CPV", kickoff_at: et(2026, 6, 21, 18, 0),  venue: "Hard Rock Stadium, Miami",               group: "H" },
  { home: "NZL", away: "EGY", kickoff_at: et(2026, 6, 21, 21, 0),  venue: "BC Place, Vancouver",                    group: "G" },
  # June 22
  { home: "ARG", away: "AUT", kickoff_at: et(2026, 6, 22, 13, 0),  venue: "AT&T Stadium, Arlington",                group: "J" },
  { home: "FRA", away: "IC2", kickoff_at: et(2026, 6, 22, 17, 0),  venue: "Lincoln Financial Field, Philadelphia",  group: "I" },
  { home: "NOR", away: "SEN", kickoff_at: et(2026, 6, 22, 20, 0),  venue: "MetLife Stadium, East Rutherford",       group: "I" },
  { home: "JOR", away: "ALG", kickoff_at: et(2026, 6, 22, 23, 0),  venue: "Levi's Stadium, San Francisco",          group: "J" },
  # June 23
  { home: "POR", away: "UZB", kickoff_at: et(2026, 6, 23, 13, 0),  venue: "NRG Stadium, Houston",                   group: "K" },
  { home: "ENG", away: "GHA", kickoff_at: et(2026, 6, 23, 16, 0),  venue: "Gillette Stadium, Foxborough",           group: "L" },
  { home: "PAN", away: "CRO", kickoff_at: et(2026, 6, 23, 19, 0),  venue: "BMO Field, Toronto",                     group: "L" },
  { home: "COL", away: "IC1", kickoff_at: et(2026, 6, 23, 22, 0),  venue: "Estadio Akron, Guadalajara",             group: "K" },

  # ── Matchday 3 ──────────────────────────────────────────────────
  # June 24
  { home: "SUI", away: "CAN", kickoff_at: et(2026, 6, 24, 15, 0),  venue: "BC Place, Vancouver",                    group: "B" },
  { home: "UPA", away: "QAT", kickoff_at: et(2026, 6, 24, 15, 0),  venue: "Lumen Field, Seattle",                   group: "B" },
  { home: "SCO", away: "BRA", kickoff_at: et(2026, 6, 24, 18, 0),  venue: "Hard Rock Stadium, Miami",               group: "C" },
  { home: "MAR", away: "HAI", kickoff_at: et(2026, 6, 24, 18, 0),  venue: "Mercedes-Benz Stadium, Atlanta",         group: "C" },
  { home: "UPD", away: "MEX", kickoff_at: et(2026, 6, 24, 21, 0),  venue: "Estadio Azteca, Mexico City",            group: "A" },
  { home: "RSA", away: "KOR", kickoff_at: et(2026, 6, 24, 21, 0),  venue: "Estadio BBVA, Monterrey",                group: "A" },
  # June 25
  { home: "CUW", away: "CIV", kickoff_at: et(2026, 6, 25, 16, 0),  venue: "Lincoln Financial Field, Philadelphia",  group: "E" },
  { home: "ECU", away: "GER", kickoff_at: et(2026, 6, 25, 16, 0),  venue: "MetLife Stadium, East Rutherford",       group: "E" },
  { home: "JPN", away: "UPB", kickoff_at: et(2026, 6, 25, 19, 0),  venue: "AT&T Stadium, Arlington",                group: "F" },
  { home: "TUN", away: "NED", kickoff_at: et(2026, 6, 25, 19, 0),  venue: "Arrowhead Stadium, Kansas City",         group: "F" },
  { home: "UPC", away: "USA", kickoff_at: et(2026, 6, 25, 22, 0),  venue: "SoFi Stadium, Los Angeles",              group: "D" },
  { home: "PAR", away: "AUS", kickoff_at: et(2026, 6, 25, 22, 0),  venue: "Levi's Stadium, San Francisco",          group: "D" },
  # June 26
  { home: "NOR", away: "FRA", kickoff_at: et(2026, 6, 26, 15, 0),  venue: "Gillette Stadium, Foxborough",           group: "I" },
  { home: "SEN", away: "IC2", kickoff_at: et(2026, 6, 26, 15, 0),  venue: "BMO Field, Toronto",                     group: "I" },
  { home: "CPV", away: "KSA", kickoff_at: et(2026, 6, 26, 20, 0),  venue: "NRG Stadium, Houston",                   group: "H" },
  { home: "URU", away: "ESP", kickoff_at: et(2026, 6, 26, 20, 0),  venue: "Estadio Akron, Guadalajara",             group: "H" },
  { home: "EGY", away: "IRN", kickoff_at: et(2026, 6, 26, 23, 0),  venue: "Lumen Field, Seattle",                   group: "G" },
  { home: "NZL", away: "BEL", kickoff_at: et(2026, 6, 26, 23, 0),  venue: "BC Place, Vancouver",                    group: "G" },
  # June 27
  { home: "PAN", away: "ENG", kickoff_at: et(2026, 6, 27, 17, 0),  venue: "MetLife Stadium, East Rutherford",       group: "L" },
  { home: "CRO", away: "GHA", kickoff_at: et(2026, 6, 27, 17, 0),  venue: "Lincoln Financial Field, Philadelphia",  group: "L" },
  { home: "COL", away: "POR", kickoff_at: et(2026, 6, 27, 19, 30), venue: "Hard Rock Stadium, Miami",               group: "K" },
  { home: "IC1", away: "UZB", kickoff_at: et(2026, 6, 27, 19, 30), venue: "Mercedes-Benz Stadium, Atlanta",         group: "K" },
  { home: "ALG", away: "AUT", kickoff_at: et(2026, 6, 27, 22, 0),  venue: "Arrowhead Stadium, Kansas City",         group: "J" },
  { home: "JOR", away: "ARG", kickoff_at: et(2026, 6, 27, 22, 0),  venue: "AT&T Stadium, Arlington",                group: "J" },
]

GAMES_DATA.each do |data|
  home_team = teams[data[:home]]
  away_team = teams[data[:away]]

  next unless home_team && away_team

  Game.find_or_create_by!(home_team_slug: home_team.slug, away_team_slug: away_team.slug) do |g|
    g.kickoff_at = data[:kickoff_at]
    g.venue = data[:venue]
    g.status = "scheduled"
  end
end

puts "  Created #{Game.count} games"

# ─── Players (notable starters, ~3-5 per team) ──────────────────
PLAYERS_DATA = {
  "ARG" => [
    { name: "Lionel Messi", position: "Forward", jersey_number: 10 },
    { name: "Julián Álvarez", position: "Forward", jersey_number: 9 },
    { name: "Enzo Fernández", position: "Midfielder", jersey_number: 24 },
    { name: "Emiliano Martínez", position: "Goalkeeper", jersey_number: 23 },
  ],
  "BRA" => [
    { name: "Vinícius Júnior", position: "Forward", jersey_number: 7 },
    { name: "Rodrygo", position: "Forward", jersey_number: 11 },
    { name: "Endrick", position: "Forward", jersey_number: 9 },
    { name: "Alisson", position: "Goalkeeper", jersey_number: 1 },
  ],
  "FRA" => [
    { name: "Kylian Mbappé", position: "Forward", jersey_number: 10 },
    { name: "Antoine Griezmann", position: "Forward", jersey_number: 7 },
    { name: "Aurélien Tchouaméni", position: "Midfielder", jersey_number: 8 },
  ],
  "GER" => [
    { name: "Florian Wirtz", position: "Midfielder", jersey_number: 10 },
    { name: "Jamal Musiala", position: "Midfielder", jersey_number: 14 },
    { name: "Kai Havertz", position: "Forward", jersey_number: 7 },
  ],
  "ESP" => [
    { name: "Lamine Yamal", position: "Forward", jersey_number: 19 },
    { name: "Pedri", position: "Midfielder", jersey_number: 8 },
    { name: "Rodri", position: "Midfielder", jersey_number: 16 },
  ],
  "ENG" => [
    { name: "Jude Bellingham", position: "Midfielder", jersey_number: 10 },
    { name: "Harry Kane", position: "Forward", jersey_number: 9 },
    { name: "Bukayo Saka", position: "Forward", jersey_number: 7 },
    { name: "Phil Foden", position: "Midfielder", jersey_number: 11 },
  ],
  "POR" => [
    { name: "Cristiano Ronaldo", position: "Forward", jersey_number: 7 },
    { name: "Bruno Fernandes", position: "Midfielder", jersey_number: 8 },
    { name: "Bernardo Silva", position: "Midfielder", jersey_number: 10 },
  ],
  "NED" => [
    { name: "Cody Gakpo", position: "Forward", jersey_number: 11 },
    { name: "Virgil van Dijk", position: "Defender", jersey_number: 4 },
    { name: "Frenkie de Jong", position: "Midfielder", jersey_number: 21 },
  ],
  "BEL" => [
    { name: "Kevin De Bruyne", position: "Midfielder", jersey_number: 7 },
    { name: "Romelu Lukaku", position: "Forward", jersey_number: 9 },
    { name: "Jérémy Doku", position: "Forward", jersey_number: 11 },
  ],
  "URU" => [
    { name: "Darwin Núñez", position: "Forward", jersey_number: 11 },
    { name: "Federico Valverde", position: "Midfielder", jersey_number: 15 },
    { name: "Ronald Araújo", position: "Defender", jersey_number: 4 },
  ],
  "MEX" => [
    { name: "Hirving Lozano", position: "Forward", jersey_number: 22 },
    { name: "Raúl Jiménez", position: "Forward", jersey_number: 9 },
    { name: "Edson Álvarez", position: "Midfielder", jersey_number: 4 },
  ],
  "USA" => [
    { name: "Christian Pulisic", position: "Forward", jersey_number: 10 },
    { name: "Weston McKennie", position: "Midfielder", jersey_number: 8 },
    { name: "Tyler Adams", position: "Midfielder", jersey_number: 4 },
    { name: "Gio Reyna", position: "Forward", jersey_number: 7 },
  ],
  "JPN" => [
    { name: "Takefusa Kubo", position: "Forward", jersey_number: 11 },
    { name: "Kaoru Mitoma", position: "Forward", jersey_number: 9 },
    { name: "Wataru Endo", position: "Midfielder", jersey_number: 6 },
  ],
  "KOR" => [
    { name: "Son Heung-min", position: "Forward", jersey_number: 7 },
    { name: "Lee Kang-in", position: "Midfielder", jersey_number: 10 },
    { name: "Kim Min-jae", position: "Defender", jersey_number: 3 },
  ],
  "CRO" => [
    { name: "Luka Modrić", position: "Midfielder", jersey_number: 10 },
    { name: "Mateo Kovačić", position: "Midfielder", jersey_number: 8 },
    { name: "Joško Gvardiol", position: "Defender", jersey_number: 20 },
  ],
  "SEN" => [
    { name: "Sadio Mané", position: "Forward", jersey_number: 10 },
    { name: "Kalidou Koulibaly", position: "Defender", jersey_number: 3 },
    { name: "Ismaïla Sarr", position: "Forward", jersey_number: 18 },
  ],
  "MAR" => [
    { name: "Achraf Hakimi", position: "Defender", jersey_number: 2 },
    { name: "Hakim Ziyech", position: "Forward", jersey_number: 7 },
    { name: "Youssef En-Nesyri", position: "Forward", jersey_number: 9 },
  ],
  "COL" => [
    { name: "Luis Díaz", position: "Forward", jersey_number: 7 },
    { name: "James Rodríguez", position: "Midfielder", jersey_number: 10 },
    { name: "Jhon Durán", position: "Forward", jersey_number: 9 },
  ],
  "CAN" => [
    { name: "Alphonso Davies", position: "Defender", jersey_number: 19 },
    { name: "Jonathan David", position: "Forward", jersey_number: 9 },
    { name: "Cyle Larin", position: "Forward", jersey_number: 17 },
  ],
  "AUS" => [
    { name: "Mathew Ryan", position: "Goalkeeper", jersey_number: 1 },
    { name: "Jackson Irvine", position: "Midfielder", jersey_number: 22 },
    { name: "Mitchell Duke", position: "Forward", jersey_number: 13 },
  ],
  "ECU" => [
    { name: "Moisés Caicedo", position: "Midfielder", jersey_number: 23 },
    { name: "Enner Valencia", position: "Forward", jersey_number: 13 },
    { name: "Piero Hincapié", position: "Defender", jersey_number: 3 },
  ],
}

PLAYERS_DATA.each do |short_name, players|
  team = teams[short_name]
  next unless team

  players.each do |data|
    Player.find_or_create_by!(slug: data[:name].parameterize) do |p|
      p.team_slug = team.slug
      p.name = data[:name]
      p.position = data[:position]
      p.jersey_number = data[:jersey_number]
    end
  end
end

puts "  Created #{Player.count} players"

# ─── Contest ─────────────────────────────────────────────────────
contest = Contest.find_or_create_by!(name: "World Cup 2026 — Matchday 1") do |c|
  c.entry_fee_cents = 20_00
  c.status = "open"
  c.max_entries = 15
  c.starts_at = Time.new(2026, 6, 11, 15, 0, 0, "-04:00")
end

puts "  Created contest: #{contest.name}"

# ─── Props (24 game total goals — one per Matchday 1 game) ──────
# Lines: 2.5 for strong-vs-weak, 1.5 for competitive, 2.0 for mid-tier
MATCHDAY_1_PROPS = [
  # June 11
  { home: "MEX", away: "RSA", line: 2.0 },
  { home: "KOR", away: "UPD", line: 2.0 },
  # June 12
  { home: "CAN", away: "UPA", line: 2.0 },
  { home: "USA", away: "PAR", line: 2.0 },
  # June 13
  { home: "AUS", away: "UPC", line: 2.0 },
  { home: "QAT", away: "SUI", line: 2.0 },
  { home: "BRA", away: "MAR", line: 1.5 },
  { home: "HAI", away: "SCO", line: 2.0 },
  # June 14
  { home: "GER", away: "CUW", line: 2.5 },
  { home: "NED", away: "JPN", line: 1.5 },
  { home: "CIV", away: "ECU", line: 1.5 },
  { home: "UPB", away: "TUN", line: 1.5 },
  # June 15
  { home: "ESP", away: "CPV", line: 2.5 },
  { home: "BEL", away: "EGY", line: 2.0 },
  { home: "KSA", away: "URU", line: 2.0 },
  { home: "IRN", away: "NZL", line: 1.5 },
  # June 16
  { home: "FRA", away: "SEN", line: 2.0 },
  { home: "IC2", away: "NOR", line: 1.5 },
  { home: "ARG", away: "ALG", line: 2.0 },
  { home: "AUT", away: "JOR", line: 2.0 },
  # June 17
  { home: "POR", away: "IC1", line: 2.5 },
  { home: "ENG", away: "CRO", line: 1.5 },
  { home: "GHA", away: "PAN", line: 2.0 },
  { home: "UZB", away: "COL", line: 2.0 },
]

props = MATCHDAY_1_PROPS.map do |data|
  home_team = teams[data[:home]]
  away_team = teams[data[:away]]
  game = Game.find_by(home_team_slug: home_team&.slug, away_team_slug: away_team&.slug)
  desc = "#{home_team&.name || data[:home]} vs #{away_team&.name || data[:away]} Total Goals"

  Prop.find_or_create_by!(contest: contest, description: desc) do |p|
    p.line = data[:line]
    p.stat_type = "goals"
    p.team_slug = home_team&.slug
    p.opponent_team_slug = away_team&.slug
    p.game_slug = game&.slug
  end
end

puts "  Created #{props.size} props"

# No pre-filled entries — use admin Fill button to populate

# ─── Turf Totals Contest ──────────────────────────────────────────
turf_totals = Contest.find_or_create_by!(name: "Turf Totals v1 — Matchday 1") do |c|
  c.entry_fee_cents = 20_00
  c.status = "open"
  c.max_entries = 15
  c.contest_type = "turf_totals"
  c.starts_at = Time.new(2026, 6, 11, 15, 0, 0, "-04:00")
end

puts "  Created contest: #{turf_totals.name}"

# Create 48 ContestMatchups — both teams from each Matchday 1 game
matchup_count = 0
MATCHDAY_1_PROPS.each do |data|
  home_team = teams[data[:home]]
  away_team = teams[data[:away]]
  game = Game.find_by(home_team_slug: home_team&.slug, away_team_slug: away_team&.slug)

  next unless home_team && away_team

  # Home team matchup
  ContestMatchup.find_or_create_by!(contest: turf_totals, team_slug: home_team.slug) do |m|
    m.opponent_team_slug = away_team.slug
    m.game_slug = game&.slug
  end
  matchup_count += 1

  # Away team matchup
  ContestMatchup.find_or_create_by!(contest: turf_totals, team_slug: away_team.slug) do |m|
    m.opponent_team_slug = home_team.slug
    m.game_slug = game&.slug
  end
  matchup_count += 1
end

# Default ranking: alphabetical by team name
turf_totals.contest_matchups.includes(:team).sort_by { |m| m.team.name }.each_with_index do |matchup, i|
  rank = i + 1
  matchup.update!(rank: rank, multiplier: (Math.sqrt(rank) * 0.5 + 0.5).round(1))
end

puts "  Created #{ContestMatchup.where(contest: turf_totals).count} contest matchups with rankings"

puts "Done! #{User.count} users, #{Contest.count} contests, #{Prop.count} props, #{Entry.count} entries, #{Pick.count} picks"
puts "  #{Team.count} teams, #{Game.count} games, #{Player.count} players, #{ContestMatchup.count} matchups"
