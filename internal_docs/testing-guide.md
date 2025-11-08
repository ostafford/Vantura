# Testing Guide

This guide documents testing patterns and practices used in the Vantura application.

## Testing Philosophy

We follow the Test Pyramid:
- **70% Unit Tests** - Models, service objects, helpers
- **20% Integration Tests** - Controllers, request/response cycles
- **10% System Tests** - End-to-end user flows

## Test Coverage Strategy

**Hybrid Approach:**
- **Comprehensive coverage** for service objects (100% critical business logic)
- **Critical paths** for controllers (REST actions, authentication, authorization)
- **Complete coverage** for models (validations, associations, scopes, methods)

### Coverage Targets

- **≥80%** overall coverage
- **100%** critical business logic (service objects)
- **90%+** models
- **70%+** controllers

## Running Tests

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/project_test.rb

# Run specific test
rails test test/models/project_test.rb:12

# Run with verbose output
rails test --verbose

# Run system tests
rails test:system

# Generate coverage report
rails test
open coverage/index.html
```

## Test Organization

### Directory Structure

```
test/
├── controllers/          # Controller tests
├── models/              # Model tests
├── services/            # Service object tests
├── system/              # System tests
├── fixtures/            # Test data
└── test_helper.rb       # Test configuration
```

## Model Tests

### Structure

```ruby
require "test_helper"

class ModelTest < ActiveSupport::TestCase
  def setup
    @resource = resources(:one)
  end

  # Association tests
  test "should belong to parent" do
    assert_respond_to @resource, :parent
  end

  # Validation tests
  test "should require attribute" do
    @resource.attribute = nil
    assert_not @resource.valid?
  end

  # Scope tests
  test "scope returns correct records" do
    results = Model.scope_name
    assert results.all? { |r| r.condition }
  end

  # Method tests
  test "method returns expected value" do
    assert_equal expected, @resource.method_name
  end
end
```

### Best Practices

- Test all validations (presence, length, format, uniqueness, numericality)
- Test all associations (belongs_to, has_many, has_many :through)
- Test all scopes return correct records
- Test all public instance methods
- Test edge cases and error conditions
- Use fixtures for test data

## Controller Tests

### Structure

```ruby
require "test_helper"

class ControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
  end

  test "should get index" do
    get resource_url
    assert_response :success
  end

  test "should create with valid params" do
    assert_difference("Resource.count", 1) do
      post resource_url, params: { resource: { ... } }
    end
    assert_redirected_to resource_url(Resource.last)
  end

  test "requires authentication" do
    delete session_url
    get resource_url
    assert_redirected_to new_session_url
  end
end
```

### Best Practices

- Test all REST actions (index, show, new, create, edit, update, destroy)
- Test authentication requirements
- Test authorization (users can only access their own resources)
- Test service object integration (indirectly through responses)
- Test HTTP status codes (422 for validation errors)
- Test redirects and flash messages

## Service Object Tests

### Structure

```ruby
require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
  end

  test "returns expected structure" do
    result = Service.call(@project)
    
    assert_instance_of Hash, result
    assert_includes result, :expected_key
  end

  test "calculates correctly" do
    # Setup test data
    @project.project_expenses.create!(total_cents: 10000)
    
    result = Service.call(@project)
    assert_equal 10000, result[:total]
  end

  test "handles edge cases" do
    # Test with empty data
    result = Service.call(@project)
    assert_equal 0, result[:total]
  end

  test "handles invalid input" do
    assert_raises(ArgumentError) do
      Service.call(nil)
    end
  end
end
```

### Best Practices

- Test happy path first
- Test edge cases (empty data, nil values, boundary conditions)
- Test error conditions
- Test return structure (keys present, correct types)
- Use descriptive test names
- Keep tests independent

## System Tests

### Structure

```ruby
require "application_system_test_case"

class FeatureTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    sign_in_user(@user)
  end

  test "user can complete workflow" do
    visit root_path
    click_link "New Resource"
    fill_in "Name", with: "Test"
    click_button "Create"
    
    assert_text "Test"
  end

  private

  def sign_in_user(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end
end
```

### Best Practices

- Test critical user flows end-to-end
- Test JavaScript interactions (modals, dropdowns, forms)
- Test Turbo Frame/Stream updates
- Use descriptive selectors (IDs preferred)
- Wait for asynchronous operations
- Test error handling in UI

## Fixtures

### Structure

```yaml
# test/fixtures/models.yml
one:
  attribute: value
  association: referenced_fixture

two:
  attribute: different_value
  association: referenced_fixture
```

### Best Practices

- Use fixtures for simple, fast test data
- Create realistic test data
- Use ERB for dynamic values
- Reference other fixtures properly
- Include edge case fixtures
- Document complex fixtures

## Common Patterns

### Signing In Users

```ruby
# In controller tests
def setup
  sign_in_as(:one)
end

# In system tests
def sign_in_user(user)
  visit new_session_path
  fill_in "email_address", with: user.email_address
  fill_in "password", with: "password"
  click_button "Sign in"
  assert_current_path root_path
end
```

### Testing Service Objects

```ruby
# Direct call
result = Service.call(param1, param2)

# Verify structure
assert_instance_of Hash, result
assert_includes result, :key

# Verify values
assert_equal expected, result[:key]
```

### Testing Controllers

```ruby
# REST actions
get resource_url
post resource_url, params: { resource: { ... } }
patch resource_url(id), params: { resource: { ... } }
delete resource_url(id)

# Verify responses
assert_response :success
assert_response :redirect
assert_response :unprocessable_entity

# Verify redirects
assert_redirected_to resource_url(Resource.last)
```

## Debugging Tests

### Verbose Output

```bash
rails test --verbose
```

### Debugging with byebug

```ruby
test "debugging test" do
  byebug # Execution stops here
  # Use console commands:
  # - `n` (next line)
  # - `s` (step into)
  # - `c` (continue)
  # - `p variable` (print variable)
end
```

### Isolating Failing Tests

```bash
# Run single test
rails test test/models/project_test.rb:12

# Run tests in sequence (not parallel)
rails test --no-parallel
```

## References

- `.cursor/rules/testing/overview/` - General testing guidelines
- `.cursor/rules/testing/model/` - Model testing patterns
- `.cursor/rules/testing/controller_test/` - Controller testing patterns
- `.cursor/rules/testing/system/` - System testing patterns
- `.cursor/rules/testing/fixtures/` - Fixture guidelines

