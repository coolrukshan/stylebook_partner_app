# P-15 Orders — Implementation Plan

- Spec: [docs/_specs/P-15_orders.md](../_specs/P-15_orders.md)
- Design: `mobile/P-15_orders.png` (3 cards: Paid/Accept, Accepted/Mark packed, Ready for pickup/Verify pickup code)

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p15-orders`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Marketplace orders list (cards on phone, list + detail pane on web), state-machine buttons driven by `allowed_actions`, pickup-code verification sheet, cancel with reason, badge counts from `counts`.

Depends on:
- P-01: auth, role provider, Dio interceptors (`X-Salon-Id`, idempotency key; spec relies on it for double-tap protection).
- Adaptive shell + More screen (P-22) for the entry point and badge; role guard in router.
- Shared: `sb_core` `Money.format`, `SbDates.format` (`Thu 29 Oct, 9:30 AM`), `ApiException`; `sb_ui` `SbEmptyState`, `SbErrorPanel`, `SbSkeleton`, `SbBottomSheet`, `showSbConfirm`, `SbDangerButton`, `SbSidePanel` (planned in P-13/P-14 plans; build once).
- Existing in `sb_ui`: `SbCard`, `SbStatusPill` (booking `SbStatus` only: no paid/accepted/packed/ready/collected/delivered; must extend, see section 5), `SbPrimaryButton`, `SbChoiceChip`.
- Code state: no shell, no auth, no l10n yet; `pubspec` has riverpod 3 only.

## 2. Files to create / modify

Create `apps/partner/lib/features/orders/`:
- `data/order_models.dart` (freezed + json: `PartnerOrder`, `OrderClient`, `OrderLine`, `OrderAddress`, `OrderRefund`, `OrderPage` with `counts`)
- `data/order_repository.dart`
- `data/order_status.dart` (`OrderStatus` enum + `OrderAction` enum with lenient `fromApi` returning `unknown`)
- `application/orders_controller.dart` (`OrdersController` AsyncNotifier, family by `OrdersFilter`)
- `application/orders_filter_provider.dart` (status, fulfilment, q with debounce)
- `application/order_actions_controller.dart` (per-order in-flight set, action execution)
- `application/orders_badge_provider.dart` (action-needed count for More/sidebar)
- `application/orders_permissions.dart`
- `presentation/orders_screen.dart` (adaptive)
- `presentation/widgets/order_card.dart`
- `presentation/widgets/order_detail_view.dart` (phone: pushed route/sheet; web: right pane)
- `presentation/widgets/order_action_button.dart`
- `presentation/widgets/pickup_code_sheet.dart`
- `presentation/widgets/cancel_order_dialog.dart`
- `presentation/widgets/orders_filter_bar.dart`

Modify:
- `apps/partner/lib/router.dart`: `GoRoute('/orders')` with `redirect` to a "No access" page for specialist; child `/orders/:id` on phone.
- `apps/partner/lib/shell`: sidebar item (owner/manager), More row badge (P-22).
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_ui/lib/theme/sb_theme.dart`: add order status support (see section 5).
- `packages/sb_core`: `OrderStatus` is feature-local; no change except shared formatters.

## 3. Data layer

