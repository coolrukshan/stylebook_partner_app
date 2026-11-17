# P-16 Inventory — Implementation Plan

- Spec: [docs/_specs/P-16_inventory.md](../_specs/P-16_inventory.md)
- Design: no PNG. Reference `mobile/P-22_more.png` (More row "Inventory, N products low on stock, opens on web") and the web prototype board described in the instructions (§3 P-16).

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p16-inventory`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Web/tablet stock table with four summary cards, filter chips, search, adjust dialog (signed delta + mandatory reason) and a history side panel. On phone there is no native screen in v1: the More row opens the web app and shows the low-stock count badge.

Depends on:
- P-01 (auth, role provider, Dio interceptors), shell + P-22 More (row and badge), router guard.
- Shared: `Money.format`, `SbDates.format`, `ApiException`; `sb_ui` `SbEmptyState`, `SbErrorPanel`, `SbSkeleton`, `SbSidePanel`, `showSbConfirm`/dialog helper, `SbDangerButton` (planned in the P-13/P-14/P-15 plans; build once), `SbPillBadge` (P-13).
- New `sb_ui`: `SbStatCard` (the instructions list a stat card as a shared component; P-02 Today also uses stat cards, so coordinate: build it once with `highlight` variants amber/danger), `SbDataTable` wrapper (or `data_table_2` directly in feature with sb_ui theming), `SbStepper`.
- Order status changes (P-15) refetch inventory (spec fallback for real-time).
- Code state: nothing exists yet beyond a placeholder Today screen; `data_table_2`, `url_launcher` not in `pubspec`.

## 2. Files to create / modify

Create `apps/partner/lib/features/inventory/`:
- `data/inventory_models.dart` (freezed + json: `InventoryItem`, `InventorySummary`, `InventoryPage`, `StockAdjustmentResult`, `AdjustmentHistoryItem`, `AdjustmentHistoryPage`, `InventoryProductBrief`)
- `data/inventory_repository.dart`
- `application/inventory_controller.dart` (AsyncNotifier family by `InventoryFilter`)
- `application/inventory_filter_provider.dart` (`all | low | out`, `q`)
- `application/adjust_stock_controller.dart` (per-dialog Notifier)
- `application/adjustment_history_controller.dart` (family by product id, cursor paging)
- `application/inventory_badge_provider.dart` (low-stock count for More badge)
- `application/inventory_permissions.dart`
- `presentation/inventory_screen.dart` (adaptive: table on >= 900, "open on web" info state below)
- `presentation/widgets/inventory_summary_row.dart`
- `presentation/widgets/inventory_table.dart`
- `presentation/widgets/stock_cell.dart` (number + low/out badge)
- `presentation/widgets/adjust_stock_dialog.dart`
- `presentation/widgets/adjustment_history_panel.dart`
- `presentation/widgets/open_on_web_state.dart`

Modify:
- `apps/partner/lib/router.dart`: `/inventory` route with role redirect.
- Shell sidebar item (owner/manager) and More row (P-22): tap opens `Uri.parse('https://partner.stylebook.lk/inventory')` via `url_launcher` (put host in `SbConfig`, not hard-coded in the widget; check `packages/sb_core/lib/src/config.dart`).
- `apps/partner/pubspec.yaml`: `data_table_2`, `url_launcher`, freezed/json deps.
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_ui`: `SbStatCard`, `SbStepper`, `SbDataTable` theming helper.
- `packages/sb_core/lib/src/config.dart`: `webAppUrl`.

