# Google OAuth for Supabase Auth — Manual Setup

## Overview

This guide covers configuring **Google OAuth (Sign in with Google)** for a brand's
Supabase Auth. It requires manual steps in both the **GCP Console** and the
**Supabase Dashboard** because GCP does not support fully automating External
OAuth consent screens via API/Terraform.

### Prerequisites

| Requirement                        | Where                             |
| ---------------------------------- | --------------------------------- |
| GCP project for the brand/env      | `gcp/stacks/1-org` (Phase 1)     |
| APIs enabled on the project        | `iap.googleapis.com`, `people.googleapis.com` |
| Supabase project for the brand/env | Supabase Dashboard                |
| Custom domain (optional but recommended) | DNS provider               |

> The Phase 1 org stack already enables the required APIs via the `workload_apis`
> variable. Verify with:
>
> ```bash
> gcloud services list --project=<PROJECT_ID> | grep -E "iap|people"
> ```

---

## Step 1 — Configure OAuth Consent Screen (GCP Console)

1. Go to [GCP Console → APIs & Services → OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)
2. Select the **brand project** (e.g. `prj-<brand>-dev-xxxx`)
3. Choose **User Type: External** → Create
4. Fill in the consent screen:

   | Field                | Value                              |
   | -------------------- | ---------------------------------- |
   | App name             | `<Brand Name>` or `<Brand> Dev`    |
   | User support email   | your email                         |
   | App logo             | (optional)                         |
   | App domain           | `https://<brand-domain>`           |
   | Authorized domains   | `<brand-domain>`, `supabase.co`    |
   | Developer contact    | your email                         |

5. **Scopes** — click "Add or Remove Scopes" and add:
   - `email`
   - `profile`
   - `openid`

6. **Test users** — add your own email (and any testers)
7. Click **Save and Continue** through all steps

> **Leave the app in "Testing" status.** This allows up to 100 test users without
> Google verification. Move to "In production" only when you're ready for public
> access (requires verification for sensitive scopes).

---

## Step 2 — Create OAuth 2.0 Client ID (GCP Console)

1. Go to [APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
2. **+ Create Credentials → OAuth client ID**
3. Configure:

   | Field                        | Value                                              |
   | ---------------------------- | -------------------------------------------------- |
   | Application type             | Web application                                    |
   | Name                         | `<Brand> Web (<Env>)`                              |
   | Authorized JavaScript origins | `https://<app-domain>`, `http://localhost:5173`    |
   | Authorized redirect URIs     | `https://<supabase-ref>.supabase.co/auth/v1/callback` |

   > Replace `<supabase-ref>` with the Supabase project reference ID.
   >
   > Add `http://localhost:5173` (or your local dev port) for local development.
   > Remove it before moving to production.

4. Click **Create**
5. Copy the **Client ID** and **Client Secret** — you'll need them in the next step

---

## Step 3 — Enable Google Provider in Supabase

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → select the project
2. Navigate to **Authentication → Providers**
3. Find **Google** and expand it
4. Toggle **Enable Sign in with Google**
5. Fill in:

   | Field                    | Value                                    |
   | ------------------------ | ---------------------------------------- |
   | Client ID                | from Step 2                              |
   | Client Secret            | from Step 2                              |
   | Authorized Client IDs    | (leave empty unless using native mobile) |
   | Skip nonce checks        | leave unchecked                          |

6. Click **Save**

---

## Step 4 — Frontend Integration

Use the Supabase client SDK to trigger the OAuth flow:

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: {
    redirectTo: 'https://<app-domain>/auth/callback',
  },
})
```

### Callback handling

On your `/auth/callback` route, exchange the auth code for a session:

```typescript
// src/routes/auth/callback/+server.ts (SvelteKit example)
import { redirect } from '@sveltejs/kit'

export const GET = async ({ url, locals: { supabase } }) => {
  const code = url.searchParams.get('code')

  if (code) {
    await supabase.auth.exchangeCodeForSession(code)
  }

  throw redirect(303, '/')
}
```

---

## Step 5 — Verify

1. Open your app (local or deployed)
2. Click "Sign in with Google"
3. You should see the Google consent screen with your app name
4. After consent, you're redirected back and authenticated
5. Check **Supabase Dashboard → Authentication → Users** to confirm the user was created

---

## Repeating for Production

When ready to set up the production environment:

1. Repeat Steps 1–3 for the **production** GCP project and **production** Supabase project
2. Use production domains (no `localhost`)
3. Consider moving the OAuth consent screen to **"In production"** status
   - Required if you want any Google user to sign in (not just test users)
   - May trigger a Google verification review for sensitive scopes

---

## Troubleshooting

| Issue                                 | Fix                                                        |
| ------------------------------------- | ---------------------------------------------------------- |
| `redirect_uri_mismatch`              | Ensure the Supabase callback URL exactly matches the one in GCP Credentials |
| `access_denied` / 403                | User not added as test user (while app is in Testing mode) |
| OAuth screen shows "unverified app"  | Normal in Testing mode — click "Continue" to proceed       |
| `invalid_client`                     | Client ID/Secret mismatch between GCP and Supabase         |
| User created but no `email` field    | Check that `email` scope is included in consent screen     |

---

## Security Notes

- **Never commit** OAuth Client Secrets to version control
- Store secrets in Supabase Dashboard (encrypted at rest) or a secrets manager
- Rotate Client Secrets periodically via GCP Console → Credentials → Edit → Add Secret
- For mobile apps, use separate OAuth client IDs with appropriate redirect schemes
