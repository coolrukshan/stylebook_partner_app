# P-17 Earnings — Implementation Plan

- Spec: [docs/_specs/P-17_earnings.md](../_specs/P-17_earnings.md)
- Design: no PNG. Phone shows nothing here (Today summary, P-02; More row from `mobile/P-22_more.png`, "Owner only").

## 1. Summary and dependencies

Owner-only web/tablet screen: period switch + custom range, stat cards (gross, platform fee, tips, net), `fl_chart` daily bar chart, expandable "How net is calculated", staff earnings table, payout history table with status pills and copyable reference, CSV export via async job. Each section loads and fails independently.

Depends on:
- P-01 role provider (owner-only), shell, router guard, P-22 More row (owner opens web, others see an informational non-navigating row).
- P-11 staff detail route (row tap opens `/staff/:id`); until it exists the row is non-navigating.
- `GET /v1/partner/settings` for salon `time_zone` (period boundaries). Check whether the settings repository exists from P-21; otherwise create a read-only `salonTimeZoneProvider` (shared).
- Shared: `Money.format`, `SbDates.format`, `ApiException`; `sb_ui` `SbStatCard` (planned in P-16/P-02; build once), `SbEmptyState`, `SbErrorPanel`, `SbSkeleton`, `SbPillBadge`, `SbBottomSheet`, `SbDataTable` helper (P-16).
- New packages needed in `apps/partner/pubspec.yaml`: `fl_chart`, `data_table_2`, `url_launcher`, `share_plus` (mobile share sheet), `flutter/services` clipboard (built in).
- Code state: nothing built yet beyond placeholder Today; no chart or table infra.

## 2. Files to create / modify

Create `apps/partner/lib/features/earnings/`:
- `data/earnings_models.dart` (freezed + json: `Earnings`, `EarningsSummary`, `DailyBreakdown`, `TopService`, `TopStaff`, `StaffEarnings`, `PayoutItem`, `PayoutPage`, `ExportJob`)
- `data/earnings_repository.dart`
- `data/earnings_period.dart` (`EarningsPeriod` enum: today, week, month, custom; `DateRange`)
- `application/earnings_range_provider.dart` (selected period + custom dates; resolves `from_date/to_date`)
- `application/earnings_controller.dart` (summary/chart AsyncNotifier)
- `application/staff_earnings_controller.dart`
- `application/payouts_controller.dart` (cursor paging, optional status filter)
- `application/export_controller.dart` (create + poll state machine)
- `application/earnings_permissions.dart`
- `presentation/earnings_screen.dart`
- `presentation/widgets/period_switcher.dart` (segmented control + `showDateRangePicker`)
- `presentation/widgets/earnings_stat_cards.dart`
- `presentation/widgets/earnings_bar_chart.dart`
- `presentation/widgets/net_breakdown_tile.dart` (ExpansionTile-like)
- `presentation/widgets/staff_earnings_table.dart`
- `presentation/widgets/payouts_table.dart`
- `presentation/widgets/export_button.dart`
- `presentation/widgets/owner_only_state.dart`

Modify:
- `apps/partner/lib/router.dart`: `/earnings` + redirect for non-owner to "Owner only".
- Shell sidebar: Earnings item for owner only. P-22 More row behaviour.
- `apps/partner/lib/l10n/app_en.arb`; `pubspec.yaml`.
- `packages/sb_ui`: `SbSegmentedControl` (black selected pill, `rChip`), `SbBarChartTheme` constants or `SbChartColors` exposing token colours for `fl_chart` (so the feature never uses raw colours), `SbCopyableText`, `SbPayoutStatusPill` (or generic `SbPill(label, tone)` with tones success/warning/neutral/danger; payout statuses are undocumented, so tone mapping lives in the feature with neutral default).

