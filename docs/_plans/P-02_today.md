# P-02 Today — Implementation Plan (Revision 2)
- Spec: [docs/_specs/P-02_today.md](../_specs/P-02_today.md) (updated for worker-first landing; source of truth for ACs)
- PNGs: `mobile/P-02_today.png`, `P-02_today_scrolled.png`, `P-02_today_decline_reason.png`
- Contract: `docs/api/openapi.json`. Session model: [P-01 plan Revision 3](P-01_sign_in.md).

> [!IMPORTANT]
> **Prerequisites and workflow**
> 1. **Check Git Status:** run `git status`. If there are uncommitted changes, **STOP** and ask the user to commit or stash.
> 2. **Branch plan (P-01 is not merged into `dev` yet):** `feature/p02-today` MUST be created from `dev` AFTER `feature/p01-sign-in` is merged into `dev` (`git checkout dev && git pull origin dev && git checkout -b feature/p02-today`). Do NOT branch from `feature/p01-sign-in`. Until the merge, only planning/spec work happens. Sub-tasks P-02a..e each get their own short branch off `dev` (`feature/p02a-shell`, `feature/p02b-today-data`, `feature/p02c-today-phone`, `feature/p02d-today-tablet`, `feature/p02e-today-specialist`) or are commits on `feature/p02-today` with one review per sub-task; PM decides at kickoff. Never build on `dev` or `main`.
> 3. **TDD:** failing test first (Red), minimal code (Green), refactor. Verify with `flutter analyze` and `flutter test` before marking a sub-task done.

## 1. Summary and dependencies
Home screen for every role: stats, "Needs your OK" request cards (Accept / Decline with reason), "In the chair now", "Up next". Specialists land on **My bookings** (own list); owner/manager see the whole salon with an **All staff / Me** switch. Phone is built to the PNG; web/tablet adds the five-stat row and right column with what the API supports.
- Depends on P-01 (merged): session tiers, role, interceptors, `SbFormat`, l10n, router guard. Shares booking-action plumbing with P-04 (`BookingActionsRepository`). P-02 owns the adaptive shell (sidebar >= 900 px, floating nav on phone).
- **Hard dependency on Gap A (P-01): `PartnerUserOut` has no `staff_id` or `member_type`.** Without it the Me switch, My bookings and the specialist clamp cannot be built. See section 10 for the interim.

### 1a. Session model (exact names from P-01 Rev 3 code)
- `sessionControllerProvider` (`AsyncNotifierProvider<SessionController, AuthState>`); `AuthState = Unauthenticated | Limited | Full` (both `SignedIn`, carry `partnerUser: PartnerUserOut` and `mustChangePassword`). `sessionEpochProvider` bumps on sign-out/expiry. Convenience: `currentUserProvider` (`SessionUser?`), `currentRoleProvider` (`Role?`), `Role {owner, manager, specialist}`.
- `SessionUser{id, fullName, role, salonId, salonName, timeZone (default 'Asia/Colombo'), staffId (null until Gap A)}`. Role is interim: `salons.first.isOwner` -> owner, else specialist (Gap D), so manager is not reachable yet.
- **Today needs a FULL session.** Limited = calendar only. The existing router redirect already sends `Limited` to `/verify`, so TodayScreen is never built while limited. Do not add tier checks in widgets.
- **403 `OTP_REQUIRED`:** handled by the existing `OtpRequiredInterceptor` + `stepUpCoordinatorProvider` (parks the call, opens verify, retries once). The repository and controller do NOT catch or re-implement it; they only see the retried result or a final `ApiError`. If the user cancels step-up, the call fails with `ApiError(code: 'OTP_REQUIRED')`: controller shows the error banner with Retry (no loop).
- **Salon scope:** `X-Salon-Id` comes from `salons.first` via `salonIdProvider` in `dioProvider` (already wired). Repositories never set the header.
- **Time zone:** `PartnerTodayOut.time_zone` wins for rendering; fallback `SessionUser.timeZone` = `Asia/Colombo` (P-01 Gap C). Convert with `SbFormat.*(…, timeZone:)` / `SalonClock.toSalonTime`, never the device zone.
- `build()` of every Today provider watches `sessionEpochProvider` (reset on sign-out) and `currentUserProvider`.

