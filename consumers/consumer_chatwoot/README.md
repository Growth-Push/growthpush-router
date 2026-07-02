# Chatwoot Consumer

`consumer_chatwoot` is the local adapter slot for forwarding agent outbox events
into Chatwoot.

This directory is intentionally a placeholder for the adapter boundary. It must
not contain customer-specific mapping, real credentials, or code that belongs in
the Phoenix router core.

## Responsibility

The Chatwoot consumer reads local agent outbox records, maps relevant provider
events into Chatwoot contacts, conversations, or messages, and writes them to
Chatwoot with idempotency.

It owns:

* connecting to Chatwoot;
* mapping Instagram, WhatsApp, or other provider payloads into Chatwoot contacts,
  conversations, messages, and inbox routing;
* storing the `consumer_chatwoot` cursor;
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
`sequence` for `consumer_chatwoot`.

## Environment Placeholders

These are documentation placeholders for future implementation. Do not commit
real values.

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Local router database that contains the agent outbox. |
| `CONSUMER_NAME` | Defaults to `consumer_chatwoot`. |
| `CONSUMER_BATCH_SIZE` | Maximum events to read per poll. |
| `CONSUMER_CURSOR_PATH` | Local file or storage reference for the Chatwoot cursor. |
| `CHATWOOT_BASE_URL` | Base URL for the target Chatwoot instance. |
| `CHATWOOT_ACCOUNT_ID` | Account identifier for the target Chatwoot instance. |
| `CHATWOOT_API_TOKEN` | API token for the target Chatwoot instance. |
| `CHATWOOT_INBOX_ID` | Inbox identifier used for routed conversations or messages. |
| `DRY_RUN` | Optional mode for mapping without writing to Chatwoot. |
| `LOG_LEVEL` | Runtime logging level. |

## Not In Scope Yet

This placeholder does not implement polling, cursor storage, retries, API
clients, contact resolution, inbox routing, or message field mappings. Those
should be added only after the shared consumer contract is stable.

