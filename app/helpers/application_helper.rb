module ApplicationHelper
  # Pagy 4.x: Frontend methods are now instance methods on Pagy objects
  # Create wrapper helpers for backward compatibility with views

  def pagy_nav(pagy, **options)
    return "" unless pagy
    pagy.series_nav(**options)
  end

  def pagy_info(pagy, **options)
    return "" unless pagy
    pagy.info_tag(**options)
  end
end
