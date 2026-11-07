# Finding similar products to buy from Indian retailers

Research for [#5](https://github.com/suyashpatel98/WearAI/issues/5). It decides how a Suggested Item in a Post or in a Style Me reply gets its "where to buy" links.

Sources were read on **2026-11-06**. Most vendor pages carry no "last updated" date; where a page states a date, it is given. Prices are USD unless noted. Secondary sources (news, vendor blogs) are labelled as such and used only where no primary source exists.

## The question

Starting from a **generated image of a garment** or a **text description** of a Suggested Item, how can the app find similar products on Indian retailers (Myntra, Ajio, Amazon.in, Flipkart and others)? For each option, compare:

- coverage of Indian retailers
- image or text input
- price per lookup
- rate limits
- whether the terms allow use behind a mobile app

## Answer in brief

- **Google Lens has no official API.** Google's only official visual tools are Cloud Vision **Web Detection** (no shopping data, no domain filter) and **Vision API Product Search** (it searches only a catalogue you upload). Neither finds products on Myntra or Ajio.
- **Recommended (image input): Google Lens through a SERP-scraping API, called from the backend.**
  - Use **SearchApi.io** (from $4 per 1,000 lookups, falling to $2.50) or **SerpApi** (from $15 per 1,000, falling to about $9.17).
  - Send a garment-only image. Both accept `country=in`, and their `visual_matches` return a **direct merchant link** plus `price`, `currency` and stock where Google has them.
  - Filter results to an allow-list of Indian retailer domains.
  - Look up **on tap, not eagerly**, and cache per Suggested Item.
- **Recommended fallback (text input): retailer search deep links.**
  - The stylist model already writes a structured description of each Suggested Item. Turn it into a search query and build search URLs for Myntra, Ajio, Amazon.in and Flipkart.
  - This costs nothing and has no rate limit or scraping risk, and it always returns something.
  - Optionally wrap the URLs in affiliate links later through Cuelinks' `links/convert` API. Monetization is out of scope for the MVP.
  - The trade-off is that the app shows no product images or prices for these links.
- **Ruled out for the MVP:**
  - **Amazon Creators API** (PA-API 5 is deprecated). It needs **10 qualifying sales in the past 30 days** before access, and it only covers Amazon.
  - **Flipkart Affiliate API.** Its docs were last updated in 2016, and it is unclear whether direct sign-ups are open.
  - **EarnKaro.** It has no public API.
  - **Gemini "Grounding with Google Search".** Its terms forbid click or link tracking, interspersing other content, and storing results. Grounded results may only be shown to the end user who submitted the prompt, which rules it out for background Feed generation.
  - **Google Custom Search JSON API.** It is closed to new customers and ends on **2027-01-01**.
  - **Bing Visual Search.** It was retired with the other Bing Search APIs on **2025-08-11**.
  - **Vertex AI Search / Agent Search website search.** It costs $4 per 1,000 queries and is billed for every indexed page, so it is not meant for indexing other companies' catalogues.
- **Biggest risks:**
  1. Scrapers depend on Google's page layout. Google removed the Lens **Products** tab on **2026-10-07**, which killed SerpApi's and SearchApi's `products` mode.
  2. Lens quality on *AI-generated* garment images is unproven. A prototype ticket should measure it.
  3. A generated image shows the User's likeness. **Never send the User's face to a third party.** Send a crop of the garment, or a separately generated flat-lay image of the Suggested Item.

## Comparison

| Option | Indian retailer coverage | Input | Price per lookup | Rate limit | Terms for a mobile-app backend |
|---|---|---|---|---|---|
| **SearchApi.io Google Lens** | Whatever Google Lens indexes. India is in its list of countries with shopping results | Image URL (+ optional `q`) | $0.004 (10k/mo plan) → $0.0025 (100k) → $0.0015 (1M) | 20% of monthly credits per hour | Server-side use. "Legal Protection Guarantee" on Production and higher plans, US law, covers its collection, not your use |
| **SerpApi Google Lens** | Same as above. `country=in` supported | Image URL or uploaded `image_id` (+ optional `q`) | $0.015 (5k/mo) → $0.010 (15k) → $0.0092 (30k) → $0.00725 (100k) | 1,000/hr on Developer, 3,000/hr on Production | No reselling without permission. US Legal Shield from Production up. Search data kept 31 days unless ZeroTrace mode |
| SerpApi Google Shopping | Google Shopping India (`gl=in`) | Text | Same credits as above | Same | `product_link` points to Google, so a second call is needed for the merchant URL |
| **Retailer search deep links** (+ optional Cuelinks) | Any retailer with a search URL | Text | $0 | None | Plain links. Cuelinks campaign rules apply only if affiliate links are used |
| Amazon Creators API | Amazon.in only | Text (keywords, browse nodes) | Free | 1 TPS / 8,640 per day at first, scaling with referred revenue | Needs an Associates account plus **10 qualifying sales in 30 days**. Access lapses without sales |
| Flipkart Affiliate API | Flipkart only | Text search, or full product feed | Free | Not documented. 500 products per feed page | Registered affiliates only. Sign-up status unclear |
| Cuelinks API v3 | Link conversion for Myntra, Ajio, Flipkart and more (no product search) | Product URL | Free tier (read only). Write access is "Publisher Plus", revenue share | "Scales with plan" | Myntra campaign allows app tracking. Ajio's notes say app tracking is "offline" |
| EarnKaro | Myntra, Flipkart and more | Manual links only | — | — | No public API |
| Gemini Grounding with Google Search | Google Search | Text (+ image for image models) | $14 per 1,000 (Gemini 3+) after 5,000 free per month | 1,500 per day cap | Forbids link tracking, storage and mixing in other content. Results may only be shown to the user who sent the prompt |
| Cloud Vision Web Detection | The open web. No domain filter, no prices | Image | $3.50 per 1,000 after 1,000 free | Cloud quotas | Official, but not a shopping tool |
| Vision API Product Search | Only your own uploaded catalogue | Image | — | — | Needs a catalogue we don't have |
| Vertex AI / Agent Search (website) | Up to 50 domains. Advanced indexing needs domain verification | Text | $4 per 1,000 queries (Enterprise) + about $2.38/month per 1,000 indexed pages | Cloud quotas | Not designed for indexing other companies' catalogues |
| Custom Search JSON API | — | — | — | — | Closed to new customers. Ends 2027-01-01 |
| Bing Visual Search | — | — | — | — | Retired 2025-08-11 |

## 1. Google Lens

### No official API

- Google publishes no Lens API. A Google Cloud community moderator says "there is currently no public Google Cloud service that offers the exact same features and performance as Google Lens" and points retail use cases to Product Search. This is a forum answer, not documentation; no Google page states it either way. [Google Developer forums](https://discuss.google.dev/t/difference-google-lens-vs-google-cloud-vision-api/193387)
- **Cloud Vision Web Detection** returns web entities, matching images, pages with matching images and visually similar images. It has no price or merchant data and no domain filter. It costs $3.50 per 1,000 units after the first 1,000 free each month. [Detect web entities](https://cloud.google.com/vision/docs/detecting-web), [Cloud Vision pricing](https://cloud.google.com/vision/pricing)
- **Vision API Product Search** compares a query image against *product sets you create* from your own reference images. Its categories include apparel. No deprecation is listed on the Vision deprecations page. It would only help if we built our own catalogue from affiliate feeds (see §5). [Product Search docs](https://docs.cloud.google.com/vision/product-search/docs), [Vision deprecations](https://cloud.google.com/vision/docs/deprecations)
- Google's Terms of Service forbid "using automated means to access content from any of our services in violation of the machine-readable instructions" (effective 2026-07-30). That is why the wrappers below exist as third parties that take on the scraping. [Google Terms of Service](https://policies.google.com/terms?hl=en-US)

### Unofficial wrappers: SearchApi.io and SerpApi

Both run Google Lens for you and return JSON.

- **Input.** A public image URL (`url`). SerpApi also accepts an `image_id` from its upload API. Both take an optional text `q` to steer results, and `country` (India is `in`). [SerpApi Google Lens API](https://serpapi.com/google-lens-api), [SerpApi Lens countries](https://serpapi.com/google-lens-countries), [SearchApi Google Lens](https://www.searchapi.io/docs/google-lens)
- **Result types.** `all`, `visual_matches` and `exact_matches`.
  - The **`products` type is gone.** SearchApi: "As of October 7, 2026, Google Lens no longer has a Products tab". SerpApi: "Google has discontinued the Products search type in Google Lens." [SearchApi Google Lens](https://www.searchapi.io/docs/google-lens), [SerpApi Lens Products (discontinued)](https://serpapi.com/google-lens-products-api)
- **Shopping data in `visual_matches`.**
  - SerpApi documents `title`, `link` (the merchant page), `source`, `thumbnail`, `rating`, a `price` object (`value`, `extracted_value`, `currency`) and `in_stock`. [SerpApi Lens Visual Matches](https://serpapi.com/google-lens-visual-matches-api)
  - SearchApi documents `price`, `extracted_price`, `currency` and `stock_information`, and notes that "Some visual matches carry price and stock". It lists **India** among the countries with Lens shopping results. [SearchApi Google Lens](https://www.searchapi.io/docs/google-lens)
  - Not every match has a price. Lens also returns non-retail pages such as Pinterest and blogs, so **filter by an allow-list of retailer domains**: myntra.com, ajio.com, amazon.in, flipkart.com, plus candidates such as nykaafashion.com, tatacliq.com and meesho.com.
  - **Not verified here:** how often Lens on an Indian-locale query actually returns Myntra/Ajio/Flipkart pages for *generated* images. Neither vendor publishes this. It needs a prototype.
- **SerpApi pricing** (no date on page). [SerpApi pricing](https://serpapi.com/pricing)

  | Plan | $/month | Searches/month | Searches/hour | $ per 1,000 | US Legal Shield |
  |---|---|---|---|---|---|
  | Free | 0 | 250 | 50 | — | No |
  | Starter | 25 | 1,000 | 200 | 25.00 | No |
  | Developer | 75 | 5,000 | 1,000 | 15.00 | No |
  | Production | 150 | 15,000 | 3,000 | 10.00 | Yes |
  | Big Data | 275 | 30,000 | 6,000 | 9.17 | Yes |
  | Searcher | 725 | 100,000 | 20,000 | 7.25 | Yes |
  | Volume | 1,475 | 250,000 | 50,000 | 5.90 | Yes |

- **SearchApi.io pricing** (no date on page). Every plan may use at most 20% of its monthly credits per hour. [SearchApi pricing](https://www.searchapi.io/pricing)

  | Plan | $/month | Searches/month | $ per 1,000 | Legal Protection Guarantee |
  |---|---|---|---|---|
  | Developer | 40 | 10,000 | 4.00 | Not listed |
  | Production | 100 | 35,000 | 3.00 | Yes |
  | BigData | 250 | 100,000 | 2.50 | Yes |
  | Scale | 500 | 250,000 | 2.00 | Yes |
  | Octo 1M | 1,500 | 1,000,000 | 1.50 | Yes |

- **Terms (SerpApi, "Legal Documents", last updated 2026-08-27).** [SerpApi legal](https://serpapi.com/legal)
  - No clause forbids showing results to end users in your own app. You may not "resell or exploit" the Service without written permission.
  - "SerpApi assumes liability for the lawful collection of public search data", but not for how the data is used. You indemnify them for your breaches.
  - The Legal Shield is limited to **US** claims in US courts. It gives an India-based app little comfort.
  - Search data is retained for **31 days**. ZeroTrace mode stores nothing. This matters for privacy (see §6).
- **SearchApi's guarantee** covers Production and higher plans, up to $2M, under US law. It covers their collection and parsing, "not your use of the data". [SearchApi pricing](https://www.searchapi.io/pricing)
- **Litigation risk (secondary sources).**
  - Google sued SerpApi under the DMCA in December 2025 (N.D. Cal., 25-cv-10826-YGR).
  - On 2026-07-20 the court dismissed all claims, partly with leave to amend.
  - The wrappers survive for now, but Google keeps changing Lens (e.g. removing the Products tab), so expect breakage.
  - [PPC Land, 2026-07-21](https://ppc.land/google-loses-dmca-bid-to-treat-search-scraping-like-dvd-piracy/), [IPWatchdog, 2025-12-26](https://ipwatchdog.com/2025/12/26/google-sues-serpapi-parasitic-scraping-circumvention-protection-measures/)
- **Serper.dev** lists Search, Images, Shopping and others, but no Lens endpoint. [Serper](https://serper.dev/)

### Google Shopping (text) through a wrapper

- SerpApi's `google_shopping` engine takes `q`, `gl` (`in`), `min_price`/`max_price` and sorting. It returns `title`, `price`, `extracted_price`, `source` (seller), `thumbnail` and `rating`. [SerpApi Google Shopping API](https://serpapi.com/google-shopping-api)
- `product_link` is a **Google** URL, not the merchant's. Getting the merchant link costs a second call per product.
- Pagination is ignored; each call returns about 40 items.
- This makes it worse than Lens `visual_matches` (direct merchant links) for our use. It is a fallback only if image quality disappoints.

## 2. Other Google options

- **Custom Search JSON API.** "Closed to new customers". Existing customers "have until January 1, 2027". Google suggests Vertex AI Search "for searching up to 50 domains". [Custom Search JSON API overview](https://developers.google.com/custom-search/v1/overview)
- **Vertex AI Search (now "Agent Search").** [Agent Search pricing](https://cloud.google.com/generative-ai-app-builder/pricing), [Advanced website indexing](https://docs.cloud.google.com/generative-ai-app-builder/docs/turn-on-advanced-indexing)
  - Website search needs the Enterprise edition at **$4.00 per 1,000 queries**. Website storage is billed at 500 KiB per page, about **$2.38/month per 1,000 pages**.
  - Basic website search over public sites needs no domain verification. Advanced indexing does.
  - Indexing millions of Myntra/Ajio product pages would be costly. Coverage of the basic index is whatever Google already crawled, and it returns web pages, not structured products.
  - Vertex AI Search *for commerce* searches *your own* catalogue.
- **Gemini API Grounding with Google Search.**
  - **Price.** Gemini 3+ models get 5,000 free search requests a month, then **$14 per 1,000**, capped at 1,500 per day. Gemini 2.5 Flash is $35 per 1,000 grounded prompts after 1,500 per day. [Gemini API pricing](https://aistudio.google.com/docs/pricing)
  - **Terms (Gemini API Additional Terms, effective 2026-03-23).** [Gemini API terms](https://aistudio.google.com/docs/terms)
    - Only "in an application that is owned and operated by you", and grounded results are shown only "to the end user who submitted the prompt". Feed Posts are generated in the background, not from a User's prompt.
    - "Will not … cache, frame, syndicate, resell, copy, store, or implement any click tracking, Link-tracking or other monitoring of Grounded Results". This rules out affiliate wrapping and caching per Suggested Item.
    - "Will not modify, or intersperse any other content with, the Grounded Results or Search Suggestions", and Search Suggestions must be displayed with them.
    - No "using Links to build an index".
  - **Verdict.** Usable at most as a live, in-chat aid in Style Me, shown exactly as Google requires. Not usable as the Post buy-link source.
- **Google Merchant Center / Merchant API.** These are for merchants managing their own listings, not for searching other people's products. Not applicable.

## 3. Amazon.in: Creators API (replaces PA-API 5)

- **Status.** PA-API 5 "has been deprecated". "New and existing integrations should move to the Creators API". The page states no exact sunset date. Secondary sources cite 2026-04-30/05-15. [PA-API 5 deprecation](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/paapiv5-deprecation)
- **India is supported** (`www.amazon.in`). [Locale reference (amazon.in)](https://affiliate-program.amazon.in/creatorsapi/docs/en-us/locale-reference)
- **Operations.** `SearchItems` (keywords, filters, browse nodes), `GetItems`, `GetVariations` and `GetBrowseNodes`. Input is **text only**. [Creators API introduction (amazon.in)](https://affiliate-program.amazon.in/creatorsapi/docs/en-us/introduction)
- **Eligibility.** "Have at least **10 qualifying sales within the past 30 days** to access the PA API through the Creators API." A brand-new app cannot get access until it already drives Amazon sales through plain affiliate links. [Creators API introduction (amazon.in)](https://affiliate-program.amazon.in/creatorsapi/docs/en-us/introduction)
- **Rate limits.** [API rates (amazon.in)](https://affiliate-program.amazon.in/creatorsapi/docs/en-us/concepts/api-rates)
  - 1 TPS and 8,640 per day for the first 30 days.
  - After that, limits scale with shipped revenue referred through the API: 1 TPD per 5 cents, 1 TPS per $4,320, up to 10 TPS.
  - Access is lost after 30 days with no referred sales.
- **Price.** Free, paid for by affiliate commission.
- **Verdict.** A later add-on for Amazon.in with images and prices. Not available at launch.

## 4. Affiliate networks and retailer feeds

- **Flipkart Affiliate API.** [Product APIs reference](https://affiliate.flipkart.com/api-docs/af_prod_ref.html), [Changelog](https://affiliate.flipkart.com/api-docs/af_changelog.html)
  - Offers a keyword search API, a product-ID API, and per-category **product feeds**. Feeds come in 500-product pages with multi-resolution `imageUrls` and MRP/selling/special prices in INR.
  - Auth uses `Fk-Affiliate-Id` and `Fk-Affiliate-Token` headers. Feed URLs are valid for 10 hours. No rate limit is documented.
  - The docs say "Last updated: 27 July 2016".
  - The affiliate homepage offers login only, with no visible sign-up. Third parties (Cuelinks, Haulpack; secondary, self-interested) say direct sign-ups are often closed. **Treat it as unavailable until a sign-up succeeds.** [affiliate.flipkart.com](https://affiliate.flipkart.com/)
- **Cuelinks (API v3).** [Cuelinks developers](https://developers.cuelinks.com/)
  - Endpoints include `GET /pub_api/v3/campaigns`, `POST /pub_api/v3/links/convert` ("Convert any URL to a tracked affiliate link"), `links/monetize`, transactions and reports. **There is no product search or product feed endpoint.**
  - The Starter tier is free with `read:campaigns` only. Write scopes (link conversion) need "Publisher Plus", which is revenue share, contact sales. Rate limits "scale with your plan". An older help-centre article says API tokens went only to publishers earning more than ₹10,000 a month. The new developer portal does not repeat this, so confirm at sign-up.
  - **Myntra campaign** (page titled November 2026): [Cuelinks Myntra](https://www.cuelinks.com/campaigns/myntra-affiliate-program)
    - 7.5% on new-user and 3.75% on existing-user sales.
    - Android and iOS app tracking enabled, deep links allowed, India only, 1-day attribution.
    - No Telegram sharing. Budget-based, so contact the advertiser first.
  - **Ajio campaign** (payouts listed from 2026-11-02): [Cuelinks Ajio](https://www.cuelinks.com/campaigns/ajio-affiliate-program)
    - 4.5–10.8% by category.
    - **Contradictory:** the app tracking icons are on, but the notes say app tracking is "offline" and list "API traffic" and "App Track" as forbidden. Confirm with Cuelinks before relying on Ajio affiliate links in-app.
- **EarnKaro (CashKaro).** Its site describes manual "copy & convert" of deals for Flipkart, Myntra and 200+ brands. It mentions no API or developer access. [EarnKaro](https://earnkaro.com/)
- **Myntra / Ajio own APIs.** We found no public product API or feed for either. Myntra's program runs through networks (Cuelinks, vCommission and others; secondary sources). [vCommission Myntra](https://www.vcommission.com/publishers/turn-fashion-trends-into-commissions-with-myntra-affiliate-program)

## 5. Visual-search APIs and our own index

- **Bing Visual Search.** Retired with the Bing Search APIs on **2025-08-11**. Microsoft points to "Grounding with Bing Search" in Azure AI Agents. [Microsoft lifecycle announcement](https://learn.microsoft.com/en-us/lifecycle/announcements/bing-search-api-retirement)
- **Retailer-side visual search vendors** (Vision API Product Search, Vertex AI Search for commerce and similar B2B tools) all search a catalogue **you supply**.
- **Building our own index** is a post-MVP option. It would mean ingesting affiliate feeds (Flipkart feed if sign-up works, network feeds), embedding the product images, and querying with the Suggested Item image. It gives control and stable terms. But it needs feed access we don't have and adds ongoing ingestion work for one developer.

## 6. Recommended design

1. **Make the stylist model output a structured Suggested Item.** Include category, colour, fabric, pattern, fit, gender and price band. This serves the text fallback and later the Amazon/Flipkart APIs.
2. **Use a garment-only image for visual search.** Crop the Suggested Item from the generated image (the item-detection pipeline in #6 already produces boxes and masks), or generate a flat-lay image of it.
   - Host it at a short-lived public URL.
   - **Never send an image containing the User's face or body to a SERP vendor.** SerpApi keeps search data 31 days unless ZeroTrace is on.
3. **Look up on tap, server-side.** When the User opens a Suggested Item's "where to buy", call Lens through SearchApi.io (or SerpApi) with `country=in` and an optional `q` from the description (e.g. "women mustard cotton kurta").
   - Keep `visual_matches` from allow-listed Indian retailer domains. Show up to N with thumbnail and price where present.
   - Cache the result per Suggested Item.
4. **Always show the deep-link fallback.** Add "Search on Myntra / Ajio / Amazon.in / Flipkart" buttons built from the text description. They cover zero Lens results, vendor outages and layout changes.
5. **Keep vendor keys on the backend.** Never ship them in the APK. Put the vendor behind a single interface so SerpApi and SearchApi can be swapped.
6. **Affiliate wrapping is a post-MVP switch.** Cuelinks `links/convert` on each outbound link would add it. Monetization is out of scope.

### Rough cost per User

These assumptions are illustrative, not measured. Up to 10 generated images a day (5 Posts + 5 Style Me), about 1.5 Suggested Items each, so at most about 15 lookups per User per day if done eagerly.

| Strategy | Lookups per User per month | SearchApi @ $2.50/1k | SerpApi @ $9.17/1k |
|---|---|---|---|
| Eager (every Suggested Item) | ~450 | ~$1.13 | ~$4.13 |
| On tap, ~10% of Suggested Items, cached | ~45 | ~$0.11 | ~$0.41 |

Text deep links add $0.

## Open questions

- **Quality on generated images (needs a prototype).** On, say, 30 generated Suggested Items, including Indian ethnic wear, what share of Lens `visual_matches` with `country=in` land on allow-listed Indian retailers, carry a price, and look "similar"? Compare a tight crop, a flat-lay regeneration, and adding a `q` hint.
- **Ajio in-app affiliate tracking** contradicts itself on Cuelinks. Ask Cuelinks before monetizing.
- **Flipkart Affiliate sign-up**: is it actually open in late 2026?
- **Amazon Associates India and app traffic**: the operating agreement for in-app use was not reviewed here. It matters only once Creators API access is in reach.
