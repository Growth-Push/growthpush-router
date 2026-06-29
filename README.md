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
* forwards events to local tools such as Twenty CRM, Chatwoot, n8n or custom systems.

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
```

### Agent mode

Runs inside the client environment.

It receives signed events from the edge router and applies the client-side business logic:

```text
Client Agent
  ↓
Twenty CRM
  ↓
Chatwoot / n8n / custom workflows
```

### Both mode

Runs edge and agent together in the same deployment.

This is useful for demos, development, internal use and small self-hosted setups.

```text
Meta webhook
  ↓
Growth Push Router :both
  ↓
Twenty CRM + Chatwoot
```

## MVP target

The first MVP focuses on Growth Push internal dogfooding:

```text
Growth Push Instagram
  ↓
Meta App webhook
  ↓
Growth Push Router in :both mode
  ↓
Twenty CRM
  ↓
Chatwoot API Channel
```

The MVP should demonstrate:

* Instagram event received;
* event wrapped and processed;
* lead created or updated in Twenty;
* conversation/message visible in Chatwoot;
* minimal admin/onboarding flow for connecting Instagram;
* privacy and data deletion pages required for Meta App review.

## Design principles

* Client business data should remain in the client environment.
* The edge router should not store customer lead history or conversation content long-term.
* Events sent from edge to agent should be signed.
* Event processing should be idempotent.
* Client-side business logic belongs in the agent.
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

Initial targets:

* Instagram webhooks
* WhatsApp webhooks
* Twenty CRM
* Chatwoot API Channel

Future targets:

* email inbound events
* n8n workflows
* custom webhook destinations
* follow-up and conversation state tracking

