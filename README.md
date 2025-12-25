# Vantura

A Progressive Web Application (PWA) that provides desktop access to Up Bank account data with integrated budgeting and investment tracking capabilities.

## Overview

Vantura extends Up Bank's mobile-only experience to desktop/web platforms while adding budgeting and investment tracking features not available in the native app. The application syncs with Up Bank's API to provide a comprehensive financial management experience.

### Key Features

- **Account Management:** View Up Bank accounts (transactional, saver, home loan)
- **Transaction History:** Browse and filter 12 months of transaction data
- **Budgeting:** Category-based budget tracking with email alerts
- **Investment Tracking:** Monitor savings growth and investment-related transactions
- **Real-time Updates:** Manual refresh with optional background sync
- **Progressive Web App:** Installable PWA with offline support

## Technology Stack

- **Backend:** Ruby on Rails 8.1.1
- **Database:** PostgreSQL
- **Frontend:** Hotwire (Turbo + Stimulus) with Tailwind CSS
- **Authentication:** Devise
- **Background Jobs:** Solid Queue
- **Caching:** Solid Cache
- **WebSockets:** Solid Cable
- **Deployment:** Kamal (Docker-based)
- **Hosting:** Render (cloud platform)

## Prerequisites

- Ruby 3.3+ (see `.ruby-version`)
- PostgreSQL 9.3+
- Node.js and npm (for Tailwind CSS)
- Up Bank Personal Access Token (PAT)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone git@github.com:ostafford/Vantura.git
cd Vantura
```

### 2. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install Node.js packages (if needed)
npm install
```

### 3. Database Setup

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# (Optional) Seed database
rails db:seed
```

### 4. Environment Configuration

The application uses Rails encrypted credentials. To edit credentials:

```bash
EDITOR="code --wait" rails credentials:edit
```

Required environment variables (set in your shell or `.env` file):

- `RAILS_ENV` - Environment (development, production, test)
- `RAILS_MAX_THREADS` - Maximum Puma threads (default: 5)
- `PORT` - Server port (default: 3000)
- `VANTURA_DATABASE_PASSWORD` - PostgreSQL password (production)

### 5. Start the Application

```bash
# Start Rails server and background jobs
bin/dev

# Or start separately:
rails server
bin/jobs
```

The application will be available at `http://localhost:3000`

## User Workflow

1. **Sign Up:** Create an account using email/password
2. **Configure PAT:** Enter your Up Bank Personal Access Token in settings
3. **Initial Sync:** System automatically syncs accounts and transactions
4. **Set Budgets:** Create category-based budgets with spending limits
5. **Track Investments:** Set investment goals and monitor progress
6. **Receive Alerts:** Get email notifications when budgets approach thresholds

## Architecture Documentation

Comprehensive architecture documentation is available in the [`docs/architecture/`](docs/architecture/) directory:

- [Architecture Overview](docs/architecture/01-architecture-overview.md)
- [Backend Architecture](docs/architecture/02-backend-architecture.md)
- [Frontend Architecture](docs/architecture/03-frontend-architecture.md)
- [Data Flow & Integration](docs/architecture/04-data-flow-integration.md)
- [Security & Authentication](docs/architecture/05-security-authentication.md)
- [Deployment & Operations](docs/architecture/06-deployment-operations.md)
- [Up API Comprehensive Guide](docs/architecture/UP_API_Comprehensive_Guide.md)

## Development

### Running Tests

```bash
# Run test suite
rails test

# Run linters
bundle exec rubocop
bundle exec brakeman
bundle exec bundler-audit
```

### Background Jobs

Background jobs run via Solid Queue:

```bash
# Start job processor
bin/jobs
```

Jobs include:
- `InitialSyncJob` - Initial account and transaction sync
- `SyncAccountsJob` - Periodic account updates
- `SyncTransactionsJob` - Periodic transaction updates
- `SyncCategoriesJob` - Category synchronization
- `CheckBudgetAlertsJob` - Budget threshold monitoring

### Code Quality

The project uses:
- **RuboCop** - Ruby style guide enforcement
- **Brakeman** - Security vulnerability scanner
- **Bundler Audit** - Dependency vulnerability scanner

## Deployment

The application is configured for deployment using Kamal. See [Deployment & Operations](docs/architecture/06-deployment-operations.md) for detailed deployment instructions.

### Quick Deploy

```bash
# Deploy to production
kamal deploy
```

## Security

- User authentication via Devise
- Encrypted credentials storage (Rails credentials)
- Up Bank PAT stored encrypted in database
- HTTPS-only in production
- Content Security Policy headers
- SQL injection protection via ActiveRecord
- XSS protection via Rails defaults

## License

[Add license information here]

## Contributing

[Add contributing guidelines here]

## Support

For issues and questions, please open an issue on GitHub.
