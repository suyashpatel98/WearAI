# Which managed backend fits WearAI?

Research for issue #8. Researched 2026-11-06. Sources were read on that date; pricing pages carry no publication date unless noted.

## Answer

**Supabase (Pro plan, project in Mumbai `ap-south-1`).** It covers every requirement with one product: Postgres for Wardrobe, Posts and Style Me conversations; private per-User Storage buckets enforced by Row Level Security; Google Sign-In via native ID token; Supabase Cron + Queues + Edge Functions for the daily Feed job and all model calls (keys stay server-side); push through Expo's free push service. Its database, Storage and Auth can all live in Mumbai, its Edge Functions can be pinned to Mumbai, and its data is plain Postgres and S3-style objects, so lock-in is low.

Firebase is the runner-up. It fits as well on paper, but Cloud Storage now requires the Blaze plan with no free quota outside US regions, Cloud Functions bill for the time they spend waiting on slow image-generation calls, and Firestore's data model and Security Rules are proprietary, which makes moving off it hard.

Expected backend bill (excluding model API costs, which will dominate): **about $25/month at hundreds of Users, about $100–150 at 5,000, about $500–900 at 50,000.**

## Requirements checked

| Requirement | Supabase | Firebase |
|---|---|---|
| Expo (Android) client | `supabase-js` works in Expo Go; Expo has a first-party guide [E1] | JS SDK works in Expo Go; React Native Firebase needs a development build [E2] |
| Google Sign-In | `@react-native-google-signin/google-signin` → `signInWithIdToken` [S5] | Firebase Auth Google provider (native lib also needed) |
| Private photos per User | Storage + RLS policies | Cloud Storage + Security Rules; **Blaze required since 2026-02-03** [F2] |
| Database for Wardrobe, Posts, conversations | Postgres (relational, SQL, joins) | Firestore (document store, per-op billing) |
| Scheduled daily Feed job | Supabase Cron (pg_cron) → pg_net → Edge Function [S6][S7]; fan out via Queues (pgmq) [S8] | `onSchedule` (Cloud Scheduler, $0.10/job/month, 3 free) [F3]; fan out with task queues |
| Server-side model calls | Edge Functions (Deno): 400 s wall clock on paid plans, 2 s CPU per request excluding async I/O, 256 MB [S3] | Cloud Functions 2nd gen (Cloud Run), up to 60 min for HTTP [G1] |
| Per-User daily limits | A counter table + a Postgres function / check in the Edge Function, atomic in one transaction | Firestore transaction on a counter document |
| Push notifications | Expo push service (free, 600/s per project; needs FCM V1 credentials and a development build) [E3] | FCM free [F1], or Expo push on top of it |
| India residency | DB, Storage, Auth in Mumbai `ap-south-1` [S2]; Edge Functions pinnable to `ap-south-1` [S9] | Firestore, Storage, Functions (2nd gen, Tier 2 pricing) in `asia-south1` [F4] |

Push needs a development build either way (Expo Go dropped push in SDK 53 [E3]), as does native Google Sign-In, so neither backend's need for native modules is a real differentiator. WearAI will ship a development build regardless.

## Key findings

### Supabase

