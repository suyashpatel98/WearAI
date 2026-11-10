# Which free test tools fit each layer of WearAI?

Research for [#45](https://github.com/suyashpatel98/WearAI/issues/45), part of the dev-ex map [#42](https://github.com/suyashpatel98/WearAI/issues/42). Sources were read on **2026-11-09**. Timings marked "measured" come from the public GitHub Actions run logs of the tool's own repository (read through the GitHub API), not from a vendor claim.

The tests are minimal by design: they exist only to stop an RLS leak, spent Nano Banana images, a broken deploy or an app that won't start. There is no coverage target. Every tool below is free and open source. The repo is public, so standard GitHub-hosted runners cost nothing.

## Answer

| Layer | Recommended tool | Runs where | Cost |
|---|---|---|---|
| Database (RLS, Storage policies, `image_budget`) | **pgTAP via `supabase test db`**, after `supabase db start` | `ubuntu-latest` and the laptop (Docker) | $0 |
| Edge Functions (Deno) | **`deno test`** on the exported handler, with `globalThis.fetch` stubbed by `@std/testing/mock`, and network permission limited to localhost | `ubuntu-latest` (setup-deno) and the laptop | $0 |
| App (Expo, TypeScript) | **`tsc --noEmit` + `npx expo lint` + `npx expo export --platform android`**. Skip `jest-expo` until there is logic worth unit testing | `ubuntu-latest` | $0 |
| Android end-to-end | **Not in the default CI.** If wanted, the Maestro CLI on `reactivecircus/android-emulator-runner`, in a manual or nightly workflow. Never Maestro Cloud or EAS Workflows Maestro jobs | `ubuntu-latest` with KVM | $0 (both paid options are excluded) |
| Image-spend guard | **No Nano Banana key anywhere tests run**, plus `deno test --allow-net=127.0.0.1` so any real model call throws, plus a test seed with `image_budget.cap = 0` | everywhere | $0 |

That is four tools on top of what the project already has: the Supabase CLI (with its bundled pgTAP), Deno, TypeScript/ESLint through Expo, and, only if e2e is wanted, Maestro.

Key numbers:

- **`supabase start` on `ubuntu-latest` (cold, all images pulled): 72–74 s with the latest CLI, up to ~155 s with older CLIs** (measured, below). `supabase db start` pulls fewer images, so it should be no slower.
- **Android emulator on `ubuntu-latest` with KVM: ~92 s to download the system image, create the AVD, cold-boot and save a snapshot. A later boot from that snapshot plus a short test run took ~45 s** (measured, below). Building the release APK first is the larger cost. I found no primary timing for it.
- **Maestro Cloud costs $250 per device per month. EAS Workflows Maestro jobs are not on Expo's Free plan.** Both are out.

## Database: pgTAP via `supabase test db`

**What it is.** The Supabase CLI runs every `.sql` file under `supabase/tests/` with pgTAP as the runner ([Supabase: Testing your database](https://supabase.com/docs/guides/database/testing)). Each file wraps its work in a transaction and rolls back, so test data never persists.

**RLS tests.** Supabase's RLS testing guide has each assertion run as a real role: `set local role authenticated;` plus `set local request.jwt.claim.sub = '<uuid>';`. It checks visibility with `results_eq` and blocked writes with `is_empty`. For each User-owned table, it confirms that a second user can't read, update or delete the first user's rows ([Supabase: Test RLS policies with pgTAP](https://supabase.com/docs/guides/database/postgres/testing-row-level-security)). It also recommends checking each test once by adding a temporary `using (true)` policy and watching the test fail.

Optional helpers: `basejump-supabase_test_helpers` adds `tests.create_supabase_user()`, `tests.authenticate_as()`, `tests.authenticate_as_service_role()` and `tests.rls_enabled('public')` ([Supabase: Advanced pgTAP testing](https://supabase.com/docs/guides/local-development/testing/pgtap-extended); [source](https://github.com/usebasejump/supabase-test-helpers)). It is a community package, installed through dbdev, which needs `pg_tle` and `pgsql-http` and fetches SQL from a remote registry. For a minimal suite, the two `set local` lines are enough and add no dependency. `tests.rls_enabled('public')` is the one helper worth copying by hand: it is a single assertion that fails if any new table ships without RLS. A plain query on `pg_class.relrowsecurity` does the same.

**What to cover for WearAI** (from [`docs/spec/data-model.md`](../spec/data-model.md)):

1. RLS is on for every table in `public`.
2. For each User-owned table, User B can't select User A's rows. For the tables the client writes (`profiles`, `reference_photos`, `user_stylists`, …), User B can't update or delete them either.
3. `image_budget`: `authenticated` and `anon` can't select or update it ("no client access").
4. `image_budget`: with `used = cap - 1`, the reserve statement `update image_budget set used = used + 1 where used < cap returning used` returns one row, then none. A second reserve at the cap leaves `used` unchanged. This proves fail-closed behaviour, not concurrency. The `where used < cap` row lock gives atomicity in Postgres itself, and one pgTAP session can't race itself.
5. Storage: User B can't select or insert under User A's folder (`(storage.foldername(name))[1] = auth.uid()::text`).

**Does Storage need the full stack?** No. `supabase db start` on Postgres 15 or later runs one-shot migrate jobs for realtime, storage and auth, then applies the project's migrations and seed ([Supabase CLI source: `db start` SIDE_EFFECTS.md](https://github.com/supabase/cli/blob/develop/apps/cli/src/commands/db/start/SIDE_EFFECTS.md)). So `auth.users`, `auth.uid()` and `storage.objects` all exist without starting Kong, GoTrue or the Storage API. The Postgres image alone only creates the empty `storage` schema ([supabase/postgres init scripts](https://github.com/supabase/postgres/tree/develop/migrations/db/init-scripts)). This is why the migrate jobs matter.

**CI.** Supabase's own example workflow is ([Supabase: Testing and linting in CI](https://supabase.com/docs/guides/deployment/ci/testing)):

```yaml
- uses: supabase/setup-cli@v1
  with: { version: latest }   # pin a version in practice
- run: supabase db start
- run: supabase test db
```

**How long does it take on a GitHub runner?** Supabase's docs give no figure ("The first run takes time while the CLI downloads the Docker images", [Getting started](https://supabase.com/docs/guides/local-development/cli/getting-started)). Measured figures:

- `supabase/setup-cli`'s own E2E workflow runs a cold, full `supabase start` on `ubuntu-latest`. In run [42736624239](https://github.com/supabase/setup-cli/actions/runs/42736624239) (2026-11-10 01:33 UTC) the step took **72 s (CLI `latest`, PG15), 74 s (`latest`, PG17), 97–104 s (`^2`), and 92–155 s (older 1.178.2 / 2.33.0)**.
- The CLI's concurrent-pull change ([supabase/cli#4394](https://github.com/supabase/cli/pull/4394), merged 2025-11-24) cut a cold start from ~2:43 to ~1:30 on the author's machine. The author adds that even with all images present there is "a ~30s uncompressible delay to start all the containers".
- `supabase start -x <services>` can skip containers (gotrue, realtime, storage-api, imgproxy, kong, mailpit, postgrest, postgres-meta, studio, edge-runtime, logflare, vector, supavisor) ([CLI reference](https://supabase.com/docs/reference/cli/supabase-start)). `supabase db start` has no `--exclude` and needs none.
- setup-cli's workflow reserves the local ports before starting, because "Supabase's local ports fall inside Linux's ephemeral port range, so outbound connections (like image pulls) can hold one when `supabase start` binds it" (`sudo sysctl -w net.ipv4.ip_local_reserved_ports=54320-54329`, [e2e.yml](https://github.com/supabase/setup-cli/blob/main/.github/workflows/e2e.yml)). Copy this step to avoid a rare flake.

So a database job costs roughly **1.5–2 minutes** on a free runner, and $0.

## Edge Functions: `deno test` with `fetch` stubbed

**Two options from the ticket:**

- **(a) Unit-test the handler in-process.** Export the handler from `index.ts`, call it with a `Request`, and stub `globalThis.fetch`. Supabase's own testing guide takes this route: it recommends mocking `globalThis.fetch` and notes that this "needs no changes to production code" ([Supabase: Testing Edge Functions](https://supabase.com/docs/guides/functions/unit-test)). It runs `deno test` directly (`--allow-env` for the integration test) and never mentions `supabase functions serve`.
- **(b) `deno test` against `supabase functions serve`.** This is Supabase's CI example (`supabase start` then `deno test --allow-all deno-test.ts --env-file .env.local`, [CI testing](https://supabase.com/docs/guides/deployment/ci/testing)). It needs the full stack plus the edge-runtime container, and the function runs in a separate process. A test then **can't stub its outbound `fetch`**, so a fake would have to be a local HTTP server and the function would need a configurable base URL for each model API. That costs more and opens a path to real calls.

**Recommendation: (a).** It needs no Docker, runs in seconds, and gives the test full control over every outbound call. Use (b), or a manual `supabase functions serve` plus `curl`, only to check that a function boots in the real runtime. The deploy step covers that anyway, because `supabase functions deploy` fails if the bundle doesn't build.

**How to fake Gemini Flash, Nano Banana and Roboflow.** `@std/testing/mock` provides `stub(obj, "method", impl)`, `returnsNext([...])` and `resolvesNext([...])`. Stubs are disposable, so `using` restores them automatically ([JSR: @std/testing/mock](https://jsr.io/@std/testing/doc/mock)). The docs show stubbing a plain object method. Stubbing `fetch` follows the same pattern and is what Supabase's guide does:

```ts
import { stub } from "jsr:@std/testing/mock";

Deno.test("over budget: Nano Banana is never called", async () => {
  const calls: string[] = [];
  using _fetch = stub(globalThis, "fetch", (input) => {
    const url = String(input instanceof Request ? input.url : input);
    calls.push(url);
    if (url.includes("generativelanguage.googleapis.com") && url.includes(":generateContent")) {
      return Promise.resolve(Response.json({ /* canned Gemini response */ }));
    }
    throw new Error(`unexpected fetch in test: ${url}`); // fail closed
  });
  // ... call handler with a fake budget reservation that returns no row ...
  // assert: no URL in `calls` matches the image model
});
```

This works for the official Google GenAI SDK as well as for hand-written calls, as long as the SDK uses the global `fetch`. That is an assumption to confirm when the client is written. A small `models.ts` module that wraps the three HTTP calls makes the canned responses easier to keep than URL matching in every test. The rule that matters is the final `throw`: any URL the test didn't expect fails the test.

**What to cover:** only the budget path. When the reserve returns no row, the Outfit is `over_limit` and no image request is made. The budget SQL itself is covered by pgTAP.

**CI:** `denoland/setup-deno` then `deno test`. No Supabase stack is needed.

## App: typecheck, lint and an Android bundle export

**The standard unit setup:** `npx expo install jest-expo jest @types/jest @testing-library/react-native --dev`, with `"jest": { "preset": "jest-expo" }` in `package.json` ([Expo: Unit testing](https://docs.expo.dev/develop/unit-testing/)).

**What it costs to keep working:** `jest-expo` is tied to the Expo SDK. Expo's docs warn that "In SDK 58 and later, `jest-expo` requires Jest 30", that Expo Router tests need `@testing-library/react-native` 14 or later, and that `react-test-renderer` is deprecated for React 19+. Each SDK upgrade can break the test setup even when the app is fine. Native modules (Google sign-in, image picker, Supabase storage) also need Jest mocks before a screen will render under Jest.

**Is typecheck + lint + one render test enough of a smoke test?** A render test under Jest proves only that a component renders under Jest's mocked native layer, not that the app starts. A cheaper, more useful check catches the common "app won't start" causes: a broken import, a missing module or a Metro bundling error.

- `npx tsc --noEmit`: type errors.
- `npx expo lint`: ESLint with Expo's config ([Expo CLI](https://docs.expo.dev/more/expo-cli/)).
- `npx expo export --platform android`: builds the production JS bundle for Android into `dist/` ([Expo CLI](https://docs.expo.dev/more/expo-cli/)). If Metro can't resolve or transform something, this fails. That is the same bundle a release APK ships.
- `npx expo install --check`: exits non-zero in CI when installed packages don't match the SDK ([Expo CLI](https://docs.expo.dev/more/expo-cli/)). It is cheap and catches the version drift that most often breaks a native build.

**Recommendation:** run these four commands in CI. Leave out `jest-expo` and React Native Testing Library until a piece of client logic is worth a unit test. Pure TypeScript logic can be tested then without the React Native preset. Native crashes at startup can only be caught on a device or emulator, which is what the e2e step below covers. For this MVP, the developer installing the build on their own OnePlus 7T already does that check.

## Android end-to-end smoke test (optional)

**Is it feasible for free? Yes, on `ubuntu-latest`.**

- GitHub: "Use of the standard GitHub-hosted runners is free and unlimited on public repositories". A public-repo `ubuntu-latest` runner has 4 CPUs, 16 GB RAM and a 14 GB SSD, and "GitHub-hosted Linux runners support hardware acceleration for Android SDK tools" ([GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)). A job may run for 6 hours ([Actions limits](https://docs.github.com/en/actions/reference/limits)).
- KVM has been available on standard 2-vCPU Linux runners since 2024-04-02, after a udev rule (`KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"`, then `udevadm control --reload-rules` and `udevadm trigger --name-match=kvm`) ([GitHub changelog](https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/)).
- `reactivecircus/android-emulator-runner` boots the emulator. Its README recommends Ubuntu runners as "2-3 times faster than the macOS ones" and supports AVD snapshot caching with `actions/cache` to cut startup. `emulator-boot-timeout` defaults to 600 s ([README](https://github.com/ReactiveCircus/android-emulator-runner)).
- **Maestro CLI** is Apache-2.0 and needs Java 17 or later. Install with `curl -fsSL "https://get.maestro.mobile.dev" | bash` ([repo](https://github.com/mobile-dev-inc/Maestro)). Its pricing page lists "Local: Free, Open Source — Test for free on your own devices with Maestro Studio or the CLI" ([pricing](https://maestro.dev/pricing)). On Android it supports **API 29, 30, 31, 33 and 34**, with 35 and 36 announced for Q2 2026 ([install docs](https://docs.maestro.dev/getting-started/installing-maestro)). Pick `api-level: 34`, `arch: x86_64`.

**What costs money (excluded):**

- **Maestro Cloud:** $250 per device per month ([pricing](https://maestro.dev/pricing)). The official "Maestro GitHub Action for Android" uploads to Cloud and needs `MAESTRO_API_KEY` ([docs](https://docs.maestro.dev/cloud/ci-integration/github-actions/maestro-github-action-for-android)), so don't use that action. Run `maestro test` yourself inside the emulator runner instead.
- **EAS Workflows `type: maestro` jobs** ([Expo e2e guide](https://docs.expo.dev/eas/workflows/examples/e2e-tests/)): the Free plan has 60 workflow minutes, and Maestro test jobs are not included on Free ([Expo pricing](https://expo.dev/pricing)).

**Detox instead?** Detox's Android setup edits `android/build.gradle` and `android/app/build.gradle`, adds a `DetoxTest.java` instrumentation test and a network security config, and builds a separate `assembleAndroidTest` APK. It says that "The setup for Expo projects is different and is not covered" ([Detox project setup](https://wix.github.io/Detox/docs/introduction/project-setup)). Maestro needs no app changes, just a YAML flow and an installed APK, so it is the smaller tool for one smoke flow.

**What the job would do:**

1. Build a release APK on the runner: `npx expo prebuild --platform android`, then `./gradlew assembleRelease`. The Expo template signs release builds with the debug keystore by default (`signingConfig signingConfigs.debug`, [Expo bare template](https://github.com/expo/expo/blob/main/templates/expo-template-bare-minimum/android/app/build.gradle)), so no signing secret is needed. A release build embeds the JS bundle, so no Metro server is needed. This avoids EAS Build's 15-builds-per-month Free quota ([Expo pricing](https://expo.dev/pricing)).
2. Enable KVM, then run `android-emulator-runner` with a script of `adb install app-release.apk && maestro test .maestro/smoke.yaml`.
3. The flow: `launchApp`, then `assertVisible: "Sign in with Google"`. Don't try to complete Google sign-in on the emulator.

**How long:**

- Emulator, measured in the action's own CI run [38912362990](https://github.com/ReactiveCircus/android-emulator-runner/actions/runs/38912362990) (2026-10-17, `ubuntu-latest`, API 35 `google_apis` x86_64): **92 s** for "run emulator to generate snapshot for caching" (system image download, AVD creation, cold boot, snapshot save). **45 s** for the following boot from snapshot plus the test run. Whole ubuntu jobs, including a Gradle build of the action's small test app, took **4:11–4:56**. The macOS job took 12:17.
- APK build: I found no primary timing for a cold Gradle release build of an Expo app on `ubuntu-latest`. It is the dominant cost, and an estimate of 10+ minutes cold, less with Gradle caching, needs proving with a spike.
- Maestro: the flow itself takes seconds.

**How flaky:** no primary source gives a flake rate for emulators on GitHub runners. Maestro claims "built-in flakiness tolerance and automatic waiting" with no `sleep()` calls ([README](https://github.com/mobile-dev-inc/Maestro)). The emulator action's own run history shows many failures (14 of its last 30 "Main workflow" runs), but those include PR breakage, so they say nothing about flakiness. The likely failure modes are a boot timeout and a slow first frame. Mitigations are the snapshot cache, a generous `emulator-boot-timeout`, and Maestro's `extendedWaitUntil` on the sign-in text.

**Recommendation:** leave e2e out of the required PR checks. It adds a Gradle build of unknown length and a tool, Maestro, whose only job is one assertion the developer makes by hand when installing on the OnePlus 7T. If the map wants it, add it as a `workflow_dispatch` (or nightly) job. It is free either way.

## Cheapest guard against spending images in tests

No vendor documents a "test mode" for the Gemini API, so the guard has to come from how WearAI is set up. Layer three free measures. Each one alone fails closed:

1. **No Nano Banana key where tests run.** The image client reads its key from an env var and throws if the var is absent, with no fallback. Locally, Edge Functions read secrets from `supabase/functions/.env` ([Supabase: Secrets](https://supabase.com/docs/guides/functions/secrets)). Keep the paid key out of that file and out of every CI workflow. The paid key exists only as a hosted secret (`supabase secrets set`). A key that isn't present can't be spent. For the same reason, don't give CI jobs a GitHub secret holding the paid key. GitHub also withholds secrets from fork-triggered workflows, but WearAI doesn't need to rely on that.
2. **Deno network permission.** Run Edge Function tests with `deno test --allow-net=127.0.0.1,localhost` (or without `--allow-net` at all for pure handler tests). `--allow-net` takes a host list, and a refused operation throws `NotCapable` ([Deno: Security](https://docs.deno.com/runtime/fundamentals/security/)). Even if a stub is missing, a real call to `generativelanguage.googleapis.com` throws instead of spending. `Deno.test` can also deny permissions per test ([Deno: Testing](https://docs.deno.com/runtime/fundamentals/testing/)).
3. **Budget at zero in test and local data.** Have the local seed (or the pgTAP setup) set `image_budget.cap = 0` unless a test raises it inside its own rolled-back transaction. Then even a manual `supabase functions serve` run with a key present gets `over_limit` and never calls the model. This uses the reservation in [`data-model.md`](../spec/data-model.md#image-budget) that already runs before every image call.

The catch-all `throw` in the `fetch` stub (above) is a fourth, test-level guard. Gemini Flash and Roboflow are free tiers with rate limits, not paid. The same guards keep tests from using up those quotas.

## Sources

- Supabase: [Testing your database](https://supabase.com/docs/guides/database/testing) · [Test RLS policies with pgTAP](https://supabase.com/docs/guides/database/postgres/testing-row-level-security) · [Advanced pgTAP testing](https://supabase.com/docs/guides/local-development/testing/pgtap-extended) · [Testing and linting in CI](https://supabase.com/docs/guides/deployment/ci/testing) · [Testing Edge Functions](https://supabase.com/docs/guides/functions/unit-test) · [Edge Function secrets](https://supabase.com/docs/guides/functions/secrets) · [CLI: supabase start](https://supabase.com/docs/reference/cli/supabase-start) · [CLI getting started](https://supabase.com/docs/guides/local-development/cli/getting-started)
- Supabase source and CI: [cli `db start` SIDE_EFFECTS.md](https://github.com/supabase/cli/blob/develop/apps/cli/src/commands/db/start/SIDE_EFFECTS.md) · [cli#4394](https://github.com/supabase/cli/pull/4394) · [setup-cli e2e.yml](https://github.com/supabase/setup-cli/blob/main/.github/workflows/e2e.yml) and [run 42736624239](https://github.com/supabase/setup-cli/actions/runs/42736624239) · [postgres init scripts](https://github.com/supabase/postgres/tree/develop/migrations/db/init-scripts) · [basejump supabase-test-helpers](https://github.com/usebasejump/supabase-test-helpers)
- Deno: [Testing](https://docs.deno.com/runtime/fundamentals/testing/) · [Security and permissions](https://docs.deno.com/runtime/fundamentals/security/) · [@std/testing/mock](https://jsr.io/@std/testing/doc/mock)
- Expo: [Unit testing](https://docs.expo.dev/develop/unit-testing/) · [Expo CLI](https://docs.expo.dev/more/expo-cli/) · [EAS Workflows e2e](https://docs.expo.dev/eas/workflows/examples/e2e-tests/) · [Pricing](https://expo.dev/pricing) · [bare template build.gradle](https://github.com/expo/expo/blob/main/templates/expo-template-bare-minimum/android/app/build.gradle)
- GitHub: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) · [Actions limits](https://docs.github.com/en/actions/reference/limits) · [Hardware-accelerated Android virtualization (2024-04-02)](https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/)
- Android e2e: [ReactiveCircus/android-emulator-runner](https://github.com/ReactiveCircus/android-emulator-runner) and [run 38912362990](https://github.com/ReactiveCircus/android-emulator-runner/actions/runs/38912362990) · [Maestro repo](https://github.com/mobile-dev-inc/Maestro) · [Maestro install](https://docs.maestro.dev/getting-started/installing-maestro) · [Maestro pricing](https://maestro.dev/pricing) · [Maestro GitHub Action (Cloud)](https://docs.maestro.dev/cloud/ci-integration/github-actions/maestro-github-action-for-android) · [Detox project setup](https://wix.github.io/Detox/docs/introduction/project-setup)
