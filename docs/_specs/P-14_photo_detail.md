# P-14 Photo detail

## 1. Goal and roles
Bottom sheet (phone) or side panel (web) to edit one gallery photo: specialist (and service) tags, show on salon page toggle, delete with confirmation.
- Owner and Manager: edit and delete (Manager delete: PM to confirm). Specialist: view only.

## 2. User stories
US-P-28 (PTN-13, edit tags and visibility), US-P-29 (BR-14, delete after confirm).

## 3. Layout
- Ref: `mobile/P-14_photo_detail.png`, `P-14_photo_delete_confirm.png`. Sheet with handle, large rounded image with caption overlay, "Done by" chips (single select, selected amber), "Show on salon page" toggle (green), outlined red "Delete photo" button. Delete step replaces button text with prompt "Delete this photo? It disappears from your salon page." and button "Yes, delete photo" (danger).
- Phone: bottom sheet over the gallery (grid dimmed). Web: right-side panel, delete confirm in a dialog.
- sb_ui: bottom sheet, chip, switch, outlined danger button, confirm.
- Design shows no service selector or caption field; instructions require tagging specialist and service (add per Gap 1).

## 4. Data and API map
| UI element | Endpoint | Fields | Errors |
|---|---|---|---|
| Open | data from P-13 list item (`GalleryItemOut`) | `image_url`, `caption`, `tags`, `is_hidden`, `is_cover` | |
| Done by / tags / caption | PUT `/v1/partner/gallery/{image_id}` | `UpdateIn`: `caption`, `tags[]`, `sort_order` | 404, 422 |
| Show on salon page | PUT `/v1/partner/gallery/{image_id}` | `UpdateIn.is_hidden` (toggle ON = `is_hidden=false`) | 404 |
| Set as cover | POST `/v1/partner/gallery/{image_id}/cover` | `CoverOut` | 404 |
| Delete | DELETE `/v1/partner/gallery/{image_id}` | `DeleteIn.confirm=true`; 204 | 404, 409 |

## 5. Acceptance criteria
1. Given a photo is opened, then current specialist chip and toggle reflect API values.
2. When the toggle changes, then PUT `is_hidden` is sent immediately, toggle shows pending state, reverts with a toast on failure, and the P-13 grid and "N of M visible" summary update.
3. When another "Done by" chip is tapped, then the tag is updated by PUT and the tile subtitle in P-13 changes.
4. When "Delete photo" is tapped, then no request is sent; the button becomes confirm state ("Yes, delete photo", red `danger`) and a prompt shows; tapping outside or Back cancels.
5. When confirm is tapped, DELETE with `confirm=true` is sent; on 204 the sheet closes, tile removed, toast "Photo deleted".
6. Given a delete failure (404 already deleted or 409), show message and refresh the grid.
7. Specialist sees no toggle, chips or delete.
8. Delete button is 44 px or higher and the toggle has a Semantics label "Show on salon page".

## 6. States
Saving: inline spinner on the changed control. Error: toast, revert. Offline: controls disabled. Deleting: button spinner, sheet not dismissible. Real-time: n/a.

## 7. Rules and edge cases
- Deletion is permanent (hard delete, audited) so the confirmation is mandatory and the warning text must say so; design text "It disappears from your salon page" is incomplete.
- Deleting the cover: warn and refresh cover state (API behaviour unknown).
- Hidden photos remain editable.
- Last-write wins on concurrent edits; refresh grid after each success.

## 8. Gaps and questions
1. Same as P-13 Gap 1: no structured staff/service tag; chips map to `tags` only by convention.
2. `DeleteIn.confirm` is optional (default?) with no `reason`; instructions require reasons only for decline and stock, so none needed. Confirm that 204 with `confirm=false` is rejected.
3. Delete wording: confirm text does not state permanence.
4. Cover and service selection and caption editing missing in the design.
5. Behaviour when deleting the cover photo is undocumented.
