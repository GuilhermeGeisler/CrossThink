---
name: i18n-workflow
description: Internationalization workflow for the firmware's 24-language UI. Use when adding user-facing strings, modifying translations, or debugging missing translations. Covers the tr() macro, YAML source files, the gen_i18n.py generator, StrId enum, fallback to English, and the commit-only-YAML rule.
---

# i18n Workflow

The firmware supports 24 UI languages. All user-facing text goes through the
`tr()` macro and `StrId` enum. Hardcoded strings in UI code are a bug.

## The pipeline

```
YAML files (source of truth)
    ↓ scripts/gen_i18n.py
I18nKeys.h (StrId enum)
I18nStrings.h (declarations)
I18nStrings.cpp (string tables)
    ↓ build
firmware
```

**Generated files are in `.gitignore`.** Never edit them directly. Edit the
YAML source files in `lib/I18n/translations/`.

## Adding a new string

1. **Add the key to `english.yaml`** (the reference language):

```yaml
# lib/I18n/translations/english.yaml
STR_NEW_FEATURE: "New Feature"
STR_NEW_FEATURE_DESC: "Enable the new feature"
```

2. **Run the generator:**

```bash
python scripts/gen_i18n.py lib/I18n/translations lib/I18n/
```

This updates `I18nKeys.h`, `I18nStrings.h`, and `I18nStrings.cpp`.

3. **Use the string in code:**

```cpp
#include <I18n.h>

renderer.drawText(font, x, y, tr(STR_NEW_FEATURE));
```

4. **Commit only the YAML files.** The generated headers are rebuilt by the
   build system.

## The tr() macro

`tr(STR_ID)` expands to `I18n::getInstance().get(StrId::STR_ID)`. It returns
a `const char*` for the current language, falling back to English if the key
is missing in the active language.

```cpp
// Correct
renderer.drawText(font, x, y, tr(STR_LOADING));

// Wrong — hardcoded string
renderer.drawText(font, x, y, "Loading...");
```

## YAML file structure

Each language file has:

```yaml
_language_name: "English"      # display name in language picker
_language_code: "EN"            # ISO code (2-3 chars)
_order: 0                       # sort order in language picker

STR_LOADING: "Loading..."
STR_ERROR: "Error"
# ... all STR_* keys
```

**English is the reference.** Other languages can omit keys — missing keys
fall back to English. This allows partial translations.

## Formatting strings

For strings with parameters, use `snprintf` with a stack buffer:

```cpp
char buf[64];
snprintf(buf, sizeof(buf), tr(STR_PAGE_X_OF_Y), currentPage, totalPages);
renderer.drawText(font, x, y, buf);
```

**Do not** use `std::string` concatenation or `String` formatting on hot paths.

## What needs tr()

| Needs tr() | Does not need tr() |
|------------|-------------------|
| UI labels, buttons, menus | `LOG_DBG` / `LOG_ERR` messages |
| Error messages shown to user | Internal debug strings |
| Settings names and values | File paths |
| Help text, tooltips | Code comments |

## Adding a new language

1. Copy `english.yaml` to `<language>.yaml`.
2. Update `_language_name`, `_language_code`, and `_order`.
3. Translate all `STR_*` values.
4. Run `gen_i18n.py` and verify the language appears in the picker.

**Note:** some languages need custom character sets for the font system.
Check `I18n::getCharacterSet(Language)` for the glyph coverage required.

## Debugging missing translations

If a string shows as the English fallback:

1. Check the key exists in the target language's YAML.
2. Verify the key name matches exactly (case-sensitive).
3. Re-run `gen_i18n.py` and rebuild.
4. Check `I18nStrings.cpp` to confirm the translation is compiled in.

## Self-review

- [ ] No hardcoded user-facing strings in UI code.
- [ ] New `STR_*` keys added to `english.yaml` first.
- [ ] `gen_i18n.py` run after YAML changes.
- [ ] Only YAML files committed (not generated headers).
- [ ] `snprintf` used for parameterized strings, not `std::string` concat.