### 1b. Reuse from P-01 (do not recreate)
- `sb_ui`: `SbTextField`, `SbPasswordField`, `SbOtpInput`, `SbTextLink` (use for "Calendar" link), `SbErrorBanner` (use for error/offline banners), `SbAuthScaffold` (auth only), `SbPrimaryButton` (has loading state: use for Accept/Start/Complete), `SbCard`, `SbStatusPill`, `SbChoiceChip`, `SbFloatingNav`/`SbNavItem`, `SbActionBar`, `SbTokens`.
- `sb_core`: `SbFormat` (`money`, `dateTime`, `time`, `dayLabel`, `countdown`), `SalonClock`, `ApiError` (map errors by `code`, not status), `Role`, `SessionUser`.
- `sb_api`: `buildDio` interceptors (auth + single-flight refresh, `OtpRequiredInterceptor`, `SalonHeaderInterceptor`, `IdempotencyInterceptor`, mapper). Idempotency: the interceptor adds a UUID to every POST under `/v1/partner/` (except `/auth/`) and KEEPS a caller-supplied `Idempotency-Key` header, so the action repository passes its own key header per attempt and reuses it on retry (not via `extra`).
- App: l10n setup (`app_en.arb`, `AppLocalizations`; `todayTitle` already exists, reuse), router `_redirect` + `kRouteAllowedRoles` table, `shell/routes.dart` (`kHomePath`, `kAuthPaths`, `safeFromTarget`, `withFrom`), test harness/fakes under `apps/partner/test/support/`, golden harness.
- Existing placeholder: `features/today/presentation/today_screen.dart` (rewrite). Not in `sb_ui` yet (create in P-02a): `SbSidebar`, `SbStatCard`, `SbSecondaryButton`, `SbDangerButton`, `SbCountPill`, `SbSectionHeader`, `SbSkeleton`, `SbEmptyState`, `SbAvatar`, `SbReasonChips`, `SbTabs`, `SbSegmentedControl` (All staff / Me), `showSbSheet()`, amber-tint `SbChoiceChip` variant, `SbStatusPill` optional `label` override.

## 2. Files to create / modify
- `apps/partner/lib/shell/partner_shell.dart` (`LayoutBuilder`: >= 900 `SbSidebar`, else `SbFloatingNav`), `shell/nav_destinations.dart` (id, label key, icon, `allowedRoles`), reuse `kRouteAllowedRoles` instead of a second role table.
- `apps/partner/lib/router.dart` (modify, see 2a). `routes.dart`: add `kCalendarPath`, `kStaffPath`, `kGalleryPath`, `kMorePath` constants.
- `features/today/data/today_repository.dart`, `data/models/today_models.dart` (`PartnerToday`, `TodayStats`, `NeedsActionItem`, `InChairItem`, `UpNextItem`, `TodayServiceItem`; plain immutable classes with `fromJson`, matching the P-01 model style, not freezed unless the repo already uses it).
- `features/booking_detail/data/booking_actions_repository.dart` (shared with P-04; `perform(bookingId, BookingAction action, {String? reason, required String idempotencyKey})`), `models/booking_action.dart` (enum -> wire strings in ONE place).
- `features/today/application/today_controller.dart` (`TodayController extends AsyncNotifier<TodayState>`), `today_scope_provider.dart` (`TodayScope { allStaff, me }`, specialist fixed to own), `request_card_controller.dart` (family: `idle|accepting|decliningOpen|declining|error`), `realtime_provider.dart` (60 s poll; `TodayEventSource` no-op), `today_cache.dart` (in-memory first, drift-ready interface), `next_booking.dart` (pure helper for the "Next" highlight).
- `features/today/presentation/today_screen.dart`, `widgets/{today_header,scope_switch,stat_row,needs_ok_section,request_card,decline_panel,in_chair_section,up_next_section,today_skeleton,tablet_right_column}.dart`
- `packages/sb_ui/lib/widgets/*` + export in `sb_ui.dart`; `apps/partner/lib/l10n/app_en.arb` (append).

