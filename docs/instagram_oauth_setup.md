# Instagram OAuth Setup

This guide configures the Meta/Facebook OAuth flow used by Growth Push Router to
connect an Instagram Business account to a user-owned agent.

This is not Instagram username/password login. Meta's Instagram Graph API flow
uses a Facebook user, a Facebook Page, and the Instagram professional account
connected to that Page.

## Prerequisites

Before configuring env vars, confirm all of this is true:

1. You have a Meta developer account.
2. You have a Meta app at <https://developers.facebook.com/apps/>.
3. The Facebook user who will click **connect with Instagram** is added to the
   Meta app as an admin, developer, or tester while the app is in Development
   mode.
4. That Facebook user has access to a Facebook Page.
5. The Instagram account is a professional account, preferably Business.
6. The Instagram professional account is connected to that Facebook Page.
7. The Phoenix app is reachable through a public HTTPS URL for OAuth callback
   testing. For local development, use a tunnel.

If any of items 3-6 are missing, OAuth may succeed but `/me/accounts` will fail
or return no Instagram account.

## Connect Instagram To A Facebook Page

Do this before testing Growth Push Router.

1. Open Instagram for the account you want to connect.
2. Switch the account to a professional account:
   **Settings and privacy > Account type and tools > Switch to professional
   account**.
3. Choose **Business** if available.
4. Connect the Instagram account to a Facebook Page.
   You can usually do this from Instagram account settings or Meta Business
   Suite.
5. In Meta Business Suite, confirm the Page and Instagram account appear under
   the same business/account area.
6. Confirm the Facebook user used for OAuth has access to that Page.

Expected result: the Facebook user can see the Page, and the Page has an
Instagram professional account attached.

## Configure The Meta App

1. Open <https://developers.facebook.com/apps/>.
2. Select the app used by Growth Push Router.
3. Go to **App settings > Basic**.
4. Copy **App ID**. This becomes `META_INSTAGRAM_CLIENT_ID`.
5. Copy **App secret**. This becomes `META_INSTAGRAM_CLIENT_SECRET`.
6. Set the app domain for production. Use only the domain, not `https://`.
7. Add the Facebook Login/OAuth product if it is not already enabled.
8. Open the Facebook Login/OAuth settings.
9. Add the exact redirect URL:

   ```text
   https://YOUR_PUBLIC_ROUTER_HOST/auth/instagram/callback
   ```

10. If testing locally through a tunnel, add the tunnel callback URL too:

    ```text
    https://YOUR-TUNNEL-HOST/auth/instagram/callback
    ```

The redirect URI must match exactly, including scheme, host, path, and trailing
slash behavior. A mismatch usually breaks the OAuth code exchange.

## App Roles In Development Mode

While the Meta app is in Development mode, only app users can authorize it.

For local/dev testing:

1. Open the Meta app dashboard.
2. Go to **App roles**.
3. Add the Facebook user as admin, developer, or tester.
4. Accept the app role invitation from that Facebook account if Meta requires it.
5. Use that same Facebook account when clicking **connect with Instagram**.

If a non-role user tries the flow while the app is in Development mode, Meta may
deny permissions or return incomplete data.

## Required Environment Variables

Set these in the deployment environment. For local development, `.envrc` defines
safe defaults and `.envrc.custom` should hold real secrets.

```bash
export META_INSTAGRAM_CLIENT_ID="123456789012345"
export META_INSTAGRAM_CLIENT_SECRET="app-secret-from-meta"
export META_INSTAGRAM_REDIRECT_URI="https://router.example.com/auth/instagram/callback"
export META_GRAPH_VERSION="v23.0"
export META_INSTAGRAM_SCOPES="instagram_basic,pages_show_list,pages_read_engagement"
```

### `META_INSTAGRAM_CLIENT_ID`

Use the Meta app **App ID** from **App settings > Basic**.

### `META_INSTAGRAM_CLIENT_SECRET`

Use the Meta app **App secret** from **App settings > Basic**.

Do not commit this value. Put it in `.envrc.custom`, the VPS environment, or the
secret manager used by the deployment.

### `META_INSTAGRAM_REDIRECT_URI`

Use the public callback URL registered in Meta:

```text
https://YOUR_PUBLIC_ROUTER_HOST/auth/instagram/callback
```

For local development, use the public tunnel URL, not `localhost`:

```text
https://YOUR-TUNNEL-HOST/auth/instagram/callback
```

### `META_GRAPH_VERSION`

Use the Graph API version used in OAuth and Graph requests.

Current default:

```bash
export META_GRAPH_VERSION="v23.0"
```

Update this when Meta deprecates the configured Graph API version.

### `META_INSTAGRAM_SCOPES`

Use:

```bash
export META_INSTAGRAM_SCOPES="instagram_basic,pages_show_list,pages_read_engagement"
```

Why:

* `instagram_basic` lets the app read basic Instagram professional account data.
* `pages_show_list` lets the app list Pages the Facebook user can access.
* `pages_read_engagement` helps the app read Page metadata needed when
  traversing from Page to Instagram Business account.

If Meta asks for App Review, only request permissions that the current feature
needs.

## Webhook Verification

Meta verifies a webhook callback before it sends real events to it.

Configure a shared verification token in the deployment environment:

```bash
export META_WEBHOOK_VERIFY_TOKEN="a-long-random-shared-token"
```

Then register this callback URL in the Meta app webhook settings:

```text
https://YOUR_PUBLIC_ROUTER_HOST/webhooks/meta
```

When Meta verifies the callback, it sends `hub.mode`, `hub.verify_token`, and
`hub.challenge` query params. Growth Push Router accepts the request only when
`hub.mode` is `subscribe` and `hub.verify_token` matches
`META_WEBHOOK_VERIFY_TOKEN`, then responds with the raw `hub.challenge` value.

Local curl check:

```bash
curl "https://YOUR_PUBLIC_ROUTER_HOST/webhooks/meta?hub.mode=subscribe&hub.verify_token=a-long-random-shared-token&hub.challenge=123456"
```

Expected response:

```text
123456
```

This only verifies the webhook URL. Receiving real `POST` webhook events,
checking Meta signatures, and storing event payloads are separate steps.

## Local Development Example

1. Start a tunnel to the Phoenix app.
2. Add the tunnel callback URL to the Meta app OAuth redirect settings.
3. Put real credentials in `.envrc.custom`:

   ```bash
   export META_INSTAGRAM_CLIENT_ID="123456789012345"
   export META_INSTAGRAM_CLIENT_SECRET="app-secret-from-meta"
   export META_INSTAGRAM_REDIRECT_URI="https://example-tunnel.ngrok-free.app/auth/instagram/callback"
   export META_GRAPH_VERSION="v23.0"
   export META_INSTAGRAM_SCOPES="instagram_basic,pages_show_list,pages_read_engagement"
   export META_WEBHOOK_VERIFY_TOKEN="a-long-random-shared-token"
   ```

4. Reload direnv:

   ```bash
   direnv allow
   ```

5. Start Phoenix.
6. Sign in as a normal user that owns an agent.
7. Open `/dashboard`.
8. Click **connect with Instagram** on the agent.

## Validate With Graph API Explorer

If the app shows:

```text
não foi possível buscar a conta Instagram no Meta Graph.
```

then OAuth reached Meta, but the app could not read the Page/Instagram account
from Graph.

Use Graph API Explorer or another Meta token debugging tool with the same
Facebook user and permissions, then call:

```text
GET /me/accounts?fields=id,name,instagram_business_account{id,username,name}
```

Expected successful shape:

```json
{
  "data": [
    {
      "id": "FACEBOOK_PAGE_ID",
      "name": "Page Name",
      "instagram_business_account": {
        "id": "17841400000000000",
        "username": "instagram_username"
      }
    }
  ]
}
```

If `data` is empty, the Facebook user does not have Page access or the token
does not include Page-list permissions.

If pages are returned but `instagram_business_account` is missing, the Page is
not connected to an Instagram professional account.

If Meta returns a permission error, check app roles, app mode, requested scopes,
and whether permissions require App Review for the current user/app state.

## Current Token Handling

The current implementation completes OAuth and creates a `connections` row, but
it does not persist the raw Meta access token in the database.

Instead, it stores an `access_token_ref` like:

```text
oauth://meta/instagram/17841400000000000
```

That keeps raw tokens out of the connection row. A later token-vault step should
bind this reference to encrypted token storage before the app uses the token for
real API work.

## Troubleshooting

### `não foi possível trocar o código OAuth por um token Meta`

Likely causes:

* `META_INSTAGRAM_CLIENT_ID` is wrong.
* `META_INSTAGRAM_CLIENT_SECRET` is wrong.
* `META_INSTAGRAM_REDIRECT_URI` does not exactly match the URI registered in
  Meta.
* The OAuth `code` expired or was already used.

### `não foi possível buscar a conta Instagram no Meta Graph`

Likely causes:

* The Facebook user has no access to a Page.
* The Page is not connected to an Instagram professional account.
* The app is in Development mode and the Facebook user is not an app role user.
* `META_INSTAGRAM_SCOPES` is missing `pages_show_list` or
  `pages_read_engagement`.
* The permission is unavailable to the app/user until Meta App Review or app
  setup is completed.

Check the Phoenix server logs for:

```text
Instagram OAuth failed: ...
```

The log includes Meta's status code and error message when Meta returns one.

## User Flow

1. Admin creates a user and an agent.
2. User signs in and opens `/dashboard`.
3. User clicks **connect with Instagram** on an agent.
4. Meta asks the user to approve access.
5. Meta redirects to `/auth/instagram/callback`.
6. Growth Push Router finds the Instagram Business account and creates the
   `meta` / `instagram` connection for that agent.
