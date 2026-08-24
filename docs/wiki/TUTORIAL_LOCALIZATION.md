# Tutorial Localization

Last checked: 2026-08-24

## Current contract

- `TutorialLanguageState` observes the local player's Roblox translator locale. The saved
  preference defaults to `auto`; the Settings menu can force `en` (English), and that choice is
  persisted in `Settings.ClientPrefs.tutorialLanguage`.
- The tutorial currently has explicit Spanish and Brazilian Portuguese catalogs. Roblox locale
  variants such as `es-MX` and `pt-PT` resolve into those catalogs. Every other locale keeps the
  authored English config copy, so missing translations can never blank or expose a key.
- Tutorial config entries publish stable `localization_key` values. `TutorialFlow` includes the
  derived title/body keys in client state while retaining raw English title/body fields as the
  compatibility fallback.
- In Auto mode, a supported non-English player receives one session banner naming the detected
  language and explaining that the tutorial can be changed to English in Settings. The banner
  deliberately says **tutorial**, because the rest of the game has not yet been claimed as fully
  localized.

## Extending coverage

Add a locale catalog to `src/Shared/Game/TutorialLocalization.lua`, update `languageFor` and
`DISPLAY_NAMES`, and add coverage to `tests/headless/specs/tutorial_localization.spec.luau`.
Do not translate only the visible current step: every authored tutorial key must exist before a
language is advertised as supported.
