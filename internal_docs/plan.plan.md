# Vantura Codebase Refactoring Plan

## Executive Summary

This plan systematically refactors the Vantura codebase to align with Rails 8 standards and the comprehensive rules defined in `.cursor/rules/`. The refactoring will be executed incrementally, prioritizing high-impact areas (ID naming, controller structure) while maintaining system stability through comprehensive testing.

**CRITICAL:** Each phase must be fully completed and verified before proceeding to the next phase. This ensures stability and allows for proper review and understanding.

## Current State Analysis

### Critical Issues Identified

1. **ID Naming Violations** (Highest Priority)

- Mixed camelCase (`mainContent`) and snake_case (`projects_bento_grid`) - should be kebab-case
- Generic IDs (`filter`, `frequency`) - missing context and purpose suffix
- Missing purpose suffixes (`transactionModal` should be `transaction-modal`)
- Found in: 20+ view files

2. **Controller Structure Violations**

- `ProjectsController#show`: 42 lines (max 10 lines per action)
- `ProjectsController#calculate_project_statistics`: 65 lines (should be service object)
- Multiple instance variables in some actions (max 2 allowed)
- Some actions exceed 10-line limit

3. **Model Structure Violations**

- `Transaction` model: 267 lines (max 200 lines)
- Missing proper organization order (constants, associations, validations, scopes, callbacks, public, private)
- Complex business logic that should be extracted to service objects

4. **Stimulus Controller Issues**

- `modal_controller.js` uses `getElementById` instead of Stimulus targets (lines 123-126)
- Should use Stimulus targets/classes/values instead of direct DOM queries

5. **View Structure Issues**

- Missing semantic HTML in some places
- Inconsistent ID patterns across views
- Some views missing proper ARIA labels

## Refactoring Phases

### Phase 1: ID Naming Standardization (Foundation)

**Priority: CRITICAL**
**Estimated Time: 2-3 days**
**Risk Level: Medium** (requires JavaScript updates)

**Why This First:** ID naming affects every HTML element, JavaScript targeting, and accessibility. Fixing this foundation makes all subsequent work easier and prevents accumulating technical debt. This is also the most visible and highest-impact change.

#### Scope

- Audit all IDs in views using pattern: `grep -r 'id="' app/views`
- Convert all IDs to kebab-case format: `[context]-[element]-[purpose]`
- Update Stimulus controllers that reference IDs via `getElementById`
- Update JavaScript files that reference IDs
- Ensure all form inputs have proper `id` attributes matching `label[for]`

#### Files to Refactor

1. `app/views/layouts/application.html.erb` - `mainContent` → `main-content-container`
2. `app/views/transactions/all.html.erb` - `filter` → `transaction-filter-select`
3. `app/views/projects/index.html.erb` - `projects_bento_grid` → `projects-bento-grid-section`
4. `app/views/projects/show.html.erb` - `project_statistics_bento` → `project-statistics-bento-section`
5. `app/views/transactions/index.html.erb` - Multiple IDs to fix
6. `app/views/dashboard/index.html.erb` - Multiple IDs to fix
7. `app/views/shared/_transaction_drawer.html.erb` - `transactionModal` → `transaction-modal`
8. `app/views/shared/_recurring_drawer.html.erb` - `recurringModal` → `recurring-modal`
9. `app/views/shared/_details_drawer.html.erb` - `detailsDrawer` → `details-drawer`
10. All other views with ID violations

#### JavaScript Files Requiring Updates

1. `app/javascript/controllers/modal_controller.js` - Lines 123-126 (use Stimulus targets)
2. Any other JS files referencing old ID patterns

#### Success Criteria

- All IDs use kebab-case format
- All IDs follow `[context]-[element]-[purpose]` pattern
- No generic IDs remain
- All form inputs have matching label associations
- All JavaScript references updated and tested

#### Testing Requirements

- Run system tests to verify JavaScript functionality
- Verify form submissions work correctly
- Check modal/drawer interactions
- Verify Turbo Stream targets still work

#### Completion Criteria Checklist

**DO NOT PROCEED TO PHASE 2 UNTIL ALL ITEMS ARE CHECKED:**

