# P-13 Gallery — Implementation Plan

- Spec: [docs/_specs/P-13_gallery.md](../_specs/P-13_gallery.md)
- Design: `mobile/P-13_gallery.png`
- Branch: `feature/p13-gallery` off `main` (P-14 is built on the same branch, see P-14 plan).

## 1. Summary and dependencies

Gallery grid for the Gallery tab: summary line, specialist filter chips, 2-col (phone) / 4-5 col (web) tile grid with hidden pill, cursor pagination, three-step S3 upload with per-tile progress, web drag reorder. Tapping a tile opens P-14.

Current code state (checked): `apps/partner/lib` has only `main.dart`, `app.dart`, `router.dart` (single `/` route) and a placeholder `today_screen.dart`. There is no shell, no auth/role provider, no l10n folder, no repository base, no `sb_core` formatters, and `apps/partner/pubspec.yaml` only declares `flutter_riverpod ^3.5.0` (Riverpod 3, not 2; no freezed, json_serializable, cached_network_image, image_picker, file_picker, mocktail). `sb_ui` has `SbChoiceChip`, `SbCard`, `SbPrimaryButton`, `SbStatusPill` (booking statuses only), `SbFloatingNav`, but no bottom-sheet helper, no skeleton, no empty/error panel, no image tile.

Prerequisites (must exist before this screen, owned by earlier build-order items):
- P-01: auth session, `currentRoleProvider` (owner/manager/specialist), Dio interceptors (auth refresh, `X-Salon-Id`, idempotency key).
- Adaptive shell (`lib/shell`): sidebar >= 900 px, floating nav on phone, a Gallery route. If not built, P-13 adds only a `/gallery` GoRoute and the shell task adds the nav entry.
- P-09 staff list (`GET /v1/partner/staff`) for chips. If P-09 is not merged, create the minimal `staffNamesProvider` here and let P-09 absorb it.
- Shared (create once, reused by P-14..P-17, coordinate with other plans): `sb_core` `ApiException` + `ErrorResponse` mapping, `Money.format(cents)`, `SbDates` formatters; `sb_ui` `SbEmptyState`, `SbErrorPanel`, `SbSkeleton`, `SbBottomSheet.show`, `showSbConfirm`.

## 2. Files to create / modify

Create under `apps/partner/lib/features/gallery/`:
- `data/gallery_models.dart` (freezed + json: `GalleryItem`, `GalleryPage`, `UploadUrl`, `GalleryUpdate`, `CoverResult`)
- `data/gallery_repository.dart`
- `data/gallery_tags.dart` (tag convention parser/encoder, see Gap 1)
- `data/upload_service.dart` (S3 PUT with progress using a separate bare `Dio`, no auth headers)
- `application/gallery_controller.dart` (`GalleryController` AsyncNotifier, family-less; filter in state)
- `application/gallery_filter_provider.dart` (selected staff id)
- `application/upload_queue_controller.dart` (Notifier of `List<UploadTask>`)
- `application/gallery_summary_provider.dart` (derived counts)
- `presentation/gallery_screen.dart`
- `presentation/widgets/gallery_grid.dart` (SliverGrid, reorderable variant on web)
- `presentation/widgets/gallery_tile_content.dart` (caption overlay, hidden pill, upload progress/retry overlay)
- `presentation/widgets/gallery_filter_bar.dart`
- `presentation/widgets/gallery_empty.dart`

Modify:
- `apps/partner/lib/router.dart`: add `GoRoute('/gallery')` inside the shell; redirect rule not needed (all roles may view).
- `apps/partner/lib/shell/*`: nav entry Gallery (already in phone nav per design).
- `apps/partner/lib/l10n/app_en.arb` (create with `l10n.yaml` if no earlier screen did).
- `apps/partner/pubspec.yaml`: add `cached_network_image`, `image_picker`, `file_picker`, `freezed_annotation`, `json_annotation` (+ dev `build_runner`, `freezed`, `json_serializable`, `mocktail`).
- `packages/sb_ui/lib/theme/sb_theme.dart` (or new `lib/widgets/*.dart` exported from `sb_ui.dart`): new shared widgets below.
- `packages/sb_api`: add `partnerRepositoryBase`/`apiErrorFrom(DioException)` if P-01 has not.

## 3. Data layer

All calls need `X-Salon-Id` (interceptor). Models are plain mirrors of `openapi.json`.

