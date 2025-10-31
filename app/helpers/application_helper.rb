module ApplicationHelper
  # Render transaction status badges (Hypothetical, Pending, Settled)
  def transaction_status_badge(transaction, compact: false)
    if transaction.is_hypothetical
      content_tag :span, "Hypothetical",
        class: compact ?
          "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300" :
          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300"
    elsif transaction.status == "HELD"
      content_tag :span, "Pending",
        class: compact ?
          "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300" :
          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-warning-100 dark:bg-warning-900/30 text-warning-800 dark:text-warning-300"
    else
      content_tag :span, "Settled",
        class: compact ?
          "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300" :
          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-success-100 dark:bg-success-900/30 text-success-800 dark:text-success-300"
    end
  end

  # Render recurring badge if transaction is recurring
  def transaction_recurring_badge(transaction, compact: false)
    return unless transaction.recurring?

    content_tag :span, class: compact ?
      "inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300" :
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-info-100 dark:bg-info-900/30 text-info-800 dark:text-info-300" do
      concat content_tag(:svg, class: "w-3 h-3 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
      end
      concat "Recurring"
    end
  end

  # Format transaction amount with color
  def formatted_transaction_amount(transaction)
    amount = transaction.amount
    color_class = amount < 0 ? "text-expense-600 dark:text-expense-400" : "text-income-600 dark:text-income-400"
    sign = amount < 0 ? "-" : "+"

    content_tag :span, class: color_class do
      "#{sign}$#{number_with_precision(amount.abs, precision: 2)}"
    end
  end

  # Format balance with green for positive, red for negative
  def formatted_balance(balance)
    color_class = balance >= 0 ? "text-success-300 dark:text-success-400" : "text-red-300 dark:text-red-400"
    sign = balance >= 0 ? "" : "-"

    content_tag :span, class: "text-3xl font-bold #{color_class} drop-shadow-md" do
      "#{sign}$#{number_to_currency(balance, unit: '').strip}"
    end
  end

  # Render transaction action buttons (Remove for hypothetical, Make Recurring for real transactions)
  def transaction_action_buttons(transaction)
    if transaction.is_hypothetical && !transaction.recurring?
      # Remove button for hypothetical transactions
      button_to transaction_path(transaction), method: :delete,
          form: { class: "inline-block", data: { turbo_confirm: "Remove this hypothetical transaction?" } },
          class: "inline-flex items-center px-3 py-1 bg-expense-100 dark:bg-expense-900/30 text-expense-700 dark:text-expense-300 rounded-lg hover:bg-expense-200 dark:hover:bg-expense-800 hover:shadow-md hover:scale-105 focus:outline-none focus-visible:ring-2 focus-visible:ring-expense-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-800 active:scale-95 transition-all text-xs font-medium" do
        svg_icon = <<~HTML.html_safe
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
          </svg>
        HTML
        svg_icon + "Remove"
      end
    elsif !transaction.is_hypothetical && !transaction.recurring?
      # Make Recurring button for real transactions
      button_tag type: "button",
          data: {
            action: "click->recurring-modal#open",
            transaction_id: transaction.id,
            description: transaction.description,
            amount: transaction.amount,
            transaction_date: transaction.transaction_date
          },
          class: "inline-flex items-center px-3 py-1 bg-info-100 dark:bg-info-900/30 text-info-700 dark:text-info-300 rounded-lg hover:bg-info-200 dark:hover:bg-info-800 hover:shadow-md hover:scale-105 focus:outline-none focus-visible:ring-2 focus-visible:ring-info-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-800 active:scale-95 transition-all text-xs font-medium" do
        svg_icon = <<~HTML.html_safe
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
        HTML
        svg_icon + "Make Recurring"
      end
    elsif transaction.recurring?
      # Display Recurring badge for recurring transactions
      content_tag :span, class: "inline-flex items-center px-3 py-1 bg-info-100 dark:bg-info-900/30 text-info-700 dark:text-info-300 rounded-lg text-xs font-medium" do
        svg_icon = <<~HTML.html_safe
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
        HTML
        svg_icon + "Recurring"
      end
    end
  end

  # Navigation helpers for persistent nav
  def nav_link_to(text, path, icon:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all"
    active_classes = "bg-primary/10 dark:bg-primary/20 text-primary-700 dark:text-primary-400 border-b-2 border-primary-700 dark:border-primary-400"
    inactive_classes = "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-primary-700 dark:hover:text-primary-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-700 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-900"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes do
      concat nav_icon(icon)
      concat content_tag(:span, text)
    end
  end

  def mobile_nav_link_to(path, icon:, label:)
    active = current_page?(path) || (path == root_path && request.path == "/")

    base_classes = "flex flex-col items-center justify-center gap-1 px-2 py-2 rounded-lg transition-all min-w-0 flex-1"
    active_classes = "text-primary-700 dark:text-primary-400"
    inactive_classes = "text-gray-500 dark:text-gray-400 hover:text-primary-700 dark:hover:text-primary-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-700 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-900"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes do
      concat nav_icon(icon, mobile: true)
      concat content_tag(:span, label, class: "text-xs font-medium truncate max-w-full")
    end
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

    content_tag :svg, class: size_class, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
      icons[icon_name].html_safe
    end
  end

  def user_display_name(user)
    return user&.email_address if user.nil?
    user.respond_to?(:name) && user.name.present? ? user.name : user.email_address
  end
end
