module DateParseable
  extend ActiveSupport::Concern

  private

  # Parse year and month from params, defaulting to current date
  # Sets @year, @month, and @date instance variables
  # @date is set to the first day of the parsed month
  def parse_month_params
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @date = Date.new(@year, @month, 1)
  end

  # Get the start and end dates for the current parsed month
  # Requires parse_month_params to be called first
  # @return [Array<Date>] [start_date, end_date]
  def month_date_range
    [@date.beginning_of_month, @date.end_of_month]
  end
end

