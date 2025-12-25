class BudgetAlertMailer < ApplicationMailer
  def threshold_reached(user, budget, calculation)
    @user = user
    @budget = budget
    @calculation = calculation

    mail(
      to: @user.email,
      subject: "Budget Alert: #{@budget.name} - #{@calculation[:percentage].round(1)}% Spent"
    )
  end
end

