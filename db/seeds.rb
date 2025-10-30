# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# --- Sample data for Projects feature (idempotent) ---
if defined?(User) && defined?(Project)
  owner = User.find_or_create_by!(email_address: "owner@example.com") do |u|
    u.password = "password"
  end
  member = User.find_or_create_by!(email_address: "member@example.com") do |u|
    u.password = "password"
  end

  project = Project.find_or_create_by!(name: "Sample House Project", owner: owner)
  ProjectMembership.find_or_create_by!(project: project, user: member)

  unless project.project_expenses.exists?(merchant: "Electricity Co")
    expense = project.project_expenses.create!(merchant: "Electricity Co", category: "Utilities", total_cents: 12345, due_on: Date.today + 14.days, notes: "Monthly power bill")
    expense.rebuild_contributions!
  end
end
