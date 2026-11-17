# P-19 AI Studio — Implementation Plan

- Spec: [docs/_specs/P-19_ai_studio.md](../_specs/P-19_ai_studio.md)
- Design: no PNG. Phone only has a More row "Opens on web" (`mobile/P-22_more.png`), so there is no native phone screen in v1 (Q6). This plan builds the web/tablet screen only. On phone widths, the route shows a short "Open on web" screen.

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p19-ai-studio`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Two-column AI Studio: post builder on the left (prompt, platform, tone, language, goal, hashtags, output type, credits card, "Generate · N credits"), result pane on the right (text with Copy and Share, image, Delete) and a history grid below. Generation is async: POST returns 202, then poll GET until terminal. Credits can be bought via purchase endpoint.

Prerequisites:
- Shell, role guard, auth/session (role, salon id), Dio with `X-Salon-Id` and the idempotency interceptor named in instructions §1 (`Idempotency-Key`).
- P-22 More row for the phone link (`url_launcher` to `https://partner.stylebook.lk/ai-studio`).
- Shared `sb_ui` skeleton, error card, empty state, danger button, secondary button (first plan to land creates them; see P-18 plan).
- Payment: purchase returns `client_secret`. The payment provider (Stripe or other) is unspecified (risk, section 11).

## 2. Files to create / modify

`apps/partner/lib/features/ai_studio/`:
- `data/ai_models.dart` (freezed): `AiCredits`, `AiUsageItem`, `AiPost`, `AiPostCreated`, `AiPostPage`, `AiPurchase`, `AiPostType` enum (`text`, `image`, `textAndImage`), `AiPostStatus` (see risks, unknown-safe parse).
- `data/ai_studio_repository.dart`.
- `application/ai_credits_provider.dart` (`AsyncNotifier<AiCredits>`), `application/ai_builder_controller.dart` (form state, `Notifier`), `application/ai_generation_controller.dart` (`AsyncNotifier`, polling), `application/ai_history_provider.dart` (paged `AsyncNotifier`), `application/ai_purchase_controller.dart`.
- `presentation/ai_studio_screen.dart` (adaptive; phone shows `AiStudioWebOnlyView`), `presentation/widgets/post_builder_form.dart`, `credits_card.dart`, `result_pane.dart`, `history_grid.dart`, `buy_credits_sheet.dart`, `delete_post_dialog.dart`.
- Tests under `apps/partner/test/features/ai_studio/`.

Shell/router/pubspec:
- `lib/router.dart`: `/ai-studio` route (owner, manager). Sidebar item "AI Studio".
- `apps/partner/pubspec.yaml`: add `share_plus` (system share), `flutter/services` Clipboard needs no package, `url_launcher` (shared with P-22), `uuid` (Idempotency-Key). Payment SDK deferred (section 11).

sb_ui additions: `SbSkeleton` (shared), `SbStatCard`-style credit card if none exists (style guide lists a stat card; not in `sb_theme.dart` yet), `SbBanner` (info/warning/danger banner for "Not enough credits", offline), `SbCharCounterField` (multiline field with counter), `SbChipGroup` (wrap of `SbChoiceChip` with single-select semantics), `SbDangerButton`, `SbSecondaryButton`.

l10n: `app_en.arb` (section 8).

## 3. Data layer

| Method | Path | Notes |
|---|---|---|
| GET | `/v1/partner/ai/credits` | `CreditsOut {salon_id, balance, cost_per_text_post, cost_per_image_post, cost_per_text_and_image_post, recent_usage[]}` |
| POST | `/v1/partner/ai/posts` | `PostCreateIn {type, prompt (1..1000), style (<=50), platform, include_hashtags, language}` -> 202 `PostCreatedOut {post_id, status, credits_reserved, estimated_seconds}` |
| GET | `/v1/partner/ai/posts/{post_id}` | `PostOut {id, prompt, generated_text?, generated_image_url?, model_used, credits_used, status, created_at}` |
| GET | `/v1/partner/ai/posts` | query `status`, `cursor`, `limit` -> `PostListOut {items: PostOut[], next_cursor}` |
| DELETE | `/v1/partner/ai/posts/{post_id}` | 204 |
| POST | `/v1/partner/ai/credits/purchase` | headers `Idempotency-Key` (also `X-Idempotency-Key` declared); body `PurchaseIn {pack, payment_method default "card"}` -> `PurchaseOut {payment_intent_id, client_secret?, amount_cents, credits_to_add}` |

