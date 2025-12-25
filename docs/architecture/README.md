# Technical Architecture Documentation
## Document Maintenance

### Version History

- **v1.0 (December 2025):** Initial architecture documentation

### Update Process

When updating these documents:

1. Update version number and date
2. Maintain 300-500 lines per document
3. Update this README if structure changes
4. Keep code examples accurate and tested
5. Update diagrams if architecture changes

---

## Vantura PWA - Budgeting & Investment Tracker

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Project:** Multi-user Progressive Web Application for Up Bank with Budgeting & Investment Tracking

---

## Overview

This technical architecture documentation provides a comprehensive guide for building a desktop Progressive Web Application (PWA) that integrates with the Up Bank API to provide budgeting and investment tracking capabilities.

### Initial Sync Strategy (3,000 Transactions)

**Chosen Approach:** Background job with progress indicator

**Why This Works:**
- Fetches 100 transactions per API call (Up API pagination limit)
- 3,000 transactions = 30 API calls @ ~2 seconds each = ~60 seconds
- User can navigate app while sync continues in background
- Turbo Streams update progress bar in real-time
- No timeout issues on Heroku/Render (long-running requests)

**Alternative Considered (Rejected):**
- Sync last 3 months immediately → Would still take 20-30 seconds, blocking UX
- Our approach is better: Start sync, show dashboard immediately with "Syncing..." banner

### Key Specifications

