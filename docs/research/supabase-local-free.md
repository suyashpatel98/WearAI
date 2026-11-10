# What do Supabase's local stack and Free plan give WearAI for dev and deploys?

Research for issue #43 (part of the dev-ex map, #42). Researched 2026-11-09. It builds on [managed-backend.md](managed-backend.md), which chose Supabase. That document covers pricing, regions and Edge Function limits, so they are not repeated here. Sources are Supabase docs, the `supabase/cli` and `supabase/auth` repos, CLI `--help` output, and a short spike on the dev machine (marked **[spike]**).

## Answer

- **The CLI just had a major release.** v3.0.0 came out on 2026-11-02 and v3.1.0 on 2026-11-09 [R1][R2]. The installed CLI is 2.106. v3 changes CI: database commands now target the **local** stack unless you pass `--remote`, and every change to a hosted project fails without `--yes` [R1][R3]. Pin the CLI as a pnpm devDependency and write every command in v3 form.
- **Docker Desktop 20.10 works.** No Supabase doc gives a minimum Docker version. On this Mac, a full CLI 2.x stack of 12 containers has run on Docker Desktop 20.10.11 for 7 weeks. CLI 3.1.0 also ran `db start`, `migration up`, `test db` and `gen types` against it **[spike]**. Docker's VM has only about 2 GB of RAM, and that stack already uses about 1.2 GB of it. Give the VM 4 GB or more, or switch to OrbStack (free for personal use) or Colima (MIT licence). There is also an experimental Docker-free native runtime for Apple silicon on macOS 14 or later [R4].
- **Google sign-in can work against the local stack.** The app's flow is native Google Sign-In, which returns an ID token, followed by `signInWithIdToken`. Local Auth (GoTrue) checks the token's signature and checks that its audience is one of the `client_id`s in `config.toml` [R5][R6]. No redirect URL is involved. The phone must be able to reach the Mac (`adb reverse` or the LAN IP) over cleartext HTTP, and the Auth container needs internet access to fetch Google's signing keys. For tests and agents, use a seeded email/password user or OTP codes caught by Mailpit instead.
- **Free plan:** 2 active projects (paused projects don't count) [R7][R8]. A project pauses after a week of low database activity. Restore it from the dashboard or with `POST /v1/projects/{ref}/restore` on the Management API, within 1 year [R9][R10]. The Free plan is never charged [R11]. **Branching, image transformations, spend cap and compute sizes are all paid**, so stay away from them.
- **CI deploys need only an access token and a project ref.** The steps are `supabase/setup-cli@v3` → `supabase link` → `db push --remote --yes` → `functions deploy --use-api --yes` → `secrets set --env-file … --yes` [R3][R12][R13]. According to `db push --help`, a token with `database_write` can push without the database password.
- **DB tests need only the local Postgres container.** `supabase db start` followed by `supabase test db` ran pgTAP on this Mac in about 75 s, including image pulls **[spike]**. That included an RLS check that switches to the `authenticated` role with JWT claims. A GitHub `ubuntu-latest` runner has Docker, and Supabase's own example workflow uses it [R14].

## 1. CLI version: v3 is out, and CI must be written for it

| | |
|---|---|
| Installed | `supabase` 2.106.0, a global npm install under nvm Node 20.19.5 |
| Latest stable | **v3.1.0** (2026-11-09). v3.0.0 (2026-11-02) was the breaking release. The last v2 is v2.122.1 [R2] |
| Install | `pnpm add -D supabase --allow-build=supabase`. The flag is required on pnpm 10 and later. Run it with `pnpm supabase …`. The CLI needs Node 20 or later [R15][R16] |

Breaking changes in v3 that matter to WearAI [R1][R3]:

- `db push`, `db pull`, `gen types`, `migration list`/`repair`, `test db` and `storage …` target the **local** stack when no target is given. A bare `supabase db push` in CI "succeeds there and never reaches your project". Always pass `--remote` for hosted work.
- Any command that changes a hosted project (`db push`, `functions deploy`, `secrets set`/`unset`, `config push`, `projects create`, …) fails when run unattended unless you pass `--yes`, or export `SUPABASE_YES=1` in the shell. `SUPABASE_YES` set in a `.env` file is ignored. Piping `echo y` no longer works.
- `--linked`, `--project-ref` and `--db-url` are deprecated in favour of `--remote[=<ref|url>]`. Use `gen types` instead of `gen types --local`.
- Settings resolve in this order: flag > shell env > project `.env*` files > `config.toml`. Set `SUPABASE_ENV` in CI so `.env.development` doesn't apply.
- Without `project_id` in `config.toml`, local containers are named after the folder. Set `project_id` explicitly.
- `[inbucket]` is now `[local_smtp]`. Any `import_map.json` inside a function directory must become `deno.json`.
- v3.1.0: the local stack no longer adds CORS headers on `/functions/v1`, which matches hosted. A native app's `fetch` isn't subject to CORS, so this doesn't affect WearAI. `SUPABASE_API_MAX_RETRIES=0` stops the CLI retrying Management API requests in CI [R2].

## 2. What runs locally

`supabase start` runs these containers, with images pinned by CLI 3.1.0 (`supabase services`): Postgres **17.11.0.018**, GoTrue (Auth) v2.197.0, PostgREST v16.5, Realtime v2.154.0, Storage v1.90.1, Edge Runtime v1.78.1, Studio, postgres-meta, Logflare (analytics), Supavisor (pooler), plus Kong, Mailpit, imgproxy and Vector **[spike]**. Any of them can be skipped with `supabase start -x gotrue,realtime,…`. `supabase db start` starts Postgres alone.

Default endpoints [R15]: API `http://127.0.0.1:54321` (`/auth/v1`, `/rest/v1`, `/storage/v1`, `/functions/v1`), Postgres `postgresql://postgres:postgres@127.0.0.1:54322/postgres`, Studio `:54323`, Mailpit `:54324`.

| Area | Local behaviour |
|---|---|
| Postgres + RLS | Same Postgres image family as hosted; RLS policies behave the same. `supabase link` pins the local service versions to the hosted project's [R2]. Migrations live in `supabase/migrations`, applied by `db reset` or `migration up`. |
| Auth | GoTrue with a `[auth.external.google]` provider in `config.toml`. Email goes to Mailpit (`:54324`), not real inboxes. Email/password, OTP and anonymous sign-in are all available locally [R17]. |
| Storage | Same API. The default `file_size_limit` is 50 MiB, the same as the Free plan's upload limit [R17][R7]. Image transforms work locally through imgproxy, **but hosted image transformations are Pro-only** [R18]. Don't build on them. |
| Edge Functions | `supabase functions serve` hot-reloads functions on `:54321/functions/v1/<name>`. They run in the `edge-runtime` container, so Deno doesn't need to be installed; install it only for editor support and `deno lint/test` [R19]. `config.toml` defaults to `deno_version = 2` and `policy = "per_worker"` [R17]. Local secrets go in `supabase/functions/.env`, which must be gitignored [R20]. |
| Cron / Queues / pg_net | Run inside local Postgres. Inside a container, `127.0.0.1` means the container itself, so calls from the database or a function to another service must use the Docker network name or `host.docker.internal` [R15]. |

### Differences from hosted that could bite

1. **Image transformations work locally but not on the Free plan** (Pro and above only) [R18].
2. **Local limits are looser.** The only local/hosted difference Supabase lists for functions is bundle size: 20 MB when bundled by the CLI, 5 MB when bundled server-side. Hosted Free also enforces a 150 s wall clock, 2 s of CPU and 256 MB of memory [R21]. A function that works locally can still be killed when hosted.
3. **Email.** Locally, Mailpit catches every message. Hosted email depends on the project's SMTP setup, which this research didn't cover.
4. **Hosted Free has no backups and keeps only 1 day of logs** [R7].
5. **Secret names starting with `SUPABASE_` are reserved** on hosted [R20].
6. **Only one local project can use the default ports.** This Mac already runs a `tournament-scheduler` stack on 54321–54327 **[spike]**. Either stop that stack or give WearAI's `config.toml` different ports. The experimental `supabase stack` commands run one project per worktree [R16][R4].

## 3. Google sign-in against the local stack

**It works, with conditions.** How it works:

- The app calls `GoogleSignin.signIn()` and then `supabase.auth.signInWithIdToken({ provider: 'google', token: idToken })` [R5]. GoTrue's ID-token endpoint (`internal/api/token_oidc.go`) collects the Google `client_id` list from config and rejects the token if its `aud` isn't in that list ("Unacceptable audience in id_token"). It then checks the nonce, unless `skip_nonce_check` is set [R6]. No OAuth redirect or callback URL is involved, so `site_url` and redirect allow-lists don't matter for this flow.
- Local config [R5][R17]:

  ```toml
  [auth.external.google]
  enabled = true
  client_id = "<web-client-id>,<android-client-id>"   # web client first
  secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET)"
  skip_nonce_check = false   # the init template says "Required for local sign in with Google auth" -> set true if the nonce check fails
  ```

- The Android OAuth client is tied to the package name and signing-key SHA-1. A locally built dev build is signed with the debug keystore, which has a different SHA-1 from an EAS or release build. Supabase's docs say to register both sets of fingerprints [R5].
- **The phone has to reach the Mac.** Use `adb reverse tcp:54321 tcp:54321` over USB with `http://127.0.0.1:54321`, or the Mac's LAN IP. On the emulator, `10.0.2.2` is the host. Android 9 and later blocks cleartext HTTP by default [R22]. RN/Expo debug builds normally allow it; a release-type build needs `expo-build-properties` `android.usesCleartextTraffic` (not verified here).
- **The Auth container needs internet access** to fetch Google's OIDC keys, so Google sign-in won't work offline. This is inferred from GoTrue using an OIDC provider for `accounts.google.com` [R6]; it wasn't tested.
- **Not tested end to end.** The spike didn't run Google sign-in. It is the first thing to prove when the app skeleton exists.

**For tests and coding agents, don't use Google.** Seed an email/password user in `supabase/seed.sql`, or sign in by email OTP and read the code from Mailpit's UI or API at `:54324`. pgTAP RLS tests need no sign-in at all: they switch roles with `set local role authenticated; set local request.jwt.claims = '{"sub":"…"}'` **[spike]**.

## 4. Docker on an M1 with 16 GB

| Option | Works with Supabase CLI? | Cost / licence |
|---|---|---|
| **Docker Desktop 20.10.11** (installed, Nov 2021) | **Yes on this machine [spike]**: a CLI 2.x full stack (12 containers, healthy for 7 weeks) and CLI 3.1.0 `db start`/`test db`/`gen types`. A full `supabase start` on 3.1.0 wasn't tried, to avoid disturbing the running stack. | Free for personal use, education, non-commercial open source, and small businesses (fewer than 250 employees **and** less than $10M revenue) [R23] |
| Docker Desktop, current (4.88+ era, Engine 29.x) | Officially listed [R16] | Same licence. Supports only the current and two previous macOS releases; needs at least 4 GB RAM [R24] |
| **OrbStack** | Supabase's recommended runtime on macOS [R15] | $0 for "Personal, non-commercial use"; Pro is $8/user/month for business use [R25] |
| **Colima** | Listed (macOS only) [R15] | MIT, free. Default VM: 2 CPU, 2 GiB RAM, 100 GiB disk; change with `colima start --cpu 4 --memory 6` [R26] |
| Podman, Rancher Desktop | Listed [R16] | Free |
| Native runtime (experimental) | No container engine. Apple silicon on macOS 14 or later (this Mac runs macOS 26.3.1). Opt-in via `[experimental] stack`, then `supabase start --runtime native` [R4] | Free; experimental, so flags can change |

Version and resource facts:

- **No doc states a minimum Docker version or minimum RAM/disk for `supabase start`** [R15][R16][R4]. The only version threshold found is for the experimental stack: it stores the database in a Docker volume when the client and daemon are both v26 or later, and falls back to a host directory otherwise. So older Docker versions are supported on purpose [R4].
- The v3 CLI is TypeScript, and it calls the `docker` CLI rather than a pinned API client (`apps/cli/src/command-internal/docker-*.ts`) [R27]. That's why an old engine works, as long as the CLI flags it uses exist.
- Measured on this Mac **[spike]**: Docker Desktop's VM has 4 CPUs and **1.94 GiB** of RAM. The running full stack uses about 1.2 GiB in total (Logflare 354 MB, Studio 190 MB, Postgres 171 MB, Realtime 144 MB, …). Its images take about 8 GB of disk; the 2.x Postgres image alone is 3.09 GB, while the 3.1 one is 1.19 GB. `db start` on 3.1.0 took about 75 s with image pulls.
- **Recommendation:** raise Docker Desktop's memory to 4–6 GB, or run `supabase start -x logflare,vector,studio,supavisor,realtime` when you don't need those services. Upgrading Docker Desktop or switching to OrbStack is optional, and both are free for this use. Docker Desktop 20.10 gets no security fixes.

## 5. Free plan limits that matter for dev

From the pricing page [R7] unless noted. Edge Function limits are in managed-backend.md [S3]; only the Free-specific ones are repeated here.

| Limit | Free |
|---|---|
| Active projects | **2**, counted across all orgs where you're Owner/Admin. Paused projects don't count [R8] |
| Pausing | After about **7 days** with too little "user database activity". "A few user requests to the database each day" is usually enough. A warning email comes about a week before the pause [R9] |
| Undo a pause | Dashboard → Resume project, within **1 year**. Data and config come back [R9]. Scriptable via Management API `POST /v1/projects/{ref}/restore` (and `/pause`) [R10] |
| Database / Storage | 500 MB DB, 1 GB files, 50 MB max upload, 5 GB + 5 GB cached egress |
| Compute | Shared CPU, 500 MB RAM |
| Edge Functions | 500k invocations/month, **150 s wall clock** (paid: 400 s), 100 functions per project [R21] |
| Auth | 50,000 MAU |
| Backups / logs | No backups; 1-day log retention |
| Branching | **Not available on Free.** $0.01344 per branch-hour on Pro/Team. **Paid** |
| Image transformations | **Pro and above only. Paid** [R18] |
| Spend cap | Pro only. "You will not be charged while using the Free Plan" [R11] |
| Over quota | Notification, then a grace period, then restrictions; no bill [R28] |
| Card on file | **No primary source found.** Third-party guides say no card is needed. Since the Free plan is never charged [R11], a card wouldn't be billed anyway |

Things that would cost money, so avoid them:

- `supabase projects create --size …`: every size choice is a paid compute add-on. Omit `--size` on a Free org.
- `supabase branches create` / preview branching.
- Upgrading the org to Pro, which also brings the spend cap.
- Calling hosted image transformation URLs.

**Pausing and CI:** a WearAI dev project that sees no use for a week will pause, and then `db push` and deploys fail. A CI step can check the project's status and call `POST /v1/projects/{ref}/restore` with the same access token, so no dashboard click is needed. Whether CI's own traffic counts as "user database activity" isn't documented.

## 6. Deploying from GitHub Actions

Inputs (GitHub secrets):

- `SUPABASE_ACCESS_TOKEN`: a personal access token, or a **scoped** token. CLI `--help` lists the permissions each command needs, e.g. `functions deploy` needs `edge_functions_write`, `secrets set` needs `edge_functions_secrets_write`, `link` needs `project_admin_read` **[spike]**.
- `SUPABASE_PROJECT_ID`: the project ref. It isn't secret, but keeping it in a secret is harmless.
- `SUPABASE_DB_PASSWORD`: **may be unnecessary.** `db push --help` says that with `--remote` and no `--password`, the token needs `database_write`, which means the CLI connects through a temporary login role **[spike]**. Supabase's own workflow example still sets the password [R12]. Prove it either way in the first CI spike.

Workflow, in v3 syntax [R3][R12][R13][R29]:

```yaml
- uses: actions/checkout@v4
- uses: supabase/setup-cli@v3        # v3.2.0; installs the version pinned in pnpm-lock.yaml
- run: supabase link --project-ref "$SUPABASE_PROJECT_ID"
- run: supabase db push --remote --yes
- run: supabase functions deploy --use-api --yes   # server-side bundling, no Docker needed
- run: supabase secrets set --env-file ./functions.env --yes   # file written from GitHub secrets in an earlier step
env:
  SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
  SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
  SUPABASE_ENV: production
```

- `db push` records applied migrations in `supabase_migrations.schema_migrations` and skips them next time. `--dry-run` previews; `--include-seed` also seeds. Don't seed in production [R30].
- Functions pick up new secrets without a redeploy. `secrets unset` now needs names, or `--all` [R1][R20].
- JWT verification per function is set in `config.toml` (`[functions.<name>] verify_jwt = false`) or with `--no-verify-jwt` [R13].
- `setup-cli@v1`/`@v2` are legacy. `@v3` installs the CLI from npm (Node 20+) and, with no `version`, uses the version in the root lockfile [R29].

**TypeScript types:** run `supabase gen types --lang typescript > <path>/database.types.ts` against the local DB after migrations. Supabase's sample CI starts the DB, regenerates the types, and fails if `git diff` shows changes [R12][R31]. For hosted, the command is `gen types --remote=<ref>`, which needs the token [R31]. Generating from local means CI never touches the hosted project. **[spike]**: `gen types` produced `Database` types for a test table on CLI 3.1.0.

**Cost:** Actions minutes on standard runners are unlimited for this public repo (map #42). The Supabase CLI and Management API are free.

## 7. DB tests (`supabase test db` / pgTAP)

- `supabase test db [path…]` runs **`pg_prove` in a container** (`public.ecr.aws/supabase/pg_prove:3.36`) against the local DB. It runs tests in `supabase/tests/` (`*.sql`, `*.pg`). It enables the `pgtap` extension for the run and drops it afterwards, and rolls back each file whether it passes or fails [R32] **[spike]**.
- It needs only Postgres running. `supabase db start` is enough; there's no need to `supabase start` the whole stack **[spike]**.
- Tested on Docker 20.10.11 with CLI 3.1.0 **[spike]**: a migration created an RLS-protected table, and a pgTAP file inserted a row for user A, then ran `set local role authenticated` with user B's `request.jwt.claims` and asserted 0 visible rows. Result: `Files=1, Tests=2 … PASS`.
- On GitHub Actions: Supabase's example `db-tests.yml` runs on `ubuntu-latest` with `setup-cli`, `supabase start` and `supabase test db` [R14]. GitHub-hosted Ubuntu runners include Docker. Use `supabase db start` instead to save time.
- pgTAP has policy assertions (`policies_are`, `policy_roles_are`, `policy_cmd_is`) on top of behavioural checks like the one above [R33].
- `test db --remote` exists but needs `--yes` against hosted. Never use it in CI.

## Open points / spikes worth doing

1. Full `supabase start` on CLI 3.1.0 with Docker Desktop 20.10. The spike tested only `db start` and `test db`, plus a 2.x full stack.
2. Google sign-in from the OnePlus 7T dev build to the local stack (ports, cleartext, SHA-1, nonce).
3. `db push --remote --yes` in CI with only `SUPABASE_ACCESS_TOKEN` (no DB password), using a scoped token.
4. Whether the account already uses a Free project slot. The CLI isn't logged in on this Mac, so `supabase projects list` couldn't be checked.

## Sources

- [R1] Supabase CLI v3.0.0 release notes (2026-11-02): https://github.com/supabase/cli/releases/tag/v3.0.0
- [R2] Supabase CLI v3.1.0 release notes (2026-11-09) and release list: https://github.com/supabase/cli/releases/tag/v3.1.0
- [R3] Migrating to CLI v3: https://supabase.com/docs/guides/local-development/cli/migrating-to-v3
- [R4] Docker and native runtimes: https://supabase.com/docs/guides/local-development/docker-and-native-runtimes
- [R5] Login with Google: https://supabase.com/docs/guides/auth/social-login/auth-google
- [R6] GoTrue ID-token verification: https://github.com/supabase/auth/blob/master/internal/api/token_oidc.go
- [R7] Pricing: https://supabase.com/pricing (undated, read 2026-11-09)
- [R8] Billing on the Free plan: https://supabase.com/docs/guides/platform/billing-on-free-plan
- [R9] Project pausing: https://supabase.com/docs/guides/platform/free-project-pausing
- [R10] Management API OpenAPI spec (`/v1/projects/{ref}/restore`, `/pause`): https://api.supabase.com/api/v1-json ; docs https://supabase.com/docs/reference/api
- [R11] Control your costs: https://supabase.com/docs/guides/platform/cost-control
- [R12] Managing environments (GitHub Actions): https://supabase.com/docs/guides/deployment/managing-environments
- [R13] Deploy Edge Functions: https://supabase.com/docs/guides/functions/deploy ; `supabase functions deploy --help` (CLI 3.1.0)
- [R14] Testing overview: https://supabase.com/docs/guides/local-development/testing/overview
- [R15] CLI getting started: https://supabase.com/docs/guides/local-development/cli/getting-started
- [R16] Local development overview: https://supabase.com/docs/guides/local-development
- [R17] `supabase init` config template (CLI repo): https://github.com/supabase/cli/blob/develop/apps/cli/src/shared/init/testdata/templates/config.toml ; config reference https://supabase.com/docs/guides/local-development/cli/config
- [R18] Storage image transformations: https://supabase.com/docs/guides/storage/serving/image-transformations
- [R19] Edge Functions development environment: https://supabase.com/docs/guides/functions/development-environment
- [R20] Edge Function secrets: https://supabase.com/docs/guides/functions/secrets
- [R21] Edge Function limits: https://supabase.com/docs/guides/functions/limits
- [R22] Android network security config (cleartext defaults): https://developer.android.com/privacy-and-security/security-config
- [R23] Docker Desktop licence: https://docs.docker.com/subscription/desktop-license/
- [R24] Docker Desktop for Mac requirements: https://docs.docker.com/desktop/setup/install/mac-install/
- [R25] OrbStack pricing: https://orbstack.dev/pricing
- [R26] Colima README / licence: https://github.com/abiosoft/colima
- [R27] CLI Docker integration source: https://github.com/supabase/cli/tree/develop/apps/cli/src/command-internal
- [R28] Billing FAQ (fair use, grace period): https://supabase.com/docs/guides/platform/billing-faq
- [R29] `supabase/setup-cli` README (v3.2.0, 2026-11-02): https://github.com/supabase/setup-cli
- [R30] `supabase db push` reference: https://supabase.com/docs/reference/cli/supabase-db-push ; `--help` (CLI 3.1.0)
- [R31] Generating TypeScript types: https://supabase.com/docs/guides/api/rest/generating-types
- [R32] `supabase test db` reference: https://supabase.com/docs/reference/cli/supabase-test-db
- [R33] pgTAP extension: https://supabase.com/docs/guides/database/extensions/pgtap
- [S3] (from managed-backend.md) Edge Function limits: https://supabase.com/docs/guides/functions/limits
- **[spike]**: run on the dev Mac on 2026-11-09 in a scratch project (`project_id = "wearai-spike"`, ports 553xx) with `npx supabase@3.1.0`: `init`, `db start`, `migration up`, `test db`, `gen types`, `stop --no-backup`. The pulled images were then removed. `docker info`, `docker stats` and `docker images` were read for the existing stack.
