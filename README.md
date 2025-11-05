# Vantura

> **Personal Finance Management** - Real-time transaction tracking, balance projections, and financial insights

A modern Rails 8 application for managing personal finances with Up Bank integration, real-time sync, and intelligent balance projections.

## Features

- ✅ **Up Bank Integration** - Real-time transaction sync
- ✅ **Transaction Management** - Track real and hypothetical transactions
- ✅ **Recurring Patterns** - Automatic detection and generation of recurring transactions
- ✅ **Calendar View** - See balance projections for any date
- ✅ **Real-time Updates** - WebSocket-powered live updates
- ✅ **Dark Mode** - Beautiful dark theme support
- ✅ **Progressive Web App** - Install on mobile devices
- ✅ **Production Ready** - Security hardened, performance optimized, monitored

## Quick Start

### Prerequisites

- Ruby 3.4.4
- Bundler
- SQLite3

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/vantura.git
cd vantura

# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate

# Start the development server
bin/dev
```

Visit http://localhost:3000

### Testing

```bash
# Run the test suite
bin/rails test

# Run specific test
bin/rails test test/models/user_test.rb

# Run system tests
bin/rails test:system

# Generate coverage report
bin/rails test
open coverage/index.html
```

**Coverage Targets:**
- ≥80% overall coverage
- 100% critical business logic
- 90%+ models
- 70%+ controllers

See [Testing Guide](docs/testing-guide.md) for detailed testing patterns and practices.

## Development

### Tech Stack

- **Framework:** Rails 8.0
- **Database:** SQLite3
- **Frontend:** Tailwind CSS, Stimulus.js, Turbo
- **Caching:** Solid Cache
- **Background Jobs:** Solid Queue
- **WebSockets:** Solid Cable
- **Deployment:** Kamal

### Architecture

- **MVC Pattern** - Standard Rails architecture
- **Service Objects** - Extracted business logic
- **Background Jobs** - Async operations
- **Stimulus Controllers** - Frontend interactivity
- **Turbo Streams** - Real-time updates

### Key Commands

```bash
# Database management
bin/rails db:backup              # Create database backup
bin/rails db:list_backups        # List available backups
bin/rails db:restore[filename]   # Restore from backup

# Security scanning
bin/brakeman                    # Security audit
bin/bundle-audit                # Dependency vulnerabilities

# Code quality
bin/rubocop                     # Linting
bin/rails test                  # Run tests
```

## Documentation

- **[Public Roadmap](PUBLIC_ROADMAP.md)** - Upcoming features and development plans (public-facing)
- **[Refactoring Decisions](docs/refactoring-decisions.md)** - Architectural decisions made during refactoring
- **[Testing Guide](docs/testing-guide.md)** - Testing patterns and practices
- **[Stimulus Controllers Architecture](docs/stimulus-controllers-architecture.md)** - Frontend architecture decisions

## Security

- ✅ CSRF protection enabled
- ✅ SQL injection protection (ActiveRecord parameterization)
- ✅ XSS protection (ERB auto-escaping)
- ✅ Force SSL in production
- ✅ Content Security Policy headers
- ✅ Security headers configured
- ✅ Error tracking with Sentry
- ✅ Regular security audits

## Status

**Version 1.0** - Production Ready ✅

- Core features complete and tested
- Production deployment configured
- Performance optimized (<25ms response times)
- Security hardened
- Monitoring and error tracking active

## Acknowledgments

- Built with [Rails](https://rubyonrails.org/)
- [Up Bank API](https://developer.up.com.au/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Stimulus](https://stimulus.hotwired.dev/)
- [Turbo](https://turbo.hotwired.dev/)

---

