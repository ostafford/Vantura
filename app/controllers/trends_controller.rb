class TrendsController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    nil unless @account

    # Placeholder for future analytics logic
    # For now, just show the page structure
  end
end