- [ ] All view files audited for ID violations (`grep -r 'id="' app/views` shows only kebab-case)
- [ ] All camelCase IDs converted to kebab-case (`mainContent` → `main-content-container`)
- [ ] All snake_case IDs converted to kebab-case (`projects_bento_grid` → `projects-bento-grid-section`)
- [ ] All generic IDs updated with context and purpose (`filter` → `transaction-filter-select`)
- [ ] All form inputs have matching `label[for]` associations
- [ ] All Stimulus controllers updated to use new IDs (no `getElementById` with old IDs)
- [ ] All JavaScript files updated to reference new IDs
- [ ] All Turbo Frame/Stream targets updated if IDs changed
- [ ] Manual browser testing complete - all interactions work
- [ ] No JavaScript console errors
- [ ] All system tests pass
- [ ] Form submissions work correctly
- [ ] Modal/drawer interactions work correctly
- [ ] Git commit with descriptive message: "refactor: standardize all IDs to kebab-case format"
- [ ] **PHASE 1 VERIFIED COMPLETE** - Ready to proceed to Phase 2

---

### Phase 2: Controller Refactoring (Thin Controllers)

**Priority: HIGH**
**Estimated Time: 3-4 days**
**Risk Level: Medium-High** (business logic extraction)

**Why Second:** Controllers are the coordination layer. Making them thin improves maintainability and makes models/services easier to refactor later. Once IDs are standardized, refactoring controllers won't break JavaScript targeting.

#### Scope

- Extract business logic from controllers to service objects
- Ensure all actions are under 10 lines
- Limit instance variables to maximum 2 per action
- Reorganize controller structure: callbacks → actions → private methods

#### Controllers Requiring Refactoring

**1. ProjectsController**

- Extract `calculate_project_statistics` (65 lines) → `ProjectStatisticsService`
- Refactor `show` action (42 lines) → extract date/expense logic to service
- Review all actions for 10-line limit compliance

**2. TransactionsController**

- Review `index` action - ensure under 10 lines (currently 53 lines)
- Extract filter logic to service object if needed
- Extract stats calculation (already using `TransactionStatsCalculator` - verify usage)

**3. ProjectExpensesController**

- Review all actions for length and instance variable count
- Extract `calculate_projects_statistics` → service object

**4. All Other Controllers**

- Audit for action length violations
- Audit for instance variable count violations
- Ensure proper HTTP status codes (`:unprocessable_entity` for validation errors)

#### Service Objects to Create

1. `ProjectStatisticsService` - Extract from `ProjectsController#calculate_project_statistics`
2. `ProjectExpenseStatisticsService` - Extract from `ProjectExpensesController#calculate_projects_statistics`
3. Review existing service objects for consistency with new patterns

#### Success Criteria

- All controller actions under 10 lines
- Maximum 2 instance variables per action
- All business logic extracted to service objects
- Controllers follow structure: callbacks → actions → private methods
- Proper HTTP status codes used throughout

#### Testing Requirements

- All controller tests pass
- Integration tests verify service object extraction
- System tests verify user flows still work

#### Completion Criteria Checklist

**DO NOT PROCEED TO PHASE 3 UNTIL ALL ITEMS ARE CHECKED:**

- [ ] All controller actions are <10 lines each (verified with line count)
- [ ] Maximum 2 instance variables per action (verified manually)
- [ ] All business logic extracted to service objects
- [ ] All controllers follow structure: callbacks → actions → private methods
- [ ] Proper HTTP status codes set (422 for validation errors, etc.)
- [ ] All controller tests pass (`rails test test/controllers/`)
- [ ] Integration tests pass (`rails test test/integration/`)
- [ ] System tests pass for affected features (`rails test:system`)
- [ ] Manual testing confirms functionality unchanged
- [ ] No regressions introduced
- [ ] Git commit with descriptive message: "refactor: extract business logic from controllers to service objects"
- [ ] **PHASE 2 VERIFIED COMPLETE** - Ready to proceed to Phase 3

---

### Phase 3: Model Refactoring (Organization & Extraction)

**Priority: MEDIUM**
**Estimated Time: 2-3 days**
**Risk Level: Low-Medium** (reorganization, no behavior changes)

**Why Third:** Models are the foundation. After controllers are thin, we can focus on model organization, validations, and business logic placement. Models can be refactored independently once controllers don't contain business logic.

#### Scope

- Reorganize models to follow standard structure order
- Extract complex logic to service objects where models exceed 200 lines
- Ensure proper organization: constants → associations → validations → scopes → callbacks → public methods → private methods

