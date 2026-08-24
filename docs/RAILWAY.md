# Railway: one-service self-hosting

This deployment runs the self-hosted PWA and Node API in one Railway service. nginx listens on
Railway's injected `PORT`, proxies `/api` to an internal `API_PORT`, and the API stores all mutable
state on one volume mounted at `/data`. Exercise media stays outside the image and loads from the
commit-pinned upstream CDN URLs documented in `NOTICE.md`.

The native Capacitor build is a separate, device-local flavor and does not connect to this server.
On iPhone, this Railway deployment is used through Safari or **Add to Home Screen**.

## First deployment

Railway's current Infrastructure as Code file is `.railway/railway.ts`. It creates one `opengym`
service and one 1 GB `opengym-data` volume in US East. The service deliberately has no repository
source because this fork is deployed from the current checkout; `railway up` uploads it directly.

1. Install Railway CLI **5.42.1 or newer**, install the pinned IaC evaluator, and authenticate:

   ```sh
   brew install railway
   npm ci --prefix .railway
   railway login
   ```

2. From the repository root, create and link a Railway project named `opengym`, then review and
   apply the service and volume plan:

   ```sh
   railway init
   railway config plan
   railway config apply
   railway service opengym
   ```

3. Choose the permanent public hostname **before registering any passkey**. Either generate a
   Railway domain with `railway domain` or attach the custom domain you intend to keep. Set:

   ```text
   RP_ID=<hostname only, without https:// or a path>
   ORIGIN=https://<the exact same public hostname>
   ```

   Set both in the Railway service's Variables tab or with `railway variable set`. Do not set
   Railway's `PORT`; the platform injects it. Changing `RP_ID` later invalidates passkeys created
   for the old hostname.

4. Build and deploy the current checkout, then verify both layers through the public origin:

   ```sh
   railway up --service opengym --detach
   curl --fail https://<hostname>/api/health
   ```

   A healthy response is JSON with `"ok": true`. Railway also checks `/api/health` before routing
   a new deployment.

## Lock down registration after the owner profile exists

Do **not** start with invite-only mode: without an existing admin, nobody can generate the first
invite. First create the owner's passkey profile at the final hostname, then inspect `/data/db.json`
through `railway ssh` to find that profile's `id`. Set these service variables and redeploy:

```text
ADMIN_UIDS=<owner profile id>
INVITE_ONLY=1
ALLOW_GUEST=0
```

The owner will then see the Admin dashboard and can create invite codes. `INVITE_ONLY=1` controls
new server profiles; `ALLOW_GUEST=0` separately removes browser-only guest mode.

## Data and backups

Everything needed to restore the server lives under `/data`: profiles and public passkeys,
per-profile workout state, the session secret, push keys, and the audit log. Keep the service at one
replica; this JSON store is not safe for concurrent writers or multiple regions.

- Enable Railway's daily and weekly volume backups in the service **Backups** tab.
- Take a manual volume backup before each application update.
- Use each profile's **Settings → Export data** for a portable off-platform copy of workout data.
- Treat full volume backups as sensitive: `/data/secret` can sign sessions and the state files may
  contain body weight and training history.

Restoring a Railway backup stages a replacement volume. Review it, deploy the staged change, and
confirm `/api/health` plus a passkey login before deleting the previous volume.

## Updates and diagnostics

From a reviewed checkout, run `railway up --service opengym --detach` and watch `railway logs`.
The attached volume survives builds and deploys. If either nginx or the Node API exits, the
supervisor stops the other process and exits non-zero so Railway's restart policy can recover the
whole service instead of leaving a partially working container.

The container retains openGym's AGPL license and third-party notices under
`/usr/share/licenses/opengym/`. This distribution's corresponding source is published at
<https://github.com/isaacSoto10/OpenGym>; the original project remains at
<https://gitlab.com/DuarteSantos8/opengym>. If you deploy further modifications, make the exact
corresponding source available to your users as required by the AGPL.
