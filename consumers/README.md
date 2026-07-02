# Consumers

This directory contains local outbox consumers that can ship with the
Growth Push self-hosted stack.

Consumers are outside the Phoenix router core. They may be scripts, workers, or
small services, but they should not add CRM, inbox, or customer workflow logic to
`lib/growthpush_router` or `lib/growthpush_router_web`.

The detailed contract lives in [`../docs/agent-consumers.md`](../docs/agent-consumers.md).

## Outbox Contract

The router core ends at the local agent outbox. Consumers read agent-side event
records from the local database and decide what to do with each event.

Consumers must:

* read only records where `stored_by = "agent"`;
* process records in ascending `sequence` order;
* store their own durable cursor;
* advance that cursor only after downstream work is durable;
* keep separate cursors per adapter, for example `consumer_twenty` and
  `consumer_chatwoot`.

SQL consumers should use the same polling shape:

```sql
select *
from events
where stored_by = 'agent'
  and sequence > $1
order by sequence asc
limit $2;
```

Elixir consumers that run inside the same application runtime can use:

```elixir
GrowthPushRouter.Agents.list_agent_events_after(agent, last_sequence, limit: 100)
```

## Common Environment Placeholders

These names are placeholders for future consumers. Do not commit real tokens or
customer-specific values here.

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Local router database that contains the agent outbox. |
| `CONSUMER_NAME` | Stable adapter name used in logs, cursors, and idempotency keys. |
| `CONSUMER_BATCH_SIZE` | Maximum events to read per poll. |
| `CONSUMER_CURSOR_PATH` | Local file or storage reference for the adapter cursor. |
| `LOG_LEVEL` | Runtime logging level. |
| `DRY_RUN` | Optional mode for reading events without writing downstream. |

Target-specific adapters document their own placeholders in their README files.

## Current Adapter Slots

* [`consumer_twenty`](consumer_twenty/README.md) maps local outbox events into
  Twenty CRM records.
* [`consumer_chatwoot`](consumer_chatwoot/README.md) forwards local outbox events
  into Chatwoot conversations or messages.