| Method | Path | Notes |
|---|---|---|
| GET | `/v1/partner/gallery` | query `include_hidden=true`, `tag` (maxLength 50), `cursor`, `limit`. Response `GalleryListOut {items, total_count, next_cursor}` |
| POST | `/v1/partner/gallery/upload-url` | body `UploadUrlIn {filename (<=255), content_type, file_size_bytes}` -> `UploadUrlOut {upload_url, object_key, image_id, expires_in_seconds}` |
| PUT | `upload_url` (S3) | raw bytes, `Content-Type` header must equal declared type; no API auth header |
| POST | `/v1/partner/gallery/{image_id}/confirm` | `ConfirmIn {caption, tags[], sort_order}` -> 201 `GalleryItemOut` |
| PUT | `/v1/partner/gallery/reorder` | `ReorderIn {order: [{image_id, sort_order}]}` -> `ReorderOut {updated_count}` |
| POST | `/v1/partner/gallery/{image_id}/cover` | used from P-14 |
| GET | `/v1/partner/staff` | chips (`id`, `full_name`) |

`GalleryItem`: `id, imageUrl, thumbnailUrl?, caption?, tags (List<String>), isCover, isHidden, sortOrder, uploadedByName?, createdAt`.

Repository (`GalleryRepository`): `list({String? tag, String? cursor, int limit = 24})`, `requestUploadUrl(...)`, `confirm(imageId, {caption, tags, sortOrder})`, `reorder(List<ReorderEntry>)`, `setCover(id)`. `uploadToS3(url, bytes, contentType, onProgress)` lives in `UploadService`, not the repository.

Error mapping: Dio error -> `ApiException(code, message, field, status)` from `ErrorResponse`. 422 on upload-url shows API `message` (limits come from API, spec §7). 429 -> "Too many requests, try again in a moment". Confirm 404/409 -> mark task failed, offer re-upload from step 1. S3 403 (expired URL) -> redo step 1 once automatically, then fail.

## 4. Application / state

`GalleryController extends AsyncNotifier<GalleryState>`:
```
GalleryState { List<GalleryItem> items; int totalCount; String? nextCursor; bool loadingMore; Object? loadMoreError; }
```
- `build()` watches `galleryFilterProvider` (a `staffId?`), resolves the tag string via `GalleryTags.forStaff(staffId)` (Gap 1) and loads page 1 with `include_hidden=true`.
- `loadMore()` guarded by `loadingMore`/`nextCursor != null`; triggered by scroll controller at 80% extent.
- `applyUpdated(GalleryItem)`, `removeById(id)`, `prependConfirmed(item)`: used by P-14 and the upload queue so the grid and summary update without a refetch; each followed by a background `refresh()` (spec P-14 §7 "refresh grid after each success").
- `reorder(List<GalleryItem> newOrder)`: optimistic local reorder, one PUT with the full order (sort_order = index), on failure restore the saved previous list and surface a snackbar. Only enabled when no filter is active (reordering a filtered subset would send a partial order; see Gap below).
- Summary: `visibleCount = items.where(!isHidden).length`, `total = state.totalCount`. These are display counts of API data, no business computation. If `total_count` semantics prove "visible only" the label degrades to "N photos" (Gap 6).

`UploadQueueController extends Notifier<List<UploadTask>>`; `UploadTask {localId, fileName, bytes/path, contentType, size, phase: validating|requesting|uploading|confirming|done|failed, progress 0..1, error?, imageId?}`.
- `enqueue(List<PickedFile>)`: client-side validation (jpeg/png/webp; size cap) before any request; rejected files produce a message and never enter the queue. Size cap constant is not documented: read it from `GET /v1/partner/settings` if it exposes one, else rely on API 422 (Gap 5).
- Runs max 2 concurrent tasks. On `done` it calls `GalleryController.prependConfirmed`. `retry(localId)` restarts from step 1 for that tile only. Offline: `connectivityProvider` disables enqueue and edits.

States: loading = `SbSkeleton` grid of grey tiles; empty = `SbEmptyState` with black Upload (hidden for specialist); error = `SbErrorPanel` with retry; load-more error = trailing retry row. Offline: cached tiles via `CachedNetworkImage`, upload disabled, banner.

## 5. Presentation

