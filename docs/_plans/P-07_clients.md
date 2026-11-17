# P-07 Clients — Implementation Plan

- Spec: [docs/_specs/P-07_clients.md](../_specs/P-07_clients.md)
- Design: no PNG. Follow the style guide and the P-09 list card look.

## 1. Summary and dependencies

Searchable, sortable, cursor-paged client list with a client record (stats, preferences, private notes, history, upcoming bookings) and shortcuts (New booking, Message, Call). Two panes at >= 900 px, list then full-screen record on phone.

Dependencies (prerequisites, not built here):
- Shell, router and role guard (`lib/shell`, `lib/router.dart`), session provider exposing `role` and `salonId`.
- `sb_api`: Dio client sending `Authorization` and `X-Salon-Id`, `ApiError` mapping (see section 3). Today only `buildDio()` exists; the interceptors come with P-01.
- `sb_core` formatters `SbFormat.money(cents)` and `SbFormat.date(...)` (add if P-02 has not).
- P-06 (New booking) entry point accepting `{userId, clientName, phone}`, P-04 booking sheet opener (`bookingId`), P-05 message flow (thread create + send). If not landed, the buttons are wired to a callback and left disabled behind a TODO route.
- New shared `sb_ui` widgets listed in section 5.
- Build order puts P-07 last of this group (instructions §6 step 4).

## 2. Files to create / modify

Create under `apps/partner/lib/features/clients/`:
- `data/client_models.dart` (freezed + json: `ClientListItem`, `ClientList`, `ClientDetail`, `ClientStaffStat`, `ClientServiceStat`, `ClientVisit`, `ClientUpcoming`, `ClientNotes`)
- `data/clients_repository.dart`
- `application/clients_providers.dart` (`clientsRepositoryProvider`, `clientListControllerProvider`, `clientDetailProvider`, `clientNotesControllerProvider`, `selectedClientIdProvider`)
- `presentation/clients_screen.dart` (adaptive scaffold: two pane vs list)
- `presentation/client_list_pane.dart`, `client_list_row.dart`, `client_sort_menu.dart`
- `presentation/client_detail_screen.dart` (phone route and right pane body: `ClientRecordView`)
- `presentation/widgets/client_stats_row.dart`, `client_preferences_card.dart`, `client_notes_card.dart`, `client_visit_history.dart`, `client_upcoming_list.dart`, `client_actions_bar.dart`
- tests under `apps/partner/test/features/clients/`

Modify:
- `apps/partner/lib/router.dart`: add `GoRoute('/clients')` and `GoRoute('/clients/:userId')` (phone full screen; on wide, `/clients/:userId` renders the two-pane screen with the id preselected). Guard: owner and manager (and specialist, see Q1).
- Shell nav config: "Clients" sidebar item (web/tablet) and a row in More (phone, P-22).
- `apps/partner/lib/l10n/app_en.arb` (keys in section 8).
- `apps/partner/pubspec.yaml`: add `url_launcher` (Call `tel:`), `flutter_localizations`, `intl` if the l10n setup has not landed; `freezed`, `json_serializable`, `build_runner` dev deps if not yet added by an earlier plan.
- `packages/sb_core/lib/sb_core.dart`: export `SbFormat` (if missing), `ApiError`.
- `packages/sb_ui`: see section 5.

## 3. Data layer

Endpoints (all in `docs/api/openapi.json`, header `X-Salon-Id` added by the Dio interceptor):
| Method | Path | Notes |
|---|---|---|
| GET | `/v1/partner/clients` | query `q` (max 100), `sort` (default `last_visit`), `order` (default `desc`), `cursor`, `limit` (1..50, default 20) |
| GET | `/v1/partner/clients/{user_id}` | `ClientDetailOut` |
| PUT | `/v1/partner/clients/{user_id}/notes` | body `{notes}` -> `{notes, updated_at}` |
| POST | `/v1/threads` | body `ThreadCreateRequest {salon_id, user_id}`; reuse P-05 message code |
| POST | `/v1/threads/{thread_id}/messages` | via the P-05 message sheet, not re-implemented here |

Repository (`ClientsRepository`, takes `Dio`):
- `Future<ClientList> list({String? q, String sort, String order, String? cursor, int limit = 20})`
- `Future<ClientDetail> detail(String userId)`
- `Future<ClientNotes> saveNotes(String userId, String notes)`
- `Future<String> ensureThread(String userId)` returns `thread_id` (delegates to a shared `MessagingRepository` if P-05 creates one; otherwise add it to `features/booking_detail/data` and import).

Models: field names per spec section 4. Dates (`last_visit_date`, `first_visit_date`, visit `date`) parse as `DateTime`; money stays `int` cents. Verify the exact `ClientUpcomingOut` and `ClientVisitOut` fields in the schema before writing the models (spec lists them only partially).

Error mapping: catch `DioException`, decode body `ErrorResponse {code, message, field}` into `ApiError`; 404 on detail -> "Client not found" state; 422 on notes -> inline `message`; 409/429 -> message with Retry. Never log phone or notes (acceptance 11): Dio log interceptor must be disabled or redacted for `/clients`.

