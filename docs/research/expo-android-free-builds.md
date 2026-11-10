# How do we get an Expo Android build onto the OnePlus 7T for $0?

Research for issue #44 (part of the dev-ex map, #42). Researched 2026-11-09. Sources were read on that date; pricing and docs pages carry no publication date unless noted.

## Answer

- **Use a development build, not Expo Go.** Native Google Sign-In (`@react-native-google-signin/google-signin`, the library Supabase's guide uses) "cannot be used in Expo Go because it uses native code" [G1][S1]. The photo picker and upload would work in Expo Go [E7], but one native dependency is enough to need a development build (`expo-dev-client`) [E4]. Expo Go supports only one SDK at a time, and on the release date of SDK 58 Expo recommended a development build for it [E3].
- **Cheapest path: build on the laptop with `npx expo run:android`, and on GitHub Actions with `expo prebuild` + Gradle.** Both cost $0, have no quota, and need no Expo account [E4]. The laptop needs Node 22.13+ (Node 20 is too old for SDK 58 [E2][E3]), JDK 17 (installed), and the Android SDK, from either the command-line tools or Android Studio [E5]. The `ubuntu-24.04` runner already has the Android SDK, NDK 27 and JDK 17 [GH3], and standard runners are free for public repos [GH1].
- **EAS Build (Free) is the fallback, not the main path.** It gives 15 Android builds a month at low priority (queues can exceed 90 minutes at peak) with a 45-minute timeout [E1]. Free accounts "cannot incur overage charges"; when the quota runs out, builds stop until the 1st of the next month [E8][E9]. No card was found to be required. `eas build --local` needs `eas login` and the same SDK/NDK as a plain Gradle build, and it has no caching [E6], so it adds nothing for us.
- **JS-only changes reach the phone without a rebuild.** During development, the dev build loads JS from Metro, so only native changes need a rebuild [E4][E10]. For a release APK away from the laptop, EAS Update Free gives 1,000 MAU and 100 GiB with no overage [E1]. It also works with builds that weren't made by EAS [E12]. It's optional for the MVP.
- **Signing: the Expo template signs release builds with a public, shared debug keystore** (SHA-1 `5E:8F:16:06:…:F6:25`) [X1]. That's $0 and needs no secrets, and the SHA-1 is identical on the laptop and CI, which Google Sign-In needs [S1]. But anyone can sign with that key. The safer free option is our own keystore, kept outside the repo and given to CI as a base64 GitHub secret [GH4]. Its SHA-1 is registered alongside the debug one.
- **Getting a CI-built APK onto the phone:** attach it to a GitHub Release (public, 2 GiB per file, no bandwidth limit [GH5]) and open it on the phone, or download it with `gh` and run `adb install`. Prefer `adb`: Google's developer verification exempts adb installs for good, while browser sideloads of unregistered apps will need extra steps once the rollout reaches India (global in 2027) [A3].

Nothing in this path costs money. Paid items to avoid: EAS Starter ($19/month plus usage) [E1], and the Android Developer Console Full Distribution account ($25) [A3].

## The test device: OnePlus 7T

- Shipped in 2019 with Android 10. Its last major update was **OxygenOS 12 (Android 12, API 31)**, the final build in January 2023 with the December 2022 security patch [D1][D2]. It will stay on Android 12.
- Expo SDK 58 supports **Android 7+**, compiles against API 37 and targets API 36 [E2]. Android 12 is well inside the range, and an app that targets 36 installs normally on API 31.
- **Wireless debugging** (`adb pair`) needs Android 11+, so the 7T supports it. The older `adb tcpip 5555` flow (after one USB connection) also works [A1].
- **Photo picker:** `expo-image-picker` on Android launches AndroidX `PickVisualMedia` by default. A `legacy: true` option falls back to `ACTION_GET_CONTENT` [X2]. The system picker needs Android 11+ plus Google system updates of modular components. Without them, AndroidX falls back to `ACTION_OPEN_DOCUMENT` automatically [A2]. Either way, no storage permission is needed to pick an image [E7].
- The CPU is arm64 (Snapdragon 855+). We only need `arm64-v8a`, so CI can skip the other three ABIs the template builds by default [X3].

## Expo Go or a development build?

| Need | Expo Go | Development build |
|---|---|---|
| Native Google Sign-In → `signInWithIdToken` | No: "cannot be used in Expo Go because it uses native code" [G1] | Yes, via its config plugin [G1] |
| Photo picker (`expo-image-picker`) | Yes, "Included in Expo Go" [E7] | Yes |
| Image upload (`supabase-js` / `fetch`) | Yes (pure JS) | Yes |
| SDK pinning | Only the SDK that the store copy of Expo Go supports; SDK 58 Expo Go was announced as coming "within a few weeks" of Oct 15 [E3] | Any SDK |

A browser OAuth flow (`signInWithOAuth` plus a redirect) could run in Expo Go, but the product map's stack is native ID-token sign-in, and Supabase's Expo guide documents only that route [S1]. **Verdict: development build.**

What a development build involves [E4]:

```sh
npx expo install expo-dev-client
npx expo run:android            # local build + install, no Expo account needed
# or: eas build -p android --profile development  (cloud, uses free quota)
npx expo start                  # serves JS to the dev build
```

Rebuild only when you add or upgrade a library with native code, change the app config, or upgrade the SDK [E4]. With Continuous Native Generation, `android/` is generated by `npx expo prebuild` and is gitignored by default in new projects [E11].

## Ways to build the APK

| Option | Cost / limits | Account | Effort / notes |
|---|---|---|---|
| **`npx expo run:android` on the M1** | $0, unlimited | None [E4] | Needs the Android SDK locally. Builds, installs over adb and starts Metro in one command [E5]. Expo measured a clean debug build at about 39 s on an M3 Pro with SDK 58's prebuilt `expo-modules-core` [E3]. Expect an M1 to be somewhat slower. |
| **GitHub Actions: `expo prebuild` + Gradle** | $0; standard runners "free and unlimited on public repositories" [GH1]. 4 vCPU, 16 GB RAM, 14 GB SSD [GH1] | None | `ubuntu-24.04` image 20261101 includes Android cmdline-tools 12.0, Build-tools 34–37, platforms 34–37, NDK 27.3 (default) and JDK 17 (default) [GH3]. Its Node 22.23 meets SDK 58's minimum [GH3][E2]. Secrets aren't passed to fork-triggered workflows [GH4]. |
| **EAS Build, Free plan** | 15 Android + 15 iOS builds/month, low priority, peak queues "can exceed 90 minutes", 45-min timeout [E1]. No overage on Free; builds stop until the 1st of next month [E8][E9] | Expo account | Simplest signing (EAS can generate and store the keystore) [E13]. Paid servers: 4 vCPU/16 GB (medium) or 8 vCPU/32 GB (large) [E14]. The docs don't say which class Free builds get. |
| **`eas build --local`** | $0. The FAQ suggests it when the free quota runs out [E8], which implies it doesn't use quota (not stated outright) | Needs `eas login` or `EXPO_TOKEN` [E6] | Needs your own Android SDK + NDK, ignores `eas.json` `ndk`/`image`, and has **no caching** [E6]. Its only edge is that it applies EAS-managed or `credentials.json` signing for you [E13]. |

**Recommendation.** Use `npx expo run:android` for daily work and a GitHub Actions workflow for the installable release APK. Keep EAS Build Free as an emergency fallback (15 builds/month, can't bill).

Sketch of the CI build (unverified; a spike should time it, since no primary source gives a build time for this runner):

```sh
pnpm install --frozen-lockfile
npx expo prebuild --platform android --clean --no-install
cd android && ./gradlew :app:assembleRelease -PreactNativeArchitectures=arm64-v8a
# → android/app/build/outputs/apk/release/app-release.apk
```

`reactNativeArchitectures` defaults to `armeabi-v7a,arm64-v8a,x86,x86_64` in the template [X3], so building only `arm64-v8a` cuts native compile time. Cache `~/.gradle` (for example with `actions/setup-java`'s Gradle cache or `gradle/actions/setup-gradle`) for faster repeat builds.

## Laptop toolchain (minimum)

Current state: Node 20, Java 17 (Oracle 17.0.1), pnpm. No Android SDK, adb or eas.

1. **Node 22.13+ (or 24.3+).** SDK 58's minimum is Node 22.13.x [E2]. Its release notes say Expo tooling needs 22.13+, 24.3+ or 26+, and odd-numbered releases aren't supported [E3]. **Node 20 must be upgraded.**
2. **JDK 17.** Expo's guide installs Azul Zulu 17 (`brew install --cask zulu@17`) and sets `JAVA_HOME` [E5]. The installed Java 17 should work. Zulu is the documented choice if Gradle complains.
3. **Android SDK.** Expo's guide uses Android Studio. It installs SDK Platform 36 and Build-Tools, then sets `ANDROID_HOME=$HOME/Library/Android/sdk` with `platform-tools` on `PATH` [E5]. A lighter route is the standalone command-line tools, which Android distributes separately [A4]. They're also on Homebrew as `android-commandlinetools` (SDK root `$HOMEBREW_PREFIX/share/android-commandlinetools`) and `android-platform-tools` (adb) [H1]. Then install packages with `sdkmanager` [A4]:
   ```sh
   sdkmanager "platform-tools" "platforms;android-36" "platforms;android-37" "build-tools;36.0.0"
   sdkmanager --licenses
   ```
   (Package list inferred from compileSdk 37 / targetSdk 36 [E2]. Once licences are accepted, Gradle downloads any other missing SDK/NDK packages.) Android Studio is free too. Use it if the CLI route gets fiddly. No emulator is needed because we test on the phone.
4. **adb to the phone.** Enable Developer options (tap the build number 7 times), turn on USB debugging, then `adb devices` [E5]. For Wi-Fi: on Android 11+, `adb pair ip:port` from *Wireless debugging* [A1]. Or plug in USB once, run `adb tcpip 5555`, then `adb connect <phone-ip>:5555` [A1]. Metro reaches the phone over the same LAN or USB.
5. **eas-cli: not needed** for the recommended path. Install it only to use EAS Build or EAS Update (`npm i -g eas-cli`, free Expo account).

## Updates: EAS Update vs reinstalling

- **During development** the dev build fetches JS from Metro, so JS changes need no rebuild. Only native changes do [E4][E10].
- **EAS Update** pushes JS, styling and images over the air to builds that include `expo-updates`. Builds only get updates whose runtime version matches their native code [E12]. Commands: `npx expo install expo-updates`, `eas update:configure`, `eas update --channel production --message "…"` [E12]. It works as a standalone service with non-EAS builds. In that case the channel is set as a request header in app config, and created with `eas channel:create` [E15].
- **Free plan:** 1,000 update MAUs, 100 GiB bandwidth. "The Free plan has no update overage pricing; it is limited to its included monthly active users" [E1]. One phone is about 1 MAU. No card is required; Free accounts can't incur overage [E9].
- **Verdict for the MVP:** not needed at first. A rebuilt APK from CI plus `adb install -r` (same signing key) is simpler. EAS Update is a free add-on to adopt if reinstalling gets tedious.

## Signing and keystores (public repo)

- **What prebuild generates.** The Expo template's `android/app/build.gradle` signs **both debug and release** with `debug.keystore` (`android`/`androiddebugkey`/`android`), with the comment "Caution! In production, you need to generate your own keystore file" [X1]. That keystore ships inside the template, so every prebuild on any machine gets the same key. Its fingerprints:
  - SHA-1 `5E:8F:16:06:2E:A3:CD:2C:4A:0D:54:78:76:BA:A6:F3:8C:AB:F6:25`
  - SHA-256 `FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C`

  (computed with `keytool -list -v` on the template file [X1])
- **Why it matters.** Google's Android OAuth client needs the SHA-1 of the signing key, and you'll have different ones for local and production [S1]. Android also refuses to install an update signed with a different key, so you must uninstall first and lose app data.
- **Option A, MVP-simplest: the shared debug key everywhere.** It costs $0, needs no secrets, and gives the same SHA-1 on the laptop and CI. The cost is that the key is public. Anyone can build an APK with our package name and this SHA-1, which our Google OAuth client would accept. That only matters if someone installs that APK on a phone, which is negligible for a single-developer test phone. The key also can't be used to register the package for developer verification [A3]. For a personal test phone with adb installs, that doesn't matter yet.
- **Option B, own keystore (recommended once CI builds releases).**
  - Generate one with `keytool -genkey …` (RSA 2048, JKS) as in Expo's local-credentials guide [E16].
  - Keep it **outside the repo**, or gitignore it along with `credentials.json` [E16].
  - For CI, base64-encode it (`base64 -i release.keystore -o ks.b64`), store it with `gh secret set ANDROID_KEYSTORE_BASE64 < ks.b64` plus the passwords, and decode it on the runner [GH4]. The secret limit is 48 KB [GH4]; a keystore is a few KB. Secrets never reach fork PRs [GH4].
  - Register this SHA-1 in Google Cloud next to the debug one [S1].
  - Wiring it in: the generated Gradle file hard-codes the debug config [X1]. So either add a small local config plugin that writes a `release` signingConfig, or re-sign the APK after Gradle with `apksigner` from Build-tools. Alternatively, `eas build --local` with `credentialsSource: "local"` applies `credentials.json` for you [E16].
  - Back up the keystore (for example in a password manager). Google notes a lost key can't be used to register the package later [A3].
- **EAS-managed credentials** (generated by `eas build`, stored on Expo servers, viewable with `eas credentials`) are another free route [E13]. But they tie signing to EAS Build or `eas build --local`.

## Getting a CI-built APK onto the phone

| Route | How | Notes |
|---|---|---|
| **GitHub Release asset** | The workflow runs `gh release create`/`upload` with the APK. On the phone, open the release page and tap the APK. Or on the laptop: `gh release download … && adb install -r app-release.apk` | Under 2 GiB per file, up to 1,000 assets, "no limit on … bandwidth usage" [GH5]. The repo is public, so the asset is publicly downloadable; it must contain no secrets (public anon keys are fine). |
| **Actions artifact** | `actions/upload-artifact`, then `gh run download <run-id>` and `adb install -r` | Retention defaults to 90 days, the maximum for public repos [GH2]. Artifacts download as a zip, which is awkward to open on the phone directly. |
| **adb from the laptop** | `adb install path/to/app.apk` [A1][E10] | **Always allowed:** adb installs are exempt from Android developer verification and from the advanced-flow wait [A3]. |
| **EAS Build URL** (if EAS is used) | Open the build URL on the phone, or `eas build:run -p android` [E10] | Only for EAS-built APKs. |

**Android developer verification (Google, 2026–2027).** From Sept 30, 2026, installs of apps from unverified developers are blocked on certified devices, but only for participating stores in Brazil, Indonesia, Singapore and Thailand. Rollout goes global in 2027, enforced via Google Play services on Android 7+ [A3]. Sideloading an unregistered APK through the browser will then need either the one-time "advanced flow" (Developer mode, restart, a 24-hour wait, then confirmation) or a free **limited distribution account** (up to 20 devices, no ID, no fee). The $25 Full Distribution account is the paid tier to avoid [A3]. adb installs are unaffected [A3]. So **`adb install` should be the documented install command**, with Release-asset downloads as a convenience.

## Cost flags

- $0: Expo account, EAS Build Free (hard limit, no overage) [E1][E9], EAS Update Free (hard limit, no overage) [E1], GitHub-hosted standard runners on a public repo [GH1], Releases bandwidth [GH5], Android SDK/Studio/adb, limited distribution account [A3].
- **Costs money (avoid):** EAS Starter $19/month plus usage and higher tiers [E1]; Android Developer Console Full Distribution $25 [A3]; Play Console (out of scope). No card was found to be needed for any $0 item. Expo's billing pages only discuss cards for paid plans [E8].

## Open points for the spec / a spike

- Time a cold and a warm `assembleRelease` (arm64 only) on `ubuntu-24.04`. No primary source gives this figure.
- Decide between Option A and Option B signing, and if B, between a config plugin and post-build `apksigner`.
- Check that the 7T actually gets the system photo picker (needs Google system updates). The `ACTION_OPEN_DOCUMENT` fallback works either way [A2].
- Expo Go for SDK 58 may now be on Play. It doesn't matter, because Google Sign-In needs a development build.

## Sources

Expo
- [E1] Expo pricing — https://expo.dev/pricing
- [E2] Expo SDK 58 reference (versions tables) — https://docs.expo.dev/versions/v58.0.0/ and https://docs.expo.dev/versions/latest/
- [E3] Expo SDK 58 changelog (Oct 15, 2026) — https://expo.dev/changelog/sdk-58
- [E4] Introduction to development builds — https://docs.expo.dev/develop/development-builds/introduction/
- [E5] Set up your environment (Android, physical device, development build, local) — https://docs.expo.dev/get-started/set-up-your-environment/?platform=android&device=physical&mode=development-build&buildEnv=local
- [E6] Run builds locally (`eas build --local`) — https://docs.expo.dev/build-reference/local-builds/
- [E7] ImagePicker reference — https://docs.expo.dev/versions/latest/sdk/imagepicker/
- [E8] Billing FAQ — https://docs.expo.dev/billing/faq/
- [E9] Billing plans — https://docs.expo.dev/billing/plans/
- [E10] Build APKs for emulators and devices — https://docs.expo.dev/build-reference/apk/ ; Use a development build — https://docs.expo.dev/develop/development-builds/use-development-builds/
- [E11] Continuous Native Generation — https://docs.expo.dev/workflow/continuous-native-generation/
- [E12] EAS Update introduction — https://docs.expo.dev/eas-update/introduction/
- [E13] App credentials (managed) — https://docs.expo.dev/app-signing/managed-credentials/
- [E14] Build server infrastructure — https://docs.expo.dev/build-reference/infrastructure/
- [E15] EAS Update as a standalone service — https://docs.expo.dev/eas-update/standalone-service/
- [E16] Local app credentials — https://docs.expo.dev/app-signing/local-credentials/

Expo source (read via GitHub, `expo/expo` main on 2026-11-09; latest `expo` on npm is 58.0.23, published 2026-11-03)
- [X1] Template `android/app/build.gradle` and `android/app/debug.keystore` — https://github.com/expo/expo/tree/main/templates/expo-template-bare-minimum/android/app
- [X2] `expo-image-picker` `ImageLibraryContract.kt` — https://github.com/expo/expo/blob/main/packages/expo-image-picker/android/src/main/java/expo/modules/imagepicker/contracts/ImageLibraryContract.kt
- [X3] Template `android/gradle.properties` — https://github.com/expo/expo/blob/main/templates/expo-template-bare-minimum/android/gradle.properties

Google / Android
- [G1] React Native Google Sign-In, Expo setup — https://react-native-google-signin.github.io/docs/setting-up/expo
- [A1] Android Debug Bridge (wireless debugging, `adb install`) — https://developer.android.com/tools/adb
- [A2] Photo picker — https://developer.android.com/training/data-storage/shared/photopicker
- [A3] Android developer verification + FAQ — https://developer.android.com/developer-verification and https://developer.android.com/developer-verification/guides/faq
- [A4] SDK Command-Line Tools — https://developer.android.com/tools/releases/cmdline-tools

Supabase
- [S1] Login with Google (React Native / Expo) — https://supabase.com/docs/guides/auth/social-login/auth-google?platform=react-native

GitHub
- [GH1] GitHub-hosted runners reference — https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- [GH2] Artifact and log retention — https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization
- [GH3] Ubuntu 24.04 runner image readme (image 20261101.360.1) — https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md
- [GH4] Using secrets in GitHub Actions — https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- [GH5] About releases — https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases

Other
- [H1] Homebrew casks `android-commandlinetools`, `android-platform-tools`, `zulu@17` — https://formulae.brew.sh/cask/android-commandlinetools
- [D1] Android Authority, OnePlus 7 / 7T final software updates (Jan 2023) — https://www.androidauthority.com/oneplus-7-oneplus-7t-final-software-updates-3264835 (secondary; OnePlus's own forum post was not retrieved)
- [D2] 9to5Google, OnePlus 7/7T final update — https://9to5google.com/2023/01/10/oneplus-7-7t-final-update/ (secondary)
