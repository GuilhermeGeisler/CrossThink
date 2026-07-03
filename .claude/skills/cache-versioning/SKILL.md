---
name: cache-versioning
description: Cache file format versioning for the .crosspoint/ SD card cache. Use when modifying any cached data structure (book.bin, section.bin, progress.bin, settings.json, state.json, recent.json, opds.json, wifi.json, crosspet.json). Covers version increment rules, binary-to-JSON migration, backward compatibility, and the invalidation cascade.
---

# Cache Versioning

The firmware caches aggressively to SD card to minimize RAM usage and speed up
repeated reads. Cache files live in `.crosspoint/` and have versioned binary
formats. Getting versioning wrong silently corrupts user data.

## Cache structure

```
.crosspoint/
├── epub_<hash>/          # per-book cache (hash = std::hash of filepath)
│   ├── book.bin          # metadata (title, author, spine, TOC) — VERSION 7
│   ├── progress.bin      # reading position — VERSION 3
│   ├── cover.bmp         # generated cover image
│   ├── css_rules.cache   # parsed CSS rules
│   ├── img_*             # rendered image cache
│   └── sections/         # per-chapter layout cache — VERSION 25
│       ├── 0.bin
│       └── ...
├── settings.json         # device settings (migrated from .bin)
├── state.json            # runtime state (migrated from .bin)
├── recent.json           # recent books (migrated from .bin)
├── wifi.json             # WiFi credentials (migrated from .bin)
├── opds.json             # OPDS servers (migrated from .bin)
└── crosspet.json         # CrossPet-specific settings
```

## The golden rule

**Increment the version number BEFORE changing the binary structure.**

A version mismatch auto-invalidates the cache and triggers regeneration. If you
change the struct without bumping the version, the old file is read with the new
code and fields are silently misinterpreted.

```cpp
// lib/Epub/Epub/Section.cpp
static constexpr uint8_t SECTION_FILE_VERSION = 26;  // was 25, now 26

// Add new field
struct PageLine {
  // ... existing fields ...
  uint16_t newField;  // NEW
};
```

## Version increment procedure

1. **Identify the file format** — check `docs/file-formats.md` for current version.
2. **Increment the version constant** in the source file (e.g., `SECTION_FILE_VERSION`).
3. **Update `docs/file-formats.md`** with the new version and what changed.
4. **Add migration code** if backward compatibility is needed (read old format,
   write new format).

## Binary format pattern

```cpp
bool loadFromBinaryFile() {
  HalFile file;
  if (!Storage.openFileForRead("MOD", CACHE_PATH, file)) return false;

  uint8_t version;
  serialization::readPod(file, version);
  if (version > CURRENT_VERSION) {
    LOG_ERR("MOD", "Unknown version %u", version);
    return false;  // will regenerate
  }

  // Read fields, branching on version for new fields
  serialization::readPod(file, field1);
  if (version >= 2) {
    serialization::readPod(file, field2);  // added in v2
  }
  if (version >= 3) {
    serialization::readPod(file, field3);  // added in v3
  }
  return true;
}
```

## JSON migration pattern

Settings files migrated from binary to JSON follow this pattern:

```cpp
bool loadFromFile() {
  // Try JSON first
  if (Storage.exists(JSON_PATH)) {
    String json = Storage.readFile(JSON_PATH);
    if (!json.isEmpty()) {
      return loadFromJson(json.c_str());
    }
  }

  // Fall back to binary migration
  if (Storage.exists(BIN_PATH)) {
    if (loadFromBinaryFile()) {
      saveToFile();  // write JSON
      Storage.rename(BIN_PATH, BAK_PATH);  // keep backup
      LOG_DBG("MOD", "Migrated .bin to .json");
      return true;
    }
  }
  return false;
}
```

## Invalidation cascade

Cache invalidation triggers:

| Trigger | What invalidates |
|---------|-----------------|
| File format version bump | That specific file type |
| Font family/size change | All `sections/*.bin` (layout depends on font metrics) |
| Screen orientation change | All `sections/*.bin` (layout depends on viewport) |
| Margin/spacing change | All `sections/*.bin` |
| Book file moved/renamed | Entire `epub_<hash>/` (new hash = new cache dir) |

## Self-review

- [ ] Version constant incremented BEFORE struct change.
- [ ] `docs/file-formats.md` updated with new version and changes.
- [ ] Migration code handles old versions gracefully (no crash on old files).
- [ ] JSON migration keeps `.bak` backup of old binary file.
- [ ] Tested: delete `.crosspoint/` and verify clean regeneration.
