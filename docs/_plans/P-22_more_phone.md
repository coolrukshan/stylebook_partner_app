# P-22 More (phone) — Implementation Plan

- Spec: [docs/_specs/P-22_more_phone.md](../_specs/P-22_more_phone.md)
- Design: `mobile/P-22_more.png` (title "More", one white grouped card with 7 rows, black count pills for Orders 2, Reviews 2, Inventory 3, floating black nav with "More" selected).

## 1. Summary and dependencies

The fifth tab of the phone shell: a role-filtered menu card that links to other screens, with count badges fetched from three independent calls. Rows for Inventory and AI Studio open the web app in the external browser. Sign out and Language appear as proposed account rows (Q5).

This plan owns the role-to-items map and the badge providers. It also relies on the phone shell (floating nav) that is not built yet: `lib/shell/` is empty and `router.dart` only has `/` -> `TodayScreen`.

Prerequisites:
- Shell (adaptive scaffold: sidebar >= 900 px, `SbFloatingNav` with `showLabels: true` on phone, 5 items Today, Calendar, Staff, Gallery, More) with `StatefulShellRoute.indexedStack`.
- Auth/session: `role`, `salonId`, sign out action.
- Target routes: P-15 Orders, P-08 Services and prices, P-21 Booking rules, P-18 Reviews. Until they exist, rows route to a `ComingSoonScreen` placeholder (kept in `shell`, removed later).
- Endpoint knowledge from other plans: orders list `counts`, inventory `summary`, services list.
- `url_launcher` dependency (not yet in `apps/partner/pubspec.yaml`).

## 2. Files to create / modify

`apps/partner/lib/shell/`:
- `shell_scaffold.dart` (adaptive: sidebar vs floating nav) if not created by another plan; coordinate, only the "More" branch is owned here.
- `permissions.dart`: `AppRole` enum and `Permissions` (shared with P-18..P-21; only add the More-related getters here).
- `more/more_item.dart`: `MoreItem {id, titleKey, subtitleBuilder, route?, webPath?, badge?, roles}` and enum `MoreItemId`.
- `more/more_items.dart`: const role-to-items map and `moreItemsFor(role)`.
- `more/more_screen.dart`, `more/widgets/more_row.dart`, `more/widgets/more_group_card.dart` (or a shared `SbMenuRow`/`SbGroupedCard` in `sb_ui`, see below), `more/widgets/account_section.dart`.
- `more/more_badges_provider.dart`: `ordersBadgeProvider`, `reviewsBadgeProvider`, `inventoryBadgeProvider`, `servicesCountProvider`, aggregated `moreBadgesProvider` (family-free; keyed on `salonId` so no cross-salon caching).

Data (small, read-only; placed in each owning feature so other screens reuse them):
- `features/orders/data/orders_badge_repository.dart` -> `fetchActionCount()`; `features/reviews/application/unreplied_count_provider.dart` (shared with P-18; if P-18 lands first reuse `unrepliedCountProvider`); `features/inventory/data/inventory_badge_repository.dart` -> `fetchLowStock()`; `features/services/data/services_count_repository.dart` -> `fetchServiceCount()`.

Router: `lib/router.dart` add the branch `/more` plus child routes `/orders`, `/services`, `/settings/booking-rules`, `/reviews` (full-screen, outside the tab so the back pill is shown; owned by those feature plans, referenced here by constants in `lib/routes.dart`).

Other: `apps/partner/pubspec.yaml` add `url_launcher`; `lib/shell/web_links.dart` with `webUrl(path)` building `https://partner.stylebook.lk/<path>` from `SbConfig` (add `SbConfig.webAppBaseUrl` via `String.fromEnvironment('WEB_APP_URL', defaultValue: 'https://partner.stylebook.lk')` in `packages/sb_core/lib/src/config.dart`).

