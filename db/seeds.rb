puts "Seeding Turf Picks..."

# Users
alex = User.find_or_create_by!(email: "alex@turf.com") do |u|
  u.name = "Alex"
  u.balance_cents = 100_000
  u.password = "pass"
end
alex.update!(password: "pass") if alex.password_digest.blank?

jordan = User.find_or_create_by!(email: "jordan@turf.com") do |u|
  u.name = "Jordan"
  u.balance_cents = 100_000
  u.password = "pass"
end
jordan.update!(password: "pass") if jordan.password_digest.blank?

sam = User.find_or_create_by!(email: "sam@turf.com") do |u|
  u.name = "Sam"
  u.balance_cents = 100_000
  u.password = "pass"
end
sam.update!(password: "pass") if sam.password_digest.blank?

puts "  Created #{User.count} users"

# ─── Teams ───────────────────────────────────────────────────────
TEAMS_DATA = [
  # Group A
  { name: "Morocco", short_name: "MAR", location: "Morocco", emoji: "🇲🇦", color_primary: "#C1272D", color_secondary: "#006233" },
  { name: "Peru", short_name: "PER", location: "Peru", emoji: "🇵🇪", color_primary: "#D91023", color_secondary: "#FFFFFF" },
  { name: "Scotland", short_name: "SCO", location: "Scotland", emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿", color_primary: "#003399", color_secondary: "#FFFFFF" },
  { name: "Argentina", short_name: "ARG", location: "Argentina", emoji: "🇦🇷", color_primary: "#75AADB", color_secondary: "#FFFFFF" },
  # Group B
  { name: "Mexico", short_name: "MEX", location: "Mexico", emoji: "🇲🇽", color_primary: "#006847", color_secondary: "#CE1126" },
  { name: "Ecuador", short_name: "ECU", location: "Ecuador", emoji: "🇪🇨", color_primary: "#FFD100", color_secondary: "#003DA5" },
  { name: "Japan", short_name: "JPN", location: "Japan", emoji: "🇯🇵", color_primary: "#000080", color_secondary: "#FFFFFF" },
  { name: "Colombia", short_name: "COL", location: "Colombia", emoji: "🇨🇴", color_primary: "#FCD116", color_secondary: "#003893" },
  # Group C
  { name: "United States", short_name: "USA", location: "United States", emoji: "🇺🇸", color_primary: "#002868", color_secondary: "#BF0A30" },
  { name: "Bolivia", short_name: "BOL", location: "Bolivia", emoji: "🇧🇴", color_primary: "#007934", color_secondary: "#D52B1E" },
  { name: "Turkey", short_name: "TUR", location: "Turkey", emoji: "🇹🇷", color_primary: "#E30A17", color_secondary: "#FFFFFF" },
  { name: "England", short_name: "ENG", location: "England", emoji: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", color_primary: "#FFFFFF", color_secondary: "#CF081F" },
  # Group D
  { name: "Canada", short_name: "CAN", location: "Canada", emoji: "🇨🇦", color_primary: "#FF0000", color_secondary: "#FFFFFF" },
  { name: "Cameroon", short_name: "CMR", location: "Cameroon", emoji: "🇨🇲", color_primary: "#007A3D", color_secondary: "#CE1126" },
  { name: "Slovenia", short_name: "SVN", location: "Slovenia", emoji: "🇸🇮", color_primary: "#003DA5", color_secondary: "#FFFFFF" },
  { name: "Portugal", short_name: "POR", location: "Portugal", emoji: "🇵🇹", color_primary: "#006600", color_secondary: "#FF0000" },
  # Group E
  { name: "Germany", short_name: "GER", location: "Germany", emoji: "🇩🇪", color_primary: "#000000", color_secondary: "#DD0000" },
  { name: "Serbia", short_name: "SRB", location: "Serbia", emoji: "🇷🇸", color_primary: "#C6363C", color_secondary: "#0C4076" },
  { name: "Uruguay", short_name: "URU", location: "Uruguay", emoji: "🇺🇾", color_primary: "#5CBFEB", color_secondary: "#FFFFFF" },
  { name: "South Korea", short_name: "KOR", location: "South Korea", emoji: "🇰🇷", color_primary: "#CD2E3A", color_secondary: "#0047A0" },
  # Group F
  { name: "Brazil", short_name: "BRA", location: "Brazil", emoji: "🇧🇷", color_primary: "#009C3B", color_secondary: "#FFDF00" },
  { name: "Italy", short_name: "ITA", location: "Italy", emoji: "🇮🇹", color_primary: "#0066B3", color_secondary: "#FFFFFF" },
  { name: "Paraguay", short_name: "PAR", location: "Paraguay", emoji: "🇵🇾", color_primary: "#D52B1E", color_secondary: "#0038A8" },
  { name: "Ivory Coast", short_name: "CIV", location: "Ivory Coast", emoji: "🇨🇮", color_primary: "#FF8200", color_secondary: "#009A44" },
  # Group G
  { name: "France", short_name: "FRA", location: "France", emoji: "🇫🇷", color_primary: "#002395", color_secondary: "#FFFFFF" },
  { name: "Panama", short_name: "PAN", location: "Panama", emoji: "🇵🇦", color_primary: "#DA121A", color_secondary: "#003893" },
  { name: "Australia", short_name: "AUS", location: "Australia", emoji: "🇦🇺", color_primary: "#00843D", color_secondary: "#FFCD00" },
  { name: "Indonesia", short_name: "IDN", location: "Indonesia", emoji: "🇮🇩", color_primary: "#FF0000", color_secondary: "#FFFFFF" },
  # Group H
  { name: "Spain", short_name: "ESP", location: "Spain", emoji: "🇪🇸", color_primary: "#AA151B", color_secondary: "#F1BF00" },
  { name: "Nigeria", short_name: "NGA", location: "Nigeria", emoji: "🇳🇬", color_primary: "#008751", color_secondary: "#FFFFFF" },
  { name: "New Zealand", short_name: "NZL", location: "New Zealand", emoji: "🇳🇿", color_primary: "#000000", color_secondary: "#FFFFFF" },
  { name: "Chile", short_name: "CHI", location: "Chile", emoji: "🇨🇱", color_primary: "#D52B1E", color_secondary: "#0039A6" },
  # Group I
  { name: "Netherlands", short_name: "NED", location: "Netherlands", emoji: "🇳🇱", color_primary: "#FF6600", color_secondary: "#FFFFFF" },
  { name: "Senegal", short_name: "SEN", location: "Senegal", emoji: "🇸🇳", color_primary: "#00853F", color_secondary: "#FDEF42" },
  { name: "Iran", short_name: "IRN", location: "Iran", emoji: "🇮🇷", color_primary: "#239F40", color_secondary: "#DA0000" },
  { name: "Qatar", short_name: "QAT", location: "Qatar", emoji: "🇶🇦", color_primary: "#8A1538", color_secondary: "#FFFFFF" },
  # Group J
  { name: "Belgium", short_name: "BEL", location: "Belgium", emoji: "🇧🇪", color_primary: "#ED2939", color_secondary: "#FAE042" },
  { name: "Saudi Arabia", short_name: "KSA", location: "Saudi Arabia", emoji: "🇸🇦", color_primary: "#006C35", color_secondary: "#FFFFFF" },
  { name: "Denmark", short_name: "DEN", location: "Denmark", emoji: "🇩🇰", color_primary: "#C60C30", color_secondary: "#FFFFFF" },
  { name: "Croatia", short_name: "CRO", location: "Croatia", emoji: "🇭🇷", color_primary: "#FF0000", color_secondary: "#FFFFFF" },
  # Group K
  { name: "Wales", short_name: "WAL", location: "Wales", emoji: "🏴󠁧󠁢󠁷󠁬󠁳󠁿", color_primary: "#D4213D", color_secondary: "#00AB39" },
  { name: "Switzerland", short_name: "SUI", location: "Switzerland", emoji: "🇨🇭", color_primary: "#FF0000", color_secondary: "#FFFFFF" },
  { name: "Costa Rica", short_name: "CRC", location: "Costa Rica", emoji: "🇨🇷", color_primary: "#002B7F", color_secondary: "#CE1126" },
  { name: "Ghana", short_name: "GHA", location: "Ghana", emoji: "🇬🇭", color_primary: "#006B3F", color_secondary: "#FCD116" },
  # Group L
  { name: "Poland", short_name: "POL", location: "Poland", emoji: "🇵🇱", color_primary: "#DC143C", color_secondary: "#FFFFFF" },
  { name: "Egypt", short_name: "EGY", location: "Egypt", emoji: "🇪🇬", color_primary: "#CE1126", color_secondary: "#FFFFFF" },
  { name: "Honduras", short_name: "HON", location: "Honduras", emoji: "🇭🇳", color_primary: "#0051AB", color_secondary: "#FFFFFF" },
  { name: "Algeria", short_name: "ALG", location: "Algeria", emoji: "🇩🇿", color_primary: "#006633", color_secondary: "#FFFFFF" },
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

# ─── Games (Opening day — June 11, 2026) ────────────────────────
GAMES_DATA = [
  { home: "MEX", away: "ECU", kickoff_at: Time.new(2026, 6, 11, 12, 0, 0, "-05:00"), venue: "Estadio Azteca, Mexico City" },
  { home: "USA", away: "BOL", kickoff_at: Time.new(2026, 6, 11, 16, 0, 0, "-05:00"), venue: "SoFi Stadium, Los Angeles" },
  { home: "MAR", away: "PER", kickoff_at: Time.new(2026, 6, 11, 19, 0, 0, "-05:00"), venue: "Hard Rock Stadium, Miami" },
  # Day 2 — June 12
  { home: "ARG", away: "SCO", kickoff_at: Time.new(2026, 6, 12, 13, 0, 0, "-05:00"), venue: "MetLife Stadium, New Jersey" },
  { home: "JPN", away: "COL", kickoff_at: Time.new(2026, 6, 12, 16, 0, 0, "-05:00"), venue: "AT&T Stadium, Dallas" },
  { home: "CAN", away: "CMR", kickoff_at: Time.new(2026, 6, 12, 19, 0, 0, "-05:00"), venue: "BMO Field, Toronto" },
  # Day 3 — June 13
  { home: "GER", away: "SRB", kickoff_at: Time.new(2026, 6, 13, 13, 0, 0, "-05:00"), venue: "Lincoln Financial Field, Philadelphia" },
  { home: "ENG", away: "TUR", kickoff_at: Time.new(2026, 6, 13, 16, 0, 0, "-05:00"), venue: "Lumen Field, Seattle" },
  { home: "POR", away: "SVN", kickoff_at: Time.new(2026, 6, 13, 19, 0, 0, "-05:00"), venue: "Gillette Stadium, Foxborough" },
  # Day 4 — June 14
  { home: "BRA", away: "ITA", kickoff_at: Time.new(2026, 6, 14, 13, 0, 0, "-05:00"), venue: "MetLife Stadium, New Jersey" },
  { home: "FRA", away: "PAN", kickoff_at: Time.new(2026, 6, 14, 16, 0, 0, "-05:00"), venue: "NRG Stadium, Houston" },
  { home: "ESP", away: "NGA", kickoff_at: Time.new(2026, 6, 14, 19, 0, 0, "-05:00"), venue: "Mercedes-Benz Stadium, Atlanta" },
  # Day 5 — June 15
  { home: "NED", away: "SEN", kickoff_at: Time.new(2026, 6, 15, 13, 0, 0, "-05:00"), venue: "SoFi Stadium, Los Angeles" },
  { home: "BEL", away: "KSA", kickoff_at: Time.new(2026, 6, 15, 16, 0, 0, "-05:00"), venue: "Lumen Field, Seattle" },
  { home: "URU", away: "KOR", kickoff_at: Time.new(2026, 6, 15, 19, 0, 0, "-05:00"), venue: "Hard Rock Stadium, Miami" },
  { home: "CRO", away: "DEN", kickoff_at: Time.new(2026, 6, 15, 19, 0, 0, "-05:00"), venue: "Estadio Azteca, Mexico City" },
]

GAMES_DATA.each do |data|
  home_team = teams[data[:home]]
  away_team = teams[data[:away]]
  Game.find_or_create_by!(home_team_slug: home_team.slug, away_team_slug: away_team.slug) do |g|
    g.kickoff_at = data[:kickoff_at]
    g.venue = data[:venue]
    g.status = "scheduled"
  end
end

puts "  Created #{Game.count} games"

# ─── Players (notable starters, ~3-5 per team with props) ──────
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
contest = Contest.find_or_create_by!(name: "World Cup 2026 — Group Stage Day 1") do |c|
  c.entry_fee_cents = 10_00
  c.status = "open"
  c.starts_at = Time.new(2026, 6, 11, 16, 0, 0)
end

puts "  Created contest: #{contest.name}"

# ─── Props (with team + game slug links) ─────────────────────────
# Map prop descriptions to team short_names and opponent short_names
PROP_TEAM_MAP = {
  "Argentina Total Goals" => { team: "ARG", opponent: "SCO", home: "ARG", away: "SCO" },
  "Brazil Total Goals" => { team: "BRA", opponent: "ITA", home: "BRA", away: "ITA" },
  "France Total Goals" => { team: "FRA", opponent: "PAN", home: "FRA", away: "PAN" },
  "Germany Total Goals" => { team: "GER", opponent: "SRB", home: "GER", away: "SRB" },
  "Spain Total Goals" => { team: "ESP", opponent: "NGA", home: "ESP", away: "NGA" },
  "England Total Goals" => { team: "ENG", opponent: "TUR", home: "ENG", away: "TUR" },
  "Portugal Total Goals" => { team: "POR", opponent: "SVN", home: "POR", away: "SVN" },
  "Netherlands Total Goals" => { team: "NED", opponent: "SEN", home: "NED", away: "SEN" },
  "Belgium Total Goals" => { team: "BEL", opponent: "KSA", home: "BEL", away: "KSA" },
  "Uruguay Total Goals" => { team: "URU", opponent: "KOR", home: "URU", away: "KOR" },
  "Mexico Total Goals" => { team: "MEX", opponent: "ECU", home: "MEX", away: "ECU" },
  "USA Total Goals" => { team: "USA", opponent: "BOL", home: "USA", away: "BOL" },
  "Japan Total Goals" => { team: "JPN", opponent: "COL", home: "JPN", away: "COL" },
  "South Korea Total Goals" => { team: "KOR", opponent: "URU", home: "URU", away: "KOR" },
  "Croatia Total Goals" => { team: "CRO", opponent: "DEN", home: "CRO", away: "DEN" },
  "Senegal Total Goals" => { team: "SEN", opponent: "NED", home: "NED", away: "SEN" },
}

prop_defs = [
  ["Argentina Total Goals", 1.5],
  ["Brazil Total Goals", 1.5],
  ["France Total Goals", 1.5],
  ["Germany Total Goals", 1.5],
  ["Spain Total Goals", 2.5],
  ["England Total Goals", 1.5],
  ["Portugal Total Goals", 1.5],
  ["Netherlands Total Goals", 1.5],
  ["Belgium Total Goals", 1.5],
  ["Uruguay Total Goals", 0.5],
  ["Mexico Total Goals", 0.5],
  ["USA Total Goals", 1.5],
  ["Japan Total Goals", 0.5],
  ["South Korea Total Goals", 0.5],
  ["Croatia Total Goals", 1.5],
  ["Senegal Total Goals", 0.5],
]

props = prop_defs.map do |desc, line|
  mapping = PROP_TEAM_MAP[desc]
  team = mapping ? teams[mapping[:team]] : nil
  opponent = mapping ? teams[mapping[:opponent]] : nil
  game = if mapping
    home_team = teams[mapping[:home]]
    away_team = teams[mapping[:away]]
    Game.find_by(home_team_slug: home_team&.slug, away_team_slug: away_team&.slug)
  end

  prop = Prop.find_or_create_by!(contest: contest, description: desc) do |p|
    p.line = line
    p.stat_type = "goals"
    p.team_slug = team&.slug
    p.opponent_team_slug = opponent&.slug
    p.game_slug = game&.slug
  end

  # Update existing props that didn't have slugs
  if prop.team_slug.blank? && team
    prop.update_columns(
      team_slug: team.slug,
      opponent_team_slug: opponent&.slug,
      game_slug: game&.slug
    )
  end

  prop
end

puts "  Created #{props.size} props"

# Entries with random picks for Alex and Jordan
[alex, jordan].each do |user|
  next if Entry.exists?(user: user, contest: contest)

  entry = Entry.create!(user: user, contest: contest)
  user.deduct_funds!(contest.entry_fee_cents)

  props.each do |prop|
    entry.picks.create!(
      prop: prop,
      selection: ["more", "less"].sample
    )
  end

  puts "  Created entry for #{user.display_name} with #{entry.picks.count} picks"
end

puts "Done! #{User.count} users, #{Contest.count} contests, #{Prop.count} props, #{Entry.count} entries, #{Pick.count} picks"
puts "  #{Team.count} teams, #{Game.count} games, #{Player.count} players"
