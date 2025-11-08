# Test Coverage Report - Phase 7 Baseline

**Date:** 2025-11-06  
**Test Suite Status:** ✅ 263 tests, 516 assertions, 0 failures, 0 errors, 23 skips

## Coverage Targets

Per `.cursor/rules/testing/overview/test_coverage.mdc`:
- **≥80%** overall coverage
- **100%** critical business logic
- **90%+** models
- **70%+** controllers

## Current State

### Controllers

**Total Controllers:** 19  
**Tested Controllers:** 3  
**Controllers Needing Tests:** 16  

**Existing Tests:**
- ✅ `calendar_controller_test.rb`
- ✅ `dashboard_controller_test.rb`
- ✅ `filters_controller_test.rb`

**Critical Controllers Needing Tests (8):**
1. `ProjectsController` - CRITICAL - Core feature, refactored in Phase 2
2. `ProjectExpensesController` - CRITICAL - Core feature, refactored in Phase 2
3. `TransactionsController` - CRITICAL - Core feature, refactored in Phase 2
4. `DashboardController` - CRITICAL - Main entry point (exists, verify completeness)
5. `CalendarController` - CRITICAL - Core feature (exists, verify completeness)
6. `RecurringTransactionsController` - CRITICAL - Core feature
7. `SessionsController` - CRITICAL - Authentication/security
8. `AccountController` - CRITICAL - User data management

**Lower Priority Controllers (8):**
- `AnalysisController` - Analysis logic (can add later)
- `TrendsController` - Trends logic (can add later)
- `FiltersController` - Filter logic (exists, verify only)
- `SettingsController` - Settings management (can add later)
- `RegistrationsController` - Registration (can add later)
- `PasswordsController` - Password reset (can add later)
- `ProjectMembershipsController` - Membership management (can add later)
- `ExpenseContributionsController` - Contribution logic (can add later)
- `Projects::StatsController` - Stats endpoint (can add later)
- `HealthController` - Health check (low priority)

### Service Objects

**Total Service Objects:** 19  
**Tested Services:** 6  
**Services Needing Tests:** 14  

**Existing Tests:**
- ✅ `dashboard_stats_calculator_test.rb`
- ✅ `transaction_broadcast_service_test.rb`
- ✅ `transaction_filter_service_test.rb`
- ✅ `transaction_merchant_service_test.rb`
- ✅ `transaction_stats_calculator_test.rb`
- ✅ `trends_stats_calculator_test.rb`

**Statistics Calculators Needing Tests (CRITICAL - 3):**
1. `ProjectStatsCalculator` - Calculate MoM/YoY/projections
2. `ProjectsIndexStatisticsService` - Index page statistics
3. `CalendarStatsCalculator` - Calendar view statistics
4. `DashboardStatsCalculator` - Dashboard statistics (exists, verify completeness)

**Data Services Needing Tests (HIGH - 4):**
5. `ProjectShowDataService` - Project show page data aggregation
6. `CalendarDataService` - Calendar data preparation
7. `TransactionIndexService` - Transaction index data
8. `TransactionSearchService` - Search functionality

**Business Logic Services Needing Tests (MEDIUM - 4):**
9. `ProjectExpenseTemplatesService` - Template management
10. `RecurringTransactionsService` - Recurring transaction logic
11. `RecurringTransactions::GenerateService` - Generate future transactions
12. `ProjectBarsAggregator` - Chart data aggregation

**External Services (LOW - 2):**
13. `Up::Bank::SyncService` - Up Bank sync logic
14. `Up::Bank::Client` - API client (if business logic exists)

### Models

**Total Models:** 13  
**Tested Models:** 7  
**Models Needing Coverage Verification:** 7  

**Existing Tests:**
- ✅ `account_test.rb`
- ✅ `filter_test.rb`
- ✅ `project_expense_test.rb`
- ✅ `recurring_transaction_test.rb`
- ✅ `transaction_query_helpers_test.rb`
- ✅ `transaction_test.rb`
- ✅ `user_test.rb`

**Models Refactored in Phase 3 (Need Coverage Verification):**
1. `Transaction` - Reorganized structure, extracted logic
2. `Project` - Structure reorganization (NO TEST FILE)
3. `ProjectExpense` - Structure reorganization (test exists)
4. `Account` - Structure reorganization (test exists)
5. `Filter` - Structure reorganization (test exists)
6. `RecurringTransaction` - Structure reorganization (test exists)
7. `User` - Structure reorganization (test exists)
8. `ProjectMembership` - (NO TEST FILE)
9. `ExpenseContribution` - (NO TEST FILE)

### System Tests

**Total System Tests:** 3  
**System Tests Existing:**
- ✅ `dashboard_test.rb`
- ✅ `transaction_workflow_test.rb`
- ✅ `user_authentication_test.rb`

**System Tests Needed for Refactored Features:**
1. ID Naming Changes (Phase 1) - Form submissions, JavaScript interactions, Turbo Frame/Stream targets
2. Controller Refactoring (Phase 2) - Service object integration, user flows, error handling
3. Stimulus Controller Refactoring (Phase 4) - Modal/drawer interactions, calendar navigation, month/week navigation

## Coverage Gaps Summary

### Critical Gaps (Must Fix)

**Controllers:**
- 8 critical controllers without tests or incomplete tests

**Services:**
- 3 critical statistics calculators without tests
- 4 high-priority data services without tests

**Models:**
- `Project` model has no test file
- `ProjectMembership` model has no test file
- `ExpenseContribution` model has no test file

### Medium Priority Gaps

**Services:**
- 4 business logic services without tests

**System Tests:**
- Refactored features need system test coverage

### Low Priority Gaps

**Services:**
- External services (Up Bank) can be tested later if complex logic exists

**Controllers:**
- Lower priority controllers can be tested incrementally

## Next Steps

1. ✅ Install SimpleCov - DONE
2. ✅ Generate baseline coverage report - DONE
3. ⏳ Add tests for 14 service objects (focus on critical calculators first)
4. ⏳ Add tests for 8 critical controllers (focus on refactored controllers)
5. ⏳ Verify/update model tests (especially missing Project model test)
6. ⏳ Add system tests for refactored features
7. ⏳ Update test fixtures to support new tests
8. ⏳ Re-run coverage report and verify targets met

## Notes

- SimpleCov configuration complete with proper grouping
- Test suite runs successfully (263 tests, 0 failures)
- Coverage report generated at `coverage/index.html`
- Focus on critical paths per plan (Option C: comprehensive for services, critical paths for controllers)

