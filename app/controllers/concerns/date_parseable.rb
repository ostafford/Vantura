module DateParseable
  extend ActiveSupport::Concern

  private

  # Parse year, month, and optionally day from params, defaulting to current date
  # Sets @year, @month, and @date instance variables
  # @date is set to the first day of the parsed month, or specific day if provided
  def parse_month_params
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    day = params[:day]&.to_i || 1

    # Use specific day if provided (for week view), otherwise default to 1st of month
    @date = Date.new(@year, @month, day)
  rescue ArgumentError
    # Handle invalid dates (e.g., Feb 30) by using the 1st of the month
    @date = Date.new(@year, @month, 1)
  end

  # Get the start and end dates for the current parsed month
  # Requires parse_month_params to be called first
  # @return [Array<Date>] [start_date, end_date]
  def month_date_range
    [ @date.beginning_of_month, @date.end_of_month ]
  end
end
