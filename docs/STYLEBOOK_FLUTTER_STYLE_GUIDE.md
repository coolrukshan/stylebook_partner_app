# StyleBook — Flutter Style Guide ("Amber & Ink")

> Visual system for the Client, Partner and Admin apps. Source: the clickable prototype (Nov 2026 "Amber & Ink" restyle, the same look across all four boards).
> Code: `sb_theme.dart` in `packages/sb_ui/lib/theme/` implements every token below. Never hard-code a colour, font size, radius or shadow in a feature widget: read it from `Theme.of(context)` or `context.sb`.

---

## 1. Brand idea

Modern beauty studio: **warm, confident, editorial**. A burnt-orange gradient for hero moments, black ink for every action, warm cream surfaces, big light headlines, portrait-led cards and soft rounded shapes. Colour sets the mood; status colours stay plain so they're readable.

Rules of thumb:
- **Actions are black pills.** On a dark or photo surface the action flips to a **white pill with black text**.
- **Orange is for atmosphere and accents**, not buttons: the home header, links, focus rings, selected option borders, small highlights.
- **One hero per screen**: the orange header (client home) or a large portrait card (specialist, featured specialist). Everything else sits on cream.
- One typeface, Manrope, from Light 300 for big greetings to ExtraBold 800 for tiny badges.

---

## 2. Colour tokens

### 2.1 Brand

| Token | Hex | Use |
|---|---|---|
| `ink` | `#141414` | Primary buttons, selected chips, slots and dates, bottom nav, dark action bars, admin sidebar |
| `amber` | `#D9691F` | Accent: links, active tab underline, focus ring, radio dot, selected option border, partner-mobile FAB ring |
| `amberDark` | `#9A4413` | Text on amber tint, partner active menu text, pressed link |
| `amberLight` | `#E07A2E` | Input focus border |
| `amberTint` | `#FBEADB` | Soft pills, badges, selected rows |
| `amberSurface` | `#FFF5EC` | Selected option card fill |
| `amberBorder` | `#F1C8A6` | Highlight cards (e.g. "Needs your OK" stat) |
| `badgeYellow` | `#FFD43B` | Notification count dot on the orange header |

**Header gradient** (client home, hero areas): `LinearGradient(165°, [#F2A35A 0%, #DD7326 45%, #B9531B 100%])`, bottom corners radius 36.

**Glass control** (icon buttons and chips on the header): fill white at 22%, 1 px white border at 45%, white icon or text, background blur 8.

**Promo gradient** (dark banner): `#1F1A17 → #3A2A20 (55%) → #7A3E18`, white text, white pill CTA.

### 2.2 Ink (text and icons)

| Token | Hex | Use |
|---|---|---|
| `text` | `#1A1512` | Body text, headings on light surfaces |
| `text2` | `#4A3E36` | Secondary body text |
| `muted` | `#857469` | Captions, meta, inactive labels |
| `subtle` | `#A2948A` | Placeholders, disabled text |
| `navInactive` | `#A69A90` | Inactive icons in the black nav (partner mobile: `#8F847B` with labels) |
| `onDarkMuted` | `#BDB2A8` | Secondary text on `ink` bars |
| `cocoa` | `#3B2A1F` | Initials on avatar tiles |

### 2.3 Surfaces and lines

| Token | Hex | Use |
|---|---|---|
| `canvas` | `#F6EFE9` | Client app background (every screen) |
| `background` | `#F7F0E9` | Partner and admin page background (with a soft `#FBE3CC` radial glow top-right) |
| `surface` | `#FFFFFF` | Cards, sheets, inputs' container |
| `soft` | `#F4EBE3` | Icon buttons, segmented-control track, taken slots |
| `inputFill` | `#FFFCF8` | Text fields |
| `border` | `#EEE3D9` | Card borders, dividers |
| `borderStrong` | `#E7D9CC` | Chips, outlined buttons, inputs |
| `inputBorder` | `#DDCBBD` | Strong field border (complete profile, OTP) |
| `darkLine` | `#4A443F` | Outlined buttons on `ink` bars |

**Partner sidebar (web/tablet):** `LinearGradient(180°, [#FBF4EE, #F1E6DC])`, right border `border`. Active item: white card, `amberDark` 700 text, shadow `0 4 14 rgba(20,16,12,0.15)`.
**Admin sidebar:** `LinearGradient(180°, [#141414, #1F1C1A])`, text `#ECDFD4`, active item white at 14% with white 600 text.

### 2.4 Status (unchanged, keep plain)

