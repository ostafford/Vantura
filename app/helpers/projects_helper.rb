module ProjectsHelper
  def format_cents(cents)
    number_to_currency((cents || 0) / 100.0)
  end

  def can_toggle_paid?(contribution)
    contribution.user_id == Current.user&.id
  end
end


