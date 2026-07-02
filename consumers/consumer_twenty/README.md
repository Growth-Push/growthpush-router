# Twenty Consumer

`consumer_twenty` is the local adapter slot for pushing agent outbox events into
Twenty CRM.

This directory is intentionally a placeholder for the adapter boundary. It must
not contain customer-specific mapping, real credentials, or code that belongs in
the Phoenix router core.

## Responsibility

The Twenty consumer reads local agent outbox records, maps provider-shaped
payloads into Twenty concepts, and writes them to Twenty with idempotency.

It owns:

* connecting to Twenty;
* mapping Instagram, WhatsApp, or other provider payloads into Twenty leads,
  people, companies, notes, tasks, or activities;
* storing the `consumer_twenty` cursor;
* retry and dead-letter behavior;
* target-system idempotency keys.

The router owns only the durable local event record and ordered polling
contract.

## Outbox Read Contract

Read only agent-side events from the local database:

```sql
select *
from events
where stored_by = 'agent'
  and sequence > $1
order by sequence asc
limit $2;
```

Process events in sequence order and persist the highest successfully processed
`sequence` for `consumer_twenty`.

## Environment Placeholders

These are documentation placeholders for future implementation. Do not commit
real values.

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Local router database that contains the agent outbox. |
| `CONSUMER_NAME` | Defaults to `consumer_twenty`. |
| `CONSUMER_BATCH_SIZE` | Maximum events to read per poll. |
| `CONSUMER_CURSOR_PATH` | Local file or storage reference for the Twenty cursor. |
| `TWENTY_BASE_URL` | Base URL for the target Twenty instance. |
| `TWENTY_API_KEY` | API token for the target Twenty instance. |
| `TWENTY_WORKSPACE_ID` | Optional workspace identifier when required by deployment. |
| `DRY_RUN` | Optional mode for mapping without writing to Twenty. |
| `LOG_LEVEL` | Runtime logging level. |

## Not In Scope Yet

This placeholder does not implement polling, cursor storage, retries, API
clients, or CRM field mappings. Those should be added only after the shared
consumer contract is stable.