Note: the spec's `PostOut` has no `error`/`message` field for failed status; the "API message" in AC6 is not available on GET (gap). Use a generic localized message plus `status` text.

Request mapping: prompt (what to promote + goal appended by app, Q3; the goal text is a localized sentence, e.g. "Goal: get more bookings." appended after a blank line, counted inside the 1000 char limit) -> `prompt`; tone chip -> `style`; platform chip -> `platform` (lowercase `instagram`, `facebook`, `tiktok`, `generic`); language -> `language` (`en`, `si`, `ta`); output type -> `type`.

Repository: `credits()`, `createPost(request)`, `getPost(id)`, `listPosts({status, cursor, limit})`, `deletePost(id)`, `purchase({pack, paymentMethod, idempotencyKey})`.

Error mapping: 429 -> `RateLimited` (AC9 text); 402/409/422 on create -> `InsufficientCredits` guess is undocumented (Q2), so map: 402 or 409 -> `InsufficientCredits` (show banner and refetch credits); 422 -> `Validation`; otherwise generic error with retry. Delete 404 -> treat as already gone, remove from list. Purchase 422 -> field error.

## 4. Application / state

- `aiCreditsProvider`: loads on screen open, `refresh()` after generate success/failure, delete (no refund, but cheap), and purchase. Never modified locally.
- `AiBuilderController` state: `prompt`, `goal?`, `platform`, `tone?`, `language` (default from `Localizations.localeOf`: en/si/ta else en), `includeHashtags` (true), `type` (text). Derived: `cost` = matching `cost_per_*` from `AiCredits` (read, not computed), `canGenerate = prompt.trim().isNotEmpty && length <= 1000 && credits != null && balance >= cost && !generating && online`.
- `AiGenerationController` (`AsyncNotifier<GenerationState?>`): `generate()` -> POST; keep `postId`; poll `GET /posts/{id}` every 2 s up to 60 s (first delay `min(estimated_seconds, 2)` s, a hint only); stop on terminal status; on timeout set `timedOut` and keep the post in history (user can leave). Poll uses a cancellable `Timer` disposed with `ref.onDispose`. Terminal status values are undocumented (Q5): treat `completed`/`succeeded`/`done` and any non-null `generated_text` or `generated_image_url` with a non-"pending|processing|queued" status as success, `failed|error|rejected` as failure; central helper `AiPostStatus.parse` with unit tests, unknown values are non-terminal until timeout. Keep this one place so it is easy to fix once the real enum is known.
- Leaving the page: controller is not auto-disposed while generating (`keepAlive` while polling); history refreshes when it ends.
- `AiHistoryNotifier`: first page on open, `loadMore`, `delete(id)` (removes after 204; on 404 also removes), `refresh()`; optional `status` filter chips are not in spec, skip.
- `AiPurchaseController`: `purchase(pack)` generates a fresh UUID per user-confirmed attempt (reused on retry of the same attempt, new one for a new attempt), calls POST, hands `client_secret` to the payment layer (interface `PaymentLauncher`), then refetches credits. Payment errors leave balance unchanged.
- Loading: credits shimmer, history skeleton cards. Empty history: `aiHistoryEmpty`. Error: retry banner with the builder values kept (builder state lives in its own provider, unaffected by failures).
- Offline: builder disabled with banner; history stays on last loaded data.

## 5. Presentation

