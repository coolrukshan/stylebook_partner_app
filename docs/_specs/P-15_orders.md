# P-15 Orders

Refs: US-P-30. Mockup: `mobile/P-15_orders.png`. API: `/v1/partner/orders*` (API-28).

## 1. Goal and roles
Marketplace (shop) orders for the salon move through paid, accepted, packed, ready, then collected (pickup) or delivered (delivery). The pickup code is checked before hand-over.

| Role | Access |
|---|---|
| Owner | List, all actions, cancel |
| Manager | List, all actions, cancel (assumed, see Q1) |
| Specialist | No menu item, route guarded (assumed, see Q1) |

## 2. User stories
- US-P-30 (move orders through accept, pack, ready, collected and verify pickup code). SRS ref: none in instructions (see Q2). Order commission and payout come from the API.
- US-P-00b (role-filtered menu).

## 3. Layout
- Phone (PNG): back pill + title "Orders"; list of white cards (`SbCard`): `reference_code · customer_name`, status pill (right), line summary `product_name × quantity · Pickup|Delivery`, one full-width outlined action button for the next step.
- Web/tablet: same cards in a table or a two-pane layout: list left, order detail panel right (lines, totals, client phone, delivery address, notes). Filter chips: All, Paid, Accepted, Packed, Ready, Done, Cancelled; fulfilment toggle Pickup / Delivery; search box (`q`).
- Status pills use `sb_ui` status pill tokens: Paid = info (blue), Accepted = neutral, Ready for pickup = amber.
- Pickup-code entry: bottom sheet (phone) or modal (web) with 6 digit field and black "Confirm hand-over" pill.
- Cancel is a secondary text action in the detail view (not on the card).

## 4. Data and API map
All calls send `X-Salon-Id`; errors use `ErrorResponse {code, message, field}`.

| UI element | Endpoint | Request | Response fields used | Errors |
|---|---|---|---|---|
| Order list, tab badge | GET `/v1/partner/orders` | query `status`, `fulfilment_type` (`pickup`/`delivery`), `q` (max 100), `cursor`, `limit` (1..50, default 20) | `PartnerOrderListOut`: `items[]`, `counts` (map string->int), `next_cursor`. Per `PartnerOrderOut`: `id`, `reference_code`, `customer_name`, `client{full_name, phone}`, `status`, `fulfilment_type`, `lines[]{product_name, quantity, unit_price_cents, line_total_cents, image_url}`, `total_cents`, `delivery_fee_cents`, `delivery_address`, `notes`, `allowed_actions`, `created_at` | 401, 403, 422, 429 |
| Accept | POST `/v1/partner/orders/{order_id}/accept` | `OrderActionNoteRequest` (optional `note`) | `PartnerOrderOut` (replace card) | 404, 409 (state changed), 403 |
| Mark packed | POST `.../pack` | `OrderActionNoteRequest` | same | 409 |
| Mark ready | POST `.../ready` | `OrderActionNoteRequest` | same | 409 |
| Verify pickup code | POST `.../collect` | `OrderCollectRequest {pickup_code}` (6 digits) | same (`collected_at`) | 409 or 422 on wrong code (code string not documented, see Q3), 429 |
| Mark delivered | POST `.../deliver` | `OrderDeliverRequest` (optional `note`) | same | 409 |
| Cancel order | POST `.../cancel` | `OrderPartnerCancelRequest {reason}` required | `cancel_reason`, `refund_initiated`, `stock_restored`, `refund{amount_cents,status,method}` | 409, 422 |
| Money in detail | (from list) | | `subtotal_cents`, `discount_cents`, `delivery_fee_cents`, `total_cents`, `commission_rate_percent`, `commission_cents`, `net_payout_cents` shown as read only | |

The app never computes totals, commission or net payout; it shows the API values (format `LKR 1,500`).

## 5. Acceptance criteria
1. Given orders exist, when the screen opens, then cards show newest first with `reference_code`, customer, line summary, fulfilment type, status pill, and pagination loads on scroll via `next_cursor`.
2. The action button on a card is derived from `allowed_actions`, never from the status text. Mapping: `accept` = "Accept", `pack` = "Mark packed", `ready` = "Mark ready", `collect` = "Verify pickup code", `deliver` = "Mark delivered". If `allowed_actions` is empty, no button is shown.
3. Given status Paid, when I tap Accept, then POST accept is sent, the button is disabled with a spinner, and on 200 the card updates to Accepted with the next button.
4. Given a pickup order Ready, when I tap "Verify pickup code", enter 6 digits and confirm, then POST collect is sent; on 200 the order shows Collected and leaves the active list; on a wrong code the sheet stays open with the API message and the order is unchanged.
5. The pickup code field accepts digits only, exactly 6; confirm is disabled otherwise. The app never displays `pickup_code` to the salon (it is the client's secret).
6. Given a delivery order Ready, the button is "Mark delivered" (no code).
7. Cancel opens a confirm dialog with required reason (min 1 char); confirm button is `danger`. On 200 the detail shows "Stock restored" and refund info from `stock_restored`, `refund_initiated`, `refund`.
8. A 409 on any action reloads the order list, and shows the API `message` in a snackbar.
9. Tab or More badge shows the count of orders needing action from `counts` (see Q4).
10. Role guard: a Specialist cannot reach the route; a 403 shows a "No access" state.
11. Touch targets 44 px minimum; back and icon buttons have Semantics labels; all strings in ARB.

## 6. States
- Loading: skeleton cards.
- Empty: "No orders yet. Marketplace orders will appear here." (per filter: "No orders in this status").
- Error: inline error card with Retry, keeps cached list if any.
- Offline: banner "You are offline", action buttons disabled (orders are not cached for write).
- Real-time: new order and status changes should arrive by WebSocket (instructions §1). Not in OpenAPI, see Q5. Until then: pull to refresh plus refetch on app resume, poll every 60 s while visible.

## 7. Rules and edge cases
- Every state change is a server call; update UI from the returned `PartnerOrderOut`, not optimistically.
- Double tap protection: send an idempotency key header if the Dio client adds one (already in client rules).
- Cancel is destructive: confirm first, reason required, `danger` button.
- Two staff acting on the same order: second gets 409, refetch.
- Long names and lines truncate with ellipsis; show "+N more items" for several lines.

## 8. Gaps and questions
- Q1: Role matrix for orders is not defined (instructions only give Manager "no payout account, no fee changes"). Assumed Owner and Manager allowed, Specialist not. Confirm with PM.
- Q2: US-P-30 has no SRS id.
- Q3: `status` is a free `string` in OpenAPI (no enum) and `allowed_actions` has no documented values. Dev needs the exact lists (expected: paid, accepted, packed, ready, collected, delivered, cancelled) and the error `code` for a wrong pickup code and for too many attempts.
- Q4: `counts` keys are undocumented; need them to build badges.
- Q5: No WebSocket contract in OpenAPI (orders, status changes). Ask backend for channel name and event payloads.
- Q6: Instructions say "Paid -> accepted -> ..." but the mockup has no decline or cancel on the card; cancel exists in the API. Decision needed: show cancel only in detail (proposed here).
- Q7: Mockup shows only 3 cards; no filters. Filters here are a proposal derived from API params.