Tree (phone):
```
Scaffold(canvas)
 SafeArea > CustomScrollView
   SliverToBoxAdapter: Header row [Text('Gallery', headlineMedium), Spacer, if(canUpload) SbPrimaryButton('+ Upload', expand:false)]
   SliverToBoxAdapter: summary Text(bodySmall)  // l10n with counts
   SliverToBoxAdapter: GalleryFilterBar (horizontal ListView of SbChoiceChip: All + first names)
   SliverPadding > SliverGrid(2 cols, gap16, childAspectRatio ~1.09)  // 348x320 in PNG
        SbImageTile(image, title: caption, subtitle: 'Kasun · Skin fade', hiddenBadge, onTap)
   loading-more footer
 bottom padding for SbFloatingNav
```
- Tablet/web (>= 900 px): header, same filter bar, `SliverGrid` with `maxCrossAxisExtent` ~240 (4-5 columns). Reorder via `ReorderableGridView`-style: Flutter has no built-in grid reorder, use a `Wrap` of `LongPressDraggable`/`DragTarget` tiles or the `reorderable_grid_view` package (add; needs team approval, listed in risks). Drag handle icon with Semantics label "Reorder photo". P-14 opens as a right side panel (`SbSidePanel`) next to the grid via `Row(Expanded(grid), SizedBox(width:420, panel))`.
- Phone tap opens `showSbBottomSheet` with `PhotoDetailSheet` (P-14).
- Upload: phone `image_picker.pickMultiImage`; web `file_picker` with `allowMultiple` and `withData: true`. Choose via `kIsWeb`.

New `sb_ui` components (feature code must not style):
- `SbImageTile` (rounded `rCard`, `portraitFade` gradient overlay, white title/subtitle, optional `SbPillBadge('Hidden')` top-left, optional progress/retry overlay slot, Semantics label = caption). Image provider injected so goldens can use a local asset.
- `SbPillBadge` (white pill, muted text, radius `rPill`) used by Hidden badge.
- `SbSkeleton` / `SbSkeletonGrid` (no shimmer animation when `MediaQuery.disableAnimations`).
- `SbEmptyState`, `SbErrorPanel`, `SbBottomSheet.show`, `SbSidePanel`: shared with P-14..P-17; implement once.
- Text must handle 200% scaling: caption `maxLines: 2` ellipsis; chip bar scrolls horizontally; grid aspect ratio uses `mainAxisExtent` scaled by `MediaQuery.textScalerOf`.
Tokens used: `SbTokens.screenPadding`, `gap8/12/16`, `rCard`, `portraitFade`, `minTouch`, `context.text.headlineMedium/bodySmall/labelMedium`. No literal colours.

## 6. Role rules

| Role | Behaviour |
|---|---|
| Owner | Everything |
| Manager | Everything (spec: "all, confirm") |
| Specialist | View only: no Upload button, no drag handles, tile opens read-only P-14. PM decision pending on "own photos only" |

Enforcement: `canManageGalleryProvider = role in {owner, manager}` (in `features/gallery/application/gallery_permissions.dart`, reading the P-01 role provider). UI hides controls; reorder, upload and update calls are additionally gated in the controllers (`assert` + early return) and the API remains authoritative (403 -> "No access" snackbar and refresh). If PM picks "own photos", filter client-side by `uploaded_by_name` is NOT reliable (name not id): raise as API gap.

## 7. Validation, confirmations, formatting

- File validation before upload: allowed `image/jpeg`, `image/png`, `image/webp` (by extension and picker mime); reject others with "Only JPEG, PNG or WebP photos". Size limit: see Gap 5; message "Photo is too large (max N MB)" built from the limit constant or API 422 `message`.
- No destructive action here (delete is P-14). Reorder failure restores order + snackbar.
- Subtitle "Specialist · Service" derived from tags via `GalleryTags.parse(tags, staffById, serviceById)`; no computation of business data. Service names require `GET /v1/partner/services` lookup (P-08 provider) if tag convention carries service UUIDs.
- No money here; dates not shown on tiles.

## 8. ARB keys (`app_en.arb`)

