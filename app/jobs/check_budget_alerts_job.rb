class CheckBudgetAlertsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    calculator = BudgetCalculator.new(user)
    
    user.budgets.active.each do |budget|
      calculation = calculator.calculate_for_period(budget)
      
      if calculation[:alert_triggered]
        # Check if we've already sent an alert for this period
        last_alert = user.budget_alerts
          .where(budget_id: budget.id)
          .where('created_at >= ?', calculation[:period_start])
          .order(created_at: :desc)
          .first
        
        unless last_alert
          send_budget_alert(user, budget, calculation)
        end
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "User not found for CheckBudgetAlertsJob: #{e.message}"
  rescue => e
    Rails.logger.error "Error in CheckBudgetAlertsJob for user #{user_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def send_budget_alert(user, budget, calculation)
    BudgetAlertMailer.threshold_reached(user, budget, calculation).deliver_later
    
    # Create alert record
    user.budget_alerts.create!(
      budget: budget,
      spent: calculation[:spent],
      limit: calculation[:limit],
      percentage: calculation[:percentage]
    )
  rescue => e
    Rails.logger.error "Failed to send budget alert for user #{user.id}, budget #{budget.id}: #{e.message}"
    raise
  end
end

