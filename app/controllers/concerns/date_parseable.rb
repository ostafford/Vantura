module DateParseable
  extend ActiveSupport::Concern

  private

  # Parse year, month, and optionally day from params, defaulting to current date
  # Sets @year, @month, and @date instance variables
  # @date is set to the first day of the parsed month, or specific day if provided
  def parse_month_params
    today = Date.current
    @year = normalize_year(params[:year], today.year)
    @month = normalize_month(params[:month], today.month)
    day = normalize_day(params[:day], @year, @month)

    # Use specific day if provided (for week view), otherwise default to valid day in month
    @date = Date.new(@year, @month, day)
  rescue ArgumentError
    # Handle unexpected invalid dates by using the 1st of the month
    @date = Date.new(@year, @month, 1)
  end

  # Get the start and end dates for the current parsed month
  # Requires parse_month_params to be called first
  # @return [Array<Date>] [start_date, end_date]
  def month_date_range
    [ @date.beginning_of_month, @date.end_of_month ]
  end

  def normalize_year(value, fallback)
    parsed = parse_integer(value)
    return fallback unless parsed&.positive?

    parsed
  end

  def normalize_month(value, fallback)
    parsed = parse_integer(value)
    return fallback unless parsed

    parsed.clamp(1, 12)
  end

  def normalize_day(value, year, month)
    parsed = parse_integer(value)
    parsed = 1 unless parsed&.positive?

    max_day = Date.civil(year, month, -1).day
    parsed.clamp(1, max_day)
  rescue ArgumentError
    1
  end

  def parse_integer(value)
    Integer(value, exception: false)
  end
end