All with `X-Salon-Id`; errors `ErrorResponse {code, message, field}`.

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/v1/partner/orders` | `status`, `fulfilment_type` (`pickup`/`delivery`, regex-validated), `q` (<=100), `cursor`, `limit` (1..50, default 20) (a `salon_id` query param also exists; not used, header carries the salon) | `PartnerOrderListOut {items, counts: map, next_cursor}` |
| POST | `/v1/partner/orders/{id}/accept` | OpenAPI declares NO body (spec says optional `note`: gap) | `PartnerOrderOut` |
| POST | `.../pack` | no body | `PartnerOrderOut` |
| POST | `.../ready` | no body | `PartnerOrderOut` |
| POST | `.../collect` | `OrderCollectRequest {pickup_code: ^\d{6}$}` | `PartnerOrderOut` |
| POST | `.../deliver` | no body in path definition (schema `OrderDeliverRequest {note?}` exists but is unreferenced by the route) | `PartnerOrderOut` |
| POST | `.../cancel` | `OrderPartnerCancelRequest {reason, maxLength 500}` | `PartnerOrderOut` (`cancel_reason`, `refund_initiated`, `stock_restored`, `refund`) |

`PartnerOrder` mirrors `PartnerOrderOut`: `id, referenceCode?, customerName, client{fullName, phone}, status (String), fulfilmentType, deliveryAddress?, lines[{productName, quantity, unitPriceCents, lineTotalCents, imageUrl}], subtotalCents, discountCents, deliveryFeeCents, totalCents, commissionRatePercent, commissionCents, netPayoutCents, notes?, allowedActions (List<String>), createdAt, collectedAt?, cancelledAt?, cancelReason?, refundInitiated, stockRestored, refund?`. The model parses but never exposes `pickup_code` (field omitted from the Dart class by design; spec AC5).
Exact line shape (`lines` items schema) must be checked against the generated model when coding; names from spec.

Repository: `list(OrdersFilter, {cursor, limit})`, `accept(id)`, `pack(id)`, `ready(id)`, `collect(id, code)`, `deliver(id)`, `cancel(id, reason)`. One generic `_action(id, verb)` helper.
Error mapping: 409 -> `OrderStateConflict(message)`; 422/409 on collect -> `PickupCodeRejected(message)` (code string unknown: treat any 4xx on collect as rejected and show API `message`; 429 -> `TooManyAttempts`); 403 -> `NoAccess`; 404 -> `OrderGone`; others generic.

## 4. Application / state

`OrdersController extends AsyncNotifier<OrdersState>` (family parameter `OrdersFilter {status?, fulfilment?, q}`):
```
OrdersState { List<PartnerOrder> items; Map<String,int> counts; String? nextCursor; bool loadingMore; DateTime loadedAt }
```
- `build`: GET page 1. Pull-to-refresh = `ref.invalidateSelf` keeping previous data (`AsyncValue` with `isRefreshing`, shows cached list under inline error per spec).
- `loadMore()` by cursor on scroll.
- `OrderActionsController` holds `Set<String> busyIds` (+ per-order last error). `perform(order, OrderAction a, {code, reason})`: guards double tap (id in busy), calls repo, on 200 replaces the item in `OrdersController` via `replaceOrder(updated)`; if the new status no longer matches the active status filter or is terminal (collected/delivered/cancelled) while viewing active list, remove it. Not optimistic (spec §7). On `OrderStateConflict`: snackbar with API message + `invalidate` list (AC8). Idempotency key comes from Dio interceptor.
- Badge: `ordersBadgeProvider` derives needed-action count from `counts` for keys that need action (assumed `paid`, `accepted`, `packed`, `ready`; keys undocumented: Q4) via one config constant `kOrderActionNeededStatuses`; refreshes when `OrdersController` refreshes, on app resume (`WidgetsBindingObserver`), and polling every 60 s while the screen is visible (`Timer.periodic` in a provider disposed on `ref.onDispose`). Real-time: WebSocket not in OpenAPI (Q5); leave a `OrdersRealtimeSource` interface with a no-op polling implementation so a WS impl can slot in.
- States: loading skeleton cards; empty (global vs per-filter copy); error card with Retry keeping cached list; offline banner (`connectivityProvider`) disables all action buttons; 403 -> `NoAccess` state widget.
- Search: `q` debounced 350 ms, min 0 chars, trimmed, max 100.

Status to UI mapping: `OrderStatus.fromApi(String)`; unknown strings render the raw string in a neutral pill (API has no enum, Q3).

## 5. Presentation

Phone (`OrdersScreen`, route from More): `Scaffold` + header row `[circular back button (Semantics 'Back', 44+) , Text('Orders', headlineMedium)]`, then `ListView` of `OrderCard`s with `SbTokens.gap12` spacing, padding `screenPadding`.
`OrderCard` (`SbCard`): row `Text('SB-1046 · Nimal Perera', titleMedium, ellipsis)` + `OrderStatusPill`; `Text('Argan Repair Shampoo × 1 · Pickup', bodyMedium muted)` for the first line, "+N more items" for several; full-width `OrderActionButton` (outlined button style as in PNG; uses theme `outlinedButtonTheme`; spinner when busy; disabled offline). Tap card -> detail (phone: push `/orders/:id`; web: select in right pane).
Action label from `allowed_actions` in fixed priority order: `accept`->Accept, `pack`->Mark packed, `ready`->Mark ready, `collect`->Verify pickup code, `deliver`->Mark delivered. If several are allowed, the card shows the first and the detail shows all. Unknown action values ignored. Cancel is NOT on the card.
Web/tablet (>= 900 px): header with title, filter chips (`SbChoiceChip`: All, Paid, Accepted, Packed, Ready, Done, Cancelled), fulfilment toggle (two `SbChoiceChip`s Pickup/Delivery plus All), `TextField` search; `Row(Expanded(list), SizedBox(420, detail pane))`.
`OrderDetailView`: header (reference, status pill, created `Thu 29 Oct, 9:30 AM`), client name + phone (tap-to-call via `url_launcher`, optional), lines with image, `qty × unit`, line total; delivery address / notes; money block read only: Subtotal, Discount, Delivery fee, Total, `Commission (x%)`, `Net payout` all straight from API cents; actions row (primary action as `SbPrimaryButton`, black pill, in detail; card keeps outlined); secondary text action "Cancel order" (only if `allowed_actions` contains `cancel`; if `cancel` is not in the list the permitted set is unknown, see gap) ; after cancel: "Stock restored" and refund info (`refund.amountCents`, `status`, `method`) from the response.
`PickupCodeSheet` (`SbBottomSheet` phone / dialog web): 6-digit `TextField` (`FilteringTextInputFormatter.digitsOnly`, `LengthLimitingTextInputFormatter(6)`, numeric keyboard, `autofillHints: oneTimeCode` off), inline error text from API message, black `SbPrimaryButton('Confirm hand-over')` enabled only at exactly 6 digits, spinner while sending, sheet stays open on rejection. Never shows the order's `pickup_code`.
`CancelOrderDialog`: multiline reason (required, trimmed non-empty, max 500 with counter), `SbDangerButton('Cancel order')`, secondary "Keep order".
New `sb_ui` additions:
- Order status pill: extend `SbStatus` with `paid, accepted, packed, ready, collected, delivered` and `context.sb.status()` cases (Paid = info `SbColors.info/infoBg`; Accepted = neutral per PNG (purple-ish text on `soft`/sand: take colours from tokens, propose `SbColors.cocoa`/`soft` and ask design if the purple in the PNG is intended); Packed = `amberDark`/`amberTint`; Ready = `amberDark`/`amberTint` ("Ready for pickup" label via `label:` override, the PNG uses amber); Collected/Delivered = success; cancelled already exists). Wrapping in `SbOrderStatusPill` is an alternative to avoid touching the shared booking enum used by the client app; recommend a new `SbOrderStatus` enum + `SbOrderStatusPill` to keep client-app statuses stable.
- `SbOutlinedActionButton` (full width, 44+ min height, loading spinner) if the plain `OutlinedButton` is insufficient.
- `SbDangerButton`, `showSbConfirm`, `SbSidePanel`, `SbEmptyState`, `SbErrorPanel`, `SbSkeleton` (shared).
Text scale 200%: card title wraps to 2 lines, buttons grow in height, detail scrolls.

## 6. Role rules

| Role | Behaviour |
|---|---|
| Owner | List, all actions, cancel |
| Manager | Same (assumed Q1) |
| Specialist | No menu/More item; route redirect to `/` or "No access" screen |

Enforced by: `canAccessOrdersProvider` used in (1) shell menu filtering, (2) `GoRouter.redirect` for `/orders*`, (3) screen `NoAccess` state if API returns 403. Action buttons are additionally derived from `allowed_actions` from the API (API remains source of truth). The Manager restriction in instructions is only about payout account and fees: net payout/commission figures in detail are read only for both roles (confirm managers may see commission, Q).

## 7. Validation, confirmations, formatting

- Cancel: confirm dialog with required reason (min 1 char after trim, max 500), `danger` confirm button. This is the only destructive action.
- Other transitions (accept, pack, ready, deliver, collect) are single-tap, not destructive, no confirm; collect confirmed by code entry.
- Pickup code: digits only, exactly 6; never log or display `pickup_code`; wrong-code error shown inline, order unchanged.
- Money: `Money.format(cents)` -> `LKR 1,500` for lines, totals, fee, commission, net. No arithmetic (no summing lines, no totals).
- Dates: `SbDates.format(createdAt)` -> `Thu 29 Oct, 9:30 AM` in salon time zone (from settings; fall back to device if settings not loaded).
- Truncation: single-line ellipsis for names/product; "+N more items".

## 8. ARB keys

`ordersTitle`, `ordersBackSemantics`, `ordersFilterAll`, `ordersStatusPaid`, `ordersStatusAccepted`, `ordersStatusPacked`, `ordersStatusReady`, `ordersStatusReadyForPickup`, `ordersStatusCollected`, `ordersStatusDelivered`, `ordersStatusCancelled`, `ordersStatusUnknown`, `ordersFilterDone`, `ordersFulfilmentPickup`, `ordersFulfilmentDelivery`, `ordersSearchHint`, `ordersLineSummary` (`product`, `qty`, `fulfilment`), `ordersMoreItems` (`count`), `ordersActionAccept`, `ordersActionPack`, `ordersActionReady`, `ordersActionCollect`, `ordersActionDeliver`, `ordersPickupCodeTitle`, `ordersPickupCodeHint`, `ordersPickupCodeConfirm`, `ordersPickupCodeWrong`, `ordersPickupCodeTooMany`, `ordersCancel`, `ordersCancelTitle`, `ordersCancelReasonLabel`, `ordersCancelReasonRequired`, `ordersCancelConfirm`, `ordersKeepOrder`, `ordersStockRestored`, `ordersRefundInitiated`, `ordersRefundSummary` (`amount`, `status`, `method`), `ordersSubtotal`, `ordersDiscount`, `ordersDeliveryFee`, `ordersTotal`, `ordersCommission` (`percent`), `ordersNetPayout`, `ordersClient`, `ordersDeliveryAddress`, `ordersNotes`, `ordersEmptyTitle`, `ordersEmptyBody`, `ordersEmptyFiltered`, `ordersErrorTitle`, `ordersRetry`, `ordersOffline`, `ordersConflictReloaded`, `ordersNoAccess`, `ordersUpdated`.

## 9. Tests

Unit (`test/features/orders/`):
1. `OrderStatus.fromApi` known values and unknown fallback; `OrderAction` parsing ignores unknown.
2. Action label selection: `[accept]`->Accept; `[]`->none; `[collect]` on delivery order never produces deliver; label priority with multiple.
3. Repository: list query params (`status`, `fulfilment_type`, `q`, `cursor`, `limit`), collect body `{pickup_code}`, cancel body `{reason}`; 409 -> `OrderStateConflict` with API message.
4. `OrdersController`: pagination append; `replaceOrder` removes terminal items from active filter; 409 triggers refetch; busy set prevents double POST.
5. `PartnerOrder.fromJson` never exposes pickup code (no field).
6. Badge provider counts only configured needs-action keys from `counts`.
Widget:
7. Card renders reference, customer, line summary, status pill, button text from `allowed_actions`; no button when empty.
8. Tap Accept: button shows spinner + disabled, then card updates (fake repo returns accepted order).
9. Pickup sheet: confirm disabled until 6 digits; letters filtered; wrong code keeps sheet open with API message; success closes and removes the card.
10. Delivery order Ready shows "Mark delivered" and no code sheet.
11. Cancel dialog: confirm disabled with empty/whitespace reason; confirm button uses `danger` colour; after 200 detail shows "Stock restored" and refund line.
12. Loading skeleton, empty (global and filtered), error with retry keeping cached list, offline banner disables buttons.
13. Role: specialist redirected (router test); 403 shows "No access".
14. 200% text scale at 390 px no overflow; icon buttons have Semantics; targets >= 44 px.
Golden: `orders_390.png` (3 cards as PNG) and `orders_1280.png` (list + detail pane).

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p15-orders`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. Prereq check; add deps (freezed, json, url_launcher optional, connectivity); ARB scaffolding.
2. Models + enums + tests (including pickup_code omission).
3. Repository + tests with fake adapter.
4. `sb_ui`: `SbOrderStatusPill`, `SbOutlinedActionButton`, shared state widgets, `SbDangerButton` (if not already present).
5. `OrdersController`, filter provider, actions controller + tests.
6. Phone screen: cards, states, pagination, pull to refresh.
7. Pickup code sheet and cancel dialog.
8. Detail view (money block, refund info) and phone route `/orders/:id`.
9. Web two-pane layout, filter chips, fulfilment toggle, search.
10. Badge provider + polling + resume refetch; wire into More/sidebar.
11. Role guard (router redirect, menu filtering, 403 state).
12. Offline banner/disable; a11y checks.
13. Goldens 390/1280; analyze; test.

