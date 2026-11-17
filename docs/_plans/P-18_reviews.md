# P-18 Reviews — Implementation Plan

- Spec: [docs/_specs/P-18_reviews.md](../_specs/P-18_reviews.md)
- Design: `mobile/P-18_reviews.png` (phone). Web/tablet has no PNG; follow the spec layout.

## 1. Summary and dependencies

Reviews list with rating summary, filters, reply composer (with AI draft that is never auto-posted), edit reply, and report-as-fake. Phone: single list with a back pill. Tablet/web (>= 900 px): summary card on top, filter chips, list with a right-hand composer panel.

Prerequisites (none exist in the repo yet; the current `lib/` has only `app.dart`, `router.dart`, `features/today/presentation/today_screen.dart`, and `shell/` is empty):
- Adaptive shell + role guard (`lib/shell`) and the More page (P-22) for the entry point and `unreplied_count` badge.
- Auth/session provider exposing `role` and `salonId`, and a Dio interceptor that adds `Authorization` and `X-Salon-Id` (`packages/sb_api/lib/src/api_client.dart` only builds a bare Dio today).
- ARB/l10n setup (`flutter_localizations`, `intl`, `l10n.yaml`) and date/money formatters in `sb_core` (see section 7).
- Soft dependency on P-19: the draft call uses AI credits (Q3). The review screen does not need the P-19 UI.

## 2. Files to create / modify

