# Image models that can dress a real person in given clothes (Nov 2026)

Research for issue #4. Researched 2026-11-06 against vendor docs, pricing pages and terms. Prices are USD list prices on that date.

**Question:** Which hosted image models can take a User's Reference Photos plus images or descriptions of specific Items (or Suggested Items) and produce a realistic image of that User wearing the Outfit while keeping their likeness? For each: identity preservation, garment fidelity, multi-image input, price per image, latency, API terms on images of real people, availability in India, and safety filters.

## Answer

- **Start the prototype (#9) with Gemini Nano Banana 2.1 (`gemini-nano-banana-2.1`) on the paid Gemini API.** It is Google's current main image model. Its docs include a try-on example (put the dress from image 1 on the woman from image 2, full-body). It takes up to 14 reference images, with up to 4 characters and 10 objects, so one call can take 1–3 Reference Photos plus every Item in an Outfit. It costs about $0.034 per 1K image plus about $0.0017 per input image, and Batch halves that, which suits the background Feed job. India is a supported region.
- **"Muse Image" is Meta's `muse-image-1.0`, and WearAI cannot use it.** It costs $0.01 per image and can combine several images, but Meta's Geographic Use Policy (updated 2026-10-12) bars making it available to End Users in India.
- **Use Gemini 3 Pro Image as the quality benchmark** ($0.134 per image, up to 5 character references), and **gpt-image-2 as the cross-vendor benchmark** (about $0.041 per medium portrait image).
- **Use a dedicated try-on API as the likeness benchmark.** Vertex AI Virtual Try-On costs $0.06 per image and takes one garment per call. FASHN Try-On Max costs $0.15 per image at 1K balanced. Both edit the Reference Photo itself, so they keep the User's face and body better by design. But they cannot restage the scene, so they can't make the varied Posts the Feed needs, and a full Outfit takes one call per garment.
- **No vendor measures likeness or garment fidelity.** Nobody publishes latency numbers for these models either. The prototype has to measure all three on Indian Users and Indian clothes (sarees, kurtas, dupattas).

## Shortlist for the prototype (#9)

| # | Model | Role in #9 | List price per output image | Multi-image input | India |
|---|---|---|---|---|---|
| 1 | Gemini Nano Banana 2.1 `gemini-nano-banana-2.1` | Default candidate | 1K $0.0336, 2K $0.0504; Batch 1K $0.0168. Input images 1,120 tokens each ≈ $0.0017 | Up to 14 refs: up to 4 characters + 10 objects | Yes (Gemini API region list) |
| 2 | Gemini 3 Pro Image (Nano Banana Pro) `gemini-3-pro-image` | Quality benchmark | 1K/2K $0.134, 4K $0.24 | Up to 14 refs: 5 characters, 6 objects, 3 style | Yes |
| 3 | OpenAI `gpt-image-2` (or 2.5/2.6 "flare") | Cross-vendor benchmark | 1024×1536: low $0.005, medium $0.041, high $0.165 (plus input image tokens at $8/M) | Yes; max not documented; inputs always processed at high fidelity | India on OpenAI's supported-countries list |
| 4 | Vertex AI Virtual Try-On `virtual-try-on-001` | Likeness benchmark / fallback for single-garment try-on | $0.06 | 1 person + 1 garment image per call | Not served from Mumbai; nearest are asia-southeast1 and asia-northeast1 |
| 5 | FASHN Try-On Max `tryon-max` | Likeness benchmark (specialist vendor) | Credits at $0.075 each: 1K fast 1 credit ($0.075), balanced 2 credits ($0.15), quality 3 credits ($0.225) | 1 model image + 1 product image | No regional limit stated |

Rough cost for one Post on #1: 3 Reference Photos + 5 Item photos = 8 inputs × 1,120 tokens × $1.50/M ≈ $0.013, plus 1K output $0.034, comes to **≈ $0.05 per image, or ≈ $0.025 with Batch**. Thinking tokens add a little more; the default level is `medium`, and they are billed. At 5 Feed Posts + 5 Style Me images per User per day, that is roughly $0.25–0.50 per User per day before retries. Treat this as an estimate to check in #9.

## Per-model findings

### Gemini image models (Google, "Nano Banana" family)

The current line-up comes from the image-generation guide [G1] and the pricing pages [G2, G3]:

| Model | Status per docs | Output price | Reference images |
|---|---|---|---|
| `gemini-nano-banana-2.1` | "Primary" model, model page updated Oct 2026, "Stable" [G4] | 1K $0.0336 / 2K $0.0504 / 4K $0.113; Batch half [G2] | 14 total, 4 characters, 10 objects [G1, G4] |
| `gemini-3.1-flash-image` (Nano Banana 2) | Previous generation; docs say new projects should use 2.1 | 0.5K $0.045 / 1K $0.067 / 2K $0.101 / 4K $0.151 | Same as 2.1 |
| `gemini-3.1-flash-lite-image` (Nano Banana 2 Lite) | Fastest and cheapest | 1K $0.0336 | "Not optimized for multiple reference inputs or multi-turn sequential editing" [G1], so **not suitable** for try-on |
| `gemini-3-pro-image` (Nano Banana Pro) | Premium | 1K/2K $0.134, 4K $0.24 | 14 total, 5 characters, 6 objects, 3 style |
| `gemini-2.5-flash-image` (Nano Banana, named in the map) | Legacy; **shuts down 2027-03-15**, migrate to Nano Banana 2 Lite [G2] | $0.039 (Batch $0.0195) | "works best with up to 3 images as input" [G1] |

- **Identity:** Google promises "character resemblance" for up to 4 characters, and 2.1 claims improved multi-turn character consistency [G4]. No metric is published.
- **Garment fidelity:** Google's docs include an e-commerce try-on prompt, quoted here: *"Take the blue floral dress from the first image and let the woman from the second image wear it. Generate a realistic, full-body shot…"* [G1]. Garments count as "objects", with up to 10 at high fidelity. No metric is published.
- **Multi-turn:** Style Me conversations can refine an image across turns, because 2.1 supports conversational editing [G4].
- **Latency:** No figures are published. The docs say only "Flash-level speed." Thinking defaults to `medium` and has a `minimal` level that trades quality for speed. It cannot be turned off on Gemini 3 image models, and thinking tokens are billed [G1].
- **Terms on real people:** The guide says *"Make sure you have the necessary rights to any images you upload"* [G1]. The Prohibited Use Policy bans impersonation "in order to deceive", "using personal data or biometrics without legally-required consent", non-consensual intimate imagery and sexually explicit content (last modified 2024-12-17) [G5]. A User dressing themselves from their own Reference Photos fits this, provided onboarding gets explicit consent.
- **API terms that matter:**
  - Developers must be 18+, and API Clients must not be "directed towards or likely to be accessed by individuals under the age of 18" [G6]. This fits the map's 18+ rule.
  - On the free tier, Google uses inputs and outputs to improve its products, human reviewers may read them, and the terms say not to submit personal information [G6]. **Reference Photos must therefore go only through the paid tier.**
  - The API is for "professional or business purposes" [G6].
- **India:** India is on the Gemini API available-regions list [G7]. Prompts work best in a listed set of languages that includes hi-IN [G1].
- **Safety filters:** The adjustable filters are **off by default**, and core harms such as child safety are always blocked [G8]. No doc says full-body photos are blocked. Swimwear, innerwear or sheer garments may still trip the sexually-explicit classifier, so #9 should test them. All outputs carry an invisible SynthID watermark [G1].
- **Vertex AI:** The same models are on Vertex AI at the same global prices. Some non-global endpoints cost 10% more [G3]. Vertex is the route if the pipeline ends up on Google Cloud.

### Muse Image (Meta)

- **What it is:** Meta's proprietary image model `muse-image-1.0`, launched on the Meta Model API on 2026-08-25. A single model handles generation, editing and multi-image composition, through the OpenAI-compatible `/v1/images/generations` and `/v1/images/edits` endpoints and the Responses API. It keeps a character consistent by passing the reference images on every call ("anchored composition"). Output goes up to 1600px [M1, M2].
- **Price:** $0.01 per image [M1].
- **Blocked for WearAI:** Meta's Geographic Use Policy, section 2.2 (last updated 2026-10-12), lists "Muse Image: India". Developers may not make the model "available to or permit access by End Users located in" India [M3]. Separately, Meta's related Muse Spark launch post says the Model API preview is for "developers in the US" (2026-07-08) [M4].
- **Not documented:** maximum input images, latency, and any rules specific to real people. Meta's launch post gives no guidance on real people and no try-on examples [M1].

### OpenAI GPT Image (`gpt-image-2`, 2.5 and 2.6 "flare"/"sunburst")

- **Price:** Image output costs $30/M tokens and image input $8/M tokens. Batch costs half [O1]. For `gpt-image-2`, the guide's per-image output prices at 1024×1536 are low $0.005, medium $0.041 and high $0.165 [O2]. No per-image table is published for 2.5 and 2.6; their token prices are the same as gpt-image-2's [O1].
- **Identity:** The guide says gpt-image-2 "processes every image input at high fidelity automatically", so there is no `input_fidelity` setting [O2]. The guide also warns the model "may occasionally struggle to maintain visual consistency for recurring characters" [O2].
- **Latency:** "Complex prompts may take up to 2 minutes" [O2].
- **Moderation:** The `moderation` parameter is `auto` (default) or `low` [O2]. Using GPT Image models may require API Organization Verification [O2].
- **Terms on real people:**
  - The Usage Policies ban using someone's likeness "without their consent in ways that could confuse authenticity" [O3].
  - The Service Terms say "You may not use Visual Capabilities to reproduce the likeness of any person without express consent and all necessary rights". This is quoted from search results; the page returned 403 when fetched directly [O4].
  - Either way, WearAI needs explicit consent from each User at onboarding.
- **India:** India is on OpenAI's supported-countries list [O5].

### Vertex AI Virtual Try-On (`virtual-try-on-001`, Google Cloud)

- **What it is:** A dedicated try-on model. You give it "an image of a person and product photos" and it returns up to 4 samples at the input image's resolution [V1, V2]. It became GA on 2026-01-23 and replaced `virtual-try-on-preview-08-04` [V3].
- **Price:** **$0.06 per image** for "1 image of a person and 1 image of clothing" [G3].
- **Multi-image input:** Up to 2 images per prompt (7 MB, PNG or JPEG) [V4]. A full Outfit therefore takes one call per garment, chained, and costs $0.06 × garments.
- **Identity:** It edits the person photo itself, so the face, body and pose come from the Reference Photo. That is good for likeness, but every result has the Reference Photo's pose and background. It cannot stage a styled scene.
- **India:** Regions are US, Canada, Europe, me-central1, asia-northeast1 and asia-southeast1. **asia-south1 (Mumbai) is not listed** [V4].
- **Safety:** "Person generation" is supported, safety settings can be configured, and outputs carry Content Credentials (C2PA) [V2, V4].

### FASHN API (specialist try-on vendor)

- **Endpoints:**
  - `tryon-max`: recommended, in preview since 2026-01-26. It takes `model_image` + `product_image` plus an optional prompt such as "tuck in shirt". FASHN says it "preserves the model's identity, pose, and styling" [F1].
  - `tryon-v1.6`: stable, 1 credit per image, about 5–17 s. It takes a garment category of tops, bottoms or one-pieces [F1].
- **Price:** On-demand credits cost $0.075 each, with a $7.50 minimum and no volume API plan [F2]. Try-On Max costs 1/2/3 credits (fast/balanced/quality) at 1K, and up to 5 credits at 4K [F1]. A January changelog said a flat 4 credits; the current docs list per-mode credits [F3].
- **Latency:** Try-On Max takes about 10 s (fast, 1K) to about 55 s (quality, 4K) [F1].
- **Moderation:** v1.6 has a `moderation_level` setting: conservative, permissive or none [F1].
- **Data handling:** Outputs are deleted after 3 days. Base64 inputs are deleted after processing. FASHN says it does not train on customer content unless the customer opts in [F1].
- **India:** No regional restriction is stated [F2].

### Also considered, not shortlisted

- **FLUX.2 (Black Forest Labs):**
  - FLUX.2 [pro] costs $0.03 for the first megapixel, plus $0.015 per megapixel for each reference image.
  - FLUX.2 [max] costs $0.07.
  - Kontext [pro] costs $0.04 per image.
  - All support multiple reference images, but no maximum is stated [B1].
  - It is a reasonable alternative if Gemini fails, but BFL publishes nothing on keeping a likeness and offers no try-on feature.
- **ByteDance Seedream 4.5 / 5.0 (BytePlus ModelArk):**
  - Third-party sources quote $0.018–0.09 per image.
  - Official per-image prices could not be confirmed because the BytePlus pricing pages need JavaScript.
  - Availability to Indian end users and the terms were not verified. Not recommended without that.
- **Imagen 4 (Vertex):** Text-to-image only ($0.02–0.06) [G3]. It cannot dress a given person.

## Open points that #9 must measure

1. **Likeness:** a face-similarity score between output and Reference Photo, plus a human check, across skin tones and body types. No vendor publishes this.
2. **Garment fidelity on Indian clothes:** drape, prints and embroidery (sarees, lehengas, kurtas, dupattas), and outfits of 3–5 Items in one call.
3. **Latency:** p50/p95 per call. This matters for Style Me (interactive) more than for the Feed (background, can use Batch).
4. **Refusal rate:** how often full-body images are refused or quietly sanitised, especially swimwear, innerwear and sleeveless clothes.

## Sources

- [G1] Gemini API — Image generation guide: https://aistudio.google.com/docs/image-generation (fetched 2026-11-06; formerly ai.google.dev/gemini-api/docs/image-generation)
- [G2] Gemini API — Pricing: https://aistudio.google.com/docs/pricing (fetched 2026-11-06)
- [G3] Vertex AI generative AI pricing: https://cloud.google.com/vertex-ai/generative-ai/pricing (fetched 2026-11-06)
- [G4] Gemini Nano Banana 2.1 model page: https://aistudio.google.com/docs/models/gemini-nano-banana-2.1 ("Latest update: October 2026")
- [G5] Google Generative AI Prohibited Use Policy: https://policies.google.com/terms/generative-ai/use-policy (last modified 2024-12-17)
- [G6] Gemini API Additional Terms of Service: https://ai.google.dev/gemini-api/terms (fetched 2026-11-06)
- [G7] Gemini API available regions: https://aistudio.google.com/docs/available-regions (fetched 2026-11-06)
- [G8] Gemini API safety settings: https://aistudio.google.com/docs/safety-settings (fetched 2026-11-06)
- [M1] Meta — Build with Muse Image: https://dev.meta.ai/resources/blog/build-with-muse-Image (2026-08-25)
- [M2] Meta Model API — Models: https://dev.meta.ai/docs/models (fetched 2026-11-06)
- [M3] Meta Model API — Geographic Use Policy: https://dev.meta.ai/legal/geographic-use-policy (last updated 2026-10-12)
- [M4] Meta — Build with Muse Spark: https://dev.meta.ai/resources/blog/build-with-muse-spark (2026-07-08)
- [O1] OpenAI API pricing: https://developers.openai.com/api/docs/pricing (fetched 2026-11-06)
- [O2] OpenAI image generation guide: https://developers.openai.com/api/docs/guides/image-generation (fetched 2026-11-06)
- [O3] OpenAI Usage Policies: https://openai.com/policies/usage-policies/
- [O4] OpenAI Service Terms: https://openai.com/policies/service-terms/ (quoted from search result; direct fetch returned 403)
- [O5] OpenAI supported countries: https://developers.openai.com/api/docs/supported-countries
- [V1] Vertex AI — Generate Virtual Try-On images: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/image/generate-virtual-try-on-images
- [V2] Vertex AI — Virtual Try-On 001 model page: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/virtual-try-on-001
- [V3] Vertex AI release notes: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/release-notes (GA 2026-01-23, per search result)
- [V4] Gemini Enterprise Agent Platform — Virtual Try-On model page: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/vto/virtual-try-on-001
- [F1] FASHN API docs (full): https://docs.fashn.ai/llms-full.txt (fetched 2026-11-06)
- [F2] FASHN pricing: https://fashn.ai/pricing (fetched 2026-11-06)
- [F3] FASHN changelog — Try-On Max: https://fashn.ai/changelog/api-try-on-max-endpoint-now-available (2026-01-25)
- [B1] Black Forest Labs pricing: https://bfl.ai/pricing (fetched 2026-11-06)
