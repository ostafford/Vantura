module ApplicationHelper
  # Transaction UI Helpers

  # Render transaction status badges (Hypothetical, Pending, Settled)
  def transaction_status_badge(transaction, compact: false)
    badge_id = "transaction-#{transaction.id}-status-badge"
    label, status_class =
      if transaction.is_hypothetical
        [ "Hypothetical", "badge-hypothetical" ]
      elsif transaction.status == "HELD"
        [ "Pending", "badge-pending" ]
      else
        [ "Settled", "badge-settled" ]
      end

    badge_classes = compact ?
      "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium #{status_class}" :
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_class}"

    content_tag :span, label,
      id: badge_id,
      class: badge_classes,
      "aria-label": "Transaction status: #{label}"
  end

  # Render recurring badge if transaction is recurring
  def transaction_recurring_badge(transaction, compact: false)
    return unless transaction.recurring?

    content_tag :span, "Recurring",
      id: "transaction-#{transaction.id}-recurring-badge",
      class: compact ?
        "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium badge-recurring" :
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium badge-recurring",
      "aria-label": "Recurring transaction"
  end

  # Render recurring category badge
  def recurring_category_badge(recurring_transaction, compact: false)
    return unless recurring_transaction.recurring_category.present?

    category_name = recurring_transaction.recurring_category_name
    transaction_type = recurring_transaction.transaction_type

    # Color coding based on transaction type and category
    color_classes = if transaction_type == "income"
      "badge-income"
    else
      "badge-recurring"
    end

    content_tag :span, category_name,
      id: "recurring-transaction-#{recurring_transaction.id}-category-badge",
      class: compact ?
        "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium #{color_classes}" :
        "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{color_classes}",
      "aria-label": "Category: #{category_name}"
  end

  # Format transaction amount with color
  def formatted_transaction_amount(transaction)
    amount = transaction.amount
    color_class = amount_color_class(amount)
    sign = amount < 0 ? "-" : "+"

    content_tag :span, class: color_class do
      "#{sign}$#{number_with_precision(amount.abs, precision: 2)}"
    end
  end

  # Return semantic color class for transaction amounts
  # @param amount [Numeric] Transaction amount (negative = expense, positive = income)
  # @return [String] CSS class name ('amount-negative' or 'amount-positive')
  def amount_color_class(amount)
    amount < 0 ? "amount-negative" : "amount-positive"
  end

  # Format balance with green for positive, red for negative
  def formatted_balance(balance)
    color_class = balance >= 0 ? "amount-positive" : "amount-negative"
    sign = balance >= 0 ? "" : "-"

    content_tag :span, class: "text-3xl font-bold #{color_class}" do
      "#{sign}$#{number_to_currency(balance, unit: '').strip}"
    end
  end

  # Render transaction action buttons (Remove for hypothetical, Make Recurring for real transactions)
  def transaction_action_buttons(transaction)
    if transaction.is_hypothetical && !transaction.recurring?
      # Remove button for hypothetical transactions
      button_to transaction_path(transaction), method: :delete,
          id: "transaction-#{transaction.id}-remove-button",
          form: { class: "inline-block", data: { turbo_confirm: "Remove this hypothetical transaction?" } },
          class: "inline-flex items-center px-3 py-1 btn-destructive text-xs font-medium hover:shadow-md hover:scale-105 focus:outline-none focus-visible:ring-2 focus-visible:ring-expense-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-neutral-900 active:scale-95 transition-all",
          "aria-label": "Remove hypothetical transaction: #{transaction.description}" do
        svg_icon = <<~HTML.html_safe
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
          </svg>
        HTML
        svg_icon + "Remove"
      end
    elsif !transaction.is_hypothetical && !transaction.recurring?
      # Make Recurring button for real transactions
      button_tag type: "button",
          id: "transaction-#{transaction.id}-make-recurring-button",
          data: {
            action: "click->recurring-modal#open",
            transaction_id: transaction.id,
            description: transaction.description,
            amount: transaction.amount,
            transaction_date: transaction.transaction_date
          },
          class: "inline-flex items-center px-3 py-1 btn-info-light text-xs font-medium hover:shadow-md hover:scale-105 focus:outline-none focus-visible:ring-2 focus-visible:ring-info-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-neutral-900 active:scale-95 transition-all",
          "aria-label": "Make transaction recurring: #{transaction.description}" do
        svg_icon = <<~HTML.html_safe
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
        HTML
        svg_icon + "Make Recurring"
      end
    elsif transaction.recurring?
      # Display Recurring badge for recurring transactions
      content_tag :span,
        id: "transaction-#{transaction.id}-recurring-action-badge",
        class: "inline-flex items-center px-3 py-1 badge-recurring rounded-lg text-xs font-medium",
        "aria-label": "Recurring transaction" do
        svg_icon = <<~HTML.html_safe
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
        HTML
        svg_icon + "Recurring"
      end
    end
  end

  # Navigation Helpers

  # Navigation helpers for persistent nav
  def nav_link_to(text, path, icon:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "flex items-center gap-2 px-2 lg:px-3 py-2 rounded-lg text-sm font-medium transition-all nav-link-focus"
    active_classes = "nav-link-active border-b-2 border-primary-700 dark:border-primary-400"
    inactive_classes = "nav-link-inactive"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes do
      concat nav_icon(icon)
      concat content_tag(:span, text, class: "hidden lg:inline")
    end
  end

  def mobile_nav_link_to(path, icon:, label:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "flex flex-col items-center justify-center gap-1 px-2 py-2 rounded-lg transition-all min-w-0 flex-1 nav-link-focus"
    active_classes = "nav-link-mobile-active"
    inactive_classes = "nav-link-mobile-inactive"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes do
      concat nav_icon(icon, mobile: true)
      concat content_tag(:span, label, class: "text-xs font-medium truncate max-w-full")
    end
  end

  def mobile_drawer_nav_link_to(text, path, icon:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "flex items-center gap-3 px-6 py-3 text-base font-medium transition-all nav-link-focus"
    active_classes = "nav-link-active"
    inactive_classes = "nav-link-inactive"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes do
      concat nav_icon(icon, mobile: true)
      concat content_tag(:span, text)
    end
  end

  def sidebar_nav_link_to(text, path, icon:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "relative flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-all group sidebar-nav-link nav-link-focus"
    active_classes = "nav-link-active"
    inactive_classes = "nav-link-inactive"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes, title: text do
      concat nav_icon(icon, mobile: false)
      concat content_tag(:span, text, class: "sidebar-label whitespace-nowrap")
      if active
        concat content_tag(:span, "", class: "absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-primary-700 dark:bg-primary-400 rounded-r-full")
      end
    end
  end

  def navbar_nav_link_to(text, path, icon:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "relative flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all whitespace-nowrap flex-shrink-0 nav-link-focus"
    active_classes = "nav-link-active"
    inactive_classes = "nav-link-inactive"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes, title: text do
      concat nav_icon(icon, mobile: false)
      concat content_tag(:span, text)
    end
  end

  # Layout Helpers

  # Reusable content wrapper following DRY principles
  # Provides consistent responsive padding and max-width across all pages
  def content_wrapper(options = {}, &block)
    classes = "max-w-[1920px] mx-auto px-4 sm:px-6 lg:px-8 xl:px-12 2xl:px-16"
    classes = "#{classes} #{options[:class]}" if options[:class]

    tag_options = { class: classes }
    tag_options.merge!(options[:data]) if options[:data]

    content_tag :div, tag_options, &block
  end

  def nav_icon(icon_name, mobile: false)
    size_class = mobile ? "w-6 h-6" : "w-5 h-5"

    icons = {
      "home" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>',
      "calendar" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>',
      "chart" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>',
      "list" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>',
      "refresh" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>',
      "settings" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>',
      "folder" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7a2 2 0 012-2h3l2 2h9a2 2 0 012 2v7a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"></path>'
    }

    content_tag :svg, class: "#{size_class} flex-shrink-0", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
      icons[icon_name].html_safe
    end
  end

  # User Helpers

  def user_display_name(user)
    return user&.email_address if user.nil?
    user.respond_to?(:name) && user.name.present? ? user.name : user.email_address
  end

  # Date Helpers

  # Calculate days remaining in a month
  # @param date [Date] Date to calculate from
  # @return [Integer] Days remaining in the month
  def days_remaining_in_month(date)
    date.end_of_month.day - date.day
  end

  # Formatting Helpers

  # Calculate spending pace metrics for a given month
  # Delegates to SpendingPaceCalculator service object
  # @param transactions_data [Hash] Hash containing :date, :expense_total keys
  # @return [Hash] Hash with spending pace calculations:
  #   - is_current_month [Boolean] Whether viewing current month
  #   - days_elapsed [Integer] Days elapsed in the month
  #   - days_in_month [Integer] Total days in the month
  #   - month_progress [Float] Percentage of month elapsed (0-100)
  #   - expected_expenses [Float] Expected expenses for full month
  #   - spending_rate [Float] Spending rate percentage (0-100+)
  def calculate_spending_pace(transactions_data)
    SpendingPaceCalculator.calculate(transactions_data)
  end

  # Return background class for transaction card based on transaction amount and type
  # @param transaction [Transaction] Transaction to get background class for
  # @return [String] Tailwind CSS classes for card background
  def transaction_card_bg_class(transaction)
    # Planning/projection background for hypothetical transactions
    return "projection-surface" if transaction.is_hypothetical

    # Color-coded based on amount
    amount = transaction.amount
    if amount > 0
      "amount-positive-bg"
    elsif amount < 0
      "amount-negative-bg"
    else
      "surface-card-base"
    end
  end

  # Format percentage change with trend indicator
  # Delegates to TrendCalculator service object
  # @param current [Numeric] Current value
  # @param previous [Numeric] Previous value
  # @param context [String] Context for determining if increase is good ('expense', 'income', 'neutral')
  # @return [Hash] Hash with :change, :change_pct, :trend_icon, :trend_color, :formatted, :is_positive
  def calculate_change(current, previous, context: "neutral")
    TrendCalculator.calculate_change(current, previous, context: context)
  end

  # Format trend indicator with icon and color
  # @param change_data [Hash] Result from calculate_change
  # @return [String] HTML-safe string with trend indicator
  def trend_indicator(change_data)
    return content_tag(:span, "→", class: "text-neutral-muted") if change_data.nil?

    content_tag(:span, change_data[:trend_icon], class: "font-bold #{change_data[:trend_color]}")
  end

  # Format percentage change for display with context-aware coloring
  # @param change_pct [Numeric] Percentage change
  # @param context [String] Context for determining if increase is good ('expense', 'income', 'neutral')
  # @return [String] HTML-safe formatted percentage
  def format_trend_percentage(change_pct, context: "neutral")
    return content_tag(:span, "N/A", class: "text-neutral-muted") if change_pct.nil?

    value = change_pct.is_a?(Numeric) ? change_pct.round(1) : 0.0
    sign = value >= 0 ? "+" : ""

    # Determine color based on context
    is_positive = case context
    when "expense"
      value.negative? # Spending less is good
    when "income"
      value.positive? # Earning more is good
    else
      value.positive?
    end

    color_class = if is_positive
      "amount-positive"
    elsif value.zero?
      "text-neutral-muted"
    else
      "amount-negative"
    end

    content_tag(:span, "#{sign}#{value}%", class: "font-semibold #{color_class}")
  end
end
