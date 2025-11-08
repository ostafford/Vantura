# Vantura Codebase Review Checklist

## ✅Category 1: Controllers
**Review Criteria:**
- Each action <10 lines
- Max 2 instance variables per action
- Business logic extracted to service objects
- Structure: callbacks → actions → private methods
- Proper HTTP status codes (`:unprocessable_entity` for validation errors)

### ✅Main Controllers
- [X] `app/controllers/account_controller.rb`
- [X] `app/controllers/application_controller.rb`
- [X] `app/controllers/calendar_controller.rb`
- [X] `app/controllers/dashboard_controller.rb`
- [X] `app/controllers/expense_contributions_controller.rb`
- [X] `app/controllers/passwords_controller.rb`
- [X] `app/controllers/project_expenses_controller.rb`
- [X] `app/controllers/project_memberships_controller.rb`
- [X] `app/controllers/projects_controller.rb`
- [X] `app/controllers/recurring_transactions_controller.rb`
- [X] `app/controllers/registrations_controller.rb`
- [X] `app/controllers/sessions_controller.rb`
- [X] `app/controllers/settings_controller.rb`
- [X] `app/controllers/transactions_controller.rb`
- [X] `app/controllers/trends_controller.rb`

### ✅Nested Controllers
- [X] `app/controllers/projects/stats_controller.rb`

### ✅Controller Concerns
- [X] `app/controllers/concerns/account_loadable.rb`
- [X] `app/controllers/concerns/authentication.rb`
- [X] `app/controllers/concerns/date_parseable.rb`

---

## ✅Category 2: Models
**Review Criteria:**
- Each model <200 lines
- Structure order: constants → associations → validations → scopes → callbacks → public methods → private methods
- All associations specify `dependent:` option
- Complex business logic extracted to service objects
- Proper use of scopes vs class methods

### Main Models
- [X] `app/models/account.rb`
- [X] `app/models/application_record.rb`
- [X] `app/models/current.rb`
- [X] `app/models/expense_contribution.rb`
- [X] `app/models/filter.rb`
- [X] `app/models/project_expense.rb`
- [X] `app/models/project_membership.rb`
- [X] `app/models/project.rb`
- [X] `app/models/recurring_transaction.rb`
- [X] `app/models/session.rb`
- [X] `app/models/transaction.rb` ⚠️ (267 lines - needs refactoring)
- [X] `app/models/user.rb`

### Model Concerns
- [X] `app/models/concerns/` (check all files in this directory)

---

## Category 3: Views
**Review Criteria:**
- All IDs use kebab-case format: `[context]-[element]-[purpose]`
- No generic IDs (`filter`, `frequency` → use `transaction-filter-select`, etc.)
- Semantic HTML (`<article>`, `<nav>`, `<button>`, proper heading hierarchy)
- All form inputs have matching `label[for]` associations
- Proper ARIA labels for accessibility
- ERB indentation (2 spaces)
- No business logic in views

### Layouts
- [X] `app/views/layouts/application.html.erb`
- [X] `app/views/layouts/mailer.html.erb`
- [X] `app/views/layouts/mailer.text.erb`

### Authentication & Account
- [X] `app/views/registrations/new.html.erb`
- [X] `app/views/sessions/new.html.erb`
- [X] `app/views/passwords/new.html.erb`
- [X] `app/views/passwords/edit.html.erb`
- [ ] `app/views/settings/show.html.erb`

### Dashboard
- [ ] `app/views/dashboard/index.html.erb`
- [ ] `app/views/dashboard/_net_cash_flow_card.html.erb`
- [ ] `app/views/dashboard/_projection_card.html.erb`
- [ ] `app/views/dashboard/_recent_transaction_row.html.erb`

### Calendar
- [ ] `app/views/calendar/index.html.erb`
- [ ] `app/views/calendar/index.turbo_stream.erb`
- [ ] `app/views/calendar/_bento_cards.html.erb`
- [ ] `app/views/calendar/_month_nav_wrapper.html.erb`
- [ ] `app/views/calendar/_month_view.html.erb`
- [ ] `app/views/calendar/_week_view.html.erb`

### Projects
- [ ] `app/views/projects/index.html.erb`
- [ ] `app/views/projects/show.html.erb`
- [ ] `app/views/projects/show.turbo_stream.erb`
- [ ] `app/views/projects/new.html.erb`
- [ ] `app/views/projects/edit.html.erb`
- [ ] `app/views/projects/create.turbo_stream.erb`
- [ ] `app/views/projects/destroy.turbo_stream.erb`
- [ ] `app/views/projects/_form.html.erb`
- [ ] `app/views/projects/_bento_cards.html.erb`
- [ ] `app/views/projects/_project_bento_cards.html.erb`
- [ ] `app/views/projects/_expenses_table.html.erb`

