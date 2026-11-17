# P-08 Services and prices

Refs: instructions §3 (P-08), US-P-18, US-P-19, US-P-20, US-P-21; SRS PTN-02, CLI-33, CLI-29, CLI-25. PNG: `mobile/P-08_services_and_prices.png`. Feature folder `features/services/`.

## 1. Goal and roles
Owner maintains services: price (quick +/-), duration, options, add-ons, deposit, online bookability, packages, home-visit and patch-test settings.

| Role | Access |
|---|---|
| Owner | everything |
| Manager | view; edit only if granted (Q1) |
| Specialist | no access (menu hidden); they see their services on P-11 |

## 2. User stories
| Story | SRS | Summary | Priority |
|---|---|---|---|
| US-P-18 | PTN-02, CLI-33 | Prices, durations, options, add-ons, deposits | M |
| US-P-19 | PTN-02 | Packages (e.g. Fade + beard combo) | S |
| US-P-20 | CLI-29 | Home visits for chosen services with radius, travel fee | S |
| US-P-21 | CLI-25 | Patch test flag for colour services | S |

## 3. Layout notes
- Phone (PNG): back button in a white circle, title "Services and prices"; one white card per service: name, "30 min · Kasun, Dilan" (duration and specialists) left; right: `-` stepper, price `LKR 1,500`, `+` stepper (44 px, Semantics "Decrease price"/"Increase price"). Footer note "New prices apply to new bookings only." Tapping the card body opens the service editor (extension beyond the PNG).
- Web/tablet: grouped by category (`categories[]`), table-like rows, editor in a side panel: name, description, category, price, duration, deposit, options table, add-ons table, specialists multi-select, toggles (Bookable online, Home visit, Needs patch test). Tabs or sections: Services, Packages, Home visits.
- Stepper step size: fixed by the app (Q2, proposed LKR 100). Price changes are staged, then saved (debounced or with a Save pill, see criterion 3).
- Components: `sb_ui` card, icon stepper buttons, toggle, text field, black pill "Save", danger confirm.

## 4. Data and API map
| UI element | Endpoint | Request | Response / fields used | Errors |
|---|---|---|---|---|
| Service list | `GET /v1/partner/services` | `active_only`, `category_id` | `ServiceListOut.categories[]` -> `ServiceOut`: `id`, `name`, `description`, `base_price_cents`, `duration_minutes`, `deposit_cents`, `requires_patch_test`, `home_service_eligible`, `is_active`, `sort_order`, `options[]`, `addons[]`, `staff_count` | 422 |
| Specialist names on card | `GET /v1/partner/staff` + `GET /v1/partner/staff/{staff_id}` | - | `ServiceOut` has only `staff_count` (G1) | 422 |
| Price +/- , duration, deposit, patch test, home eligible, online toggle | `PUT /v1/partner/services/{service_id}` | `ServiceUpdateIn` (partial): `base_price_cents`, `duration_minutes`, `deposit_cents`, `requires_patch_test`, `home_service_eligible`, `is_active` | `ServiceOut` | 404, 422 |
| Options / add-ons | same PUT | `options[]` `ServiceOptionIn` (`id`, `name`, `price_cents`, `duration_minutes`, `sort_order`), `addons[]` `ServiceAddonIn` (`id`, `name`, `price_cents`, `duration_minutes`, `sort_order`) | `ServiceOut.options/addons` | 422 |
| Specialists who do it | same PUT | `staff_ids[]` | - | 422 |
| Add service | `POST /v1/partner/services` | `ServiceCreateIn`: `name`, `base_price_cents`, `duration_minutes` required; others optional | 201 `ServiceOut` | 422 |
| Delete service | `DELETE /v1/partner/services/{service_id}` | `DeleteServiceIn`: `confirm=true` | `DeleteServiceOut`: `id`, `is_active=false`, `deactivated_at` | 404, 422 |
| Packages list | `GET /v1/partner/packages` | `cursor`, `limit` | `PackageListOut.items[]` `PackageOut`: `name`, `services[]` (`PackageItemOut`), `original_price_cents`, `package_price_cents`, `discount_percent`, `total_duration_minutes`, `deposit_cents`, `is_active` | 422 |
| Create package | `POST /v1/partner/packages` | `PackageCreateIn`: `name`, `service_items[]` (`service_id`, `option_id`), `package_price_cents`, `deposit_cents`, `description`, `is_active`, `sort_order` | 201 `PackageOut` | 422 |
| Home visit settings | `GET`/`PUT /v1/partner/home-service` | `HomeServiceUpdateIn`: `enabled`, `radius_km`, `travel_fee_cents`, `min_notice_hours` | `HomeServiceOut`: same plus `eligible_services[]` | 422 |

