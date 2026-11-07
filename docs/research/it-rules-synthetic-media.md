# Do India's IT Rules on AI-generated media apply to WearAI?

Research for ticket #13 (map #1). Researched 2026-11-06.

> **This is research, not legal advice.** It summarises primary-source text as read on 2026-11-06. Have an Indian technology lawyer confirm the points marked **Open** before launch.

## Answer in one paragraph

Yes. Build WearAI as if the synthetic-media rules apply to it. Every Feed Post and Style Me image is a photorealistic picture of a real, identifiable person (the User) in clothes they were not wearing. That fits the definition of "synthetically generated information" (SGI) in Rule 2(1)(wa), and none of its three exclusions applies. WearAI receives and stores Users' photos on their behalf, so it is an "intermediary" under s.2(1)(w) of the IT Act. MeitY's own FAQ names "AI image/video generation or editing tools" as covered by the new Rule 3(3). The rules make no exception for images shown only to the person who made them. The concrete duties are:

- **Label.** A prominent visible "AI-generated" label on every generated image.
- **Provenance.** Permanent embedded metadata with a unique identifier that names WearAI as the source. C2PA fits this. The duty applies "to the extent technically feasible".
- **No stripping.** No feature that removes the label or the metadata.
- **Blocking.** Technical measures that block unlawful SGI, such as sexual or "undressing" output, images of someone who is not the User, and fake documents.
- **Warnings.** An SGI misuse warning at onboarding and at least every 3 months.
- **Grievance Officer.** A named Grievance Officer reachable from the home screen. Complaints are acknowledged in 24 hours and resolved in 7 days. Removal requests take 36 hours. Complaints about nudity or morphed images take **2 hours**.
- **Orders.** Removal within **3 hours** of a court order or an authorised government intimation.
- **Retention.** Removed content is kept for 180 days, and registration data for 180 days after an account is deleted.

WearAI is **not** a social media intermediary, so the extra duties for significant social media intermediaries in Rule 4(1A) (user declaration and verification) do not apply. A draft second amendment would require the label to stay visible "throughout the duration of the content". As of September 2026 it was still a draft.

## Primary sources and their dates