## 4. Application / state

Riverpod 3 (`flutter_riverpod ^3.5.0` in pubspec). Use hand-written `AsyncNotifier`s unless `riverpod_generator` is set up by an earlier plan.

- `ClientListQuery` (value: `q`, `sort`, `order`) held by `clientListQueryProvider` (`Notifier`). Search text is debounced 300 ms in the widget (a `Timer` in the search field state) before it writes `q`.
- `ClientListController extends AsyncNotifier<ClientListState>`; `ClientListState {items, totalCount, nextCursor, isLoadingMore, loadMoreError}`. `build()` watches the query and fetches page 1 (so a query change reloads and resets). `loadMore()` appends when `nextCursor != null` and not already loading; guards against duplicate calls. `refresh()` for pull-to-refresh.
- `clientDetailProvider = FutureProvider.family<ClientDetail, String>`; invalidated by pull-to-refresh and after notes save (only the notes field needs updating, so patch locally using the response).
- `ClientNotesController` (family by userId): holds draft text, `dirty` flag, `saving`. `save()` sends the full text (empty string clears), on success updates the baseline and emits a toast event; on `ApiError` 422 exposes `message`. Not optimistic.
- States: loading (skeleton rows/cards), empty (no clients vs no search match, distinguished by `q.isNotEmpty`), error with Retry (shows `ApiError.message`). Offline: out of scope for the first cut (drift cache blocked by Q4); notes Save disabled when connectivity provider reports offline, show last loaded data only if already in memory.
- WebSocket "booking completed" refresh is optional: wire to `ref.invalidate(clientListControllerProvider)` once the real-time provider exists (P-02); not a blocker.

## 5. Presentation

Tree (wide, >= 900 px): `AdaptivePage(title "Clients", count "124 clients")` -> `Row[ SizedBox(width ~ 380) ClientListPane, Expanded ClientRecordView ]`. Right pane shows a "Select a client" placeholder until a row is chosen (selection in route or `selectedClientIdProvider`).

Phone: `ClientListPane` full screen; tap -> `context.push('/clients/$id')` -> `ClientDetailScreen` with back glass button.

`ClientListPane`: search `SbTextField` (clear button, Semantics), sort control (menu of `last visit`, `spend`, `visits`, `name`), `ListView.builder` with a scroll listener at 80% calling `loadMore()`, bottom spinner row, pull-to-refresh.
`ClientListRow` (min height 44, uses `SbCard`/list tile): avatar (initials when `avatar_url` null), name, "N visits · LKR 12,500", last visit date `Thu 29 Oct`.
`ClientRecordView`: header (avatar, name, phone, "Usually every 4 weeks"), `ClientStatsRow` (visits, total spend, first visit, last visit as stat cards), preferences (usual specialists and services as chips with counts, hair type read-only), notes card ("Private to your salon", multiline field, black Save pill), visit history (date, services, `LKR`, status pill, rating, tip), upcoming bookings (tap opens P-04 sheet), `ClientActionsBar` (black "New booking", white "Message", white "Call").

Interval label: derived only for display from `average_interval_days` (weeks if divisible by 7, else days; hidden when null). This is formatting, not business computation; put in `SbFormat.interval(days)` with ARB plural strings.

sb_ui tokens/components used: `SbCard`, `SbPrimaryButton`, `SbStatusPill`, `SbChoiceChip`, `SbGlassIconButton` (back), `SbColors/context.sb/context.text`. Shared additions needed (coordinate with other plans, reuse if already added): `SbTextField` (search + multiline), `SbSecondaryButton` (white pill), `SbStatCard`, `SbAvatar` (initials fallback), `SbSkeleton`, `SbEmptyState`, `SbErrorPanel` (message + Retry), `SbToast`/snackbar helper, `SbConfirmDialog` (for unsaved-changes prompt).

## 6. Role rules

- Owner and manager: full list and record, edit notes.
- Specialist: spec Q1 open. Plan: gate the route and menu with `roleCan(Capability.viewClients)` that allows all three roles now (story US-P-24 is a specialist story), with `ClientsScreen` taking no filter because the API has no staff filter. Flip to deny by changing one capability map entry if PM decides otherwise.
- Enforcement: menu item hidden by capability; go_router `redirect` for `/clients*` sends disallowed roles to `/`; the API still checks (403 shown as error panel).

## 7. Validation, confirmations, formatting

- No destructive actions. Unsaved notes: leaving (back, selecting another client, route pop) with `dirty` prompts `SbConfirmDialog` ("Discard changes?" with Keep editing / Discard; discard is `danger`). Use `PopScope` on phone and an explicit check on pane selection.
- Notes length: no client limit; surface the API 422 `message`.
- Money `LKR 12,500` from cents, dates `Thu 29 Oct`; spend and visits rendered as returned.
- Call uses `tel:` via `url_launcher`; hide Call when phone is null.
- 44 px targets on rows, sort menu, icon buttons; Semantics labels for search clear, sort, back.

