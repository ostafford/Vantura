require "test_helper"

class RecurringTransactionsProjectorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "returns projected structure keys" do
    start_date = Date.today.beginning_of_month
    end_date = Date.today.end_of_month

    result = RecurringTransactions::Projector.call(account: @account, start_date: start_date, end_date: end_date)

    assert result.is_a?(Hash)
    %i[expenses income expense_total income_total].each do |k|
      assert result.key?(k), "expected #{k} in projector result"
    end
  end
end


