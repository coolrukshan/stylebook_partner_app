# P-17 Earnings

Refs: US-P-32, US-P-33, US-P-34; SRS PTN-12, PTN-14, BR-11. No PNG (phone: summary on Today only, `mobile/P-22_more.png` says "Owner only"). API: `/v1/partner/earnings*`, `/v1/partner/payouts*`, `/v1/partner/exports*`.

## 1. Goal and roles
Owner sees what the salon earned for a period, what StyleBook kept, tips, net, payout history, per-staff results, and exports a CSV.

| Role | Access |
|---|---|
| Owner | Everything |
| Manager | No access (user stories are owner-only, Q1) |
| Specialist | No access. May see own tips elsewhere (out of scope, Q1) |

## 2. User stories
US-P-32 gross, platform fee, staff commission, tips, net for any period (PTN-12, BR-11). US-P-33 staff earnings and tips per person (PTN-12). US-P-34 payout history and CSV export (PTN-14).

## 3. Layout
- Web/tablet: title "Earnings"; period switch segmented control (Today, Week, Month, Custom) + date range picker; stat cards row (Gross, Platform fee, Tips, Net; net is emphasised); bar chart (`fl_chart`) from `daily_breakdown`; two tables: "Staff earnings" and "Payouts"; "Export CSV" outlined pill top right.
- Phone: no screen. Today shows `revenue_today_cents` summary (P-02). More row "Earnings and payouts, Owner only, see the Today tab" is informational and non-navigating for non-owners; for the owner it opens the web app (Q2).
- Components: `sb_ui` stat card, status pill (payout status), table, bottom sheet for export on small widths.

## 4. Data and API map
| UI element | Endpoint | Request | Response fields | Errors |
|---|---|---|---|---|
| Period + cards + chart | GET `/v1/partner/earnings` | `period` (string, default `month`; allowed values undocumented, Q3), `from_date`, `to_date` | `EarningsOut`: `from_date`, `to_date`, `summary` (`EarningsSummary`: `gross_revenue_cents`, `service_revenue_cents`, `product_revenue_cents`, `tips_cents`, `commission_cents`, `cancellation_fees_collected_cents`, `no_show_fees_collected_cents`, `refunds_cents`, `dispute_deductions_cents`, `net_earnings_cents`), `daily_breakdown[]` (`date`, `gross_cents`, `booking_count`, `product_order_count`), `top_services[]`, `top_staff[]` | 422 (bad range), 403 |
| Staff table | GET `/v1/partner/earnings/staff` | `from_date`, `to_date`, `staff_id` | `StaffEarningsOut.items[]`: `staff_name`, `booking_count`, `service_revenue_cents`, `tips_cents`, `average_rating`, `no_show_count`, `utilisation_percent` | 422 |
| Payout history | GET `/v1/partner/earnings/payouts` | `status`, `cursor`, `limit` | `EarningsPayoutItem`: `period_from`, `period_to`, `gross_cents`, `commission_cents`, `dispute_deductions_cents`, `net_cents`, `status`, `reference`, `completed_at` | |
| Payout history (alt) | GET `/v1/partner/payouts` | `cursor`, `limit` | `PartnerPayoutItemOut` with service/product commission split, `tip_cents`, `refund_deductions_cents`, `paid_at` | |
| Export CSV | POST `/v1/partner/exports` then poll GET `/v1/partner/exports/{export_id}` | `ExportCreateIn {type, from_date, to_date}` | `ExportCreatedOut {export_id, status, estimated_seconds}`; `ExportStatusOut {status, download_url, expires_at, row_count}` | 202, 404, 429 |
| Export payouts CSV (direct) | GET `/v1/partner/payouts/export` | `from`, `to`, `format=csv` | file | 422 |

Platform fee label = `commission_cents` (the API field is the StyleBook commission). All values are shown as returned.

## 5. Acceptance criteria
1. Given I open Earnings, then the default period is `month` and cards show `gross_revenue_cents`, `commission_cents` (label "Platform fee"), `tips_cents`, `net_earnings_cents` in `LKR 1,500` format.
2. When I change period or dates, then GET earnings (and staff) are re-requested with `from_date`/`to_date` set from the resolved range; the visible range label comes from the response `from_date`/`to_date`.
3. The chart shows one bar per `daily_breakdown` entry with `gross_cents`; tapping a bar shows date, `booking_count`, `product_order_count`.
4. The staff table lists each person with revenue, tips and rating, sortable by revenue and tips; tapping a row opens staff detail (P-11).
5. Payouts table shows status pills (e.g. pending, paid) from `status`; `reference` copyable; load more via `next_cursor`.
6. Export: "Export CSV" starts a job for the current range, shows "Preparing" until status is done, then opens `download_url` (web download, share sheet on mobile). On failure shows a retry.
7. Deductions (`refunds_cents`, `dispute_deductions_cents`) appear in an expandable "How net is calculated" list with each API value; no arithmetic is done in the app.
8. Non-owner roles do not see the menu item; direct navigation shows "Owner only".
9. A `from_date` after `to_date` is blocked in the picker; a 422 shows the API message.

## 6. States
- Loading: shimmer cards, empty chart frame.
- Empty: "No earnings in this period" with zeros kept in cards; chart shows empty state text.
- Error: retry card per section (cards, staff, payouts fail independently).
- Offline: show last loaded numbers with "Last updated" time; export disabled.
- Real-time: none required. Refetch on resume. (No WebSocket event for earnings in instructions.)

## 7. Rules and edge cases
- Money only from API cents; app never recomputes net or fees.
- Period boundaries use salon `time_zone` (from `/v1/partner/settings`).
- Export links expire (`expires_at`); if expired, create a new export.
- Exports are rate limited (429): show "Try again in a moment".
- Large staff counts: table scrolls horizontally on tablet.

## 8. Gaps and questions
- Q1: Roles. Instructions: owner stories only. Confirm manager cannot see earnings.
- Q2: Phone has no Earnings screen. Confirm that More row for owner opens web.
- Q3: `period` accepts an unspecified string; need allowed values (assumed `today`, `week`, `month`, `custom`).
- Q4: Instructions require a separate "staff commission" figure. `EarningsSummary` only has `commission_cents` (platform), and `StaffEarningsItem` has no commission. Staff payroll commission is not supported by the API. Flag to PM; the UI shows only platform fee.
- Q5: Two payout list endpoints overlap (`/v1/partner/payouts` and `/v1/partner/earnings/payouts`). Proposed: use `/earnings/payouts` for the table, keep `/payouts` for detail. Backend to confirm.
- Q6: Two export routes (`/exports` with undocumented `type`, and `/payouts/export`). Need the allowed `type` values; proposal: `/exports` for earnings, `/payouts/export` for payouts.
- Q7: `PartnerPayoutItemOut` field `tip_cents` and status enum undocumented.