`galleryTitle`, `galleryUpload`, `gallerySummary` (placeholders `visible`, `total`), `gallerySummarySuffix`, `galleryFilterAll`, `galleryHidden`, `galleryTileSemantics` (`caption`, `hidden`), `galleryEmptyTitle`, `galleryEmptyBody`, `galleryErrorTitle`, `galleryRetry`, `galleryOfflineBanner`, `galleryUploadInvalidType`, `galleryUploadTooLarge` (`maxMb`), `galleryUploadProgress`, `galleryUploadFailedRetry`, `galleryUploadRateLimited`, `galleryReorderFailed`, `galleryReorderHandleSemantics`, `galleryNoAccess`, `galleryUntitled`, `galleryNoSpecialist`.

## 9. Tests

Unit (`apps/partner/test/features/gallery/`):
1. `GalleryTags` round-trips `staff:<uuid>` / `service:<uuid>`, ignores unknown tags, builds the filter tag.
2. Repository: list sends `include_hidden=true` and `tag`; parses `next_cursor`; maps 422 `ErrorResponse` to `ApiException`.
3. `GalleryController`: pages append by cursor; `loadMore` no-op when cursor null; filter change reloads; `reorder` sends one PUT with full order and rolls back on error; `removeById` and `applyUpdated` update summary counts.
4. `UploadQueueController`: rejects gif and oversize before any request; runs 3 steps in order; expired S3 URL restarts step 1 once; failure marks only that task failed; retry works; success prepends item.
Widget:
5. Loading shows skeleton; empty shows empty state with Upload for owner and none for specialist; error shows retry and calls reload.
6. Hidden pill appears only for `is_hidden`; summary text "7 of 8 photos visible" from fake data; chips filter and "All" clears.
7. Specialist: no Upload, no drag handles; tile tap opens read-only sheet.
8. Semantics: tile label equals caption; handle/button labels present; tap targets >= 44 px.
9. 200% text scale renders without overflow at 390 px.
Golden: `gallery_390.png` and `gallery_1280.png` (owner, 8 items incl. 1 hidden, local asset images, fonts via `google_fonts` allowRuntimeFetching off).

## 10. Task checklist

1. Confirm prerequisites merged (auth/role, shell, Dio interceptors); add dependencies; run `flutter pub get`.
2. Add `l10n.yaml` + ARB keys; wire `localizationsDelegates` in `app.dart`.
3. Add shared `sb_ui` widgets (`SbImageTile`, `SbPillBadge`, `SbSkeleton`, `SbEmptyState`, `SbErrorPanel`, `SbBottomSheet`) with widget tests.
4. Models + repository + tests with a fake `Dio` adapter.
5. `GalleryTags` helper (pending Gap 1 decision) + tests.
6. `GalleryController`, filter provider, summary, tests.
7. Phone screen: header, summary, chips, grid, states.
8. Pagination on scroll.
9. Upload service + queue + picker integration; tile progress/retry UI.
10. Web layout (>= 900 px), reorder drag, side panel hook for P-14.
11. Role gating, offline banner.
12. Goldens 390/1280, a11y and text-scale tests.
13. `flutter analyze` clean, `flutter test` green.

## 11. Open questions / gaps / risks

- Gap 1 (blocking for chips): `GalleryItemOut` has no `staff_id`/`service_id`; only `tags` strings and `GET gallery?tag=` (maxLength 50, so `staff:<uuid>` = 42 chars fits, `service:<uuid>` = 44 fits). Plan assumes the `staff:<uuid>` / `service:<uuid>` convention behind `GalleryTags` so a later structured field swap touches one file. Web "Book this look" depends on this.
- Gallery endpoints in `openapi.json` declare no 401/403 responses (orders do); specialist role enforcement by the API is unspecified.
- `total_count` semantics (all vs visible) unknown; summary label needs it.
- Max upload size / count not in OpenAPI; `SettingsUpdateIn.max_upload_size_mb` exists on the admin side only. Ask backend to expose it in `/v1/partner/settings` or document 422 codes.
- Reorder with an active filter or partial pages: the API takes a list of `{image_id, sort_order}`; sending only loaded items could collide with unloaded ones. Plan: reorder only with no filter and all pages loaded (auto-load remaining pages on first drag) or ask backend to confirm partial semantics.
- Reorder on phone is not in the design (web only).
- Packages: Flutter has no native grid reorder; `reorderable_grid_view` is a new dependency.
- Riverpod 3 is in pubspec (project docs say 2); `AsyncNotifier` API is the same, but mocks/overrides syntax differs slightly. Confirm.
- Specialist "own photos" rule undecidable client-side (`uploaded_by_name` only).
- Cover rule when hidden: API behaviour unknown (see P-14).