### 2a. Router merge (do not replace the P-01 flow)
Keep `/loading`, `/sign-in`, `/verify`, `/change-password` as top-level `GoRoute`s OUTSIDE the shell, and keep `_redirect` as is (loading -> sign-in -> limited -> verify -> mustChange -> change-password -> app, with `from` deep-link handling). Add the shell as a sibling:
```
routes: [ /loading, /sign-in, /verify, /change-password,
  StatefulShellRoute.indexedStack(builder: PartnerShell,
    branches: [ '/' Today (kHomePath, keep this path), '/calendar', '/staff', '/gallery', '/more' ]) ]
```
- Today stays at `kHomePath` (`/`); do NOT add a `/today` route or a redirect (the guard, `initialLocation` and `_linkToKeep` already treat `/` as home). Update the spec/PNG naming only in nav labels.
- The role table check in `_redirect` applies to `matchedLocation` inside the shell too; the nav hides destinations using the same `kRouteAllowedRoles`, no second source of truth.
- Tests: existing router guard tests stay green; add shell cases (limited never reaches shell, specialist deep link `/staff` -> `/`, branch state kept when switching tabs).

## 3. Data layer
- GET `/v1/partner/today?date=YYYY-MM-DD&staff_id=<uuid>` (header `X-Salon-Id` via interceptor) -> `PartnerTodayOut{date, time_zone, needs_action[], in_chair[], up_next[], stats}`; `PartnerTodayStats{total_bookings_today, completed_today, revenue_today_cents, cancellations_today, no_shows_today, walk_ins_today}`. Both `date` and `staff_id` optional.
- **`staff_id` rule:** specialist -> always own `SessionUser.staffId`; owner/manager -> only when scope is Me; All staff omits it. If `staffId == null` (Gap A) the param is never sent (see 10).
- POST `/v1/partner/bookings/{booking_id}/{action}` -> `BookingDetailOut`. `action` is a free string with no body (Gap 1). Wire values in `BookingAction.wire` (assumed `accept`, `decline`, `check_in`, `start`, `complete`; `no_show` in P-05), corrected in one place. Decline sends `{reason}` as JSON only when `kDeclineReasonSupported` is true; until the contract is confirmed the flag is false and **decline ships disabled behind the flag** (PM decision needed, reason is mandatory by project rules).
- Leave tab and dispute card: not rendered (no list source, Gap 4/7).
- **Error mapping (by `ApiError.code`, then status):** `OTP_REQUIRED` -> interceptor owns it (section 1a). 404/409 on action -> remove card, snackbar with `message`, refetch. 422 -> inline on reason field. 429 -> snackbar with `Retry-After` backoff. **403 on accept/decline/check-in/start/complete -> snackbar "Not available" (ARB `actionNotAvailable`), keep the card, refetch; never retry (Gap 11/12, covers specialist lacking permission).** 403 on GET today (non-OTP) -> error banner with Retry. Offline -> actions disabled.
- Idempotency: one UUID per card action attempt, passed as `Idempotency-Key` header, reused on retry of the same attempt, new key for a new attempt.

## 4. Application / state
- `todayControllerProvider = AsyncNotifierProvider<TodayController, TodayState>`; `TodayState{PartnerToday data, DateTime fetchedAt, bool isStale, Object? refreshError}`.
- `build()` watches `sessionEpochProvider`, `currentUserProvider` and `todayScopeProvider`; fetches once per scope (AC 1); changing scope refetches (AC 7). `refresh()` keeps previous data via `copyWithPrevious`; failure sets `refreshError` and keeps stale data with a retry banner.
- `todayScopeProvider`: specialist -> `me` fixed (no switch); owner/manager -> `allStaff` default; selection is session-local and reset on `sessionEpochProvider`.
- Derived selectors (no money maths): `needsCount = needsAction.length`, `inChairCount`, `stillToCome = upNext.length` (approximation, Gap 2). Reschedule vs request not representable (Gap 3): all `needs_action` render as booking requests.
- "Next" highlight (AC 7a, `next_booking.dart`): across needs-action + in-chair + up-next of the specialist's own list, order by `start_time_utc`; highlight the earliest booking not completed/cancelled; recompute on refetch and on the 1-minute ticker. Pure function, unit tested with fixed `now`. Owner/manager lists in Me scope use the same helper; All staff has no highlight.
- Optimistic updates: Accept -> card `accepting`, on 200 remove from `needsAction` and refetch silently; Check in/Start/Complete update row from returned `BookingDetailOut.status`, then refetch. Error = restore + snackbar.
- Real-time: `Timer.periodic(60 s)` refetch while visible (pause in background). `TodayEventSource` interface with no-op impl until the WebSocket exists (Gap 6); a fake source drives the widget test.
- Expiry: 1-minute `nowProvider` marks `expires_at < now` as Expired; API decides after refetch.
- Offline: `TodayCache` holds last JSON + `fetchedAt`; on network error return cached with `isStale=true`, banner "Offline, last updated 9:05 AM" (`SbErrorBanner`), actions disabled.