sb_ui additions:
- `SbGroupedCard` + `SbMenuRow` (title 16/600, subtitle `bodySmall`-muted, optional trailing, min height `SbTokens.minTouch`, divider between rows, whole row tappable, `Semantics(button: true)`). No chevron per PNG.
- `SbCountBadge` (black circle, white digits, `shadowChip`; "99+" cap; hidden at 0; Semantics label supplied by caller).
- `SbBanner` (offline) and `SbEmptyState` (shared).

l10n: `app_en.arb` (section 8).

## 3. Data layer

No aggregate badge endpoint exists. Four small independent GETs (all with `X-Salon-Id`):

| Badge/subtitle | Method + path | Params | Field |
|---|---|---|---|
| Orders | GET `/v1/partner/orders` | `limit=1` (also optional `salon_id`) | `PartnerOrderListOut.counts` (`map<string,int>`) |
| Reviews | GET `/v1/partner/reviews` | `limit=1` | `summary.unreplied_count` |
| Inventory | GET `/v1/partner/inventory` | `limit=1` | `summary.low_stock` (the schema has both `low_stock` and `low_stock_count`; prefer `low_stock`, fall back to `low_stock_count`) |
| Services subtitle | GET `/v1/partner/services` | `active_only=true` | `ServiceListOut.categories[].services` count (sum of services across categories; this is counting items returned, not a price/slot computation) |

"Needs action" keys for orders are undocumented (Q2). Interim rule, isolated in one function `ordersNeedingAction(Map<String,int> counts)`: sum of keys `paid`, `accepted`, `packed` (statuses before hand-over per instructions: paid -> accepted -> packed -> ready -> collected). Confirm against live API before shipping; unit-tested so it is a one-line change.

Error mapping: each call is wrapped in its own `AsyncValue`; any error or 401/403/429 results in "no badge" (null) for that row; no dialogs. If all calls fail show a small footer "Pull to retry".

## 4. Application / state

- `moreBadgesProvider` (`AsyncNotifier<MoreBadges>`): `MoreBadges {int? orders, int? unreplied, int? lowStock, int? services}`. `build()` runs the calls with `Future.wait` over per-call `try/catch` returning null, filtered by role (do not call orders/inventory/reviews endpoints for a role that cannot see the row, avoids 403 noise). Keyed on `salonId` via `ref.watch(sessionProvider.select((s) => s.salonId))` so the state resets on salon switch.
- Refresh triggers: when More becomes visible again (shell branch `onTap` / `RouteAware` / `NavigatorObserver` or `visibilityDetector` on the screen; simplest: `StatefulShellRoute` branch re-select calls `ref.invalidate`), `RefreshIndicator` pull, and app resume. Real-time (Q4) is a documented future hook: expose `MoreBadgesNotifier.applyEvent(...)` but do not implement a socket.
- Rows render immediately with fixed subtitles; badges appear when loaded (no spinner). While services count is null the subtitle falls back to "Prices and who does them".
- Empty: Specialist sees "Nothing here for your role" plus account rows. Error: silent except the all-failed footer. Offline (`connectivity` signal from shared provider when available): banner "You are offline", web rows disabled, other rows tappable.

## 5. Presentation

- `MoreScreen`: `SafeArea > RefreshIndicator > ListView(padding: EdgeInsets.fromLTRB(screenPadding, ..., screenPadding, navHeight + 32))` so content clears the floating nav. Children: title `Text('More', style: headlineMedium)`, optional offline `SbBanner`, `SbGroupedCard(children: [for item in moreItemsFor(role) MoreRow(item)])`, account card (Language, Sign out) as a second group below, footer retry text.
- Role to rows (`more_items.dart`), PNG order:
  1. Orders (owner, manager), badge, route `/orders`.
  2. Services and prices (owner, manager), subtitle "N services, prices and who does them", route `/services`.
  3. Booking rules (owner, manager), route `/settings/booking-rules`.
  4. Reviews (owner, manager), badge, subtitle "N waiting for a reply" (or "No reviews waiting" at 0), route `/reviews`.
  5. Inventory (owner, manager), subtitle "N products low on stock · opens on web", badge, web path `inventory`.
  6. AI Studio (owner, manager), subtitle "Promo posts · opens on web", web path `ai-studio`.
  7. Earnings and payouts (owner only), subtitle "Owner only · see the Today tab for a summary", tap switches to the Today tab (`StatefulNavigationShell.goBranch(0)`; Q3).