### Project Expenses
- [ ] `app/views/project_expenses/new.html.erb`
- [ ] `app/views/project_expenses/edit.html.erb`
- [ ] `app/views/project_expenses/_form.html.erb`
- [ ] `app/views/project_expenses/create.turbo_stream.erb`
- [ ] `app/views/project_expenses/update.turbo_stream.erb`
- [ ] `app/views/project_expenses/destroy.turbo_stream.erb`
- [ ] `app/views/project_expenses/_projects_stats_update.turbo_stream.erb`

### Transactions
- [ ] `app/views/transactions/index.html.erb`
- [ ] `app/views/transactions/index.turbo_stream.erb`
- [ ] `app/views/transactions/all.html.erb`
- [ ] `app/views/transactions/show.html.erb`
- [ ] `app/views/transactions/edit.html.erb`
- [ ] `app/views/transactions/create.turbo_stream.erb`
- [ ] `app/views/transactions/search.turbo_stream.erb`
- [ ] `app/views/transactions/_bento_cards.html.erb`
- [ ] `app/views/transactions/_table_body.html.erb`

### Recurring Transactions
- [ ] `app/views/recurring_transactions/index.html.erb`
- [ ] `app/views/recurring_transactions/show.html.erb`
- [ ] `app/views/recurring_transactions/edit.html.erb`
- [ ] `app/views/recurring_transactions/_recurring_transaction.html.erb`

### Trends & Analysis
- [ ] `app/views/trends/index.html.erb`
- [ ] `app/views/analysis/index.html.erb`

### Shared Partials
- [ ] `app/views/shared/_details_drawer.html.erb`
- [ ] `app/views/shared/_month_navigation.html.erb`
- [ ] `app/views/shared/_navigation.html.erb`
- [ ] `app/views/shared/_notifications.html.erb`
- [ ] `app/views/shared/_page_header.html.erb`
- [ ] `app/views/shared/_page_header_simple.html.erb`
- [ ] `app/views/shared/_quick_actions.html.erb`
- [ ] `app/views/shared/_recurring_drawer.html.erb`
- [ ] `app/views/shared/_settings_button.html.erb`
- [ ] `app/views/shared/_sidebar.html.erb`
- [ ] `app/views/shared/_sync_complete_notification.html.erb`
- [ ] `app/views/shared/_theme_toggle.html.erb`
- [ ] `app/views/shared/_transaction_drawer.html.erb`

### Shared Bento Cards
- [ ] `app/views/shared/bento_cards/_bar_chart_card.html.erb`
- [ ] `app/views/shared/bento_cards/_chart_card.html.erb`
- [ ] `app/views/shared/bento_cards/_hero_card.html.erb`
- [ ] `app/views/shared/bento_cards/_hypothetical_card.html.erb`
- [ ] `app/views/shared/bento_cards/_projection_card.html.erb`
- [ ] `app/views/shared/bento_cards/_stat_card.html.erb`
- [ ] `app/views/shared/bento_cards/_transaction_type_card.html.erb`
- [ ] `app/views/shared/bento_cards/_week_summary_card.html.erb`
- [ ] `app/views/shared/bento_cards/_week_summary_row.html.erb`

### Shared Transactions
- [ ] `app/views/shared/transactions/_table.html.erb`
- [ ] `app/views/shared/transactions/_row.html.erb`

### Mailers
- [ ] `app/views/passwords_mailer/reset.html.erb`
- [ ] `app/views/passwords_mailer/reset.text.erb`

### PWA
- [ ] `app/views/pwa/manifest.json.erb`
- [ ] `app/views/pwa/service-worker.js`

---

## Category 4: Stimulus Controllers
**Review Criteria:**
- Each controller <200 lines
- No `querySelector` within controller scope (use Stimulus targets)
- `getElementById` only for cross-controller access (documented)
- Proper structure: static properties → lifecycle → actions → helpers
- HTML uses both `data-[controller]-target` AND `id` attributes

