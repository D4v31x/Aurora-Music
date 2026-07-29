// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get aboutArtist => 'Über den Künstler';

  @override
  String get add => 'Hinzufügen';

  @override
  String get addedToPlaylist => 'Zur Wiedergabeliste hinzugefügt';

  @override
  String addedToNamedPlaylist(String name) {
    return 'Zu $name hinzugefügt';
  }

  @override
  String get addExclusion => 'Ausschluss hinzufügen';

  @override
  String get addSeparator => 'Trennzeichen hinzufügen';

  @override
  String get addSongs => 'Songs hinzufügen';

  @override
  String get addSongsToPlaylist => 'Titel zur Wiedergabeliste hinzufügen';

  @override
  String get addToPlaylist => 'Zur Wiedergabeliste hinzufügen';

  @override
  String get adjustSync => 'Synchronisierung anpassen';

  @override
  String get album => 'Album';

  @override
  String get albums => 'Alben';

  @override
  String get allSongs => 'Alle Songs';

  @override
  String get appName => 'Aurora Music';

  @override
  String get artist => 'Künstler';

  @override
  String get artistName => 'Künstlername';

  @override
  String get artists => 'Künstler';

  @override
  String get artistSeparation => 'Trennung der Künstler';

  @override
  String get artistSeparationDesc =>
      'Konfigurieren Sie, wie mehrere Interpreten aufgeteilt werden';

  @override
  String get audioQuality => 'Audioqualität';

  @override
  String get audioQualityDesc => 'Technische Daten der Audiodatei';

  @override
  String get auroraMusic => 'Aurora Music';

  @override
  String get autoPlaylists => 'Automatische Wiedergabelisten';

  @override
  String get autoTag => 'Auto-Tag';

  @override
  String get smartPlaylists => 'Intelligente Wiedergabelisten';

  @override
  String get createSmartPlaylist => 'Intelligente Wiedergabeliste erstellen…';

  @override
  String get editSmartPlaylist => 'Intelligente Wiedergabeliste bearbeiten';

  @override
  String get smartPlaylistNameHint => 'Name der Wiedergabeliste';

  @override
  String get smartPlaylistRules => 'Regeln';

  @override
  String get addRule => 'Regel hinzufügen';

  @override
  String get saveSmartPlaylist => 'Speichern';

  @override
  String get matchAll => 'Alle Regeln erfüllen';

  @override
  String get matchAny => 'Regel „BELIEBIG“';

  @override
  String get limitResultsLabel => 'Ergebnisse einschränken';

  @override
  String get noLimit => 'Keine Begrenzung';

  @override
  String get deleteSmartPlaylistConfirm =>
      'Diese intelligente Wiedergabeliste löschen? Dadurch werden lediglich die gespeicherten Regeln entfernt – deine Titel bleiben davon unberührt.';

  @override
  String smartPlaylistPreviewCount(int count) {
    return 'Es werden derzeit $count Titel angezeigt';
  }

  @override
  String get saveAsClip => 'Als Clip speichern';

  @override
  String get generatingClip => 'Clip wird erstellt…';

  @override
  String get clipDuration => 'Dauer des Clips';

  @override
  String get clipStartOffset => 'Ausgangspunkt';

  @override
  String get saveClip => 'Clip speichern';

  @override
  String get clipSavedToDevice => 'Clip auf dem Gerät gespeichert';

  @override
  String get clipSaveFailed =>
      'Der Clip konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get playlistSavedToDevice => 'Playlist auf dem Gerät gespeichert';

  @override
  String get trackTags => 'Track-Tags';

  @override
  String get editTrackTags => 'Tags bearbeiten';

  @override
  String get addTrackTag => 'Tag hinzufügen';

  @override
  String get noTrackTagsYet =>
      'Noch keine Tags. Füge einen hinzu, um direkt zu einem bestimmten Abschnitt dieses Titels zu springen.';

  @override
  String get trackTagNameHint => 'z. B. Songtitel oder Interpret';

  @override
  String get trackTagPosition => 'Position';

  @override
  String get useCurrentPosition => 'Aktuelle Position verwenden';

  @override
  String get isThisASet => 'Zeitstempel zu diesem Titel hinzufügen';

  @override
  String get tagPartsForEasySwitching =>
      'Markieren Sie jeden beliebigen Moment – Kapitel, Höhepunkte, Lesezeichen oder was auch immer.';

  @override
  String get tagThisTrack => 'Tags hinzufügen';

  @override
  String get pasteSetlist => 'Zeitstempel importieren';

  @override
  String get pasteSetlistDialogTitle => 'Zeitstempel importieren';

  @override
  String get pasteSetlistHint =>
      'Fügen Sie hier Zeitstempel ein, z. B.\n0:00 Intro\n3:45 Kapitelbezeichnung';

  @override
  String get importAction => 'Importieren';

  @override
  String tagsImportedMessage(int count) {
    return 'Importierte $count-Tags';
  }

  @override
  String get noTagsFoundInPaste =>
      'Im eingefügten Text wurden keine Zeitstempel gefunden.';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get buyMeCoffee => 'Lade mir einen Kaffee ein';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get coffeeSupport => 'Unterstützung bei einem Kaffee';

  @override
  String get composer => 'Komponist';

  @override
  String get connectWithUs => 'Bleiben Sie mit uns in Kontakt';

  @override
  String get copied => 'Kopiert';

  @override
  String get copy => 'Kopieren';

  @override
  String get create => 'Erstellen';

  @override
  String get createFirstPlaylist =>
      'Tippe auf die Schaltfläche oben, um deine erste Wiedergabeliste zu erstellen';

  @override
  String get createPlaylist => 'Playlist erstellen';

  @override
  String get darkMode => 'Dunkler Modus';

  @override
  String get dateAdded => 'Hinzugefügt am';

  @override
  String get dateModified => 'Änderungsdatum';

  @override
  String get delete => 'Löschen';

  @override
  String get deletePlaylist => 'Wiedergabeliste löschen';

  @override
  String get deletePlaylistConfirm => 'Möchten Sie das wirklich löschen?';

  @override
  String get deletePlaylistConfirmation =>
      'Möchtest du diese Wiedergabeliste wirklich löschen?';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String get details => 'Details anzeigen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get dontShowAgain => 'Nicht mehr anzeigen';

  @override
  String get duration => 'Dauer';

  @override
  String get enableArtistSeparation => 'Künstlertrennung aktivieren';

  @override
  String get enableArtistSeparationDesc =>
      'Kombinierte Künstlernamen automatisch trennen';

  @override
  String get enjoyingAurora => 'Gefällt dir „Aurora“?';

  @override
  String get enjoyingAuroraDesc =>
      'Wenn Ihnen Aurora Music gefällt, denken Sie doch einmal darüber nach, die Entwicklung der App zu unterstützen. Ihre Unterstützung trägt dazu bei, dass die App kostenlos bleibt!';

  @override
  String get error => 'Fehler';

  @override
  String get exclusionHint => 'z. B. AC/DC';

  @override
  String get exclusions => 'Ausschlüsse';

  @override
  String get exclusionsDesc =>
      'Künstlernamen, die niemals getrennt werden sollten';

  @override
  String get exit => 'Beenden';

  @override
  String get exitApp => 'App beenden';

  @override
  String get exitAppConfirm => 'Möchten Sie das Programm beenden?';

  @override
  String get expandLyrics => 'Songtext anzeigen';

  @override
  String get extraLarge => 'Extra groß';

  @override
  String get favoriteSongs => 'Lieblingslieder';

  @override
  String get fileInfo => 'Datei-Info';

  @override
  String get fileInfoDesc =>
      'Halten Sie die Werte gedrückt, um sie zu kopieren';

  @override
  String get fileName => 'Dateiname';

  @override
  String get filePath => 'Dateipfad';

  @override
  String get folder => 'Ordner';

  @override
  String get folders => 'Ordner';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String get format => 'Format';

  @override
  String get forYou => 'Für dich';

  @override
  String get general => 'Allgemeines';

  @override
  String get genre => 'Genre';

  @override
  String get getStarted => 'Erste Schritte';

  @override
  String get goodQuality => 'Gute Qualität';

  @override
  String get gotIt => 'Verstanden!';

  @override
  String get grantPermission => 'Berechtigung erteilen';

  @override
  String get highQuality => 'Hohe Qualität';

  @override
  String get home => 'Startseite';

  @override
  String get kofi => 'Ko-fi';

  @override
  String get buyMeACoffee => 'Lade mir einen Kaffee ein';

  @override
  String get donationNote =>
      'Kein Druck – du kannst jederzeit später unter „Einstellungen“ spenden.';

  @override
  String get language => 'Sprache';

  @override
  String get large => 'Groß';

  @override
  String get later => 'Später';

  @override
  String get library => 'Bibliothek';

  @override
  String get libraryError => 'Fehler beim Laden der Musikbibliothek';

  @override
  String get libraryLoaded => 'Musikbibliothek wurde geladen';

  @override
  String get libraryUpdated => 'Bibliothek aktualisiert';

  @override
  String get loading => 'Wird geladen';

  @override
  String get loadingLibrary => 'Bibliothek wird geladen';

  @override
  String get lossless => 'Verlustfrei';

  @override
  String get lowQuality => 'Geringe Qualität';

  @override
  String get lyrics => 'Songtext';

  @override
  String get lyricsAhead => 'Es folgen die Liedtexte';

  @override
  String get lyricsBehind => 'Die Liedtexte folgen';

  @override
  String get lyricsSynced => 'Die Liedtexte sind synchronisiert';

  @override
  String get maybeLater => 'Vielleicht später';

  @override
  String get medium => 'Mittel';

  @override
  String get metadata => 'Metadaten';

  @override
  String get metadataSaved => 'Metadaten erfolgreich gespeichert';

  @override
  String get metadataApplied => 'Metadaten wurden erfolgreich heruntergeladen';

  @override
  String get metadataDownloadFailed =>
      'Der Download ist fehlgeschlagen. Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get chooseArtworkFromDevice => 'Wählen Sie ein Gerät aus';

  @override
  String get mostPlayed => 'Am häufigsten gespielt';

  @override
  String get newPlaylist => 'Neue Wiedergabeliste';

  @override
  String get next => 'Weiter';

  @override
  String get no => 'Nein';

  @override
  String get noAlbumsFound => 'Es wurden keine Alben gefunden';

  @override
  String get noArtistInfo => 'Keine Informationen zum Künstler verfügbar';

  @override
  String get noArtistsFound => 'Es wurden keine Künstler gefunden';

  @override
  String get noData => 'Es sind keine Daten vorhanden.';

  @override
  String get noExclusions => 'Es sind keine Ausschlüsse konfiguriert';

  @override
  String get noLyrics => 'Songtext nicht verfügbar';

  @override
  String get noLyricsDesc =>
      'Wir konnten keinen Liedtext zu diesem Lied finden.';

  @override
  String get noLyricsFound => 'Es wurden keine Liedtexte gefunden';

  @override
  String get noPermissionExplanation =>
      'Ohne die entsprechenden Berechtigungen kann Aurora Music nicht auf Ihre Musikbibliothek zugreifen.';

  @override
  String get noPlaylists => 'Es sind keine Wiedergabelisten verfügbar';

  @override
  String get noResults => 'Es wurden keine Ergebnisse gefunden';

  @override
  String get noSeparators => 'Es sind keine Trennzeichen konfiguriert';

  @override
  String get noSongPlaying => 'Es wird kein Lied abgespielt';

  @override
  String get noSongsAvailable => 'Es sind keine Songs verfügbar';

  @override
  String get noSongsInPlaylist => 'Diese Wiedergabeliste enthält keine Titel';

  @override
  String get nowPlaying => 'Aktuell läuft';

  @override
  String get onboardingAlbumArt => 'Wunderschönes Albumcover';

  @override
  String get onboardingAlbumArtwork => 'Albumcover';

  @override
  String get onboardingAlbumArtworkDesc =>
      'Lädt hochwertige Albumcover herunter, um Ihre Mediathek aufzuwerten';

  @override
  String get onboardingAppInfoSubtitle => 'Dein persönlicher Musikbegleiter';

  @override
  String get onboardingAppInfoTitle => 'Willkommen bei Aurora Music';

  @override
  String get onboardingAudioAccess => 'Audio-Zugriff';

  @override
  String get onboardingAudioAccessDesc =>
      'Erforderlich zum Abspielen und Verwalten Ihrer Musikbibliothek';

  @override
  String get onboardingBack => 'Zurück';

  @override
  String get onboardingBeautifulArtwork => 'Wunderschönes Albumcover';

  @override
  String get onboardingBeautifulArtworkDesc =>
      'Albumcover automatisch abrufen und so anzeigen, wie sie eigentlich gedacht sind';

  @override
  String get onboardingBluetooth => 'Bluetooth';

  @override
  String get onboardingBluetoothDesc =>
      'Erforderlich für die Verbindung mit Bluetooth-Geräten';

  @override
  String get onboardingChooseLanguage => 'Wählen Sie Ihre Sprache';

  @override
  String get languageNotListedHint =>
      'Ihre Sprache ist nicht aufgeführt? Wählen Sie „Englisch“ aus und fahren Sie auf der nächsten Seite fort.';

  @override
  String get onboardingCompletionSubtitle => 'Genießen Sie Ihre Musik';

  @override
  String get onboardingCompletionTitle => 'Das war\'s schon!';

  @override
  String get onboardingContinue => 'Weiter';

  @override
  String get onboardingDynamicColors => 'Dynamische Farben';

  @override
  String get onboardingDynamicColorsDesc =>
      'Farben der Systemhintergründe anpassen';

  @override
  String get onboardingGrantPermissions => 'Berechtigungen erteilen';

  @override
  String get onboardingInternetSubtitle =>
      'Wie Aurora Music das Internet nutzt';

  @override
  String get onboardingInternetTitle => 'Internetnutzung';

  @override
  String get onboardingLocalMusic => 'Musik auf Ihrem Gerät';

  @override
  String get onboardingLocalMusicDesc => 'Ihre Musikdateien immer griffbereit';

  @override
  String get onboardingLyrics => 'Songtext';

  @override
  String get onboardingLyricsDesc =>
      'Lädt synchronisierte Songtexte für deine Lieder herunter';

  @override
  String get onboardingLyricsSupport => 'Unterstützung bei Liedtexten';

  @override
  String get onboardingLyricsSupportDesc =>
      'Synchronisierte Liedtexte beim Anhören anzeigen';

  @override
  String get onboardingMaterialDesign => 'Material You-Design';

  @override
  String get onboardingMaterialDesignDesc =>
      'Dynamische Farben, die sich Ihren Vorlieben anpassen';

  @override
  String get onboardingMusicMetadata => 'Musik-Metadaten';

  @override
  String get onboardingMusicMetadataDesc =>
      'Ruft Informationen zum Interpreten, zum Album und zu den Titeln ab';

  @override
  String get onboardingNotifications => 'Benachrichtigungen';

  @override
  String get onboardingNotificationsDesc =>
      'Wiedergabesteuerung und Aktualisierungen anzeigen';

  @override
  String get onboardingOptional => 'Optional';

  @override
  String get onboardingPermissionsSubtitle =>
      'Aurora Music benötigt diese Berechtigungen, um ordnungsgemäß zu funktionieren';

  @override
  String get onboardingPermissionsTitle => 'Berechtigungen erteilen';

  @override
  String get onboardingPrivacyNote =>
      'Der Schutz Ihrer Privatsphäre ist uns wichtig. Alle Musikdateien verbleiben auf Ihrem Gerät.';

  @override
  String get onboardingRequesting => 'Wird angefordert...';

  @override
  String get onboardingRequired => 'Erforderlich';

  @override
  String get onboardingAudioRequired =>
      'Um fortzufahren, ist der Zugriff auf die Audiofunktion erforderlich. Bitte erteilen Sie die oben genannte Berechtigung.';

  @override
  String get onboardingSelectLanguage =>
      'Wählen Sie Ihre bevorzugte Sprache aus';

  @override
  String get onboardingSmartPlaylists => 'Intelligente Wiedergabelisten';

  @override
  String get onboardingSmartPlaylistsDesc =>
      'Erstellen und verwalten Sie Ihre Musiksammlungen';

  @override
  String get onboardingStartListening => 'Zum Anhören';

  @override
  String get onboardingStorageAccess => 'Speicherzugriff';

  @override
  String get onboardingStorageAccessDesc =>
      'Erforderlich, um Musikdateien von Ihrem Gerät zu lesen';

  @override
  String get onboardingVisualizerAccess => 'Visualisierer';

  @override
  String get onboardingVisualizerAccessDesc =>
      'Ermöglicht es dem Visualizer, die Audiositzung Ihres Geräts für das Live-Balkenspektrum auszulesen. Es wird zu keinem Zeitpunkt Audio aufgezeichnet.';

  @override
  String get onboardingThemeSubtitle =>
      'Wähle ein Thema, das zu deinem Stil passt';

  @override
  String get onboardingThemeTitle =>
      'Gestalte deinen Look ganz nach deinen Wünschen';

  @override
  String get beta_welcome_title => 'Beta-Testprogramm';

  @override
  String get beta_welcome_thanks =>
      'Vielen Dank, dass Sie an unserem Beta-Testprogramm teilnehmen und uns dabei helfen, Aurora Music zu verbessern.';

  @override
  String get beta_expect_bugs_title => 'Rechnen Sie mit Fehlern';

  @override
  String get beta_expect_bugs_desc =>
      'Es kann zu Abstürzen oder unerwartetem Verhalten kommen. Dies ist eine Testversion.';

  @override
  String get beta_feedback_title => 'Feedback ist wichtig';

  @override
  String get beta_feedback_desc =>
      'Ihre Rückmeldungen und Vorschläge helfen uns dabei, die App für alle zu verbessern.';

  @override
  String get beta_updates_title => 'Regelmäßige Aktualisierungen';

  @override
  String get beta_updates_desc =>
      'Im Zuge der weiteren Entwicklung werden regelmäßig neue Funktionen und Fehlerbehebungen veröffentlicht.';

  @override
  String get oneTimeSupport => 'Schnelle einmalige Unterstützung';

  @override
  String get openFolder => 'Im Dateimanager öffnen';

  @override
  String get openFolderInfo =>
      'Navigieren Sie mit Ihrem Dateimanager zu diesem Speicherort';

  @override
  String get ownTimer => 'Eigener Timer';

  @override
  String get permDeny => 'Zugriff verweigert';

  @override
  String get permissionExplanation =>
      'Aurora Music benötigt diese Berechtigungen, um ordnungsgemäß zu funktionieren. Bitte erteilen Sie die Berechtigungen in den App-Einstellungen.';

  @override
  String get permissionLater =>
      'Sie können die Berechtigungen später in den App-Einstellungen erteilen.';

  @override
  String get permissionRequired => 'Genehmigung erforderlich';

  @override
  String get playAll => 'Alle abspielen';

  @override
  String get playingFrom => 'Abspielen von';

  @override
  String get playlist => 'Wiedergabeliste';

  @override
  String get playlistName => 'Name der Wiedergabeliste';

  @override
  String get playlists => 'Playlists';

  @override
  String get possibleReasons => 'Mögliche Gründe:';

  @override
  String get privacyNotice =>
      'Wenn Sie diese App weiterhin nutzen, erklären Sie sich mit unserer Datenschutzerklärung einverstanden.';

  @override
  String get privacyPolicyLink => 'Lesen Sie unsere Datenschutzerklärung';

  @override
  String get quality => 'Qualität';

  @override
  String get qualityDesc =>
      'Audioqualität in Abhängigkeit von Format und Bitrate';

  @override
  String get queue => 'Warteschlange';

  @override
  String get queueEmpty => 'Die Warteschlange ist leer';

  @override
  String get reasonFormat =>
      'Das Dateiformat unterstützt die Bearbeitung von Metadaten nicht.';

  @override
  String get reasonPermissions => 'Speicherberechtigungen nicht erteilt';

  @override
  String get reasonReadonly =>
      'Die Datei ist schreibgeschützt oder befindet sich auf einem externen Speichermedium';

  @override
  String get recentlyAdded => 'Kürzlich hinzugefügt';

  @override
  String get recentlyPlayed => 'Zuletzt gespielt';

  @override
  String get recentlyPlayedArtists => 'Zuletzt abgespielte Künstler';

  @override
  String get recentlyPlayedSongs => 'Zuletzt abgespielte Titel';

  @override
  String get refreshing => 'Erfrischend...';

  @override
  String get refreshLyrics => 'Songtexte aktualisieren';

  @override
  String get remove => 'Entfernen';

  @override
  String get removeSong => 'Titel entfernen';

  @override
  String get removeSongConfirmation =>
      'Soll dieser Titel aus der Wiedergabeliste entfernt werden?';

  @override
  String get rename => 'Umbenennen';

  @override
  String get renamePlaylist => 'Wiedergabeliste umbenennen';

  @override
  String get repeat => 'Wiederholen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get resetArtistSeparationDesc =>
      'Dadurch werden alle Standardtrennzeichen und Ausschlüsse wiederhergestellt.';

  @override
  String get resetToDefaults => 'Auf Standardwerte zurücksetzen';

  @override
  String get result => 'Ergebnis';

  @override
  String get results => 'Ergebnisse';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get sampleRate => 'Abtastrate';

  @override
  String get save => 'Speichern';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get saveChangesDesc => 'Möchten Sie Ihre Änderungen speichern?';

  @override
  String get saveFailed => 'Speichern fehlgeschlagen';

  @override
  String get saveFailedDesc =>
      'Metadaten können nicht in dieser Datei gespeichert werden.';

  @override
  String get scanFailed => 'Scan fehlgeschlagen';

  @override
  String get scanningSongs => 'Songs scannen';

  @override
  String get search => 'Suche';

  @override
  String get searchAlbums => 'Alben suchen';

  @override
  String get searchArtists => 'Künstler suchen';

  @override
  String get searchFailed => 'Die Suche ist fehlgeschlagen';

  @override
  String get searchLyrics => 'Songtexte suchen';

  @override
  String get searchMetadata => 'Metadaten durchsuchen';

  @override
  String get searchTracks => 'Titel suchen';

  @override
  String get selectAll => 'Alles auswählen';

  @override
  String get selectArtist => 'Künstler auswählen';

  @override
  String get selected => 'ausgewählt';

  @override
  String get selectPlaylist => 'Playlist auswählen';

  @override
  String get separator => 'Trennzeichen';

  @override
  String get separatorHint => 'z. B. / oder mit';

  @override
  String get separators => 'Trennzeichen';

  @override
  String get set => 'Set';

  @override
  String get setMinutes => 'Protokoll festlegen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsAboutApp => 'Über Aurora Music';

  @override
  String get settingsAboutSubtitle => 'Version, Feedback und Updates';

  @override
  String get settingsAccentColor => 'Akzentfarbe';

  @override
  String get settingsAppearance => 'Aussehen';

  @override
  String get settingsAppearanceSubtitle => 'Thema, Farben und Layout';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsBackground => 'Hintergrund';

  @override
  String get settingsCacheCleared => 'Cache geleert';

  @override
  String get settingsCacheInfo => 'Cache-Informationen';

  @override
  String get settingsCacheInfoDesc => 'Speicherbelegung anzeigen';

  @override
  String get settingsCheckingUpdates => 'Nach Updates suchen...';

  @override
  String get settingsCheckUpdates => 'Nach Updates suchen';

  @override
  String get settingsCheckUpdatesDesc => 'Aktuelle Version herunterladen';

  @override
  String get settingsClearCache => 'Cache leeren';

  @override
  String get settingsClearCacheDesc =>
      'Alle zwischengespeicherten Daten löschen';

  @override
  String get settingsClearCacheMessage =>
      'Alle zwischengespeicherten Daten werden gelöscht und bei Bedarf neu erstellt.';

  @override
  String get settingsClearCacheTitle => 'Cache leeren?';

  @override
  String get settingsDataWindow => 'Datenfenster';

  @override
  String get settingsDataWindowDesc =>
      'Wie weit zurück der Rückblick-Bildschirm reicht';

  @override
  String get settingsGapless => 'Wiedergabe ohne Pausen';

  @override
  String get settingsGaplessDesc => 'Nahtlose Übergänge zwischen den Titeln';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsCrossfadeDesc =>
      'Das Ende eines Titels nahtlos in den nächsten überblenden';

  @override
  String get crossfadeDuration => 'Überblenddauer';

  @override
  String get crossfadeDurationDesc =>
      'Wie lange die Überlappung zwischen den Titeln dauert';

  @override
  String get settingsInsights => 'Einblicke';

  @override
  String get settingsInsightsSubtitle =>
      'Zusammenfassung der Hörverständnis-Phase';

  @override
  String get settingsLast7Days => 'Die letzten 7 Tage';

  @override
  String get settingsLast30Days => 'Letzte 30 Tage';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLayout => 'Layout';

  @override
  String get settingsLibraryFolders => 'Bibliotheksordner';

  @override
  String get settingsLibraryFoldersSubtitle =>
      'Scan-Ordner einbeziehen oder ausschließen';

  @override
  String get settingsMaterialYou => 'Material You';

  @override
  String get settingsMaterialYouDesc => 'Dynamische Farben durch die Tapete';

  @override
  String get settingsMonthlyRecap => 'Monatsrückblick';

  @override
  String get settingsMonthlyRecapDesc =>
      'Jeden Monat ein Banner anzeigen (hat Vorrang vor der wöchentlichen Anzeige)';

  @override
  String get settingsNormalization => 'Lautstärkenormalisierung';

  @override
  String get settingsNormalizationDesc =>
      'Gleichmäßige Lautstärke · Erfordert ReplayGain-Tags in Ihren Dateien';

  @override
  String get playbackSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get playbackSpeedDesc => 'Wiedergabegeschwindigkeit anpassen';

  @override
  String get adjustPitchWithSpeed => 'Tonhöhe mit der Geschwindigkeit anpassen';

  @override
  String get adjustPitchWithSpeedDesc =>
      'Wenn ausgeschaltet, ändert sich das Tempo ohne Tonhöhenverschiebung';

  @override
  String get settingsPlayback => 'Wiedergabe';

  @override
  String get settingsPlaybackSubtitle =>
      'Geschwindigkeit, lückenlose Wiedergabe und Normalisierung';

  @override
  String get settingsRecapBannerDesc =>
      'Das Banner wird zu Beginn jeder neuen Woche oder jedes neuen Monats – gerechnet ab deinem allerersten Spiel – auf dem Startbildschirm angezeigt. Wenn du auf „Später“ tippst, wird es für diese Sitzung ausgeblendet; wenn du auf „Anzeigen“ tippst, wird es als gesehen markiert.';

  @override
  String get settingsRecapContent => 'Zusammenfassung des Inhalts';

  @override
  String get settingsRecapContentDesc =>
      'Legt fest, wie viel Verlauf auf dem Übersichtsbildschirm angezeigt wird, wenn Sie ihn manuell oder über das Banner öffnen.';

  @override
  String get settingsPreviewRecap => 'Vorschau – Rückblick';

  @override
  String get settingsPreviewRecapDesc =>
      'Sehen Sie sich an, wie Ihre Zusammenfassung mit den aktuellen Einstellungen derzeit aussieht';

  @override
  String get settingsRecapSchedule => 'Zeitplan der Zusammenfassungen';

  @override
  String get settingsStorage => 'Lagerung';

  @override
  String settingsCacheItems(String count) {
    return '$count Artikel';
  }

  @override
  String get settingsMemoryCache => 'Speicher-Cache';

  @override
  String get settingsStorageSubtitle => 'Cache- und Mediendateien';

  @override
  String get settingsTheme => 'Thema';

  @override
  String get settingsTools => 'Werkzeuge';

  @override
  String get settingsResetSetup => 'Einstellungen zurücksetzen';

  @override
  String get settingsResetSetupDesc => 'Den Onboarding-Prozess neu starten';

  @override
  String get settingsUpdateAvailable => 'Update verfügbar!';

  @override
  String get settingsUpToDate => 'Du bist auf dem neuesten Stand';

  @override
  String get settingsWeeklyRecap => 'Wochenrückblick';

  @override
  String get settingsWeeklyRecapDesc =>
      'Zeige jede Woche nach dem ersten Abspielen ein Banner an';

  @override
  String get settingsVersion => 'Version';

  @override
  String get share => 'Teilen';

  @override
  String get showChangelog => 'Änderungsprotokoll anzeigen';

  @override
  String get shuffle => 'Zufallsreihenfolge';

  @override
  String get size => 'Größe';

  @override
  String get sleepTimer => 'Ausschalt-Timer';

  @override
  String get small => 'Klein';

  @override
  String get songInfo => 'Informationen zum Song';

  @override
  String get songs => 'Lieder';

  @override
  String get songsLoaded => 'Lieder wurden geladen';

  @override
  String get standardQuality => 'Standardqualität';

  @override
  String get startType => 'Beginnen Sie mit der Eingabe, um zu suchen';

  @override
  String get storagePermissionNeeded =>
      'Um Metadaten zu bearbeiten, benötigt Aurora Music die Berechtigung, Dateien zu verwalten. Bitte erteilen Sie in den Einstellungen die Berechtigung „Zugriff auf alle Dateien“.';

  @override
  String get suggestedArtists => 'Künstler für dich';

  @override
  String get suggestedTracks => 'Empfohlene Titel';

  @override
  String get supportAurora => 'Unterstütze Aurora';

  @override
  String get supportAuroraBtn => 'Unterstütze Aurora';

  @override
  String get supportAuroraDescShort => 'Hilf mit, die App kostenlos zu halten';

  @override
  String get supportAuroraMessage =>
      'Helfen Sie mit, Aurora Music kostenlos zu halten, und unterstützen Sie die weitere Entwicklung. Jeder Beitrag bedeutet uns sehr viel!';

  @override
  String get supportAuroraTitle => 'Unterstützen Sie Aurora Music';

  @override
  String get tapAddToAddSongs => 'Tippe auf „+“, um Songs hinzuzufügen';

  @override
  String get reorderSongs => 'Songs neu anordnen';

  @override
  String get done => 'Fertig';

  @override
  String get thankYouSupport => 'Vielen Dank für Ihre Unterstützung!';

  @override
  String get theme => 'Thema';

  @override
  String get title => 'Titel';

  @override
  String get topResult => 'Top-Ergebnis';

  @override
  String get total => 'Gesamt';

  @override
  String get track => 'Titel';

  @override
  String get trackInfo => 'Titelinformationen';

  @override
  String get trackInfoDesc =>
      'Tippe auf das Bearbeitungssymbol, um die Titelinformationen zu ändern';

  @override
  String get trackInfoEditDesc =>
      'Bearbeiten Sie die untenstehenden Felder und tippen Sie anschließend auf das Häkchen-Symbol, um zu speichern';

  @override
  String get tracks => 'Titel';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get unknownArtist => 'Unbekannter Künstler';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String get updateMessage => 'Eine neue Version ist verfügbar';

  @override
  String get updateNow => 'Jetzt aktualisieren';

  @override
  String get viewArtist => 'Künstler anzeigen';

  @override
  String get viewDetails => 'Details anzeigen';

  @override
  String get welcomeBack => 'Willkommen zurück';

  @override
  String get whatsNew => 'Was gibt’s Neues?';

  @override
  String get view_changelog =>
      'Änderungsprotokoll und neue Funktionen anzeigen';

  @override
  String get year => 'Jahr';

  @override
  String get yes => 'Ja';

  @override
  String get yourLibrary => 'Ihre Bibliothek';

  @override
  String get yourPlaylists => 'Deine Wiedergabelisten';

  @override
  String get homeLayout => 'Startseite – Layout';

  @override
  String get homeLayoutDesc =>
      'Reihenfolge der Abschnitte auf der Registerkarte „Startseite“ anpassen';

  @override
  String get customizeHomeTab => 'Registerkarte „Startseite“ anpassen';

  @override
  String get dragToReorder => 'Zum Neuanordnen der Abschnitte ziehen';

  @override
  String get resetToDefault => 'Auf Standardwerte zurücksetzen';

  @override
  String get resetLayoutConfirm => 'Layout auf Standard zurücksetzen?';

  @override
  String get resetLayoutMessage =>
      'Dadurch werden die ursprüngliche Reihenfolge und Sichtbarkeit der Abschnitte wiederhergestellt.';

  @override
  String get sectionVisibility => 'Sichtbarkeit des Abschnitts umschalten';

  @override
  String get listeningHistory => 'Hörverlauf';

  @override
  String get libraryStats => 'Bibliotheksstatistiken';

  @override
  String get back => 'Zurück';

  @override
  String get continueButton => 'Weiter';

  @override
  String get skip => 'Überspringen';

  @override
  String get feedback_title => 'Gefällt dir Aurora Music?';

  @override
  String get maybe_later => 'Vielleicht später';

  @override
  String get send_feedback => 'Feedback senden';

  @override
  String get send_feedback_desc => 'Fehler melden oder Funktionen vorschlagen';

  @override
  String get contributeTranslations => 'Übersetzungen beisteuern';

  @override
  String get contributeTranslationsDesc =>
      'Hilf mit, „Aurora Music“ auf Crowdin zu übersetzen';

  @override
  String get contributeTranslationsTitle => 'Helfen Sie uns beim Übersetzen';

  @override
  String get contributeTranslationsSubtitle =>
      'Dank unserer großartigen Community ist Aurora Music in mehreren Sprachen verfügbar. Hilf uns dabei, noch mehr Nutzer zu erreichen, indem du die App in deine Sprache übersetzt – der Einstieg dauert nur wenige Minuten.';

  @override
  String get contributeTranslationsOpenCrowdin => 'Crowdin öffnen';

  @override
  String get close => 'Schließen';

  @override
  String get settingsHighendUi => 'Hochwertige Benutzeroberfläche';

  @override
  String get settingsHighendUiDesc =>
      'Erweiterte visuelle Effekte und Animationen aktivieren';

  @override
  String get restartRequired => 'Neustart erforderlich';

  @override
  String get restartRequiredDesc =>
      'Die App muss neu gestartet werden, damit die Änderung des UI-Modus wirksam wird. Jetzt neu starten?';

  @override
  String get restartNow => 'Jetzt neu starten';

  @override
  String get clearUpcoming => 'Anstehende Termine löschen';

  @override
  String get addToQueue => 'Zur Warteschlange hinzufügen';

  @override
  String get playNext => 'Als Nächstes abspielen';

  @override
  String get removeFromQueue => 'Aus der Warteschlange entfernen';

  @override
  String get play => 'Abspielen';

  @override
  String get viewAlbum => 'Album anzeigen';

  @override
  String get shuffleAll => 'Alle mischen';

  @override
  String get noSongsFound => 'Es wurden keine Lieder gefunden';

  @override
  String get noFoldersFound => 'Es wurden keine Ordner gefunden';

  @override
  String get deleteSong => 'Titel löschen';

  @override
  String get modifySystemSettingsPermission =>
      'Aktivieren Sie auf der sich öffnenden Seite die Option „Systemeinstellungen ändern“ und versuchen Sie es dann erneut.';

  @override
  String errorMessage(String message) {
    return 'Fehler: $message';
  }

  @override
  String songsAddedToQueue(int count) {
    return '$count Titel wurden zur Wiedergabeliste hinzugefügt';
  }

  @override
  String songAddedToQueue(String title) {
    return '„$title“ wurde zur Warteschlange hinzugefügt';
  }

  @override
  String songSetAsRingtone(String title) {
    return '„$title“ als Klingelton festlegen';
  }

  @override
  String failedToSetRingtone(String error) {
    return 'Das Festlegen des Klingeltons ist fehlgeschlagen: $error';
  }

  @override
  String deleteSongConfirm(String title) {
    return '„$title“ von Ihrem Gerät löschen? Dieser Vorgang kann nicht rückgängig gemacht werden.';
  }

  @override
  String songDeleted(String title) {
    return '„$title“ wurde gelöscht';
  }

  @override
  String failedToDelete(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String songCount(int count) {
    return '$count Lieder';
  }

  @override
  String get badgeNew => 'NEU';

  @override
  String get paused => 'Angehalten';

  @override
  String get readyToPlay => 'Bereit zum Spielen';

  @override
  String get tapSongToStartListening =>
      'Tippe auf einen Song, um ihn abzuspielen';

  @override
  String get clearCachedLyrics => 'Zwischengespeicherte Liedtexte löschen';

  @override
  String lyricsCleared(String title) {
    return 'Zwischengespeicherte Songtexte für „$title“ gelöscht';
  }

  @override
  String get noLyricsCached =>
      'Für diesen Song wurden keine zwischengespeicherten Songtexte gefunden.';

  @override
  String get setAsRingtone => 'Als Klingelton festlegen';

  @override
  String get songInfoEdit => 'Song-Infos / Bearbeiten';

  @override
  String get goToAlbum => 'Zum Album';

  @override
  String get goToArtist => 'Zum Künstler';

  @override
  String get deleteFromDevice => 'Vom Gerät löschen';

  @override
  String get checkOutThisSong => 'Hör dir diesen Song mal an!';

  @override
  String get backgroundLowEndStyle => 'Hintergrundstil';

  @override
  String get backgroundLowEndStyleDesc =>
      'So sieht der Hintergrund der App aus';

  @override
  String get backgroundBlobs => 'Animierte Kleckse';

  @override
  String get backgroundSolid => 'Einfarbig';

  @override
  String get backgroundHighEndStyle => 'Aktuelle Wiedergabe – Hintergrund';

  @override
  String get backgroundHighEndStyleDesc =>
      'Hintergrundstil im Bildschirm „Aktuelle Wiedergabe“';

  @override
  String get backgroundBlurredArtwork => 'Unscharfe Kunstwerke';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get accentColorDesc => 'Wähle die Akzentfarbe der App aus';

  @override
  String get backgroundBlur => 'Hintergrundunschärfe';

  @override
  String get backgroundBlurDesc => 'Intensität der Unschärfe des Bildes';

  @override
  String get backgroundDarkness => 'Hintergrund: Dunkelheit';

  @override
  String get backgroundDarknessDesc =>
      'Deckkraft der Überlagerung auf der Grafik';

  @override
  String get microphoneAccessNeeded => 'Zugriff auf das Mikrofon erforderlich';

  @override
  String get microphoneAccessDesc =>
      'Aurora benötigt Zugriff auf das Mikrofon, um für den Live-Visualizer auf die Audiositzung Ihres Geräts zugreifen zu können. Es werden zu keinem Zeitpunkt Audiodaten aufgezeichnet oder gespeichert.';

  @override
  String get recapWeek => 'Woche';

  @override
  String get recapMonth => 'Monat';

  @override
  String get recapPeriodWeek => 'Woche';

  @override
  String get recapPeriodMonth => 'Monat';

  @override
  String get recapWeekly => 'Wöchentlich';

  @override
  String get recapMonthly => 'Monatlich';

  @override
  String get recapIntroAppName => 'AURORA MUSIC';

  @override
  String recapIntroTitle(String period) {
    return 'Dein $period\nZusammenfassung';
  }

  @override
  String get recapIntroSubtitle => 'Mal sehen, was du dir\nso angehört hast.';

  @override
  String recapPlayedEyebrow(String period) {
    return 'In diesem $period hast du Musik abgespielt';
  }

  @override
  String get recapTimeSingular => 'Zeit';

  @override
  String get recapTimePlural => 'Mal';

  @override
  String get recapListenedForEyebrow => 'Du hast darauf geachtet, ob';

  @override
  String get recapListenedForLabel => 'Musik';

  @override
  String get recapTopTrackEyebrow => 'Dein beliebtester Titel';

  @override
  String get recapPlays => 'Stücke';

  @override
  String get recapTopTracksTitle => 'Top-Titel';

  @override
  String get recapTopArtistEyebrow => 'Dein Lieblingskünstler';

  @override
  String get recapTopArtistsTitle => 'Top-Künstler';

  @override
  String get recapNothingToWrap => 'Noch gibt es nichts zum Einpacken';

  @override
  String recapNothingToWrapBody(String period) {
    return 'Spiel doch ein bisschen Musik, $period, und komm dann wieder zurück.';
  }

  @override
  String get recapSwipeUp => 'NACH OBEN WISCHEN';

  @override
  String get recapYourSoundLabel => 'DEIN SOUND';

  @override
  String get recapYouListenMost => 'DU HÖRST AM MEISTEN ZU';

  @override
  String recapOnDay(String day) {
    return 'auf ${day}s';
  }

  @override
  String recapAroundTime(String time) {
    return 'etwa $time';
  }

  @override
  String get recapVibesHitDifferent =>
      'Da war die Stimmung plötzlich ganz anders.';

  @override
  String get recapThatsAWrap => 'DAS WAR\'S DANN';

  @override
  String recapInNumbers(String period) {
    return 'Dein $period\nin Zahlen';
  }

  @override
  String get recapNumberOneTrack => '#1 TITEL';

  @override
  String get recapStatTotalPlays => 'Gesamtanzahl der Wiedergaben';

  @override
  String get recapStatTimeListened => 'Hörzeit';

  @override
  String get recapStatUniqueTracks => 'Einzigartige Titel';

  @override
  String get recapStatTopArtist => 'Top-Künstler';

  @override
  String get recapDone => 'Fertig';

  @override
  String get recapWeekdayMonday => 'Montag';

  @override
  String get recapWeekdayTuesday => 'Dienstag';

  @override
  String get recapWeekdayWednesday => 'Mittwoch';

  @override
  String get recapWeekdayThursday => 'Donnerstag';

  @override
  String get recapWeekdayFriday => 'Freitag';

  @override
  String get recapWeekdaySaturday => 'Samstag';

  @override
  String get recapWeekdaySunday => 'Sonntag';

  @override
  String get recapBannerTitle => 'Hier geht’s zum Musikrückblick';

  @override
  String get recapBannerShow => 'Anzeigen';

  @override
  String get recapBannerLater => 'Später';

  @override
  String get eqTitle => 'Equalizer';

  @override
  String get eqOn => 'EIN';

  @override
  String get eqOff => 'AUS';

  @override
  String get eqNotAvailable =>
      'Der Equalizer ist auf diesem Gerät nicht verfügbar.';

  @override
  String get eqOpenSystem => 'Offener System-Equalizer';

  @override
  String get eqSavePreset => 'Voreinstellung speichern';

  @override
  String get eqPresetNameHint => 'z. B. „My Bass Boost“';

  @override
  String get eqPresetNameEmpty => 'Der Name darf nicht leer sein.';

  @override
  String eqPresetNameBuiltIn(String name) {
    return '„$name“ ist der Name einer integrierten Voreinstellung.';
  }

  @override
  String get eqResetAllBands => 'Alle Frequenzbänder zurücksetzen';

  @override
  String get eqPresetsLabel => 'VOREINSTELLUNGEN';

  @override
  String get eqYourPresetsLabel => 'IHRE VOREINSTELLUNGEN';

  @override
  String get eqSaveCurrent => 'Aktuellen Stand speichern';

  @override
  String get eqSettingsSubtitle => 'Audiofrequenzen pro Frequenzband anpassen';

  @override
  String get eqEmptyPresets =>
      'Stelle deinen Sound ein und tippe anschließend auf „Aktuellen Sound speichern“.';

  @override
  String get lyricsHint =>
      'Füge hier die nicht synchronisierten Songtexte ein…\n\nEine Zeile pro Verszeile.';

  @override
  String get lyricsSelectLrcFile => 'Bitte wählen Sie eine .lrc-Datei aus';

  @override
  String get lyricsNoLyricsInFile =>
      'In dieser Datei wurden keine Liedtexte gefunden';

  @override
  String importFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get lyricsImportTooltip => '.lrc-Datei importieren';

  @override
  String get importPlaylistM3u => 'Wiedergabeliste importieren (.m3u)';

  @override
  String get setSyncFolder => 'Synchronisierungsordner festlegen…';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get searchPlaylists => 'Playlists suchen…';

  @override
  String get pleaseSelectM3uFile =>
      'Bitte wählen Sie eine .m3u- oder .m3u8-Datei aus';

  @override
  String get noMatchingSongsForPlaylist =>
      'Für diese Wiedergabeliste wurden keine passenden Titel gefunden.';

  @override
  String importedPlaylist(String name, int count) {
    return '„$name“ importiert ($count Titel)';
  }

  @override
  String playlistsSyncWith(String folder) {
    return 'Die Wiedergabelisten werden mit $folder synchronisiert.';
  }

  @override
  String couldNotSetSyncFolder(String error) {
    return 'Der Synchronisierungsordner konnte nicht festgelegt werden: $error';
  }

  @override
  String get setSyncFolderFirst =>
      'Legen Sie zunächst einen Synchronisierungsordner fest';

  @override
  String get playlistsSynced => 'Playlists synchronisiert';

  @override
  String get alreadyUpToDate => 'Bereits auf dem neuesten Stand';

  @override
  String syncFailed(String error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get searchFolders => 'Suchordner…';

  @override
  String get songInfoPath => 'Pfad';

  @override
  String get closeVisualiser => 'Visualisierung schließen';

  @override
  String get previousMode => 'Vorheriger Modus';

  @override
  String get nextMode => 'Nächster Modus';

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get colorTheme => 'Farbschema';

  @override
  String get insightsTotalPlays => 'Gesamt\nAufrufe';

  @override
  String get insightsTracksHeard => 'Titel\nGehört';

  @override
  String get insightsEstListening => 'Geschätzt.\nZuhören';

  @override
  String get dismiss => 'Schließen';

  @override
  String updateVersionAvailable(String version) {
    return 'Version $version ist jetzt verfügbar.';
  }

  @override
  String get updateNewVersionAvailable =>
      'Eine neue Version ist nun verfügbar.';

  @override
  String get lyricsPasteLyricsTitle => 'Songtext einfügen';

  @override
  String get lyricsUseLyrics => 'Songtexte verwenden';

  @override
  String get lyricsPaste => 'Einfügen';

  @override
  String get lyricsNoLyricsYet => 'Noch kein Liedtext';

  @override
  String get lyricsPasteToGetStarted => 'Füge den Liedtext ein, um loszulegen';

  @override
  String get lyricsNoTimestampsYet =>
      'Noch keine Zeitstempel – tippe während der Wiedergabe auf die Stempel-Schaltfläche.';

  @override
  String get lyricsAllLinesStampedHint =>
      'Alle Zeilen sind markiert – tippe auf „Speichern“, um den Vorgang abzuschließen.';

  @override
  String get lyricsAllStamped => '✓  Alle Zeilen abgestempelt';

  @override
  String get lyricsPasteFirst => 'Füge zuerst den Liedtext ein';

  @override
  String lyricsTapToStamp(int current, int total) {
    return '⏱  AUF DIE ZEILE $current / $total TIPPEN, UM SIE ZU STAMPFEN';
  }

  @override
  String get lyricsNextLabel => 'Weiter';

  @override
  String get translationDisclaimerNote =>
      'Some translations are AI-generated or community-contributed and may contain errors. Help us improve them on Crowdin.';

  @override
  String get newLanguagesAvailableTitle => 'New Languages Available';

  @override
  String get newLanguagesAvailableBody =>
      'Aurora Music now supports German, Spanish, Hindi, and Russian. You can change your language in Settings.';

  @override
  String get newLanguagesGoToSettings => 'Change Language';

  @override
  String get newLanguagesDismiss => 'Got it';
}