- **Backend:** Ruby on Rails [8.1.1+](https://rubyonrails.org/2025/10/29/new-rails-releases-and-end-of-support-announcement) with PostgreSQL 
- **Frontend:** Hotwire (Turbo + Stimulus) with Tailwind CSS
- **Styling:** Tailwind CSS with Flowbite components
- **Hosting:** Render cloud platform
- **Authentication:** Devise (multi-user)
- **Database:** PostgreSQL on Render
- **Background Jobs:** Solid Queue (Rails 8 built-in, uses PostgreSQL)
- **Scale:** Initial ~5 users, ~3,000 transactions per user

---

## Documentation Structure

This architecture documentation is organized into six main documents, each focusing on a specific aspect of the system:

### 1. [Architecture Overview](./01-architecture-overview.md)
**~500 lines**

Provides a high-level view of the entire system:
- Executive summary and system overview
- High-level architecture diagrams
- Technology stack details
- Deployment architecture
- System requirements and principles

**Start here** for a complete understanding of the system architecture.

---

### 2. [Backend Architecture](./02-backend-architecture.md)
**~500 lines**

Detailed Rails backend implementation:
- Rails application structure
- Complete database schema with migrations
- Models and relationships
- API integration layer (Up API client)
- Background jobs (Solid Queue)
- Services and business logic
- Controllers and routes
- Error handling

**Essential for:** Backend developers implementing the Rails application.

---

### 3. [Frontend Architecture](./03-frontend-architecture.md)
**~500 lines**

Hotwire/Turbo frontend implementation:
- Hotwire overview and architecture
- Turbo Drive, Frames, and Streams
- Stimulus controllers with examples
- Component structure and organization
- Tailwind CSS styling patterns
- Flowbite component integration
- State management approach
- Progressive Web App features

**Essential for:** Frontend developers implementing the user interface.

---

### 4. [Data Flow & Integration](./04-data-flow-integration.md)
**~500 lines**

Up API integration and data synchronization:
- Up API integration overview
- Initial data synchronization flow
- Ongoing data synchronization strategy
- Transaction processing details
- Budgeting engine implementation
- Investment tracking logic
- Error handling and retry logic
- Rate limiting management

**Essential for:** Understanding how data flows from Up API to the application.

---

### 5. [Security & Authentication](./05-security-authentication.md)
**~500 lines**

Security implementation and best practices:
- Devise authentication setup
- PAT encryption and storage
- Data security and user isolation
- API security measures
- Input validation and sanitization
- Security headers configuration
- Audit logging

**Essential for:** Ensuring secure handling of sensitive financial data.

---

### 6. [Deployment & Operations](./06-deployment-operations.md)
**~500 lines**

Render deployment and operational procedures:
- Render platform overview
- Application deployment configuration
- Database setup and migrations
- Environment configuration
- Background jobs setup
- Monitoring and logging
- Backup strategy
- Scaling considerations

**Essential for:** Deploying and maintaining the application in production.

---

## Quick Start Guide

### For Developers

1. **Start with:** [Architecture Overview](./01-architecture-overview.md)
   - Understand the big picture
   - Review technology choices
   - Understand deployment architecture

2. **Backend Development:**
   - Read [Backend Architecture](./02-backend-architecture.md)
   - Review database schema
   - Understand API integration patterns

3. **Frontend Development:**
   - Read [Frontend Architecture](./03-frontend-architecture.md)
   - Review Hotwire/Turbo patterns
   - Understand Stimulus controller examples

4. **Integration:**
   - Read [Data Flow & Integration](./04-data-flow-integration.md)
   - Understand sync strategies
   - Review error handling

5. **Security:**
   - Read [Security & Authentication](./05-security-authentication.md)
   - Implement PAT encryption
   - Set up Devise authentication

6. **Deployment:**
   - Read [Deployment & Operations](./06-deployment-operations.md)
   - Configure Render services
   - Set up monitoring

### For Project Managers

1. Review [Architecture Overview](./01-architecture-overview.md) for:
   - System capabilities
   - Technology stack
   - Deployment architecture
   - Scale considerations

2. Review [Deployment & Operations](./06-deployment-operations.md) for:
   - Hosting costs
   - Scaling options
   - Backup strategy
   - Monitoring approach

---

## Architecture Diagrams

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                   │
│  Hotwire (Turbo + Stimulus) + Tailwind CSS + Flowbite   │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                  Application Layer                      │
│              Ruby on Rails Application                  │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                    Data Layer                           │
│              PostgreSQL Database                        │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                  External Services                      │
│              Up Bank API (api.up.com.au)                │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
User → Rails Controller → Service Object → Up API Client
  ↓
Up Bank API → Response Handler → Data Processing
  ↓
ActiveRecord Models → PostgreSQL Database
  ↓
Background Jobs → Solid Queue → PostgreSQL
```

---

## Key Technologies

### Backend
- **Ruby on Rails 8.1.1:** Full-stack web framework
- **PostgreSQL:** Relational database
- **Devise:** Authentication
- **Solid Queue:** Background job processing (Rails 8 built-in)
- **Faraday:** HTTP client for Up API
- **attr_encrypted:** PAT encryption

### Frontend
- **Hotwire:** Modern web framework
- **Turbo:** SPA-like navigation
- **Stimulus:** JavaScript framework
- **Tailwind CSS:** Utility-first CSS
- **Flowbite:** UI component library
- **Chart.js:** Data visualization

### Infrastructure
- **Render:** Cloud hosting platform
- **PostgreSQL (Render):** Managed database (also used by Solid Queue for jobs)
- **HTTPS:** Automatic SSL/TLS

---

## Database Schema Summary

### Core Tables

- **users:** User accounts with encrypted PATs (Rails 8.1.1+ encryption)
- **accounts:** Up Bank accounts (transactional, saver, home loan)
- **transactions:** Transaction history
- **categories:** Up Bank category hierarchy (shared)
- **transaction_categories:** Many-to-many relationship
- **tags:** User-specific transaction tags
- **transaction_tags:** Many-to-many relationship
- **budgets:** User-defined budgets
- **investment_goals:** Investment tracking goals

### Relationships

- User has many: accounts, transactions, budgets, tags, investment_goals
- Account has many: transactions, investment_goals
- Transaction belongs to: user, account
- Transaction has many: categories (through transaction_categories), tags (through transaction_tags)
- Budget belongs to: user, category (optional)

---

## API Integration Summary

### Up Bank API Endpoints Used

| Endpoint | Purpose | Frequency |
|----------|---------|-----------|
| `GET /accounts` | Fetch user accounts | Initial sync, periodic updates |
| `GET /transactions` | Fetch transactions | Initial sync, periodic updates |
| `GET /categories` | Fetch category hierarchy | One-time sync |
| `GET /util/ping` | Health check | Periodic validation |

### Authentication

- **Method:** Personal Access Token (PAT)
- **Storage:** Encrypted in database using Rails encryption
- **Format:** `up:yeah:[token]`
- **Header:** `Authorization: Bearer [PAT]`

### Rate Limiting

- **Detection:** `X-RateLimit-Remaining` header
- **Handling:** Exponential backoff retry strategy
- **Retry:** Up to 5 attempts with increasing delays

---

## Security Summary

### Encryption

- **PAT Storage:** Rails 8.1.1+ built-in encryption (AES-256-GCM)
- **Key Source:** Rails credentials (active_record_encryption)
- **Algorithm:** AES-256-GCM with automatic IV/salt management
- **Compression:** Enabled by default (reduces storage overhead)

### Authentication

- **Framework:** Devise
- **Features:** Registration, login, password recovery, remember me
- **Session:** Secure HTTP-only cookies
- **Timeout:** 30 minutes

### Data Isolation

- **User Scoping:** All queries scoped to current_user
- **Database Constraints:** Foreign keys with cascade delete
- **Authorization:** Controller-level ownership checks

### Security Headers

- **HTTPS:** Forced in production
- **CSP:** Content Security Policy configured
- **X-Frame-Options:** DENY
- **X-Content-Type-Options:** nosniff

---

## Deployment Summary

### Render Services

1. **Web Service:** Rails application ($7/month starter)
2. **PostgreSQL Database:** Managed database ($7/month starter)
3. **Background Worker:** Solid Queue job processor ($7/month starter)

**Total Initial Cost:** ~$21/month

**Note:** Solid Queue uses PostgreSQL for job storage, eliminating the need for Redis.

### Deployment Process

1. Push code to Git repository
2. Render auto-detects changes
3. Builds application
4. Runs database migrations
5. Restarts services
6. Health check validates deployment

### Monitoring

- **Logs:** Render built-in log aggregation
- **Health Checks:** `/up` endpoint
- **Error Tracking:** Optional Sentry integration
- **Database Backups:** Automatic daily backups

---

## Development Workflow

### Local Development Setup

1. **Clone Repository:**
   ```bash
   git clone [repository-url]
   cd up-bank-desktop
   ```

2. **Install Dependencies:**
   ```bash
   bundle install
   yarn install
   ```

3. **Setup Database:**
   ```bash
   rails db:create
   rails db:migrate
   ```

4. **Start Services:**
   ```bash
   # Terminal 1: Rails server
   rails server
   
   # Terminal 2: Solid Queue
   bundle exec rake solid_queue:start
   ```

5. **Access Application:**
   - Web: http://localhost:3000
   - Solid Queue UI: http://localhost:3000/solid_queue (if configured)

### Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

---

## Related Documentation

- [Up Bank API Comprehensive Guide](../UP_API_Comprehensive_Guide.md) - Complete Up API reference
- [Up Bank API Documentation](https://developer.up.com.au/#welcome) - Official API docs

---

## Questions & Support

For questions about this architecture:

1. Review the relevant document section
2. Check code examples in the documents
3. Refer to Up API guide for API-specific questions
4. Consult Rails/PostgreSQL documentation for framework questions

---

## License

This documentation is part of the Vantura PWA project.

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Maintained By:** Development Team