## 5. Presentation
Phone (to PNG): `PartnerShell` -> `TodayScreen` -> `RefreshIndicator` -> `CustomScrollView`
1. `TodayHeader`: eyebrow = salon name (`SessionUser.salonName`; area unavailable, Gap 9); title = date from `data.date` in `time_zone`, or **"My bookings"** for specialist; `SbAvatar` initials from `SessionUser.fullName` (no avatar URL exists on `PartnerUserOut`, initials only).
2. `ScopeSwitch` (`SbSegmentedControl` All staff / Me) under the title, owner/manager only, only when `staffId != null`.
3. `StatRow`: 3 `SbStatCard` (Bookings, Still to come, Needs your OK amber when `needsCount > 0`).
4. `NeedsOkSection`: header + `SbCountPill` + caption; empty -> `SbEmptyState("Nothing needs your OK")`; list of `RequestCard`.
5. `RequestCard` (`SbCard`, amber tint + "Next" label when highlighted): date label + time left; client, tag (Returning / New client), "service . staff . duration", meta (relative `created_at`; payment omitted, Gap 5), "Booked for X", home badge, expiry hint. **Buttons: `SbPrimaryButton(Accept)` + `SbSecondaryButton(Decline)` shown for ANY role on a request in the visible list, including specialist on their own list (AC 7b).** No `can(...)` gating.
6. `DeclinePanel` (in-place `AnimatedSize`): `SbReasonChips` (Fully booked, Specialist unavailable, Service not offered, Other; amber tint), "Other" -> required `SbTextField`, `SbDangerButton("Confirm decline")` disabled until valid, `SbSecondaryButton("Back")`.
7. `InChairSection`: `SbAvatar`, "service . staff . until {end_time_utc in tz}", small `SbPrimaryButton` Start (`checked_in`) or Complete (`in_service`).
8. `UpNextSection`: time, client, "service . staff", `SbStatusPill`, "Calendar" `SbTextLink` -> `/calendar`; row tap opens P-04 (stub until P-04).
Loading: `TodaySkeleton`. Error (no data): `SbErrorBanner` + Retry. Empty: `SbEmptyState("No bookings today")` + New booking pill (owner/manager only).
Web/tablet (>= 900): sidebar shell; title row with `+ New booking` black pill (owner/manager, opens P-06 dialog); five stat cards (Bookings, Needs your OK, Still to come, In the chair, Completed); left column "Needs your action" (`SbTabs`, Booking requests only), in chair, arriving next; right column earnings (`SbFormat.money(revenue_today_cents)`); schedule/stock omitted (Gap 7). Specialist on tablet: same layout without New booking, scope switch, tabs beyond requests, or earnings column (earnings is salon-wide; hidden when scope is specialist, confirm with ba).
`SbStatusPill` partner wording: add optional `label` override + ARB, no feature hack.

## 6. Role rules
| Item | Owner | Manager | Specialist |
|---|---|---|---|
| Landing / title | Today, date title | Today, date title | Today, **"My bookings"** |
| Data scope | All staff (default) / Me switch | All staff (default) / Me switch | own `staff_id` always, no switch |
| `staff_id` sent | only when Me | only when Me | always own id |
| Accept (black pill) / Decline (reason, danger confirm) | yes | yes | **yes, inline, own list only** |
| Check in / Start / Complete | yes | yes | own bookings |
| Move it / No-show (P-05) | yes | yes | no |
| New booking pill (phone empty state, tablet header) | yes | yes | no |
| Leave tab | yes | yes | no |
| Earnings column | yes | yes | no |
| "Next" highlight | Me scope only | Me scope only | yes |
- Specialist Accept/Decline is NOT gated by `can(Permission.acceptBookings)`; that helper and the "manager rights" claim are dropped (no `Permission` type is added to `sb_core`). Role comes from `currentRoleProvider`; widgets branch on `Role` only for Move/No-show, New booking, leave tab, earnings, scope switch.
- The API is the enforcer: an accept/decline 403 shows "Not available" and refetches (section 3, Gap 12). Manager is unreachable until Gap D; tests use a faked `Role.manager`.
- Today items carry only `status`, not `allowed_actions`, so Start/Complete come from status mapping plus API 403.