| Source | Date | What it is |
|---|---|---|
| G.S.R. 120(E), IT (Intermediary Guidelines and Digital Media Ethics Code) Amendment Rules, 2026. Gazette of India Extraordinary, eGazette **CG-DL-E-10022026-269993**. [MeitY PDF](https://www.meity.gov.in/static/uploads/2026/02/f55fe52418b03f58b0669f6a8bc03b6d.pdf) · [eGazette](https://egazette.gov.in/WriteReadData/2026/269993.pdf) | Notified **10 Feb 2026**. In force **20 Feb 2026** (rule 1(2)) | The binding amendment text. Read in full. |
| Consolidated IT Rules, 2021 "[updated as on 10.02.2026]". [MeitY PDF](https://www.meity.gov.in/static/uploads/2026/02/550681ab908f8afb135b0ad42816a1c9.pdf) | 10 Feb 2026 | MeitY's consolidated text. Used for the unamended rules the 2026 changes sit inside, such as Rules 3(1)(g), 3(1)(h) and 3(2). |
| MeitY, *Frequently Asked Questions on the IT … Amendment Rules, 2026*. [MeitY PDF](https://www.meity.gov.in/static/uploads/2025/10/065b6deb585441b5ccdf8be42502a49c.pdf) | Dated 10 Feb 2026 | MeitY's interpretation. It states that it "is not a legal document" and is "an evolving document". |
| Information Technology Act, 2000 (updated). [India Code PDF](https://www.indiacode.nic.in/bitstream/123456789/13116/1/it_act_2000_updated.pdf) | As published on India Code | s.2(1)(w) "intermediary", s.2(1)(za) "originator", s.79 safe harbour. |
| MeitY Advisory No. 2(6)/2024-CL&DG-Part(1), on AI platforms' due diligence. [MeitY PDF](https://www.meity.gov.in/static/uploads/2026/02/c19f3a28a6aa2128e51b0fd22d82626a.pdf) | 9 Feb 2026 | States MeitY's view that "AI platforms, AI tool providers" are intermediaries with due-diligence duties. |
| Draft *Second Amendment Rules, 2026*. [MeitY PDF](https://www.meity.gov.in/static/uploads/2026/03/30591fc6e322dcbcc9dae84a0f02e9e7.pdf) | Published 30 Mar 2026 | Draft only. |
| MeitY Notice extending consultation and adding a Rule 3(3)(a)(ii) change. [MeitY PDF](https://www.meity.gov.in/static/uploads/2026/04/ec197f1206279efb4964965f0dede6c1.pdf) | 21 Apr 2026 | Proposes a "continuous and clearly visible" label. Comments were due 7 May 2026. |
| PIB, *Government Strengthens Regulatory Framework to Address AI-Generated Deepfakes*. [PIB](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2295500) | 6 Aug 2026 | Government summary. Confirms the 2-hour and 3-hour timelines, and the SSMI threshold of 50 lakh users. |

Secondary sources, used only for status checks and labelled where cited:
- AZB & Partners, *India AI Regulatory Update*, 8 Sep 2026 ([PDF](https://www.azbpartners.com/wp-content/uploads/2026/09/India-AI-Regulatory-Tracker-2nd-Ed-Correct-Final.pdf)).
- Hogan Lovells, as cited in the #7 research.

## 1. Is WearAI in scope?

### 1a. WearAI's images are "synthetically generated information"

Rule 2(1)(wa) (gazette text):

> "'synthetically generated information' means audio, visual or audio-visual information which is artificially or algorithmically created, generated, modified or altered using a computer resource, in a manner that such information appears to be real, authentic or true and depicts or portrays any individual or event in a manner that is, or is likely to be perceived as indistinguishable from a natural person or real-world event"

The images meet every part of this. They are visual. They are generated by an algorithm. They are meant to look real, since a try-on that keeps the User's likeness is the product's whole point (see #4). They depict a real individual.

The proviso excludes three kinds of output. None of them covers WearAI's images:

- **(a) Routine or good-faith editing** is excluded only when it "does not materially alter … the substance". Changing what a person is wearing alters the substance.
- **(b) Documents, presentations and educational material.** WearAI's images are none of these.
- **(c) Accessibility, clarity or translation** is excluded only when the tool works "without generating, altering … any material part".

The MeitY FAQ (Q28) lists "AI-generated realistic image of a person participating in an event" as an example of SGI. Text-only output is not SGI (FAQ Q8). So the Stylist's written descriptions of Outfits and Suggested Items are outside the SGI rules, but the general unlawful-content duties still cover them.

### 1b. WearAI is an "intermediary", at least for the photos it stores

IT Act s.2(1)(w):

> "'intermediary', with respect to any particular electronic records, means any person who on behalf of another person receives, stores or transmits that record or provides any service with respect to that record …"

The definition is **per record**:

- **Reference Photos and camera-roll photos.** WearAI receives and stores these on the User's behalf, so it is an intermediary for them without much doubt.
- **Style Me images.** The User directs the generation, so WearAI is providing "any service with respect to" the User's inputs. MeitY's FAQ Q20 says Rule 3(3) covers "AI image/video generation or editing tools", with the example "An intermediary offering a tool that can generate realistic AI videos … is covered under Rule 3(3)". The 9 Feb 2026 advisory says "intermediaries, including AI platforms, AI tool providers, and social media intermediaries, have a due diligence obligation" and that "these obligations apply equally to content generated or amplified through AI systems".
- **Feed Posts.** These are less clear. WearAI's background job starts each generation, chooses the Outfit and picks the only viewer. Under s.79(2)(b), safe harbour requires that the intermediary "does not (i) initiate the transmission, (ii) select the receiver … and (iii) select or modify the information". For Feed Posts WearAI arguably does all three, which makes it closer to the **originator** (s.2(1)(za)) of those images than to an intermediary.

**This uncertainty does not reduce WearAI's exposure.** If WearAI is an intermediary for Feed Posts, Rule 3(3) applies directly. If it is the originator, it has no s.79 safe harbour for those images and answers for them directly under the IT Act and the Bharatiya Nyaya Sanhita. Either way, it must keep unlawful images from being generated. And because it is an intermediary for the stored photos and Style Me in any case, the Rule 3 duties attach to the app. The cheapest position is to apply Rule 3(3) to every generated image. **Open:** a lawyer should confirm how Feed Posts are classified.

### 1c. Private, unshared images are not exempt

Rule 3(3)(a) covers any intermediary that "offers a computer resource which may enable, permit, or facilitate the **creation, generation**, modification, alteration, publication, transmission, sharing, or dissemination" of SGI. Creation alone is enough to bring a service into scope. Publishing or sharing is not required. Rule 3(3)(a)(ii) then requires that "**every** such information" not prohibited under (i) be labelled and carry metadata. Neither the rules nor the FAQ make an exception for content shown only to its creator. A User could screenshot an image, so labelling it still serves the rule's purpose.

### 1d. Which tier: not a social media intermediary or an SSMI

A "social media intermediary" is one that "primarily or solely enables online interaction between two or more users" (Rule 2(1)(w)). The MVP has no sharing and no comments ("Out of scope" on the map), so WearAI does not qualify. Rule 4(1A), with its user declaration, verification and SSMI labelling duties, applies only to significant social media intermediaries. The threshold for those is 50 lakh registered users in India (PIB, 6 Aug 2026). **Adding sharing or comments later would change this analysis.**

## 2. The duties, and what each changes in WearAI

Rule numbers refer to the IT Rules, 2021 as amended by G.S.R. 120(E). "New" marks text introduced or changed on 10 Feb 2026.

### A. Generation pipeline

| Duty | Rule (text) | What WearAI must build |
|---|---|---|
| **Block unlawful SGI** (new) | 3(3)(a)(i): deploy "reasonable and appropriate technical measures, including automated tools … to not allow any user to create, generate …" SGI that violates any law. This expressly includes (I) CSAM, NCII, "obscene, pornographic … invasive of another person's privacy, including bodily privacy, vulgar, indecent or sexually explicit"; (II) false documents or electronic records; (III) explosives, arms or ammunition; (IV) content that "falsely depicts … a natural person … in a manner that is likely to deceive". | Put checks on **inputs and outputs**, not only on the model provider's filters. **(1) Reference Photo gate:** exactly one adult person, the same face across all 1–3 photos, no nudity, and the User's attestation that the photos are of themselves. This addresses NCII and impersonation through someone else's photos. FAQ Q21 gives as an example "AI-generated intimate photo/video of a person created using their real photographs". **(2) Style Me prompt filter:** refuse requests to undress, sexualise, add or swap another person, or produce documents, IDs or weapons. **(3) Output check before display:** run a safety classifier on every generated image and drop failures. Never show them, and log them. **(4) Item policy:** decide whether underwear, lingerie and swimwear Items are ever rendered on the User. "Vulgar, indecent" is vague, and the #7 Play findings already ban sexual output. Use Gemini's own safety settings as one layer, not the only one. |
| **Visible label** (new) | 3(3)(a)(ii): SGI must be "prominently labelled in a manner that ensures prominent visibility in the visual display that is easily noticeable and adequately perceivable … that can be used to immediately identify that such information is synthetically generated". FAQ Q22 example: a "visible 'synthetically generated' notice". | Put a visible **"AI-generated"** mark on every Post and Style Me image. **Burn it into the pixels** when the image is generated, not only as a UI overlay. A pixel label survives screenshots and any later save or export feature, and it already meets the draft "continuous" wording (§3). A UI badge can be added as well. This does not affect shopping search, which by map decision only ever receives garment-only images. |
| **Permanent metadata with a unique ID** (new) | 3(3)(a)(ii): SGI "shall be embedded with a permanent metadata or other appropriate technical provenance mechanisms, **to the extent technically feasible**, including a **unique identifier**, to identify the **computer resource of the intermediary** used to create, generate, modify or alter such information". | Embed provenance in the stored image file that names **WearAI**, not just Google, with a per-image UUID. The full option is a **C2PA manifest**: claim generator "WearAI", digital source type `trainedAlgorithmicMedia`, image UUID, and a signature. A minimum is XMP/IPTC fields carrying the same data. Google's SynthID identifies Google's model, not WearAI. The Gemini API docs say "All generated images include a SynthID watermark" ([AI Studio docs](https://aistudio.google.com/docs/image-generation), read 2026-11-06) but do not mention C2PA for API output. SynthID therefore does not meet the "computer resource of the intermediary" wording on its own. A C2PA signer needs an X.509 certificate. A "conforming" generator must use a CA on the C2PA trust list ([CAI docs](https://opensource.contentauthenticity.org/docs/signing/get-cert)). For the MVP, a self-signed or unconforming manifest plus IPTC fields is a defensible reading of "to the extent technically feasible". **Open.** |
| **No stripping** (new) | 3(3)(b): "the intermediary shall not enable the modification, suppression or removal of the label, permanent metadata, including the unique identifier". FAQ Q23: do not offer "remove watermark", "export without metadata", or similar features. | Every resize, thumbnail, CDN transform or recompression step must **keep or re-embed** the metadata. Test the Supabase Storage image path for this, since many transforms strip EXIF and XMP. Add no "clean download" option. Any future save-to-device or share feature must export the labelled, metadata-bearing file. |

### B. In-app notices and terms

| Duty | Rule | What WearAI must build |
|---|---|---|
| Publish terms, a privacy policy and a user agreement that prohibit the listed content | 3(1)(a)–(b) (2022 text) | The terms of service must list the 3(1)(b) prohibited categories. These include content that "impersonates another person" and content "invasive of another's privacy including bodily privacy". The terms must be prominently available in the app. Rule 3(1)(a) says "in English or any language specified in the Eighth Schedule … in the language of his choice". **Open:** whether English alone is enough. This is the same question as the DPDP notice languages already listed on the map. |
| **Notice every 3 months** (new: was yearly) | 3(1)(c): "at least once every three months, in a simple and effective manner", covering the right to suspend or terminate, user liability, and the reporting of offences | Show an in-app notice (modal or screen) on first launch and again whenever 90 days have passed since the User last saw it. Store a per-User timestamp as evidence. |
| **SGI misuse warning** (new) | 3(1)(ca): services that enable SGI must "additionally inform" users that misuse may attract punishment under the IT Act, BNS, POCSO, the Indecent Representation of Women Act and others, and may lead to removal, suspension, **identity disclosure to a victim**, and reporting. FAQ Q12: "prominently communicated (including at onboarding and periodically)". The FAQ's example text: "Do not create deepfakes, impersonation content or non-consensual intimate imagery. Violations may result in removal/disablement of access, account action and legal consequences." | Add this to the onboarding screen where Reference Photos are uploaded, and to the 3-month notice. |
| **Act on violations** (new) | 3(1)(cb): on becoming aware of a 3(3) violation, take "expeditious and appropriate action", including removal and suspension "without vitiating the evidence" | Build an admin action that disables an image, suspends a User and freezes the evidence (see C). |

### C. Grievances, takedowns, retention (operations)

| Duty | Rule | What WearAI must build |
|---|---|---|
| **Grievance Officer** published "prominently" | 3(2)(a). "Prominently publish" means on the home screen of the app "or on … an app screen directly accessible from the … home screen" (Explanation). | Publish a named Grievance Officer (the developer can fill this role) with an email address, reachable in one tap from the home screen, for example a Settings → Grievance link. Also publish it on the privacy-policy web page. The same contact can serve the DPDP grievance channel from #7. |
| Acknowledge in **24 h**, resolve in **7 days** (new: was 15) | 3(2)(a)(i) | Send an automatic acknowledgement email. Track each ticket against its deadline. |
| Removal requests under 3(1)(b): **36 h** (new: was 72) | 3(2)(a)(i), first proviso | The same channel, with a shorter deadline for removal requests. |
| Nudity, sexual or **"artificially morphed images"** of the complainant: **2 h** (new: was 24) | 3(2)(b). The complaint may come from "an individual or any person on his behalf". 3(2)(c) requires a way to receive these complaints. | This is the likeliest real event: a person whose photo another User uploaded as a Reference Photo. Add an in-app and web report form with its own "image of me without consent" category. Route it so it **alerts a phone at any hour** (push or SMS, not just email). Provide a one-step admin action to disable all images derived from the reported Reference Photos. |
| Court or government orders: **3 h** (new: was 36) | 3(1)(d). Knowledge arises only from a court order or a reasoned written intimation from an authorised officer. 3(2)(a)(ii) requires that such orders be received and acknowledged. PIB (6 Aug 2026) says notices also arrive through I4C's **SAHYOG** portal. | Monitor the order inbox all the time and alert a phone. Use the same disable action. **Signed-URL lifetime matters.** If images are served through long-lived Supabase signed URLs, deleting a row does not revoke a URL already issued. Keep signed-URL lifetimes well under 3 hours, or proxy access. **Open:** whether a solo developer must register on SAHYOG. |
| Preserve removed content and records for **180 days** | 3(1)(g) (2021 text) | Disabling an image must **move it to a locked evidence store**, not delete it. Keep it with its logs and inputs, then purge after 180 days unless a court or agency asks for longer. |
| Keep registration data **180 days after account deletion** | 3(1)(h) (2021 text) | This conflicts with Play's account-deletion rule and the DPDP erasure rule. Add it to the map's existing "Photo retention and account deletion" item. Registration data probably means the Google account identifiers, not photos. **Open.** |
| Give information to authorised agencies within **72 h** | 3(1)(j) | Make sure the developer can export a User's account data and logs on request. |
| Report cyber-security incidents to CERT-In | 3(1)(l) | Not researched here (see §5). |

### D. What happens if WearAI does not comply

Rule 7: if an intermediary fails to observe the rules, s.79(1) safe harbour "shall not be applicable", and it is "liable for punishment under any law", including the Bharatiya Nyaya Sanhita, 2023. Rule 2(1B) (new) gives comfort in the other direction. Removing SGI in compliance with the rules, including by automated tools, does not by itself cost safe harbour.

## 3. Pending change: the draft Second Amendment Rules, 2026

- **30 Mar 2026 draft.** Intermediaries must comply with any MeitY "clarification, advisory, order, direction, standard operating procedure, code of practice or guideline", and doing so becomes part of s.79 due diligence (draft Rule 3(4)). If notified, advisories like the 9 Feb 2026 one would become binding.
- **21 Apr 2026 addition.** Rule 3(3)(a)(ii) would require a "continuous and clearly visible display of label … throughout the duration of the content in visual display". That matters most for video. A label burned into each still image already meets it.
- **Status.** Comments closed 7 May 2026. The AZB tracker of 8 Sep 2026 (secondary) still lists it as "Draft for public consultation". No notified G.S.R. was found up to 2026-11-06. **Check egazette before launch.**

## 4. Open questions for a lawyer

1. Is WearAI an intermediary, or the originator, for **Feed Posts** that it generates without a User prompt? This decides whether s.79 safe harbour is available for them (§1b).
2. Does an unconforming or self-signed C2PA manifest, or IPTC/XMP fields alone, satisfy "to the extent technically feasible"? Or is a C2PA trust-list certificate expected?
3. Does Rule 3(1)(a)'s "in the language of his choice" require terms in more than English? This overlaps with the DPDP notice-language question.
4. How do Rule 3(1)(h) (180-day registration retention) and Rule 3(1)(g) (180-day evidence preservation) fit with Play account deletion and DPDP erasure?
5. Does a small intermediary need to register on the SAHYOG portal to receive takedown notices?
6. Is a self-attestation that "these Reference Photos are of me", plus a face-consistency check, a "reasonable and appropriate technical measure" against non-consensual depiction?

## 5. Out of scope here, but likely relevant

- **CERT-In incident reporting** under Rule 3(1)(l) and the CERT-In Directions. These are general to every intermediary and were not researched. **Suggest a ticket.** It belongs with security and breach handling, alongside the DPDP breach duties from #7.
- **Choosing the safety classifier** and how strict the Item policy is (underwear and swimwear). This belongs to the map's "Content safety for generated images" item.
- **Sharing or comments in a later version** would make WearAI a social media intermediary. That brings user interaction into scope and, at 50 lakh users, SSMI duties under Rule 4. The MVP excludes these features, so nothing changes now.

## Sources (all read 2026-11-06)

Primary:
- G.S.R. 120(E), 10 Feb 2026 (CG-DL-E-10022026-269993): [MeitY](https://www.meity.gov.in/static/uploads/2026/02/f55fe52418b03f58b0669f6a8bc03b6d.pdf), [eGazette](https://egazette.gov.in/WriteReadData/2026/269993.pdf)
- Consolidated IT Rules, 2021, updated as on 10.02.2026: [MeitY](https://www.meity.gov.in/static/uploads/2026/02/550681ab908f8afb135b0ad42816a1c9.pdf)
- MeitY FAQs on the Amendment Rules, 2026 (10 Feb 2026): [MeitY](https://www.meity.gov.in/static/uploads/2025/10/065b6deb585441b5ccdf8be42502a49c.pdf)
- MeitY Advisory on AI platforms' due diligence, 9 Feb 2026: [MeitY](https://www.meity.gov.in/static/uploads/2026/02/c19f3a28a6aa2128e51b0fd22d82626a.pdf)
- Draft Second Amendment Rules, 2026 (30 Mar 2026): [MeitY](https://www.meity.gov.in/static/uploads/2026/03/30591fc6e322dcbcc9dae84a0f02e9e7.pdf)
- MeitY Notice, 21 Apr 2026 (consultation extension and Rule 3(3)(a)(ii) change): [MeitY](https://www.meity.gov.in/static/uploads/2026/04/ec197f1206279efb4964965f0dede6c1.pdf)
- Information Technology Act, 2000 (updated): [India Code](https://www.indiacode.nic.in/bitstream/123456789/13116/1/it_act_2000_updated.pdf)
- PIB, 6 Aug 2026, *Government Strengthens Regulatory Framework to Address AI-Generated Deepfakes*: [PIB](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2295500)
- Gemini API image generation docs (SynthID statement): [Google AI Studio docs](https://aistudio.google.com/docs/image-generation)
- C2PA signing certificates: [Content Authenticity Initiative docs](https://opensource.contentauthenticity.org/docs/signing/get-cert)

Secondary (status checks only):
- AZB & Partners, *India AI Regulatory Update*, 8 Sep 2026: [PDF](https://www.azbpartners.com/wp-content/uploads/2026/09/India-AI-Regulatory-Tracker-2nd-Ed-Correct-Final.pdf)
- Prior WearAI research #7, citing Hogan Lovells: [play-dpdp-compliance.md](https://github.com/suyashpatel98/WearAI/blob/research/play-dpdp-compliance/docs/research/play-dpdp-compliance.md)
