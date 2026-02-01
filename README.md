# ScriptVoice

A Phoenix LiveView platform connecting screenplay writers with voice artists. Writers upload scripts, voice artists bring them to life with audio performances, and the community discovers new talent.

## Features

### For Writers
- Upload and manage screenplays with character breakdowns
- Browse audio performances of your scripts
- Mark favorite performances as "Author's Picks"
- Commission voice artists for custom recordings
- Like and discover other writers' work

### For Voice Artists
- Record audio versions of screenplays (solo or ensemble)
- Set up pricing for commissions (per-page, flat rate, or quote-based)
- Connect Stripe account for receiving payments
- Build a profile with bio, intro video, and social links
- Track earnings and manage active commissions

### For Everyone
- Browse screenplays by genre, popularity, or recency
- Listen to audio performances
- View verified user profiles
- Mobile-first responsive design

## Tech Stack

- **Framework**: Phoenix 1.7+ with LiveView
- **Language**: Elixir
- **Database**: PostgreSQL
- **Styling**: Tailwind CSS
- **Payments**: Stripe Connect
- **Authentication**: Custom phone/email verification

## Getting Started

### Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 14+
- Node.js 18+ (for assets)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd script_voice
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. Create and seed the database:
   ```bash
   mix ecto.setup
   ```

5. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

6. Visit [`localhost:4000`](http://localhost:4000) in your browser.

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost/script_voice_dev

# Phoenix
SECRET_KEY_BASE=your-secret-key-base
PHX_HOST=localhost

# Stripe (for commission payments)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_CONNECT_WEBHOOK_SECRET=whsec_...
```

## Demo Accounts

After running `mix ecto.setup`, the following demo accounts are available:

### Writers

| Email | Name | Description |
|-------|------|-------------|
| sarah@example.com | Sarah Chen | Sci-fi and family drama writer |
| marcus@example.com | Marcus Webb | Romance and drama writer |
| aisha@example.com | Aisha Patel | Thriller writer |

### Solo Voice Artists

| Email | Name | Pricing |
|-------|------|---------|
| jake@example.com | Jake Morrison | Per page: $5/page, min $25 |
| emma@example.com | Emma Stone | Per page: $8/page, min $50 |
| michael@example.com | Michael Chang | Quote-based (flexible) |

### Group/Ensemble Voice Artists

| Email | Name | Pricing |
|-------|------|---------|
| lighthouse@example.com | The Lighthouse Collective | Flat rate: $150, min $100 |
| kimtorres@example.com | David Kim & Rachel Torres | Per page + per character |

**Note**: All demo accounts are pre-verified. No password is required in development mode - just enter the email to sign in.

## Project Structure

```
script_voice/
├── lib/
│   ├── script_voice/           # Business logic
│   │   ├── accounts/           # User management, verification
│   │   ├── screenplays/        # Screenplay CRUD
│   │   ├── audio/              # Audio version management
│   │   ├── commissions/        # Commission requests, pricing
│   │   ├── social/             # Likes, follows
│   │   ├── notifications/      # In-app notifications
│   │   └── stripe.ex           # Stripe Connect integration
│   │
│   └── script_voice_web/       # Web layer
│       ├── components/         # Reusable UI components
│       ├── live/               # LiveView pages
│       ├── controllers/        # Traditional controllers
│       └── router.ex           # Route definitions
│
├── priv/
│   └── repo/
│       ├── migrations/         # Database migrations
│       └── seeds.exs           # Demo data
│
├── assets/                     # Frontend assets (JS, CSS)
├── config/                     # Configuration files
└── test/                       # Test files
```

## Key Routes

| Path | Description |
|------|-------------|
| `/` | Landing page |
| `/browse` | Browse all screenplays |
| `/screenplay/:id` | View screenplay details and audio versions |
| `/profile/:id` | User profile page |
| `/verify` | Phone/email verification flow |
| `/commissions` | Commission dashboard |
| `/commissions/request/:performer_id` | Request a commission |
| `/commissions/:id` | Commission details |
| `/settings/payments` | Stripe Connect setup |

## Database Schema

### Core Tables

- **users** - Writers, voice artists, and visitors
- **screenplays** - Uploaded scripts with character data
- **audio_versions** - Recorded performances linked to screenplays
- **likes** - User likes on screenplays and audio versions

### Commission System

- **performer_pricing** - Voice artist rate settings
- **commission_requests** - Commission workflow tracking
- **commission_submissions** - Audio submissions for commissions
- **commission_messages** - In-commission messaging
- **payments** - Stripe payment records
- **stripe_accounts** - Connected Stripe account info

### Supporting Tables

- **verification_codes** - Phone/email verification
- **notifications** - In-app notifications

## Commission Flow

1. **Writer requests commission** - Selects performer, screenplay, and agrees to pricing
2. **Payment captured** - Stripe holds funds (if paid commission)
3. **Performer accepts/declines** - Reviews request details
4. **Work in progress** - Performer records audio, can message writer
5. **Submission** - Performer uploads audio for review
6. **Approval** - Writer approves or requests revision
7. **Completion** - Payment released to performer (minus 10% platform fee)

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

### Database Commands

```bash
# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Run migrations only
mix ecto.migrate

# Rollback last migration
mix ecto.rollback
```

### Asset Building

```bash
# Development build
mix assets.build

# Production build
mix assets.deploy
```

## Deployment

### Production Configuration

1. Set all environment variables in your production environment
2. Configure your database connection via `DATABASE_URL`
3. Set `PHX_HOST` to your domain
4. Configure Stripe webhook endpoints

### Release Build

```bash
MIX_ENV=prod mix release
```

## API Integrations

### Stripe Connect

The platform uses Stripe Connect for marketplace payments:
- Voice artists connect their Stripe accounts
- Writers pay when requesting commissions
- Funds are held until work is approved
- 10% platform fee is deducted on payout

### Future Integrations (Planned)

- Twilio for SMS verification
- SendGrid/SES for email notifications
- S3/CloudFlare R2 for audio storage

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and formatting
5. Submit a pull request

## License

Private - All rights reserved.