- `AiStudioScreen`: `LayoutBuilder`. >= 900 px: `SingleChildScrollView > Column[ Title row, Row[ Expanded(PostBuilderForm card), Expanded(ResultPane card) ], HistoryGrid ]`. Below 900 px: a single `Column` (builder, result, history) for tablets in portrait; true phone widths (< 600 px) show `AiStudioWebOnlyView` (title, text, `SbPrimaryButton` "Open web app") since v1 has no phone UI (Q6).
- `PostBuilderForm` (`SbCard`): multiline prompt with live counter `n/1000` (turns `danger` color over limit and blocks), platform `SbChipGroup`, tone `SbChipGroup`, language chips, goal chips, `SwitchListTile`-style row for hashtags (theme switch), output type chips (Text, Image, Text + image), `CreditsCard` (balance, costs), `SbBanner` "Not enough credits" + "Buy credits" secondary button when `balance < cost`, `SbPrimaryButton("Generate · N credits")` (progress label while generating).
- `ResultPane`: states idle (hint), generating (`SbSkeleton` lines and image box plus "about N seconds" using `estimated_seconds` text only), success (text in selectable block, "Check the text before posting" hint, Copy -> clipboard + snackbar, Share -> `share_plus`; image via `Image.network` with loading/error builders; Delete), failed ("Could not generate" + retry), timed out ("Still working, find it in History").
- `HistoryGrid`: responsive `GridView` (2 to 4 columns); card shows thumbnail or first lines of `generated_text`, date, `credits_used`, status pill (reuse `SbStatusPill` mapping or a new generic `SbTag`). Tap loads post into the result pane; overflow Delete.
- `BuyCreditsSheet`: pack list as `SbOptionTile` (style guide names it; not yet in `sb_theme.dart`, add it to `sb_ui`) from... packs are not provided by the API (gap, section 11); render a placeholder list from a config constant only once confirmed. Confirm = black pill, shows `credits_to_add` and `amount_cents` from `PurchaseOut` after create.
- Tokens only; 44 px targets; icon buttons (copy, share, delete) have Semantics labels and tooltips; layout wraps at 200% text.

## 6. Role rules

- Owner: generate, history, buy credits, delete. Manager: generate and history; buy credits hidden (assumed, Q1); delete allowed (spec table lists delete for owner only, so hide Delete for manager and show a note in the open questions). Specialist: no route.
- Enforcement: `Permissions.canUseAiStudio(role)`, `canBuyAiCredits(role)`, `canDeleteAiPost(role)`; route redirect plus nav filtering; widgets read the permission and do not render the action. 403 shows a no-access view.

## 7. Validation, confirmations, formatting

- Prompt required and <= 1000 chars including appended goal; style <= 50 (tone labels are short constants).
- Generate sends nothing if `balance < cost` (spec AC2).
- Delete confirm dialog: text "Credits are not refunded", confirm `SbDangerButton`. Purchase confirm: black pill (not destructive), shows pack and amount.
- Money: `amount_cents` -> `LKR 1,500` via `SbFormat.money`. Credits are plain integers ("12 credits", ARB plural). Dates "Thu 29 Oct, 9:30 AM".
- No client-side credit math: the button label reads `cost_per_*`; balance is always the API value.

## 8. ARB keys

`aiStudioTitle`, `aiBuilderTitle`, `aiResultTitle`, `aiPromptLabel`, `aiPromptHint`, `aiPromptCounter` ({n}, {max}), `aiPlatform`, `aiPlatformInstagram`, `aiPlatformFacebook`, `aiPlatformTiktok`, `aiPlatformGeneric`, `aiTone`, `aiToneWarm`, `aiToneProfessional`, `aiToneFriendly`, `aiToneBold` (final tone list needs PM), `aiLanguage`, `aiLanguageEn`, `aiLanguageSi`, `aiLanguageTa`, `aiGoal`, `aiGoalMoreBookings`, `aiGoalFillQuietDays`, `aiGoalNewService`, `aiGoalOffer`, `aiGoalPromptPrefix`, `aiIncludeHashtags`, `aiOutputType`, `aiTypeText`, `aiTypeImage`, `aiTypeTextImage`, `aiCreditsBalance` ({n}), `aiCreditsCost` ({n}), `aiGenerateCta` ({n}), `aiGenerating`, `aiEstimatedSeconds` ({n}), `aiNotEnoughCredits`, `aiBuyCredits`, `aiBuyConfirm`, `aiBuyPackLabel` ({credits}, {amount}), `aiPurchaseSuccess`, `aiPurchaseFailed`, `aiResultHint` ("Check the text before posting"), `aiCopy`, `aiCopied`, `aiShare`, `aiDelete`, `aiDeleteTitle`, `aiDeleteBody` ("Credits are not refunded"), `aiDeleteConfirm`, `aiGenerationFailed` ("Could not generate"), `aiGenerationTimedOut`, `aiRateLimited` ("Too many requests, try again shortly"), `aiHistoryTitle`, `aiHistoryEmpty`, `aiHistoryCredits` ({n}), `aiRetry`, `aiOfflineBanner`, `aiOpenOnWeb`, `aiWebOnlyBody`, `aiNoAccess`.