All errors use `ErrorResponse {code, message, field}`; show `message`, highlight `field`.

## 5. Acceptance criteria
1. Given the screen opens, services are listed by category with name, `duration_minutes`, specialists and `base_price_cents` as `LKR 1,500`.
2. When `+` or `-` is tapped, the displayed price changes by one step; it cannot go below 0 (`-` disabled at 0).
3. After a pause of 800 ms (or on Save), one `PUT` with only `base_price_cents` is sent; on 200 show the returned price; on error roll back to the previous price and show `message`.
4. Given a price change is saved, the footer text "New prices apply to new bookings only." stays visible; existing bookings are untouched (API).
5. Editing duration, deposit, options and add-ons validates non-negative integers before sending; the API's 422 is authoritative.
6. Deposit cannot exceed price: show the API's message, do not clamp silently (Q3).
7. Toggle "Bookable online" sends `is_active` (G2) and reflects the response.
8. "Needs patch test" toggle (colour services) sends `requires_patch_test`; "Home visit" toggle sends `home_service_eligible` and is disabled with a hint when `home_service.enabled` is false.
9. Home visit panel saves `radius_km`, `travel_fee_cents` (shown `LKR 500`), `min_notice_hours`, `enabled`; list of `eligible_services` is read-only here.
10. Delete service asks a confirm dialog naming the service ("Hide Hair colour? Existing bookings are kept."), `danger` confirm, sends `confirm=true`; the service disappears from the active list.
11. Packages: create with at least 2 services and a `package_price_cents`; `original_price_cents`, `discount_percent` and total duration are shown from the API response, not computed.
12. Role check: only Owner (and Manager if granted) sees the screen; Specialist is redirected.
13. 44 px targets; steppers have Semantics labels; strings in ARB; money from cents.

## 6. States
- Loading: skeleton cards; stepper buttons disabled while saving that row (row shows a small progress).
- Empty: no services -> "Add your first service" with black "Add service" pill.
- Error: list error with Retry; row save error as inline message and rollback.
- Offline: list readable from cache; all edits disabled with "You are offline".
- Real-time: none required; refresh on focus. If a 409/422 says data changed, reload.

## 7. Rules and edge cases
- Prices, durations and deposits are always stored in cents/minutes from the API; the app never calculates package discounts or home travel fees.
- Price stepper: while saving a row, further taps are queued into the same pending value, not parallel requests.
- Options and add-ons are sent as the full list on PUT (`id` kept for existing items); omitting an item may delete it, so confirm before removing an option or add-on.
- Soft delete: the service becomes inactive, keeps history.
- Home visit toggle on a service requires salon home service enabled and a radius.

## 8. Gaps and questions
- G1: `ServiceOut` has `staff_count` but not staff names; the PNG shows "Kasun, Dilan". Needs `staff_ids/names` on `ServiceOut` or N detail calls.
- G2: Instructions list "bookable-online toggle"; the API has only `is_active` (also used by soft-delete). Confirm `is_active=false` means hidden online but still visible to staff.
- G3: No update or delete for packages (only `GET` and `POST /v1/partner/packages`). Edit/deactivate/delete packages cannot be built.
- G4: No create/delete for patch-test rules beyond the `requires_patch_test` flag; patch test validity period, and which service it covers, are not configurable.
- G5: Home service eligibility per service is via `home_service_eligible`; `HomeServiceUpdateIn` has no eligible-services list, fine, but no per-service travel fee.
- G6: No confirmation whether price changes apply to new bookings only (footnote in PNG); API docs silent. Confirm.
- G7: No audit/undo or price history.
- Q1: Can managers edit services?
- Q2: Stepper step (LKR 100 proposed) and whether long-press repeats.
- Q3: Does the API enforce deposit <= price and min duration?
