# Seed test database for Playwright smoke tests.
# Run with: RAILS_ENV=test bin/rails runner e2e/seed.rb
#
# Idempotent — clears and recreates all test data.

puts "Seeding test database for Playwright..."

# Clear in dependency order
Pick.delete_all
Entry.delete_all
Prop.delete_all
Contest.delete_all
User.delete_all

# Users
alex = User.create!(
  name: "Alex",
  email: "alex@turf.com",
  password: "pass",
  password_confirmation: "pass",
  balance_cents: 100_000
)

sam = User.create!(
  name: "Sam",
  email: "sam@turf.com",
  password: "pass",
  password_confirmation: "pass",
  balance_cents: 100_000
)

# Contest
contest = Contest.create!(
  name: "World Cup 2026",
  entry_fee_cents: 1_000,
  status: "open",
  max_entries: 10,
  starts_at: 1.week.from_now
)

# Props (need at least 3 for the "confirm" test)
contest.props.create!(description: "Argentina Total Goals", line: 1.5, stat_type: "goals")
contest.props.create!(description: "Brazil Total Goals",     line: 1.5, stat_type: "goals")
contest.props.create!(description: "Germany Total Goals",    line: 2.5, stat_type: "goals")
contest.props.create!(description: "France Total Goals",     line: 2.0, stat_type: "goals")

puts "Seeded: #{User.count} users, #{Contest.count} contests, #{Prop.count} props"
