# Refactoring Decisions

This document captures architectural decisions made during the Vantura codebase refactoring (Phases 1-6).

## Phase 1: ID Naming Strategy

### Decision
Standardize all HTML IDs to kebab-case format following the pattern: `[context]-[element]-[purpose]`

### Rationale
- Consistent ID naming improves debugging, JavaScript targeting, and maintainability
- Kebab-case is the Rails/HTML standard
- Descriptive IDs make code self-documenting

### Examples
- `mainContent` → `main-content-container`
- `transactionModal` → `transaction-modal`
- `projects_bento_grid` → `projects-bento-grid-section`
- `filter` → `transaction-filter-select`

### Impact
- Updated 20+ view files
- Updated Stimulus controllers to use new IDs
- Improved accessibility with proper label associations

## Phase 2: Controller Refactoring

### Decision
Extract business logic from controllers into service objects, keeping controllers under 10 lines per action

### Rationale
- Controllers should only coordinate, not contain business logic
- Service objects improve testability and reusability
- Follows Rails 8 best practices

### Service Objects Created
1. **Statistics Calculators:**
   - `ProjectStatsCalculator` - MoM/YoY/projections for projects
   - `ProjectsIndexStatisticsService` - Index page statistics
   - `CalendarStatsCalculator` - Calendar view statistics
   - `DashboardStatsCalculator` - Dashboard statistics
   - `TransactionStatsCalculator` - Transaction statistics
   - `TrendsStatsCalculator` - Trends analysis

2. **Data Services:**
   - `ProjectShowDataService` - Project show page data aggregation
   - `CalendarDataService` - Calendar data preparation
   - `TransactionIndexService` - Transaction index data
   - `TransactionSearchService` - Search functionality

3. **Business Logic Services:**
   - `ProjectExpenseTemplatesService` - Template management
   - `RecurringTransactionsService` - Recurring transaction logic
   - `RecurringTransactions::GenerateService` - Generate future transactions
   - `ProjectBarsAggregator` - Chart data aggregation
   - `TransactionFilterService` - Filter logic
   - `TransactionBroadcastService` - Broadcast logic

### Controller Structure
- Maximum 2 instance variables per action
- Maximum 10 lines per action
- Use service objects for all business logic
- Controllers only handle HTTP concerns (params, redirects, rendering)

## Phase 3: Model Organization

### Decision
Reorganize models following Rails conventions: constants, associations, validations, scopes, callbacks, public methods, private methods

### Rationale
- Consistent organization improves readability
- Makes it easier to find specific code
- Follows Rails community standards

### Models Refactored
- `Transaction` - Extracted complex logic to service objects
- `Project` - Reorganized structure
- `ProjectExpense` - Reorganized structure
- `Account` - Reorganized structure
- `Filter` - Reorganized structure
- `RecurringTransaction` - Reorganized structure
- `User` - Reorganized structure

## Phase 4: Stimulus Controller Refactoring

### Decision
Split large controllers, extract shared helpers, use custom events for coordination

### Rationale
- Controllers must be under 200 lines per project standards
- Shared logic should be extracted to helpers
- Custom events enable loose coupling between controllers

### Controllers Split
- `month_nav_controller.js` - Split from combined navigation controller
- `week_nav_controller.js` - Split from combined navigation controller

### Shared Helpers Created
- `app/javascript/helpers/navigation_helper.js` - URL building logic
- `app/javascript/helpers/scroll_helper.js` - Scroll preservation

### Custom Events
- `month:changed` - Dispatched when month changes
- `week:changed` - Dispatched when week changes

## Phase 5: View Structure

### Decision
Use semantic HTML, consistent ID patterns, proper ARIA labels

### Rationale
- Semantic HTML improves accessibility and SEO
- Consistent patterns improve maintainability
- ARIA labels enhance screen reader support

## Phase 6: Performance Optimization

### Decision
Optimize queries, add indexes, use eager loading, implement caching

### Rationale
- Performance is critical for user experience
- Database queries are often the bottleneck
- Caching reduces database load

## Testing Strategy

### Decision
Comprehensive coverage for service objects, critical paths for controllers (Hybrid approach)

### Rationale
- Service objects contain critical business logic - need comprehensive tests
- Controllers are thin coordinators - test critical paths only
- Balances coverage with development speed

### Coverage Targets
- ≥80% overall coverage
- 100% critical business logic
- 90%+ models
- 70%+ controllers

## Service Object Pattern

### Structure
```ruby
class ExampleService < ApplicationService
  def initialize(param1, param2)
    @param1 = param1
    @param2 = param2
  end

  def call
    {
      result: calculate_result,
      metadata: gather_metadata
    }
  end

  private

  def calculate_result
    # Business logic here
  end
end
```

### Usage
```ruby
result = ExampleService.call(param1, param2)
```

## References

- `.cursor/rules/conventions/ID_naming_strategy/` - ID naming standards
- `.cursor/rules/development/rails/controllers.mdc` - Controller rules
- `.cursor/rules/development/rails/models.mdc` - Model rules
- `.cursor/rules/development/hotwire/stimulus_controllers.mdc` - Stimulus rules
- `docs/stimulus-controllers-architecture.md` - Stimulus architecture details

