# ScriptVoice

A Phoenix LiveView platform connecting screenplay writers with voice artists. Writers upload scripts, voice artists bring them to life with audio performances, and the community discovers new talent.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Demo Accounts](#demo-accounts)
- [Project Structure](#project-structure)
- [Key Routes](#key-routes)
- [Database Schema](#database-schema)
- [Collectives System](#collectives-system)
- [Projects System](#projects-system)
- [Commission System](#commission-system)
- [Payment Flow](#payment-flow)
- [File Storage](#file-storage)
- [Development](#development)
- [Deployment](#deployment)
- [API Integrations](#api-integrations)
- [Recent Changes](#recent-changes)

## Features

### For Writers

- **Screenplay Management**
  - Upload screenplays as PDF or paste text directly
  - Track multiple versions with edit history and version notes
  - Automatic character extraction from scripts
  - Edit title, genre, logline, and metadata
  - Delete screenplays with cascade to related audio versions

- **Projects (Series/Anthology Organization)**
  - Create projects for TV series, limited series, anthologies, or miniseries
  - Organize episodes into seasons (hierarchical) or flat episode lists
  - Series bible documents with world-building, tone/style guides, and themes
  - Recurring character management across episodes with role types
  - Episode numbering with automatic codes (S01E05 format)
  - Track project status: active, completed, hiatus, archived
  - Genre and episode format metadata (30min, 60min, feature, short)

- **Commission Voice Artists**
  - Browse available voice artists with pricing info
  - Multi-step commission request: Select Performer → Set Budget → Pay
  - Secure payment via Stripe Checkout
  - Real-time messaging with performers
  - Review submissions and request revisions (included retakes)
  - Approve final recordings to release payment

- **Discovery & Social**
  - Browse audio performances of your scripts
  - Mark favorite performances as "Author's Picks"
  - Like and discover other writers' work
  - View verified user profiles

### For Voice Artists

- **Pricing & Availability**
  - Multiple pricing models: per-page, per-page-per-character, flat rate, or quote-based
  - Set minimum rates and rush job multipliers
  - Define included retakes and additional retake pricing
  - Toggle commission acceptance on/off
  - Set maximum concurrent projects

- **Commission Management**
  - Receive commission requests with full screenplay access
  - Accept or decline with optional response message
  - View screenplay details and read scripts before accepting
  - Submit audio recordings (MP3, WAV, M4A, OGG, FLAC up to 100MB)
  - Handle revision requests with writer feedback
  - Track earnings and active commissions

- **Stripe Connect Integration**
  - Connect bank account for receiving payments
  - Express account onboarding flow
  - Automatic payouts on commission completion
  - Dashboard access for earnings tracking

- **Collectives (Groups & Ensembles)**
  - Create collectives for duo/group performances
  - Invite members via search with personalized messages
  - Manage member roles (admin/member)
  - Accept/decline collective invitations
  - Request to join existing collectives
  - Approve/reject join requests (admins)
  - Leave collectives (with last-admin protection)
  - Submit recordings as a collective for proper attribution
  - Collective profile pages with member listings

- **Profile Building**
  - Bio and performer type (solo, duo, group/ensemble)
  - Profile intro video
  - Social media links
  - Verification badge for verified artists

### For Everyone

- Mobile-first responsive design
- Browse screenplays by genre, popularity, or recency
- Listen to audio performances with built-in player
- View verified user profiles
- In-app notifications for updates
- Phone/email verification for account security

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Phoenix 1.7+ with LiveView 0.20+ |
| **Language** | Elixir 1.14+ |
| **Database** | SQLite (development) / PostgreSQL (production) |
| **Styling** | Tailwind CSS 3.x |
| **Icons** | Heroicons |
| **Payments** | Stripe Connect (marketplace payments) |
| **File Storage** | Cloudflare R2 (S3-compatible) with local fallback |
| **Authentication** | Custom phone/email verification |

## Getting Started

### Prerequisites

- Elixir 1.14+
- Erlang/OTP 26+
- Node.js 18+ (for assets)
- SQLite 3.x (development) or PostgreSQL 14+ (production)

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

## Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database (SQLite for dev, PostgreSQL for prod)
DATABASE_PATH=priv/repo/script_voice_dev.db
# Or for PostgreSQL:
# DATABASE_URL=ecto://postgres:postgres@localhost/script_voice_dev

# Phoenix
SECRET_KEY_BASE=your-secret-key-base
PHX_HOST=localhost
PORT=4000

# Stripe (for commission payments)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Cloudflare R2 (optional - falls back to local storage)
R2_ACCOUNT_ID=your-account-id
R2_ACCESS_KEY_ID=your-access-key
R2_SECRET_ACCESS_KEY=your-secret-key
R2_BUCKET_NAME=scriptvoice
R2_PUBLIC_URL=https://your-bucket.r2.dev
```

## Demo Accounts

After running `mix ecto.setup`, the following demo accounts are available:

### Writers

| Email | Name | Screenplays |
|-------|------|-------------|
| sarah@example.com | Sarah Chen | Sci-fi and family drama |
| marcus@example.com | Marcus Webb | Romance and drama |
| aisha@example.com | Aisha Patel | Thriller |

### Solo Voice Artists

| Email | Name | Pricing Model |
|-------|------|---------------|
| jake@example.com | Jake Morrison | Per page: $5/page, min $25 |
| emma@example.com | Emma Stone | Per page: $8/page, min $50 |
| michael@example.com | Michael Chang | Quote-based (flexible) |
| lin@example.com | Lin Zhou | Per page: $6/page, min $30 |
| david@example.com | David Kim | Per page/char: $4/page + $2/char |
| rachel@example.com | Rachel Torres | Per page/char: $4/page + $2/char |
| sam@example.com | Sam Peters | No pricing (free/passion projects) |
| mia@example.com | Mia Chen | No pricing (free/passion projects) |

### Collectives

| Collective | Slug | Members | Description |
|------------|------|---------|-------------|
| The Lighthouse Collective | `/collective/the-lighthouse-collective` | Jake (admin), Lin, Sam, Mia | Full-cast dramatic readings |
| David Kim & Rachel Torres | `/collective/david-kim-rachel-torres` | David (admin), Rachel (admin) | Husband-wife romantic duo |

### Sample Invitations & Join Requests

For testing collective workflows:

| Scenario | Details |
|----------|---------|
| Pending Invitation | Emma Stone has an invitation to join The Lighthouse Collective |
| Pending Join Request | Michael Chang has requested to join David Kim & Rachel Torres |

**Note**: All demo accounts are pre-verified. In development mode, enter the email to sign in (no password required).

## Project Structure

```
script_voice/
├── lib/
│   ├── script_voice/                 # Business logic (contexts)
│   │   ├── accounts.ex               # User management, verification
│   │   ├── accounts/
│   │   │   └── user.ex               # User schema
│   │   ├── screenplays.ex            # Screenplay CRUD, versioning
│   │   ├── screenplays/
│   │   │   ├── screenplay.ex         # Screenplay schema (with episode fields)
│   │   │   ├── screenplay_project.ex # Project schema (series/anthology)
│   │   │   ├── screenplay_season.ex  # Season schema
│   │   │   ├── series_bible.ex       # Series bible schema
│   │   │   └── project_character.ex  # Recurring character schema
│   │   ├── projects.ex               # Projects context (series management)
│   │   ├── audio.ex                  # Audio version management
│   │   ├── audio/
│   │   │   └── audio_version.ex      # Audio schema
│   │   ├── collectives.ex            # Collective management
│   │   ├── collectives/
│   │   │   ├── collective.ex         # Collective schema
│   │   │   ├── collective_membership.ex      # Membership schema
│   │   │   ├── collective_invitation.ex      # Invitation workflow
│   │   │   ├── collective_join_request.ex    # Join request workflow
│   │   │   └── join_request_message.ex       # Join request messaging
│   │   ├── commissions.ex            # Commission workflow
│   │   ├── commissions/
│   │   │   ├── commission_request.ex # Commission schema
│   │   │   ├── commission_submission.ex
│   │   │   ├── commission_message.ex
│   │   │   ├── performer_pricing.ex
│   │   │   ├── payment.ex
│   │   │   ├── stripe_account.ex
│   │   │   └── price_calculator.ex   # Fee calculations
│   │   ├── social.ex                 # Likes, follows
│   │   ├── notifications.ex          # In-app notifications
│   │   ├── stripe.ex                 # Stripe Connect integration
│   │   └── uploads.ex                # R2/local file uploads
│   │
│   └── script_voice_web/             # Web layer
│       ├── components/
│       │   ├── core_components.ex    # Form inputs, buttons, modals
│       │   └── layouts.ex            # Root + app layouts
│       ├── live/
│       │   ├── home_live.ex          # Landing page
│       │   ├── browse_live.ex        # Screenplay browsing
│       │   ├── screenplay_live.ex    # Screenplay details
│       │   ├── script_reader_live.ex # PDF/text reader
│       │   ├── profile_live.ex       # User profiles
│       │   ├── collective_live.ex    # Collective profiles
│       │   ├── project_live.ex       # Project management (series/anthology)
│       │   ├── collective_settings_live.ex   # Collective admin settings
│       │   ├── dashboard_live.ex     # Writer/performer dashboard (tabbed)
│       │   ├── commission_dashboard_live.ex  # Commission list
│       │   ├── commission_detail_live.ex     # Commission details
│       │   ├── commission_request_live.ex    # Request form
│       │   ├── payment_success_live.ex       # Payment confirmation
│       │   ├── performer_pricing_live.ex     # Pricing settings
│       │   ├── stripe_connect_live.ex        # Stripe onboarding
│       │   ├── verify_live.ex                # Verification flow
│       │   ├── demo_login_live.ex            # Demo accounts
│       │   └── components/
│       │       ├── commission_submit_audio_component.ex
│       │       ├── submit_audio_component.ex
│       │       └── upload_screenplay_component.ex
│       ├── controllers/
│       │   ├── session_controller.ex
│       │   └── stripe_webhook_controller.ex
│       └── router.ex
│
├── priv/
│   ├── repo/
│   │   ├── migrations/               # Database migrations
│   │   └── seeds.exs                 # Demo data
│   └── static/
│       └── uploads/                  # Local file storage fallback
│
├── assets/                           # Frontend assets (JS, CSS)
├── config/                           # Configuration files
└── test/                             # Test files
```

## Key Routes

### Public Routes

| Path | Description |
|------|-------------|
| `/` | Landing page |
| `/browse` | Browse all screenplays with filters |
| `/collectives` | Browse and discover voice artist collectives |
| `/screenplay/:id` | View screenplay details and audio versions |
| `/screenplay/:id/read` | Full-screen script reader (PDF/text) |
| `/profile/:id` | User profile page |
| `/collective/:slug` | Collective profile page |
| `/verify` | Phone/email verification flow |
| `/demo-login` | Demo account login (development only) |

### Dashboard Routes

| Path | Description |
|------|-------------|
| `/dashboard` | Main dashboard with tabs: Overview, My Scripts, Commissions, Profile |
| `/dashboard?tab=commissions` | Commissions tab (writers see Cancelled filter, performers see All) |
| `/dashboard?tab=collectives` | Collectives tab (performers only) - manage memberships, invitations, requests |
| `/commissions` | Redirects to `/dashboard?tab=commissions` |

### Collective Routes

| Path | Description |
|------|-------------|
| `/collective/:slug` | Collective profile with members and recordings |
| `/collective/:slug/settings` | Collective settings (admins only) - members, invitations, requests |

### Project Routes

| Path | Description |
|------|-------------|
| `/project/:id` | Project detail view with seasons, episodes, and series bible |
| `/project/:id/episode/new` | Add new episode to project |
| `/project/:id/season/:season_id` | View specific season within project |
| `/project/:id/bible` | Series bible editor |

### Commission Routes

| Path | Description |
|------|-------------|
| `/commissions/:id` | Commission detail + messaging |
| `/commissions/request/:screenplay_id` | Multi-step commission request form |
| `/commissions/payment/success` | Post-payment confirmation |

### Settings Routes

| Path | Description |
|------|-------------|
| `/settings/pricing` | Voice artist pricing configuration |
| `/settings/payments` | Stripe Connect onboarding |

### API Routes

| Path | Method | Description |
|------|--------|-------------|
| `/session` | POST | Login with credentials |
| `/session/:user_id` | GET | Demo login (dev only) |
| `/session` | DELETE | Logout |
| `/webhooks/stripe` | POST | Stripe webhook handler |

## Database Schema

### Core Tables

| Table | Purpose |
|-------|---------|
| `users` | Writers, voice artists, and visitors with verification status |
| `screenplays` | Scripts with version tracking, characters, and metadata |
| `audio_versions` | Recorded performances with performer/casting info and collective attribution |
| `likes` | User likes on screenplays and audio versions |

### Collectives System

| Table | Purpose |
|-------|---------|
| `collectives` | Voice artist groups/ensembles with profile info |
| `collective_memberships` | Member relationships with roles (admin/member) |
| `collective_invitations` | Invitation workflow with status, messages, expiration |
| `collective_join_requests` | Join request workflow with review status |
| `join_request_messages` | Back-and-forth messaging for join requests |

### Projects System (Series/Anthology)

| Table | Purpose |
|-------|---------|
| `screenplay_projects` | Series/anthology containers with metadata (type, genre, status) |
| `screenplay_seasons` | Optional season organization within projects |
| `series_bibles` | Project documentation (world-building, tone, themes) |
| `project_characters` | Recurring characters with role types and arc tracking |

**Note:** The `screenplays` table includes episode fields (`project_id`, `season_id`, `episode_number`, `episode_code`, `screenplay_type`) allowing screenplays to be standalone or part of a project.

### Commission System

| Table | Purpose |
|-------|---------|
| `performer_pricing` | Voice artist rate settings and availability |
| `commission_requests` | Commission workflow tracking with status |
| `commission_submissions` | Audio submissions with revision feedback |
| `commission_messages` | In-commission messaging thread |
| `payments` | Stripe payment records with fee breakdown |
| `stripe_accounts` | Connected Stripe account info |

### Supporting Tables

| Table | Purpose |
|-------|---------|
| `verification_codes` | Phone/email OTP codes |
| `notifications` | In-app notifications |

## Collectives System

Collectives allow voice artists to group together as duos, trios, or ensembles for collaborative performances.

### Collective Types

| Type | Members | Use Case |
|------|---------|----------|
| Duo | 2 | Romantic couples, debate scenes |
| Trio | 3 | Small ensembles, family scenes |
| Ensemble | 4+ | Full-cast dramatic readings |

### Membership Roles

| Role | Capabilities |
|------|-------------|
| **Admin** | Invite members, manage settings, approve join requests, remove members |
| **Member** | Submit recordings as collective, leave collective |

### Invitation Flow

```
Admin invites user ──→ User receives notification
                           │
                           ├──→ Accept ──→ Becomes member
                           │
                           └──→ Decline ──→ Invitation closed
```

### Join Request Flow

```
Non-member requests to join ──→ Admins see request with message
         │                              │
         │                              ├──→ Message back and forth
         │                              │         │
         │                              │         ├──→ Admin replies ──→ User notified
         │                              │         └──→ User replies ──→ Admin notified
         │                              │
         │                              ├──→ Approve ──→ Becomes member
         │                              │
         │                              └──→ Reject (with reason) ──→ User sees rejection
         │
         └──→ User can cancel request anytime
```

Join requests support full back-and-forth messaging between the requestor and collective admins before any decision is made. Both parties can see the complete conversation thread.

### Audio Attribution

When a collective member submits a recording:

1. Recording is linked to both the **submitter** (user) and the **collective**
2. Clicking the performer name on audio cards navigates to the **collective profile** (not submitter)
3. All collective members see the recording in their personal profile's "Recordings" section
4. Collective profile shows all recordings submitted by any member

### Dashboard Integration

Voice artists see a "Collectives" tab in their dashboard with:

- **My Collectives**: List of collectives where user is a member
- **Create Collective**: Form to create a new collective
- **Pending Invitations**: Invitations received from other collectives
- **Pending Requests**: Join requests user has sent (with cancel option)

## Projects System

Projects allow writers to organize screenplays into series, anthologies, limited series, or miniseries with optional season-based hierarchy.

### Project Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Series** | Ongoing TV series with multiple seasons | Long-running dramas, sitcoms |
| **Anthology** | Standalone episodes with shared theme | Twilight Zone-style collections |
| **Miniseries** | Limited episode count, complete story | 6-10 episode limited series |

### Organization Modes

Projects support two organization modes:

**Flat Organization:**
```
Project "The Quiet Ones"
├── Episode 1: "Arrival"
├── Episode 2: "Discovery"
├── Episode 3: "Confrontation"
└── Episode 4: "Resolution"
```

**Hierarchical Organization (Seasons):**
```
Project "Midnight Chronicles"
├── Season 1: "The Beginning"
│   ├── S01E01: "Pilot"
│   ├── S01E02: "Dark Waters"
│   └── S01E03: "Revelations"
├── Season 2: "Rising Conflict"
│   ├── S02E01: "New Dawn"
│   └── S02E02: "Breaking Point"
└── Season 3: "Reckoning"
    └── ...
```

### Episode Codes

Episodes automatically receive formatted codes:
- **With Season**: `S01E05` (Season 1, Episode 5)
- **Without Season**: `E005` (Episode 5)

### Series Bible

Each project can have a series bible document containing:

| Section | Description |
|---------|-------------|
| **Content** | Main bible document text |
| **World Building** | Setting, rules, history |
| **Tone & Style** | Visual/audio direction, mood |
| **Themes** | Core themes and motifs |

### Project Characters

Recurring characters can be tracked at the project level:

| Field | Description |
|-------|-------------|
| **Name** | Character name |
| **Role Type** | Lead, Supporting, Recurring, Guest |
| **Description** | Character background and personality |
| **Gender** | Character gender |
| **Age Range** | Age bracket (child, teen, young adult, adult, senior) |
| **Character Arc** | Development across the series |
| **First Appearance** | Episode where character debuts |
| **Active Status** | Whether character is still in the series |

### Project Status

| Status | Description |
|--------|-------------|
| `active` | Currently in development/production |
| `completed` | All episodes finished |
| `hiatus` | Temporarily paused |
| `archived` | No longer active |

### Dashboard Integration

Writers see projects in their dashboard alongside standalone screenplays:

- **Projects Tab**: List of all projects with episode counts
- **Create Project**: Form with title, type, genre, logline
- **Project View**: Accordion-based season/episode browser
- **Series Bible Editor**: Full editor for project documentation
- **Episode Management**: Add, edit, reorder episodes

### Backward Compatibility

Existing standalone screenplays continue to work unchanged. The `screenplay_type` field distinguishes:

| Type | Description |
|------|-------------|
| `standalone` | Independent screenplay (default) |
| `episode` | Regular series episode |
| `pilot` | Series premiere episode |
| `finale` | Season or series finale |
| `special` | Holiday or special episode |

## Commission System

### Status Lifecycle

```
pending ──┬──→ accepted ──→ in_progress ──→ submitted ──┬──→ completed ✓
          │                                              │
          │                                              └──→ revision_requested ──→ [resubmit]
          │
          ├──→ declined ✗
          └──→ cancelled ✗
```

### Status Descriptions

| Status | Description |
|--------|-------------|
| `pending` | Awaiting performer response |
| `accepted` | Performer committed, payment held in escrow |
| `in_progress` | Performer recording |
| `submitted` | Audio uploaded for writer review |
| `revision_requested` | Writer requested changes (uses 1 retake) |
| `completed` | Approved, payment released to performer |
| `declined` | Performer declined the request |
| `cancelled` | Either party cancelled |

### Retake System

- Default: 2 retakes included per commission
- Configurable per voice artist in pricing settings
- Each revision request consumes 1 retake
- Additional retakes can be priced separately

## Payment Flow

### Escrow Model

ScriptVoice uses an escrow payment model to protect both writers and performers:

```
1. Writer requests commission
   └── Redirects to Stripe Checkout

2. Payment captured
   └── Funds held in platform account (status: "held")

3. Performer accepts & works
   └── Payment remains in escrow

4. Performer submits audio
   └── Writer reviews submission

5. Writer approves
   └── Payment transferred to performer's Stripe account
   └── Platform fee (10%) deducted

6. Performer receives payout
   └── Status: "completed"
```

### Fee Breakdown

For a $100 commission:

**Writer Pays:**
| Item | Amount |
|------|--------|
| Commission Amount | $100.00 |
| Processing Fee (2.9% + $0.30) | $3.20 |
| **Total** | **$103.20** |

**Performer Receives:**
| Item | Amount |
|------|--------|
| Commission Amount | $100.00 |
| Platform Fee (10%) | -$10.00 |
| **Payout** | **$90.00** |

### Stripe Connect

Voice artists connect their Stripe accounts via Express onboarding:

1. Navigate to `/settings/payments`
2. Click "Connect with Stripe"
3. Complete Stripe's onboarding flow
4. Return to ScriptVoice with connected account
5. Start accepting paid commissions

## File Storage

### Upload Support

| Type | Formats | Max Size |
|------|---------|----------|
| Screenplays | PDF, TXT (paste) | 50MB |
| Audio | MP3, WAV, M4A, OGG, FLAC, audio/* | 100MB |
| Profile Video | MP4, MOV, WEBM | 100MB |

### Storage Backends

1. **Cloudflare R2** (Production)
   - S3-compatible object storage
   - Public URLs for file serving
   - Configured via environment variables

2. **Local Storage** (Development Fallback)
   - Files stored in `priv/static/uploads/`
   - Served via Phoenix static plug
   - Automatic fallback when R2 not configured

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

# Drop database
mix ecto.drop

# Create database
mix ecto.create
```

### Asset Building

```bash
# Development build (with watching)
mix phx.server  # Assets built automatically

# Production build
mix assets.deploy
```

### LiveDashboard

In development, visit `/dev/dashboard` for:
- Real-time metrics
- Process information
- ETS table inspection
- Socket connections

## Deployment

### Production Configuration

1. Set all environment variables
2. Configure database connection via `DATABASE_URL`
3. Set `PHX_HOST` to your domain
4. Configure Stripe webhook endpoints:
   - `https://yourdomain.com/webhooks/stripe`
5. Set up R2 bucket with public access

### Release Build

```bash
# Build release
MIX_ENV=prod mix release

# Run migrations
_build/prod/rel/script_voice/bin/script_voice eval "ScriptVoice.Release.migrate"

# Start server
_build/prod/rel/script_voice/bin/script_voice start
```

### Docker Deployment

```dockerfile
# Example Dockerfile
FROM elixir:1.14-alpine AS build
# ... build steps ...

FROM alpine:3.18
# ... runtime configuration ...
```

## API Integrations

### Stripe Connect

Full marketplace payment integration:
- Express account creation for performers
- Checkout Sessions for secure payment
- Payment intents with escrow capability
- Automatic transfers on commission approval
- Webhook handling for payment events

### Cloudflare R2

S3-compatible file storage:
- Audio file uploads
- PDF screenplay uploads
- Public URL generation
- CORS configuration for browser uploads

### Future Integrations (Planned)

- **Twilio**: SMS verification
- **SendGrid/SES**: Email notifications
- **Claude API**: Automatic character extraction from screenplays
- **FFprobe**: Audio metadata extraction (duration, format)

## Recent Changes

### Version 2.3 (February 2026)

- **Projects System**: Complete multi-episode/series screenplay organization
  - Create projects for TV series, limited series, anthologies, or miniseries
  - Organize episodes with flat structure or hierarchical seasons
  - Series bible documents with world-building, tone/style, and themes
  - Recurring character management with role types (lead, supporting, recurring, guest)
  - Episode numbering with automatic codes (S01E05 format)
  - Project status tracking: active, completed, hiatus, archived
  - Dashboard integration with project creation and management
  - Dedicated project view with accordion-based season browser
  - Full backward compatibility with existing standalone screenplays

- **New Database Tables**:
  - `screenplay_projects`: Project containers with metadata
  - `screenplay_seasons`: Season organization within projects
  - `series_bibles`: Project documentation storage
  - `project_characters`: Recurring character tracking

- **New Routes**:
  - `/project/:id`: Project detail view
  - `/project/:id/episode/new`: Add episode
  - `/project/:id/season/:season_id`: Season view
  - `/project/:id/bible`: Series bible editor

### Version 2.2 (February 2026)

- **Join Request Messaging**: Full conversation support for join requests
  - Back-and-forth messaging between requestor and collective admins
  - Conversation thread visible on both sides (dashboard + collective page)
  - Reply input for both requestor and admin
  - Notifications sent when either party sends a message
  - Rejection reasons displayed to requestor with decline status
  - New `join_request_messages` table for persistent message storage

### Version 2.1 (February 2026)

- **Collectives Feature**: Complete implementation for voice artist groups
  - Create and manage collectives (duos, groups, ensembles)
  - **Browse Collectives page** (`/collectives`) - discover and search collectives
  - Dashboard "Collectives" tab for performers to view and manage memberships
  - Invitation-based member management with personalized messages
  - Join request workflow for non-members to request membership
  - Quick "Request to Join" directly from browse page
  - Collective profile pages with member listings and recordings
  - Admin settings page for managing members, invitations, and requests
  - Proper audio attribution: recordings link to collective profiles
  - Member recordings: collective members see group recordings in their profile
  - Leave collective functionality with last-admin protection

- **Navigation Updates**:
  - Main nav now has "Scripts" and "Collectives" links
  - Voice artist dropdown includes "My Collectives" quick link
  - Audio version cards link to collective profile when applicable
  - Collective member profiles show recordings from their collectives

### Version 2.0 (February 2026)

- **Payment Flow**: Complete Stripe Checkout integration with escrow
- **Commission UX**: Screenplay access for performers, improved navigation
- **User Type Separation**: Clear separation of writer/performer views
- **Filter Counts**: Commission filter tabs show counts
- **Version Tracking**: Screenplay versioning with edit history
- **PDF Viewer**: Embedded PDF reader for screenplays
- **Audio Upload**: Wildcard MIME type support (audio/*)
- **Local Fallback**: File storage works without R2 configured

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and formatting (`mix test && mix format`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

Private - All rights reserved.