- `MoreRow` -> `SbMenuRow(title, subtitle, trailing: SbCountBadge(count))`; `Semantics(button: true, label: '$title, $subtitleOrBadge')`; badge has its own label ("2 orders need action", plural from ARB).
- Web rows: `launchUrl(uri, mode: LaunchMode.externalApplication)`; if it returns false or throws, `ScaffoldMessenger` snackbar `moreOpenWebFailed`.
- Account section (proposal, Q5): Language row opens a bottom sheet with English / Sinhala / Tamil chips (locale provider, persisted via shared_preferences; placeholder if the locale provider is not built); Sign out opens a confirm dialog (confirm black or `danger`: sign out is not data-destructive, use the black pill; Q5 for PM) and calls `authController.signOut()`.
- Tablet/web: this screen is not used (sidebar replaces it); the route redirects to `/` when width >= 900.
- Tokens only (`SbTokens.screenPadding`, `rListCard` radius for the card per PNG, `minTouch`); no hard-coded colours.

## 6. Role rules

- `moreItemsFor(AppRole role)` is a pure function over a const table `Map<MoreItemId, Set<AppRole>>`:
  - Owner: all 7. Manager: rows 1-6 (Earnings hidden). Specialist: none of the 7; shows empty state + account rows (assumption Q1).
- Enforcement: the row list is built from the table (no row is built and no badge call is made for hidden rows); the target routes are guarded separately by `Permissions` and the API still returns 403. Role comes from token claims through `sessionProvider`; unknown role behaves as specialist (least privilege).

## 7. Validation, confirmations, formatting

- Badge formatting: 0 hides the pill; 1..99 shows the number; above 99 shows "99+" (`SbCountBadge`, tested).
- Plurals via ARB ICU: "1 waiting for a reply" vs "2 waiting for a reply", "1 product low on stock" vs "3 products low on stock", "1 service" vs "5 services".
- Sign out confirm dialog. No money or date formatting on this screen.
- Never cache counts across salon switches (provider keyed by `salonId`).

## 8. ARB keys

`moreTitle`, `moreOrdersTitle`, `moreOrdersSubtitle`, `moreOrdersBadgeSemantics` (plural {n}), `moreServicesTitle`, `moreServicesSubtitle` (plural {n}), `moreServicesSubtitleFallback`, `moreBookingRulesTitle`, `moreBookingRulesSubtitle`, `moreReviewsTitle`, `moreReviewsSubtitle` (plural {n}), `moreReviewsSubtitleNone`, `moreReviewsBadgeSemantics` (plural {n}), `moreInventoryTitle`, `moreInventorySubtitle` (plural {n}), `moreInventorySubtitleNone`, `moreInventoryBadgeSemantics` (plural {n}), `moreAiStudioTitle`, `moreAiStudioSubtitle`, `moreEarningsTitle`, `moreEarningsSubtitle`, `moreBadgeOverflow` ("99+"), `moreOpenWebFailed` ("Could not open the web app"), `moreNothingForRole` ("Nothing here for your role"), `moreOfflineBanner` ("You are offline"), `morePullToRetry`, `moreAccountSection`, `moreLanguageTitle`, `moreLanguageEnglish`, `moreLanguageSinhala`, `moreLanguageTamil`, `moreSignOut`, `moreSignOutTitle`, `moreSignOutBody`, `moreSignOutConfirm`, `commonCancel`, `navToday`, `navCalendar`, `navStaff`, `navGallery`, `navMore`.

## 9. Tests

