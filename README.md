# Vantura

A personal finance management application that integrates with Up Bank to track accounts, transactions, and expenses.

## Features

- **Bank Integration**: Sync accounts and transactions from Up Bank
- **Transaction Management**: View, categorize, and track all your transactions
- **Account Overview**: Monitor balances across multiple accounts
- **Webhook Support**: Real-time updates via Up Bank webhooks
- **Project Expenses**: Track shared expenses and contributions
- **Planned Transactions**: Schedule and track recurring transactions
- **Secure**: Encrypted token storage and rate limiting

## Tech Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: PostgreSQL
- **Background Jobs**: Solid Queue (Rails 8 built-in)
- **Authentication**: Devise
- **Frontend**: Tailwind CSS, Hotwire (Turbo + Stimulus)
- **Deployment**: Kamal
- **Job Processing**: Solid Queue

## Prerequisites

- Ruby 3.4.4
- PostgreSQL 9.3+
- Redis 5.0+
- Node.js 18+ (for asset compilation)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd vantura
```

2. Install dependencies:
```bash
bundle install
npm install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Set up the database:
```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

5. Start Redis (required for rate limiting):
```bash
redis-server
```

6. Start the application:
```bash
bin/dev
```

The application will be available at `http://localhost:3000`

## Running the Application

### Development

Start all services:
```bash
bin/dev
```

This starts:
- Rails server (port 3000)
- Solid Queue (background jobs)
- Tailwind CSS watcher

### Individual Services

Start Rails server:
```bash
bin/rails server
```

Start Solid Queue supervisor:
```bash
bin/rails solid_queue:start
# Or run in Puma: SOLID_QUEUE_IN_PUMA=1 bin/rails server
```

Run migrations:
```bash
bin/rails db:migrate
```

Run tests:
```bash
bin/rails test
# or with RSpec
bundle exec rspec
```

## Production Deployment

### Using Kamal

1. Configure `config/deploy.yml` with your server details
2. Set up secrets in `.kamal/secrets`:
   - `RAILS_MASTER_KEY`
   - `VANTURA_DATABASE_PASSWORD`
   - `ENCRYPTION_KEY`
   - `REDIS_URL`
   - `KAMAL_REGISTRY_PASSWORD`

3. Deploy:
```bash
bin/kamal setup
bin/kamal deploy
```

### Environment Variables

See `.env.example` for all required environment variables.

## Architecture

### Database Structure

- **Users**: Authentication and user data
- **Accounts**: Bank accounts synced from Up Bank
- **Transactions**: Individual transactions
- **Webhook Events**: Processed webhook events
- **Projects**: Shared expense projects
- **Planned Transactions**: Recurring transaction templates

### Background Jobs

- `SyncUpBankDataJob`: Syncs accounts and transactions from Up Bank API
- `ProcessUpWebhookJob`: Processes incoming webhook events

### API Integration

The application integrates with Up Bank API:
- Fetches accounts and transactions
- Processes webhook events for real-time updates
- Rate limiting to respect API limits

## Security Features

- **Encrypted Tokens**: Up Bank tokens encrypted with AES-256-GCM
- **Rate Limiting**: Rack::Attack for request throttling
- **Authentication**: Devise for user authentication
- **Authorization**: Pundit for resource authorization
- **Secure Headers**: Content Security Policy configured

## Configuration

### Redis

Required for:
- Solid Queue background jobs (if using separate queue database)
- Rack::Attack rate limiting
- API rate limiting

Set `REDIS_URL` in your environment.

### Encryption Key

Required for encrypting Up Bank tokens. Must be at least 32 bytes (256 bits).

Generate a secure key:
```bash
openssl rand -hex 32
```

Set as `ENCRYPTION_KEY` in your environment.

## Monitoring

### Health Checks

Basic health check:
```bash
curl http://localhost:3000/up
```

Full health check (checks database, Redis, Solid Queue, Up Bank API):
```bash
curl http://localhost:3000/health/full
```

### Monitoring Task

Run the monitoring rake task:
```bash
bin/rails monitoring:check
```

## Troubleshooting

### Database Connection Issues

Ensure PostgreSQL is running:
```bash
pg_isready
```

Check database configuration in `config/database.yml`.

### Redis Connection Issues

Ensure Redis is running:
```bash
redis-cli ping
```

Should return `PONG`.

### Solid Queue Not Processing Jobs

1. Check database connection (Solid Queue uses PostgreSQL)
2. Verify Solid Queue supervisor is running: `bin/rails solid_queue:start`
3. Check job status in database: `bin/rails runner "puts SolidQueue::Job.count"`
4. Monitor logs for job processing errors

### Migration Issues

If migrations fail:
```bash
bin/rails db:rollback
bin/rails db:migrate
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

[Your License Here]

## Support

For issues and questions, please open an issue on GitHub.

## Acknowledgments

- Up Bank for the API
- Rails community for excellent tooling
