# Program Cover Image — Design

**Issue:** #196 — Cover image does not display on program card or detail page
**Date:** 2026-03-03

## Problem

The `cover_image_url` field exists end-to-end (domain model, Ecto schema, read model, persistence mapper) and the upload pipeline in the provider dashboard works. But:

1. `programs_live.ex` `program_to_map/2` omits `cover_image_url` from the UI map
2. `program_components.ex` `program_card` renders gradient+icon, never an `<img>`
3. `program_detail_live.ex` hero section uses `Theme.gradient(:hero)`, never an `<img>`
4. Upload error handling silently discards failures (logs warning, saves without image, no user feedback)

## Scope

Full end-to-end: fix upload error UX, wire display in cards and detail page, add tests.

## Design

### 1. Upload Error Handling

**Current flow** in `save_program/2` (dashboard_live.ex:689):
- `:upload_error` → flash error, abort save entirely
- `{:ok, url}` → include in attrs
- `:no_upload` → proceed without image

**New flow** (user preference: flash warning, save anyway):
- `:upload_error` → proceed to save without image, add warning flash after save succeeds
- `{:ok, url}` → include in attrs (unchanged)
- `:no_upload` → proceed without image (unchanged)

Implementation: remove the early `:upload_error` abort from the case statement. Let all results flow through `maybe_add_cover_image/2`. Track whether cover failed via a separate assign or return value, then append a warning flash after successful program save.

### 2. Program Card Display

**File:** `program_components.ex` — `program_card` component

Add optional `cover_image_url` to the program map. In the card header (`h-48` div):

- **When `cover_image_url` present:** Render `<img src={url} class="w-full h-full object-cover" />` filling the header. No icon overlay. Category badge, ONLINE badge, and spots badge remain as absolute-positioned overlays.
- **When absent:** Keep current gradient + centered icon fallback (no change).

**File:** `programs_live.ex` — `program_to_map/2`

Add `cover_image_url: program.cover_image_url` to the returned map.

### 3. Program Detail Hero

**File:** `program_detail_live.ex` — hero section (line 163)

- **When `cover_image_url` present:** Render `<img>` with `object-cover` as the hero background. Apply a subtle bottom-up gradient overlay (`bg-gradient-to-t from-black/60 to-transparent`) for white text readability. Navigation, title, schedule, badges remain as overlays.
- **When absent:** Keep current `Theme.gradient(:hero)` fallback (no change).

### 4. Tests

- Program card: verify `<img>` renders when `cover_image_url` present, verify gradient fallback when nil
- Program detail: verify `<img>` in hero when `cover_image_url` present, verify gradient when nil
- Provider dashboard: verify upload error produces warning flash and program still saves