## 8. ARB keys

`clientsTitle`, `clientsCount` (plural/placeholder `count`), `clientsSearchHint`, `clientsSortLabel`, `clientsSortLastVisit`, `clientsSortSpend`, `clientsSortVisits`, `clientsSortName`, `clientsEmpty` ("Clients appear here after their first completed visit"), `clientsNoMatch`, `clientsSelectPrompt`, `clientsVisitsSpend`, `clientsLastVisit`, `clientsFirstVisit`, `clientsTotalSpend`, `clientsVisitsLabel`, `clientUsuallyEveryWeeks` (plural), `clientUsuallyEveryDays` (plural), `clientPreferences`, `clientPreferredStaff`, `clientPreferredServices`, `clientHairType`, `clientNotesTitle`, `clientNotesPrivate` ("Private to your salon"), `clientNotesHint`, `clientNotesSave`, `clientNotesSaved`, `clientVisitHistory`, `clientNoVisits`, `clientUpcoming`, `clientNoUpcoming`, `clientActionNewBooking`, `clientActionMessage`, `clientActionCall`, `clientDiscardTitle`, `clientDiscardBody`, `clientKeepEditing`, `clientDiscard`, `clientLoadError`, `clientNotFound`, `commonRetry`, `commonOffline`, `semanticsClearSearch`, `semanticsSortClients`, `semanticsBack`.

## 9. Tests

Unit (`test/features/clients/`):
- `clients_repository_test`: list sends `q/sort/order/cursor/limit` params; parses `next_cursor` and `total_count`; detail parses visits and upcoming; saveNotes PUT body is the full text; 422 maps to `ApiError(message, field)`.
- `client_list_controller_test`: loadMore appends and stops when `next_cursor` null; no duplicate concurrent loadMore; query change resets list; error on page 2 keeps page 1 items.
- `client_notes_controller_test`: dirty tracking; empty string saved; save success resets dirty; 422 exposes message.
- `format_interval_test`: 28 days -> "every 4 weeks", 10 days -> "every 10 days", null -> hidden.

Widget:
- list shows loading skeleton, rows, empty ("Clients appear here..."), no-match, error with Retry that refetches.
- typing in search debounces 300 ms (use `fakeAsync`) and sends one request.
- sort menu changes `sort`/`order`.
- record: sections without data hidden; interval line hidden for null; notes Save shows toast; unsaved dialog on back; Call hidden without phone.
- roles: owner and manager see item/route; disallowed role (if Q1 resolves to deny) redirected; specialist per decision.
- text scale 2.0 does not overflow list row or stat cards (pump with `MediaQuery.textScaler`).
Golden: `clients_wide_1280.png` (two pane with selected client), `clients_phone_390.png` (list) and `client_detail_phone_390.png`. No PNG design exists, so goldens are regression only.

## 10. Task checklist

1. Confirm shared pieces from earlier plans exist (`SbFormat`, `ApiError`, `SbTextField`, `SbSecondaryButton`, `SbAvatar`, `SbEmptyState`, `SbErrorPanel`, `SbSkeleton`, `SbConfirmDialog`); add missing ones to `sb_ui` with widget tests.
2. Add deps (`url_launcher`, freezed stack, l10n) and run `flutter pub get` at the root.
3. Write models + `build_runner`; repository + unit tests against a mock Dio adapter. Verify: `flutter test test/features/clients/data`.
4. Providers and controllers with unit tests.
5. `ClientListRow` + `ClientListPane` with states; widget tests.
6. `ClientRecordView` sections, stats, preferences, history, upcoming; widget tests.
7. Notes editor with dirty guard; tests.
8. Actions: Call (`tel:`), New booking (P-06 route params), Message (thread + P-05 sheet), upcoming tap (P-04).
9. Adaptive screen and routes, role guard, nav entries.
10. ARB strings, no hard-coded text; run gen-l10n.
11. Goldens at 390 and 1280; text scale 2.0 test.
12. `flutter analyze` and `flutter test` clean.

## 11. Open questions / gaps / risks

- Q1 specialist scope; no staff filter on the API (spec Q1). Risk: leaking all clients' PII to specialists.
- G1: walk-in clients without `user_id` and clients with only upcoming bookings are not listed; New booking from P-06 therefore needs its own client search.
- G2: `sort` and `order` accepted values are undocumented (plain strings). Plan assumes `last_visit`, `total_spend`/`spend`, `visit_count`/`visits`, `name`; confirm with backend before building the menu. Fallback: only offer the default.
- G3: hair type and preferences are read-only; no edit endpoint.
- G4: messaging uses the generic threads API; `ThreadCreateRequest` has no booking context. Depends on P-05 decisions.
- Q4: offline cache of PII (drift) deferred; first release is online only.
- Real-time event for completed bookings is not defined in OpenAPI.
- `ClientVisitOut.status` values and `ClientUpcomingOut` fields need a schema check; status mapping to `SbStatus` may need a fallback label.
- Phone layout: the instructions say "More (web first)"; plan provides both (spec Q5).
