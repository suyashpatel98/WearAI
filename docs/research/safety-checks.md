# Safety checks for Reference Photos, Style Me prompts and generated images (Nov 2026)

Research for issue #27. Researched 2026-11-09 against vendor docs, pricing pages, price-list APIs and terms. Prices are USD list prices on that date. This is research, not legal advice.

**Question:** Which safety checks can WearAI run on Reference Photos, Style Me prompts and generated images, and what does each cost? Cover: Reference Photos that show exactly one person, an adult, and the same face in all 1–3 photos; filtering Style Me prompts; and a safety classifier on every generated image before it is shown. For each option give cost per call, latency, whether it can be offered in India, and whether inputs may be used for training or human review. Note which fit Supabase Edge Functions (2 s CPU, 400 s wall clock).

**Why:** The IT Rules research (#13) says WearAI must block unlawful synthetic images: sexual or "undressing" images, NCII and someone else's likeness. It says to check Reference Photos (one adult, same face, attested to be the User), filter Style Me prompts, and classify every output, and not to rely only on Gemini's own filters. The Play research (#7) adds: no nudity, sexual or suggestive poses, sheer clothing or lingerie, and never any undressing.

## Answer

Recommended lean MVP combination. It adds about **$0.01 once per User** at onboarding and about **$0.0025 per generated image**, which is roughly 5–10% of the ~$0.025–0.05 it costs to generate one image (#4).

1. **Reference Photos: AWS Rekognition in Mumbai (`ap-south-1`).** Run three calls, at $0.00125 each:
   - `DetectFaces` with `ALL` attributes on each photo. Require exactly one face. Use `AgeRange` as the adult signal.
   - `DetectModerationLabels` on each photo. Reject nudity.
   - `CompareFaces` between photo 1 and photos 2 and 3. This checks it is the same face.

   For 3 photos that is 8 calls, about $0.01 per User. Do it once, plus again whenever the User replaces a photo. Keep the "these photos are of me" attestation checkbox from #13; no API can check that.
2. **Style Me prompts: no new vendor.**
   - Run a small deterministic blocklist first, in English, Hindi and Hinglish ("nude", "bikini", "lingerie", "see-through", "remove clothes" and so on).
   - Then let the Gemini text call that plans the Style Me reply also return a structured safety verdict.
   - Set that call's `sexually_explicit` and `harassment` filters to `block_low_and_above`.
   - Never pass the User's raw text to the image model. The server builds the image prompt from Item IDs and the Stylist's template.

   This adds no cost. If Style Me has no text-model call, a separate `gemini-3.1-flash-lite` check costs about $0.0002.
3. **Every generated image:**
   - Set the generation call's `sexually_explicit` filter to `block_low_and_above`. This is free.
   - Run Rekognition `DetectModerationLabels` on the output.
   - Run `DetectFaces` on the output to check there is exactly one face and that it doesn't look like a minor.

   Together that is $0.0025 per image, or about $0.45 per User per month at the ~180 images per month assumed in #8. Store the image as pending. Show it, as a Post or in Style Me, only after both checks pass.
4. **Opt out of AWS AI-service training on day one** with an AWS Organizations AI services opt-out policy. Without it, Rekognition may keep and use inputs to improve the service. Opting out deletes content already stored for that purpose [A6, A7].
5. **Defer** Gemini-as-judge, Azure, OpenAI moderation, Cloud Vision and self-hosted open models until the MVP shows a real gap (false blocks on Indian clothing, or misses).

Why Rekognition:
- It is the only option that does all three Reference Photo checks (face count, age range, face compare) and image moderation from one vendor in Mumbai, next to Supabase.
- Its moderation labels map directly onto Play's rules. It has separate labels for *Swimwear or Underwear*, *Partially Exposed Female Breast*, *Implied Nudity* and *Explicit Nudity*.
- Its moderation is independent of Google's filters, which the IT Rules finding asks for.

Azure Content Safety is cheaper per image ($0.00075) and keeps nothing. But its "Low" sexual severity includes "Fashion modeling", it has no age or face-compare WearAI can use, and the Azure Face API is closed to WearAI.

## Options compared

| Option | What it can check | List price per call | India | Training / human review of inputs | Fits Edge Functions? |
|---|---|---|---|---|---|
| **Gemini safety settings** on the generation and Style Me calls | Adjustable: harassment, hate, sexually explicit, dangerous, jailbreak. Child safety is always blocked [G1] | Free (part of the call) | Yes | Paid tier: no training. Prompts and outputs logged 55 days for abuse monitoring. Flagged content may be reviewed by Google staff [G2, G3] | Yes (same call) |
| **Gemini as judge** (`gemini-3.1-flash-lite`) | Anything a prompt can describe: person count, "looks under 18", same person, sheer or lingerie, undressing | ≈ $0.0004 per image (1,120 image tokens at $0.25/M, plus ~100 output tokens at $1.50/M). ≈ $0.0002 at `low` media resolution (280 tokens) [G4, G5] | Yes | Same as above. **Never on the free tier**: free-tier inputs are used for training and read by human reviewers [G2] | Yes (one HTTP call) |
| **AWS Rekognition** `DetectFaces`, `CompareFaces`, `DetectModerationLabels` (Mumbai) | Face count (100 largest), `AgeRange`, face similarity, 3-level moderation taxonomy incl. swimwear and underwear [A2, A3, A4] | $0.00125 per image for the first 1M per month in `ap-south-1`, for both Group 1 (`CompareFaces`) and Group 2 (`DetectFaces`, `DetectModerationLabels`) [A1] | Yes, Mumbai region [A1] | **Used to improve the service unless you opt out** through AWS Organizations; may be stored outside the region for that purpose [A6, A7] | Yes (HTTP + SigV4; send raw bytes ≤ 5 MB) |
| **Azure AI Content Safety** (text and image) | Image: hate, sexual, violence, self-harm at severity 0/2/4/6. Text: the same four plus Prompt Shields (jailbreak) [Z2, Z3] | Image $0.00075, text $0.000375 per 1,000-character record. Free tier: 5,000 images and 5,000 text records per month [Z1] | Yes, South India region (`southindia`) [Z1, Z4] | Not stored, not used for training, not human-reviewed; stays in the chosen region [Z5] | Yes |
| **Azure Face API** | Detect, verify, age | — | — | — | **Not available.** Access is "only available to Microsoft managed customers and partners". Age is a limited attribute [Z6] |
| **OpenAI `omni-moderation-latest`** | Images: sexual, self-harm, violence only. `sexual/minors` is **text-only** [O1] | **Free** [O1] | Yes (India is on OpenAI's supported list, per #4) | `/v1/moderations`: no training, no abuse-monitoring retention, eligible for Zero Data Retention [O2] | Yes |
| **Google Cloud Vision** SafeSearch + Face Detection | SafeSearch likelihoods: adult, spoof, medical, violence, racy. Face detection returns faces but **no age and no face comparison** [V2] | $0.0015 per feature per image after 1,000 free units per month. SafeSearch is no longer free with Label Detection [V1] | No India endpoint found; global, with an EU endpoint | Not used for training. Online requests processed in memory, not persisted [V3] | Yes |
| **ShieldGemma 2** (4B, open) | Sexually explicit, dangerous, violence/gore. Google's own eval: F1 88.6% on sexual [H1] | Self-hosted. A T4 GPU endpoint is $0.50/hour, about $365 per month always-on [H4] | Wherever you host it | None (your own server) | **No.** 256 MB memory, 2 s CPU, no multithreading [S1] |
| **Llama Guard 4** (12B, open) | 14 hazard categories incl. S4 child sexual exploitation and S12 sexual content, on text and images [H2] | Self-hosted, needs a bigger GPU (L4 $0.70–0.80/hour) [H4] | Wherever you host it | None | No |
| **Small open NSFW classifiers** (for example Falconsai's ViT, Apache-2.0) | Binary safe/NSFW. The card publishes no accuracy numbers [H3] | Self-hosted CPU endpoint from $0.033/hour [H4] | Wherever you host it | None | Unlikely within 256 MB and 2 s CPU; untested |
| **Open face recognition** (InsightFace) | Face compare | — | — | — | Pretrained models are "for non-commercial research purposes only"; commercial use needs a licence [H5] |

**Latency.** None of these vendors publish latency figures. All the hosted APIs are synchronous single-image calls, so their latency should be small next to image generation, which takes seconds. The prototype should log it. Self-hosted endpoints that scale to zero add cold starts.

**Break-even for self-hosting.** An always-on $365/month GPU only beats Rekognition's $0.00125 above about 290,000 checks a month. That makes it a post-launch question.

## Findings by check

### 1. Reference Photos: one person, an adult, the same face

**AWS Rekognition (recommended)**
- `DetectFaces` returns the 100 largest faces. With `Attributes=["ALL"]` it returns `AgeRange {Low, High}`, `FaceOccluded`, `Quality` and `Pose` [A2].
- A face must be at least 40×40 px in a 1920×1080 image, and the minimum scales up with larger images [A5]. A full-body phone photo usually clears this. Test it, though, because a full-body shot makes the face small.
- AWS's guidance on age: "the midpoint of the predicted age range offers the best approximation", and "A 99% confidence threshold is recommended for sensitive use cases" [A3]. The example response shows a range of 18–26 [A2], so ranges are wide.
- Suggested MVP rule:
  - Reject if the midpoint is under 18.
  - If `Low` is under 18 but the midpoint is 18 or over, accept but queue the account for a human look.
  - This is a signal, not age verification. The 18+ age gate and Play's Restrict Minor Access (#7) stay the primary control.
- `CompareFaces` compares the largest face in the source image with every face in the target image. By default it returns only matches with ≥ 80% similarity [A4].
  - AWS recommends comparing "against multiple source images" to reduce false negatives. For decisions that affect "access to services", it recommends human review before acting [A4].
  - So on a mismatch, ask the User for a retake. Don't ban.
  - `UnmatchedFaces` also shows any second face in the target image.
- `DetectModerationLabels` uses a three-level taxonomy [A3a]:
  - *Explicit* → *Explicit Nudity* and *Explicit Sexual Activity*
  - *Non-Explicit Nudity of Intimate parts and Kissing* → *Implied Nudity*, *Partially Exposed Female Breast* and others
  - *Swimwear or Underwear* → female or male
  - AWS says it "isn't an authority on, and doesn't in any way claim to be an exhaustive filter of" such content, and that it does **not** detect CSAM [A3a].
- Limits: raw bytes up to 5 MB per call; PNG or JPEG; at least 80 px per side [A5]. Edge Functions can't run `sharp` or libvips [S1], so resize Reference Photos on the phone before upload.
- Cost at Mumbai list prices [A1]: $0.00125 per image for the first 1M per month in both Group 1 and Group 2. AWS's pricing page lists a 1,000-images-per-month free allowance per group for 12 months [A8].
- Data: Rekognition "may store and use image and video inputs … unless you opt out" to improve the service [A6]. The AWS Organizations opt-out policy stops this and deletes content already stored for improvement [A7]. The FAQ says only "authorized employees" access content [A6]. Opt out before any real User's photo is sent. This also lets the Play Data safety form declare AWS as a service provider (#7).

**Gemini as judge (cheaper alternative, unproven)**
- One `gemini-3.1-flash-lite` call with 1–3 photos and a JSON schema (`person_count`, `appears_adult`, `same_person`, `nudity`) costs about $0.001–0.0015 [G4, G5]. That is less than Rekognition's ~$0.01.
- But no vendor documents how accurate an LLM is at age or identity. The model may also decline to compare faces. Treat it as an experiment, not the control.
- Google's Prohibited Use Policy bans using "biometrics without legally-required consent" (#4). The onboarding consent screen from #7 covers this.

**Not usable**
- The Azure Face API is Limited Access, "only available to Microsoft managed customers and partners", and age is a limited attribute [Z6].
- Cloud Vision face detection returns no age and no comparison [V2].
- InsightFace's pretrained models are non-commercial only [H5].

### 2. Style Me prompts

- **Gemini safety settings.**
  - The adjustable filters are harassment, hate speech, sexually explicit, dangerous content and jailbreak.
  - "The default for Gemini 2.5 and later models is Off."
  - Thresholds are `off`, `block_only_high`, `block_medium_and_above` and `block_low_and_above`.
  - Child-safety harms "are always blocked and cannot be adjusted."
  - A blocked request fails with HTTP 400 and an error code: `safety`, `jailbreak`, `prohibited_content` or `blocklist` [G1].
  - So WearAI must turn the filters on explicitly.
- **Same-call verdict.** The Style Me text call can return a field such as `{"allowed": false, "reason": "sexualised"}`. That costs no extra call. It also lets the model refuse things a blocklist can't catch: someone else's likeness ("make me look like <celebrity>"), "make me look younger or like a child", and "wet saree" or "see-through" phrasings.
- **Blocklist first.** It is deterministic, free, and works on Hinglish, where vendor classifiers are weakest. Azure says its classifiers are trained on 8 languages, not Hindi [Z4]. Vendors publish no Hindi evaluation.
- **Alternatives:**
  - Azure Content Safety text: $0.000375 per 1,000 characters, Prompt Shields included, South India region [Z1, Z4].
  - OpenAI `omni-moderation-latest`: free, and has a text-only `sexual/minors` category [O1].
  - Each adds a vendor, a DPA and a Data safety entry, so keep them in reserve.
- **Design guard:** the image model should never see raw User text. The server builds the image prompt from Item IDs, the Stylist template and a fixed "fully clothed, non-suggestive" instruction. This shrinks what a jailbreak can reach.

### 3. Every generated image, before it is shown

- **Layer 1 (free):** set `sexually_explicit` to `block_low_and_above` on the Nano Banana 2.1 call [G1]. The image-generation guide documents no image-specific safety finish reason [G6]. Also, the IT Rules finding says not to rely on this alone (#13).
- **Layer 2 (recommended): Rekognition `DetectModerationLabels`** on the output bytes, which come back from Gemini in memory, so there is no S3 hop.
  - Block on any L1 label in *Explicit*, *Non-Explicit Nudity of Intimate parts and Kissing* or *Swimwear or Underwear* at the default `MinConfidence` of 50 [A3a].
  - Start strict and loosen with data. A blouse-less saree drape or a deep-neck kurta may trip *Partially Exposed*, so log every block for later tuning.
- **Layer 3 (recommended): Rekognition `DetectFaces`** on the output. Block if there is not exactly one face, which stops added people and likeness swaps. Also block if the face's age-range midpoint is under 18, which stops "younger" renders. Rekognition's moderation has no minors label, so this is the only minors signal in the stack.
- **Cost:** 2 × $0.00125 = $0.0025 per image [A1]. With Batch generation at ~$0.025 per image (#4), checks are about 10% of image cost. At the non-batch ~$0.05, about 5%.
- **Flow:**
  - Gemini returns the image.
  - The Edge Function runs both Rekognition calls in parallel.
  - On a pass, save it to the private bucket as visible and add the label and metadata (#13).
  - On a fail, save it as blocked (kept for the 180-day log in #13), never show it, and retry generation once or show a polite message.
  - The Play-required Report button (#7) feeds the same queue.
- **Later upgrade:** `CompareFaces` from the Reference Photo to the output would show the image still depicts the User. It would also measure likeness, which is quality work deferred by the MVP-first rule.

**Alternatives for layer 2**
- **Azure Content Safety image**, $0.00075 [Z1]. It has severity levels Safe/Low/Medium/High (0/2/4/6). "Low" includes "Fashion modeling" and "Racy display" [Z3], so WearAI would block at Medium (4) and above. It has no separate underwear or swimwear label, so lingerie may pass. It can't detect child exploitation images [Z2].
- **OpenAI omni-moderation**, free. It gives a single `sexual` score on images. `sexual/minors` doesn't work on images [O1].
- **Cloud Vision SafeSearch**, $0.0015. It gives likelihoods for `adult` and `racy` [V1, V2]. It costs more and does less than Rekognition.
- **Gemini as judge**, ≈ $0.0002–0.0004 [G4, G5]. It can apply WearAI's exact policy (sheer, lingerie, undressing, minors, one person) in one call, but it is the same vendor family and its accuracy is uncalibrated. It is the best candidate for a second opinion if Rekognition proves too blunt on Indian clothing.

### Supabase Edge Function fit

- Every hosted option is an outbound HTTPS call. Async I/O doesn't count toward the 2 s CPU limit, and the 400 s wall clock and 150 s idle timeout leave plenty of room [S1].
- Signing a Rekognition request (SigV4) and base64-encoding a 1–2 MB image take milliseconds of CPU. Use AWS SDK v3 through an `npm:` import, or a small SigV4 signer. Neither was tested here.
- Self-hosted models can't run inside Edge Functions. The limits are 256 MB memory, 2 s CPU, and no Web Workers or multithreaded native libraries [S1]. ShieldGemma 2 (4B) and Llama Guard 4 (12B) need a GPU host elsewhere.

## Caveats

- **No vendor publishes accuracy** on Indian clothing (sarees, lehengas, deep-neck blouses) or Indian faces. Expect false blocks. Log every block with its labels and review the first few hundred by hand. That counts as part of the "safety or red-team testing" record Play wants (#7).
- **Age estimation is not age verification.** It is a backstop to the 18+ gate.
- **None of these detect CSAM.** AWS and Azure say so explicitly [A3a, Z2]. Gemini's always-on child-safety block [G1] and the adult-only Reference Photos are the controls. A CSAM-hash service such as PhotoDNA wasn't researched. It mainly matters for user uploads, and WearAI accepts only the User's own photos.
- **Rekognition data use** depends on the opt-out policy being in place. Check it before onboarding real Users.
- **Gemini paid tier** still logs prompts and outputs for 55 days, and Google staff may review flagged content [G3]. Disclose this in the privacy notice (#7).
- **Prices change.** Gemini Flash prices rise on 2027-01-01 for 3.6 and 3.8 Flash. The Flash-Lite prices quoted here carry no change date [G5].

## Sources

- [G1] Gemini API safety settings — https://aistudio.google.com/docs/safety-settings (fetched 2026-11-09)
- [G2] Gemini API Additional Terms of Service, effective 2026-03-23 — https://aistudio.google.com/docs/terms
- [G3] Gemini API usage policies (abuse monitoring, 55 days) — https://aistudio.google.com/docs/usage-policies
- [G4] Gemini API media resolution (image token counts for Gemini 3) — https://aistudio.google.com/docs/media-resolution
- [G5] Gemini API pricing — https://aistudio.google.com/docs/pricing
- [G6] Gemini image generation guide — https://aistudio.google.com/docs/image-generation
- [A1] AWS Price List API, Amazon Rekognition, `ap-south-1` — https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRekognition/current/ap-south-1/index.json
- [A2] Rekognition: Detecting faces in an image — https://docs.aws.amazon.com/rekognition/latest/dg/faces-detect-images.html
- [A3] Rekognition: Guidelines on face attributes — https://docs.aws.amazon.com/rekognition/latest/dg/guidance-face-attributes.html
- [A3a] Rekognition: Using the image and video moderation APIs (taxonomy, confidence, CSAM note) — https://docs.aws.amazon.com/rekognition/latest/dg/moderation-api.html
- [A4] Rekognition: Comparing faces in images — https://docs.aws.amazon.com/rekognition/latest/dg/faces-comparefaces.html
- [A5] Rekognition: Guidelines and quotas — https://docs.aws.amazon.com/rekognition/latest/dg/limits.html
- [A6] Amazon Rekognition FAQs (data use) — https://aws.amazon.com/rekognition/faqs/
- [A7] AWS Organizations: AI services opt-out policies — https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_ai-opt-out.html
- [A8] Amazon Rekognition pricing — https://aws.amazon.com/rekognition/pricing/
- [Z1] Azure Retail Prices API, product "Content Safety", `southindia` and `eastus` — https://prices.azure.com/api/retail/prices
- [Z2] What is Azure AI Content Safety? (updated 2026-11-06) — https://learn.microsoft.com/en-us/azure/ai-services/content-safety/overview
- [Z3] Azure AI Content Safety harm categories — https://learn.microsoft.com/en-us/azure/ai-services/content-safety/concepts/harm-categories
- [Z4] Azure AI Content Safety region availability and limits (updated 2026-09-18) — https://learn.microsoft.com/en-us/azure/ai-services/content-safety/region-availability
- [Z5] Data, privacy, and security for Azure AI Content Safety — https://learn.microsoft.com/en-us/azure/ai-foundry/responsible-ai/content-safety/data-privacy
- [Z6] What is the Azure Face service? (updated 2026-10-19) — https://learn.microsoft.com/en-us/azure/ai-services/computer-vision/overview-identity
- [O1] OpenAI moderation guide — https://developers.openai.com/api/docs/guides/moderation
- [O2] OpenAI: Your data (endpoint retention table) — https://developers.openai.com/api/docs/guides/your-data
- [V1] Cloud Vision pricing — https://cloud.google.com/vision/pricing
- [V2] Cloud Vision: Detect explicit content (SafeSearch) — https://docs.cloud.google.com/vision/docs/detecting-safe-search
- [V3] Cloud Vision data usage FAQ — https://docs.cloud.google.com/vision/docs/data-usage
- [H1] ShieldGemma 2 model card — https://huggingface.co/google/shieldgemma-2-4b-it
- [H2] Llama Guard 4 model card — https://huggingface.co/meta-llama/Llama-Guard-4-12B
- [H3] Falconsai/nsfw_image_detection model card — https://huggingface.co/Falconsai/nsfw_image_detection
- [H4] Hugging Face Inference Endpoints pricing — https://huggingface.co/docs/inference-endpoints/pricing
- [H5] InsightFace licence (README) — https://github.com/deepinsight/insightface
- [S1] Supabase Edge Function limits — https://supabase.com/docs/guides/functions/limits
- Repo research: #4 `docs/research/image-models.md` (generation cost, OpenAI India availability), #7 `docs/research/play-dpdp-compliance.md`, #8 `docs/research/managed-backend.md` (~180 images per User per month), #13 `docs/research/it-rules-synthetic-media.md`
