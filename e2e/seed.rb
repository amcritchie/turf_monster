# Seed test database for Playwright smoke tests.
# Run with: RAILS_ENV=test bin/rails runner e2e/seed.rb
#
# Idempotent — clears and recreates all test data.

puts "Seeding test database for Playwright..."

# Clear in dependency order
Selection.delete_all
Entry.delete_all
ContestMatchup.delete_all
Contest.delete_all
User.delete_all

# Users
alex = User.create!(
  name: "Alex",
  email: "alex@turf.com",
  password: "password",
  password_confirmation: "password",
  balance_cents: 100_000
)

sam = User.create!(
  name: "Sam",
  email: "sam@turf.com",
  password: "password",
  password_confirmation: "password",
  balance_cents: 100_000
)

# Contest
contest = Contest.create!(
  name: "World Cup 2026",
  entry_fee_cents: 1_000,
  status: "open",
  max_entries: 10,
  contest_type: "turf_totals",
  starts_at: 1.week.from_now
)

# Contest matchups (need at least 5 for confirm)
%w[team-a team-b team-c team-d team-e team-f].each_with_index do |slug, i|
  opp = %w[team-b team-a team-d team-c team-f team-e][i]
  contest.contest_matchups.create!(
    team_slug: slug,
    opponent_team_slug: opp,
    rank: i + 1,
    multiplier: (Math.sqrt(i + 1) * 0.5 + 0.5).round(1),
    status: "pending"
  )
end

puts "Seeded: #{User.count} users, #{Contest.count} contests, #{ContestMatchup.count} matchups"
