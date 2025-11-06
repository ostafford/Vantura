# Service Object: Broadcast projects index updates when expenses change
#
# Usage:
#   ProjectExpenseBroadcastService.call(expense)
#
# Broadcasts Turbo Stream updates to update projects index page in real-time
# for all project participants (owner + members)
#
class ProjectExpenseBroadcastService < ApplicationService
  include ProjectsHelper
  include ActionView::Helpers::NumberHelper
  
  def initialize(expense)
    @expense = expense
    @project = expense.project
  end

  def call
    return unless @project # Ensure we have a project

    # Get all affected users (project owner + all members)
    affected_users = @project.participants.uniq

    # Broadcast updates to each affected user
    affected_users.each do |user|
      broadcast_to_user(user)
    end
  end

  private

  def broadcast_to_user(user)
    # Calculate updated stats for this user
    stats = ProjectsIndexStatisticsService.call(user)

    # Extract stats
    projects = stats[:projects]
    total_projects = stats[:total_projects]
    total_expenses_cents = stats[:total_expenses_cents]
    total_expenses = stats[:total_expenses]
    total_participants = stats[:total_participants]
    active_projects = stats[:active_projects]
    largest_expense = stats[:largest_expense]
    most_active_project = stats[:most_active_project]

    # Broadcast hero card update
    broadcast_hero_card(user, total_projects, total_expenses_cents, active_projects, largest_expense, most_active_project)

    # Broadcast stat cards
    broadcast_stat_cards(user, total_projects, total_expenses_cents, total_participants, active_projects)

    # Broadcast table body
    broadcast_table_body(user, projects)
  end

  def broadcast_hero_card(user, total_projects, total_expenses_cents, active_projects, largest_expense, most_active_project)
    largest_expense_formatted = largest_expense ? format_cents(largest_expense.total_cents) : nil
    subtitle = total_expenses_cents > 0 ? format_cents(total_expenses_cents) : "No expenses yet"

    html = ApplicationController.render(
      partial: "projects/broadcast_hero_card",
      locals: {
        total_projects: total_projects,
        subtitle: subtitle,
        active_projects: active_projects,
        largest_expense_formatted: largest_expense_formatted,
        most_active_project: most_active_project
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      target: "projects-hero-card",
      html: html
    )
  end

  def broadcast_stat_cards(user, total_projects, total_expenses_cents, total_participants, active_projects)
    # Total Projects Card
    html = ApplicationController.render(
      partial: "projects/broadcast_stat_card",
      locals: {
        id: "total-projects-card",
        title: "Total Projects",
        value: total_projects.to_s,
        subtitle: "<span class='font-semibold text-gray-900 dark:text-white'>#{active_projects}</span> active".html_safe,
        detail: "Across all projects",
        icon: "chart",
        color: "blue",
        size: "bento-span-1 bento-row-span-2"
      }
    )
    Turbo::StreamsChannel.broadcast_replace_to(user, target: "total-projects-card", html: html)

    # Total Expenses Card
    html = ApplicationController.render(
      partial: "projects/broadcast_stat_card",
      locals: {
        id: "total-expenses-card",
        title: "Total Expenses",
        value: format_cents(total_expenses_cents),
        subtitle: "<span class='font-semibold text-gray-900 dark:text-white'>#{total_projects}</span> projects".html_safe,
        detail: "All time",
        icon: "dollar",
        color: "red",
        size: "bento-span-1 bento-row-span-2"
      }
    )
    Turbo::StreamsChannel.broadcast_replace_to(user, target: "total-expenses-card", html: html)

    # Total Participants Card
    html = ApplicationController.render(
      partial: "projects/broadcast_stat_card",
      locals: {
        id: "total-participants-card",
        title: "Total Participants",
        value: total_participants.to_s,
        subtitle: "<span class='font-semibold text-gray-900 dark:text-white'>#{total_projects}</span> projects".html_safe,
        detail: "Unique members",
        icon: "chart",
        color: "blue",
        size: "bento-span-1 bento-row-span-2"
      }
    )
    Turbo::StreamsChannel.broadcast_replace_to(user, target: "total-participants-card", html: html)

    # Active Projects Card
    html = ApplicationController.render(
      partial: "projects/broadcast_stat_card",
      locals: {
        id: "active-projects-card",
        title: "Active Projects",
        value: active_projects.to_s,
        subtitle: "<span class='font-semibold text-gray-900 dark:text-white'>#{total_projects - active_projects}</span> inactive".html_safe,
        detail: "With expenses",
        icon: "arrow-up",
        color: "green",
        size: "bento-span-1 bento-row-span-2"
      }
    )
    Turbo::StreamsChannel.broadcast_replace_to(user, target: "active-projects-card", html: html)
  end

  def broadcast_table_body(user, projects)
    html = ApplicationController.render(
      partial: "projects/broadcast_table_body",
      locals: {
        projects: projects
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      target: "projects-table-body",
      html: html
    )
  end

end

