require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  # Association tests
  test "should have many sessions" do
    assert_respond_to @user, :sessions
  end

  test "should have many accounts" do
    assert_respond_to @user, :accounts
  end

  test "should destroy dependent sessions when user is destroyed" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test")

    assert_difference "Session.count", -1 do
      user.destroy
    end
  end

  test "should destroy dependent accounts when user is destroyed" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    account = user.accounts.create!(
      up_account_id: "test_account_123",
      display_name: "Test Account",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0
    )

    assert_difference "Account.count", -1 do
      user.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    user = User.new(
      email_address: "valid@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "should require email_address" do
    @user.email_address = nil
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test "should require unique email_address" do
    duplicate_user = User.new(
      email_address: @user.email_address,
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  test "should require valid email format" do
    invalid_emails = [ "invalid", "invalid@", "@example.com", "invalid.example.com" ]
    invalid_emails.each do |email|
      @user.email_address = email
      assert_not @user.valid?, "#{email} should be invalid"
      assert_includes @user.errors[:email_address], "is invalid"
    end
  end

  test "should accept valid email formats" do
    valid_emails = [ "user@example.com", "user.name@example.co.uk", "user+tag@example.com" ]
    valid_emails.each do |email|
      user = User.new(
        email_address: email,
        password: "password123",
        password_confirmation: "password123"
      )
      assert user.valid?, "#{email} should be valid"
    end
  end

  test "should require password with minimum length of 8" do
    @user.password = "short"
    @user.password_confirmation = "short"
    assert_not @user.valid?
    assert_includes @user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "should normalize email_address" do
    user = User.create!(
      email_address: "  TeSt@ExAmPlE.cOm  ",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_equal "test@example.com", user.email_address
  end

  # Encryption tests
  test "should encrypt up_bank_token" do
    @user.update!(up_bank_token: "secret_token_123")
    # The token should be encrypted in the database
    raw_token = User.connection.select_value(
      "SELECT up_bank_token FROM users WHERE id = #{@user.id}"
    )
    assert_not_equal "secret_token_123", raw_token
  end

  test "should decrypt up_bank_token" do
    @user.update!(up_bank_token: "secret_token_123")
    assert_equal "secret_token_123", @user.reload.up_bank_token
  end

  # Custom validation tests
  test "should not require token if user has no accounts" do
    user = User.new(
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "should require token if user has accounts" do
    user = User.create!(
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    user.accounts.create!(
      up_account_id: "test_account_456",
      display_name: "Test Account",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0
    )

    user.up_bank_token = nil
    assert_not user.valid?
    assert_includes user.errors[:up_bank_token], "can't be blank"
  end

  # has_secure_password tests
  test "should authenticate with correct password" do
    user = User.create!(
      email_address: "auth@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.authenticate("password123")
  end

  test "should not authenticate with incorrect password" do
    user = User.create!(
      email_address: "auth@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.authenticate("wrong_password")
  end
end
