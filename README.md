# Billetto Events

Mirrors public events from Billetto's API, lists them, and lets signed-in users
like or dislike each one. Votes are stored as events in an append-only log
rather than as counters.

## Setup

Requires PostgreSQL and Redis.

```bash
bundle install
bin/rails db:prepare
bin/dev
```

`bin/dev` runs the web server and the Sidekiq worker together. The worker
matters: vote counts are updated by a background handler, so without it a vote
is recorded but the count never moves.

The app runs without credentials. Both integrations fall back to
fixture-backed fakes, so the suite passes offline.

Import events:

```bash
bin/rails catalog:import            # all public events
bin/rails catalog:import LIMIT=25
```

### Credentials

Environment variables take precedence over Rails credentials:

```bash
export BILLETTO_API_KEYPAIR="key:secret"
export CLERK_PUBLISHABLE_KEY="pk_test_..."
export CLERK_SECRET_KEY="sk_test_..."
export CLERK_FRONTEND_API="https://<instance>.clerk.accounts.dev"
```

Billetto's keypair is sent as a single `Api-Keypair: KEY:SECRET` header and is
issued from an Organiser account. `list-public-events` belongs to their
partner-gated Public Event API.

### Testing

```bash
bundle exec rspec
bundle exec rubocop
```

System specs use `rack_test` by default. `spec/system/voting_js_spec.rb` runs
the same flow in headless Chrome. Specs tagged `:external` call live services
and are excluded by default:

```bash
bundle exec rspec --tag external
```

## Rails Event Store setup

```ruby
gem "rails_event_store", "~> 2.17"
```

```bash
bin/rails generate rails_event_store_active_record:migration --data-type=jsonb
bin/rails db:migrate
```

`--data-type=jsonb` keeps payloads queryable in SQL instead of storing them as
a serialised blob.

The client is built in `ApplicationEventStore.build` and assigned in
`config/initializers/rails_event_store.rb`. It pairs `JSONClient` with a
dispatcher composed of `AfterCommitDispatcher` and `SyncScheduler`. Two things
to get right:

- `AfterCommitDispatcher` stops a worker picking up a job before the
  transaction commits.
- `serializer: JSON` has to match on the scheduler and the handlers.

Subscriptions are registered in `lib/application_subscriptions.rb`.

## Structure

```
app/domain/          catalog, voting, read models
app/integrations/    Billetto and Clerk adapters
lib/command/         command bus and middleware
lib/fact.rb          base class for domain events
```

Events come from Billetto and users come from Clerk. Votes are the only data
this application owns, which is why they are the part stored as events.

## Design notes

**Commands.** Controllers, jobs and handlers build a command and pass it to the
bus. The bus wraps each one in a transaction, tags published facts with a
correlation id, and instruments timing. Writing state and publishing a fact in
the same transaction keeps the log consistent with the records.

**Streams.** Each vote fact is written once and linked into three streams:
`Event$<tid>`, `User$<id>` and `Voting$votes`. Linking stores a pointer, so all
three read the same row.

**Appends only.** Changing a vote appends `VoteWithdrawn` followed by the new
vote. `VoteWithdrawn` carries the direction it undid, so read models apply a
plain increment or decrement without re-reading the stream.

**Derived tallies.** The listing page reads `event_vote_tallies`, never the
event log. The table can be dropped and rebuilt:

```bash
bin/rails voting:rebuild_tallies
```

Handlers run on a queue, so counts are eventually consistent. Two specs cover
both sides: the tally is not updated in the request that voted, and it catches
up once the queue drains.

**Idempotency.** Imports compare a SHA-256 digest of the descriptive attributes
and write nothing when unchanged. Handlers claim each fact in the same
transaction as the work, so a duplicate delivery loses a unique-index race.

**Adapters.** `EventPayload` maps Billetto's nested payload into flat
attributes, so the domain never sees their vocabulary. Errors are wrapped as
`Billetto::Error`. Both integrations ship a fake, used in tests and when no
credentials are configured.

**Authentication.** Clerk's Ruby SDK handles sessions through its Rack
middleware, with Clerk's own components for sign-up and sign-in. The app stores
only an opaque user id. `clerk.user_id` reads an already-verified claim, so
identifying a request costs no network call. The middleware is mounted in
`config/application.rb` rather than by the gem's Railtie, so the test
environment can substitute `ClerkTestMiddleware`.

## Assumptions

- Voting the same direction twice withdraws the vote. Voting the opposite
  direction withdraws and re-casts.
- One vote per person per event, backed by a unique index.
- Only upcoming events are listed, ordered by start date, capped at 50.
- Stream names use typeids (`evt_...`) rather than primary keys, since a stream
  name in an append-only log has to outlive a reseed.
- Clerk's hosted screens are not covered by automated tests.
  `DevSessionsController` and `ClerkTestMiddleware` cover everything downstream
  of the session, and those routes exist only in the test environment.

## Not done

- Pagination on the listing.
- Live-updating counts (Turbo Streams from the read-model handler).
- A scheduled import. The rake task exists; nothing triggers it on a timer.
- Sidekiq retry and DLQ policy beyond the defaults.
- Rate limiting against Billetto.

## Notes

- `json` is pinned to `~> 2.7`. Rails 7.2 calls
  `JSON.generate(..., quirks_mode: true)`, which json 3 removed.
- The `debug` gem is not in the Gemfile; `io-console` would not build locally.