#### Models Requiring Refactoring

**1. Transaction Model (267 lines)**

- Extract complex query methods to service objects:
- `top_merchants_by_type` → `TransactionMerchantService`
- `apply_filter` → `TransactionFilterService`
- Reorganize structure following standard order
- Extract broadcast logic to service object if appropriate

**2. All Other Models**

- Review for proper structure order
- Ensure associations specify `dependent:` options
- Verify scopes use proper lambda syntax
- Check callback usage (should be minimal)

#### Success Criteria

- All models under 200 lines
- Models follow standard structure order
- Complex business logic extracted to service objects
- All associations have `dependent:` options specified
- Proper use of scopes vs class methods

#### Testing Requirements

- All model tests pass
- Service object tests added for extracted logic
- Verify associations work correctly

#### Completion Criteria Checklist

**DO NOT PROCEED TO PHASE 4 UNTIL ALL ITEMS ARE CHECKED:**

- [ ] All models follow correct structure order (constants → associations → validations → scopes → callbacks → public → private)
- [ ] All models are <200 lines (verified with line count)
- [ ] All models have proper validation coverage
- [ ] Complex callback logic extracted to service objects
- [ ] All associations have appropriate `dependent:` options
- [ ] Missing scopes added where needed
- [ ] All model tests pass (`rails test test/models/`)
- [ ] Service object tests added for extracted logic
- [ ] Integration tests verify associations work correctly
- [ ] Manual testing confirms functionality unchanged
- [ ] Git commit with descriptive message: "refactor: reorganize models and extract complex logic to service objects"
- [ ] **PHASE 3 VERIFIED COMPLETE** - Ready to proceed to Phase 4

---

### Phase 4: Stimulus Controller Refactoring

**Priority: MEDIUM**
**Estimated Time: 2-3 days** (updated due to controller splitting requirements)
**Risk Level: Low-Medium** (JavaScript refactoring + controller splitting)

**Why Fifth:** Stimulus controllers depend on IDs being correct. Once IDs are standardized (Phase 1), refactoring Stimulus is safe. JavaScript controllers are isolated, so they can be refactored independently.

#### Scope

- Convert `querySelector` calls within controller scope to Stimulus targets
- Keep `getElementById` for cross-controller access (document why)
- Update HTML to include both `data-[controller]-target` attributes AND IDs
- Split controllers exceeding 200 lines into smaller, focused controllers
- Extract shared logic to helper modules
- Ensure all controllers follow Stimulus best practices
- Use `static targets`, `static classes`, `static values` appropriately

#### Key Principles (Based on Rules)

**QuerySelector vs Targets:**
- **Within controller scope** (`this.element.querySelector`): Convert to Stimulus targets
- **Global elements** (meta tags, document-level): Keep `querySelector` (acceptable exception)
- **Rationale:** Targets are declarative, work with Stimulus lifecycle, avoid brittle class selectors

**Cross-Controller Access:**
- **Keep `getElementById`** for elements accessed outside controller scope
- Examples: `calendar_content` Turbo Frame, `main-content-container` layout element
- **Rationale:** IDs are meant for external access and debugging (per `id_naming_category.mdc` lines 668-678)

**IDs vs Targets:**
- **Both required:** Elements need both `data-[controller]-target` AND `id` attributes
- **Targets:** For Stimulus controller logic
- **IDs:** For debugging, external access, testing, form labels, deep linking
- **Rationale:** IDs complement targets, they don't replace them (per `id_naming_category.mdc` lines 613-679)

#### Controllers Requiring Updates

**1. ModalController** (`app/javascript/controllers/modal_controller.js`)

- Lines 103-104: Convert `querySelectorAll('.transaction-type-radio')` to Stimulus targets
- Lines 123-126: Convert `getElementById` calls to Stimulus targets (within controller scope)
- Add targets: `typeRadio`, `typeCard`, `descriptionLabel`, `amountLabel`, `dateLabel`, `transactionDescription`
- Update HTML to include both `data-modal-target` attributes AND IDs

**2. CalendarController** (`app/javascript/controllers/calendar_controller.js`)

