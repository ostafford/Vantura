module Calendar
  class StructureBuilder
    def initialize(date:, month:, week_start: :monday)
      @date = date
      @month = month
      @week_start = week_start
    end

    # Returns [start_date, end_date] for the given view ("week" | "month")
    def date_range_for_view(view)
      case view
      when "week"
        [@date.beginning_of_week(@week_start), @date.end_of_week(@week_start)]
      else
        [@date.beginning_of_month, @date.end_of_month]
      end
    end

    # Builds 7 days for the week view with stable keys and additive iso_date
    def week_days
      days = []
      current_date = @date.beginning_of_week(@week_start)

      7.times do
        days << {
          date: current_date,
          day_name: current_date.strftime("%A"),
          day_number: current_date.day,
          is_today: current_date == Date.today,
          is_current_month: current_date.month == @month,
          iso_date: current_date.iso8601
        }
        current_date += 1.day
      end

      days
    end

    # Builds a matrix of weeks (arrays of 7 days) for the month view
    # with stable keys and additive iso_date
    def month_weeks
      weeks = []
      current_date = @date.beginning_of_month.beginning_of_week(@week_start)
      end_date = @date.end_of_month.end_of_week(@week_start)

      while current_date <= end_date
        week = []
        7.times do
          week << {
            date: current_date,
            in_current_month: current_date.month == @month,
            iso_date: current_date.iso8601
          }
          current_date += 1.day
        end
        weeks << week
      end

      weeks
    end
  end
end


