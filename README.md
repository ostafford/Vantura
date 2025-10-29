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
- ✅ **Progressive Web App** - Install on mobile devices (manifest + service worker)
- ✅ **TypeScript + Vite** - Fast development with HMR and strict type-checking
- ✅ **Production Ready** - Security hardened, performance optimized, monitored

## Quick Start

### Prerequisites

- Ruby 3.4.4
- Node.js 20+ LTS
- Bundler
- npm
- PostgreSQL 16+ (for local development)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/vantura.git
cd vantura

# Install dependencies
bundle install
npm install

# Setup database
bin/rails db:create db:migrate

# Start the development server (Rails + Vite dev server)
bin/dev
```

Visit http://localhost:3000

Notes:
- Vite HMR runs on http://localhost:3036 and is automatically proxied by the app; CSP allows dev connections.
- PWA is enabled in all environments. Service worker registers on HTTPS or localhost. Offline page available at `/offline`.

### Testing

```bash
# Run the test suite
bin/rails test

# Run specific test
bin/rails test test/models/user_test.rb

# TypeScript, ESLint, and formatting
npm run type-check
npm run lint
npm run format:check
```

## Development

### Tech Stack

- **Framework:** Rails 8.0
- **Database:** PostgreSQL 16+
- **Frontend:** Tailwind CSS, Stimulus.js (TypeScript), Turbo, Vite
- **TypeScript:** TypeScript with strict mode, ESLint, Prettier
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
- **PWA** - Manifest + Service Worker with cache-first/SWR strategies

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
bin/rubocop                     # Linting (Ruby)
npm run lint                    # Linting (TypeScript)
npm run type-check              # Type checking
npm run format                  # Format code (Prettier)

# Tests
bin/rails test                  # Run tests
```

## CI

- Ruby security scan with Brakeman
- Node/TypeScript jobs: type-check, ESLint, Prettier, and Vite build (`build_js` job)
- Rails tests run against PostgreSQL 16 service

## Security

- ✅ CSRF protection enabled
- ✅ SQL injection protection (ActiveRecord parameterization)
- ✅ XSS protection (ERB auto-escaping)
- ✅ Force SSL in production
- ✅ Content Security Policy headers (includes PWA + Vite dev allowances)
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