Feature (`apps/partner/lib/features/reviews/`):
- `data/review_models.dart` (freezed + json_serializable): `PartnerReview`, `ReviewSummary`, `ReviewPage`, `ReplyResult`, `DraftResult`, `ReportResult`, enum `ReviewTone`.
- `data/reviews_repository.dart`: `ReviewsRepository(Dio)`.
- `application/reviews_providers.dart`: `reviewsFilterProvider`, `reviewsListProvider` (`AsyncNotifier`), `reviewSummaryProvider` (derived from the list's first page), `reviewComposerProvider` (family by review id), `unrepliedCountProvider` (consumed by P-22).
- `presentation/reviews_screen.dart` (adaptive scaffold, back pill on phone).
- `presentation/widgets/review_card.dart`, `rating_summary_card.dart`, `reviews_filter_bar.dart`, `reply_composer.dart` (inline on phone via bottom sheet, side panel on tablet), `report_review_dialog.dart`, `review_card_skeleton.dart`.
- Tests: `apps/partner/test/features/reviews/...` (section 9).

Shell / router:
- `lib/router.dart`: add `GoRoute(path: '/reviews', ...)` inside the shell route, guarded by role (owner, manager).
- Sidebar item "Reviews" (web/tablet) in the shell nav config; More row on phone (P-22).

sb_ui additions (`packages/sb_ui/lib/`, export from `sb_ui.dart`):
- `widgets/sb_star_rating.dart`: read-only 5 stars (filled `SbColors.star`, outline for the rest), with Semantics "4 out of 5 stars".
- `widgets/sb_rating_bar.dart`: horizontal bar for distribution rows (value / max).
- `widgets/sb_skeleton.dart`: shared skeleton box (reused by P-19, P-20, P-21 plans; whichever lands first creates it).
- `widgets/sb_error_card.dart`, `sb_empty_state.dart` (retry card / empty message), if no earlier plan has created them.
- `widgets/sb_back_pill.dart`: white circular back button (44 px, Semantics "Back"), used by all phone sub-screens.
- `widgets/sb_secondary_button.dart`: outlined pill/button style ("Reply with AI draft") wrapping the theme's `OutlinedButton`; add a `loading` state. Do not hard-code styles in the feature.
- `widgets/sb_danger_button.dart` (red pill for destructive confirms using `SbColors.danger`). Check first whether another plan already adds it.
- `widgets/sb_tag.dart`: small tag for "Reported" (reuse `SbStatusPill`-style tokens).

l10n: `apps/partner/lib/l10n/app_en.arb` (keys in section 8).

## 3. Data layer

All calls send `X-Salon-Id` (interceptor). Paths from `docs/api/openapi.json`:

| Method | Path | Query/body | Response |
|---|---|---|---|
| GET | `/v1/partner/reviews` | `rating` (int), `replied` (bool), `sort` (string), `cursor`, `limit` | `PartnerReviewListOut {items, summary, next_cursor}` |
| POST | `/v1/partner/reviews/{review_id}/reply` | `ReplyIn {reply}` (1-2000 chars) | `ReplyOut {id, reply, replied_at}` |
| PUT | `/v1/partner/reviews/{review_id}/reply` | `ReplyIn` | `ReplyOut` |
| POST | `/v1/partner/reviews/{review_id}/draft` | `DraftIn {tone (default "professional"), context}` | `DraftOut {draft, model_used, generated_at}` |
| POST | `/v1/partner/reviews/{review_id}/report` | `ReportIn {reason}` (1-500 chars) | `ReportOut {id, reported, report_reason}` |

Models mirror `PartnerReviewOut`: `id`, `booking_id`, `user_name?`, `user_avatar_url?`, `staff_id?`, `staff_name?`, `rating`, `comment?`, `reply?`, `replied_at?`, `tip_cents` (default 0), `reported` (default false), `report_reason?`, `services` (list of string), `created_at`. `ReviewSummary`: `average_rating`, `total_count`, `rating_distribution` as `Map<String,int>` (keys "1".."5", verify against live API).

Repository methods: `list({int? rating, bool? replied, String? sort, String? cursor, int limit = 20})`, `postReply(id, text)`, `editReply(id, text)`, `draft(id, tone, context)`, `report(id, reason)`.

Error mapping (shared `ApiException` in `sb_api`, sealed: `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`, `Validation(field, message)`, `RateLimited`, `Network`, `Unknown`):
- 409 on reply POST (already replied): refetch the item, show the existing reply, snackbar l10n `reviewsAlreadyReplied`.
- 404: remove the card locally, snackbar `reviewsNotFound`.
- 422: show server `message` under the composer field; keep text.
- 429 on draft: snackbar `reviewsDraftRateLimited`.
- Unknown error on draft (credits exhausted is undocumented, Q3): show generic message plus the server message, composer opens empty so the user can write manually.
- 403: route redirects to a "no access" state.

## 4. Application / state

- `ReviewsFilter` (immutable): `rating?`, `repliedOnly?` (maps "Needs reply" to `replied=false`), `sort` (default null = server default; do not send unknown values, Q2).
- `ReviewsListNotifier extends AsyncNotifier<ReviewsState>`; `ReviewsState {summary, items, nextCursor, isLoadingMore}`. `build()` reads the filter and loads page 1. `loadMore()` appends via cursor. `refresh()` for pull to refresh and on app resume (`WidgetsBindingObserver` in the screen).
- Summary is taken from the response of the current query. Note: `summary` may be scoped by filter or not (unknown); to keep the bars stable the summary is only taken from the unfiltered query (cache it in `reviewSummaryProvider` that issues `limit=1` with no filters when a filter is active). Flag as risk.
- Post reply: not optimistic. Set card to `posting`, on 200 replace `reply` and `replied_at` from `ReplyOut`, then refetch page 1 (spec AC5: `unreplied_count` decreases after refetch). Also invalidate `unrepliedCountProvider`.
- Edit reply: same via PUT.
- Report: on 200 set `reported=true`, `report_reason` from `ReportOut`.
- Composer state (`reviewComposerProvider(reviewId)`, `Notifier`): `text`, `tone`, `context`, `isDrafting`, `isPosting`, `error`. Kept in memory so a failed post keeps typed text, and survives list rebuilds.
- States: loading = skeleton summary + 3 skeleton cards; empty = `reviewsEmpty` (no filters) or `reviewsEmptyFiltered`; error = retry card; error on loadMore = inline retry row.
- Offline: no drift cache exists yet. v1: show last loaded `AsyncValue` data (`state.valueOrNull`) with an offline banner and disable reply/report; true disk cache deferred (risk).

## 5. Presentation

Widget tree:
- `ReviewsScreen` -> `LayoutBuilder` (>= 900 px tablet, else phone).
- Phone: `SafeArea > Column[ Row(SbBackPill, Text(title headlineMedium)), Expanded(RefreshIndicator > ListView[ filter chips (horizontal scroll of SbChoiceChip), ReviewCard... ]) ]`. Summary card is shown on phone too, compact (average and bars collapse under a header; PNG shows only cards so keep it collapsed by default or omit; decision: show a one-line "4.6 average, 28 reviews" row, bars only on tablet).
- Tablet: `Row[ Expanded(flex 3: RatingSummaryCard, filter bar, list), SizedBox(width 360-420, composer panel for the selected review) ]`.
- `ReviewCard` (`SbCard`): name (`titleMedium`), `SbStarRating`, comment or "No comment" (`bodyMedium`, muted when empty), meta line `staff_name` and services (`bodySmall`), tip line only if `tip_cents > 0` (format from cents, `LKR 500`), "Reported" `SbTag` with reason. If `reply` exists: sand block (`SbColors.soft` fill, radius `SbTokens.rInput`), "Your reply:" prefix, date `replied_at`, overflow menu (Edit reply, Report as fake). Else: secondary button "Reply with AI draft" (spinner while drafting).
- `ReplyComposer`: multiline `TextField` (counter, max 2000), tone chips (`SbChoiceChip` x3 Warm, Professional, Apologetic), optional context field, "Draft with AI" secondary pill, black `SbPrimaryButton` "Post reply", hint "Your reply is visible to everyone". On phone it is a modal bottom sheet (theme has drag handle and radius); on tablet the side panel.
- `ReportReviewDialog`: reason chips (Fake, Abusive, Spam, Other) plus text field (Q6; the text sent is chip label plus free text), confirm `SbDangerButton`.
- Tokens only: `SbColors.star`, `SbColors.soft`, `SbTokens.rCard`, `SbTokens.screenPadding`, `gap*`. 44 px targets via `SbTokens.minTouch`. All icon buttons have Semantics labels. Text must wrap to 200% scale (no fixed heights on cards).

## 6. Role rules

- Owner, manager: full access. Specialist: no access (Q1). Enforce in three places: (1) nav config filters the item by role; (2) `GoRoute.redirect` sends specialists to `/`; (3) 403 from API shows a no-access state. A single `Permissions` helper in `lib/shell/permissions.dart` (shared with other plans) exposes `canViewReviews(role)`.
- Widget test per role: owner sees card actions; manager sees the same; specialist route redirects.

## 7. Validation, confirmations, formatting

- Reply: trimmed text non-empty, <= 2000 chars; Post disabled otherwise. No client-side profanity checks.
- Report: reason non-empty, <= 500; confirm dialog is mandatory and the confirm button is `danger`. Text: "Reporting cannot be undone from the app."
- Posting a reply is not destructive: black pill, no confirm. Edit also no confirm.
- Dates: `replied_at` and `created_at` formatted "Thu 29 Oct, 9:30 AM" through a shared `SbFormat.dateTime` in `sb_core` (add if no other plan has; uses `intl`, salon time zone is not available on this endpoint so use device local, flag). Money: `SbFormat.money(cents)` -> `LKR 1,500`.
- Average rating comes from `summary.average_rating`, shown to 1 decimal; bars use `rating_distribution` only (AC10).

## 8. ARB keys

`reviewsTitle`, `reviewsAverageSummary` ({avg}, {count}), `reviewsFilterAll`, `reviewsFilterNeedsReply`, `reviewsFilterStars` ({n}), `reviewsSortLabel`, `reviewsNoComment`, `reviewsYourReply`, `reviewsRepliedOn` ({date}), `reviewsReplyWithAiDraft`, `reviewsDraftWithAi`, `reviewsRegenerate`, `reviewsToneWarm`, `reviewsToneProfessional`, `reviewsToneApologetic`, `reviewsContextHint`, `reviewsReplyHint`, `reviewsReplyPublicHint` ("Your reply is visible to everyone"), `reviewsPostReply`, `reviewsEditReply`, `reviewsSaveReply`, `reviewsReportAsFake`, `reviewsReportTitle`, `reviewsReportReasonHint`, `reviewsReportReasonFake`, `reviewsReportReasonAbusive`, `reviewsReportReasonSpam`, `reviewsReportReasonOther`, `reviewsReportConfirm`, `reviewsReportWarning`, `reviewsReportedTag`, `reviewsEmpty`, `reviewsEmptyFiltered`, `reviewsLoadError`, `reviewsRetry`, `reviewsOfflineBanner`, `reviewsAlreadyReplied`, `reviewsNotFound`, `reviewsDraftRateLimited`, `reviewsDraftFailed`, `reviewsReplyTooLong`, `reviewsStarsSemantics` ({n}), `reviewsTipLine` ({amount}), `commonBack`, `commonCancel`.

## 9. Tests

Unit (`test/features/reviews/`):
- `review_models_test`: parses a full `PartnerReviewOut` JSON, nullable `comment`, `reply`, `user_name`; `rating_distribution` string keys.
- `reviews_repository_test` (mock Dio adapter): sends `replied=false` and `rating=2` query params; no `sort` when null; POST reply body is `{reply}`; draft body default tone `professional`; 409 maps to `Conflict`.
- `reviews_notifier_test`: filter change re-queries; loadMore appends and stops at null cursor; post reply updates the item and refetches; failed post keeps composer text; report sets `reported`.

Widget:
- Card with reply shows sand block and Edit; without reply shows "Reply with AI draft"; no comment shows "No comment"; 3 rating shows 3 filled and 2 outline stars.
- Tapping draft shows spinner then opens composer prefilled; Post is disabled for empty and whitespace; draft is not posted until Post tapped (verify no POST reply call).
- Report dialog: confirm disabled with empty reason; confirm button uses danger color; on success shows "Reported" tag and removes menu item.
- States: loading skeleton, empty, filtered empty, error with retry, offline banner disables actions.
- Roles: owner and manager render screen; specialist redirected.
- Text scale 2.0 pump has no overflow exceptions.

Golden: `reviews_phone_390.png` (two cards from the PNG: replied one, unreplied one), `reviews_tablet_1280.png` (summary, chips, list, composer open).

## 10. Task checklist

1. Confirm shell, auth/role provider, Dio interceptors and l10n are merged (else stub behind interfaces).
2. Add `sb_ui` widgets (star rating, rating bar, skeleton, error/empty, back pill, secondary/danger buttons, tag); each with a small widget test.
3. Add freezed models and run build_runner; model tests.
4. Implement `ReviewsRepository` with `ApiException` mapping; repository tests.
5. Implement providers (list, filter, composer); notifier tests with a fake repository.
6. Build `ReviewCard` and phone screen; golden 390 against the PNG.
7. Add filter bar and summary card; tablet layout and composer panel; golden 1280.
8. Composer: draft flow, tone chips, post/edit; tests.
9. Report dialog and flow; tests.
10. Wire route, sidebar item, role guard; role tests.
11. Add ARB strings; replace literals; run text-scale test.
12. `flutter analyze` and `flutter test` clean.

## 11. Open questions / API gaps / risks

- Q1 role matrix, Q2 `sort` values, Q3 draft credit cost and out-of-credit error, Q4 no push or WebSocket contract (use refetch on resume), Q5 tone allowed values (send "warm", "professional", "apologetic" lowercase; confirm) and max reply (API says 2000), Q6 report reasons are free text.
- `summary` filter scope is unknown (is it computed over all reviews or the filtered set?). Verify against the live API.
- `rating_distribution` key type and missing keys (treat a missing star count as 0).
- 401/403 are not declared in the OpenAPI responses for `/v1/partner/reviews*`; handled generically.
- The list endpoint has no total for filtered results; the "N waiting for a reply" figure is only `summary.unreplied_count`.
- Time zone: review timestamps are UTC; salon time zone is only in `/v1/partner/settings` (P-21). Use device local time until the session provides salon time zone.
- Draft is a paid action (possibly); show balance only if the API ever returns it. `GET /v1/partner/ai/credits` exists but showing it here is not in the spec; do not call it without PM approval.
