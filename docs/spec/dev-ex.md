# Dev-ex

How WearAI is set up, run, tested and shipped. Every part costs $0. The one exception is the 30-image Nano Banana budget from [What may the MVP spend, and how is it held there?](https://github.com/suyashpatel98/WearAI/issues/39). This spec is charted on [Wayfinder: WearAI dev-ex (environments, tests, CI/CD) at $0](https://github.com/suyashpatel98/WearAI/issues/42).

## Environments

Decided in [Which environments exist, and what does each one call?](https://github.com/suyashpatel98/WearAI/issues/46).

There are exactly two environments, **`local`** and **`hosted`**. These names are used in commands, env file names, docs and the app's badge. Don't say "dev", "prod" or "staging": no environment has real users other than the developer.

| | `local` | `hosted` |
|---|---|---|
| What it is | The Supabase CLI stack in Docker on the developer's Mac | One Supabase Free project, `wearai`, in Mumbai |
| Used for | Day-to-day development, tests, agents | The real app on the OnePlus 7T: Google sign-in, real images, the developer's real Wardrobe |
| Gemini 3.8 Flash | Real calls, free-tier key | Real calls, same free-tier key |
| SAM 3 (Roboflow) | Real calls, free-tier key | Real calls, same free-tier key |
| Nano Banana 2.1 | **Never.** Uses the fake image provider | Real calls, paid key |
| `image_budget.cap` | 1000 (raised by `seed.sql`) | 30 (from the migration) |

Automated tests are separate from both columns and never call a model. See [Tests](#tests).

The second Supabase Free project slot stays unused. There's no hosted dev project.

### Local stack

- `supabase/config.toml` sets `project_id = "wearai"` and keeps the **default ports** (54321–54327). No other Supabase stack runs on the dev Mac.
- Local Auth uses Google sign-in with the same client IDs as hosted. Agents and tests use a seeded email/password User, with OTP mail caught by Mailpit.

### Models and keys

- **Two Google Cloud projects**, because once a project has billing linked, Google charges for every Gemini API call it makes, Flash included:
  - **`wearai-free`**: billing is never linked. Holds the Gemini Flash key, used by `local` and `hosted`.
  - **`wearai-images`**: billing linked, with the $2 budget alert and an AI Studio project spend cap. Holds only the Nano Banana key, which exists only in `hosted`'s function secrets.
- The image call is chosen by an explicit setting, `IMAGE_PROVIDER=fake|nano-banana`:
  - `fake` returns a fixed placeholder JPEG with no network call. It is the only value `local` ever uses. There is no flag to spend real images locally. To get a real image, use `hosted`.
  - `nano-banana` fails loudly if its key is missing. A missing key never falls back to `fake`.
- Every image request reserves an `image_budget` slot first, in both environments, and the provider is called only after the reservation. So the "Image budget used up" paths can be tried locally by editing the one row.
- Where each key is stored and how it reaches each environment: see [Secrets](#secrets).

### Which environment the app talks to

- **Development build + Metro:** `APP_ENV=local|hosted` picks `.env.local` or `.env.hosted`, and `local` is the default. Metro reads `EXPO_PUBLIC_SUPABASE_URL` when it starts, so switching environments means restarting Metro, not rebuilding. The phone reaches the Mac's stack through `adb reverse`.
- **Standalone APK** (built by `apk:hosted`, see [Deploys](#deploys)): always `hosted`, set at build time.
- The app shows a small **`LOCAL`** badge whenever it points at `local`.
- If Google sign-in fails against `local` on the phone, add a sign-in by email that exists only in `__DEV__` bundles. Don't build it until it's needed.

### Guard rails

- Every command targets `local` unless its name ends in `:hosted` (e.g. `deploy:hosted`). See [Command surface](#command-surface).
- Each `hosted` command first prints the project ref and what it will change. Run interactively, it asks for confirmation. CI passes `--yes` itself.
- **Agents never run commands that change `hosted`**: migrations, function deploys, or setting secrets. `AGENTS.md` says so. Agents may run read-only `hosted` commands, such as reading function logs. This backs up the Supabase CLI v3 default, which only reaches `hosted` with `--remote --yes`.

## Repo layout and toolchain

Decided in [What are the repo layout and toolchain?](https://github.com/suyashpatel98/WearAI/issues/47).

### Layout

One package at the repo root, with no workspaces. A second package earns workspaces only when a second JS app or a published package exists, and neither does.

```
/
├── package.json            # the Expo app; "packageManager" pins pnpm
├── pnpm-lock.yaml          # also pins the Supabase CLI (a devDependency)
├── mise.toml               # pins Node, pnpm, Deno, JDK
├── tsconfig.json           # extends expo/tsconfig.base; excludes supabase/functions
├── src/app/                # Expo Router routes (Expo's default template layout)
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   ├── seed.sql
│   ├── tests/              # pgTAP, run by `supabase test db`
│   └── functions/
│       ├── _shared/
│       │   └── database.types.ts   # generated, the only copy of the DB types
│       └── <name>/
│           ├── index.ts
│           ├── index.test.ts       # `deno test`, beside the function
│           └── deno.json           # one per function
├── .vscode/                # settings.json + extensions.json, committed
├── docs/
├── AGENTS.md
└── GLOSSARY.md
```

- **DB types** are generated by `supabase gen types` into `supabase/functions/_shared/database.types.ts`. Edge Functions import that file by relative path, and the app imports it through a `@/db` path alias. Metro can reach it because the app and `supabase/` share one root. It's the only copy, and nothing is synced.
- **Each Edge Function has its own `deno.json`**, as Supabase documents. Shared code lives in `supabase/functions/_shared/`.

### Tool versions

| Tool | Version | Installed by |
|---|---|---|
| Node | 24 (LTS) | mise |
| pnpm | pinned | mise, and `packageManager` in `package.json` |
| Deno | 2 | mise (needed for `deno test`, `deno check`, `deno lint`; `functions serve` doesn't need it) |
| JDK | Zulu 17 | mise (`java = "zulu-17"`), replacing the Oracle 17.0.1 install |
| Supabase CLI | v3.x | pnpm devDependency, pinned by `pnpm-lock.yaml`. Always run it as `pnpm supabase …` |
| Android SDK | fixed `sdkmanager` package list | Homebrew casks `android-commandlinetools` and `android-platform-tools`, then `sdkmanager` from the setup command |
| Docker runtime | Colima | Homebrew (`colima`, `docker`) |

- **mise** is the single source of truth for Node, pnpm, Deno and the JDK. The laptop runs `mise install`, and CI installs the same versions with `jdx/mise-action`. There's no `.nvmrc` and no corepack.
- **One Supabase CLI.** The globally installed 2.106 is uninstalled, so a bare `supabase` can't silently run an old CLI with different local/hosted defaults.
- **Colima, not OrbStack or Docker Desktop.** Colima is MIT-licensed, so it stays free however WearAI is used. OrbStack is free only for personal, non-commercial use. Colima's VM size is set in the command (`colima start --cpu 4 --memory 6`), so the setup command can start it without opening a GUI. Docker Desktop 20.10 is uninstalled, leaving exactly one Docker context.
- **pnpm** uses its default isolated linker. Add `node-linker=hoisted` to `.npmrc` only if native autolinking breaks.

### TypeScript, lint and format

- **App:** `strict: true` and `noUncheckedIndexedAccess`, on top of `expo/tsconfig.base`. The app's `tsconfig.json` excludes `supabase/functions/`, which uses Deno's `npm:`/`jsr:` imports.
- **Edge Functions:** checked with `deno check` (Deno's defaults are strict) and linted with `deno lint`.
- **Lint:** `expo lint` (ESLint with Expo's config) for the app, and `deno lint` for the functions. No Biome.
- **Format:** Prettier, with its defaults, for every TS/JS/JSON/Markdown file, functions included, so the repo has one style. `deno fmt` isn't used, and SQL isn't formatted.
- **Editor:** the committed `.vscode/settings.json` enables the Deno extension only for `supabase/functions` (`deno.enablePaths`) and makes Prettier the default formatter with format on save. `.vscode/extensions.json` recommends the Deno, ESLint and Prettier extensions.

## Command surface

Decided in [What is the single command surface?](https://github.com/suyashpatel98/WearAI/issues/48).

The developer, agents and CI share one set of commands: **mise tasks**, run as `mise run <task>`. `mise tasks` lists them with their descriptions and is the source of truth for the list. `mise run` uses the versions pinned in `mise.toml`, even in a shell where mise isn't activated, which is the kind of shell agents and CI use. One-line tasks live inline in `mise.toml`, and multi-step ones are file tasks in `mise-tasks/`. `package.json` scripts are never a second command surface.

### Names

- Names follow `area:verb` (`db:reset`, `test:db`), so `mise tasks` groups them by area.
- **Every command targets `local` unless its name ends in `:hosted`.** No other command reaches hosted.

### Commands

| Command | Does |
|---|---|
| `setup` | Bootstraps or repairs the machine. See [setup](#setup) |
| `up` / `down` | Start or stop Colima and the local Supabase stack |
| `dev` | Starts Metro with `APP_ENV=local`, then runs `adb reverse` for the stack's ports |
| `dev:hosted` | Starts Metro with `APP_ENV=hosted`. It only reads hosted, but it carries the suffix so the naming rule has no exceptions |
| `android` | Runs `expo run:android`: builds the development build and installs it on the connected phone. If `adb devices` shows nothing, it fails with steps to enable USB debugging |
| `check` | Fast and needs no Docker: typechecks the app (`tsc --noEmit`), runs `deno check`, `expo lint`, `deno lint` and `prettier --check` |
| `fix` | Runs `prettier --write` and `expo lint --fix` |
| `test` | Runs everything: `check`, `test:db`, `test:functions`, `expo export --platform android` and `expo install --check` |
| `test:db` | pgTAP through `supabase test db` against local. Starts the database first (`supabase db start`) if it isn't running |
| `test:functions` | `deno test --allow-net=127.0.0.1` on the Edge Function handlers. There are none yet, so it passes trivially |
| `db:new <name>` | `supabase migration new <name>` |
| `db:reset` | Rebuilds local from the migrations and the seed, then runs `db:types`. It's the only way to apply migrations locally |
| `db:types` | Regenerates `supabase/functions/_shared/database.types.ts` from local |
| `deploy:hosted` | Restores hosted if it's paused, then runs `db push` and `functions deploy`. CI runs it on merge, and a human can run it as an escape hatch. See [Deploys](#deploys) |
| `apk:hosted` | Human only. Builds the release APK (always hosted) on the laptop from clean `main`, signs it and runs `adb install -r` onto the phone. See [Deploys](#deploys) |
| `logs:hosted` | Reads Edge Function logs. Read-only |
| `secrets:hosted` | Human only. Prompts for each hosted function secret with hidden input and runs `supabase secrets set`. See [Secrets](#secrets) |

Not commands:
- `lint` and `typecheck`: `check` covers both.
- `db:migrate`: use `db:reset`.
- CI steps: CI runs `mise run test` and nothing else. See [CI and `main`](#ci-and-main).

### Which environment a command targets

Every command that talks to Supabase prints one line before it does anything, such as `▸ local  http://127.0.0.1:54321` or `▸ hosted  wearai (ref …)`. `:hosted` commands that change hosted then print their plan and ask for confirmation, as set out in [Guard rails](#guard-rails). Commands that only touch files (`check`, `fix`, `db:new`) print no banner.

### `setup`

On a fresh Mac with Homebrew, the only manual line is:

```sh
brew install mise && mise trust && mise run setup
```

`setup` runs these steps in order. Each step can be re-run, so `setup` also repairs a broken machine:

1. Checks for Homebrew. If it's missing, it exits with the install URL.
2. `brew install colima docker android-commandlinetools android-platform-tools`.
3. `mise install`, then `pnpm install`.
4. Accepts the Android SDK licences and installs the fixed `sdkmanager` package list.
5. Copies `supabase/functions/.env.example` to `supabase/functions/.env` if that file is missing. It never overwrites one. You then fill in the two free keys.
6. `up`, then `db:reset`.

It **doesn't**:
- Uninstall anything. If it finds Docker Desktop or a global `supabase`, it prints the exact command to remove it and carries on.
- Touch hosted, secrets or Google Cloud.
- Set up the phone.

If a step fails, `setup` stops with the step's name and the command to run by hand.

### `AGENTS.md`

`AGENTS.md` gets a short **Commands** section, and the task descriptions carry the rest, so the list lives in one place:

- Run commands with `mise run <task>`. `mise tasks` lists them all.
- The four to know: `setup`, `check`, `test`, `db:reset`.
- **Never run a `:hosted` task except `logs:hosted`.**
- **Never print, commit or paste the contents of `supabase/functions/.env`.**
- **Open PRs, but never merge them.** The developer merges.
- **A migration that drops or rewrites data says so in the PR title.**
- How to test: run `check` while iterating, `test` before opening a PR, and `test:db` after any change to a migration or policy.

## Tests

Decided in [What do the minimal tests cover, and how are model calls kept out?](https://github.com/suyashpatel98/WearAI/issues/49).

The only User is the developer, and the goal is an app that can be tried on the phone. So the automated tests guard just two things: **an app that won't build** and **an image budget that fails open**. Everything else is checked by using the app.

### What's automated

| Guards against | Check | Command |
|---|---|---|
| Type errors, lint errors, functions that don't typecheck | `tsc --noEmit`, `expo lint`, `deno check`, `deno lint`, `prettier --check` | `check` |
| An app that won't bundle | `expo export --platform android` | `test` |
| Packages that don't match the Expo SDK | `expo install --check` | `test` |
| An image budget that fails open | **One pgTAP test.** In its rolled-back transaction it sets `used = cap - 1`. The first reservation (`update image_budget set used = used + 1 where used < cap returning used`) returns a row. The second returns none and leaves `used` unchanged | `test:db` |

### Not automated, on purpose

- **RLS and Storage leak tests.** Only one User exists. They're out of scope for this effort and must be written before a second person signs in.
- **Edge Function tests.** There are none for now. `check` still typechecks and lints every function.
- **An Android end-to-end test (Maestro on an emulator).** Installing each build on the OnePlus 7T is the smoke test. Revisit only if start-up crashes reach the phone that `expo export` didn't catch.
- **Feed limits, Style Me limits, Stylist rotation, UI logic.** These are product behaviour, not serious mistakes. No `jest-expo`.

### No model calls in tests

No automated test calls a real model: not Nano Banana, and not the free Gemini Flash or SAM either. Real calls are slow, give different answers each run, and use up free quota. Real Flash and SAM calls only happen when the developer uses the app against `local` or `hosted`.

When the first Edge Function test is written, it must:

- run with no model keys (`test:functions` loads no env file, and CI has no model keys),
- run under `deno test --allow-net=127.0.0.1`, so a real call fails with a permission error,
- stub `fetch` so it throws on any URL the test didn't expect.

### Phone checklist for a hosted APK

Before trusting a new standalone APK:

1. The app launches, and there's **no `LOCAL` badge**.
2. Google sign-in works.
3. The Wardrobe loads with its existing Items.
4. One Upload reaches `in_review` with Items detected. Flash and SAM are free.
5. The existing Feed and its Posts load.

**Don't press Generate Feed (3 images) or Style Me (1 image) as a routine check.** Each spends part of the 30-image budget. Try those flows on `local`, where the image provider is `fake`. Press them on `hosted` only when the build changed the image path.

## Secrets

Decided in [Where do secrets live, and how do they flow in a public repo?](https://github.com/suyashpatel98/WearAI/issues/50).

The repo is public, so anything committed is public. Each value is either **public by design**, in which case it's committed and may ship in the APK, or **server-only**, in which case it never enters the repo or the app.

### Inventory

| Value | Kind | Lives in |
|---|---|---|
| Supabase URL and publishable key, `local` | Public | `.env.local` (committed) |
| Supabase URL and publishable key, `hosted` | Public | `.env.hosted` (committed) |
| Google OAuth client IDs (Web, Android) | Public | `supabase/config.toml` and the app config (committed) |
| Hosted project ref | Public | Committed wherever commands need it |
| Gemini Flash key (`wearai-free`) | Server-only | `supabase/functions/.env` locally, and hosted function secrets |
| Roboflow key | Server-only | `supabase/functions/.env` locally, and hosted function secrets |
| Nano Banana key (`wearai-images`) | Server-only | **Hosted function secrets only** |
| Supabase secret key | Server-only | Injected into Edge Functions by Supabase. We never store it |
| Supabase access token (scoped) | Server-only | GitHub environment `hosted` |
| Android release keystore and password | Server-only | `~/.config/wearai/` on the laptop only (the APK is built there) |

Not needed:
- **Google OAuth client secret.** Native Google Sign-In passes an ID token to Supabase, and that flow has no secret. If Supabase turns out to demand one, it goes in the GitHub environment `hosted`.
- **DB password.** It's needed only if the scoped access token turns out not to be enough for `db push`. That's checked in [How do changes reach hosted Supabase and the phone?](https://github.com/suyashpatel98/WearAI/issues/52).

### App env files: committed

`.env.local` and `.env.hosted` are committed and hold **only `EXPO_PUBLIC_*` values**. They need no template and no copy step, and a CI build can read `.env.hosted` directly. A secret never goes in them.

### Local function secrets: `supabase/functions/.env`

The file is gitignored. A committed `supabase/functions/.env.example` lists its variables, and `setup` copies it once:

```sh
GEMINI_API_KEY=        # wearai-free, no billing
ROBOFLOW_API_KEY=
IMAGE_PROVIDER=fake
```

The local stack loads this file automatically. The Nano Banana key never goes in it.

### Hosted function secrets: `secrets:hosted`

The human-only `secrets:hosted` task prompts, with hidden input, for `GEMINI_API_KEY`, `ROBOFLOW_API_KEY` and `NANO_BANANA_API_KEY`. It sets `IMAGE_PROVIDER=nano-banana`, then runs `supabase secrets set`.

**No copy is kept**: not in a file, not in GitHub, not in a password manager. If a key is lost, mint a new one and run the task again. So the paid key never sits on disk where an agent could read it, and CI never holds it. Deploys don't touch function secrets.

### GitHub: one environment, `hosted`

All CI secrets live in a GitHub **environment** named `hosted`, whose deployment-branch rule allows only `main`. PR and branch runs can't read them, and fork runs never get secrets at all. It holds:

- `SUPABASE_ACCESS_TOKEN`: a scoped token with only the permissions the deploy needs.
- `SUPABASE_DB_PASSWORD`: only if `db push` turns out to need it beyond the scoped token.

The keystore isn't in GitHub, because the APK is built on the laptop.

Set them from the terminal with `gh secret set --env hosted <NAME>`.

### Android release keystore

The keystore lives outside the repo at `~/.config/wearai/release.jks`. Its single password (the same for the store and the key) is in `~/.config/wearai/keystore.properties` beside it. `.gitignore` also blocks `*.jks` and `*.keystore`. There's no other backup. Losing the keystore costs one uninstall and reinstall on the phone, plus registering the new SHA-1 with the Android OAuth client. The data lives in Supabase, so none of it is lost.

### Hosted sign-ups are closed

Because the hosted URL and publishable key are public, **hosted refuses new sign-ups** (`enable_signup = false`) once the developer's Google account exists. Otherwise anyone could sign in and spend the image budget. It applies to hosted only, so local can still create Users. The exact mechanism, a hosted-only config override or the Management API, is checked when it's built.

### If a secret leaks

GitHub push protection already blocks pushes that contain Google API keys or Supabase secret keys. Roboflow keys may not be covered. After a leak:

1. Revoke the key at its provider.
2. Mint a new one.
3. Set it again with `secrets:hosted` or `gh secret set --env hosted …`. If it's used locally, update `supabase/functions/.env` too.
4. For a Nano Banana key, also check `wearai-images`' spend in AI Studio.

## CI and `main`

Decided in [What runs in CI on a PR, and what protects main?](https://github.com/suyashpatel98/WearAI/issues/51).

### The `ci` workflow

One workflow with one job, `ci`. It runs on every pull request and every push to `main`, docs-only changes included:

```yaml
- uses: actions/checkout@v4
- uses: jdx/mise-action@v2        # installs and caches the tools pinned in mise.toml
- uses: actions/cache@v4          # pnpm store, keyed on pnpm-lock.yaml
- run: pnpm install --frozen-lockfile
- run: mise run test
```

- **`mise run test` is the only check step.** It covers `check`, `expo export`, `expo install --check` and the pgTAP budget test. `test:db` starts the database itself, so the step is identical on the laptop.
- `ubuntu-latest` (free and unlimited on a public repo), `timeout-minutes: 15`, and `concurrency` set so that a new push cancels the PR's previous run. Expect 3–5 minutes, mostly Supabase pulling its images.
- **Docs-only PRs aren't skipped.** A `paths-ignore` filter would leave the required check "pending" forever, so the PR could never merge.
- **Not cached:** Docker images, because restoring them is no faster than pulling, and Gradle, because PR CI never runs it.
- **Not run on PRs:** Android builds and end-to-end tests. APK builds are decided in [How do changes reach hosted Supabase and the phone?](https://github.com/suyashpatel98/WearAI/issues/52).
- The job uses no secrets and never references the `hosted` environment.

### Reproducing a failure

Run `mise run test` locally. CI does nothing else, and the tests need neither `supabase/functions/.env` nor any key. A failure that only happens in CI is a bug in the task, fixed in the task, never worked around in the YAML.

### Protecting `main`

A repository **ruleset** on `main`, created with `gh api`, so no dashboard is needed:

- Changes arrive only by pull request, with **0 required approvals**, because GitHub won't let the developer approve their own PR.
- The **`ci` check must pass** before merging.
- Force pushes and branch deletion are blocked.
- **No bypass**, not even for the admin. Every change, including a typo fix, waits for `ci`.

Repository settings:
- **Squash merge only**, titled after the PR, so `main` gets one commit per PR.
- Branches are deleted automatically on merge.

Agents' PRs face the same ruleset. **Agents open PRs but never merge them**, and `AGENTS.md` says so.

### No git hooks

There are no pre-commit or pre-push hooks. The required `ci` check already guards `main`, hooks would slow every commit, and agents often skip them with `--no-verify`. `AGENTS.md` tells agents to run `check` while iterating and `test` before opening a PR.

## Deploys

Decided in [How do changes reach hosted Supabase and the phone?](https://github.com/suyashpatel98/WearAI/issues/52).

### Backend: deployed automatically on merge

A `deploy` workflow runs on every push to `main` that touches `supabase/**`, after `ci` passes. It runs in the GitHub environment `hosted` and calls `mise run deploy:hosted` with `SUPABASE_YES=1`. It isn't a required check, so the path filter is safe. The task:

1. Prints the `▸ hosted` banner.
2. Restores the project through the Management API if it's paused.
3. Runs `supabase link`, then `db push --remote --yes` and `functions deploy --use-api --yes`. `functions deploy` bundles on Supabase's servers, so no Docker is needed.

So hosted always matches `main`. Deploys **never set function secrets**; `secrets:hosted` does that (see [Secrets](#secrets)). A human may run `deploy:hosted` from the laptop as an escape hatch, after the confirmation prompt. Agents never do.

To check when it's built:
- whether `db push --remote` works with only the scoped token, and if not, add `SUPABASE_DB_PASSWORD`;
- which mechanism closes hosted sign-ups.

### Destructive migrations

There's no automated guard. Hosted holds only the developer's own data, and every migration reaches `main` through a PR the developer merges. A migration that drops or rewrites data says so in its PR title. This rule is in `AGENTS.md`.

### Keeping hosted awake

A scheduled `keep-alive` workflow runs once a day and sends one cheap read to hosted's REST API with the publishable key. It needs no secret. That's enough database activity to stop the Free project pausing after a week of no use. GitHub turns off scheduled workflows after 60 days without repo activity, and the deploy's restore step covers that case.

### App: the hosted APK is built on the laptop

`apk:hosted` (human only) builds the standalone APK and installs it:

1. **It refuses to build** unless the working tree is clean and `HEAD` is a commit on `origin/main`. So the APK always matches what hosted runs.
2. `APP_VARIANT=release APP_ENV=hosted expo prebuild --platform android`, then `./gradlew :app:assembleRelease -PreactNativeArchitectures=arm64-v8a`, signed with `~/.config/wearai/release.jks`.
3. `adb install -r` onto the connected OnePlus 7T.

The first build may take 10+ minutes, and Gradle's cache makes later ones faster. If laptop builds get painful, the fallbacks are a manually triggered CI build attached to a GitHub Release, which would need the keystore in the `hosted` environment, then EAS Build Free (15 builds a month).

### Two app variants side by side

| | Development build | Hosted APK |
|---|---|---|
| Package | `app.wearai.dev` | `app.wearai` |
| Name on the phone | WearAI Dev | WearAI |
| Built by | `android` (`expo run:android`) | `apk:hosted` |
| Signed with | The debug keystore | `~/.config/wearai/release.jks` |
| JS from | Metro (`dev` or `dev:hosted`) | The bundle built into the APK |
| Talks to | `local` by default | Always `hosted` |

`app.config.ts` picks the package and name from `APP_VARIANT`. Each variant has its own Android OAuth client in Google Cloud (package plus SHA-1).

### No over-the-air updates

No `expo-updates` and no EAS Update. JS changes reach the development build through Metro, and the hosted APK changes only when it's rebuilt.

### Versioning and rollback

- `versionCode` = `git rev-list --count HEAD`, so it always goes up.
- `versionName` = `0.1.<count>`. The short commit SHA appears on the app's profile screen.
- **Rollback means reverting the PR on `main`.** The `deploy` workflow redeploys the functions. A migration is never reversed in place: a new migration undoes it. Then run `apk:hosted` from the revert commit. Never install an older build, because Android refuses a lower `versionCode`.

## Dependency updates

Decided in [How are dependencies kept current, and do updates auto-merge?](https://github.com/suyashpatel98/WearAI/issues/58).

### Dependabot, configured by one file

**Dependabot** opens the update PRs. It's built into GitHub, and the committed `.github/dependabot.yml` turns it on, so no dashboard or third-party app is needed. Renovate also covers `mise.toml`, but its hosted app has to be installed by clicking through a browser and gets write access to the repo. Running Renovate ourselves would need a personal access token, because PRs opened with the workflow token don't start CI.

| What | Covered by |
|---|---|
| npm packages in `package.json`, including the Supabase CLI devDependency (`pnpm-lock.yaml` is updated too) | Dependabot `npm` |
| Each Edge Function's `deno.json` (`/supabase/functions/*`) | Dependabot `deno` |
| Actions in `.github/workflows/` | Dependabot `github-actions` |
| Packages that the Expo SDK pins | By hand, in an SDK upgrade (below) |
| `mise.toml` (Node, pnpm, Deno, JDK) and `packageManager` in `package.json` | By hand |

### Schedule and grouping

- Runs **monthly**.
- Each ecosystem gets **one grouped PR for its minor and patch updates**, so there are at most three a month.
- **Major updates arrive as separate PRs**, so one breaking major can't turn the whole group red.

### Expo SDK packages are ignored

Dependabot ignores `expo`, `expo-*`, `@expo/*`, `react`, `react-dom`, `react-native`, `react-native-*` and `@react-native/*`. The Expo SDK fixes their versions, and a lone bump of one would fail `expo install --check` in CI. The ignore list applies to security updates too.

**An Expo SDK upgrade** is a deliberate PR, made by the developer or an agent:

1. `pnpm expo install expo@^<N>`
2. `pnpm expo install --fix`
3. If the new SDK needs a newer Node, bump it in `mise.toml`, and bump pnpm (in `mise.toml` and `packageManager`) at the same time.
4. `mise run test`, then the phone checklist in [Tests](#tests) on a fresh `apk:hosted`.

Do one when a new SDK ships or a vulnerable Expo package needs it. There's no mise task for it.

### No auto-merge

**Nothing merges itself.** The developer reads each Dependabot PR and merges it once `ci` passes, which is the same rule as for agents' PRs. There are three reasons:

- The tests only prove that the app builds and bundles, not that it works.
- Merging a `deno.json` bump deploys to hosted.
- An auto-merge done with the workflow token doesn't start other workflows. The `deploy` workflow wouldn't run, and hosted would quietly fall behind `main`.

Dependabot PRs run `ci` like any other PR. `ci` needs no secrets, so Dependabot's restricted token doesn't matter.

### Security alerts and fixes

**Dependabot alerts** and **Dependabot security updates** are both on. They're enabled with `gh api` (`PUT repos/{owner}/{repo}/vulnerability-alerts` and `PUT …/automated-security-fixes`), so no dashboard is needed. Security-fix PRs don't wait for the monthly run. Each ecosystem's security fixes are grouped into one PR, and the developer still merges it.

### Sketch of `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule: { interval: monthly }
    ignore:
      - dependency-name: "expo"
      - dependency-name: "expo-*"
      - dependency-name: "@expo/*"
      - dependency-name: "react"
      - dependency-name: "react-dom"
      - dependency-name: "react-native"
      - dependency-name: "react-native-*"
      - dependency-name: "@react-native/*"
    groups:
      npm:
        patterns: ["*"]
        update-types: [minor, patch]
      npm-security:
        applies-to: security-updates
        patterns: ["*"]
  - package-ecosystem: deno
    directories: ["/supabase/functions/*"]
    schedule: { interval: monthly }
    groups:
      deno:
        patterns: ["*"]
        update-types: [minor, patch]
      deno-security:
        applies-to: security-updates
        patterns: ["*"]
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: monthly }
    groups:
      actions:
        patterns: ["*"]
        update-types: [minor, patch]
```

To check when it's built:
- whether Dependabot's `deno` ecosystem reads a `deno.json` that sits next to `_shared/` without its own lockfile;
- whether Dependabot handles the pnpm version that `mise.toml` pins.

## Reference data and seed

Decided in [How does hosted get its reference data and first Wardrobe?](https://github.com/suyashpatel98/WearAI/issues/64).

`db push` applies migrations to hosted but never runs `seed.sql`. So everything the app needs to work goes in a **migration**, and `seed.sql` holds only conveniences for local. `deploy:hosted` never passes `--include-seed`.

| What | Where it comes from | `local` | `hosted` |
|---|---|---|---|
| The 68 `categories` and 10 `stylists` (with briefs) | One data migration | `db:reset` | First merge, through `deploy` |
| `image_budget` row | The same migration, `used = 0, cap = 30` | `seed.sql` raises `cap` to 1000 | Stays 30 |
| Stylist sample images | App assets in `assets/stylists/` | Bundled | Bundled |
| The developer's User, Style Profile and Wardrobe | Signing in and using the app | Google sign-in, or the seed User below | Google sign-in on the hosted APK, then sign-ups close |
| Agent/test User | `seed.sql` | `agent@wearai.test`, onboarded | Never |

### Reference rows live in migrations

- The migrations are the **source of truth for the row data**. `stylists.md` and `item-attributes.md` record why it's designed that way.
- Changing a brief, label or category is a new migration with `insert … on conflict (id) do update`. A row is removed by a migration too.
- There's no `seed:hosted` task.

### The image budget

- The migration inserts the row at **`cap = 30`**, so a fresh or broken hosted can never start with a bigger budget.
- `seed.sql` runs after the migrations on `db:reset` and sets `cap = 1000` on local.
- **Raising hosted's cap** is a migration (`update image_budget set cap = <n>`) that the developer merges. It also runs locally, but the seed runs after it, so local stays at 1000.

### Stylist sample images are app assets

The 20 images live at `assets/stylists/<stylist_id>-menswear.jpg` and `assets/stylists/<stylist_id>-womenswear.jpg`, about 2 MB in the APK. The app maps each Stylist id to its two files. There's no `stylists` bucket and there are no path columns, so nothing has to be uploaded to hosted. Changing an image means shipping a new APK.

The developer makes them **by hand in the free Gemini app**, never with the paid key, so they don't count against `image_budget`. Until they exist, each file is a plain tile with the Stylist's name, so the picker works from day one. Swapping in the real images is a one-PR change.

### Hosted: everything else comes through the app

On a fresh hosted project, the developer:
1. installs the hosted APK and signs in with Google;
2. onboards (Style Profile, reference photos, Stylists);
3. photographs their clothes to build the Wardrobe (Flash and SAM are free).

Then hosted sign-ups close (see [Secrets](#secrets)). Nothing is copied from local.

### The local seed

`seed.sql` adds:
- One email/password User, **`agent@wearai.test`**, with a committed password. It exists only on local, so it doesn't matter that the password is public.
- A finished `profiles` row and one active Stylist, so agents and the developer land past onboarding.
- `cap = 1000` on `image_budget`.

There's **no sample Wardrobe and no fixture photos**. Items come from uploading through the app on local, which makes real free Flash and SAM calls. To test onboarding, sign up a new email User on local, where sign-ups stay open. The pgTAP budget test needs no Items.