## 3. Data layer

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/v1/partner/earnings` | `period` (string, default `month`), `from_date`, `to_date` (dates) | `EarningsOut {period, from_date, to_date, summary, daily_breakdown[], top_services[], top_staff[]}` |
| GET | `/v1/partner/earnings/staff` | `from_date`, `to_date`, `staff_id` | `StaffEarningsOut {items[{staff_id, staff_name, booking_count, service_revenue_cents, tips_cents, average_rating?, no_show_count, utilisation_percent}]}` |
| GET | `/v1/partner/earnings/payouts` | `status`, `cursor`, `limit` | `EarningsPayoutListOut {items[{payout_line_id, run_id, gross_cents, commission_cents, dispute_deductions_cents, net_cents, status, reference?, period_from?, period_to?, created_at, completed_at?}], next_cursor}` |
| POST | `/v1/partner/exports` | `ExportCreateIn {type, from_date, to_date}` | 202 `ExportCreatedOut {export_id, status, estimated_seconds}` |
| GET | `/v1/partner/exports/{export_id}` | | `ExportStatusOut {export_id, status, download_url?, expires_at?, row_count?, created_at}` |
| GET | `/v1/partner/payouts/export` | `from`, `to`, `format=csv` | file (spec: payouts CSV; see gap) |
| GET | `/v1/partner/payouts` | `cursor`, `limit` | `PartnerPayoutListOut` (alt; NOT used for the table, per spec proposal) |

`EarningsSummary` fields mirrored exactly (all ints): `gross_revenue_cents, service_revenue_cents, product_revenue_cents, tips_cents, commission_cents, cancellation_fees_collected_cents, no_show_fees_collected_cents, refunds_cents, dispute_deductions_cents, net_earnings_cents`. Dates as `yyyy-MM-dd` strings parsed to `DateTime` (date only) and never timezone-shifted.
Note `ExportOut`/`ExportRequestedOut` (different routes) have status enum `pending|processing|ready|failed`, but `ExportStatusOut.status` and `ExportCreatedOut.status` are plain strings: parse leniently, treat `ready` and `completed/done` (unknown) as done via a constant set, `failed/error` as failure, everything else as in progress.
Repository: `earnings(range, period)`, `staffEarnings(range, {staffId})`, `payouts({status, cursor, limit})`, `createExport(type, range)`, `exportStatus(id)`.
Error mapping: 403 -> `OwnerOnly`; 422 -> `ApiException` message shown inline per section (bad range); 429 on export -> "Try again in a moment"; 404 on export status -> expired/gone -> offer new export.
Request params: for `today/week/month` send `period` and also resolved `from_date/to_date`? Spec AC2 says re-request with `from_date/to_date` set from the resolved range. Plan: always send `period` plus resolved dates for all periods so the visible label (from response) is consistent; resolution uses salon time zone (via `timezone` package, `tz.TZDateTime`) for week start. This is date selection, not business computation. Week start day (Mon vs Sun) is unspecified: ask backend; plan uses Monday and flags it.

## 4. Application / state

- `earningsRangeProvider` (`Notifier<EarningsRange {period, DateTime from, DateTime to}>`): `selectPeriod(p)`, `setCustom(from, to)` rejects `from > to` (picker already blocks). Default `month`.
- `earningsControllerProvider` (AsyncNotifier, watches range): GET earnings. `staffEarningsControllerProvider` watches range (GET staff). `payoutsControllerProvider` independent of range (payouts list is not date-filtered; optional `status` filter, cursor paging). Each section has its own `AsyncValue`, so failures show a retry card per section (spec §6).
- Staff table sort: local sort of loaded rows by `service_revenue_cents` or `tips_cents` (pure ordering, not computation).
- Chart selection state: `selectedBarIndex` (local widget state).
- `ExportController` (`Notifier<ExportState>`): `idle | creating | preparing(exportId, estimatedSeconds) | ready(url, expiresAt) | failed(message) | rateLimited`. `start()` POST create with `type` constant (Gap), then polls `GET exports/{id}` every 2 s (respect `estimated_seconds` as initial delay cap 5 s; stop after 60 s -> failed "taking longer, try again"). On ready: `kIsWeb` -> `launchUrl(downloadUrl, webOnlyWindowName: '_self'/blank)` for download; mobile -> `share_plus`/`launchUrl` external. If `expires_at` has passed when user taps again, create a new export. Polling timer cancelled on dispose and when range changes mid-export (export keeps the range it started with; label shows it).
- Offline: keep last `AsyncData` in memory with "Last updated {SbDates}" label (set on each successful load), export disabled. Refetch on app resume (`WidgetsBindingObserver`) via invalidate.
- Loading: shimmer cards (not animated if `disableAnimations`), empty chart frame. Empty: zeros stay in cards (values straight from API), chart replaced by "No earnings in this period" when `daily_breakdown` empty or all `gross_cents == 0`.

## 5. Presentation

Web/tablet (>= 900 px) `EarningsScreen` (`SingleChildScrollView`, max content width ~1100, `screenPadding`):
```
Row: Text('Earnings', headlineMedium) | Spacer | ExportButton (outlined pill, spinner while preparing)
PeriodSwitcher: SbSegmentedControl [Today | Week | Month | Custom] + date label from response (Thu 29 Oct - ...) + DateRangePicker trigger (opens `showDateRangePicker`, lastDate today in salon tz)
EarningsStatCards: Wrap/Row of SbStatCard [Gross, Platform fee (commission_cents), Tips, Net (emphasised: ink background variant or amber highlight)]
NetBreakdownTile ('How net is calculated', collapsed): list of API rows: Service revenue, Product revenue, Platform fee, Tips, Cancellation fees, No-show fees, Refunds, Dispute deductions, Net (each value from API, no arithmetic; refunds/dispute shown with their API sign, labelled "deducted")
EarningsBarChart (fl_chart BarChart; one bar per daily_breakdown; tooltip/selected bar shows date, booking_count, product_order_count, gross; x labels sparse for long ranges)
Row/Column: StaffEarningsTable (sortable) | PayoutsTable
```
Tables via `data_table_2`; horizontal scroll on tablet; row tap on staff opens P-11 (`context.go('/staff/${staffId}')`). Payout row: period (`period_from - period_to` formatted), gross, platform fee, deductions, net (Money), `SbPayoutStatusPill`, reference with copy icon (`SbCopyableText`, Semantics "Copy reference", snackbar "Copied"), completed date. "Load more" row by `next_cursor`.
Narrow widths (< 900): earnings is a web-first screen; phone shows `OwnerOnly`/"Open on web" info card for the owner (Q2) and nothing for others. For tablet between 600-900 stack the two tables vertically and use bottom sheet for export options (spec components list).
Chart colours come from `SbChartColors` in sb_ui built from tokens (`SbColors.ink` bars, `amber` for selected). Raw colours never in the feature. Chart gets `Semantics` summary label ("Daily revenue chart, N days, highest {date}") and bar selection also available through the tapped-tooltip text and a screen-reader friendly list below (collapsed "View daily figures" table) for accessibility.
Text scale 200%: stat cards `Wrap`; tables scroll horizontally; chart has min height.

## 6. Role rules

| Role | Behaviour |
|---|---|
| Owner | Everything |
| Manager | No access (Q1): hidden menu item, direct URL shows "Owner only" |
| Specialist | Same as manager; own tips elsewhere out of scope |
Enforced by `isOwnerProvider` -> `canViewEarningsProvider` used by shell menu, `GoRouter.redirect` (non-owner to `/earnings/owner-only` or inline `OwnerOnlyState` widget), and controllers (`build` throws `OwnerOnly` before any request for non-owners). API 403 also maps to `OwnerOnlyState`. Staff row tap navigation only if the user can open P-11.

## 7. Validation, confirmations, formatting

- Date range: `showDateRangePicker` prevents `from > to` and future dates; API 422 `message` shown in the relevant section card.
- Export: non-destructive, no confirm. Rate limit 429 message. Expired link -> new export.
- No arithmetic anywhere: net, fees, deductions displayed as returned. Deductions listed with API values; label wording from ARB.
- Money: `Money.format(cents)` -> `LKR 1,500`; negative/zero rendering handled by formatter (`LKR 0`). Dates `Thu 29 Oct, 9:30 AM` for timestamps (`completed_at`, "Last updated"), range labels date-only (`Thu 29 Oct`) in salon time zone.
- Percent fields (`utilisation_percent`) shown as `N%`; rating one decimal or "-".

## 8. ARB keys

`earningsTitle`, `earningsPeriodToday`, `earningsPeriodWeek`, `earningsPeriodMonth`, `earningsPeriodCustom`, `earningsRangeLabel` (`from`, `to`), `earningsPickRange`, `earningsGross`, `earningsPlatformFee`, `earningsTips`, `earningsNet`, `earningsHowNetCalculated`, `earningsServiceRevenue`, `earningsProductRevenue`, `earningsCancellationFees`, `earningsNoShowFees`, `earningsRefunds`, `earningsDisputeDeductions`, `earningsChartTitle`, `earningsChartTooltip` (`date`, `bookings`, `orders`, `gross`), `earningsChartSemantics` (`days`), `earningsViewDailyFigures`, `earningsStaffTitle`, `earningsColStaff`, `earningsColBookings`, `earningsColRevenue`, `earningsColTips`, `earningsColRating`, `earningsColNoShows`, `earningsColUtilisation`, `earningsPayoutsTitle`, `earningsColPeriod`, `earningsColGross`, `earningsColDeductions`, `earningsColNet`, `earningsColStatus`, `earningsColReference`, `earningsColPaidOn`, `earningsCopyReference`, `earningsCopied`, `earningsPayoutsEmpty`, `earningsLoadMore`, `earningsExportCsv`, `earningsExportPreparing`, `earningsExportReady`, `earningsExportFailed`, `earningsExportRetry`, `earningsExportRateLimited`, `earningsExportExpired`, `earningsExportTimeout`, `earningsEmpty`, `earningsChartEmpty`, `earningsErrorSection`, `earningsRetry`, `earningsLastUpdated` (`time`), `earningsOwnerOnly`, `earningsOpenOnWeb`, `earningsInvalidRange`.

## 9. Tests

Unit:
1. `EarningsRange` resolution: today, week (Monday start), month in salon time zone `Asia/Colombo`; custom rejects from > to; crossing month boundary and DST-free zone.
2. Repository: params `period`, `from_date`, `to_date` (ISO date); staff `staff_id`; payouts `status`/`cursor`; export create body `{type, from_date, to_date}`; 429 -> rate-limited error; 422 -> message.
3. Models: summary parses all ten fields; payout item optional fields null-safe.
4. `ExportController`: creating -> preparing -> polls -> ready exposes url; failed status -> failed; timeout after 60 s (fake timers); range change does not alter running export; expired `expires_at` triggers a new export.
5. Staff sort by revenue and tips both directions; stable.
6. Non-owner controllers throw `OwnerOnly` and make no request.
Widget:
7. Cards show API cents formatted `LKR 1,500` with label "Platform fee" for `commission_cents`.
8. Changing the period re-requests earnings and staff with new dates (fake repo captures); range label comes from the response.
9. Chart renders one bar group per daily entry; tap shows tooltip with counts (finder on tooltip text); empty breakdown shows empty text with zero cards.
10. "How net is calculated" expands and lists each API value, no derived rows (assert row count == fields).
11. Sections fail independently: staff error shows retry card while cards and payouts render.
12. Payouts: status pill text from API, copy reference puts text on clipboard, load more appends.
13. Export button: preparing label and disabled; ready triggers launcher mock; failure shows retry.
14. Offline: last numbers + "Last updated", export disabled.
15. Role: manager and specialist see "Owner only", menu item absent; owner sees all.
16. Semantics for chart and copy buttons; 44 px targets; 200% scale no overflow at 1280 and 390.
Golden: `earnings_1280.png` (cards, chart with 7 bars, both tables, collapsed breakdown) and `earnings_390.png` (owner "Open on web" state; phone has no screen so this is the only phone golden).

## 10. Task checklist

1. Prereqs + dependencies (`fl_chart`, `data_table_2`, `url_launcher`, `share_plus`, `timezone`); confirm salon time zone provider.
2. Models, `EarningsRange` + tests.
3. Repository + tests.
4. `sb_ui`: `SbSegmentedControl`, `SbChartColors`, `SbCopyableText`, `SbPill` tone (reuse `SbStatCard` and shared states if present).
5. Range + earnings + staff + payouts controllers + tests.
6. Screen skeleton with period switcher, stat cards, per-section states.
7. Bar chart with tooltip + accessibility list.
8. Net breakdown tile.
9. Staff table with sorting and navigation to P-11.
10. Payouts table with copy + paging.
11. Export controller + button (web download vs share).
12. Role guard, owner-only state, phone info state, More row behaviour.
13. Offline/last-updated, resume refetch.
14. Goldens, a11y, ARB; `flutter analyze`; `flutter test`.

## 11. Open questions / gaps / risks

- Q4 (product gap): instructions require "staff commission" but API only provides platform `commission_cents`; no staff payroll commission anywhere. UI shows platform fee only; flag to PM.
- Q3: `period` allowed values undocumented (assumed `today|week|month|custom`); week start day and whether custom needs `period=custom` unknown.
- Q5/Q6: two payout list endpoints and two export routes. `POST /v1/partner/exports` requires `type` with no documented values: blocked for exports until backend lists them (candidates `earnings`, `payouts`). `ExportStatusOut.status` values undocumented; `ExportOut` documents `pending|processing|ready|failed` for another route.
- `GET /v1/partner/payouts/export` returns a file but the schema is empty; unclear whether it needs auth headers (download via link will not carry the Bearer token): web download of an authenticated file response needs `Dio` bytes + `Blob` download, not `launchUrl`. Plan prefers the job-based export (URL with signature) and defers `/payouts/export` unless required.
- Earnings and staff endpoints in OpenAPI list no 401/403 responses; the owner-only restriction must be confirmed server-side.
- Payout list is not date-filterable (only `status`), so it does not follow the selected period; label it as "All payouts".
- Payout item field naming differs between routes (`period_from/to` vs `period_start/end`, `completed_at` vs `paid_at`); plan models only `/earnings/payouts`.
- Chart tap on mobile/web requires `fl_chart` touch config; screen-reader alternative is a collapsed table (extra scope).
- Salon time zone comes from `/v1/partner/settings`; if the field is missing the plan falls back to the device zone.
- Offline "last updated" is memory-only; persistent cache (drift) is out of scope.
- `data_table_2` and `fl_chart` themes must be fed from tokens via `sb_ui` wrappers to honour the "no hard-coded colours" rule.
