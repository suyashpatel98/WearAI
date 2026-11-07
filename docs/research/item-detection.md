# Item detection, classification and merging across camera-roll photos

Research for [#6](https://github.com/suyashpatel98/WearAI/issues/6). Feeds the prototype ticket #10 (run it on 20 real photos) and the attributes ticket #11.

Sources were read on **2026-11-06**. Most vendor pages carry no "last updated" date; where a page states a date, it is given. Prices are USD unless noted.

## The question

Which hosted models can take up to 20 camera-roll photos and:

- **(a) Detect.** Find each Item and accessory the User is wearing, and ignore other people.
- **(b) Classify.** Give each Item its attributes.
- **(c) Crop.** Produce a clean image or crop of each Item for later generation.
- **(d) Merge.** Recognise the same Item across several photos so it can be merged.

## Answer in brief

- **No single API does all four.** The best fit is a Gemini-centred pipeline:
  1. **Detect, classify and merge (a, b, d) in one multimodal call.** Send all photos of an upload (≤20) plus the User's Reference Photos to one Gemini Flash-class model. Ask for structured JSON: a de-duplicated Item list, each with attributes and a `box_2d` per photo it appears in, limited to the person who matches the Reference Photos.
  2. **Cut out each Item (c).** Turn each box into a pixel mask. Use Gemini's own segmentation output, or send the box as a prompt to SAM 3 (hosted on fal.ai at $0.005 per request). The masked crop is what the review step shows.
  3. **Only if needed, make a clean product image (c).** Do this with a Nano Banana image model (from $0.0336 per 1K image, $0.0168 batch), and only for confirmed Items. This step is the most expensive in the pipeline.
  4. **Merge against the existing Wardrobe on later uploads (d).** Use Gemini Embedding 2 image embeddings ($0.00012 per image) to find candidates, and let the LLM confirm.
- **Dedicated fashion APIs are not a better primary choice.** Ximilar is the best documented. It costs more per photo, does not document how it ignores other people, and its published taxonomy has no Indian ethnic-wear categories. It is still a useful benchmark for #10.
- **Gemini 2.5 Flash, a candidate on the map, is deprecated.** From **1 December 2026**, `gemini-2.5-flash` requests are routed to Gemini 3.5 Flash-Lite. Do not build on it.

## 1. Multimodal LLMs

### Gemini: the only major LLM API with documented detection *and* segmentation

- **Object detection.** The model returns `box_2d` as `[ymin, xmin, ymax, xmax]`, normalised to 0–1000, which you rescale to the original image. Prompts can be custom, for example "only the clothes worn by the person who matches these Reference Photos". [Gemini API: Image understanding](https://aistudio.google.com/docs/image-understanding)
- **Segmentation.** "Starting with Gemini 2.5, models not only detect items but also segment them". Output is JSON with `box_2d`, `label` and `mask`. The mask is described as a base64 PNG probability map (0–255). The code samples on the same page treat `mask` as a polygon, and the page does not reconcile the two. Google recommends setting thinking to `"minimal"` for better segmentation. Its samples use `gemini-3.8-flash`. [Image understanding](https://aistudio.google.com/docs/image-understanding)
  - **Docs conflict.** The Gemini 3.8 Flash model page says thinking levels are low/medium/high and that "`minimal` returns an error". [Gemini 3.8 Flash model page](https://aistudio.google.com/docs/models/gemini-3.8-flash) (latest update Sept 2026). #10 must check which model and thinking level actually return masks.
- **Image limits.** Up to 3,600 images per request. Inline requests are capped at 20 MB in total, so use the File API above that. JPEG, PNG, WEBP, HEIC and HEIF are accepted. [Image understanding](https://aistudio.google.com/docs/image-understanding)
- **Image token cost (Gemini 3/4).** `media_resolution` sets tokens per image:

  | Setting | Tokens per image |
  |---|---|
  | `low` | 280 |
  | `medium` | 560 |
  | `high` (also the default) | 1120 |
  | `ultra_high` | 2240 |

  Google recommends `high` for most image analysis. You can set it per image, for example `low` for Reference Photos. [Media resolution](https://aistudio.google.com/docs/media-resolution)
- **Structured outputs** are supported on the current Flash and Flash-Lite models, so attributes can be held to the fixed value lists that #11 decides. [3.8 Flash](https://aistudio.google.com/docs/models/gemini-3.8-flash), [3.5 Flash-Lite](https://aistudio.google.com/docs/models/gemini-3.5-flash-lite)
- **Accuracy and latency.** Google publishes no accuracy or latency figures for detection or segmentation. #10 has to measure them.

#### Model status and price (paid tier, per 1M tokens)

From [Gemini API pricing](https://aistudio.google.com/docs/pricing) and [Models](https://aistudio.google.com/docs/models):

| Model | Code | Status | Input (image) | Output | Batch in/out |
|---|---|---|---|---|---|
| Gemini 3.8 Flash | `gemini-3.8-flash` | New, stable (Sept 2026) | $0.75 → **$1.50 from 1 Jan 2027** | $3.75 → **$7.50 from 1 Jan 2027** | half |
| Gemini 3.6 Flash | `gemini-3.6-flash` | Stable, previous gen | same as 3.8 Flash | same | half |
| Gemini 3.5 Flash-Lite | `gemini-3.5-flash-lite` | Stable (July 2026) | $0.30 | $2.50 | $0.15 / $1.25 |
| Gemini 3.1 Flash-Lite | `gemini-3.1-flash-lite` | Stable (May 2026) | $0.25 | $1.50 | $0.125 / $0.75 |
| Gemini 2.5 Flash | `gemini-2.5-flash` | **Deprecated; routes to 3.5 Flash-Lite on 1 Dec 2026** | $0.30 | $2.50 | — |
| Gemini Robotics ER 2 | `gemini-robotics-er-2-preview` | Preview | $1.00 → $2.00 | $5 → $10 | — |

- **Robotics ER 2.** It "builds on Gemini 3.5 Flash with improved spatial reasoning" and does points and bounding boxes. Its page does not mention masks, and it is a preview. Use it only as a fallback if Flash boxes prove sloppy. [Robotics overview](https://aistudio.google.com/docs/robotics-overview)

#### Rough cost of one 20-photo upload (detection + classification + merge, one call)

- **Assumptions.**
  - Input: 20 photos at `high` (22,400 tokens), 3 Reference Photos at `low` (840) and a prompt of about 1,500 tokens, so about **25k input tokens**.
  - Output: about 30 Items with attributes and per-photo boxes, plus thinking, so about **10k output tokens**. This is a guess; #10 should log the real counts.
- **Results.**

  | Model | Price used | Cost per upload |
  |---|---|---|
  | Gemini 3.5 Flash-Lite | $0.30 / $2.50 | about **$0.03** |
  | Gemini 3.8 Flash, 2026 prices | $0.75 / $3.75 | about **$0.06** |
  | Gemini 3.8 Flash, from Jan 2027 | $1.50 / $7.50 | about **$0.11** |

- **Output dominates the cost.** Asking Gemini for masks will add a lot of output tokens, because masks come back as base64 PNG or polygons. That is a reason to get boxes from Gemini and masks from SAM 3.

### Claude and OpenAI: possible, but weaker for this job

- **Claude.** "Claude's coordinate and localization outputs are approximate … verify outputs before relying on them". It returns pixel coordinates for boxes, and its docs offer no segmentation masks. [Claude Vision docs](https://platform.claude.com/docs/en/build-with-claude/vision)
- **OpenAI.** "The model struggles with tasks requiring precise spatial localization". Its vision guide does not document bounding-box or mask output. [OpenAI Images and vision](https://developers.openai.com/api/docs/guides/images-vision)
- **Verdict.** Both could classify and merge Items well. Neither documents segmentation, so either would need a separate box and mask step. They are not shortlisted.

## 2. Dedicated fashion and segmentation APIs

### Ximilar Fashion Tagging

Source: [docs](https://docs.ximilar.com/tagging/fashion), [taxonomy](https://docs.ximilar.com/taxonomy/fashion), [pricing](https://www.ximilar.com/pricing/)

- **Endpoints.**
  - `detect` gives boxes and categories without tags.
  - `detect_tags` tags the largest Item.
  - `detect_tags_all` detects and tags every fashion item.
  - `meta` covers background, scene and view.
  - `region` classifies apparel as `indian` or `generic`. The effect of passing a region to `detect_tags` is undocumented.
  - `aggregate_labels=true` treats a batch as several photos of *one* object. That does not solve merging across a mixed upload.
  - At most 10 records per request.
- **Attributes.** Color, Pattern, Material, Design, Style, Occasion, Gender, Age, Sleeves, Length, Neckline, Fit, Cut, Closure and more.
- **Weak spots for WearAI.**
  - **No Indian categories.** The published taxonomy has no saree, kurta, lehenga, salwar or dupatta categories. Only Scarves comes close.
  - **Other people.** Nothing documents how it handles several people in one photo.
- **Price.** The credit cost depends on the operation:

  | Operation | Credits per image |
  |---|---|
  | Tag all items | 60 |
  | Tag main item | 20 |
  | Detect only | 5 |
  | Background removal, fast | 10 |
  | Background removal, precise | 50 |

  - Plans: Free has 1,000 credits a month. Business 100K is €59 / $69 a month. The price cells on the pricing page were garbled, so check the live page.
  - Per upload: 20 photos × 60 credits = 1,200 credits, about **$0.83 per upload** on Business 100K. That is roughly 10–25× the Gemini estimate.
- **Latency.** Sample responses show about 1–1.7 s per call. These are examples, not a benchmark.
- **Verdict.** Use it as a benchmark in #10, not as the primary choice.

### Meta SAM 3 (hosted on fal.ai)

Source: [fal.ai SAM 3 image endpoint](https://fal.ai/models/fal-ai/sam-3/image)

- **Prompts.** It segments from text, point, box or mask prompts, which can be combined.
- **Output.** Pixel masks as PNG, JPEG or WebP, up to 32 masks per image, with optional scores and boxes.
- **Price.** **$0.005 per request**, about $0.10 per 20-photo upload if each photo is one request.
- **Licence.** fal marks it "Commercial use permitted". The underlying weights are under Meta's custom SAM License, not Apache 2.0. I could only find that through secondary summaries ([Roboflow licence summary](https://roboflow.com/model-licenses/segment-anything-3)), so read Meta's licence text before launch.
- **Limits.**
  - It does not classify attributes.
  - It does not know which person is the User. A text prompt like "shirt" masks everyone's shirt.
  - **So:** use it *after* Gemini, with Gemini's boxes as prompts.

### Others not shortlisted

- **Not shortlisted.** Pixyle, Lily AI, API4AI Fashion and Zyla Labs. I found only marketing pages or marketplace listings, with no verifiable docs or prices.
- **Not checked.** Google Cloud Vision object localisation; its pricing page did not render. It returns generic labels ("Top", "Pants") and no fashion attributes, so it adds little over Gemini.

## 3. Clean Item images (c)

Sources: [Image generation](https://aistudio.google.com/docs/image-generation), [Pricing](https://aistudio.google.com/docs/pricing)

- **Two levels of output.**
  - **Masked crop.** SAM 3 or a Gemini mask, cut from the photo. It is cheap and shows the real Item, but folds, occlusion and the person's body stay in it.
  - **Clean product shot.** Generated from the crop by a Nano Banana model ("this garment, laid flat, plain background").
- **Nano Banana models and prices.**

  | Model | Code | Price per image | Notes |
  |---|---|---|---|
  | Nano Banana 2 Lite | `gemini-3.1-flash-lite-image` | $0.0336 per 1K image ($0.0168 batch) | Fastest and cheapest; "not optimized for multiple reference inputs" |
  | Nano Banana 2 | `gemini-3.1-flash-image` | $0.045 at 0.5K, $0.067 at 1K | — |
  | Nano Banana 2.1 | `gemini-nano-banana-2.1` | $0.0336 at 1K | Input costs $1.50 per 1M tokens |
  | Nano Banana (2.5 Flash Image) | `gemini-2.5-flash-image` | $0.039 | Shuts down 15 March 2027 |

  All generated images carry a SynthID watermark.
- **Cost.** With about 30 Items per upload, clean shots cost **about $0.50–$1.00 per upload** (batch at the low end). That is 10–30× the detection cost.
- **Risk.** A generated "clean" Item can drift from the real one: wrong print, wrong embroidery. That matters for Indian wear.
- **Recommendation.**
  1. Keep the masked crop as the Item's source image.
  2. Have #10 test whether the image-generation model (Muse Image or Nano Banana) can use the masked crop directly as a reference.
  3. Generate clean shots only if it cannot, and then only after the review step and in batch.

## 4. Merging the same Item across photos (d)

- **Within one upload (≤20 photos).**
  - Put all photos in one Gemini request (well within its limits) and ask for a de-duplicated Item list with the photos and boxes each Item appears in.
  - This uses the model's cross-image reasoning; no vendor offers a dedicated "same garment" API.
  - Expect errors with near-identical basics, such as two plain white shirts. The review step's merge and split actions cover these.
- **Across uploads (new photos against the existing Wardrobe).**
  1. Embed each masked crop with **Gemini Embedding 2**. Image input costs $0.00012 per image, at most 6 images per request, 128–3072 dimensions.
  2. Find the nearest Wardrobe Items by vector similarity.
  3. Ask the LLM to confirm "same Item?" on the shortlisted pairs.
  - Google lists clustering and classification as uses, not de-duplication specifically. [Embeddings](https://aistudio.google.com/docs/embeddings)
- **Ximilar** `aggregate_labels` assumes the whole batch is one object. It does not fit this job.

## 5. Ignoring other people (a)

- **No dedicated API offers "only this person's clothes"** as a feature. The practical approach is to give Gemini the Reference Photos with each request and tell it to return Items only for the matching person.
- **Policy.**
  - Google's Generative AI Prohibited Use Policy bans "using personal data or biometrics without legally-required consent" (§1.6). [Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy) (last modified 17 Dec 2024)
  - We ask the model to pick *the consenting User* out of the photo by appearance. We do not identify or store anyone else. Even so, the consent wording and the treatment of bystanders in uploaded photos belong with the privacy and retention work.

## 6. Terms that matter

Source: [Gemini API Additional Terms](https://aistudio.google.com/docs/terms) (effective 23 March 2026)

- **Free tier.** On the free (Unpaid) tier, Google may use prompts and photos to improve products, and human reviewers may see them. The terms say: "Do not submit sensitive, confidential, or personal information to the Unpaid Services."
- **Paid tier.** Google does not use prompts or responses for training. It logs them for a limited time to detect abuse.
- **Rule for WearAI.** User photos must go only through the **paid tier**, including in development with real photos.
- **Age.** API users must be 18+. That matches the app's 18+ rule.

## 7. Which Item attributes can be extracted reliably (input to #11)

- **No vendor publishes accuracy figures for these attributes.** The reliability judgements below are hypotheses for #10 to confirm. They come from how visible each attribute is in a photo and what fashion taxonomies (Ximilar) expose.
- **Likely reliable (directly visible):**
  - Category and subcategory, including Indian wear such as kurta, saree, lehenga or sherwani. Gemini is open-vocabulary, whereas Ximilar's taxonomy lacks these.
  - Primary colour, and a secondary colour where clear.
  - Pattern: solid, stripes, checks, floral, print, embroidery.
  - Cultural style: ethnic, western or fusion.
  - Sleeve length, garment length and neckline, when the Item is fully visible.
- **Moderate (inferred; expect fixes at review):**
  - Formality or occasion (casual, office, party, festive or wedding).
  - Fit (slim, regular, oversized). Posture and camera angle distort it.
- **Unreliable from photos (ask the User, or drop):**
  - Fabric or material. Cotton, linen and rayon look alike.
  - Season. Infer it from category and fabric instead of detecting it.
  - Brand and size.
- **Use structured output with enums** so values stay within #11's fixed lists. Add an `unknown` value for every attribute rather than forcing a guess.

## 8. Shortlist for prototype #10

| # | Pipeline | Role |
|---|---|---|
| 1 | **Gemini 3.8 Flash** (one call per upload, boxes + attributes + merge) → **SAM 3 on fal.ai** (box-prompted masks) | Primary candidate |
| 2 | Same as 1, but with **Gemini 3.5 Flash-Lite** | Cheaper variant; compare quality per dollar |
| 3 | Gemini 3.8 Flash returning **segmentation masks itself** (no SAM 3) | Simpler; check mask quality, output-token cost and the `minimal`-thinking conflict |
| 4 | **Ximilar `detect_tags_all`** on the same 20 photos | Benchmark for detection and attributes; note handling of Indian wear and bystanders |
| 5 | Optional: **Nano Banana 2 Lite** clean shots for a few Items | Only to judge whether clean shots are needed at all |

**What #10 should log for each candidate:**

- Items missed and false detections (bystanders, background).
- Attribute errors and merge errors.
- Crop quality.
- Input and output tokens, so the cost estimate can be checked.
- Wall-clock latency.

## Open caveats

- Google publishes no latency or accuracy figures for detection or segmentation; measure them.
- The Gemini 3.8 Flash price doubles on 1 Jan 2027. Budget at the 2027 price.
- Gemini's mask format (PNG versus polygon) and its thinking-level requirement conflict across Google's own pages.
- The SAM 3 licence was confirmed only through fal's label and secondary summaries.
- Ximilar's plan prices were read from a garbled table.