| State | Text | Background | Use |
|---|---|---|---|
| Success / Completed | `#166534` | `#DCFCE7` | Status chips, "Next free" text, verified badges |
| Success action | `#16A34A` | — | Switch on, progress steps |
| Warning / Waiting for salon | `#92400E` | `#FEF3C7` | Requested, patch test notice, late |
| Info / Confirmed | `#1D4ED8` | `#E0EAFF` | Confirmed pill |
| Danger / Cancel | `#B42318` | `#FEE4E2` | Cancel, decline, errors, destructive confirm buttons |
| Rating star | `#F5A524` | — | ★ |

### 2.5 Category tints (search, partner tags)

| Category | Tile gradient | Icon ink |
|---|---|---|
| Haircut | `#FBE6D6 → #F6CDAE` | `#9A4413` |
| Beard | `#FFEBD2 → #FFD3A1` | `#B45309` |
| Facial | `#ECE6D4 → #DCCFAE` | `#047857` |
| Colour | `#F1E1D3 → #E3C6AE` | `#7A4A2A` |
| Spa | `#E9E2D8 → #D6C8B6` | `#1D4ED8` |
| Nails | `#F8E0D0 → #EFC3A6` | `#A0461A` |

On the client home, categories show as **pills on the header** ("All" selected in `ink`, the rest as glass chips), not tiles.

### 2.6 Portrait and hero art (placeholders until real photos)

- **Salon heroes, 150°:** RedBox `#F2A35A→#B9531B` · Looks `#E9B48A→#8E5A3C` · Serenity `#C9B79A→#5E5240` · Fade Factory `#C98B5B→#5A3A26`.
- **Gallery looks:** `#C98552→#5E3A24` · `#D9B08C→#7A5236` · `#F0B27A→#A7522A` · `#EBC48E→#B86A35` · `#F3C9A3→#C0632A` · `#E3A77C→#7B3F1E`.
- **Specialist portraits:** illustrated placeholders on a warm two-tone background (`b1 → b2` at 165°). In the app these are **real photos**, cropped to the face and shoulders, warm-graded, with no busy background.

---

## 3. Typography

One family: **Manrope** (via `google_fonts`; bundle the 300–800 weights for release).

| Style | Size / line | Weight | Tracking | Use |
|---|---|---|---|---|
| `displayLarge` (greeting) | 40 / 42 | 300 | −0.04em | "Hey, Nimal" on the orange header |
| `displayMedium` (card name) | 24–26 / 30 | 500 | −0.02em | Name on portrait cards |
| `headlineMedium` (h1) | 27 / 33 | 600 | −0.03em | Screen titles ("Almost there", salon name, "Today") |
| `headlineSmall` (h2) | 21 / 27 | 700 | −0.02em | Sheet and sub-page titles ("Choose a time") |
| `titleLarge` (section) | 19 / 25 | 700 | −0.02em | Section headers ("Specialists near you") |
| `priceLarge` (ext) | 20 / 26 | 700 | 0 | Totals, prices in action bars |
| `titleMedium` | 15 / 21 | 600 | 0 | List item titles, labels |
| `bodyLarge` | 15 / 22 | 400 | 0 | Inputs |
| `bodyMedium` | 14 / 20 | 400 | 0 | Body |
| `bodySmall` | 12 / 17 | 400 | 0 | Meta and captions (`muted`) |
| `labelLarge` | 15 / 20 | 600–700 | 0 | Buttons |
| `labelMedium` | 13 / 18 | 600 | 0 | Chips, secondary buttons, links |
| `labelSmall` | 11 / 14 | 700 | 0 | Distance and free-time badges, pills; uppercase eyebrow +0.06em |
| `badge` | 10 / 12 | 800 | 0 | Notification count |

Support text scaling to 200%: no fixed heights on text containers, use `minHeight`.

---

## 4. Shape, spacing, elevation

**Radius:** pill 10 · slot 24 · chip 20 · input 14 · secondary button 14 · option card 14 · card 20 · list card 22 · featured / profile portrait card 32 · header bottom 36 · action bar top 30 · sheet top 24 · primary button 26 · nav bar 33 · date chip, avatar, icon button: full circle.

**Spacing (4-pt grid):** 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 30, 32. Screen side padding **20**. Section header: 26 above, 8–12 below. Card padding 14–16. Gap between list cards 12; flower grid gaps 14 × 22.

