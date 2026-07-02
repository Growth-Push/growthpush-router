# Growth Push Router

Open-source Elixir/Phoenix router for connecting Meta channel events to self-hosted business systems.

Growth Push Router helps agencies, developers and small businesses integrate Instagram, WhatsApp and other commercial channels with self-hosted tools such as CRMs, inboxes and automation agents.

The goal is to make Meta App based integrations more transparent, auditable and self-hostable, without forcing every business workflow to depend on paid cloud inbox or automation platforms.

## Why this exists

Many small businesses receive commercial opportunities through Instagram, WhatsApp and email, but their sales process usually lives somewhere else: a CRM, a spreadsheet, an inbox, or a custom internal system.

Cloud platforms can solve this, but they often centralize customer data, add recurring per-agent costs and limit how much control the business has over its own workflow.

Growth Push Router is designed as a lightweight self-hosted layer that:

* receives channel events from providers such as Meta;
* validates and wraps incoming webhooks;
* routes events to the correct client-owned agent;
* keeps business data inside the client environment;
* persists agent events in a local database outbox for downstream consumers.

## Architecture

Growth Push Router can run in three modes:

### Edge mode

Runs in the agency or operator infrastructure.

It receives external webhooks, validates them, resolves the target client and forwards a signed event to the client agent.

```text
Instagram / WhatsApp / Email
        ↓
Edge Router
        ↓
Client Agent
        ↓
Local DB event outbox
```

### Agent mode

Runs inside the client environment.

It receives signed events from the edge router and stores them in the local event outbox:

```text
Client Agent
  ↓
Local DB event outbox
```

For now, processing stops at the local database. Consumers read the outbox and
perform downstream work independently.

### Both mode

Runs edge and agent together in the same deployment.

This is useful for demos, development, internal use and small self-hosted setups.

```text
Meta webhook
  ↓
Growth Push Router :both
  ↓
Local DB event outbox
```

Example consumers can read the local DB event outbox and then:

* send a conversation or message to Chatwoot;
* create or update a lead in Twenty CRM;
* trigger another local workflow or custom integration.

## MVP target

The first MVP focuses on Growth Push internal dogfooding:

```text
Growth Push Instagram
  ↓
Meta App webhook
  ↓
Growth Push Router in :both mode
  ↓
Local DB event outbox
```

The MVP should demonstrate:

* Instagram event received;
* event wrapped and stored locally;
* event visible in the local outbox;
* example consumers can read the DB outbox and push to systems such as Twenty or Chatwoot;
* minimal admin/onboarding flow for connecting Instagram;
* privacy and data deletion pages required for Meta App review.

Instagram OAuth setup is documented in
[`docs/instagram_oauth_setup.md`](docs/instagram_oauth_setup.md).

## Design principles

* Client business data should remain in the client environment.
* The edge router should not store customer lead history or conversation content long-term.
* Events sent from edge to agent should be signed.
* Event processing should be idempotent.
* Client-side business logic belongs in consumers outside the router core.
* The project should be simple to self-host.
* Cloud platforms should be optional, not mandatory.

## What this project is not

Growth Push Router is not intended to be:

* a full inbox replacement;
* a complete CRM;
* a chatbot platform;
* a social media scheduler;
* a workaround for Meta permissions or App Review.

Meta App permissions and review requirements still apply when using official Meta APIs.

## Planned integrations

Initial event sources:

* Instagram webhooks
* WhatsApp webhooks

Example outbox consumers:

* Twenty CRM lead creation or updates
* Chatwoot conversation or message forwarding

Future targets:

* email inbound events
* n8n workflows
* custom webhook destinations
* follow-up and conversation state tracking
