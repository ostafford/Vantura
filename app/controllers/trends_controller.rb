class TrendsController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account

    preferences = trends_preferences
    store_preferences(preferences[:months], preferences[:view_type])
    stats = TrendsStatsCalculator.call(@account, Date.today, months: preferences[:months], view_type: preferences[:view_type])
    
    # Generate insights with trends context
    insights_service = FinancialInsightsService.new(@account)
    all_insights = insights_service.generate_key_insights_with_trends(5, stats)

    # Filter out dismissed insight types
    dismissed_types = Current.user.dismissed_insight_types || []
    insights = all_insights.reject { |insight| dismissed_types.include?(insight[:type]) }
    @trends_stats = stats.merge(insights: insights)
  end

  def update_preference
    load_account_or_return
    return unless @account

    prefs = preference_params
    store_preferences(prefs[:months], prefs[:view_type]) if prefs[:months] || prefs[:view_type]

    redirect_to trends_path, status: :see_other
  end

  private

  def trends_preferences
    months_param = params[:months] || session[:trends_months] || 6
    {
      months: months_param == "all" ? "all" : months_param.to_i,
      view_type: params[:view_type] || session[:trends_view_type] || "category"
    }
  end

  def store_preferences(months, view_type)
    session[:trends_months] = months if months
    session[:trends_view_type] = view_type if view_type
  end

  def preference_params
    params.permit(:view_type, :months).tap do |permitted|
      permitted[:view_type] = nil unless valid_view_type?(permitted[:view_type])
      permitted[:months] = nil unless valid_months?(permitted[:months])
    end
  end

  def valid_view_type?(type)
    type.present? && %w[category merchant].include?(type)
  end

  def valid_months?(months)
    months.present? && (months == "all" || months.to_i.positive?)
  end
end
