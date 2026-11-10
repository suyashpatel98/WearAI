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
| `image_budget.cap` (seed) | 1000 | 30 |

Automated tests are separate from both columns. Whether they call any model is decided in [What do the minimal tests cover, and how are model calls kept out?](https://github.com/suyashpatel98/WearAI/issues/49). Tests seed `cap = 0`.

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
- Where each key is stored and how it reaches each environment is decided in [Where do secrets live, and how do they flow in a public repo?](https://github.com/suyashpatel98/WearAI/issues/50).

### Which environment the app talks to

- **Development build + Metro:** `APP_ENV=local|hosted` picks `.env.local` or `.env.hosted`, and `local` is the default. Metro reads `EXPO_PUBLIC_SUPABASE_URL` when it starts, so switching environments means restarting Metro, not rebuilding. The phone reaches the Mac's stack through `adb reverse`.
- **Standalone APK** (the build pipeline is decided in [How do changes reach hosted Supabase and the phone?](https://github.com/suyashpatel98/WearAI/issues/52)): always `hosted`, set at build time.
- The app shows a small **`LOCAL`** badge whenever it points at `local`.
- If Google sign-in fails against `local` on the phone, add a sign-in by email that exists only in `__DEV__` bundles. Don't build it until it's needed.

### Guard rails

- Every command targets `local` unless its name says `hosted` (e.g. `deploy-hosted`). Command names are decided in [What is the single command surface?](https://github.com/suyashpatel98/WearAI/issues/48).
- Each `hosted` command first prints the project ref and what it will change. Run interactively, it asks for confirmation. CI passes `--yes` itself.
- **Agents never run commands that change `hosted`**: migrations, function deploys, or setting secrets. `AGENTS.md` says so. Agents may run read-only `hosted` commands, such as reading function logs. This backs up the Supabase CLI v3 default, which only reaches `hosted` with `--remote --yes`.
