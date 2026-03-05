# Apple OAuth for Supabase Auth — Manual Setup

## Overview

This guide covers configuring **Sign in with Apple** for a brand's Supabase Auth.
**None of these steps can be automated via Terraform** — Apple does not expose a
public API for Developer Portal management.

### Prerequisites

| Requirement                              | Where                               |
| ---------------------------------------- | ----------------------------------- |
| Apple Developer Program ($99/year)       | [developer.apple.com](https://developer.apple.com/programs/) |
| Supabase project for the brand/env       | Supabase Dashboard                  |
| Custom domain (optional but recommended) | DNS provider                        |

> Unlike Google OAuth, Apple Sign in does **not** require any GCP project
> configuration or APIs. It's entirely within the Apple ecosystem.

---

## Step 1 — Register an App ID (Apple Developer Portal)

1. Go to [Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **+** to register a new identifier
3. Select **App IDs** → Continue
4. Select type **App** → Continue
5. Fill in:

   | Field       | Value                                |
   | ----------- | ------------------------------------ |
   | Description | `<Brand> Auth`                       |
   | Bundle ID   | `com.<org>.<brand>` (e.g. `com.acme.myapp`) |

6. Under **Capabilities**, check **Sign in with Apple**
7. Click **Continue** → **Register**

> This App ID is the "parent" identifier. For web-based OAuth, you'll create a
> Services ID in the next step.

---

## Step 2 — Create a Services ID (for web OAuth)

1. Go to [Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **+** → Select **Services IDs** → Continue
3. Fill in:

   | Field       | Value                                |
   | ----------- | ------------------------------------ |
   | Description | `<Brand> Web (<Env>)`                |
   | Identifier  | `com.<org>.<brand>.web` (e.g. `com.acme.myapp.web`) |

4. Click **Continue** → **Register**
5. Click on the newly created Services ID to edit it
6. Check **Sign in with Apple** → click **Configure**
7. In the configuration dialog:

   | Field                  | Value                                                      |
   | ---------------------- | ---------------------------------------------------------- |
   | Primary App ID         | Select the App ID from Step 1                              |
   | Domains and Subdomains | `<supabase-ref>.supabase.co`                               |
   | Return URLs            | `https://<supabase-ref>.supabase.co/auth/v1/callback`      |

   > Replace `<supabase-ref>` with your Supabase project reference ID.

8. Click **Next** → **Done** → **Continue** → **Save**

> The **Services ID identifier** (e.g. `com.acme.myapp.web`) is
> your **Client ID** for Supabase.

---

## Step 3 — Create a Private Key

1. Go to [Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to register a new key
3. Fill in:

   | Field    | Value                   |
   | -------- | ----------------------- |
   | Key Name | `<Brand> Supabase Auth` |

4. Check **Sign in with Apple** → click **Configure**
5. Select the **Primary App ID** from Step 1 → **Save**
6. Click **Continue** → **Register**
7. **Download** the `.p8` key file — **store it securely, you can only download it once**
8. Note the **Key ID** shown on the confirmation page

> You'll also need your **Team ID** — find it at the top-right of the Developer
> Portal, or at [Account → Membership](https://developer.apple.com/account#MembershipDetailsCard).

---

## Step 4 — Generate the Client Secret (JWT)

Apple doesn't use a static client secret. Instead, you generate a **JWT** signed
with the private key from Step 3. This JWT is valid for up to **6 months** and
must be rotated before expiry.

### Using a script

```bash
#!/bin/bash
# generate-apple-secret.sh
#
# Generates a JWT client secret for Sign in with Apple.
# Requires: ruby (pre-installed on macOS) or use the Node.js alternative below.

TEAM_ID="<your-team-id>"          # Apple Developer Team ID
CLIENT_ID="com.<org>.<brand>.web" # Services ID from Step 2
KEY_ID="<your-key-id>"            # Key ID from Step 3
KEY_FILE="AuthKey_<KEY_ID>.p8"    # Path to downloaded .p8 file

# JWT valid for 6 months (maximum allowed by Apple)
ruby -e "
require 'jwt'
require 'time'

key = OpenSSL::PKey::EC.new(File.read('$KEY_FILE'))
now = Time.now.to_i

payload = {
  iss: '$TEAM_ID',
  iat: now,
  exp: now + 86400 * 180,  # 6 months
  aud: 'https://appleid.apple.com',
  sub: '$CLIENT_ID'
}

header = { kid: '$KEY_ID' }

puts JWT.encode(payload, key, 'ES256', header)
"
```

### Using Node.js (alternative)

```javascript
// generate-apple-secret.mjs
import jwt from "jsonwebtoken"; // npm install jsonwebtoken
import fs from "fs";

const privateKey = fs.readFileSync("./AuthKey_<KEY_ID>.p8");

const token = jwt.sign({}, privateKey, {
  algorithm: "ES256",
  expiresIn: "180d",
  audience: "https://appleid.apple.com",
  issuer: "<TEAM_ID>",
  subject: "com.<org>.<brand>.web", // Services ID
  header: {
    kid: "<KEY_ID>",
    alg: "ES256",
  },
});

console.log(token);
```

Run the script and copy the output — this is your **Client Secret** for Supabase.

> **Important:** Set a calendar reminder to regenerate this secret before it
> expires (every 6 months). Apple will reject expired JWTs silently.

---

## Step 5 — Configure Supabase Auth

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → select the project
2. Navigate to **Authentication → Providers**
3. Find **Apple** and expand it
4. Toggle **Enable Sign in with Apple**
5. Fill in:

   | Field                   | Value                                    |
   | ----------------------- | ---------------------------------------- |
   | Client ID (Services ID) | `com.<org>.<brand>.web` (from Step 2)    |
   | Secret Key (JWT)        | Generated JWT from Step 4                |

6. Click **Save**

---

## Step 6 — Frontend Integration

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "apple",
  options: {
    redirectTo: "https://<app-domain>/auth/callback",
  },
});
```

> Apple returns the user's name **only on the first sign-in**. Make sure your
> callback handler captures and stores it immediately. Subsequent sign-ins will
> only return the email (or a private relay email if the user chose "Hide My Email").

---

## Step 7 — Verify

1. Open your app (local or deployed)
2. Click "Sign in with Apple"
3. You should see Apple's sign-in page
4. After authentication, you're redirected back to your app
5. Check **Supabase Dashboard → Authentication → Users** to confirm the user

---

## Repeating for Production

1. **Same App ID** and **Key** can be reused across environments
2. Create a **new Services ID** for production (e.g. `com.<org>.<brand>.web.prod`)
3. Configure its domains/return URLs to point to the **production** Supabase project
4. Generate a new JWT with the production Services ID as the `sub` claim
5. Configure the production Supabase project's Apple provider

---

## Private Relay Email

When users choose **"Hide My Email"**, Apple generates a unique private relay
address (e.g. `abc123@privaterelay.appleid.com`). To send emails to these addresses:

1. Go to [Certificates, Identifiers & Profiles → Services → Sign in with Apple for Email Communication](https://developer.apple.com/account/resources/services/list)
2. Click **+** next to "Email Sources"
3. Register your sending domains and/or email addresses:
   - Domain: `<brand-domain>` (e.g. `myapp.com`)
   - Individual email: `noreply@<brand-domain>`
4. Verify via DNS TXT record (Apple provides instructions)

> Without this, transactional emails (password reset, magic links) sent to private
> relay addresses will be silently dropped by Apple.

---

## Summary of Values

| Value             | Where to find it                        | Used in        |
| ----------------- | --------------------------------------- | -------------- |
| Team ID           | Apple Developer Portal → Membership     | JWT generation |
| App ID / Bundle ID| Identifiers → App IDs                  | Services ID parent |
| Services ID       | Identifiers → Services IDs             | Supabase Client ID |
| Key ID            | Keys → the key you created              | JWT generation |
| Private Key (.p8) | Downloaded once during key creation     | JWT generation |
| Client Secret     | Generated JWT (valid 6 months)          | Supabase Secret Key |

---

## Troubleshooting

| Issue                                | Fix                                                                  |
| ------------------------------------ | -------------------------------------------------------------------- |
| `invalid_client`                     | JWT expired, wrong `sub` (must be Services ID, not App ID), or wrong Key ID |
| `redirect_uri_mismatch`             | Return URL in Services ID config doesn't match Supabase callback URL |
| User email is `@privaterelay.appleid.com` | Normal — user chose "Hide My Email". Register email source (see above) |
| Name not returned on sign-in         | Apple only sends name on first auth. Check if user already signed in previously |
| `invalid_grant`                      | Auth code expired (Apple codes are single-use, valid ~5 minutes)     |

---

## Security Notes

- **Never commit** the `.p8` private key to version control
- Store the `.p8` file in a secure location (e.g. 1Password, GCP Secret Manager)
- Rotate the JWT client secret before the 6-month expiry
- The private key itself does not expire — only the generated JWT does
- Consider automating JWT rotation via a scheduled script or CI job
