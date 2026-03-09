/// Centralized registry of languages supported by Aurora Music.
///
/// ## How to add a new language (for community translators)
///
/// 1. Create `lib/l10n/app_<code>.arb` (e.g. `app_de.arb`) by copying
///    `app_en.arb` and translating every value.
///
/// 2. Run the code generator once:
///    ```
///    flutter gen-l10n
///    ```
///    This will produce `lib/l10n/generated/app_localizations_<code>.dart`
///    and automatically register the locale inside the generated
///    `AppLocalizations.supportedLocales` list.
///
/// 3. Add **one entry** to [SupportedLanguages.all] below – that is the only
///    hand-written change needed.
///
/// Everything else (settings dropdown, onboarding language picker, locale
/// resolution) derives its data from this single list.

/// Metadata for a single locale that Aurora Music ships.
class SupportedLanguage {
  /// BCP-47 language tag (matches the ARB filename suffix, e.g. `'de'`).
  final String code;

  /// The language name as it appears in its own script ("Deutsch", "Čeština").
  final String nativeName;

  /// The language name in English ("German", "Czech").
  final String englishName;

  const SupportedLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}

/// Registry of every language that has an ARB translation file.
///
/// Add a new [SupportedLanguage] entry here whenever you add a new
/// `lib/l10n/app_<code>.arb` file and re-run `flutter gen-l10n`.
class SupportedLanguages {
  SupportedLanguages._();

  static const List<SupportedLanguage> all = [
    SupportedLanguage(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
    ),
    SupportedLanguage(
      code: 'cs',
      nativeName: 'Čeština',
      englishName: 'Czech',
    ),
    // ---------------------------------------------------------------------------
    // Community translations – add new entries below this line.
    // Example:
    // SupportedLanguage(
    //   code: 'de',
    //   nativeName: 'Deutsch',
    //   englishName: 'German',
    // ),
    // ---------------------------------------------------------------------------
  ];

  /// Returns the [SupportedLanguage] whose [code] matches [languageCode],
  /// or `null` if no match is found.
  static SupportedLanguage? forCode(String languageCode) =>
      all.where((lang) => lang.code == languageCode).firstOrNull;

  /// Returns the native name for the given [languageCode], falling back to
  /// the upper-cased code if the language is not yet listed.
  static String nativeNameFor(String languageCode) =>
      forCode(languageCode)?.nativeName ?? languageCode.toUpperCase();
}
