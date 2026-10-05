# Billetto Events

An event-discovery board. It mirrors public events from Billetto's API, lists
them, and lets signed-in people like or dislike each one — with every vote
recorded as an immutable fact in an event stream rather than a counter that
gets overwritten.

## Setup

Requires PostgreSQL and Redis running locally.

```bash
bundle install
bin/rails db:prepare
```

That's enough to boot. **The app runs with no credentials at all** — both
external integrations fall back to fixture-backed fakes, so the suite runs
without a key or a network connection.

```bash
bin/rails server          # http://localhost:3000
bundle exec sidekiq       # needed for vote counts to update
```

Import events (the captured fixture without a key, the live API with one):

```bash
bin/rails catalog:import            # all public events
bin/rails catalog:import LIMIT=25   # cap the run
```

### Credentials

Either environment variables, which take precedence:

```bash
export BILLETTO_API_KEYPAIR="key:secret"
export CLERK_PUBLISHABLE_KEY="pk_test_..."
export CLERK_SECRET_KEY="sk_test_..."
export CLERK_FRONTEND_API="https://<your-instance>.clerk.accounts.dev"
```

Or Rails credentials (`bin/rails credentials:edit`), under `billetto:` and
`clerk:` with the same keys in snake_case.

> Billetto's keypair is a single header — `Api-Keypair: KEY:SECRET` — issued
> from an **Organiser** account. `list-public-events` belongs to their
> partner-gated Public Event API, so a fresh account may not have access.

### Rails Event Store setup

Already done in this repo; recorded here because reproducing it from scratch is
four steps and none of them are guessable.

**1. The gem** — `gem "rails_event_store", "~> 2.17"`.

**2. The tables.** `--data-type=jsonb` matters: it keeps payloads queryable in
SQL instead of storing them as an opaque serialised blob.

```bash
bin/rails generate rails_event_store_active_record:migration --data-type=jsonb
bin/rails db:migrate
```

**3. The client** — `config/initializers/rails_event_store.rb`, delegating to
`ApplicationEventStore.build`, which pairs `RailsEventStore::JSONClient` (to
match the jsonb columns) with a broker whose dispatcher composes
`AfterCommitDispatcher` and `SyncScheduler`. Two details are easy to get wrong
and silently damaging:

- **`AfterCommitDispatcher`.** Scheduling a job inside the transaction lets a
  worker pick it up before — or despite — the commit, and react to something
  that never happened.
- **`serializer: JSON` on both sides.** The scheduler and the handlers must
  agree, or jobs serialise one way and deserialise another.

**4. Subscriptions.** Handlers are registered in one place,
`lib/application_subscriptions.rb`, so "what reacts to this fact?" is a file to
read rather than a grep for `subscribe` calls.

### Testing

```bash
bundle exec rspec
bundle exec rubocop
```

System specs run on `rack_test` by default. `spec/system/voting_js_spec.rb`
runs the same journey in real headless Chrome; Selenium Manager fetches a
matching driver, so there is nothing to install.

Specs tagged `:external` reach a real third-party service and are **excluded by
default**, so the suite stays runnable offline:

```bash
bundle exec rspec --tag external   # drives the live Clerk components
```

## How it fits together

```
Billetto API ──(job)──▶ events ──▶ listing page
                                        ▲
Clerk ──(session JWT)──▶ user id        │
                            │           │
                            ▼           │
                      command bus ──▶ Event Store (append-only facts)
                                              │
                                      (async subscriber)
                                              ▼
                                     event_vote_tallies ──────┘
```

```
app/domain/          catalog, voting, read models — the application's own logic
app/integrations/    anti-corruption layers for Billetto and Clerk
lib/command/         the command bus and its middleware chain
lib/fact.rb          base class for domain events
```

Events belong to Billetto and people belong to Clerk. **The votes are the only
thing this application genuinely owns** — which is why they are the part built
as an event stream.

## Design choices

### Commands are the only way in

Controllers, jobs and event handlers build a command and hand it to the bus;
nothing calls a domain method directly. The bus is a chain —
`Instrumentation → Correlation → Transaction → dispatch` — and that single
entry point is what lets three guarantees be stated once instead of per caller:

- **Transaction.** A command usually writes state *and* publishes a fact about
  it. If those commit separately, a crash in between leaves the log disagreeing
  with the records — and the log is what read models are rebuilt from.
- **Correlation.** Every fact published during a command is tagged, and a
  command dispatched from inside a handler reuses the ambient id, so a chain of
  consequences stays traceable to the action that started it.
- **Instrumentation.** Timing and failures without each handler logging.

### Stream design

Each vote fact is written **once** and linked into three streams:

| Stream | Answers |
|---|---|
| `Event$<tid>` | everything that happened to this event |
| `User$<id>` | everything this person did |
| `Voting$votes` | one stream to replay when rebuilding every tally |

Linking stores a pointer, not a copy, so all three read the same row and cannot
drift apart. Without `Voting$votes` a full rebuild would have to walk every
event stream individually.

