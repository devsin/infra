# GitHub OAuth for Supabase Auth — Manual Setup

## Overview

This guide covers configuring **Sign in with GitHub** for a brand's Supabase Auth.
GitHub OAuth is the simplest provider to set up — no cloud project, no rotating
secrets, no developer program fees.

**Terraform:** Not possible — GitHub OAuth Apps have no Terraform/API resource
for automated creation. Setup is fully manual but takes ~3 minutes.

### Prerequisites

| Requirement                        | Where                          |
| ---------------------------------- | ------------------------------ |
| GitHub account (free)              | [github.com](https://github.com) |
| Supabase project for the brand/env | Supabase Dashboard             |

---

## Step 1 — Create a GitHub OAuth App

1. Decide where to register the OAuth App:
   - **Personal account:** [Settings → Developer settings → OAuth Apps](https://github.com/settings/developers)
   - **Organization:** `https://github.com/organizations/<org>/settings/applications`

   > Use the organization if the brand has its own GitHub org. Otherwise, personal
   > account is fine for solo/small-team setups.

2. Click **New OAuth App** (or **Register a new application**)
3. Fill in:

   | Field                       | Value                                                     |
   | --------------------------- | --------------------------------------------------------- |
   | Application name            | `<Brand> (<Env>)` (e.g. `MyApp Dev`)                      |
   | Homepage URL                | `https://<app-domain>`                                     |
   | Application description     | (optional) `Sign in with GitHub for <Brand>`               |
   | Authorization callback URL  | `https://<supabase-ref>.supabase.co/auth/v1/callback`      |

   > Replace `<supabase-ref>` with your Supabase project reference ID.

4. Click **Register application**
5. On the next page, copy the **Client ID**
6. Click **Generate a new client secret** → copy the **Client Secret**

   > Store the Client Secret securely — it's shown only once. If lost, you can
   > generate a new one (the old one is revoked).

---

## Step 2 — Configure Supabase Auth

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → select the project
2. Navigate to **Authentication → Providers**
3. Find **GitHub** and expand it
4. Toggle **Enable Sign in with GitHub**
5. Fill in:

   | Field         | Value                   |
   | ------------- | ----------------------- |
   | Client ID     | from Step 1             |
   | Client Secret | from Step 1             |

6. Click **Save**

---

## Step 3 — Frontend Integration

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "github",
  options: {
    redirectTo: "https://<app-domain>/auth/callback",
  },
});
```

### Requesting additional scopes (optional)

By default, Supabase requests the `user:email` scope. To access more GitHub data
(e.g. private repos), add scopes:

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "github",
  options: {
    redirectTo: "https://<app-domain>/auth/callback",
    scopes: "read:user user:email",
  },
});
```

Common scopes:

| Scope         | Access                          |
| ------------- | ------------------------------- |
| `user:email`  | User's email addresses (default)|
| `read:user`   | User's profile data             |
| `repo`        | Private repositories            |
| `read:org`    | Organization membership         |

Full list: [GitHub OAuth scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)

---

## Step 4 — Verify

1. Open your app (local or deployed)
2. Click "Sign in with GitHub"
3. GitHub shows an authorization page with your app name
4. After authorization, you're redirected back and authenticated
5. Check **Supabase Dashboard → Authentication → Users** to confirm the user

---

## Repeating for Production

1. Create a **separate OAuth App** for production with:
   - Homepage URL: `https://<prod-app-domain>`
   - Callback URL: `https://<prod-supabase-ref>.supabase.co/auth/v1/callback`
2. Configure the production Supabase project's GitHub provider with the new credentials

> Using separate OAuth Apps per environment prevents callback URL conflicts and
> makes it easy to revoke dev credentials independently.

---

## OAuth App vs GitHub App

GitHub offers two types of apps. For Supabase Auth, use **OAuth App**:

| Feature        | OAuth App              | GitHub App                    |
| -------------- | ---------------------- | ----------------------------- |
| Use case       | User authentication    | Integrations, bots, CI        |
| Setup          | Simple                 | More complex (webhooks, perms)|
| Token type     | User access token      | Installation token            |
| Right choice?  | **Yes — for Supabase** | No — overkill for auth        |

---

## Troubleshooting

| Issue                                | Fix                                                              |
| ------------------------------------ | ---------------------------------------------------------------- |
| `redirect_uri_mismatch`             | Callback URL must **exactly** match what's in the OAuth App settings |
| `bad_verification_code`             | Auth code expired or already used — retry the sign-in flow       |
| No email in user profile             | User has no public email — the `user:email` scope fetches private emails too |
| `application_suspended`              | OAuth App was suspended by GitHub — check your email for notices  |

---

## Security Notes

- **Never commit** the Client Secret to version control
- Client secrets are static and do not expire — rotate manually if compromised
- Register OAuth Apps under the brand's GitHub organization when possible
- Review authorized OAuth Apps periodically in GitHub Settings → Applications
