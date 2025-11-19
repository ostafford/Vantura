module ProjectsHelper
  def format_cents(cents)
    number_to_currency((cents || 0) / 100.0)
  end

  def can_toggle_paid?(contribution)
    contribution.user_id == Current.user&.id
  end

  # Format percentage change with sign and appropriate styling
  # Returns HTML-safe string with +/- sign and color classes
  def format_percentage_change(change_pct)
    return content_tag(:span, "N/A", class: "text-neutral-muted") if change_pct.nil?

    # Round to 1 decimal place if not already
    value = change_pct.is_a?(Numeric) ? change_pct.round(1) : 0.0

    # Determine if positive or negative
    is_positive = value >= 0
    sign = is_positive ? "+" : ""

    # Color classes based on direction
    color_class = is_positive ? "amount-positive" : "amount-negative"

    content_tag(:span, "#{sign}#{value}%", class: "font-semibold #{color_class}")
  end

  def can_manage_members?(project)
    return false unless Current.user
    return true if project.owner_id == Current.user.id
    project.project_memberships.where(user_id: Current.user.id, access_level: ProjectMembership.access_levels[:full]).exists?
  end

  # Render top categories list for stat cards
  # categories: Array of {category: "Name", total_cents: 12345}
  # total_cents: Total amount for percentage calculation
  def render_top_categories(categories, total_cents = nil)
    return nil if categories.blank? || categories.empty?

    # Build array of category divs
    category_divs = categories.map do |cat_data|
      category_name = (cat_data[:category] || cat_data["category"] || "Uncategorized").to_s
      cat_total = cat_data[:total_cents] || cat_data["total_cents"] || 0

      # Calculate percentage if total is provided
      percentage = if total_cents && total_cents > 0
        ((cat_total.to_f / total_cents) * 100).round(1)
      end

      percentage_text = percentage ? " • #{percentage}%" : ""

      content_tag(:div, class: "flex items-center justify-between text-xs") do
        content_tag(:span, class: "text-neutral-muted") do
          content_tag(:span, h(category_name), class: "font-medium text-neutral-label") +
          (percentage ? content_tag(:span, percentage_text, class: "text-neutral-muted") : "".html_safe)
        end +
        content_tag(:span, format_cents(cat_total), class: "font-semibold text-neutral-label")
      end
    end

    # Wrap in container div with spacing
    content_tag(:div, safe_join(category_divs), class: "mt-3 space-y-1.5")
  end
end