## 11. Open questions / gaps / risks

- Q3 (blocking for exact labels): `status` and `allowed_actions` are free strings with undocumented values. Plan hardcodes the expected set behind a lenient parser; need backend to confirm, including whether `cancel` appears in `allowed_actions` (if not, when is Cancel shown? Fallback: show Cancel for statuses paid/accepted/packed/ready, which is client-side business logic and should be avoided: ask backend).
- Q4: `counts` keys undocumented; badge uses a constant list.
- Q5: no WebSocket contract; plan polls every 60 s + resume.
- OpenAPI: `accept/pack/ready/deliver` routes have no request body, although spec and schemas (`OrderActionNoteRequest`, `OrderDeliverRequest`) suggest an optional `note`. Plan sends no body; no note UI.
- Wrong-code error `code` and lockout behaviour undocumented; plan treats any 4xx on collect as an inline error and 429 as too many attempts.
- `PartnerOrderOut.pickup_code` is returned to the partner app; flagged as a security smell (client secret). Plan omits it from the model.
- `OrderStatus` colours: PNG shows "Accepted" in a purple/sand tone not in current tokens; need design confirmation before adding a token.
- Extending shared `SbStatus` would affect the Client app (shared package); plan uses a separate `SbOrderStatus`.
- Role matrix (Q1) and whether Managers may see commission/net payout.
- `salon_id` query param exists alongside `X-Salon-Id`; plan uses the header only.
- Idempotency header is assumed provided by the Dio interceptor from P-01; not yet present in `sb_api/api_client.dart`.