- Pricing [S1]: Free $0; Pro from $25/month, with 100,000 MAU, 8 GB database, 100 GB file storage, 250 GB egress + 250 GB cached egress, 2M Edge Function invocations and $10 compute credit (covers a Micro instance). Overage: $0.00325/MAU, $0.0213/GB storage, $0.09/GB egress, $0.03/GB cached egress, $2 per 1M invocations, $0.125/GB disk. Spend cap is on by default on Pro.
- Compute add-ons [S1][S4]: Micro $10 (1 GB), Small $15 (2 GB), Medium $60 (4 GB), Large $110, XL $210.
- The Free plan is not for production: Nano compute (0.5 GB), 1 GB Storage, 5 GB egress, and projects can be paused [S1][S10]. Two free projects per account are fine for dev/staging.
- Edge Functions bill **per invocation**, not per second, and the 2 s CPU limit excludes async I/O [S3]. Generating an image is mostly waiting on a model API, so this pricing suits the Feed and Style Me well. The 150 s request idle timeout [S3] means long jobs should run as background tasks (`EdgeRuntime.waitUntil`) [S11] or one Post per invocation, not as one blocking request.
- Supabase Cron advises no more than 8 concurrent jobs, each finishing within 10 minutes [S6]. So the daily Feed job should be: a cron job enqueues one message per User (or per Post) into a Queue [S8], and a worker Edge Function, invoked frequently, drains the Queue. Do not loop over all Users in one cron run.
- Image Transformations cost $5 per 1,000 origin images after 100/month [S12]. At ~180 new images per User per month this gets expensive fast; generate the thumbnail when the image is written instead.
- Regions [S2]: Mumbai `ap-south-1` is available as a specific region. Edge Functions run nearest the caller by default; pin them with `x-region` / `forceFunctionRegion` [S9].

### Firebase

