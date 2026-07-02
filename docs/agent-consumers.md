# Agent Consumer Contract

Growth Push Router stops at the local agent outbox. Local programs consume that
outbox and decide what to do with each event.

Twenty, Chatwoot, n8n jobs, and customer-specific scripts are consumers. They
are not Phoenix router modules, and the router core should not contain CRM,
inbox, or customer workflow code.

## Data Flow

```text
Provider webhook
  -> edge router
  -> client agent
  -> local database event outbox
  -> external consumers
```

The agent writes consumer-visible records to the `events` table with
`stored_by = "agent"`. Consumers poll only those records.

## Where Consumers Live

Consumers may live in this repository when they are part of the local
Growth Push deployment. Keep them outside the Phoenix router core:

```text
growthpush-router/
  lib/growthpush_router/        # router and agent domain core
  lib/growthpush_router_web/    # Phoenix web layer
  docs/
  consumers/
    consumer_twenty/
      README.md
      ...
    consumer_chatwoot/
      README.md
      ...
```

Consumers may also live outside this repository in a different deployable
project.

Both options are valid:

* same repo, separate folder: useful when the consumer is shipped with this
  self-hosted stack;
* separate repo: useful when the consumer has its own release cycle, owner, or
  language/runtime.

The boundary is architectural, not only about git. A consumer can be in this
repo, but it should still be outside `lib/growthpush_router` and
`lib/growthpush_router_web`.

## How Consumers Read

Elixir consumers that run inside the same application runtime can use the domain
API:

```elixir
GrowthPushRouter.Agents.list_agent_events_after(agent, last_sequence, limit: 100)
```

Consumers written in another language should use the same SQL contract directly
against the local database:

```sql
select *
from events
where stored_by = 'agent'
  and sequence > $1
order by sequence asc
limit $2;
```

For example, `consumers/consumer_twenty` could be an Elixir worker, a Python
script, a Node service, or a small Go binary. The language does not matter as
long as it reads only agent-side outbox records, processes them in sequence
order, and stores its own cursor.

## Cursor Contract

Each consumer owns its own cursor.

A consumer stores the highest event `sequence` that it has durably processed.
On the next poll it asks for events where:

```sql
stored_by = 'agent'
and sequence > last_sequence
order by sequence asc
limit consumer_batch_size
```

In Elixir, the router domain API for this query is:

```elixir
GrowthPushRouter.Agents.list_agent_events_after(agent, last_sequence, limit: 100)
```

The sequence is a database-assigned, increasing integer. Consumers should treat
it as an opaque cursor, not as a timestamp or per-connection counter.

Consumer cursor rules:

1. Start with `last_sequence = 0` for a new consumer.
2. Read the next batch ordered by `sequence`.
3. Process events in sequence order.
4. Advance the consumer's stored cursor only after downstream work is durable.
5. Re-poll with the new `last_sequence`.

If downstream processing fails, leave the cursor unchanged or advance it only up
to the last successfully processed event. This makes retries explicit and keeps
the router from needing consumer-specific status fields.

## Event Payload Contract

Consumers receive event records with these fields:

| Field | Meaning |
| --- | --- |
| `id` | Router event UUID. Useful for logs and idempotency keys. |
| `sequence` | Monotonic outbox cursor used for polling. |
| `connection_id` | Local connection that produced the event. |
| `provider` | External provider, for example `meta`. |
| `channel` | Channel, for example `instagram` or `whatsapp`. |
| `event_type` | Normalized event type, for example `message_received`. |
| `external_event_id` | Provider event id when available. May be null. |
| `payload` | Provider/router payload map. Consumers own interpretation. |
| `received_at` | Time the router recorded for receipt. |
| `inserted_at` | Time the row was inserted locally. |
| `stored_by` | Always `agent` for consumer-visible outbox records. |
| `status` | Router-side event status. Consumers should not use it as their cursor. |

The `payload` field is intentionally provider-shaped. For Meta Instagram events,
for example, it may include an `entry` array from the inbound webhook. The router
does not promise a CRM-ready schema. Each consumer maps the provider/router
payload into its own target system.

Consumers should use idempotency when writing downstream:

* prefer `external_event_id` when the provider supplies it;
* otherwise use the router `id`;
* include the consumer name when the target system needs separate idempotency
  keys for Twenty, Chatwoot, or another integration.

## Conceptual Twenty Consumer

`consumer_twenty` can be a separate local process, cron job, worker service, or
script. It can live under `consumers/consumer_twenty` in this repo or in a
separate project.

Conceptual loop:

```text
consumer_name = "consumer_twenty"
last_sequence = load_cursor(consumer_name)

events = query_agent_events(sequence > last_sequence, stored_by = "agent")

for event in events ordered by sequence:
  normalized = map_provider_payload_to_twenty(event.payload)
  upsert_lead_or_activity_in_twenty(normalized, idempotency_key: event.id)
  save_cursor(consumer_name, event.sequence)
```

That adapter owns:

* how to connect to Twenty;
* how to map Instagram/WhatsApp payloads into leads, people, companies, notes,
  tasks, or activities;
* where to store `consumer_twenty`'s cursor;
* retry and dead-letter behavior;
* target-system idempotency.

The router owns only the durable local event record and the ordered polling
contract.

## Multiple Consumers

Consumers are independent. A Twenty adapter and a Chatwoot adapter should keep
separate cursors:

```text
consumer_twenty.cursor = 384
consumer_chatwoot.cursor = 371
```

One blocked consumer must not stop another consumer from advancing. If a shared
orchestrator is used, it should still persist a separate cursor per downstream
adapter.

## What Belongs Outside The Router Core

Do not add these to Growth Push Router core:

* Twenty lead, person, company, or activity mapping code.
* Chatwoot conversation/message forwarding code.
* Consumer-specific retry queues, cursor tables, or deployment units.
* Customer-specific enrichment, scoring, routing, or notification logic.

Those belong in consumers that read the local agent outbox through the sequence
cursor contract above. They may be in `consumers/` in this repo, or in another
repository and another language.
