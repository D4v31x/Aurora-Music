# Contributing Translations to Aurora Music

Thank you for helping translate Aurora Music! This guide walks you through everything you need to add a new language.

## Prerequisites

- Flutter SDK installed (any stable version)
- A fork/clone of the repository

---

## Step 1 – Create the translation file

Copy the English template and name it after the [BCP-47 language tag](https://en.wikipedia.org/wiki/IETF_language_tag) for your target language (e.g. `de` for German, `fr` for French, `pt_BR` for Brazilian Portuguese):

```bash
cp lib/l10n/app_en.arb lib/l10n/app_<code>.arb
```

Open the new file and translate every **value** while keeping every **key** unchanged:

```json
{
  "@@locale": "de",
  "songs": "Lieder",
  "settings": "Einstellungen"
}
```

> **Tips**
> - Keep `@@locale` matching the language code.
> - Do **not** rename keys – only translate the values.
> - Placeholders like `{count}` or `{name}` must stay exactly as they are.
> - If you are unsure about a translation, look at `app_cs.arb` for reference.

---

## Step 2 – Regenerate the Dart files

Run the code generator once from the project root:

```bash
flutter gen-l10n
```

This produces `lib/l10n/generated/app_localizations_<code>.dart` and automatically registers your locale inside `AppLocalizations.supportedLocales` — no other generated files need editing.

---

## Step 3 – Register the language (the only manual step)

Open **`lib/l10n/supported_languages.dart`** and add one entry to the `all` list:

```dart
// inside SupportedLanguages.all
SupportedLanguage(
  code: 'de',            // must match the ARB file suffix
  nativeName: 'Deutsch', // name in the target language itself
  englishName: 'German', // name in English
),
```

That's it! The language picker in the onboarding flow and the Settings dropdown will automatically show your new language once this entry is added.

---

## Step 4 – (Optional) Add a welcome greeting

The onboarding welcome screen cycles through "Welcome to Aurora Music" in every supported language as a decorative animation. To add your language, open **`lib/features/onboarding/pages/welcome_page.dart`** and append an entry to `_welcomeTexts`:

```dart
{
  'title': 'Willkommen bei Aurora Music',
  'subtitle': 'Lass uns dein Erlebnis einrichten',
},
```

---

## Step 5 – Open a Pull Request

Push your branch and open a PR with:
- The new `lib/l10n/app_<code>.arb` file
- The regenerated `lib/l10n/generated/app_localizations_<code>.dart`  
  *(commit the generated file so reviewers can check translations without running the generator)*
- Your one-line addition to `SupportedLanguages.all` in `lib/l10n/supported_languages.dart`
- (Optional) the welcome greeting in `welcome_page.dart`

---

## Keeping translations up to date

When new strings are added to the English template (`app_en.arb`), your translation file will be missing those keys. The generator will use the English fallback automatically, so the app won't crash — but please open a follow-up PR to translate the new strings.

---

## Need help?

Open a [GitHub Discussion](https://github.com/D4v31x/Aurora-Music/discussions) or reach out via our community channels. We appreciate every contribution!