- Spark (free) excludes Cloud Storage and Cloud Functions entirely [F1]. Since **2026-02-03** Blaze is required to use Cloud Storage at all [F2]. New `*.firebasestorage.app` buckets get no-cost quota **only in US regions** (us-central1, us-east1, us-west1) [F1][F2]; a Mumbai bucket pays from the first byte.
- Firestore in Mumbai (`asia-south1`, Standard edition) [G2]: reads $0.035 / 100K, writes $0.104 / 100K, deletes $0.012 / 100K, stored data about $0.104 / GiB-month; daily free quota 50K reads, 20K writes, 20K deletes, 1 GiB [F5].
- Cloud Storage Standard in Mumbai is roughly $0.02–0.025 / GiB-month [G3] (the page's tables were hard to parse; verify in the calculator). Egress to the internet is charged on top at Google network rates, about $0.12/GB from Asia (not confirmed from the primary table).
- Cloud Functions [F1]: 2M invocations/month free then $0.40/M, plus GB-seconds and CPU-seconds beyond free tiers. `asia-south1` is 2nd gen only and Tier 2 pricing [F4]. Unlike Supabase, the instance bills while it waits on the model API (concurrency per instance reduces this).
- Auth: 50K MAU free, then Identity Platform pricing [F1] (per-MAU rates could not be read from the primary page).
- FCM is free [F1].

### Other options considered briefly

- **Convex**: good TypeScript developer experience, but regions are only US East, EU (Ireland), Sydney and Canada, with no India region [C1]. Ruled out on residency/latency.
- **Appwrite Cloud**: the pricing page lists neither its quotas nor its regions clearly [A1]; nothing suggested it beats Supabase on any requirement. Not pursued.

### Data residency in India

- The DPDP Act 2023, s.16, allows personal data to go abroad except to countries the Government restricts by notification. The DPDP Rules were notified in November 2025 (13 or 14 Nov per secondary sources [D1]); Rule 15 governs cross-border transfers and allows further conditions by order. No hard localisation applies to an app like WearAI today, so a Mumbai region is a latency and trust choice, not a legal requirement. (Legal reading is from secondary sources; not legal advice.)
- Whichever backend is chosen, photos go to the model APIs (e.g. Gemini), which may process them outside India. Residency of the backend alone doesn't keep Reference Photos in India.

## Rough monthly backend cost

Assumptions per active User per month: ~180 new generated images (150 Feed Posts + ~30 Style Me) at ~300 KB, plus Wardrobe photos, so ~100 MB stored at steady state (depends on the retention policy, not yet decided); ~110 MB served (cached via CDN); ~1,000 Edge Function invocations; a few hundred DB reads/writes per day. **Model API costs are excluded** and will be much larger.

| Users | Supabase (Mumbai) | Firebase (Mumbai, Blaze) |
|---|---|---|
| 500 | ~$25 (Pro; everything within quota) | ~$10–20 (mostly free tiers; storage + egress billed) |
| 5,000 | ~$100–150: Pro $25 + Medium compute ~$50 net + storage ~$9 + cached egress ~$9 (up to ~$27 uncached) + invocations ~$6 | ~$120–200: Firestore ~$20 + Storage ~$12 + egress ~$65 + Functions (depends on concurrency) |
| 50,000 | ~$500–900: Pro $25 + Large/XL compute $100–200 + storage ~$105 + egress ~$160 cached (~$470 uncached) + invocations ~$96 | ~$1,000–1,500: Firestore ~$180 + Storage ~$115 + egress ~$650 + Functions |

The Firebase column is less certain: GCS egress and Cloud Run per-second rates for Mumbai weren't confirmed from the primary tables. Even so, the direction holds: egress and time spent waiting in functions cost more on Firebase for this workload.

## Lock-in

- **Supabase**: open source; the data is standard Postgres (`pg_dump`) and S3-compatible object storage; can be self-hosted or moved to any Postgres. Edge Functions are Deno/TypeScript and port easily. RLS policies are plain SQL. Low lock-in.
- **Firebase**: Firestore's data model, query limits and Security Rules are proprietary; migrating means rewriting the data layer and the rules. High lock-in.

## Open points

- Retention of generated images drives storage and egress cost the most (map: "Photo retention and account deletion").
- Concrete design of the Feed job (Cron → Queue → worker, retries, failures) belongs to the generation-pipeline ticket.
- Whether to keep Supabase's spend cap on: it limits bills but may stop service when a quota is reached.

## Sources

- [S1] Supabase pricing — https://supabase.com/pricing (undated, read 2026-11-06)
- [S2] Supabase regions — https://supabase.com/docs/guides/platform/regions
- [S3] Edge Function limits — https://supabase.com/docs/guides/functions/limits
- [S4] Compute and disk — https://supabase.com/docs/guides/platform/compute-and-disk
- [S5] Google login (React Native) — https://supabase.com/docs/guides/auth/social-login/auth-google?platform=react-native
- [S6] Supabase Cron — https://supabase.com/docs/guides/cron
- [S7] Scheduling Edge Functions — https://supabase.com/docs/guides/functions/schedule-functions
- [S8] Supabase Queues — https://supabase.com/docs/guides/queues
- [S9] Regional invocations — https://supabase.com/docs/guides/functions/regional-invocation
- [S10] Billing on the Free plan — https://supabase.com/docs/guides/platform/billing-on-free-plan
- [S11] Edge Function background tasks — https://supabase.com/docs/guides/functions/background-tasks
- [S12] Storage image transformations — https://supabase.com/docs/guides/storage/serving/image-transformations
- [F1] Firebase pricing — https://firebase.google.com/pricing (template metadata 2026-10-14)
- [F2] Cloud Storage for Firebase changes FAQ — https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- [F3] Scheduled functions — https://firebase.google.com/docs/functions/schedule-functions
- [F4] Cloud Functions locations — https://firebase.google.com/docs/functions/locations
- [F5] Firestore pricing (Firebase) — https://firebase.google.com/docs/firestore/pricing
- [G1] Cloud Run timeout — https://docs.cloud.google.com/functions/docs/configuring/timeout
- [G2] Firestore pricing (Google Cloud, Mumbai table) — https://cloud.google.com/firestore/pricing
- [G3] Cloud Storage pricing — https://cloud.google.com/storage/pricing
- [E1] Expo: Using Supabase — https://docs.expo.dev/guides/using-supabase/ (last modified 2026-11-02)
- [E2] Expo: Using Firebase — https://docs.expo.dev/guides/using-firebase/
- [E3] Expo push notifications FAQ — https://docs.expo.dev/push-notifications/faq/
- [C1] Convex regions — https://docs.convex.dev/production/regions
- [A1] Appwrite pricing — https://appwrite.io/pricing
- [D1] DPDP Rules 2025 (secondary summaries) — https://en.wikipedia.org/wiki/Digital_Personal_Data_Protection_Rules,_2025 ; https://www.mondaq.com/india/data-protection/1708164/digital-personal-data-protection-rules-2025-notified
