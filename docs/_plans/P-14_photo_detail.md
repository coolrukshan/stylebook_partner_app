# P-14 Photo Detail — Implementation Plan

- Spec: [docs/_specs/P-14_photo_detail.md](../_specs/P-14_photo_detail.md)
- Design: `mobile/P-14_photo_detail.png`, `mobile/P-14_photo_delete_confirm.png`

## 1. Summary and dependencies

Edit one gallery photo: "Done by" specialist chips (single select), show-on-salon-page toggle, set as cover (added, not in design), delete with in-place confirm (phone) or dialog (web). Presented as a bottom sheet (phone) or right side panel (>= 900 px) from P-13.

Depends on:
- P-13 (same branch): `GalleryItem`, `GalleryRepository`, `GalleryController` (`applyUpdated`, `removeById`, `refresh`), `GalleryTags`, `canManageGalleryProvider`, staff chips data.
- Shared `sb_ui`: `SbBottomSheet.show`, `SbSidePanel`, `SbPillBadge` (P-13), plus new `SbDangerButton`/`SbOutlinedDangerButton`, `showSbConfirm` (also needed by P-15 cancel and P-16). Coordinate so only one plan creates them (suggest P-13's task 3 or whichever merges first).
- P-01 role provider, `ApiException`.

Current code has no theme slot for an outlined danger button or red filled button: `SbColors.danger`/`dangerBg` exist, `SbPrimaryButton` is ink only. Must add to `sb_ui`.

## 2. Files to create / modify

Create under `apps/partner/lib/features/gallery/`:
- `application/photo_detail_controller.dart` (family AsyncNotifier keyed by image id, or a `Notifier` seeded from the list item; see section 4)
- `presentation/photo_detail_sheet.dart` (content shared by sheet and panel: `PhotoDetailContent`)
- `presentation/photo_detail_presenter.dart` (`openPhotoDetail(context, ref, item)` chooses sheet vs side panel by width)
- `presentation/widgets/done_by_chips.dart`
- `presentation/widgets/delete_photo_section.dart` (idle / confirming / deleting state machine)

Modify:
- `data/gallery_repository.dart`: add `update(id, GalleryUpdate)`, `delete(id)`; `setCover(id)` already in P-13.
- `data/gallery_models.dart`: `GalleryUpdate` (nullable fields, `toJson` omits nulls), `DeleteRequest`.
- `application/gallery_controller.dart`: hooks used here.
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_ui`: `SbDangerButton` (filled red, white text, pill), `SbOutlinedDangerButton` (white, `dangerBg`-tinted border, `danger` text, min height 44+), `SbSwitchRow` (label + switch + pending spinner + Semantics), `SbSelectChip` (amber selected variant: `amberTint` fill, `amberBorder`/`amber` border, `amberDark` text, per design "selected amber"; note `SbChoiceChip` selected is ink so a variant param is needed), `showSbConfirm`.

## 3. Data layer

| Method | Path | Body | Result |
|---|---|---|---|
| PUT | `/v1/partner/gallery/{image_id}` | `UpdateIn {caption?, tags?, sort_order?, is_hidden?}` | 200 `GalleryItemOut` |
| POST | `/v1/partner/gallery/{image_id}/cover` | none | `CoverOut {id, is_cover, previous_cover_id}` |
| DELETE | `/v1/partner/gallery/{image_id}` | `DeleteIn {confirm: true}` (JSON body on DELETE: set `Options(contentType: json)` and `data:`) | 204 |

Repository: `Future<GalleryItem> update(String id, GalleryUpdate patch)`, `Future<CoverResult> setCover(String id)`, `Future<void> delete(String id)` (always sends `confirm: true`; the UI guarantees the confirm step).
Error mapping: 404 -> `PhotoGone` (already deleted: close, remove tile, refresh); 409 on delete -> message + refresh; 422 -> field message; 429 -> rate-limit message; network -> generic retry message. Note tags edit sends the full tags list (replace semantics assumed; confirm, Gap).

## 4. Application / state

`photoDetailControllerProvider(imageId)` (`AsyncNotifier<PhotoDetailState>` or `Notifier` with initial value from the list item, avoids a second GET since there is no single-item endpoint):
```
PhotoDetailState { GalleryItem item; Set<PendingField> pending (hidden, staff, cover); DeletePhase delete (idle, confirming, deleting); String? errorMessage }
```
- `toggleVisible(bool show)`: sets `pending.add(hidden)`, sends PUT `is_hidden: !show`. Pessimistic display: switch shows the pending spinner and the requested value only after success (spec: "pending state, reverts with toast on failure"). On success: `item = result`, `GalleryController.applyUpdated(result)` (grid + "N of M visible" update), then background `refresh()`. On failure: keep old value, emit toast message.
- `selectStaff(String? staffId)`: new tags = old tags minus `staff:*` plus new tag (via `GalleryTags.replaceStaff`); PUT `tags`; same success/failure path; tile subtitle updates through `applyUpdated`.
- `setCover()`: POST cover; on success update item `is_cover = true`, refresh the grid (previous cover id changes too, so full refresh rather than local patch).
- Delete: `requestDelete()` sets phase `confirming` (no request); `cancelDelete()` returns to idle (outside tap, Back, sheet dismiss); `confirmDelete()` sets `deleting`, calls DELETE; on success `removeById`, close sheet/panel, snackbar "Photo deleted"; on 404/409: show message, `refresh()`, close. While `deleting` the sheet has `isDismissible: false` and `PopScope(canPop: false)`.
- Offline (`connectivityProvider`): all controls disabled.
- Selection source: current staff chip = `GalleryTags.staffIdOf(item.tags)`; list of chips from the P-13 staff provider (active staff only, first name via `fullName.split(' ').first`; handle duplicates by showing full name).

## 5. Presentation

Phone bottom sheet (`SbBottomSheet.show`, scrollable, `isScrollControlled`, max 90% height, dimmed grid via barrier), tree from design:
```
Column(
  ClipRRect(rCard) AspectRatio(~2:1.2) Stack(CachedNetworkImage(image_url), portraitFade, caption Text white)  // Semantics label caption
  Text('Done by', titleMedium)
  Wrap(spacing gap8) [ SbSelectChip per staff ]      // single select, tap selected = no-op
  SbSwitchRow('Show on salon page', value: !is_hidden, pending)
  if is_cover: SbPillBadge('Cover photo') else SbOutlinedButton('Set as cover')
  DeletePhotoSection
)
```
`DeletePhotoSection`:
- idle: `SbOutlinedDangerButton('Delete photo')` (>= 44, design height 52).
- confirming (phone, per PNG): prompt text above (`bodyMedium`, includes permanence: "Delete this photo? It disappears from your salon page and cannot be restored.") and the button becomes `SbDangerButton('Yes, delete photo')`; a text "Cancel" link-button under it for non-gesture dismissal; Back/outside tap cancels first (`PopScope` intercept: first back cancels confirm, second closes).
- web side panel (>= 900 px): tapping Delete shows `showSbConfirm` dialog (danger confirm "Yes, delete photo", cancel "Keep photo").
- deleting: button shows spinner, disabled.
Web panel: `SbSidePanel` 420 px wide, close icon button with Semantics "Close", same content widget.
Cover-deletion warning: if `item.isCover`, prompt adds "This is your cover photo." (ARB key).
Specialist: `PhotoDetailContent(readOnly: true)`: image + caption + the specialist name as plain text; no chips, no toggle, no delete, no cover.
Tokens: `SbTokens.rCard`, `rSheet` (theme), `gap8/12/16/24`, `minTouch`, `SbColors.danger/dangerBg` only through the new sb_ui buttons; the switch uses the existing `switchTheme` (green on).
Text scale 200%: chips wrap, switch row text wraps, sheet scrolls.

## 6. Role rules

- Owner: edit + delete. Manager: edit + delete (PM to confirm delete; build behind `canDeletePhotoProvider` returning true for owner and manager so one-line change).
- Specialist: view only (no toggle, chips, cover, delete).
Enforced by `canManageGalleryProvider` / `canDeletePhotoProvider` (in `gallery_permissions.dart`, created in P-13). Controllers early-return if not permitted. API 403 -> toast "You do not have access to change photos" and refresh.

## 7. Validation, confirmations, formatting

- Delete is destructive: no request until the confirm step; confirm button `danger`; copy states permanence (spec §7). `DeleteIn.confirm` always `true`.
- Reason: none required for delete (instructions require reasons only for decline and stock).
- Toggle ON means `is_hidden=false`. Hiding the cover: warn before sending ("This is your cover photo. Hide anyway?" with `showSbConfirm`, non-danger) since API behaviour is unknown (Gap in P-13).
- No money; created date not displayed (could show `uploaded_by_name`, label optional).
- Snackbars via a shared `showSbSnack(context, message)` helper using the theme `snackBarTheme`.

## 8. ARB keys

`photoDetailDoneBy`, `photoDetailShowOnSalonPage`, `photoDetailShowSemantics`, `photoDetailSetCover`, `photoDetailIsCover`, `photoDetailCoverSet`, `photoDetailDelete`, `photoDetailDeletePrompt`, `photoDetailDeletePromptCover`, `photoDetailDeleteConfirm`, `photoDetailKeepPhoto`, `photoDetailDeleted`, `photoDetailDeleteFailed`, `photoDetailAlreadyDeleted`, `photoDetailUpdateFailed`, `photoDetailHideCoverWarningTitle`, `photoDetailHideCoverWarningBody`, `photoDetailHideAnyway`, `photoDetailClose`, `photoDetailNoSpecialist`, `photoDetailNoAccess`, `photoDetailOfflineDisabled`.

## 9. Tests

Unit:
1. `selectStaff` replaces only `staff:*` tag and preserves other tags; sends PUT with full tags.
2. `toggleVisible(false)` sends `is_hidden: true`; failure keeps old value and emits message; success calls `applyUpdated` and the summary counts change.
3. Delete: `requestDelete` sends no request; `confirmDelete` sends DELETE with `{confirm: true}`; 204 removes item; 404 and 409 refresh and close; cancel returns to idle.
4. `setCover` success updates `is_cover` and triggers list refresh.
Widget:
5. Initial chip and switch reflect item values.
6. Toggle shows spinner while pending; reverts on failure with snackbar text.
7. Delete flow on phone: tap "Delete photo" -> prompt + "Yes, delete photo" (danger colour from theme) and zero DELETE calls; Back cancels confirm; second tap confirms -> sheet closes, "Photo deleted" snackbar.
8. Deleting state: sheet not dismissible, button disabled.
9. Specialist: no chips, switch, cover, or delete widgets found.
10. Hiding cover shows warning dialog.
11. Semantics: switch label "Show on salon page"; close button label; delete button >= 44 px tall.
12. Web width (1280): side panel is used and delete opens a dialog.
Golden: `photo_detail_390.png` (idle) and `photo_detail_delete_confirm_390.png` (mirrors the two PNGs), `photo_detail_panel_1280.png`.

## 10. Task checklist

1. Add `sb_ui` widgets: `SbDangerButton`, `SbOutlinedDangerButton`, `SbSwitchRow`, `SbSelectChip`, `showSbConfirm`, `showSbSnack` + tests (skip any already added by another plan).
2. Extend repository/models (`update`, `delete`) + tests.
3. Controller with state machine + unit tests.
4. Sheet content (read-only and editable), chips, switch row.
5. Delete section phone flow + PopScope handling.
6. Side panel + dialog for web; `openPhotoDetail` chooser.
7. Hook into P-13 tile tap; verify grid/summary updates.
8. Role gating and offline disabling.
9. Goldens, a11y, text-scale tests; ARB strings.
10. `flutter analyze` and `flutter test`.

## 11. Open questions / gaps / risks

- Same Gap 1 as P-13: no structured staff/service; chips write `staff:<uuid>` tags. Service selector and caption editing are not in the design; plan leaves a clearly marked extension point (`ServiceTagPicker`, caption `TextField`) but does not build them unless PM approves. Instructions (§3 P-13) do require service tagging: flag to PM.
- Does `UpdateIn.tags` replace or merge? Assumed replace.
- `DeleteIn.confirm` default and behaviour with `false` unknown; we always send `true`.
- Deleting or hiding the cover: API behaviour undocumented. Plan warns and refetches.
- Gallery endpoints list no 401/403 in OpenAPI; role enforcement server-side unspecified.
- No GET single image: sheet depends on the list item; stale if another admin edits (last-write wins; refresh after each success).
- DELETE with a JSON body: some proxies/Dio configs drop bodies on DELETE; verify against the running API.
- Manager delete permission pending PM.