## 3. Data layer

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/v1/partner/inventory` | `low_stock` bool, `out_of_stock` bool, `q` (<=100), `cursor`, `limit` (`salon_id` query exists, unused) | `PartnerInventoryListOut {items, summary, next_cursor}` |
| POST | `/v1/partner/inventory/{product_id}/adjust` | `StockAdjustmentRequest {quantity_delta:int, reason (1..255), note?}` | `StockAdjustmentOut {id, product_id, product_name, stock_before, previous_stock, quantity_delta, stock_after, low_stock_alert, reason, note, adjusted_by, created_at}` |
| GET | `/v1/partner/inventory/{product_id}/adjustments` | `cursor`, `limit` | `StockAdjustmentListOut {product{id,name,sku,current_stock,low_stock_threshold}, items[{id, quantity_delta, reason, stock_after, adjusted_by_name, adjuster{id,full_name}, created_at}], next_cursor}` |

Models: `InventoryItem {id, name, sku?, category?, imageUrl?, priceCents, stock, lowStockThreshold, isActive, isLowStock, isOutOfStock, lastAdjustedAt?, updatedAt}`. `InventorySummary` uses ONE set: `total_products`, `in_stock`, `low_stock`, `out_of_stock` (fall back to `*_count` aliases in `fromJson` if the primary is absent, Q6). Use `stock_before` (ignore `previous_stock` alias). `low_stock_alert` on the item list is ignored in favour of `is_low_stock`.
Repository: `list(filter, {cursor, limit})`, `adjust(productId, delta, reason, {note})`, `history(productId, {cursor, limit})`.
Error mapping: 403 -> `NoAccess`; 404 -> `ProductGone` (refresh list); 409 or 422 on adjust -> `AdjustRejected(message)` shown inline (below-zero code undocumented, Q3; any 409/422 shows API `message`, never a local guess); 429 -> rate limit; 422 on list -> generic.

## 4. Application / state

`InventoryController extends AsyncNotifier<InventoryState>` (family by filter):
```
InventoryState { List<InventoryItem> items; InventorySummary summary; String? nextCursor; bool loadingMore; DateTime loadedAt }
```
- One GET provides summary + items (AC1). Filters: All -> no flags; Low stock -> `low_stock=true`; Out -> `out_of_stock=true`. Search debounced 350 ms. Note the summary in the response may reflect the filter or not (undocumented): summary cards should stay stable, so keep a separate `inventorySummaryProvider` fed from the unfiltered ("All", empty q) request and updated from any response only when no filter is set; refetch after adjust.
- `applyAdjustment(StockAdjustmentResult r)`: patches item stock to `stock_after` and `lastAdjustedAt = r.createdAt`; then `ref.invalidate(summary)` / refetch because flags (`is_low_stock`, `is_out_of_stock`) are computed server-side; the row's badges update after the refetch (do not recompute flags locally).
- `AdjustStockController` state: `{delta, reason, note, status (idle|saving|error), errorMessage}`. `save()` sends request; on success returns result to dialog caller, which closes and shows snackbar "Stock updated: 3 -> 7" (from `stock_before`/`stock_after` in the response). On rejection stays open with API message, no local change. On 409 also refetch list (server value wins).
- `AdjustmentHistoryController(productId)`: newest-first paging by cursor.
- `inventoryBadgeProvider`: from a light call to `GET /v1/partner/inventory?limit=1` reading `summary.low_stock` (works for the phone More badge; no dedicated endpoint). Refreshes on app resume and after order status updates (listen to P-15 `ordersControllerProvider` changes) and push "low stock" deep link opens `/inventory?filter=low`.
- States: loading = shimmer stat cards + skeleton rows; empty = "No products yet..." (empty filter: "Nothing low on stock"); error = inline retry card (section-level: summary and table share one request so one card); offline = cached last list (read-only; `drift` cache is out of scope for this slice: keep last `AsyncData` in memory and show "Last updated"), adjust buttons disabled with banner.

## 5. Presentation

Web/tablet (>= 900 px):
```
Page(title 'Inventory' headlineMedium)
 SbStatCardRow: [Total products, In stock, Low stock (amber highlight), Out of stock (danger)]  // values from summary
 Row: filter chips (SbChoiceChip: All / Low stock / Out of stock) + search TextField (inputDecorationTheme)
 DataTable2 (sticky header, horizontal scroll under 900 px tablet width):
   image(40 thumb, rounded) | name (ellipsis; "Hidden" tag if !isActive) | SKU | category | price (Money) | stock (StockCell) | last adjusted (SbDates, '-' if null) | [Adjust] outlined button (44 min)
 row tap -> SbSidePanel(AdjustmentHistoryPanel)
 load more row on scroll end