### Votes are appends, never edits

Changing your mind appends `VoteWithdrawn` and then the new vote. Clicking like
twice un-likes — also an append. What you previously thought stays readable.

`VoteWithdrawn` carries the direction it undid. That one field keeps every
downstream read model a plain increment or decrement: a tally is *told* what is
being reversed instead of re-reading the stream to work it out.

### The tally is derived

The listing page reads a counter table, never the event log — there's a spec
asserting it never touches `event_store_events`. Counting by replaying a stream
per event would be one query per row on every page view, getting slower with
every vote cast.

Nothing in that table is authoritative; `bin/rails voting:rebuild_tallies`
replays the stream and rebuilds it. That is the payoff for deriving rather than
storing — a new read model over the same facts costs a replay, not a migration
and a backfill.

Handlers run on a queue, so the count trails the vote; a vote should not wait
for its own bookkeeping. Two specs pin that down in both directions — the tally
is **not** updated inside the request that voted, and it catches up once the
queue drains.

### Idempotency

- **Ingestion** is idempotent on Billetto's external id. Each event carries a
  SHA-256 digest of its descriptive attributes, so a re-import compares one
  column instead of fourteen and writes nothing when nothing changed.
- **Handlers** are delivered at least once, and a counter incremented twice is
  silently wrong forever. `Handler::Idempotency` claims each fact in the same
  transaction as the work, so a duplicate loses a unique-index race and does
  nothing.

Rebuilding has to clear those claims first, or idempotency correctly refuses
the replay and leaves an empty table. There's a spec for that interaction.

### Anti-corruption layers

Billetto nests `organiser`, `location` and `minimum_price`, and spells dates
`startdate`/`enddate`. None of that reaches the domain: `EventPayload` maps it
into our own flat vocabulary, and the import command takes already-mapped
attributes, so it knows nothing about Billetto at all. Errors are wrapped too —
callers rescue `Billetto::Error`, never `Net::HTTP` or `JSON` exceptions.

Both integrations ship a **fake**, used by the test environment and a
credential-less dev machine in preference to stubbing HTTP, so tests point at a
seam this codebase owns.

### Authentication

The application learns nothing about a person beyond an opaque Clerk user id —
no users table, no mirrored email, no password.

Clerk's official Ruby SDK does the work, through its Rack middleware, with
Clerk's own JavaScript components for sign-up, sign-in and sign-out. Using the
vendor's SDK beats a hand-rolled verifier here: token format, key rotation and
session refresh are their problem to keep correct, and they change them without
asking.

Identifying a visitor costs no network call — `clerk.user_id` reads the subject
off claims the middleware has already verified. `clerk.user` is the call that
would reach Clerk's API, and nothing here needs it. A session Clerk refuses
means "not signed in", never an error: a stale cookie in a reopened tab should
not break the page.

The middleware is mounted explicitly in `config/application.rb` rather than by
the gem's Railtie, because the test environment swaps in `ClerkTestMiddleware`.
That stand-in builds the same `Clerk::Proxy` from a cookie whose value is just
a user id, so controllers, the `clerk` helper and every guard run the same code
they run in production — without a secret key in CI or a network call per
example.

## Assumptions

- **Re-voting semantics.** Same direction withdraws; opposite direction
  withdraws then re-casts. The brief didn't specify; this keeps the read model
  a simple increment.
- **One vote per person per event**, backed by a unique index.
- **Only upcoming events are listed**, ordered by start date, capped at 50. The
  brief asked for "a simple page", not a browsing experience.
- **Typeids (`evt_...`) rather than primary keys in stream names.** A database
  id changes when data is moved or reseeded; a stream name in an append-only
  log is permanent, so it needs an identifier with the same lifetime.
- **Clerk's hosted screens are out of scope for automated tests.**
  `DevSessionsController` plus `ClerkTestMiddleware` are the seam for testing
  what *is* ours — everything downstream of the session. Those routes exist in
  the test environment only.

## Deliberately not done

Timeboxed, as the brief suggested. In rough priority order:

- **Pagination on the listing.** Capped at 50 instead.
- **Live-updating counts.** Turbo Streams broadcast from the read-model handler
  would close the loop.
- **A scheduled import.** The rake task and job exist; nothing calls them on a
  timer.
- **Sidekiq retry/DLQ policy** beyond the defaults, and no dashboard mounted.
- **Rate limiting** against Billetto.
- **Snapshotting.** Not needed at this volume, but a stream that grew for years
  would want it.

## Known issues

- `json` is pinned to `~> 2.7`. Rails 7.2 still calls
  `JSON.generate(..., quirks_mode: true)`, which `json` 3.x removed; on json 3
  every request that writes a session cookie raises `ArgumentError`. The
  request specs did not catch this — they never exercised the cookie
  middleware — so the suite was green while the app was unusable.
- The `debug` gem is not in the Gemfile. It pulls `irb → reline → io-console`,
  whose current release would not build on the machine this was written on.