## 7. Validation, confirmations, formatting
- Decline: confirm disabled until a chip is chosen; "Other" needs non-empty trimmed text (max 200 as local UX limit, confirm with API); danger button; Accept has no confirm.
- Money `SbFormat.money(cents)`; dates "Today 4:00 PM" when same day in salon tz else `Tue 27 Oct, 10:30 AM`; relative "25 min ago" from `created_at`.
- Double-tap guard: card state `accepting` disables both buttons.

## 8. ARB keys
Existing: `todayTitle`, `retry`, `errOffline`, `errServer`. Add: `myBookingsTitle`, `scopeAllStaff`, `scopeMe`, `nextBookingLabel`, `statBookings`, `statStillToCome`, `statNeedsOk`, `statInChair`, `statCompleted`, `needsOkTitle`, `needsOkCaption`, `needsOkEmpty`, `needsActionTitle`, `tabBookingRequests`, `tabReschedule`, `tabStaffLeave`, `accept`, `decline`, `confirmDecline`, `back`, `declineReasonLabel`, `reasonFullyBooked`, `reasonSpecialistUnavailable`, `reasonServiceNotOffered`, `reasonOther`, `reasonOtherHint`, `tagReturning`, `tagNewClient`, `tagReschedule`, `bookedFor` (`name`), `homeVisit`, `minutesAgo` (`n`), `expiresIn` (`time`), `expired`, `inChairTitle`, `untilTime` (`time`), `start`, `complete`, `checkIn`, `upNextTitle`, `calendarLink`, `emptyToday`, `newBooking`, `offlineLastUpdated` (`time`), `actionConflict`, `actionNotAvailable`, `earningsToday`, `semAvatar`, `semNavToday`, `semScopeSwitch`.

## 9. Tests (Red first)
Unit
- `PartnerToday.fromJson`: full fixture and missing optional fields.
- `TodayController`: loads once; session epoch bump resets; **specialist with `staffId` sends own `staff_id`; owner All staff omits it; Me sends own id; `staffId == null` never sends it**; refresh keeps previous on error; accept success removes card; 409 removes card + message; **403 on accept keeps card, shows "Not available", refetches, no retry**; expiry hides card after tick.
- `OTP_REQUIRED` is not caught by the controller (repository test with fake Dio: error propagates only after the interceptor; no second call from our code).
- `next_booking` helper: earliest unfinished by time, moves when one starts/completes.
- `BookingAction.wire` table; date label helper (Colombo vs device UTC); `time_zone` fallback to `Asia/Colombo`.
Widget
- Loading -> skeleton; error w/o data -> banner + Retry; error with data keeps data + banner.
- Needs OK non-empty: count pill, amber card; empty: copy, neutral card.
- Accept shows progress, one call on double tap. Decline flow (panel, disabled confirm, chip enables, Other needs text, Back, `SbDangerButton`).
- In chair: `checked_in` -> Start, `in_service` -> Complete, one call.
- **Role matrix (owner / manager / specialist), updated:**
  - Accept + Decline present for ALL three roles on a request in the list (specialist own list included).
  - New booking pill: owner and manager only (phone empty state and tablet header).
  - Scope switch: owner and manager only, default All staff; specialist none, title "My bookings".
  - Leave tab and earnings column: owner and manager only.
  - Specialist "Next" highlight on the earliest unfinished booking; moves after Complete.
- Pull to refresh; offline cached banner disables actions; fake `TodayEventSource` adds a request at top without refresh.
- Semantics on avatar/nav/switch; targets >= 44; text scale 2.0 at 390 px, no overflow.
- Router: shell with the P-01 flow (limited -> `/verify`, never shows Today).
Golden: `today_390.png`, `today_decline_390.png`, `today_1280.png`, `today_specialist_390.png` (P-02e).

## 10. Task checklist (TDD order; each sub-task = one branch/review)
0. **Pre-flight:** P-01 merged into `dev`; `git status` clean; branch from `dev` (never from `feature/p01-sign-in`).

