# Seed test database for Playwright smoke tests.
# Run with: RAILS_ENV=test bin/rails runner e2e/seed.rb
#
# Idempotent — clears and recreates all test data.

puts "Seeding test database for Playwright..."

# Clear in dependency order
TransactionLog.delete_all
GeoSetting.delete_all
Selection.delete_all
Entry.delete_all
SlateMatchup.delete_all
Contest.delete_all
Slate.delete_all
Team.delete_all
User.delete_all

# Users
alex = User.create!(
  name: "Alex",
  username: "alex",
  email: "alex@turf.com",
  password: "password",
  password_confirmation: "password",
  balance_cents: 100_000,
  role: "admin"
)

sam = User.create!(
  name: "Sam",
  username: "sam",
  email: "sam@turf.com",
  password: "password",
  password_confirmation: "password",
  balance_cents: 100_000
)

joe = User.create!(
  name: "Joe",
  username: "joe",
  email: "joe@turf.com",
  password: "password",
  password_confirmation: "password",
  balance_cents: 100_000
)

# Teams (needed for matchup card rendering)
teams = {}
[
  { name: "Team A", short_name: "TMA", slug: "team-a", emoji: "\u{1F1E6}\u{1F1F7}" },
  { name: "Team B", short_name: "TMB", slug: "team-b", emoji: "\u{1F1E7}\u{1F1F7}" },
  { name: "Team C", short_name: "TMC", slug: "team-c", emoji: "\u{1F1E8}\u{1F1F4}" },
  { name: "Team D", short_name: "TMD", slug: "team-d", emoji: "\u{1F1E9}\u{1F1EA}" },
  { name: "Team E", short_name: "TME", slug: "team-e", emoji: "\u{1F1EA}\u{1F1F8}" },
  { name: "Team F", short_name: "TMF", slug: "team-f", emoji: "\u{1F1EB}\u{1F1F7}" },
].each do |attrs|
  teams[attrs[:slug]] = Team.create!(attrs)
end

# Slate
slate = Slate.create!(
  name: "World Cup 2026",
  starts_at: 1.week.from_now
)

# Contest
contest = Contest.create!(
  name: "World Cup 2026",
  entry_fee_cents: 900,
  status: "open",
  max_entries: 5,
  contest_type: "small",
  starts_at: 1.week.from_now,
  slate: slate
)

# Slate matchups (need at least 5 for confirm — creating 6 as 3 game pairs)
# game_slug pairs matchups for the game view layout
game_slugs = %w[game-1 game-1 game-2 game-2 game-3 game-3]
%w[team-a team-b team-c team-d team-e team-f].each_with_index do |slug, i|
  opp = %w[team-b team-a team-d team-c team-f team-e][i]
  slate.slate_matchups.create!(
    team_slug: slug,
    opponent_team_slug: opp,
    game_slug: game_slugs[i],
    rank: i + 1,
    multiplier: SlateMatchup.multiplier_for(i + 1, 6),
    status: "pending"
  )
end

# Set wallet addresses
# Alex uses mock keypair (deterministic seed byte 1) so Playwright tests can sign.
# For devnet smoke tests, SOLANA_BOT_PUBKEY overrides Alex's wallet to Alex Bot's pubkey.
alex_wallet = ENV.fetch("SOLANA_BOT_PUBKEY", "6ASf5EcmmEHTgDJ4X4ZT5vT6iHVJBXPg5AN5YoTCpGWt")
alex.update!(web3_solana_address: alex_wallet)
sam.update!(web3_solana_address: "foUuRyeibadQoGdKXZ9pBGDqmkb1jY1jYsu8dZ29nds")

# Enable onchain path for the seeded contest (directOnchain check needs this)
contest.update!(onchain_contest_id: "MockContestPDA11111111111111111111111111111")

# GeoSetting (disabled by default for most tests)
GeoSetting.create!(
  app_name: Studio.app_name,
  enabled: false,
  banned_states: GeoSetting::DEFAULT_BANNED_STATES
)

puts "Seeded: #{User.count} users, #{Team.count} teams, #{Slate.count} slates, #{Contest.count} contests, #{SlateMatchup.count} matchups, #{GeoSetting.count} geo_settings"
