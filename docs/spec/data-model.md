# Data model

The Supabase Postgres tables, Storage layout and row-level security for the MVP. Decided in [What is the data model?](https://github.com/suyashpatel98/WearAI/issues/31), amended by [What may the MVP spend, and how is it held there?](https://github.com/suyashpatel98/WearAI/issues/39) and [How does the User generate a Feed without the daily Cron?](https://github.com/suyashpatel98/WearAI/issues/40). Item and Suggested Item fields come from [`item-attributes.md`](./item-attributes.md); Stylist briefs from [`stylists.md`](./stylists.md).

## Principles

- **Simplest shape that works** for one User on one phone. No denormalised counters or caches of history: everything Outfit selection needs is worked out by query (see [History queries](#history-queries)).
- **One `outfits` table** holds every generated Outfit, whether it's a Feed Post or a Style Me reply. Posts and Style Me messages point at it.
- **Hard deletes.** Deleting an Item removes its links from Outfits; saved Posts keep their image and caption text, so nothing visible breaks. Nothing else is deleted for now, including Storage files.
- **"Today" is the IST date:** `(now() at time zone 'Asia/Kolkata')::date`, written `ist_today` below.
- All ids are `uuid default gen_random_uuid()` unless stated. Every User-owned table has `user_id uuid not null references auth.users on delete cascade` and `created_at timestamptz not null default now()`; both are left out of the tables below.

## Enums

```sql
create type gender        as enum ('male', 'female', 'prefer_not_to_say');
create type clothes       as enum ('menswear', 'womenswear', 'both');
create type price_band    as enum ('under_1000', '1000_3000', '3000_7000', 'over_7000');  -- Style Profile budget and Suggested Item price band
create type colour_family as enum (/* the 22 families in item-attributes.md */);
create type tradition     as enum ('ethnic', 'western', 'fusion');
create type pattern       as enum (/* the 12 patterns in item-attributes.md */);
create type slot          as enum ('top', 'bottom', 'one_piece', 'footwear', 'outer_layer', 'accessory');
create type upload_status as enum ('processing', 'failed', 'in_review', 'done');
create type item_status   as enum ('in_review', 'in_wardrobe');
create type image_status  as enum ('ready', 'failed', 'over_limit');
create type dismiss_reason as enum ('not_my_style', 'dislike_piece', 'wouldnt_wear_together', 'doesnt_look_like_me');
create type feed_status   as enum ('ok', 'failed');
create type message_kind  as enum ('user', 'assistant', 'divider');
```

## Reference tables (seeded, read-only)

**`categories`**: the 68 categories from `item-attributes.md`. The slot is a lookup, never stored on an Item.

| column | type | notes |
|---|---|---|
| `id` | `text` pk | e.g. `kurta`, `other_footwear` |
| `slot` | `slot` | |
| `label` | `text` | shown in the review picker |

**`stylists`**: the ten Stylists from `stylists.md`.

| column | type | notes |
|---|---|---|
| `id` | `text` pk | slug, e.g. `indian_traditional` |
| `name` | `text` | |
| `tagline` | `text` | |
| `brief` | `jsonb` | paragraph, signature pieces, palette, fabrics, avoid, menswear/womenswear notes |
| `sample_menswear_path` | `text` | Storage path |
| `sample_womenswear_path` | `text` | Storage path |
| `position` | `int` | display order |

## The User

**`profiles`**: the User and their Style Profile, one row per User.

| column | type | notes |
|---|---|---|
| `user_id` | `uuid` pk → `auth.users` | |
| `gender` | `gender` | |
| `clothes` | `clothes` | always set: from gender, or from the "Prefer not to say" follow-up. Generation reads only this. |
| `budget_band` | `price_band` | |
| `height_cm` | `int` null | |
| `onboarded_at` | `timestamptz` null | |

Name and email come from `auth.users` (Google). No 18+ column: legal work is out of scope.

**`reference_photos`**

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `path` | `text` | Storage path |

The app enforces 1–3 per User. Replacing a photo deletes one row and inserts another.

**`user_stylists`**: the User's active Stylists.

| column | type | notes |
|---|---|---|
| `user_id`, `stylist_id → stylists` | pk | |

The app enforces 1–3. Each Feed's 3 Posts are split 3 / 2 + 1 / 1 + 1 + 1. With 2 active, the Stylist that gets 2 is picked by the User's count of `ok` Feed runs mod 2, so no rotation state is stored. Changes apply from the next Feed, because the Feed function reads this table on each press.

## The Wardrobe

**`uploads`**

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `status` | `upload_status` | `processing` → `in_review` → `done`, or `failed` |
| `photo_paths` | `text[]` | up to 20 originals, kept |

Flow: the client puts the photos in Storage, inserts the row (`processing`), then calls the upload Edge Function with its id. The function sets `in_review` (Items inserted) or `failed`. The client sets `done` when the User finishes review. That doesn't start a Feed.

**`items`**

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `upload_id` | `uuid` → `uploads` | |
| `status` | `item_status` | `in_review` until confirmed; only `in_wardrobe` rows are the Wardrobe |
| `category` | `text` → `categories` | slot via join |
| `primary_colour` | `colour_family` | |
| `secondary_colour` | `colour_family` null | |
| `tradition` | `tradition` | |
| `pattern` | `pattern` | |
| `name` | `text` | |
| `name_set_by_user` | `bool` default false | the rewrite call keeps a hand-typed name |
| `description` | `text` | |
| `crop_path` | `text` | the one SAM 3 cutout; also the Item's image in the Wardrobe and the generation reference |
| `excluded_from_outfits` | `bool` default false | "Don't use in Outfits"; excluded rows are never sent to selection or Style Me |

Review actions: **confirm** sets `in_wardrobe`; **fix** updates fields; **merge** keeps one Item and deletes the other; **delete** deletes the row. Deleting a Wardrobe Item is the same hard delete.

## Outfits

**`outfits`**: every generated Outfit, Feed or Style Me.

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `caption` | `text` | e.g. "Your indigo kurta with ivory chinos and tan kolhapuris (suggested)" |
| `image_status` | `image_status` | `ready`, `failed`, or `over_limit` (the image budget is used up, or the Style Me daily limit is reached) |
| `image_path` | `text` null | set only when `ready` |

Calls are interactive, so a row is written after generation finishes and there's no `pending` state. The Feed function writes an Outfit only when its image is `ready`; Style Me always writes one so the thread can show the image, the error, or the limit message.

**`outfit_items`**: the Wardrobe Items in an Outfit.

| column | type | notes |
|---|---|---|
| `outfit_id` | → `outfits` on delete cascade | pk part |
| `item_id` | → `items` on delete cascade | pk part |

**`suggested_items`**: each belongs to exactly one Outfit; a recurring kind of piece is a new row.

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `outfit_id` | → `outfits` on delete cascade | |
| `category` … `description` | as on `items` | same fields, no `status` or `crop_path` |
| `price_band` | `price_band` | |

Buy links aren't stored. The app builds retailer search links (Myntra, Ajio, Amazon.in, Flipkart) from the Suggested Item's name and fields. There is no Lens lookup and no SAM 3 cutout. Style Me shows no buy links.

## The Feed

**`feed_runs`**: one row per press of "Generate Feed".

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `feed_date` | `date` | `ist_today` when pressed |
| `status` | `feed_status` | |
| `error` | `text` null | shown on the Feed tab when the latest run `failed` |

The Feed function first checks the User's `ok` runs for `ist_today`. At 3 it refuses, and the app has already disabled the button. A `failed` run (selection failed, so no images) doesn't count, so pressing again is the retry. While a Feed is being made, the app disables the button, so a double tap can't start two Feeds.

The Feed tab shows today's Posts that aren't dismissed, ordered by the run's `created_at` descending, then `position`. If the latest run is `failed`, its error shows above them. If some images failed, that run simply has fewer than 3 Posts.

**`posts`**

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `outfit_id` | `uuid` unique → `outfits` | |
| `feed_run_id` | `uuid` → `feed_runs` | |
| `feed_date` | `date` | |
| `stylist_id` | `text` → `stylists` | the Stylist tag |
| `position` | `int` 1–3 | |
| `saved_at` | `timestamptz` null | unsave sets it back to null |
| `dismissed_at` | `timestamptz` null | no undo |
| `dismiss_reason` | `dismiss_reason` null | optional even when dismissed |
| `dismissed_item_id` | `uuid` null → `items` on delete set null | only with `dislike_piece` |
| `dismissed_suggested_item_id` | `uuid` null → `suggested_items` | only with `dislike_piece` |

Checks: `saved_at is null or dismissed_at is null`; the two `dismissed_*_id` columns are null unless `dismiss_reason = 'dislike_piece'`, and at most one is set.

The **Saved list** is `saved_at is not null order by saved_at desc`, kept for good. The **image-quality log** is `dismiss_reason = 'doesnt_look_like_me'`.

## Style Me

**`style_me_messages`**: one continuous thread per User.

| column | type | notes |
|---|---|---|
| `id` | `uuid` pk | |
| `kind` | `message_kind` | `user`, `assistant` or `divider` ("New conversation") |
| `body` | `text` null | null for dividers |
| `outfit_id` | `uuid` null → `outfits` | assistant replies that propose an Outfit |

The thread is every row ordered by `created_at`. The model's context is the rows after the last divider, capped at the latest 20.

**Daily image limit:** the flag is the Edge Function environment variable `STYLE_ME_DAILY_LIMIT` (unset means off, no limit). When set, the count is the User's Style Me Outfits created on `ist_today` with `image_status = 'ready'`; failed generations don't count and no counter is stored.

## Image budget

**`image_budget`**: a single row, not owned by a User, that caps the total number of Nano Banana calls. It is seeded with `used = 0, cap = 30`.

| column | type | notes |
|---|---|---|
| `id` | `boolean` pk default `true`, check `id` | keeps it to one row |
| `used` | `int` | |
| `cap` | `int` | edit the row to raise it |

Before every image call, Feed or Style Me, the Edge Function reserves a slot:

```sql
update image_budget set used = used + 1 where used < cap returning used;
```

No row returned means the budget is used up: the Outfit is `over_limit` and the model isn't called. A failed call keeps its slot. The app reads `used` and `cap` through an Edge Function, to show "Image budget used up (30 of 30)". The table has no client access.

## History queries

All Feed-only: Style Me never affects selection.

```sql
-- Last used, per Item
select oi.item_id, max(p.feed_date) as last_used_on
from posts p join outfit_items oi using (outfit_id)
where p.user_id = $user
group by oi.item_id;

-- Wardrobe Item sets for the repeat check (60 days; 14 when no new set is possible)
select p.id, array_agg(oi.item_id order by oi.item_id) as item_set
from posts p join outfit_items oi using (outfit_id)
where p.user_id = $user and p.feed_date > ist_today - 60
group by p.id;

-- Today's earlier Outfits, so a new Feed doesn't repeat a top + bottom (or one-piece) from today
select p.id, array_agg(oi.item_id) as item_set
from posts p join outfit_items oi using (outfit_id)
where p.user_id = $user and p.feed_date = ist_today
group by p.id;

-- Kinds of Suggested Item used this week (at most once a week)
select distinct s.category, s.primary_colour
from posts p join suggested_items s using (outfit_id)
where p.user_id = $user and p.feed_date > ist_today - 7;

-- 90-day blocks from "Don't like this piece" on a Suggested Item
select distinct s.category, s.primary_colour
from posts p join suggested_items s on s.id = p.dismissed_suggested_item_id
where p.user_id = $user and p.dismissed_at > now() - interval '90 days';

-- 30 most recent dismissals (examples to avoid, with Stylist tag) and 20 most recent saves
select ... from posts where user_id = $user and dismissed_at is not null order by dismissed_at desc limit 30;
select ... from posts where user_id = $user and saved_at     is not null order by saved_at     desc limit 20;
```

Deleting an Item drops it from past sets, so a past set can shrink and block a smaller new set it didn't contain. That only over-blocks, which is harmless.

## Row-level security

- **Every User-owned table:** RLS on; `select` where `user_id = auth.uid()`.
- **Client writes** (`insert`/`update`/`delete` with `user_id = auth.uid()` in `using` and `with check`), only where the User edits:
  - `profiles`: insert, update
  - `reference_photos`, `user_stylists`: insert, delete
  - `uploads`: insert, update (`done`)
  - `items`: update (review, edits, switch), delete
  - `posts`: update (save, unsave, dismiss)
  - `style_me_messages`: insert (`divider` only, for "New conversation")
- **Everything else** is written by Edge Functions with the service role: Items from detection, Outfits, Suggested Items, Posts, Feed runs, the image budget and Style Me user/assistant messages.
- **No column-level guards:** the client could overwrite other columns on its own rows. Accepted for the MVP.
- **`categories`, `stylists`:** `select` for `authenticated`; no writes.

## Storage

One private bucket, `user-media`, with every path under `{user_id}/`:

```
{user_id}/reference/{id}.jpg
{user_id}/uploads/{upload_id}/{n}.jpg
{user_id}/crops/{item_id}.png
{user_id}/outfits/{outfit_id}.jpg
```

Policy: `(storage.foldername(name))[1] = auth.uid()::text` for select and insert. Images are served through signed URLs. Stylist sample images sit in a separate public-read bucket, `stylists`.
