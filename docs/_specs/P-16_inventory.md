# P-16 Inventory

Refs: US-P-31, SRS BR-13. No PNG (instructions: web table; phone "Opens on web"). API: `/v1/partner/inventory*` (API-29).

## 1. Goal and roles
Show product stock, flag low and out-of-stock items, and adjust stock with a reason. Stock never goes below zero.

| Role | Access |
|---|---|
| Owner | View, adjust, history |
| Manager | View, adjust, history (assumed, Q1) |
| Specialist | No access (assumed) |

## 2. User stories
- US-P-31 (adjust with reason, never below zero, low-stock alerts), BR-13.
- Push: "low stock" notification (instructions §1) deep-links here.

## 3. Layout
- Web/tablet: page title "Inventory"; four summary stat cards (Total products, In stock, Low stock amber, Out of stock red) from `summary`; filter chips All / Low stock / Out of stock; search; `data_table_2` table: image, name, SKU, category, price, stock (with low badge), last adjusted, row action "Adjust". Row click opens a side panel with adjustment history.
- Phone: More lists "Inventory, N products low on stock, opens on web" (`mobile/P-22_more.png`). Tapping opens the web app (external link `partner.stylebook.lk/inventory`). No native phone screen in v1 (Q2).
- Adjust dialog: stepper (- / +, numeric field), reason chips + free text, optional note, black "Save adjustment" pill.

## 4. Data and API map
| UI element | Endpoint | Request | Response fields | Errors |
|---|---|---|---|---|
| Summary cards | GET `/v1/partner/inventory` | | `PartnerInventoryListOut.summary` (`PartnerInventorySummaryOut`: `total_products`, `in_stock`, `low_stock`, `out_of_stock`; the `*_count` duplicates are aliases, use one set) | 401, 403 |
| Table | GET `/v1/partner/inventory` | `low_stock` (bool), `out_of_stock` (bool), `q`, `cursor`, `limit` (default 20) | `items[]` `PartnerInventoryItemOut`: `id`, `name`, `sku`, `category`, `image_url`, `price_cents`, `stock`, `low_stock_threshold`, `is_active`, `is_low_stock`, `is_out_of_stock`, `last_adjusted_at`; `next_cursor` | 422 |
| Save adjustment | POST `/v1/partner/inventory/{product_id}/adjust` | `StockAdjustmentRequest {quantity_delta (int, signed), reason (1..255 chars, required), note}` | `StockAdjustmentOut`: `stock_before`, `quantity_delta`, `stock_after`, `low_stock_alert`, `reason`, `created_at` | 404, 409/422 if result would be below 0 (code undocumented, Q3), 403 |
| History panel | GET `/v1/partner/inventory/{product_id}/adjustments` | `cursor`, `limit` | `StockAdjustmentListOut`: `product{name, sku, current_stock, low_stock_threshold}`, `items[]{quantity_delta, reason, stock_after, adjusted_by_name, created_at}` | 404 |

## 5. Acceptance criteria
1. Given the page opens, then summary cards and the table load from one GET; stat values are the API values.
2. Given I choose "Low stock", then GET is re-sent with `low_stock=true`; same for "Out of stock" with `out_of_stock=true`.
3. Rows with `is_low_stock` show an amber badge "Low (N left)"; `is_out_of_stock` shows a red "Out of stock" pill.
4. Given stock is 3, when I open Adjust, then the minus stepper stops so that `stock + quantity_delta >= 0`; with stock 0 the minus control is disabled. (The API remains the authority.)
5. Save is disabled until `quantity_delta != 0` and reason is non-empty (max 255).
6. On 200 the row updates to `stock_after`, the summary refetches, and a snackbar shows "Stock updated: 3 -> 7".
7. If the API rejects with below-zero error, the dialog stays open and shows the API `message`; no local change.
8. History lists newest first with signed delta (green `+5`, red `-2`), reason, who, date (`Thu 29 Oct, 9:30 AM`).
9. Specialist cannot open the route; 403 shows "No access".
10. Inactive products (`is_active=false`) show a muted "Hidden" tag and can still be adjusted.

## 6. States
- Loading: table skeleton rows and shimmer stat cards.
- Empty: "No products yet. Add products in the marketplace setup." (no create endpoint, see Q4); empty filter: "Nothing low on stock".
- Error: inline retry card.
- Offline: view cached last list (read only), adjust disabled with banner.
- Real-time: low-stock push and WebSocket stock events (not in OpenAPI, Q5). Fallback: refetch on resume and after each order status change.

## 7. Rules and edge cases
- Reason is mandatory for every change (BR-13). Suggested chips: Restock, Sold in salon, Damaged, Count correction, Other (free text). The chips are UI helpers; the API stores a string.
- Adjusting is a delta, not an absolute set. For "Count correction" the UI may compute the delta from the entered count, but sends `quantity_delta`.
- Concurrent edits: server value wins; refetch on 409.
- Low stock threshold is read only here (no endpoint to change it).

## 8. Gaps and questions
- Q1: Role matrix undefined.
- Q2: Instructions say phone "Opens on web". Confirm that no phone UI is wanted (the More badge still needs `summary.low_stock`).
- Q3: Error code for below-zero adjustment is undocumented; reason values are free text, no enum.
- Q4: No endpoint to create or edit products or set `low_stock_threshold` (not required by US-P-31).
- Q5: No WebSocket contract for stock.
- Q6: `PartnerInventorySummaryOut` has duplicate fields (`in_stock`/`in_stock_count`, etc.). Ask backend which to keep.