Unit (`test/shell/more/`):
- `more_items_test`: owner gets 7 ids in PNG order; manager gets 6 (no earnings); specialist gets empty; unknown role equals specialist.
- `orders_action_count_test`: sums the configured keys, ignores others, empty map returns 0.
- `more_badges_provider_test`: each call failing independently yields null for that badge only; hidden-role endpoints not called (verify with fake repositories and call counters); provider resets when `salonId` changes; refresh re-queries.
- `count_badge_format_test`: 0 hidden, 7 -> "7", 99 -> "99", 100 -> "99+".
- `web_links_test`: URL composition from config.

Widget (`test/shell/more/`):
- Owner screen: 7 rows, badge pills show 2/2/3, subtitles pluralised (1 vs 2), 0 hides pill.
- Manager: no Earnings row. Specialist: "Nothing here for your role" plus account rows.
- Tap Reviews navigates to `/reviews` (fake router); tap Inventory calls fake `UrlLauncher` with external mode; launch failure shows snackbar.
- Badge fetch failure renders rows without pills and without dialogs; all-fail shows footer.
- Semantics: badge label "2 orders need action"; rows are buttons with height >= 44.
- Offline banner disables web rows only.
- Pull to refresh re-queries.
- Text scale 2.0: no overflow, rows grow.

Golden: `more_owner_390.png` (matches `mobile/P-22_more.png` with floating nav at bottom, More selected) and `more_manager_390.png`, `more_specialist_390.png` (spec section 7 says per-role goldens at 390).

## 10. Task checklist

1. Check whether the shell and session exist; if not, build the minimal shell (5-tab `SbFloatingNav`) with role from a stub provider that is replaced later.
2. Add `url_launcher`, `SbConfig.webAppBaseUrl`, and `lib/routes.dart` constants.
3. Add `sb_ui` widgets: `SbGroupedCard`, `SbMenuRow`, `SbCountBadge`, `SbBanner`, `SbEmptyState`, each with tests.
4. Implement `moreItemsFor(role)` and tests.
5. Implement badge repositories and `moreBadgesProvider`; tests including salon switch and failure isolation.
6. Build `MoreScreen`, rows, subtitles with ARB plurals; golden 390 owner.
7. Web row launch and snackbar; fake launcher tests.
8. Account section (Language sheet, Sign out confirm); tests.
9. Wire refresh triggers (tab re-select, pull, resume); tests.
10. Role goldens (manager, specialist); semantics and text-scale tests.
11. `flutter analyze` and `flutter test`.

## 11. Open questions / API gaps / risks

- Q1 role matrix beyond Earnings. Q2 orders `counts` keys undocumented and no batch badge endpoint (propose a `GET /v1/partner/badges`; interim 3-4 calls, note that opening More triggers up to 4 requests every time). Q3 the Today API only exposes `revenue_today_cents`, so the phone "earnings summary" the Earnings row points to depends on P-02/P-17. Q4 no real-time contract. Q5 Sign out, Language and salon switcher placement (plan proposes a second card). Q6 Clients not listed.
- Inventory summary has duplicate fields (`low_stock` and `low_stock_count`); confirm which is authoritative.
- Services count requires the full services list (`/v1/partner/services` is not paginated and returns categories with services); heavy for a subtitle. Alternative: reuse the cached list from P-08's provider when present.
- `GET /v1/partner/orders`, `/inventory` and `/reviews` show optional `salon_id` query in the schema for orders and inventory; send only `X-Salon-Id` unless the backend requires `salon_id` (as in `/engagement/due`).
- Deep links from push (low stock, new order): router must open the target as a full-screen route with the back pill even when More has never been visited; needs push plumbing that does not exist yet.
- The target screens (P-08, P-15, P-18, P-21) may land after this plan; use placeholder routes to avoid a blocked task.
- Web URL path names (`inventory`, `ai-studio`) are guesses; the spec says `<path>` without defining it. Confirm with the web app.
