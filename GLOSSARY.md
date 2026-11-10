# WearAI

An AI stylist app: it learns a user's clothes from their photos and shows them wearing outfits built from those clothes and from pieces they could buy.

## Language

### The user and their clothes

**User**:
A person with a WearAI account. Each User's Wardrobe, Style Profile and Feed are private to them.
_Avoid_: Customer, member

**Style Profile**:
What a User tells the app about themselves at onboarding (gender, budget and, optionally, height). It covers only what the Reference Photos and Wardrobe can't show.
_Avoid_: Preferences, persona, user profile

**Reference Photo**:
A full-body photo of the User, taken for the app at onboarding, that shows the User in generated images. It is separate from the camera-roll photos used to find Items.
_Avoid_: Selfie, base photo, avatar

**Item**:
One piece of clothing or an accessory the User owns, such as a navy kurta or white sneakers.
_Avoid_: Outfit (for a single piece), garment, clothing piece, product

**Wardrobe**:
All of a User's Items.
_Avoid_: Closet, collection, inventory

### Styling

**Outfit**:
A complete head-to-toe combination worn together: a one-piece garment or a top and a bottom, plus footwear, with an optional outer layer and accessories. It is built mostly from the User's Items and may include Suggested Items they don't own.
_Avoid_: Look, fit, ensemble

**Slot**:
The part of an Outfit a piece fills: top, bottom, one-piece, footwear, outer layer or accessory. A piece's category decides its slot.
_Avoid_: Type, position

**Suggested Item**:
A piece the AI recommends that isn't in the User's Wardrobe, shown with where to buy it.
_Avoid_: Product, recommendation, missing item

**Stylist**:
A named aesthetic, such as "Indian Traditional" or "Streetwear", that the User turns on to decide what kind of Outfits their Feed shows. A User has one to three active.
_Avoid_: Persona, style, theme, filter

### Surfaces

**Feed**:
The tab showing a small, fixed set of Posts (five) generated for the User from their active Stylists. It is not an endless scroll.
_Avoid_: Timeline, explore, infinite feed

**Post**:
One Feed entry: a generated image of the User wearing an Outfit, with buy links for any Suggested Items in it.
_Avoid_: Card, suggestion

**Style Me**:
The tab where the User chats with the AI stylist, which replies with generated images of Outfits.
_Avoid_: Chat, assistant tab