### Controllers
- [ ] `app/javascript/controllers/application.js`
- [ ] `app/javascript/controllers/autocomplete_controller.js`
- [ ] `app/javascript/controllers/bento_bar_chart_controller.js`
- [ ] `app/javascript/controllers/calendar_controller.js`
- [ ] `app/javascript/controllers/chart_controller.js`
- [ ] `app/javascript/controllers/expense_row_controller.js`
- [ ] `app/javascript/controllers/expense_template_controller.js`
- [ ] `app/javascript/controllers/filter_controller.js`
- [ ] `app/javascript/controllers/hello_controller.js`
- [ ] `app/javascript/controllers/index.js`
- [ ] `app/javascript/controllers/modal_controller.js` ⚠️ (uses getElementById - needs refactoring)
- [ ] `app/javascript/controllers/month_nav_controller.js` ⚠️ (624 lines - needs splitting)
- [ ] `app/javascript/controllers/notification_controller.js`
- [ ] `app/javascript/controllers/recurring_modal_controller.js`
- [ ] `app/javascript/controllers/sidebar_controller.js`
- [ ] `app/javascript/controllers/sync_controller.js`
- [ ] `app/javascript/controllers/theme_controller.js`
- [ ] `app/javascript/controllers/transactions_nav_controller.js`
- [ ] `app/javascript/controllers/week_nav_controller.js`

---

## Category 5: Services
**Review Criteria:**
- Single responsibility principle
- Proper error handling
- Consistent naming conventions
- Documented with comments if complex logic

### Main Services
- [ ] `app/services/application_service.rb`
- [ ] `app/services/calendar_data_service.rb`
- [ ] `app/services/calendar_stats_calculator.rb`
- [ ] `app/services/dashboard_stats_calculator.rb`
- [ ] `app/services/project_bars_aggregator.rb`
- [ ] `app/services/project_expense_templates_service.rb`
- [ ] `app/services/project_show_data_service.rb`
- [ ] `app/services/project_stats_calculator.rb`
- [ ] `app/services/projects_index_statistics_service.rb`
- [ ] `app/services/recurring_transactions_service.rb`
- [ ] `app/services/transaction_broadcast_service.rb`
- [ ] `app/services/transaction_filter_service.rb`
- [ ] `app/services/transaction_index_service.rb`
- [ ] `app/services/transaction_merchant_service.rb`
- [ ] `app/services/transaction_search_service.rb`
- [ ] `app/services/transaction_stats_calculator.rb`
- [ ] `app/services/trends_stats_calculator.rb`

### Nested Services
- [ ] `app/services/recurring_transactions/generate_service.rb`
- [ ] `app/services/up_bank/client.rb`
- [ ] `app/services/up_bank/sync_service.rb`

---

## Category 6: Helpers
**Review Criteria:**
- Presentation logic only (no business logic)
- Consistent naming and organization
- Proper documentation

### Helpers
- [ ] `app/helpers/application_helper.rb`
- [ ] `app/helpers/bento_cards_helper.rb`
- [ ] `app/helpers/calendar_helper.rb`
- [ ] `app/helpers/dashboard_helper.rb`
- [ ] `app/helpers/filters_helper.rb`
- [ ] `app/helpers/projects_helper.rb`

---

## Category 7: Jobs
**Review Criteria:**
- Proper error handling
- Retry configuration
- Idempotent operations
- Proper logging

### Jobs
- [ ] `app/jobs/application_job.rb`
- [ ] `app/jobs/recurring_transaction_generator_job.rb`
- [ ] `app/jobs/session_cleanup_job.rb`
- [ ] `app/jobs/sync_up_bank_job.rb`

---

## Category 8: Channels
**Review Criteria:**
- Proper authentication
- Error handling
- Clean subscription logic

### Channels
- [ ] `app/channels/application_cable/channel.rb`
- [ ] `app/channels/application_cable/connection.rb`
- [ ] `app/channels/dashboard_channel.rb`

---

## Category 9: Mailers
**Review Criteria:**
- Proper template structure
- Clear subject lines
- Proper formatting

### Mailers
- [ ] `app/mailers/application_mailer.rb`
- [ ] `app/mailers/passwords_mailer.rb`

---

## Category 10: Routes & Configuration
**Review Criteria:**
- RESTful routes where possible
- Max 1 level of nesting (or use `shallow: true`)
- Proper route naming
- Custom routes documented

### Configuration Files
- [ ] `config/routes.rb`
- [ ] `config/application.rb`
- [ ] `config/database.yml`
- [ ] `config/environments/development.rb`
- [ ] `config/environments/production.rb`
- [ ] `config/environments/test.rb`

---

## Review Summary
**After completing all categories:**

- [ ] All controllers reviewed - actions <10 lines, max 2 instance variables
- [ ] All models reviewed - <200 lines, proper structure order
- [ ] All views reviewed - kebab-case IDs, semantic HTML, ARIA labels
- [ ] All Stimulus controllers reviewed - using targets, <200 lines
- [ ] All services reviewed - single responsibility, proper error handling
- [ ] All routes reviewed - RESTful, proper nesting
- [ ] Full test suite passes (`rails test`)
- [ ] Manual testing confirms all features work
- [ ] No JavaScript console errors
- [ ] All form submissions work correctly
- [ ] All modal/drawer interactions work correctly