- Line 10: Convert `querySelectorAll('[data-view]')` to Stimulus targets
- Line 37: **Keep** `getElementById('calendar_content')` - cross-controller access (Turbo Frame)
- Lines 94-98: **Keep** `getElementById` calls - accessing drawer elements outside controller scope
- Line 149: Convert `getElementById` to target if element is within controller scope
- Line 154: Convert `querySelectorAll('[id^="day-"]')` to Stimulus targets

**3. SidebarController** (`app/javascript/controllers/sidebar_controller.js`)

- Line 10: **Keep** `getElementById('main-content-container')` - cross-controller access (shared layout)
- This is acceptable per rules - element is accessed outside controller scope

**4. MonthNavController** (`app/javascript/controllers/month_nav_controller.js`) - **SPLIT REQUIRED**

- **Current:** 624 lines (violates 200-line rule)
- **Split into:**
  1. `month_nav_controller.js` (~150 lines)
     - Month/year selection
     - Month navigation
     - Dropdown toggle logic
     - Month button state updates
  2. `week_nav_controller.js` (~150 lines)
     - Week year/month selection
     - Week generation logic (`generateWeeksForMonth`, `renderWeeks`)
     - Week navigation
     - Week list rendering
  3. Extract shared utilities to `app/javascript/helpers/navigation_helper.js` (~50 lines)
     - `buildUrl()` function
     - Shared URL building logic
  4. Extract scroll preservation to `app/javascript/helpers/scroll_helper.js` (~150 lines)
     - `restoreScrollAfterStream()` logic
     - Reusable across controllers needing scroll preservation
- Lines 256, 273, 362, 379, 419, 437, 471: **Keep** `getElementById('main-content-container')` - cross-controller access
- Line 581: **Keep** `getElementById(frameId)` - accessing Turbo Frame from outside scope

**5. ExpenseRowController** (`app/javascript/controllers/expense_row_controller.js`)

- Line 18: Convert `querySelector('.chevron-icon')` to Stimulus target

**6. ExpenseTemplateController** (`app/javascript/controllers/expense_template_controller.js`)

- Line 86: Convert `querySelector('ul')` to Stimulus target
- Line 122: Convert `querySelectorAll('li[data-index]')` to Stimulus targets

**7. TransactionsNavController** (`app/javascript/controllers/transactions_nav_controller.js`)

- Line 33: Convert `querySelector('[data-controller~="autocomplete"]')` to Stimulus target or value

**8. ThemeController** (`app/javascript/controllers/theme_controller.js`)

- Lines 78-79: Convert `querySelector` calls to Stimulus targets

**9. AutocompleteController** (`app/javascript/controllers/autocomplete_controller.js`)

- Line 134: Convert `querySelectorAll('li[data-index]')` to Stimulus targets

**10. All Other Controllers**

- Audit for direct DOM queries
- Ensure proper use of targets/classes/values
- Verify controllers are under 200 lines

#### Controller Splitting Strategy (for Controllers >200 Lines)

**Process for Maintaining Logic Consistency:**

1. **Extract Shared Logic First:**
   - Move `buildUrl()` to `app/javascript/helpers/navigation_helper.js`
   - Extract `restoreScrollAfterStream()` to `app/javascript/helpers/scroll_helper.js`
   - Create reusable utility functions

2. **Split by Behavior:**
   - Month logic → `month_nav_controller.js`
   - Week logic → `week_nav_controller.js`
   - Each controller handles one responsibility

3. **Maintain Consistency Through:**
   - Shared values: Both controllers use same `urlPattern`, `urlType`, `turboFrame` values
   - Custom events: Dispatch `month:changed` / `week:changed` events for coordination
   - Shared helpers: Use same `buildUrl()` and scroll preservation logic

4. **Documentation:**
   - Add header comments explaining controller responsibilities
   - Document which controllers coordinate together
   - Explain shared helper usage
   - Reference architecture decision document

#### Documentation Requirements

**1. Inline Comments:**
- Add header comments to each controller explaining its purpose
- Document why `getElementById` is used for cross-controller access (with references to rule files)
- Explain shared helper usage and coordination between controllers

**2. Architecture Reference Document:**
- Create `docs/stimulus-controllers-architecture.md`
- Document controller splitting decisions
- Explain shared helper modules
- Map controller relationships and coordination patterns
- Reference relevant rule files for decisions

**3. Helper Module Documentation:**
- Document shared helpers in `app/javascript/helpers/`
- Explain when to use each helper
- Provide usage examples

#### Success Criteria

