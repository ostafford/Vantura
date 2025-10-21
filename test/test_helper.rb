ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    # Helper to sign in a user for tests
    def sign_in_as(user)
      session_record = sessions(user.to_sym)
      # For integration tests, we need to use signed cookies via post request
      # Simulate what happens when a user logs in
      post session_url, params: {
        email_address: users(user.to_sym).email_address,
        password: "password"
      }
    end
  end
end