**Sizes:** primary button 52 · input 48 · secondary button min 44 · icon button 44 (glass header buttons 46) · chip ~38 · date chip 54 circle · time slot 48 · nav bar 66 high, active circle 50 · action bar 92 · featured card 380 high · profile portrait card 360 · flower avatar 140 (home grid), 92 (salon team) · header avatar 48.

**Shadows (warm-tinted, never grey):**

| Token | Value | Use |
|---|---|---|
| `shadowCard` | `0 6 18 rgba(60,40,25,0.06)` | Cards, list cards |
| `shadowFloat` | `0 6 18 rgba(60,40,25,0.07)` | Floating fields |
| `shadowPrimary` | `0 8 18 rgba(20,16,12,0.18)` | Black primary button |
| `shadowChip` | `0 4 12 rgba(20,16,12,0.25)` | Selected chip, Book tag |
| `shadowNav` | `0 12 28 rgba(20,16,12,0.30)` | Floating black nav |
| `shadowHero` | `0 18 36 rgba(60,30,10,0.28)` | Featured portrait card |
| `shadowSheet` | `0 -8 24 rgba(26,21,18,0.12)` | Bottom sheets |

---

## 5. Components

| Component | Spec | Widget |
|---|---|---|
| Primary button | `ink` fill, white `labelLarge`, pill 52, `shadowPrimary`. On dark/photo: white fill, `ink` text, no shadow. Disabled 40%. | `SbPrimaryButton(onDark:)` |
| Secondary button | White, 1 px `borderStrong`, radius 14, `text` 13/600. On dark: transparent, `darkLine` border, white text. Danger: text `#B42318`. | `SbOutlineButton` |
| Text link | `amber`, 13/600 | `SbLink` |
| Icon button | 44 circle, `soft` fill, `text` icon 20 | `SbIconButton` |
| Glass button | 46 circle, glass fill, white icon; count badge 18 circle `badgeYellow`, `ink` 10/800 | `SbGlassIconButton` |
| Chip | Off: white, `borderStrong`, `text` 13. On: `ink`, white 600, `shadowChip`. On the header: glass off, `ink` on. | `SbChoiceChip` |
| Option card (radio) | White, radius 14, `borderStrong`. On: `amberSurface` fill, `amber` border, `amber` dot. | `SbOptionTile` |
| Text field | Fill `inputFill`, border `borderStrong`, radius 14, height 48. Focus: `amberLight` border + 3 px ring `amber` at 18%. | theme `InputDecorationTheme` |
| Card | White, radius 20, `border`, `shadowCard` | `SbCard` |
| Status pill | 12/600, padding 4×10, radius 10, colours from §2.4 | `SbStatusPill` |
| Date chip | 54 circle, white with white border; selected `ink` with white text; weekday 11 above the number 16/600 | `SbDateChip` |
| Time slot | 48 h, radius 24, white with white border, 14/600. Selected `ink`. Taken: `soft`, `subtle`, strikethrough. Off-peak tag 10/700 green. | `SbSlotChip` |
| Orange header | Header gradient, bottom radius 36, padding 50/20/22. Avatar 48 (2 px white border), glass search + bell, greeting `displayLarge`, location 13 white 85%, category pill row | `SbHomeHeader` |
| Featured portrait card | 380 h, radius 32, portrait fill, bottom 55% fade to `rgba(20,16,12,0.78)`, name `displayMedium` white, role 13 white 75%, "Next free" badge top-left (`ink` at 75%), white "Book now" pill bottom-left, rating circle 44 and heart circle 44 bottom-right, `shadowHero`. Two stacked ghost cards peek above (cream at 35% / 60%). Dots below: active 24×8 white, others 8×8 white 50%. | `SbFeaturedCard` |
| Flower avatar | 8-petal shape: polygon with r = 44% + 6%·cos(8θ) around the centre (96 points). Distance badge on top (`ink` pill, white 11/700), free-time badge at the bottom (white pill, `ink` 11/600, small shadow). Name 15/600 and role below. Two-column grid, the right column offset 56 down. | `SbFlowerAvatar` (`ShapeBorder`) |
| Profile portrait card | 360 h, radius 32, portrait fill, experience badge top-left, name 26/500, role · salon, rating circle 48 | `SbPortraitHeader` |
| Next-free strip | `ink`, radius 24, "Next free" 12 `onDarkMuted` + date 16/600 white, white "Book" pill | `SbNextFreeStrip` |
| Bottom nav (client) | Floating: inset 18 left/right, 16 bottom, height 66, radius 33, `ink`, `shadowNav`. Icon-only (each with a `Semantics` label); active = 50 white circle with `ink` icon; inactive `navInactive`. | `SbFloatingNav` |
| Bottom nav (partner mobile) | Same floating `ink` bar with 5 items and 11 px labels; active white, inactive `#8F847B` | `SbFloatingNav(labels: true)` |
| Action bar | Bottom of salon, choose time, specialist: `ink`, top radius 30, height 92; summary in white with `onDarkMuted` meta; white primary pill | `SbActionBar` |
| Bottom sheet | White, top radius 24, grab handle 36×4 `border`, padding 20 | `showSbSheet()` |
| Toast | `ink` fill, white 13 text, radius 14 (client: bottom 96; partner mobile: top 48) | `SbToast` |
| Promo banner | Promo gradient, radius 20, eyebrow 12/600 uppercase, title 22/700, white pill CTA with `amberDark` text | `SbPromoBanner` |

