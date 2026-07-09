# Stay Ahead

[![codecov](https://codecov.io/github/cesarecamurani/stay-ahead/graph/badge.svg?token=MZTH4LNN88)](https://codecov.io/github/cesarecamurani/stay-ahead)

Stay Ahead is a fintech-inspired application for tracking financial commitments and understanding future financial obligations. It models recurring and one-time payments, manages their lifecycles over time, and projects when those obligations will occur.

The current version is deliberately scoped to backend foundations: commitment modelling, lifecycle management, background automation, and forecast generation exposed through a JSON API. A React frontend is planned but not yet present in this repository.

Longer term, Stay Ahead is intended to grow into a fuller financial planning product — balance projections, affordability analysis, recommendations, and alerts — built on top of the commitment and forecasting data model described here. Those capabilities are not implemented yet.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Features](#2-features)
3. [Commitment Lifecycle](#3-commitment-lifecycle)
4. [Background Processing](#4-background-processing)
5. [Forecasting Engine](#5-forecasting-engine)
6. [API](#6-api)
7. [Architecture](#7-architecture)
8. [Domain Model](#8-domain-model)
9. [Testing](#9-testing)
10. [Running Locally](#10-running-locally)
11. [Roadmap](#11-roadmap)

---

## 1. Project Overview

### What it is

Stay Ahead helps users answer a practical question: *given the financial commitments I have today, what payments am I expected to make over a given period?*

It treats commitments — rent, loans, subscriptions, pension contributions — as first-class domain objects with categories, recurrence rules, amounts, and explicit lifecycle states. Background jobs keep those states accurate as dates pass, and a forecasting engine projects future payment occurrences without coupling that logic to HTTP controllers.

### What problem it solves

Most personal finance tools either track historical spending or require manual calendar maintenance. Stay Ahead focuses on **forward-looking obligations**: modelling what you have committed to pay, when those commitments are active, and generating a chronological forecast of expected payments over any date range.

### Current scope

The application today provides:

- User registration and JWT-based authentication
- CRUD and lifecycle management for financial commitments
- Automated lifecycle transitions via background jobs
- A forecasting engine that generates future commitment occurrences
- API endpoints for forecasts, commitments, and current financial snapshots

### Long-term vision

Future iterations will add financial intelligence on top of the existing data:

- Running balance projections over time
- Affordability evaluation against income and savings
- Recommendations and alerts

The forecasting layer produces raw future events today. Higher-level analysis will consume that output rather than replacing it.

---

## 2. Features

### User Management

- **Registration and login** — Users sign up via `POST /api/v1/users` and authenticate with `POST /api/v1/login`. Successful authentication returns a JWT.
- **Profile management** — Authenticated users can read and update their profile (`GET/PATCH /api/v1/me`), including `monthly_income`, `savings`, and `currency`.
- **User ownership** — Every commitment belongs to a single user. API queries are always scoped to `current_user`; cross-user access returns `404`.
- **API-first architecture** — The backend is a Rails API (`ActionController::API`). There is no frontend in this repository yet.

### Commitment Management

A **commitment** represents a financial obligation: something the user has committed to pay.

#### Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| `obligation` | Essential fixed costs | Rent, mortgage, utilities |
| `debt` | Repayment flows | Loans, installments, credit repayments |
| `service` | Ongoing services | Subscriptions, insurance |
| `investment` | Savings and investing flows | Pension, funds, regular investing |

#### Recurrence types

| Recurrence | Behaviour |
|------------|-----------|
| `one_time` | A single payment on a fixed date |
| `weekly` | Repeats every week from the start date |
| `monthly` | Repeats every month from the start date |
| `quarterly` | Repeats every three months from the start date |
| `yearly` | Repeats every year from the start date |

#### One-time vs recurring

**One-time commitments** represent a single financial event. They use `due_date` (not `start_date`) and do not participate in the `activate!` transition — they move from `scheduled` to `completed` when their due date is reached.

**Recurring commitments** use `start_date` as the recurrence anchor. Each occurrence is advanced from that anchor using the recurrence rule. An optional `end_date` (set explicitly or derived from `duration_months`) defines when the lifecycle ends. Recurring commitments with a future `start_date` begin in `scheduled` status and are activated automatically when the start date arrives.

#### Lifecycle actions via API

Lifecycle transitions are exposed as dedicated endpoints rather than arbitrary status updates:

- `POST /api/v1/commitments/:id/pause`
- `POST /api/v1/commitments/:id/resume`
- `POST /api/v1/commitments/:id/cancel`

`activate!` and `complete!` are invoked by background jobs, not directly through the API. Status cannot be set via create/update parameters.

### Financial Snapshots

In addition to forward-looking forecasts, the API exposes **current-state** financial calculations for active commitments only:

- **`GET /api/v1/summary`** — Monthly income, savings, total monthly commitment cost (normalised across recurrence types), available cash flow, and savings runway in months.
- **`GET /api/v1/breakdown`** — Monthly commitment totals grouped by category.

These endpoints use the `Calculator::MonthlyAmount` service to normalise weekly, monthly, quarterly, and yearly amounts to a monthly equivalent. They reflect the present snapshot of active commitments; they do not project balances over time.

---

## 3. Commitment Lifecycle

Commitments follow an explicit state machine. Status is an enum with five values:

| Status | Meaning |
|--------|---------|
| `scheduled` | Created but not yet active (future start date, or one-time payment not yet due) |
| `active` | Currently in effect; included in forecasts and financial snapshots |
| `paused` | Temporarily suspended; excluded from forecasts and snapshots |
| `completed` | Lifecycle finished naturally |
| `cancelled` | Terminated by the user |

### Supported transitions

```
scheduled  → active      (via activate! — background job)
scheduled  → cancelled   (via cancel!)
active     → paused      (via pause!)
active     → completed   (via complete! — background job)
active     → cancelled   (via cancel!)
paused     → active      (via resume!)
paused     → cancelled   (via cancel!)
```

All other transitions are rejected with validation errors.

### Domain methods

Transitions are controlled through domain methods on `Commitment`, not by assigning `status` directly:

| Method | From | To | Notes |
|--------|------|----|-------|
| `activate!` | `scheduled` | `active` | Recurring only; requires `start_date` on or before today |
| `pause!` | `active` | `paused` | |
| `resume!` | `paused` | `active` | |
| `complete!` | `scheduled` (one-time) or `active` (recurring) | `completed` | Requires due/end date on or before today |
| `cancel!` | `scheduled`, `active`, `paused` | `cancelled` | |

Validation and transition rules live in the model. Controllers and jobs delegate to these methods and surface errors when a transition is not permitted.

### Initial status on creation

When a commitment is created, `set_initial_status` assigns the starting state based on dates:

- **Recurring** with `start_date` in the past or today → `active`
- **Recurring** with a future `start_date` → `scheduled`
- **One-time** with `due_date` in the past or today → `completed`
- **One-time** with a future `due_date` → `scheduled`

---

## 4. Background Processing

Stay Ahead uses **Rails ActiveJob** with **Solid Queue** as the queue adapter. Lifecycle automation runs asynchronously so HTTP requests stay fast and date-driven transitions happen reliably on a schedule.

### ActivateScheduledCommitmentsJob

Finds recurring commitments in `scheduled` status whose `start_date` is on or before today (`Commitment.ready_to_activate`) and calls `activate!` on each.

### CompleteCommitmentsJob

Completes commitments whose lifecycle has ended (`Commitment.ready_to_complete`):

- **One-time** — `scheduled` commitments with `due_date` on or before today
- **Recurring** — `active` commitments with an `end_date` on or before today

### Scheduling and resilience

Recurring tasks are defined in `config/recurring.yml` and executed by Solid Queue:

| Environment | Activate job | Complete job |
|-------------|--------------|--------------|
| Production | Daily at 00:05 | Daily at 00:10 |
| Development | Every 5 minutes | Every 5 minutes |

Both jobs:

- Retry on `StandardError` with polynomial backoff (up to 3 attempts)
- Log transition failures via `ApplicationJob#log_transition_failure` without raising — a single invalid record does not abort the batch
- Delegate all business rules to the `Commitment` model

To run the job worker locally, start Solid Queue in a separate process:

```bash
bin/jobs
```

Alternatively, set `SOLID_QUEUE_IN_PUMA=true` to run the Solid Queue supervisor inside Puma for single-process deployments.

---

## 5. Forecasting Engine

The forecasting layer is isolated in `ForecastGenerator`, a plain Ruby service object. Controllers call it; they do not contain recurrence or date-range logic.

### Flow

```
Commitments (scheduled + active)
        ↓
ForecastGenerator
        ↓
Forecast occurrences (in-memory structs)
        ↓
ForecastSerializer → API response
```

### Behaviour

- **One-time commitments** — A single occurrence on `due_date`, if that date falls within the requested range.
- **Recurring commitments** — Occurrences generated from `start_date` using the recurrence rule, up to the lesser of the request `to` date and the commitment `end_date`.
- **Status filtering** — Only `scheduled` and `active` commitments are included. Paused, completed, and cancelled commitments are excluded.
- **Date range** — The `from` and `to` parameters bound the output. Occurrences before `from` are skipped efficiently by advancing the recurrence cursor.
- **Ordering** — Results are sorted chronologically by date, then by `commitment_id`.

### What is not implemented

The forecasting engine produces **raw future payment events**. It does not:

- Calculate running account balances
- Evaluate affordability against income
- Generate recommendations
- Emit financial alerts or insights

Those features will build on this foundation in future iterations, consuming forecast occurrences as input rather than duplicating recurrence logic.

---

## 6. API

All endpoints are under `/api/v1`. Authenticated requests require a Bearer token:

```
Authorization: Bearer <jwt>
```

### Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/users` | No | Register a new user |
| `POST` | `/api/v1/login` | No | Authenticate and receive a JWT |
| `DELETE` | `/api/v1/logout` | No | Log out (stateless; client discards token) |
| `GET` | `/api/v1/me` | Yes | Current user profile |
| `PATCH` | `/api/v1/me` | Yes | Update profile fields |

### Commitments

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/commitments` | List current user's commitments |
| `POST` | `/api/v1/commitments` | Create a commitment |
| `GET` | `/api/v1/commitments/:id` | Show a commitment |
| `PATCH` | `/api/v1/commitments/:id` | Update a commitment |
| `POST` | `/api/v1/commitments/:id/pause` | Pause an active commitment |
| `POST` | `/api/v1/commitments/:id/resume` | Resume a paused commitment |
| `POST` | `/api/v1/commitments/:id/cancel` | Cancel a commitment |

Create and update accept `due_date` for one-time commitments (`recurrence: "one_time"`). Recurring commitments use `start_date` and must not include `due_date`.

**One-time example:**

```json
POST /api/v1/commitments
{
  "commitment": {
    "name": "Insurance premium",
    "category": "obligation",
    "recurrence": "one_time",
    "amount": 120.00,
    "due_date": "2026-06-15"
  }
}
```

### Financial snapshots

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/summary` | Monthly income, savings, commitments total, cash flow, runway |
| `GET` | `/api/v1/breakdown` | Active commitment totals by category |

### Forecast endpoint

**`GET /api/v1/forecasts`**

Returns projected commitment occurrences for the authenticated user within a date range.

#### Parameters

| Parameter | Required | Format | Description |
|-----------|----------|--------|-------------|
| `from` | Yes | ISO 8601 date (`YYYY-MM-DD`) | Start of forecast range (inclusive) |
| `to` | Yes | ISO 8601 date (`YYYY-MM-DD`) | End of forecast range (inclusive) |

#### Example request

```
GET /api/v1/forecasts?from=2026-01-01&to=2026-12-31
Authorization: Bearer <token>
```

#### Example response

```json
{
  "forecasts": [
    {
      "commitment_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "name": "Netflix",
      "category": "service",
      "date": "2026-01-15",
      "amount": "15.00"
    }
  ]
}
```

Missing or invalid date parameters return `400 Bad Request`. Unauthenticated requests return `401 Unauthorized`.

The forecast API exposes projected payment events only. It does not perform balance calculations, affordability checks, or recommendations.

---

## 7. Architecture

### Stack

| Layer | Technology |
|-------|------------|
| Framework | Ruby on Rails 8 (API mode) |
| Language | Ruby 3.3.5 |
| Database | PostgreSQL |
| Background jobs | ActiveJob + Solid Queue |
| Authentication | JWT (`jwt` gem) + `bcrypt` password hashing |
| Money handling | `money` gem (currency validation) |
| Testing | RSpec, Factory Bot, Shoulda Matchers, SimpleCov |
| Frontend | React (planned — not in this repository) |

### Design principles

- **Thin controllers** — HTTP concerns only: authentication, parameter parsing, rendering.
- **Service objects for business operations** — `ForecastGenerator`, `Calculator::Summary`, `Calculator::Breakdown`, and `Calculator::MonthlyAmount` encapsulate logic that does not belong in models or controllers.
- **Model-driven lifecycle transitions** — State machine rules and validations live on `Commitment`. Jobs and controllers call domain methods; they do not mutate `status` directly.
- **Asynchronous processing** — Date-driven transitions (`activate!`, `complete!`) run in background jobs on a schedule.
- **API-first design** — Serializers (`BaseSerializer` and subclasses) define the JSON contract. The backend is ready for a separate frontend client.

### Responsibility separation

| Layer | Responsibility |
|-------|----------------|
| Controllers | HTTP routing, auth, request/response formatting |
| Services | Forecasting, financial calculations |
| Models | Domain rules, validations, lifecycle transitions |
| Jobs | Scheduled, asynchronous execution of domain methods |
| Serializers | JSON shape for API responses |

---

## 8. Domain Model

### User

A user owns financial commitments and holds optional profile fields (`monthly_income`, `savings`, `currency`) used by financial snapshot endpoints. Authentication uses `has_secure_password` with a bcrypt digest.

### Commitment

The central domain entity. A commitment represents a financial obligation with:

| Concept | Business meaning |
|---------|------------------|
| `category` | What kind of obligation (obligation, debt, service, investment) |
| `recurrence` | How often the payment occurs (one_time through yearly) |
| `status` | Where the commitment is in its lifecycle |
| `amount` | Payment amount per occurrence |
| `start_date` | Recurrence anchor for recurring commitments |
| `due_date` | Payment date for one-time commitments |
| `end_date` | When a recurring commitment's lifecycle ends |
| `duration_months` | Optional; used to derive `end_date` from `start_date` on creation |
| `interest_rate` | Optional metadata for debt-related commitments |

Commitments use UUID primary keys. Records are always accessed through their owning user to enforce data isolation.

---

## 9. Testing

The test suite uses **RSpec** with **Factory Bot** for fixture data.

### Spec types

| Type | Location | Covers |
|------|----------|--------|
| Model specs | `spec/models/` | Validations, lifecycle transitions, scopes |
| Service specs | `spec/services/` | Forecasting rules, monthly amount normalisation, summary/breakdown calculations |
| Request specs | `spec/requests/` | API authentication, commitments CRUD, forecasts, summary, breakdown |
| Job specs | `spec/jobs/` | Background job integration with domain methods |
| Serializer specs | `spec/serializers/` | JSON output shape |

### Smoke test

`script/lifecycle_smoke_test.rb` is an end-to-end integration script that exercises the running API: commitment creation, lifecycle transitions, financial calculations, forecast responses, validation, and authorisation. Run it against a live server:

```bash
JWT_SECRET=your_secret bin/rails server -p 9000   # terminal 1
JWT_SECRET=your_secret ruby script/lifecycle_smoke_test.rb   # terminal 2
```

Configure the target with `SMOKE_TEST_BASE_URL` (default `http://localhost:9000/api/v1`) and `SMOKE_TEST_USER_ID` if needed.

### CI

GitHub Actions runs Brakeman security scanning, RuboCop linting, and the full RSpec suite against PostgreSQL on every push and pull request to `main`.

---

## 10. Running Locally

### Prerequisites

- Ruby 3.3.5 (see `.ruby-version`)
- PostgreSQL
- Bundler

### Setup

```bash
git clone <repository-url>
cd stay-ahead
bundle install
```

Set the JWT signing secret (required for authentication):

```bash
export JWT_SECRET=your_development_secret
```

Prepare the database:

```bash
bin/rails db:prepare
```

Or use the setup script, which installs dependencies, prepares the database, and starts the server:

```bash
bin/setup
```

Pass `--skip-server` to prepare without starting the server.

### Running the application

Start the Rails server (default port 3000):

```bash
bin/rails server
```

Start the Solid Queue worker in a separate terminal to process background jobs:

```bash
bin/jobs
```

### Running tests

```bash
bundle exec rspec
```

Coverage reports are generated via SimpleCov in the `coverage/` directory.

---

## 11. Roadmap

### Completed

- Backend foundation (Rails 8 API, PostgreSQL, JWT auth)
- Commitment domain model with categories and recurrence types
- Commitment lifecycle state machine
- Background processing with Solid Queue (activate and complete jobs)
- Forecast generation (`ForecastGenerator`)
- Forecast API (`GET /api/v1/forecasts`)
- Financial snapshot endpoints (summary and breakdown)

### Next

- React frontend
- Dashboard UI
- Commitment management UI
- Forecast visualisation

### Future

- Balance projections over time
- Affordability analysis
- Financial recommendations
- Alerts and insights

---

## License

This project is a portfolio application. Refer to the repository for licensing details.
