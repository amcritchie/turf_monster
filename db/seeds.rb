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

# Contest
contest = Contest.find_or_create_by!(name: "World Cup 2026 — Group Stage Day 1") do |c|
  c.entry_fee_cents = 10_00
  c.status = "open"
  c.starts_at = Time.new(2026, 6, 11, 16, 0, 0)
end

puts "  Created contest: #{contest.name}"

# Props
teams = [
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

props = teams.map do |desc, line|
  Prop.find_or_create_by!(contest: contest, description: desc) do |p|
    p.line = line
    p.stat_type = "goals"
  end
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