Status labels (same words in every app): Requested ("Waiting for salon" in client), Confirmed, Checked in, In service, Completed, Declined, Expired, Cancelled, No-show.

---

## 6. Iconography and imagery

- Line icons, 1.8 stroke, rounded caps and joins (Lucide style: `lucide_icons` package). 20 px in buttons, 22 px in the nav, 24 px in tiles.
- Category icons: scissors (Haircut), beard, smiling face (Facial), drop (Colour), leaf (Spa), nail (Nails).
- Photos: real salon work and real specialist portraits, warm-graded, rounded 14–32 depending on size. Portraits must have clear faces for the flower crop. Until photos exist, use §2.6.

## 7. Accessibility

- Contrast: white on `ink` and `ink` on white pass AAA. White on the header gradient passes AA for 14 px/500+ text; keep header body text at 85% white or more.
- Icon-only nav and glass buttons need `Semantics` labels (Home, Shop, Bookings, Profile, Search, Notifications).
- Touch targets ≥ 44×44.
- Don't rely on colour alone: taken slots also strike through, status pills always carry a word, selected dates also invert text.
- Respect reduced motion: no shimmer or parallax when `MediaQuery.disableAnimations`.

## 8. Dark mode (later)

Not designed yet. When added: canvas `#121010`, surface `#1C1917`, text `#F4EBE3`, primary buttons flip to white pills, keep the header gradient, status backgrounds at 20% alpha.

---

## 9. Screen exports

All PNGs are at 2×. Files are named by the screen IDs in the app instruction files.

**`StyleBook_Client_Screens.zip`**: 62 PNGs at 780×1688 (390×844).

| ID | Files |
|---|---|
| C-01..C-03 | welcome, OTP, complete your profile (phone, Google, Apple verify mobile, ready), home (+ scrolled) |
| C-04, C-05 | search, search with Home visits filter, map |
| C-06 | salon: services, options and add-ons, specialists, gallery, shop, reviews, home-visit mode |
| C-07, C-08 | look viewer, specialist profile (+ scrolled) |
| C-09 | choose time: single, split visit with patch test, split plan, group, waitlist |
| C-10, C-11 | review and pay (top, details, methods, home visit), booking done |
| C-12..C-18 | bookings (upcoming, past), details, cancel, reschedule, running late, review and tip, report a problem |
| C-19..C-23 | shop, product, cart, cart checkout, order placed, my orders |
| C-24..C-34 | notifications, chat, profile, payment methods, add card, addresses, favourites, gift cards, settings (+ scrolled), delete account, location, reminder push |
| C-35 | personal details (photo and contact, about you, sign-in methods), change mobile |

**`StyleBook_Partner_Screens.zip`**: `web/` 30 full-page PNGs at 2560 wide (1280 layout); `mobile/` 21 PNGs at 780×1688.

| ID | Web | Mobile |
|---|---|---|
| P-02 | today, decline reason | today (+ scrolled), decline reason |
| P-03 | calendar day, week, list, next day | calendar, other day |
| P-04..P-06 | booking detail, move, no-show, message, new booking | booking sheet, move, no-show, new booking sheet |
| P-07, P-08 | clients, client record, services and prices | services and prices |
| P-09..P-12 | staff, add staff, staff detail, staff leave | staff, add staff, staff detail (+ scrolled) |
| P-13, P-14 | gallery, photo detail, delete confirm | gallery, photo detail, delete confirm |
| P-15..P-17 | orders, inventory, earnings | orders |
| P-18..P-22 | reviews, AI reply, AI Studio (+ generated), clients due back, settings | reviews, booking rules, more |