```
`StockCell`: number + `SbPillBadge` amber "Low (N left)" when `isLowStock`, danger "Out of stock" when `isOutOfStock`.
`AdjustStockDialog`: header product name + current stock; `SbStepper` (minus/plus icon buttons 44 px with Semantics "Decrease stock"/"Increase stock", numeric `TextField` accepting signed int, `+`/`-` prefix, minus disabled when `stock + delta <= 0`, i.e. spec AC4, UI convenience only); reason chips (`SbChoiceChip`: Restock, Sold in salon, Damaged, Count correction, Other) + free-text field (required when Other or to refine; reason string sent = chip label or text, max 255 with counter), optional note, black `SbPrimaryButton('Save adjustment')` disabled until `delta != 0` and `reason.trim().isNotEmpty`. "Count correction" offers an optional "Counted quantity" field that sets delta = counted - stock (spec allows this client arithmetic for UI input; sent value is still `quantity_delta`).
Because negative adjustments (stock down) are destructive per project rules ("stock down asks confirmation, reason required"): when `delta < 0` the dialog's Save becomes a two-step: first tap changes the button to `SbDangerButton('Yes, reduce stock by N')` with a prompt; second tap sends.
`AdjustmentHistoryPanel`: product name, SKU, current stock; list newest first: signed delta (green `+5` using `SbColors.success`, red `-2` using `danger`, always with sign so colour is not the only cue), reason, `adjusted_by_name`, `SbDates.format(createdAt)`, `stock_after`; load more; empty "No adjustments yet".
Phone (< 900 px): `/inventory` shows `OpenOnWebState`: `SbCard` with copy "Inventory is managed on the web" and black pill "Open on web" (`url_launcher`, Semantics) plus the low-stock count line; More row triggers the same launch directly. Tablet portrait between 600-900: table with horizontal scroll.
Tokens: `SbTokens.rCard`, `gap8..24`, `minTouch`, `context.text.*`, `SbColors.success/danger` through components only (add `SbSignedNumber` text widget in `sb_ui` if feature needs colours; do not use raw `SbColors` in the feature).
Text scale 200%: table cells wrap/ellipsis, dialog scrolls, stat cards use `Wrap`.

## 6. Role rules

| Role | Behaviour |
|---|---|
| Owner | View, adjust, history |
| Manager | View, adjust, history (assumed Q1; US-P-31 is written for manager) |
| Specialist | No menu item, route redirect, 403 -> "No access" |
Enforced by `canManageInventoryProvider` (owner or manager) used in shell filtering, `GoRouter.redirect` and the badge provider (specialists never call inventory). API 403 mapped to the No access state.

## 7. Validation, confirmations, formatting

- Reason mandatory (1..255) for every adjustment (BR-13); `quantity_delta != 0`.
- Stock down requires confirm step (danger button). Stock up is a normal submit.
- Never allow result below zero in UI (stepper bound, plus API remains authority; show its message).
- Money: `price_cents` via `Money.format` -> `LKR 1,500`. Dates `Thu 29 Oct, 9:30 AM`.
- Snackbar: "Stock updated: 3 -> 7" (use `->` rendered as an arrow glyph from ARB).

## 8. ARB keys

`inventoryTitle`, `inventoryStatTotal`, `inventoryStatInStock`, `inventoryStatLow`, `inventoryStatOut`, `inventoryFilterAll`, `inventoryFilterLow`, `inventoryFilterOut`, `inventorySearchHint`, `inventoryColName`, `inventoryColSku`, `inventoryColCategory`, `inventoryColPrice`, `inventoryColStock`, `inventoryColLastAdjusted`, `inventoryAdjust`, `inventoryLowBadge` (`count`), `inventoryOutBadge`, `inventoryHiddenTag`, `inventoryNeverAdjusted`, `inventoryAdjustTitle`, `inventoryCurrentStock`, `inventoryDecreaseSemantics`, `inventoryIncreaseSemantics`, `inventoryQuantityLabel`, `inventoryReasonLabel`, `inventoryReasonRestock`, `inventoryReasonSoldInSalon`, `inventoryReasonDamaged`, `inventoryReasonCountCorrection`, `inventoryReasonOther`, `inventoryReasonRequired`, `inventoryNoteLabel`, `inventoryCountedLabel`, `inventorySave`, `inventoryConfirmReduce` (`count`), `inventoryReducePrompt`, `inventoryStockUpdated` (`from`, `to`), `inventoryHistoryTitle`, `inventoryHistoryEmpty`, `inventoryHistoryBy`, `inventoryEmptyTitle`, `inventoryEmptyBody`, `inventoryEmptyLow`, `inventoryErrorTitle`, `inventoryRetry`, `inventoryOfflineBanner`, `inventoryLastUpdated`, `inventoryNoAccess`, `inventoryOpenOnWeb`, `inventoryOpenOnWebBody`, `inventoryMoreRow` (`count`).

## 9. Tests

Unit:
1. Models parse `PartnerInventoryListOut` incl. alias fallback for summary; `stock_before` used over `previous_stock`.
2. Repository: filter -> `low_stock=true` / `out_of_stock=true`; adjust body `{quantity_delta, reason, note}`; 409 maps to `AdjustRejected` with API message.
3. `InventoryController.applyAdjustment` patches stock and triggers summary refetch; filters reload.
4. `AdjustStockController`: save disabled when delta 0 or reason blank or reason > 255; stepper bound `stock + delta >= 0`; stock 0 -> minus disabled; count-correction computes delta.
5. History controller paging newest first.
6. Badge provider reads `summary.low_stock`.
Widget:
7. Summary cards show API values; Low-stock card amber, Out card danger.
8. Rows: low badge "Low (2 left)", out pill, hidden tag for inactive, null `last_adjusted_at` dash.
9. Adjust flow: choose reason chip, delta +4 -> Save -> repo called -> row shows new stock, snackbar "Stock updated: 3 -> 7".
10. Negative delta shows danger confirm step; no request before second tap.
11. Rejection keeps dialog open with API message, row unchanged.
12. History panel shows green/red signed deltas with explicit sign, date format.
13. States: skeleton, empty (global and low filter), error retry, offline banner disables Adjust.
14. Role: specialist redirected; 403 -> No access; manager sees Adjust.
15. Phone width renders `OpenOnWebState` and button invokes launcher mock.
16. A11y: stepper buttons have Semantics, 44 px targets; 200% text.
Golden: `inventory_1280.png` (table with 1 low + 1 out + 1 hidden row), `inventory_phone_390.png` (open-on-web state), `adjust_dialog_1280.png`.

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p16-inventory`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. Prereq check; add `data_table_2`, `url_launcher`; `SbConfig.webAppUrl`.
2. Models + repository + tests.
3. `sb_ui`: `SbStatCard`, `SbStepper`, `SbSignedNumber`, shared state widgets (reuse if present).
4. `InventoryController`, filter, summary provider, tests.
5. Table + stat row + filter/search + states (web).
6. Adjust dialog + controller + two-step confirm for decrease.
7. History panel.
8. Phone `OpenOnWebState`, More row launch + badge provider.
9. Role guard and permission provider; offline handling.
10. Deep link `/inventory?filter=low` for the low-stock push.
11. Goldens, a11y, ARB; `flutter analyze`; `flutter test`.

## 11. Open questions / gaps / risks

- Q1 roles: Specialist and Manager rules assumed.
- Q2 phone: confirm no native phone UI; More badge uses `summary.low_stock` via `limit=1` request (no lightweight count endpoint).
- Q3: error code for below-zero undocumented (409 vs 422); reason enum undocumented (free text).
- Q5: no WebSocket for stock; refetch on resume and after P-15 order status changes.
- Q6: duplicate summary fields; plan prefers `total_products/in_stock/low_stock/out_of_stock`.
- Unclear whether `summary` reflects active filters; plan keeps an unfiltered summary source.
- Project rules say "stock down" is destructive and needs confirm + reason; the spec only requires a reason. Plan adds a confirm step for negative deltas: confirm with PM.
- Offline cached read-only list needs `drift`; deferred (in-memory only).
- `partner.stylebook.lk/inventory` deep link must exist on the web build; the URL is configured, not verified.
- Image thumbnails in table need `cached_network_image` (shared with P-13).
- No create/edit product or threshold endpoint: UI is strictly read + adjust.