- No `querySelector` calls within controller scope (use Stimulus targets instead)
- `getElementById` only used for cross-controller access (documented with comments)
- All HTML updated to include both `data-[controller]-target` attributes AND IDs
- All controllers under 200 lines
- Controllers follow proper structure: static properties → lifecycle → actions → helpers
- Shared logic extracted to helper modules
- Documentation added (inline comments + architecture reference)

#### Testing Requirements

- Manual testing of all interactive features
- System tests for JavaScript functionality
- Verify modals/drawers work correctly
- Test split controllers independently
- Test shared helper modules
- Integration tests verify controllers coordinate correctly

#### Completion Criteria Checklist

**DO NOT PROCEED TO PHASE 5 UNTIL ALL ITEMS ARE CHECKED:**

- [ ] All Stimulus controllers follow proper structure (static properties → lifecycle → actions → helpers)
- [ ] All controllers are <200 lines (verified with line count)
- [ ] One controller per behavior (no mixing concerns)
- [ ] Proper naming convention (`_controller.js` suffix)
- [ ] All static properties defined first (targets, values, classes)
- [ ] Lifecycle methods (`connect`, `disconnect`) present where needed
- [ ] No `querySelector` calls within controller scope - all use Stimulus targets
- [ ] `getElementById` only used for cross-controller access (documented with comments)
- [ ] All HTML updated to use both `data-[controller]-target` attributes AND IDs
- [ ] Controllers split where needed (month_nav_controller → month_nav + week_nav + helpers)
- [ ] Shared logic extracted to helper modules (`navigation_helper.js`, `scroll_helper.js`)
- [ ] Header comments added to all controllers explaining purpose
- [ ] Cross-controller access documented with rule file references
- [ ] Architecture reference document created (`docs/stimulus-controllers-architecture.md`)
- [ ] Manual browser testing confirms all interactions work
- [ ] No JavaScript console errors
- [ ] System tests pass for interactive features
- [ ] Split controllers tested independently
- [ ] Shared helpers tested separately
- [ ] Integration tests verify controller coordination
- [ ] Git commit with descriptive message: "refactor: convert Stimulus controllers to use targets, split large controllers, add documentation"
- [ ] **PHASE 4 VERIFIED COMPLETE** - Ready to proceed to Phase 5

---

### Phase 5: View Organization & Partials

**Priority: MEDIUM**
**Estimated Time: 1-2 days**
**Risk Level: Low** (HTML structure improvements)

**Why Fourth:** Views are presentation-only. After models/controllers are clean, organizing views is straightforward. Views depend on controllers/models, so fixing those first ensures views don't need rework.

#### Scope

- Extract repeated view code to partials
- Ensure views contain no business logic
- Organize partials in `shared/` for cross-resource use
- Review ERB syntax and indentation
- Ensure proper semantic HTML structure

#### Approach

- Identify repeated patterns
- Create shared partials
- Refactor views to use partials
- Test after each change

#### Testing Requirements

- Visual regression testing (ensure UI unchanged)
- Manual testing of affected pages

#### Completion Criteria Checklist

**DO NOT PROCEED TO PHASE 6 UNTIL ALL ITEMS ARE CHECKED:**

- [ ] All repeated view code extracted to partials
- [ ] Views contain zero business logic (only presentation)
- [ ] Proper ERB indentation (2 spaces)
- [ ] Semantic HTML used (`<article>`, `<nav>`, `<button>`, etc.)
- [ ] All partials properly organized in `shared/` when cross-resource
- [ ] Visual regression testing confirms UI unchanged
- [ ] Manual testing confirms functionality unchanged
- [ ] Git commit with descriptive message: "refactor: extract view partials and improve semantic HTML"
- [ ] **PHASE 5 VERIFIED COMPLETE** - Ready to proceed to Phase 6

---

### Phase 6: Routes & Database Alignment

**Priority: LOW**
**Estimated Time: 1 day**
**Risk Level: Low** (review only, no changes unless critical)

**Why Sixth:** Routes and database are foundational but less visible. After UI/controllers/models are clean, aligning routes/database is straightforward. These are infrastructure-level changes that don't affect user-facing code.

#### Scope

- Ensure RESTful routes
- Verify database indexes exist for foreign keys
- Review migration structure
- Ensure proper column types

#### Approach

