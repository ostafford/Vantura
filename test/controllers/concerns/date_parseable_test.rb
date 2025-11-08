require "test_helper"

class DateParseableTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  class DummyController
    include DateParseable

    attr_reader :year, :month, :date

    def initialize(params = {})
      @params = ActionController::Parameters.new(params)
    end

    def parse
      send(:parse_month_params)
      self
    end

    private

    attr_reader :params
  end

  test "defaults to current month when params missing" do
    travel_to Date.new(2024, 5, 10) do
      controller = DummyController.new.parse

      assert_equal 2024, controller.year
      assert_equal 5, controller.month
      assert_equal Date.new(2024, 5, 1), controller.date
    end
  end

  test "uses provided year while falling back to current month when month is invalid" do
    travel_to Date.new(2024, 6, 10) do
      controller = DummyController.new(year: "2023", month: "abc").parse

      assert_equal 2023, controller.year
      assert_equal 6, controller.month
      assert_equal Date.new(2023, 6, 1), controller.date
    end
  end

  test "clamps month within calendar bounds" do
    controller = DummyController.new(year: 2024, month: 13).parse

    assert_equal 12, controller.month
    assert_equal Date.new(2024, 12, 1), controller.date

    controller = DummyController.new(year: 2024, month: 0).parse

    assert_equal 1, controller.month
    assert_equal Date.new(2024, 1, 1), controller.date
  end

  test "clamps day to valid range for month" do
    controller = DummyController.new(year: 2024, month: 2, day: 30).parse

    assert_equal Date.new(2024, 2, 29), controller.date

    controller = DummyController.new(year: 2023, month: 2, day: -5).parse

    assert_equal Date.new(2023, 2, 1), controller.date
  end

  test "keeps valid day when provided" do
    controller = DummyController.new(year: 2024, month: 4, day: 15).parse

    assert_equal Date.new(2024, 4, 15), controller.date
  end

  test "falls back to current year when year is invalid" do
    travel_to Date.new(2025, 3, 5) do
      controller = DummyController.new(year: "", month: 1, day: 2).parse

      assert_equal 2025, controller.year
      assert_equal 1, controller.month
      assert_equal Date.new(2025, 1, 2), controller.date
    end
  end
end