## 9. Tests

Unit:
- `ai_post_status_test`: known and unknown statuses; terminal detection.
- `ai_builder_controller_test`: cost picks `cost_per_text_post`/`image`/`text_and_image` for the type; `canGenerate` false when empty, over 1000, balance below cost; goal appended into `prompt` and within limit; language default from locale.
- `ai_generation_controller_test` (fake async clock via `fakeAsync`): polls every 2 s; stops on success; stops at 60 s with `timedOut`; failure triggers credit refetch; 429 maps to rate-limited state; dispose cancels timer.
- `ai_repository_test`: request body field names and defaults; purchase sends `Idempotency-Key` and a new key per attempt.
- `ai_history_notifier_test`: delete removes on 204 and on 404; pagination.

Widget:
- Button label uses API cost, "Generate · 5 credits" when `cost_per_image_post=5` and type image.
- Insufficient credits: button disabled, banner and Buy action visible; tapping does not call the repository.
- Prompt counter blocks over 1000.
- Result pane: skeleton while generating, text + Copy/Share on success (Copy writes the clipboard), failure message, Delete shows danger confirm.
- History empty and error states; offline disables builder.
- Roles: owner sees Buy credits; manager does not; specialist redirected.
- Phone width shows web-only view.
- Text scale 2.0 no overflow.

Golden: `ai_studio_1280.png` (builder, result success, history of 3). Phone golden at 390 for `AiStudioWebOnlyView`.

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p19-ai-studio`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. Confirm prerequisites (shell, auth/role, Dio idempotency, l10n); add `share_plus`, `url_launcher`, `uuid`.
2. Add `sb_ui` pieces (banner, chip group, counter field, skeleton, option tile, danger/secondary buttons) with widget tests.
3. Models and repository with tests.
4. Credits provider; credits card UI; state tests.
5. Builder controller and form; validations; tests.
6. Generation controller with polling and status helper; `fakeAsync` tests.
7. Result pane (copy, share, image, failure, timeout).
8. History provider and grid; delete flow with confirm.
9. Buy credits sheet and purchase controller (payment launcher behind an interface, fake in tests).
10. Role wiring, route, phone web-only view, sidebar item.
11. ARB strings; text scale test; goldens.
12. `flutter analyze` and `flutter test`.

## 11. Open questions / API gaps / risks

- Q1 manager rights (buy credits, delete). Q2 insufficient-credits status and code undocumented. Q3 no `goal`, no multi-caption output, no publish endpoint (system share only). Q4 credit release on failure; always refetch. Q5 allowed `type`, `platform`, `status`, `pack` values undocumented. Q6 no phone UI.
- No endpoint lists purchasable packs or prices; `PurchaseIn.pack` is a free string. Need backend or PM to supply pack ids and prices, otherwise buy flow cannot be built beyond a stub.
- Payment completion with `client_secret` needs an SDK (Stripe or PayHere) and web support; undecided. Plan keeps it behind a `PaymentLauncher` interface.
- `PostOut` has no failure message field, so AC6 "show the API message" cannot be met from GET; need `error` or `failure_reason` on the contract.
- Both `Idempotency-Key` and `X-Idempotency-Key` are declared; use `Idempotency-Key` as the spec says.
- Credits `recent_usage` is returned but the spec does not display it; optional "Usage" list later.
- `generated_image_url` hosting and CORS on web (Flutter web canvas) may block `Image.network`; may need CanvasKit/HTML renderer check. Verify early.
- Spec says tone chip -> `style`; allowed tone list not given, so the tone chip set in the ARB list is a proposal.