- Audit routes file
- Review database schema
- Add missing indexes if needed
- Document any non-standard routes

#### Testing Requirements

- Routes test
- Database query performance check

#### Completion Criteria Checklist

**DO NOT PROCEED TO PHASE 7 UNTIL ALL ITEMS ARE CHECKED:**

- [ ] All routes follow RESTful conventions
- [ ] Maximum 1 level of nesting (or use `shallow: true`)
- [ ] All foreign keys have indexes
- [ ] Frequently queried columns have indexes
- [ ] Column types are appropriate (string vs text, decimal vs float)
- [ ] All migrations follow naming conventions
- [ ] Routes tests pass
- [ ] Database query performance acceptable (no N+1 queries)
- [ ] Git commit with descriptive message: "refactor: align routes and database structure with standards"
- [ ] **PHASE 6 VERIFIED COMPLETE** - Ready to proceed to Phase 7

---

### Phase 7: Testing & Documentation (Final Phase)

**Priority: MEDIUM**
**Estimated Time: 2-3 days**
**Risk Level: Low** (adding tests, not breaking existing)

**Why Last:** Testing ensures everything works. Documentation captures what we've done. After all refactoring is complete, comprehensive testing and documentation finalize the work. This phase validates that all previous phases didn't break anything.

#### Scope

- Ensure test coverage for refactored code
- Add tests for new service objects
- Update test fixtures
- Document architectural decisions
- Update README if needed

#### Approach

- Review test coverage
- Add missing tests
- Update documentation
- Final verification

#### Testing Requirements

- Full test suite
- Manual end-to-end testing

#### Completion Criteria Checklist

**FINAL VERIFICATION - ALL PHASES COMPLETE:**

- [ ] Test coverage ≥80% overall
- [ ] All new service objects have tests
- [ ] All refactored controllers have tests
- [ ] All refactored models have tests
- [ ] Test fixtures updated to match new structure
- [ ] Architectural decisions documented
- [ ] README updated if needed
- [ ] Full test suite passes (`rails test`)
- [ ] Manual end-to-end testing confirms all features work
- [ ] Git commit with descriptive message: "refactor: add comprehensive tests and update documentation"
- [ ] **FINAL VERIFICATION:** All phases complete, codebase fully compliant with rules

---

## Execution Strategy

### Phase-by-Phase Approach

**CRITICAL:** Complete each phase fully before moving to the next. Do not start Phase 2 until Phase 1 is 100% complete and verified.

### Testing Strategy

- After each file: Quick manual test
- After each phase: Full test suite + manual verification
- Before proceeding: Fix any test failures
- Document breaking changes if any

### Git Strategy

- One commit per phase completion
- Descriptive commit messages following git commit style guide
- Small, focused commits within phases

## Risk Mitigation

### High-Risk Areas

1. **ID Naming Changes** - Could break JavaScript functionality

- Mitigation: Comprehensive testing after changes, update JavaScript references immediately

2. **Controller Refactoring** - Could break business logic

- Mitigation: Extract to service objects incrementally, test each extraction before proceeding

3. **Model Refactoring** - Could break associations/queries

- Mitigation: Reorganize structure only (no behavior changes), test associations after reorganization

### Rollback Plan

- Each phase committed separately
- Can rollback individual phases if issues arise
- Keep original code commented during refactoring (remove after verification)

## Success Metrics

### Code Quality Metrics

- All IDs follow kebab-case naming convention
- All controller actions under 10 lines
- All models under 200 lines
- Zero direct DOM queries in Stimulus controllers
- Semantic HTML throughout views

### Testing Metrics

- 100% test suite passing after each phase
- Critical paths have system test coverage
- No regression in functionality

## Timeline Estimate

- **Phase 1**: 2-3 days
- **Phase 2**: 3-4 days
- **Phase 3**: 2-3 days
- **Phase 4**: 2-3 days (updated due to controller splitting requirements)
- **Phase 5**: 1-2 days
- **Phase 6**: 1 day
- **Phase 7**: 2-3 days

**Total Estimated Time**: 12-18 days (with testing and verification)

## Notes

- This is a comprehensive refactoring - take time to do it right
- Test thoroughly after each phase
- Document any deviations from standards with reasoning
- User testing recommended after Phase 1 (ID changes) and Phase 2 (Controller refactoring)
- **Each phase must be verified complete before proceeding to the next**