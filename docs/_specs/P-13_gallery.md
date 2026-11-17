# P-13 Gallery

## 1. Goal and roles
Manage salon photos shown on the salon page in the client app and used for "Book this look": upload, tag specialist and service, hide/show, set cover, filter by specialist.
- Owner: all. Manager: all (confirm). Specialist: view only (or own photos; PM to decide).

## 2. User stories
US-P-28 (PTN-13); US-P-29 deletion in P-14.

## 3. Layout
- Ref: `mobile/P-13_gallery.png`. Title "Gallery", black "+ Upload" pill top-right; summary "7 of 8 photos visible · shown under your salon in the client app"; filter chips All / Kasun / Dilan / Ishara / Sachini (selected black); 2-column tile grid, rounded images with dark gradient and white caption "Title" + "Specialist · Service"; hidden photos show a "Hidden" pill.
- Phone: 2 columns, floating nav (Gallery selected). Web/tablet: 4-5 column grid; drag handles to reorder; tapping a tile opens P-14 as side panel (web) or bottom sheet (phone).
- sb_ui: filter chips, image tile, pill badge, black pill, bottom sheet.

## 4. Data and API map
| UI element | Endpoint | Fields | Errors |
|---|---|---|---|
| Grid | GET `/v1/partner/gallery` (`include_hidden=true`, `tag`, `cursor`, `limit`) | `GalleryListOut`: `items[]: GalleryItemOut` (`id`, `image_url`, `thumbnail_url`, `caption`, `tags[]`, `is_cover`, `is_hidden`, `sort_order`, `uploaded_by_name`), `total_count`, `next_cursor` | 429, 500 |
| Counter "7 of 8 visible" | same | `total_count`, count of `is_hidden=false` (loaded items) | |
| Specialist chips | GET `/v1/partner/staff` | `full_name` (first name shown), `id` | |
| Filter | GET gallery with `tag` | see Gap 1 | |
| Upload step 1 | POST `/v1/partner/gallery/upload-url` | `UploadUrlIn`: `filename`, `content_type`, `file_size_bytes` -> `UploadUrlOut`: `upload_url`, `object_key`, `image_id`, `expires_in_seconds` | 422 (type/size), 429 |
| Upload step 2 | PUT binary to `upload_url` (S3, not API) | | expired URL -> redo step 1 |
| Upload step 3 | POST `/v1/partner/gallery/{image_id}/confirm` | `ConfirmIn`: `caption`, `tags[]`, `sort_order` -> 201 `GalleryItemOut` | 404, 409 |
| Reorder (web) | PUT `/v1/partner/gallery/reorder` | `ReorderIn.order[]: ReorderItem` (`image_id`, `sort_order`) | 422 |
| Cover | POST `/v1/partner/gallery/{image_id}/cover` | `CoverOut`: `is_cover`, `previous_cover_id` | 404 |

## 5. Acceptance criteria
1. Given the page loads, then all photos including hidden ones show (include_hidden=true), hidden ones have a "Hidden" pill.
2. Summary text uses counts from API data, not stored locally.
3. When a specialist chip is tapped, then only photos tagged with that specialist show; All clears the filter.
4. When "+ Upload" is tapped, the user picks one or more images (image_picker on phone, file_picker on web); jpeg/png/webp only; oversize files rejected before upload with message.
5. Given upload steps 1-3, each file shows progress; on failure shows retry on that tile only; successful photos appear at the top and in P-14 can be tagged.
6. Tile caption shows `caption` and "Specialist · Service" derived from `tags` (convention in Gap 1).
7. Pagination: more tiles load by `next_cursor` on scroll.
8. Reorder drag on web sends one PUT reorder with the full new order; failure restores previous order.
9. Specialist role sees no Upload button and tiles open read-only.
10. Image tiles have alt/semantic labels (caption).

## 6. States
Loading: grey tile skeletons. Empty: "No photos yet. Photos you add show on your salon page" + black Upload. Error: retry panel. Offline: cached tiles via cached_network_image, upload and edits disabled. Uploading: tile with progress. Real-time: none required.

## 7. Rules and edge cases
- Hidden photos do not appear in the client app; the cover photo cannot be hidden without warning (Gap 3).
- Upload only after confirm: unconfirmed images are not shown (orphan image_ids expire).
- Max count/size limits come from API 422 messages.
- Gallery photos are not copied between staff (see P-10).

## 8. Gaps and questions
1. No structured specialist or service on `GalleryItemOut`: only free `caption` and `tags[]` (strings). The design needs specialist and service tags plus a filter by specialist. Proposal: add `staff_id`, `service_id` (and names) to confirm/update/list plus `staff_id` filter; or define a tag convention (`staff:<uuid>`, `service:<uuid>`). PM/BE to decide. "Book this look" depends on service linkage.
2. Staff detail has `portfolio_images` (`PortfolioItemOut`); relation to salon gallery unclear.
3. Cover: no UI in design; the API has a cover endpoint. Proposal: "Set as cover" in P-14. Unknown rule if cover is hidden.
4. Caption title ("Low skin fade") vs specialist/service subtitle: the title is `caption`.
5. Allowed content types and size limits not documented in the spec.
6. `total_count` semantic (all vs visible) not defined; needed for "7 of 8".