**P-02a Shell + sb_ui components** (no network)
1. Widget tests then `SbStatCard`, `SbSecondaryButton`, `SbDangerButton`, `SbCountPill`, `SbSectionHeader`, `SbSkeleton`, `SbEmptyState`, `SbAvatar`, `SbReasonChips`, `SbTabs`, `SbSegmentedControl`, `SbSidebar`, `showSbSheet`, amber chip variant, `SbStatusPill.label`. Tokens only, 44 px targets.
2. `PartnerShell` + nav destinations + router merge (2a); tests at 899/900 px and guard regression.

**P-02b Data layer + controller**
3. Models + `TodayRepository` + fixtures + tests (`staff_id` rule, `time_zone`).
4. `BookingAction` + `BookingActionsRepository` (idempotency key per attempt, error mapping incl. 403) + tests.
5. `TodayController`, scope provider, request-card controller, cache, poll + ticker, `next_booking` + tests.

**P-02c Phone UI (owner/manager view first)**
6. ARB keys. Phone widgets to PNG; loading/empty/error states; Accept/Decline inline for all roles.
7. Decline panel + danger confirm, gated by `kDeclineReasonSupported`.
8. In-chair actions; up-next rows -> P-04 stub.

**P-02d Tablet UI + states + goldens**
9. Tablet layout (five stats, tabs, right column), New booking pill, earnings.
10. Offline, realtime-fake, text-scale, Semantics tests; goldens 390/1280; analyze + test.

**P-02e Specialist / Me switch (BLOCKED on Gap A)**
11. `SessionUser.staffId` populated from API (P-01 follow-up); `ScopeSwitch`, My bookings title, "Next" highlight, specialist clamp, `today_specialist_390` golden, role-matrix tests above.

## 11. Open questions / API gaps / risks
- **Gap A / spec Gap 10 (HARD DEPENDENCY, owner: backend via PM):** `PartnerUserOut` lacks `staff_id` and `member_type`. P-02e cannot start. **Interim:** P-02a-d ship the owner view (All staff only, no `staff_id` ever sent). Every specialist/Me feature is behind a `staffId != null` check (`SessionUser.staffId`); when null, owners see no switch, and a non-owner (interim specialist, Gap D) sees the unfiltered salon-wide endpoint result, which is wrong for them. Mitigation to confirm with PM: while `staffId == null` and role is specialist, show a blocking "My bookings is not available yet" `SbEmptyState` instead of salon-wide data (never leak other staff bookings in the UI).
- **Gap 11 (spec 11):** `staff_id` on `/v1/partner/today` is documented only as "Filter dashboard to specific staff member". Confirm it filters `needs_action` as well as `in_chair`/`up_next` and `stats`, and how multi-staff (split) bookings match (`services[].staff_id`). Until confirmed, do not trust `stats` under a filter without a test against the live API; the app does not re-filter client-side except as a safety net decided by ba.
- **Gap 12 (spec 12):** can a Specialist call accept/decline on the action endpoint? Buttons show; a 403 shows "Not available" and refetches. If backend says no, switch to hiding Accept/Decline for specialists with one flag, not a rewrite.
- Gap 1 (blocker for decline reason): action endpoint undocumented (values, body). Decide with PM whether decline ships disabled.
- Gap 2: no "still to come" or "in chair" counts; derived; `up_next` may be limited to 2 hours (undercount).
- Gap 3: reschedule requests and "Move it" not in the API; card and tab not built.
- Gap 4/7: no pending-leave list, disputes, schedule or stock sources; right column limited to earnings.
- Gap 5: no payment mode on cards. Gap 6: no WebSocket contract; DoD "new request without refresh" met by 60 s polling only.
- Gap 8/9: confirm `services[].staff_name` is the assignee; no salon area/profile endpoint.
- Gap C (P-01): salon time zone for non-owners; default `Asia/Colombo`, `PartnerToday.time_zone` preferred. Gap D: no manager role yet. Gap E: limited-session endpoints undocumented (Today treated as full-only).
- Stale `needs_action` after `expires_at`: API may still return it; accept returns 409, handled.
- Risk: P-01 not merged; P-02 start is gated on it. Router merge (2a) is the main integration risk, hence the guard regression tests in P-02a.
