# Service Object: Generate expense templates from project expenses
#
# Usage:
#   templates = ProjectExpenseTemplatesService.call(project, search_term: params[:q])
#
# Returns array of template hashes with:
#   - merchant: Merchant name
#   - category: Category name
#   - notes: Notes from most recent expense
#   - last_amount: Amount in cents from most recent expense
#
class ProjectExpenseTemplatesService < ApplicationService
  def initialize(project, search_term: nil)
    @project = project
    @search_term = search_term.to_s.downcase.strip
  end

  def call
    templates = build_templates_hash.values.sort_by { |t| -t[:last_created_at] }
    templates = filter_by_search_term(templates) if @search_term.present?
    templates.take(20).map { |t| t.except(:last_created_at) }
  end

  private

  def build_templates_hash
    templates_hash = {}
    @project.project_expenses.order(created_at: :desc).each do |expense|
      key = "#{expense.merchant}|#{expense.category || ''}"
      unless templates_hash[key]
        templates_hash[key] = {
          merchant: expense.merchant,
          category: expense.category,
          notes: expense.notes,
          last_amount: expense.total_cents,
          last_created_at: expense.created_at.to_i
        }
      end
    end
    templates_hash
  end

  def filter_by_search_term(templates)
    templates.select do |template|
      merchant_match = template[:merchant]&.downcase&.include?(@search_term)
      category_match = template[:category]&.downcase&.include?(@search_term)
      merchant_match || category_match
    end
  end
end
