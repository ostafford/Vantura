module ApplicationHelper
  # Render transaction status badges (Hypothetical, Pending, Settled)
  def transaction_status_badge(transaction)
    if transaction.is_hypothetical
      content_tag :span, "Hypothetical",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300"
    elsif transaction.status == "HELD"
      content_tag :span, "Pending",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300"
    else
      content_tag :span, "Settled",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300"
    end
  end

  # Render recurring badge if transaction is recurring
  def transaction_recurring_badge(transaction)
    return unless transaction.recurring?

    content_tag :span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300" do
      concat content_tag(:svg, class: "w-3 h-3 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
      end
      concat "Recurring"
    end
  end

  # Format transaction amount with color
  def formatted_transaction_amount(transaction)
    amount = transaction.amount
    color_class = amount < 0 ? "text-red-600 dark:text-red-400" : "text-green-600 dark:text-green-400"
    sign = amount < 0 ? "-" : "+"

    content_tag :span, class: color_class do
      "#{sign}$#{number_with_precision(amount.abs, precision: 2)}"
    end
  end

  # Render transaction action buttons (Remove for hypothetical, Make Recurring for real transactions)
  def transaction_action_buttons(transaction)
    if transaction.is_hypothetical && !transaction.recurring?
      # Remove button for hypothetical transactions
      button_to transaction_path(transaction), method: :delete,
          data: { confirm: "Remove this hypothetical transaction?" },
          class: "inline-flex items-center px-3 py-1 bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300 rounded-lg hover:bg-red-200 dark:hover:bg-red-800 transition-colors text-xs font-medium" do
        concat content_tag(:svg, class: "w-4 h-4 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
        end
        concat "Remove"
      end
    elsif !transaction.is_hypothetical && !transaction.recurring?
      # Make Recurring button for real transactions
      content_tag :button, type: "button",
          data: {
            action: "click->recurring-modal#open",
            transaction_id: transaction.id,
            description: transaction.description,
            amount: transaction.amount,
            transaction_date: transaction.transaction_date
          },
          class: "inline-flex items-center px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded-lg hover:bg-blue-200 dark:hover:bg-blue-800 transition-colors text-xs font-medium" do
        concat content_tag(:svg, class: "w-4 h-4 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
        end
        concat "Make Recurring"
      end
    elsif transaction.recurring?
      # Display Recurring badge for recurring transactions
      content_tag :span, class: "inline-flex items-center px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded-lg text-xs font-medium" do
        concat content_tag(:svg, class: "w-4 h-4 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
        end
        concat "Recurring"
      end
    end
  end
end
