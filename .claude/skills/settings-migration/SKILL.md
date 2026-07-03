---
name: settings-migration
description: Settings and state migration patterns for persistent data. Use when adding, removing, or renaming settings fields, changing default values, or migrating from binary to JSON format. Covers the needsResave flag, obfuscation for passwords, backward-compatible field addition, legacy enum migration, and the save/load contract.
---

# Settings Migration

Settings are persisted to SD card and must survive firmware updates. Users
should never lose their configuration when upgrading. The migration code is
defensive: it handles missing fields, old formats, and corrupt files gracefully.

## The save/load contract

```cpp
bool saveToFile() const;   // write current state to disk
bool loadFromFile();       // read state from disk, migrate if needed
```

**Invariant:** `loadFromFile` must succeed even if the file was written by an
older firmware version. Missing fields get struct-initializer defaults.

## Adding a new field

1. **Add the field to the struct** with a sensible default:

```cpp
class CrossPointSettings {
  // ... existing fields ...
  uint8_t newFeatureEnabled = 0;  // new field, default off
};
```

2. **Add to `SettingsList.h`** with a JSON key:

```cpp
SettingInfo::Toggle(StrId::STR_NEW_FEATURE, &CrossPointSettings::newFeatureEnabled,
                    "newFeatureEnabled", StrId::STR_CAT_READER),
```

3. **Done.** The generic save/load loop in `JsonSettingsIO` picks it up
   automatically. Old files without the key get the struct default.

## The needsResave flag

When loading detects a legacy format that should be rewritten:

```cpp
bool JsonSettingsIO::loadSettings(CrossPointSettings& s, const char* json,
                                  bool* needsResave) {
  if (needsResave) *needsResave = false;

  // ... load fields ...

  // Legacy migration: old field name
  if (doc["oldFieldName"].isNull() && !doc["legacyFieldName"].isNull()) {
    s.newFieldName = doc["legacyFieldName"] | defaultValue;
    if (needsResave) *needsResave = true;  // flag for resave
  }

  return true;
}

// Caller checks the flag:
bool CrossPointSettings::loadFromFile() {
  bool resave = false;
  bool result = JsonSettingsIO::loadSettings(*this, json.c_str(), &resave);
  if (result && resave) {
    saveToFile();  // rewrite with migrated format
  }
  return result;
}
```

## Obfuscation for passwords

Passwords are XOR-obfuscated with the device's MAC address and base64-encoded:

```cpp
// Save
doc["password_obf"] = obfuscation::obfuscateToBase64(plaintext);

// Load
bool ok = false;
std::string password = obfuscation::deobfuscateFromBase64(
    doc["password_obf"] | "", &ok);
if (!ok || password.empty()) {
  // Fallback to plaintext for old files
  password = doc["password"] | std::string("");
  if (!password.empty() && needsResave) *needsResave = true;
}
```

**Never** store passwords in plaintext. The obfuscation is not cryptographically
secure (it's XOR with a device-unique key), but it prevents casual reading and
ties credentials to the specific device.

## Binary-to-JSON migration

Legacy binary files are migrated to JSON on first load:

```cpp
bool loadFromFile() {
  // Try JSON first
  if (Storage.exists(JSON_PATH)) {
    String json = Storage.readFile(JSON_PATH);
    if (!json.isEmpty()) {
      bool resave = false;
      bool result = loadFromJson(json.c_str(), &resave);
      if (result && resave) saveToFile();
      return result;
    }
  }

  // Fall back to binary migration
  if (Storage.exists(BIN_PATH)) {
    if (loadFromBinaryFile()) {
      saveToFile();  // write JSON
      Storage.rename(BIN_PATH, BAK_PATH);  // keep .bak backup
      LOG_DBG("MOD", "Migrated .bin to .json");
      return true;
    }
  }
  return false;
}
```

**Keep the `.bak` file** — if the JSON write fails (SD card full), the user
can recover by renaming `.bak` back to `.bin`.

## Enum migration

When adding a new enum value, append at the END to preserve stored indices:

```cpp
enum LONG_PRESS_MENU_FUNCTION {
  LP_MENU_KOSYNC = 0,
  LP_MENU_DISABLED = 1,
  LP_MENU_BOOKMARK = 2,
  // NEW VALUES GO HERE, not in the middle
  LP_MENU_DICTIONARY = 3,  // added later
  LONG_PRESS_MENU_FUNCTION_COUNT
};
```

If you insert in the middle, existing saved indices shift and users' settings
are silently misinterpreted.

## String fields (char arrays)

For fixed-length string fields in `CrossPointSettings`:

```cpp
class CrossPointSettings {
  char opdsServerUrl[128] = "";
  char sdFontFamilyName[32] = "";
};
```

In `SettingsList.h`, use `SettingInfo::String` with offset and max length:

```cpp
SettingInfo::String(StrId::STR_OPDS_URL, SETTINGS.opdsServerUrl,
                    sizeof(SETTINGS.opdsServerUrl), "opdsServerUrl",
                    StrId::STR_CAT_SYSTEM),
```

The generic loop handles `strncpy` with proper null-termination.

## Self-review

- [ ] New field has a sensible default in the struct initializer.
- [ ] New field added to `SettingsList.h` with a JSON key.
- [ ] Legacy migrations set `needsResave = true`.
- [ ] Passwords use `obfuscateToBase64` / `deobfuscateFromBase64`.
- [ ] New enum values appended at the END, not inserted.
- [ ] Binary migration keeps `.bak` backup.
- [ ] Tested: delete `.json`, verify `.bin` migration works.
