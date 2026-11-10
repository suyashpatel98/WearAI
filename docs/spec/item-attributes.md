# Item attributes

What every Item and Suggested Item carries, and the fixed values each field can take. Decided in [Which attributes does each Item get?](https://github.com/suyashpatel98/WearAI/issues/11).

## Who reads them

- **Outfit selection** sees the Wardrobe as text only, with no images. Code checks each Outfit against hard rules that need fixed values: whether it covers every **slot**, and whether a Suggested Item is the "same kind of piece" (category + primary colour family).
- **Captions** use `name`, e.g. "Your indigo kurta with ivory chinos and tan kolhapuris (suggested)".
- **Shopping search** gets a text hint from a Suggested Item's `name` and `description`. Wardrobe Items never go to shopping search.
- **The app** groups and filters the Wardrobe by slot, category, colour and tradition.

## Fields

| Field | Kind | Required | Notes |
|---|---|---|---|
| `category` | fixed list (below) | yes | Decides the slot. |
| `slot` | derived from `category` | — | Never stored or edited on its own. To change the slot, change the category. |
| `primary_colour` | colour family | yes | Used in the "same kind of piece" check. |
| `secondary_colour` | colour family | no | Leave it empty for a single-colour piece. |
| `tradition` | `ethnic` / `western` / `fusion` | yes | Indian Traditional and Indo-Western have rules about it. |
| `pattern` | fixed list (below) | yes | |
| `name` | text, 2–4 words | yes | Shown in the app and used in captions, e.g. "Indigo block-print kurta". |
| `description` | text, one sentence | yes | For the selection LLM only. Holds what the fixed fields can't: exact shade, visible fabric or texture, fit, length, neckline, sleeves, embellishment, weight. E.g. "Knee-length indigo cotton kurta with a white block-print yoke and mandarin collar; relaxed fit, looks lightweight." |

A **Suggested Item** has the same fields plus a **price band**, taken from the User's Style Profile budget.

**Deliberately not fixed fields:** formality, fit, fabric, season, sleeve, length, neckline, brand, size. Detection gets the weak ones wrong, which would mean more review fixes. Anything visible goes in `description` instead.

**"Same kind of piece"** and **"similar"** (the 90-day block after "Don't like this piece") both mean: the same `category` and the same `primary_colour`.

## Detection and review

- **Detection fills every required field and never returns `unknown`.** When it can't tell the category, it picks the slot's `other_…` category, and the review step highlights that Item.
- **The review step** shows each Item's crop with `name`, `category`, `primary_colour` and `tradition` editable. Fixing the category is how the User fixes the slot.
- **Item details** (opened from the Wardrobe at any time) also let the User edit `secondary_colour`, `pattern` and `description`.
- **Keeping the text in step with fixes:** when the User changes a fixed field, `name` and `description` are rewritten from the crop and the corrected fields. This is one cheap Flash-Lite call per review batch, covering only the changed Items. If the User has edited `name` by hand, their name is kept and only `description` is rewritten.

## What one Item is

Pieces are split **by how they can be worn**:

- **Saree:** one one-piece Item, including its blouse. The blouse isn't tracked separately.
- **Lehenga set** (lehenga, choli, dupatta): one one-piece Item.
- **Kurta set, salwar kameez, sharara set:** split into the kurta or kameez (top), the bottom, and the dupatta (accessory), so the kurta can also be worn with jeans.
- **Suit:** the jacket (outer layer) and the trousers (bottom) are separate Items.
- **Dress, jumpsuit, or a co-ord made as one piece:** one-piece. A two-piece co-ord is a top plus a bottom.

## What detection leaves out

These never become Items:

- **Innerwear, socks, nightwear and swimwear.** Swimwear and underwear also sit under content safety, which is still open on the map.
- **Head coverings and markers of faith or marriage** (turban, patka, hijab, kippah, mangalsutra, sindoor, bindi, kara). They belong to the person, not the Wardrobe. Selection never swaps them in or out, and generation keeps them as they appear in the Reference Photos.
- **Prescription glasses**, for the same reason. Sunglasses are Items.

Activewear is kept, because the Athleisure Stylist needs it.

## Categories

68 categories across 6 slots. Every slot ends with an `other_…` category for anything the list misses. Labels cover both menswear and womenswear.

### Top (12)

| id | Label |
|---|---|
| `tshirt` | T-shirt |
| `polo` | Polo |
| `shirt` | Shirt |
| `blouse_top` | Blouse / top |
| `crop_top` | Crop top |
| `tank_camisole` | Tank top / camisole |
| `sweater` | Sweater (pullover) |
| `sweatshirt_hoodie` | Sweatshirt / hoodie (pullover) |
| `kurta` | Kurta / kurti / kameez |
| `sherwani` | Sherwani |
| `sports_top` | Sports top / sports bra |
| `other_top` | Other top |

A sherwani is worn closed over a churidar, so it fills the top slot.

### Bottom (14)

| id | Label |
|---|---|
| `jeans` | Jeans |
| `trousers` | Trousers |
| `chinos` | Chinos |
| `shorts` | Shorts |
| `skirt` | Skirt |
| `ethnic_skirt` | Ethnic skirt (incl. a lehenga skirt worn on its own) |
| `joggers_trackpants` | Joggers / track pants |
| `leggings` | Leggings / jeggings |
| `churidar_pyjama` | Churidar / pyjama |
| `salwar_patiala` | Salwar / patiala |
| `palazzo` | Palazzo / wide-leg ethnic pants |
| `dhoti` | Dhoti / veshti / dhoti pants |
| `sharara_gharara` | Sharara / gharara |
| `other_bottom` | Other bottom |

### One-piece (6)

| id | Label |
|---|---|
| `saree` | Saree (incl. pre-draped) |
| `lehenga_set` | Lehenga set |
| `anarkali_gown` | Anarkali / ethnic gown |
| `dress` | Dress / kaftan |
| `jumpsuit` | Jumpsuit / playsuit / dungarees |
| `other_one_piece` | Other one-piece |

A short anarkali kurta worn with a churidar is a `kurta`. A floor-length anarkali worn as a complete piece is an `anarkali_gown`.

### Footwear (12)

| id | Label |
|---|---|
| `sneakers` | Sneakers |
| `sports_shoes` | Running / training shoes |
| `loafers` | Loafers / moccasins |
| `formal_shoes` | Formal shoes (oxfords, derbies, brogues) |
| `boots` | Boots |
| `sandals` | Sandals |
| `slides_flipflops` | Slides / flip-flops |
| `heels` | Heels / wedges |
| `flats` | Flats / ballet flats / mules |
| `juttis_mojaris` | Juttis / mojaris |
| `kolhapuris` | Kolhapuris |
| `other_footwear` | Other footwear |

### Outer layer (12)

| id | Label |
|---|---|
| `blazer` | Blazer / suit jacket |
| `jacket` | Jacket (denim, bomber, leather, puffer) |
| `coat` | Coat / overcoat / trench |
| `cardigan_shrug` | Cardigan / shrug |
| `overshirt` | Overshirt / shacket |
| `zip_hoodie` | Zip hoodie / track jacket |
| `nehru_jacket` | Nehru jacket |
| `bandhgala` | Bandhgala / jodhpuri jacket |
| `ethnic_jacket` | Ethnic jacket / koti / cape |
| `waistcoat` | Waistcoat / vest |
| `shawl` | Shawl |
| `other_outer_layer` | Other outer layer |

### Accessory (12)

| id | Label |
|---|---|
| `bag` | Bag (handbag, sling, tote, clutch, potli, backpack) |
| `watch` | Watch |
| `belt` | Belt |
| `sunglasses` | Sunglasses |
| `hat_cap` | Hat / cap |
| `scarf` | Scarf / muffler |
| `dupatta_stole` | Dupatta / stole |
| `necklace` | Necklace |
| `earrings` | Earrings / jhumkas |
| `bangles_bracelets` | Bangles / bracelets |
| `tie_pocket_square` | Tie / pocket square |
| `other_accessory` | Other accessory (rings, hair accessories, maang tikka, brooch) |

## Colour families (22)

`black`, `white`, `ivory_cream`, `grey`, `beige_khaki`, `camel_tan`, `brown`, `navy`, `blue`, `light_blue`, `teal`, `green`, `olive`, `yellow_mustard`, `orange_rust`, `red`, `maroon`, `pink`, `purple_lavender`, `gold`, `silver`, `multicolour`

Exact shades ("dusty rose", "bottle green") go in `description`. Use `multicolour` only when no single colour dominates. A white kurta with a blue print is `white` + `blue`.

## Patterns (12)

| id | Label |
|---|---|
| `solid` | Solid |
| `stripes` | Stripes |
| `checks` | Checks / plaid |
| `floral` | Floral |
| `block_print` | Block print |
| `woven_pattern` | Ikat / woven pattern |
| `paisley_motif` | Paisley / motif |
| `embroidered` | Embroidered / embellished |
| `graphic_logo` | Graphic / logo |
| `polka_dot` | Polka dot |
| `animal_print` | Animal print |
| `other_print` | Abstract / other print |
