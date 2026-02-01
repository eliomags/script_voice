# ScriptVoice Commission System - Implementation Plan

## Overview

This document outlines the complete implementation plan for adding a paid commission system where screenplay writers can hire voice artists to perform their scripts.

## Table of Contents
1. [User Stories](#user-stories)
2. [Database Schema](#database-schema)
3. [Business Logic](#business-logic)
4. [State Machine](#state-machine)
5. [Price Calculation](#price-calculation)
6. [UI/UX Flows](#uiux-flows)
7. [Notification System](#notification-system)
8. [Implementation Phases](#implementation-phases)

---

## User Stories

### As a Voice Artist (Performer)
1. I want to set my pricing structure so writers know my rates
2. I want to see commission requests from writers
3. I want to accept or decline requests with a message
4. I want to see the screenplay details before accepting
5. I want to upload my audio submission when ready
6. I want to see feedback from writers
7. I want to submit retakes within my agreed limits
8. I want to track my commission history and earnings

### As a Writer (Author)
1. I want to request specific voice artists to perform my script
2. I want to see their pricing and calculated cost for my script
3. I want to set my own budget/offer amount
4. I want to track the status of my commission requests
5. I want to review submitted audio and provide feedback
6. I want to request revisions (within limits)
7. I want to approve final submissions
8. I want approved commissions to be marked as "Author's Pick"

### As a Visitor/Browser
1. I can see which audio versions are paid commissions vs free submissions
2. I can see Author's Picks highlighted

---

## Database Schema

### New Tables

#### 1. `performer_pricing` - Voice Artist Rate Settings
```sql
CREATE TABLE performer_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Pricing Model
  pricing_model VARCHAR(20) NOT NULL DEFAULT 'per_page',
    -- 'per_page': rate × pages
    -- 'per_page_per_character': rate × pages × characters
    -- 'flat': single flat rate
    -- 'quote': custom quote per project

  -- Rate Settings (in cents to avoid float issues)
  per_page_rate_cents INTEGER,           -- e.g., 500 = $5.00 per page
  per_character_rate_cents INTEGER,      -- additional per character
  flat_rate_cents INTEGER,               -- flat project rate
  minimum_rate_cents INTEGER,            -- minimum project rate

  -- Retake Policy
  included_retakes INTEGER NOT NULL DEFAULT 2,
  retake_rate_cents INTEGER,             -- cost per additional retake

  -- Rush Jobs
  rush_multiplier_percent INTEGER DEFAULT 50,  -- 50 = 1.5x normal rate
  rush_days_threshold INTEGER DEFAULT 3,       -- projects < X days = rush

  -- Availability
  is_accepting_commissions BOOLEAN NOT NULL DEFAULT true,
  max_concurrent_projects INTEGER DEFAULT 5,
  typical_turnaround_days INTEGER DEFAULT 7,

  -- Additional Info
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  notes TEXT,                            -- special terms, restrictions

  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  UNIQUE(user_id)
);
```

#### 2. `commission_requests` - The Commission/Job
```sql
CREATE TABLE commission_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Parties
  screenplay_id UUID NOT NULL REFERENCES screenplays(id) ON DELETE CASCADE,
  writer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  performer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Status (see state machine)
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
    -- pending, accepted, declined, in_progress,
    -- submitted, revision_requested, completed, cancelled

  -- Pricing
  calculated_amount_cents INTEGER,       -- auto-calculated from performer rates
  offered_amount_cents INTEGER,          -- what writer offered
  agreed_amount_cents INTEGER,           -- final agreed amount

  -- Communication
  writer_message TEXT,                   -- initial request message
  performer_response TEXT,               -- accept/decline message

  -- Timeline
  deadline DATE,
  is_rush BOOLEAN NOT NULL DEFAULT false,

  -- Retakes
  retakes_included INTEGER NOT NULL DEFAULT 2,
  retakes_used INTEGER NOT NULL DEFAULT 0,

  -- Result
  final_audio_version_id UUID REFERENCES audio_versions(id),

  -- Tracking
  accepted_at TIMESTAMP,
  submitted_at TIMESTAMP,
  completed_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  cancelled_by UUID REFERENCES users(id),
  cancellation_reason TEXT,

  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_commission_requests_writer ON commission_requests(writer_id);
CREATE INDEX idx_commission_requests_performer ON commission_requests(performer_id);
CREATE INDEX idx_commission_requests_screenplay ON commission_requests(screenplay_id);
CREATE INDEX idx_commission_requests_status ON commission_requests(status);
```

#### 3. `commission_submissions` - Audio Submissions for Commission
```sql
CREATE TABLE commission_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_request_id UUID NOT NULL REFERENCES commission_requests(id) ON DELETE CASCADE,

  -- Audio
  audio_url VARCHAR(500) NOT NULL,
  duration INTEGER,                      -- in seconds
  file_size_bytes INTEGER,

  -- Submission Info
  submission_number INTEGER NOT NULL,    -- 1 = initial, 2+ = retakes
  performer_notes TEXT,                  -- notes from performer

  -- Review
  status VARCHAR(20) NOT NULL DEFAULT 'pending_review',
    -- pending_review, approved, revision_requested
  writer_feedback TEXT,
  reviewed_at TIMESTAMP,

  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_commission_submissions_request ON commission_submissions(commission_request_id);
```

#### 4. `commission_messages` - Communication Thread
```sql
CREATE TABLE commission_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_request_id UUID NOT NULL REFERENCES commission_requests(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  message TEXT NOT NULL,
  message_type VARCHAR(20) NOT NULL DEFAULT 'message',
    -- message, revision_request, status_update

  -- Attachments (optional)
  attachment_url VARCHAR(500),
  attachment_type VARCHAR(50),

  read_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_commission_messages_request ON commission_messages(commission_request_id);
```

#### 5. `notifications` - User Notifications
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Content
  type VARCHAR(50) NOT NULL,
    -- commission_request_received, commission_accepted, commission_declined,
    -- submission_received, revision_requested, commission_completed,
    -- commission_cancelled, message_received
  title VARCHAR(200) NOT NULL,
  body TEXT,

  -- Related Entity
  related_type VARCHAR(50),              -- 'commission_request', 'submission', etc.
  related_id UUID,

  -- Link
  action_url VARCHAR(500),

  -- Status
  read_at TIMESTAMP,
  email_sent_at TIMESTAMP,

  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id) WHERE read_at IS NULL;
```

### Modified Tables

#### `audio_versions` - Add commission link
```sql
ALTER TABLE audio_versions ADD COLUMN commission_request_id UUID REFERENCES commission_requests(id);
ALTER TABLE audio_versions ADD COLUMN is_paid_commission BOOLEAN NOT NULL DEFAULT false;
```

---

## Business Logic

### Contexts to Create

#### 1. `ScriptVoice.Commissions`
```elixir
# Performer Pricing
- get_performer_pricing(user_id)
- upsert_performer_pricing(user_id, attrs)
- calculate_commission_price(screenplay, performer_pricing)

# Commission Requests
- create_commission_request(screenplay, writer, performer, attrs)
- get_commission_request(id)
- list_commission_requests_for_writer(writer_id, opts)
- list_commission_requests_for_performer(performer_id, opts)
- accept_commission(commission, performer_response, agreed_amount)
- decline_commission(commission, reason)
- cancel_commission(commission, user, reason)

# Submissions
- submit_audio(commission, audio_url, notes)
- request_revision(submission, feedback)
- approve_submission(submission)
- get_submissions_for_commission(commission_id)

# Messages
- send_message(commission_id, sender_id, message, type)
- list_messages(commission_id)
- mark_messages_read(commission_id, user_id)
```

#### 2. `ScriptVoice.Notifications`
```elixir
- create_notification(user_id, type, title, body, related)
- list_notifications(user_id, opts)
- mark_read(notification_id)
- mark_all_read(user_id)
- get_unread_count(user_id)
- subscribe_to_notifications(user_id)  # PubSub
```

---

## State Machine

```
Commission Request States:

                    ┌─────────────┐
                    │   pending   │ (writer sends request)
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            │            ▼
      ┌───────────┐        │    ┌───────────┐
      │ declined  │        │    │ cancelled │
      └───────────┘        │    └───────────┘
                           ▼
                    ┌─────────────┐
                    │  accepted   │ (performer accepts)
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ in_progress │ (performer working)
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  submitted  │ (audio uploaded)
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
    ┌──────────────────┐        ┌─────────────┐
    │revision_requested│───────▶│ in_progress │ (loop, limited)
    └──────────────────┘        └─────────────┘
              │
              └─────────────────────────┐
                                        ▼
                                 ┌─────────────┐
                                 │  completed  │ (writer approves)
                                 └─────────────┘

Cancellation possible from: pending, accepted, in_progress
```

---

## Price Calculation

```elixir
defmodule ScriptVoice.Commissions.PriceCalculator do
  def calculate(screenplay, pricing) do
    base_amount = case pricing.pricing_model do
      "per_page" ->
        screenplay.page_count * pricing.per_page_rate_cents

      "per_page_per_character" ->
        char_count = length(screenplay.characters)
        screenplay.page_count * pricing.per_page_rate_cents +
        screenplay.page_count * char_count * pricing.per_character_rate_cents

      "flat" ->
        pricing.flat_rate_cents

      "quote" ->
        nil  # Requires manual quote
    end

    # Apply minimum rate
    base_amount = if base_amount && pricing.minimum_rate_cents do
      max(base_amount, pricing.minimum_rate_cents)
    else
      base_amount
    end

    %{
      base_amount_cents: base_amount,
      pricing_model: pricing.pricing_model,
      breakdown: %{
        pages: screenplay.page_count,
        characters: length(screenplay.characters),
        per_page_rate: pricing.per_page_rate_cents,
        per_character_rate: pricing.per_character_rate_cents,
        minimum_rate: pricing.minimum_rate_cents
      },
      included_retakes: pricing.included_retakes,
      retake_rate_cents: pricing.retake_rate_cents
    }
  end
end
```

---

## UI/UX Flows

### Flow 1: Voice Artist Sets Pricing

**Location:** Profile Settings or dedicated Pricing page

```
┌─────────────────────────────────────────────────────────┐
│  Your Pricing Settings                                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Accepting Commissions: [✓ Yes]                        │
│                                                         │
│  Pricing Model: [▼ Per Page]                           │
│    ○ Per Page                                          │
│    ○ Per Page + Per Character                          │
│    ○ Flat Rate                                         │
│    ○ Custom Quote                                      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Per Page Rate: $[____] per page                   │ │
│  │ Minimum Project Rate: $[____]                     │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  Retake Policy:                                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Included Retakes: [2▼]                            │ │
│  │ Additional Retake Rate: $[____] each              │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  Rush Jobs (< 3 days):                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Rush Fee: [50]% additional                        │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  Typical Turnaround: [7] days                          │
│  Max Concurrent Projects: [5]                          │
│                                                         │
│  Notes for Clients:                                    │
│  ┌───────────────────────────────────────────────────┐ │
│  │ [________________________________________________]│ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  [Save Pricing Settings]                               │
└─────────────────────────────────────────────────────────┘
```

### Flow 2: Writer Requests Commission

**Location:** Screenplay detail page → "Request Performance" button

```
Step 1: Select Voice Artist
┌─────────────────────────────────────────────────────────┐
│  Request Performance for "The Last Light"               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Select Voice Artist:                                   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔍 Search voice artists...                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Recommended (based on genre/style):                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ● Emma Stone [Solo] ✓ Verified                  │   │
│  │   $15/page • 2 retakes included • ~5 day turn   │   │
│  │   Estimated: $180 for 12 pages                  │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ○ The Lighthouse Collective [Group] ✓ Verified  │   │
│  │   $25/page + $5/character • ~7 day turn         │   │
│  │   Estimated: $540 for 12 pages, 4 characters    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [Next: Set Budget →]                                  │
└─────────────────────────────────────────────────────────┘

Step 2: Set Budget & Message
┌─────────────────────────────────────────────────────────┐
│  Commission Details                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Script: "The Last Light" (12 pages, 4 characters)     │
│  Performer: Emma Stone                                  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Calculated Rate: $180.00                        │   │
│  │ (Based on $15/page × 12 pages)                  │   │
│  │                                                  │   │
│  │ Includes 2 revision rounds                      │   │
│  │ Additional revisions: $25 each                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Your Offer: $[180.00]                                 │
│  (Minimum: $180.00 based on performer's rates)         │
│                                                         │
│  Deadline (optional): [____________] 📅               │
│  ⚠️ Less than 3 days = rush fee (+50%)                │
│                                                         │
│  Message to Performer:                                  │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Hi Emma, I love your previous work and think    │   │
│  │ your voice would be perfect for Maya...         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [← Back]                    [Send Request →]          │
└─────────────────────────────────────────────────────────┘
```

### Flow 3: Voice Artist Reviews Request

**Location:** Notifications / Commission Dashboard

```
┌─────────────────────────────────────────────────────────┐
│  New Commission Request                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  From: Sarah Chen (Writer) ✓ Verified                  │
│  Script: "The Last Light"                              │
│  Genre: Sci-Fi • 12 pages • 4 characters               │
│                                                         │
│  [View Full Script]                                    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Characters:                                      │   │
│  │ • MAYA (Female) - 45 lines                      │   │
│  │ • COMMANDER VOSS (Male) - 28 lines              │   │
│  │ • THE VOICE (Unknown) - 15 lines                │   │
│  │ • TOMMY (Male) - 12 lines                       │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Offer: $200.00                                        │
│  (Your rate: $180.00 • Offer is $20 above)            │
│                                                         │
│  Deadline: Feb 15, 2026 (14 days)                     │
│  Retakes: 2 included                                   │
│                                                         │
│  Message from Sarah:                                    │
│  "Hi Emma, I love your previous work and think..."    │
│                                                         │
│  Your Response (optional):                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [________________________________________________]│  │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [Decline]              [Accept Commission →]          │
└─────────────────────────────────────────────────────────┘
```

### Flow 4: Commission Dashboard

```
┌─────────────────────────────────────────────────────────┐
│  My Commissions                      [As Writer ▼]     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Active (3)                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ "The Last Light" → Emma Stone                   │   │
│  │ Status: In Progress    Due: Feb 15              │   │
│  │ $200.00                            [View →]     │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ "Coffee for Two" → The Lighthouse Collective    │   │
│  │ Status: Submitted - Review Needed   Due: Feb 10 │   │
│  │ $350.00                            [Review →]   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Pending (1)                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ "Hollow Men" → Jake Morrison                    │   │
│  │ Status: Awaiting Response    Sent: Jan 28       │   │
│  │ $275.00                            [View →]     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Completed (12)                        [View All →]    │
└─────────────────────────────────────────────────────────┘
```

---

## Notification System

### Notification Types

| Type | Recipient | Trigger | Title Example |
|------|-----------|---------|---------------|
| commission_request_received | Performer | Writer sends request | "New commission request from Sarah Chen" |
| commission_accepted | Writer | Performer accepts | "Emma Stone accepted your commission" |
| commission_declined | Writer | Performer declines | "Commission request declined" |
| submission_received | Writer | Performer uploads audio | "Audio submitted for 'The Last Light'" |
| revision_requested | Performer | Writer requests changes | "Revision requested for 'The Last Light'" |
| commission_completed | Both | Writer approves | "Commission completed!" |
| commission_cancelled | Other party | Either cancels | "Commission cancelled" |
| message_received | Other party | New message sent | "New message from Sarah Chen" |

### Real-time Delivery

Using Phoenix PubSub:
```elixir
# Subscribe user to their notifications channel
Phoenix.PubSub.subscribe(ScriptVoice.PubSub, "notifications:#{user_id}")

# Broadcast new notification
Phoenix.PubSub.broadcast(ScriptVoice.PubSub, "notifications:#{user_id}", {:new_notification, notification})
```

---

## Implementation Phases

### Phase 1: Database & Core Models (Day 1)
- [ ] Create migrations for all new tables
- [ ] Create Ecto schemas: PerformerPricing, CommissionRequest, CommissionSubmission, CommissionMessage, Notification
- [ ] Create Commissions context with basic CRUD
- [ ] Create Notifications context

### Phase 2: Performer Pricing UI (Day 2)
- [ ] Create PerformerPricingLive page
- [ ] Add pricing settings to voice artist profile/settings
- [ ] Display pricing on performer profile (public view)
- [ ] Price calculation logic

### Phase 3: Commission Request Flow (Day 3)
- [ ] "Request Performance" button on screenplay page
- [ ] CommissionRequestLive - multi-step form
- [ ] Voice artist selection with pricing display
- [ ] Request submission

### Phase 4: Request Response Flow (Day 4)
- [ ] Performer notification of new request
- [ ] Request review page
- [ ] Accept/Decline functionality
- [ ] Writer notification of response

### Phase 5: Submission & Review (Day 5)
- [ ] Performer can upload audio for commission
- [ ] Writer sees submission, can play audio
- [ ] Feedback/revision request functionality
- [ ] Retake limits enforcement

### Phase 6: Completion & Integration (Day 6)
- [ ] Approval workflow
- [ ] Auto-create AudioVersion on completion
- [ ] Mark as Author's Pick
- [ ] Commission history views

### Phase 7: Dashboard & Polish (Day 7)
- [ ] CommissionDashboardLive for both roles
- [ ] Full notification system
- [ ] Email notifications (optional)
- [ ] Edge cases and error handling

---

## Open Questions

1. **Payment Processing**: Is this MVP tracking only, or do we need Stripe integration?
2. **Escrow**: Should payments be held until completion?
3. **Dispute Resolution**: What happens if writer never approves?
4. **Platform Fee**: Will ScriptVoice take a percentage?
5. **Refunds**: What's the cancellation/refund policy?
6. **Contracts**: Any legal agreement needed between parties?

---

## Files to Create/Modify

### New Files
```
lib/script_voice/commissions.ex
lib/script_voice/commissions/performer_pricing.ex
lib/script_voice/commissions/commission_request.ex
lib/script_voice/commissions/commission_submission.ex
lib/script_voice/commissions/commission_message.ex
lib/script_voice/commissions/price_calculator.ex

lib/script_voice/notifications.ex
lib/script_voice/notifications/notification.ex

lib/script_voice_web/live/performer_pricing_live.ex
lib/script_voice_web/live/commission_request_live.ex
lib/script_voice_web/live/commission_dashboard_live.ex
lib/script_voice_web/live/commission_detail_live.ex

priv/repo/migrations/TIMESTAMP_create_performer_pricing.exs
priv/repo/migrations/TIMESTAMP_create_commission_requests.exs
priv/repo/migrations/TIMESTAMP_create_commission_submissions.exs
priv/repo/migrations/TIMESTAMP_create_commission_messages.exs
priv/repo/migrations/TIMESTAMP_create_notifications.exs
priv/repo/migrations/TIMESTAMP_add_commission_to_audio_versions.exs
```

### Modified Files
```
lib/script_voice_web/router.ex - Add commission routes
lib/script_voice_web/components/core_components.ex - Add commission components
lib/script_voice_web/live/screenplay_live.ex - Add "Request Performance" button
lib/script_voice_web/live/profile_live.ex - Show pricing for voice artists
lib/script_voice_web/components/layouts/app.html.heex - Add notifications indicator
```
