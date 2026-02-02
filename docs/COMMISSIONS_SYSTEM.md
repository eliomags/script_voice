# ScriptVoice Commissions System

## Overview

The **Commissions** feature is a marketplace system that connects **Writers** with **Voice Artists/Audio Performers**. It allows Writers to hire Voice Artists to record professional audio performances of their screenplays, with built-in payment escrow, revision management, and messaging.

---

## For Writers

### Purpose:
Writers use commissions to **hire voice talent** to bring their screenplays to life with professional audio recordings.

### Writer Workflow:

1. **Request a Performance**
   - Browse a screenplay → Find a Voice Artist → Click "Request Performance"
   - Set your budget, deadline, and number of retakes
   - Send a message explaining what you're looking for

2. **Wait for Response**
   - Commission shows as **"Pending"** until performer responds
   - Performer can Accept, Decline, or negotiate the price

3. **Payment Captured**
   - When performer accepts, your payment is **held in escrow**
   - Money is NOT released until you approve the final audio

4. **Review Submissions**
   - Performer uploads audio → You receive notification
   - Listen to the recording
   - **Approve** → Commission completed, payment released to performer
   - **Request Revision** → Uses 1 retake, performer must resubmit (default: 2 retakes included)

5. **Completion**
   - Final audio becomes available on the screenplay page
   - Payment released to performer (minus 10% platform fee)

### Writer Pays:
```
Commission Amount (your offer)
+ Processing Fee (Stripe: 2.9% + $0.30)
= Total
```

---

## For Voice Artists/Audio Performers

### Purpose:
Voice Artists use commissions to **earn money** by recording audio performances of screenplays.

### Performer Setup (Required First):
1. Go to **Settings → Pricing** to set up rates:
   - Pricing model: per page, per character, flat rate, or quote
   - Minimum rate
   - Rush fee multiplier (for tight deadlines)
   - Number of included retakes

2. Go to **Settings → Payments** to connect **Stripe** (required to receive payouts)

### Performer Workflow:

1. **Receive Commission Request**
   - Shows in Commissions tab as **"Pending"**
   - See screenplay details, writer's message, and offered amount

2. **Accept or Decline**
   - **Accept** → Payment is captured, you commit to the work
   - **Decline** → Commission ends, writer notified
   - Can negotiate the agreed amount before accepting

3. **Record & Submit**
   - Read the screenplay, record your performance
   - Upload audio (MP3, WAV, M4A, etc. up to 100MB)
   - Add any notes for the writer

4. **Handle Revisions** (if requested)
   - Writer may request changes (uses 1 of your included retakes)
   - Review their feedback
   - Resubmit with updated recording

5. **Get Paid**
   - Writer approves → Commission marked **"Completed"**
   - Payment transferred to your Stripe account

### Performer Receives:
```
Agreed Amount
- Platform Fee (10%)
= Your Payout
```

---

## Commission Status Lifecycle

```
pending ──┬──→ accepted ──→ in_progress ──→ submitted ──┬──→ completed ✓
          │                                             │
          │                                             └──→ revision_requested ──→ [resubmit]
          │
          ├──→ declined ✗
          └──→ cancelled ✗
```

| Status | Meaning |
|--------|---------|
| `pending` | Waiting for performer to accept/decline |
| `accepted` | Performer accepted, payment held in escrow |
| `in_progress` | Performer working on recording |
| `submitted` | Audio uploaded, waiting for writer review |
| `revision_requested` | Writer requested changes |
| `completed` | Approved! Payment released |
| `declined` | Performer declined the request |
| `cancelled` | Either party cancelled |

---

## Database Schema

### CommissionRequest
- `screenplay_id`, `writer_id`, `performer_id` - Foreign keys
- `status` - One of 9 possible statuses
- `calculated_amount_cents` - Auto-calculated based on pricing
- `offered_amount_cents` - Writer's offer
- `agreed_amount_cents` - Final negotiated amount
- `deadline` - Due date
- `is_rush` - Rush order flag
- `retakes_included` - Number of revisions allowed (default: 2)
- `retakes_used` - Counter for revisions used

### CommissionSubmission
- `audio_url` - URL to uploaded audio file
- `duration` - Audio length in seconds
- `submission_number` - 1 = initial, 2+ = retakes
- `status` - pending_review, approved, revision_requested
- `writer_feedback` - Revision notes from writer

### Payment
- `amount_cents` - Commission amount
- `processing_fee_cents` - Stripe fees (2.9% + $0.30)
- `platform_fee_cents` - 10% platform fee
- `performer_payout_cents` - Amount performer receives
- `status` - pending, held, completed, refunded

### PerformerPricing
- `pricing_model` - per_page, per_page_per_character, flat, quote
- `per_page_rate_cents`, `flat_rate_cents`, etc.
- `included_retakes` - Default retakes per commission
- `rush_multiplier_percent` - Extra fee for rush orders
- `is_accepting_commissions` - Toggle availability

---

## Key Routes

| Route | Purpose |
|-------|---------|
| `/commissions` | Commission dashboard (list all) |
| `/commissions/:id` | Commission detail page |
| `/commissions/new/:screenplay_id` | Start new commission request |
| `/settings/pricing` | Performer pricing setup |
| `/settings/payments` | Stripe Connect setup |

---

## Platform Economics

**Example: $100 Commission**

| Line Item | Amount |
|-----------|--------|
| Commission Amount | $100.00 |
| + Stripe Processing (2.9% + $0.30) | $3.20 |
| **Writer Pays** | **$103.20** |

| Distribution | Amount |
|--------------|--------|
| Commission Amount | $100.00 |
| - Platform Fee (10%) | -$10.00 |
| **Performer Receives** | **$90.00** |
