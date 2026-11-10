# Screens and flows

What each screen shows and how a User moves through the app. Decided in [What does each screen show, and how does a User move through the app?](https://github.com/suyashpatel98/WearAI/issues/32). The clickable prototype behind these decisions is on the throwaway branch [`prototype/screens`](https://github.com/suyashpatel98/WearAI/blob/prototype/screens/docs/prototypes/screens-prototype.html) (open it in a browser). It is rough on purpose: layout and copy are a starting point, not a design.

Tables and fields referred to below are in [`data-model.md`](./data-model.md).

## Navigation

- Three tabs: **Feed**, **Style Me**, **Wardrobe**. The app opens on the Feed.
- Every tab's header has an avatar button that opens **Settings**. There is no fourth tab.
- The **Saved list** opens from a "★ Saved" button in the Feed header.
- Sub-screens (Saved, a saved Post, buy links, Item details, review, Settings) open on top of the tab with a back arrow.

## Onboarding

A linear flow shown once, until the first review is finished. Each step's Continue button is disabled until the step is complete.

1. **Sign-in:** app name, one line on what it does, "Continue with Google". Google is the only option.
2. **Style Profile** (step 1 of 4):
   - Gender: Male / Female / Prefer not to say. "Prefer not to say" shows "Which clothes should we suggest?": Menswear / Womenswear / Both.
   - "How much would you spend on one piece?", with the four budget bands.
   - Height in cm, optional.
3. **Reference Photos** (step 2 of 4): three slots, at least one filled. Each slot offers "Take a photo" or "Choose from gallery". A tip explains what makes a good photo: whole body, good light, plain background, fitted clothes, front view (side view optional).
4. **Stylists** (step 3 of 4): the ten Stylists in a two-column grid. Each card has the sample image matching the User's clothes setting (both images for "Both"), the name and the tagline. Nothing is pre-selected; pick 1 to 3. Choosing a fourth shows "Up to 3 Stylists. Remove one first."
5. **First upload** (step 4 of 4): explains what photos to pick, then opens the Android photo picker (up to 20). **It can't be skipped**, because the first Feed needs at least one Item. Photos are resized on the phone before upload (longest side about 1600 px, JPEG).
6. **Processing:** "Finding your clothes in N photos…", which takes about a minute with the app open. On failure: "Couldn't process these photos, try again." with a button that opens the picker again.
7. **Review** (see [Review](#review)). Pressing "Add N Items to Wardrobe" finishes onboarding and lands on the Feed tab's empty state. No Feed starts until the User presses "Generate Feed".

## Feed

- **Header:** "Today", the date, "★ Saved" (with the count), avatar.
- **Generate Feed button**, at the top of the Feed. Each successful press makes 3 new Posts, up to 3 times per IST day:

  | State | Button |
  |---|---|
  | Presses left today | "Generate Feed · N of 3 left today" |
  | A Feed is being made | "Making your Feed…" (disabled, with a spinner) |
  | No presses left today | "3 of 3 used today, more at midnight" (disabled) |
  | Image budget used up | "Image budget used up (30 of 30)" (disabled) |

- **Layout:** all of today's Posts in one vertical scroll, newest Feed first, ending with "That's today's N."
- **Each Post:**
  - the generated image, marked "AI-generated"
  - the Stylist tag
  - **Save** (toggles to "★ Saved") and **Dismiss**. A saved Post has no Dismiss button; unsave it first.
  - the caption line
  - when the Outfit has Suggested Items, a **"Buy something similar"** section with one row per Suggested Item: its swatch, name and price band.
- **Dismiss:** the Post hides straight away and can't be undone. A sheet asks "Dismissed. Why? (optional)" with the four reasons and "Skip". "Don't like this piece" opens a second step listing the Outfit's pieces. A Suggested Item row says no similar suggestions for 90 days; a Wardrobe Item row says it will be used less.
- **States:**
  - No Posts yet today (including right after onboarding): "No Posts yet today." with the button.
  - Selection failed: an error card above the Posts with the error. The press doesn't count, so the button stays available.
  - Some images failed: fewer Posts from that press, with no message.
  - Everything dismissed: "That's everything for now." with the button.
- **No notifications.**

### Buy links

Tapping a Suggested Item row opens a screen headed "Buy something similar":
- the piece's swatch, name and price band
- "Search these shops:" with search links for Myntra, Ajio, Amazon.in and Flipkart, built from the piece's name, colour and category. Tapping one opens it in the browser.

There is no in-app product lookup in the MVP (see [What may the MVP spend, and how is it held there?](https://github.com/suyashpatel98/WearAI/issues/39)).

### Saved list

A two-column grid of saved Posts, newest save first, each with its image and caption. Tapping one opens the full Post with Save (to unsave) and its buy links, but no Dismiss. Empty state: "Save Posts you like and they stay here."

## Style Me

- **Header:** "Style Me", the "N of 5 left" chip (shown only when the daily-limit flag is on), "＋ New", avatar.
- **Thread:** one continuous thread, scrolled to the newest message. User messages on the right, replies on the left. "＋ New" adds a "New conversation" divider (not twice in a row).
- **Empty state:** one line on what Style Me does, plus three tappable example prompts.
- **A reply with an Outfit** shows the text, the image marked "AI-generated", and the caption line. Nothing in it is tappable and there are no buy links or saving.
  - Image failed: "Couldn't make this image." with the caption still shown.
  - Daily limit reached: the caption without an image, and "You've used today's 5 images, more at midnight."
  - Image budget used up: the caption without an image, and "Image budget used up (30 of 30)."
- **Input:** a single-line text field and Send. Both are disabled while a reply is pending, which shows a spinner bubble.

## Wardrobe

- **Header:** "Wardrobe", "＋ Add photos" (Android photo picker, up to 20), avatar.
- **Upload banners** at the top, one per Upload that isn't done:
  - processing: "Finding clothes in N photos…"
  - in review: "N new Items to check. They join your Wardrobe after you check them." Tapping it opens review.
  - failed: "Couldn't process these photos, try again." with OK to clear it.
- **Slot filter chips:** All plus each slot that has Items, with counts.
- **Grid:** three columns of Item crops with their names. Items switched to "Don't use in Outfits" are dimmed and badged "Not in Outfits".

### Item details

Opened by tapping an Item:
- the crop
- editable fields: name, category (grouped by slot; it decides the slot), main colour, second colour (or None), style (ethnic / western / fusion), pattern, and the description, labelled as what the stylist reads
- the **"Don't use in Outfits"** switch ("Keep it in your Wardrobe, but never style it"), which applies straight away
- "Save changes"
- "Delete Item", with the confirmation "It leaves your Wardrobe for good. Saved Posts keep their image."

## Review

Used for the first upload during onboarding and for every later Upload from the Wardrobe banner.

- **Header:** "Check your Items", with "N Items from M photos". There is no back arrow during onboarding.
- **Layout:** one list of every Item found. Each row has the crop, name, and category · colour · style, plus three buttons:
  - **Fix:** a sheet to edit the name, category, main colour and style. It notes that changing a fixed field rewrites the name unless the User typed their own.
  - **Same as…:** pick another Item from this Upload. This one is merged into it.
  - **Delete:** removes it at once.
- Items whose category is an `other_…` value are highlighted with "We weren't sure what this is".
- **"Add N Items to Wardrobe"** confirms everything still in the list. There is no per-Item confirm.
- Leaving review part-way through keeps the Items waiting, and the Wardrobe banner brings the User back.

## Settings

- **Style Profile:** gender (and the clothes follow-up for "Prefer not to say"), budget band, height. Each saves as soon as it changes.
- **Reference Photos:** the same three slots. At least one must stay: a User adds a new photo before removing their last one. New photos apply to images made from then on.
- **Stylists:** the active ones and "Change Stylists", which opens the same grid. At least one must stay. Changes apply from the next Feed, and the screen says so.
- **Account:** the Google email and "Sign out".
