import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en')
  ];

  /// No description provided for @aboutArtist.
  ///
  /// In en, this message translates to:
  /// **'About artist'**
  String get aboutArtist;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to playlist'**
  String get addedToPlaylist;

  /// No description provided for @addExclusion.
  ///
  /// In en, this message translates to:
  /// **'Add Exclusion'**
  String get addExclusion;

  /// No description provided for @addSeparator.
  ///
  /// In en, this message translates to:
  /// **'Add Separator'**
  String get addSeparator;

  /// No description provided for @addSongs.
  ///
  /// In en, this message translates to:
  /// **'Add Songs'**
  String get addSongs;

  /// No description provided for @addSongsToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add Songs to Playlist'**
  String get addSongsToPlaylist;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @adjustSync.
  ///
  /// In en, this message translates to:
  /// **'Adjust Sync'**
  String get adjustSync;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @allSongs.
  ///
  /// In en, this message translates to:
  /// **'All Songs'**
  String get allSongs;

  /// No description provided for @alphaDescription.
  ///
  /// In en, this message translates to:
  /// **'Thank you for testing Aurora Music before its public release. Your feedback helps us make the app even better.'**
  String get alphaDescription;

  /// No description provided for @alphaTitle.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Alpha Access'**
  String get alphaTitle;

  /// No description provided for @appExit.
  ///
  /// In en, this message translates to:
  /// **'Exit Aurora Music'**
  String get appExit;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Aurora Music'**
  String get appName;

  /// No description provided for @appUpToDate.
  ///
  /// In en, this message translates to:
  /// **'App is up to date!'**
  String get appUpToDate;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @artistName.
  ///
  /// In en, this message translates to:
  /// **'Artist name'**
  String get artistName;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @artistSeparation.
  ///
  /// In en, this message translates to:
  /// **'Artist Separation'**
  String get artistSeparation;

  /// No description provided for @artistSeparationDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure how multiple artists are split'**
  String get artistSeparationDesc;

  /// No description provided for @audioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio Quality'**
  String get audioQuality;

  /// No description provided for @audioQualityDesc.
  ///
  /// In en, this message translates to:
  /// **'Technical specifications of the audio file'**
  String get audioQualityDesc;

  /// No description provided for @auroraMusic.
  ///
  /// In en, this message translates to:
  /// **'Aurora Music'**
  String get auroraMusic;

  /// No description provided for @autoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Auto Playlists'**
  String get autoPlaylists;

  /// No description provided for @autoTag.
  ///
  /// In en, this message translates to:
  /// **'Auto Tag'**
  String get autoTag;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @buyMeCoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy Me a Coffee'**
  String get buyMeCoffee;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates'**
  String get checkingForUpdates;

  /// No description provided for @coffeeSupport.
  ///
  /// In en, this message translates to:
  /// **'Support with a coffee'**
  String get coffeeSupport;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @communityDescription.
  ///
  /// In en, this message translates to:
  /// **'Want to know what\'s happening behind the scenes? Follow us on Instagram for exclusive content and updates.'**
  String get communityDescription;

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Our Community'**
  String get communityTitle;

  /// No description provided for @composer.
  ///
  /// In en, this message translates to:
  /// **'Composer'**
  String get composer;

  /// No description provided for @connectWithUs.
  ///
  /// In en, this message translates to:
  /// **'Connect with us'**
  String get connectWithUs;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @coverArtUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cover art updated'**
  String get coverArtUpdated;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createFirstPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Tap the button above to create your first playlist'**
  String get createFirstPlaylist;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @dateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get dateAdded;

  /// No description provided for @dateModified.
  ///
  /// In en, this message translates to:
  /// **'Date Modified'**
  String get dateModified;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get deletePlaylistConfirm;

  /// No description provided for @deletePlaylistConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this playlist?'**
  String get deletePlaylistConfirmation;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'See details'**
  String get details;

  /// No description provided for @directDonation.
  ///
  /// In en, this message translates to:
  /// **'Direct donation'**
  String get directDonation;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @dontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get dontShowAgain;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @editPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Edit Playlist'**
  String get editPlaylist;

  /// No description provided for @enableArtistSeparation.
  ///
  /// In en, this message translates to:
  /// **'Enable Artist Separation'**
  String get enableArtistSeparation;

  /// No description provided for @enableArtistSeparationDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically split combined artist names'**
  String get enableArtistSeparationDesc;

  /// No description provided for @enjoyingAurora.
  ///
  /// In en, this message translates to:
  /// **'Enjoying Aurora?'**
  String get enjoyingAurora;

  /// No description provided for @enjoyingAuroraDesc.
  ///
  /// In en, this message translates to:
  /// **'If you love using Aurora Music, consider supporting its development. Your support helps keep it free!'**
  String get enjoyingAuroraDesc;

  /// No description provided for @enterPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Enter playlist name'**
  String get enterPlaylistName;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @exclusionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AC/DC'**
  String get exclusionHint;

  /// No description provided for @exclusions.
  ///
  /// In en, this message translates to:
  /// **'Exclusions'**
  String get exclusions;

  /// No description provided for @exclusionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Artist names that should never be split'**
  String get exclusionsDesc;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @exitAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to exit?'**
  String get exitAppConfirm;

  /// No description provided for @exitDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit?'**
  String get exitDesc;

  /// No description provided for @expandLyrics.
  ///
  /// In en, this message translates to:
  /// **'Expand Lyrics'**
  String get expandLyrics;

  /// No description provided for @extraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra Large'**
  String get extraLarge;

  /// No description provided for @favoriteSongs.
  ///
  /// In en, this message translates to:
  /// **'Favorite Songs'**
  String get favoriteSongs;

  /// No description provided for @fileInfo.
  ///
  /// In en, this message translates to:
  /// **'File Info'**
  String get fileInfo;

  /// No description provided for @fileInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Long press on values to copy them'**
  String get fileInfoDesc;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @filePath.
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get filePath;

  /// No description provided for @finalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing'**
  String get finalizing;

  /// No description provided for @finishDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything is ready! We wish you a delightful listening experience!'**
  String get finishDescription;

  /// No description provided for @finishTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get finishTitle;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @followInstagram.
  ///
  /// In en, this message translates to:
  /// **'Follow us on Instagram'**
  String get followInstagram;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get forYou;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @goodQuality.
  ///
  /// In en, this message translates to:
  /// **'Good Quality'**
  String get goodQuality;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gotIt;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @highQuality.
  ///
  /// In en, this message translates to:
  /// **'High Quality'**
  String get highQuality;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @kofi.
  ///
  /// In en, this message translates to:
  /// **'Ko-fi'**
  String get kofi;

  /// No description provided for @buyMeACoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy Me a Coffee'**
  String get buyMeACoffee;

  /// No description provided for @donationNote.
  ///
  /// In en, this message translates to:
  /// **'No pressure - you can always donate later in Settings'**
  String get donationNote;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get languageTitle;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @libraryError.
  ///
  /// In en, this message translates to:
  /// **'Error loading music library'**
  String get libraryError;

  /// No description provided for @libraryLoaded.
  ///
  /// In en, this message translates to:
  /// **'Music library loaded'**
  String get libraryLoaded;

  /// No description provided for @libraryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Library updated'**
  String get libraryUpdated;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @loadingImages.
  ///
  /// In en, this message translates to:
  /// **'Loading images'**
  String get loadingImages;

  /// No description provided for @loadingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Loading library'**
  String get loadingLibrary;

  /// No description provided for @lossless.
  ///
  /// In en, this message translates to:
  /// **'Lossless'**
  String get lossless;

  /// No description provided for @lowQuality.
  ///
  /// In en, this message translates to:
  /// **'Low Quality'**
  String get lowQuality;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @lyricsAhead.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are ahead'**
  String get lyricsAhead;

  /// No description provided for @lyricsBehind.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are behind'**
  String get lyricsBehind;

  /// No description provided for @lyricsSynced.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are synced'**
  String get lyricsSynced;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @metadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadata;

  /// No description provided for @metadataEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Metadata editing requires a third-party app. Changes are shown for preview only.'**
  String get metadataEditInfo;

  /// No description provided for @metadataInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get metadataInfoTitle;

  /// No description provided for @metadataSaved.
  ///
  /// In en, this message translates to:
  /// **'Metadata saved successfully'**
  String get metadataSaved;

  /// No description provided for @moreResults.
  ///
  /// In en, this message translates to:
  /// **'More Results'**
  String get moreResults;

  /// No description provided for @mostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get mostPlayed;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get newPlaylist;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @noAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No albums found'**
  String get noAlbumsFound;

  /// No description provided for @noArtistInfo.
  ///
  /// In en, this message translates to:
  /// **'Artist info not available'**
  String get noArtistInfo;

  /// No description provided for @noArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No artists found'**
  String get noArtistsFound;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data to display'**
  String get noData;

  /// No description provided for @noExclusions.
  ///
  /// In en, this message translates to:
  /// **'No exclusions configured'**
  String get noExclusions;

  /// No description provided for @noLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics not available'**
  String get noLyrics;

  /// No description provided for @noLyricsDesc.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find lyrics for this song'**
  String get noLyricsDesc;

  /// No description provided for @noLyricsFound.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found'**
  String get noLyricsFound;

  /// No description provided for @noPermissionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Without permissions, Aurora Music won\'t be able to access your music library.'**
  String get noPermissionExplanation;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists available'**
  String get noPlaylists;

  /// No description provided for @noPlaylistsCreated.
  ///
  /// In en, this message translates to:
  /// **'No playlists created'**
  String get noPlaylistsCreated;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @noSeparators.
  ///
  /// In en, this message translates to:
  /// **'No separators configured'**
  String get noSeparators;

  /// No description provided for @noSongPlaying.
  ///
  /// In en, this message translates to:
  /// **'No song playing'**
  String get noSongPlaying;

  /// No description provided for @noSongsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No songs available'**
  String get noSongsAvailable;

  /// No description provided for @noSongsInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'No songs in this playlist'**
  String get noSongsInPlaylist;

  /// No description provided for @noUpdateFound.
  ///
  /// In en, this message translates to:
  /// **'No update found'**
  String get noUpdateFound;

  /// No description provided for @noUpper.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noUpper;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @ofMusic.
  ///
  /// In en, this message translates to:
  /// **'of music'**
  String get ofMusic;

  /// No description provided for @onboardingAlbumArt.
  ///
  /// In en, this message translates to:
  /// **'Beautiful Album Art'**
  String get onboardingAlbumArt;

  /// No description provided for @onboardingAlbumArtDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically fetch and display album artwork'**
  String get onboardingAlbumArtDesc;

  /// No description provided for @onboardingAlbumArtwork.
  ///
  /// In en, this message translates to:
  /// **'Album Artwork'**
  String get onboardingAlbumArtwork;

  /// No description provided for @onboardingAlbumArtworkDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetches high-quality album covers to enhance your library'**
  String get onboardingAlbumArtworkDesc;

  /// No description provided for @onboardingAppInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal music companion'**
  String get onboardingAppInfoSubtitle;

  /// No description provided for @onboardingAppInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aurora Music'**
  String get onboardingAppInfoTitle;

  /// No description provided for @onboardingAudioAccess.
  ///
  /// In en, this message translates to:
  /// **'Audio Access'**
  String get onboardingAudioAccess;

  /// No description provided for @onboardingAudioAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Required to play and manage your music library'**
  String get onboardingAudioAccessDesc;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingBeautifulArtwork.
  ///
  /// In en, this message translates to:
  /// **'Beautiful album artwork'**
  String get onboardingBeautifulArtwork;

  /// No description provided for @onboardingBeautifulArtworkDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically fetch and display album artwork in the way it was meant to be seen'**
  String get onboardingBeautifulArtworkDesc;

  /// No description provided for @onboardingBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get onboardingBluetooth;

  /// No description provided for @onboardingBluetoothDesc.
  ///
  /// In en, this message translates to:
  /// **'Needed to connect to bluetooth devices'**
  String get onboardingBluetoothDesc;

  /// No description provided for @onboardingChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get onboardingChooseLanguage;

  /// No description provided for @onboardingCompletionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start enjoying your music'**
  String get onboardingCompletionSubtitle;

  /// No description provided for @onboardingCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get onboardingCompletionTitle;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get onboardingDarkMode;

  /// No description provided for @onboardingDarkModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy on the eyes in low light'**
  String get onboardingDarkModeDesc;

  /// No description provided for @onboardingDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure automatic downloads'**
  String get onboardingDownloadsSubtitle;

  /// No description provided for @onboardingDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Settings'**
  String get onboardingDownloadsTitle;

  /// No description provided for @onboardingDynamicColors.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Colors'**
  String get onboardingDynamicColors;

  /// No description provided for @onboardingDynamicColorsDesc.
  ///
  /// In en, this message translates to:
  /// **'Match system wallpaper colors'**
  String get onboardingDynamicColorsDesc;

  /// No description provided for @onboardingGrantPermissions.
  ///
  /// In en, this message translates to:
  /// **'Grant Permissions'**
  String get onboardingGrantPermissions;

  /// No description provided for @onboardingInternetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How Aurora Music uses the internet'**
  String get onboardingInternetSubtitle;

  /// No description provided for @onboardingInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'Internet Usage'**
  String get onboardingInternetTitle;

  /// No description provided for @onboardingLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get onboardingLightMode;

  /// No description provided for @onboardingLightModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Bright and clean interface'**
  String get onboardingLightModeDesc;

  /// No description provided for @onboardingLocalLibrary.
  ///
  /// In en, this message translates to:
  /// **'Local Music Library'**
  String get onboardingLocalLibrary;

  /// No description provided for @onboardingLocalLibraryDesc.
  ///
  /// In en, this message translates to:
  /// **'Play your music files stored on your device'**
  String get onboardingLocalLibraryDesc;

  /// No description provided for @onboardingLocalMusic.
  ///
  /// In en, this message translates to:
  /// **'Music on your device'**
  String get onboardingLocalMusic;

  /// No description provided for @onboardingLocalMusicDesc.
  ///
  /// In en, this message translates to:
  /// **'Have your music files in the palm of your hand'**
  String get onboardingLocalMusicDesc;

  /// No description provided for @onboardingLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get onboardingLyrics;

  /// No description provided for @onboardingLyricsDesc.
  ///
  /// In en, this message translates to:
  /// **'Downloads synchronized lyrics for your songs'**
  String get onboardingLyricsDesc;

  /// No description provided for @onboardingLyricsSupport.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Support'**
  String get onboardingLyricsSupport;

  /// No description provided for @onboardingLyricsSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'View synchronized lyrics while listening'**
  String get onboardingLyricsSupportDesc;

  /// No description provided for @onboardingMaterialDesign.
  ///
  /// In en, this message translates to:
  /// **'Material You Design'**
  String get onboardingMaterialDesign;

  /// No description provided for @onboardingMaterialDesignDesc.
  ///
  /// In en, this message translates to:
  /// **'Dynamic colors that adapt to your preferences'**
  String get onboardingMaterialDesignDesc;

  /// No description provided for @onboardingMusicMetadata.
  ///
  /// In en, this message translates to:
  /// **'Music Metadata'**
  String get onboardingMusicMetadata;

  /// No description provided for @onboardingMusicMetadataDesc.
  ///
  /// In en, this message translates to:
  /// **'Gets artist info, album details, and track information'**
  String get onboardingMusicMetadataDesc;

  /// No description provided for @onboardingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboardingNotifications;

  /// No description provided for @onboardingNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Show playback controls and updates'**
  String get onboardingNotificationsDesc;

  /// No description provided for @onboardingOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get onboardingOptional;

  /// No description provided for @onboardingPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aurora Music needs these permissions to work properly'**
  String get onboardingPermissionsSubtitle;

  /// No description provided for @onboardingPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant Permissions'**
  String get onboardingPermissionsTitle;

  /// No description provided for @onboardingPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is important. All music files stay on your device.'**
  String get onboardingPrivacyNote;

  /// No description provided for @onboardingRequesting.
  ///
  /// In en, this message translates to:
  /// **'Requesting...'**
  String get onboardingRequesting;

  /// No description provided for @onboardingRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get onboardingRequired;

  /// No description provided for @onboardingAudioRequired.
  ///
  /// In en, this message translates to:
  /// **'Audio access is required to continue. Please grant the permission above.'**
  String get onboardingAudioRequired;

  /// No description provided for @onboardingSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get onboardingSelectLanguage;

  /// No description provided for @onboardingSetupExperience.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set up your experience'**
  String get onboardingSetupExperience;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingSmartPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Smart Playlists'**
  String get onboardingSmartPlaylists;

  /// No description provided for @onboardingSmartPlaylistsDesc.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your music collections'**
  String get onboardingSmartPlaylistsDesc;

  /// No description provided for @onboardingStartListening.
  ///
  /// In en, this message translates to:
  /// **'Start Listening'**
  String get onboardingStartListening;

  /// No description provided for @onboardingStorageAccess.
  ///
  /// In en, this message translates to:
  /// **'Storage Access'**
  String get onboardingStorageAccess;

  /// No description provided for @onboardingStorageAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Required to read music files from your device'**
  String get onboardingStorageAccessDesc;

  /// No description provided for @onboardingSyncBackup.
  ///
  /// In en, this message translates to:
  /// **'Sync & Backup'**
  String get onboardingSyncBackup;

  /// No description provided for @onboardingSyncBackupDesc.
  ///
  /// In en, this message translates to:
  /// **'Optional cloud sync for playlists and preferences'**
  String get onboardingSyncBackupDesc;

  /// No description provided for @onboardingThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a theme that suits your style'**
  String get onboardingThemeSubtitle;

  /// No description provided for @onboardingThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize Your Look'**
  String get onboardingThemeTitle;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aurora Music'**
  String get onboardingWelcome;

  /// No description provided for @beta_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Beta Testing Program'**
  String get beta_welcome_title;

  /// No description provided for @beta_welcome_thanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for joining our beta testing program and helping us improve Aurora Music.'**
  String get beta_welcome_thanks;

  /// No description provided for @beta_expect_bugs_title.
  ///
  /// In en, this message translates to:
  /// **'Expect Bugs'**
  String get beta_expect_bugs_title;

  /// No description provided for @beta_expect_bugs_desc.
  ///
  /// In en, this message translates to:
  /// **'You may encounter crashes or unexpected behavior. This is a testing version.'**
  String get beta_expect_bugs_desc;

  /// No description provided for @beta_feedback_title.
  ///
  /// In en, this message translates to:
  /// **'Feedback Matters'**
  String get beta_feedback_title;

  /// No description provided for @beta_feedback_desc.
  ///
  /// In en, this message translates to:
  /// **'Your reports and suggestions help us make the app better for everyone.'**
  String get beta_feedback_desc;

  /// No description provided for @beta_updates_title.
  ///
  /// In en, this message translates to:
  /// **'Frequent Updates'**
  String get beta_updates_title;

  /// No description provided for @beta_updates_desc.
  ///
  /// In en, this message translates to:
  /// **'New features and fixes are released regularly as we continue development.'**
  String get beta_updates_desc;

  /// No description provided for @beta_build_label.
  ///
  /// In en, this message translates to:
  /// **'Beta Build'**
  String get beta_build_label;

  /// No description provided for @oneTimeSupport.
  ///
  /// In en, this message translates to:
  /// **'Quick one-time support'**
  String get oneTimeSupport;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open in File Manager'**
  String get openFolder;

  /// No description provided for @openFolderInfo.
  ///
  /// In en, this message translates to:
  /// **'Use your file manager to navigate to this location'**
  String get openFolderInfo;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @ownTimer.
  ///
  /// In en, this message translates to:
  /// **'Own timer'**
  String get ownTimer;

  /// No description provided for @paypal.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get paypal;

  /// No description provided for @permDeny.
  ///
  /// In en, this message translates to:
  /// **'Permissions denied'**
  String get permDeny;

  /// No description provided for @permissionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Aurora Music needs these permissions to function properly. Please grant the permissions in the app settings.'**
  String get permissionExplanation;

  /// No description provided for @permissionLater.
  ///
  /// In en, this message translates to:
  /// **'You can grant permissions later in app settings'**
  String get permissionLater;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// No description provided for @permissionsDescription.
  ///
  /// In en, this message translates to:
  /// **'To provide you with the best experience, Aurora Music needs access to certain features of your device.'**
  String get permissionsDescription;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Now, the important stuff'**
  String get permissionsTitle;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @possibleReasons.
  ///
  /// In en, this message translates to:
  /// **'Possible reasons:'**
  String get possibleReasons;

  /// No description provided for @preparingToScan.
  ///
  /// In en, this message translates to:
  /// **'Preparing to scan'**
  String get preparingToScan;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'At Aurora Music, we take your privacy seriously. We collect anonymous data to improve your experience and enhance our services. By using the app, you agree to our Privacy Policy.'**
  String get privacyDescription;

  /// No description provided for @privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing to use this app, you agree to our Privacy Policy.'**
  String get privacyNotice;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'Read our Privacy Policy'**
  String get privacyPolicyLink;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Matters'**
  String get privacyTitle;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @qualityDesc.
  ///
  /// In en, this message translates to:
  /// **'Audio quality based on format and bitrate'**
  String get qualityDesc;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccess;

  /// No description provided for @reasonFormat.
  ///
  /// In en, this message translates to:
  /// **'File format doesn\'t support metadata editing'**
  String get reasonFormat;

  /// No description provided for @reasonPermissions.
  ///
  /// In en, this message translates to:
  /// **'Storage permissions not granted'**
  String get reasonPermissions;

  /// No description provided for @reasonReadonly.
  ///
  /// In en, this message translates to:
  /// **'File is read-only or on external storage'**
  String get reasonReadonly;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @recentlyPlayedAlbums.
  ///
  /// In en, this message translates to:
  /// **'Recently played albums'**
  String get recentlyPlayedAlbums;

  /// No description provided for @recentlyPlayedArtists.
  ///
  /// In en, this message translates to:
  /// **'Recently played artists'**
  String get recentlyPlayedArtists;

  /// No description provided for @recentlyPlayedSongs.
  ///
  /// In en, this message translates to:
  /// **'Recently played songs'**
  String get recentlyPlayedSongs;

  /// No description provided for @recommendedApps.
  ///
  /// In en, this message translates to:
  /// **'Recommended apps:'**
  String get recommendedApps;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// No description provided for @refreshLyrics.
  ///
  /// In en, this message translates to:
  /// **'Refresh Lyrics'**
  String get refreshLyrics;

  /// No description provided for @releaseToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Release to refresh'**
  String get releaseToRefresh;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeSong.
  ///
  /// In en, this message translates to:
  /// **'Remove Song'**
  String get removeSong;

  /// No description provided for @removeSongConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove this song from the playlist?'**
  String get removeSongConfirmation;

  /// No description provided for @removeSongs.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get removeSongs;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get renamePlaylist;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetArtistSeparationDesc.
  ///
  /// In en, this message translates to:
  /// **'This will restore all default separators and exclusions.'**
  String get resetArtistSeparationDesc;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @sampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get sampleRate;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @saveChangesDesc.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save your changes?'**
  String get saveChangesDesc;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get saveFailed;

  /// No description provided for @saveFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Unable to save metadata to this file.'**
  String get saveFailedDesc;

  /// No description provided for @savingMetadata.
  ///
  /// In en, this message translates to:
  /// **'Saving metadata...'**
  String get savingMetadata;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get scanFailed;

  /// No description provided for @scanningSongs.
  ///
  /// In en, this message translates to:
  /// **'Scanning songs'**
  String get scanningSongs;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchAlbums.
  ///
  /// In en, this message translates to:
  /// **'Search albums'**
  String get searchAlbums;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Search artists'**
  String get searchArtists;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @searchLyrics.
  ///
  /// In en, this message translates to:
  /// **'Search Lyrics'**
  String get searchLyrics;

  /// No description provided for @searchMetadata.
  ///
  /// In en, this message translates to:
  /// **'Search metadata'**
  String get searchMetadata;

  /// No description provided for @searchTracks.
  ///
  /// In en, this message translates to:
  /// **'Search tracks'**
  String get searchTracks;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @selectArtist.
  ///
  /// In en, this message translates to:
  /// **'Select artist'**
  String get selectArtist;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get selected;

  /// No description provided for @selectPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Select Playlist'**
  String get selectPlaylist;

  /// No description provided for @separator.
  ///
  /// In en, this message translates to:
  /// **'Separator'**
  String get separator;

  /// No description provided for @separatorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. / or feat.'**
  String get separatorHint;

  /// No description provided for @separators.
  ///
  /// In en, this message translates to:
  /// **'Separators'**
  String get separators;

  /// No description provided for @separatorsDesc.
  ///
  /// In en, this message translates to:
  /// **'Characters used to split artist names'**
  String get separatorsDesc;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @setMinutes.
  ///
  /// In en, this message translates to:
  /// **'Set minutes'**
  String get setMinutes;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutApp.
  ///
  /// In en, this message translates to:
  /// **'About Aurora Music'**
  String get settingsAboutApp;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsCacheCleared;

  /// No description provided for @settingsCacheInfo.
  ///
  /// In en, this message translates to:
  /// **'Cache Information'**
  String get settingsCacheInfo;

  /// No description provided for @settingsCacheInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'View storage usage'**
  String get settingsCacheInfoDesc;

  /// No description provided for @settingsCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get settingsCheckingUpdates;

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsCheckUpdatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Get latest version'**
  String get settingsCheckUpdatesDesc;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove all cached data'**
  String get settingsClearCacheDesc;

  /// No description provided for @settingsClearCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'All cached data will be deleted and rebuilt as needed.'**
  String get settingsClearCacheMessage;

  /// No description provided for @settingsClearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache?'**
  String get settingsClearCacheTitle;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsDarkModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark theme'**
  String get settingsDarkModeDesc;

  /// No description provided for @settingsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get settingsDisabled;

  /// No description provided for @settingsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingsEnabled;

  /// No description provided for @settingsGapless.
  ///
  /// In en, this message translates to:
  /// **'Gapless Playback'**
  String get settingsGapless;

  /// No description provided for @settingsGaplessDesc.
  ///
  /// In en, this message translates to:
  /// **'Seamless track transitions'**
  String get settingsGaplessDesc;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsMaterialYou.
  ///
  /// In en, this message translates to:
  /// **'Material You'**
  String get settingsMaterialYou;

  /// No description provided for @settingsMaterialYouDesc.
  ///
  /// In en, this message translates to:
  /// **'Dynamic colors from wallpaper'**
  String get settingsMaterialYouDesc;

  /// No description provided for @settingsNormalization.
  ///
  /// In en, this message translates to:
  /// **'Volume Normalization'**
  String get settingsNormalization;

  /// No description provided for @settingsNormalizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Consistent volume levels'**
  String get settingsNormalizationDesc;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available!'**
  String get settingsUpdateAvailable;

  /// No description provided for @settingsUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get settingsUpToDate;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @showChangelog.
  ///
  /// In en, this message translates to:
  /// **'Show Changelog'**
  String get showChangelog;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @songInfo.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfo;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @songsLoaded.
  ///
  /// In en, this message translates to:
  /// **'Songs loaded'**
  String get songsLoaded;

  /// No description provided for @standardQuality.
  ///
  /// In en, this message translates to:
  /// **'Standard Quality'**
  String get standardQuality;

  /// No description provided for @startType.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search'**
  String get startType;

  /// No description provided for @storagePermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'To edit metadata, Aurora Music needs permission to manage files. Please grant \'All files access\' in settings.'**
  String get storagePermissionNeeded;

  /// No description provided for @suggestedArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists For You'**
  String get suggestedArtists;

  /// No description provided for @suggestedTracks.
  ///
  /// In en, this message translates to:
  /// **'Suggested Tracks'**
  String get suggestedTracks;

  /// No description provided for @supportAurora.
  ///
  /// In en, this message translates to:
  /// **'Support Aurora'**
  String get supportAurora;

  /// No description provided for @supportAuroraBtn.
  ///
  /// In en, this message translates to:
  /// **'Support Aurora'**
  String get supportAuroraBtn;

  /// No description provided for @supportAuroraDescShort.
  ///
  /// In en, this message translates to:
  /// **'Help keep the app free'**
  String get supportAuroraDescShort;

  /// No description provided for @supportAuroraMessage.
  ///
  /// In en, this message translates to:
  /// **'Help keep Aurora Music free and support future development. Every contribution means a lot!'**
  String get supportAuroraMessage;

  /// No description provided for @supportAuroraTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Aurora Music'**
  String get supportAuroraTitle;

  /// No description provided for @tapAddToAddSongs.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add songs'**
  String get tapAddToAddSongs;

  /// No description provided for @testArtistString.
  ///
  /// In en, this message translates to:
  /// **'Test artist string'**
  String get testArtistString;

  /// No description provided for @testSeparation.
  ///
  /// In en, this message translates to:
  /// **'Test Separation'**
  String get testSeparation;

  /// No description provided for @thankYouSupport.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support!'**
  String get thankYouSupport;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @topResult.
  ///
  /// In en, this message translates to:
  /// **'Top Result'**
  String get topResult;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @trackInfo.
  ///
  /// In en, this message translates to:
  /// **'Track Info'**
  String get trackInfo;

  /// No description provided for @trackInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the edit icon to modify track information'**
  String get trackInfoDesc;

  /// No description provided for @trackInfoEditDesc.
  ///
  /// In en, this message translates to:
  /// **'Edit fields below, then tap the check icon to save'**
  String get trackInfoEditDesc;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get unknownArtist;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Library update failed'**
  String get updateFailed;

  /// No description provided for @updateMessage.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get updateMessage;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @userSettings.
  ///
  /// In en, this message translates to:
  /// **'User settings'**
  String get userSettings;

  /// No description provided for @versionCheckError.
  ///
  /// In en, this message translates to:
  /// **'New version couldn\'t be checked'**
  String get versionCheckError;

  /// No description provided for @viewArtist.
  ///
  /// In en, this message translates to:
  /// **'View artist'**
  String get viewArtist;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Embark on a journey with your music. Listen like never before. Elevate your music experience to a new level.'**
  String get welcomeDescription;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aurora Music'**
  String get welcomeTitle;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whatsNew;

  /// No description provided for @whats_new.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whats_new;

  /// No description provided for @view_changelog.
  ///
  /// In en, this message translates to:
  /// **'View changelog and new features'**
  String get view_changelog;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @yesUpper.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesUpper;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
  String get yourLibrary;

  /// No description provided for @yourPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Your Playlists'**
  String get yourPlaylists;

  /// No description provided for @homeLayout.
  ///
  /// In en, this message translates to:
  /// **'Home Layout'**
  String get homeLayout;

  /// No description provided for @homeLayoutDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize section order on Home tab'**
  String get homeLayoutDesc;

  /// No description provided for @customizeHomeTab.
  ///
  /// In en, this message translates to:
  /// **'Customize Home Tab'**
  String get customizeHomeTab;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder sections'**
  String get dragToReorder;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @resetLayoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset layout to default?'**
  String get resetLayoutConfirm;

  /// No description provided for @resetLayoutMessage.
  ///
  /// In en, this message translates to:
  /// **'This will restore the original section order and visibility.'**
  String get resetLayoutMessage;

  /// No description provided for @sectionVisibility.
  ///
  /// In en, this message translates to:
  /// **'Toggle section visibility'**
  String get sectionVisibility;

  /// No description provided for @listeningHistory.
  ///
  /// In en, this message translates to:
  /// **'Listening History'**
  String get listeningHistory;

  /// No description provided for @libraryStats.
  ///
  /// In en, this message translates to:
  /// **'Library Stats'**
  String get libraryStats;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @downloadPreferences.
  ///
  /// In en, this message translates to:
  /// **'Download Preferences'**
  String get downloadPreferences;

  /// No description provided for @downloadPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what to download for your music'**
  String get downloadPreferencesSubtitle;

  /// No description provided for @downloadAlbumArt.
  ///
  /// In en, this message translates to:
  /// **'Download Album Art'**
  String get downloadAlbumArt;

  /// No description provided for @downloadAlbumArtDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically fetch album covers for all songs'**
  String get downloadAlbumArtDesc;

  /// No description provided for @downloadLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Lyrics'**
  String get downloadLyricsTitle;

  /// No description provided for @downloadLyricsDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetch synchronized lyrics when available'**
  String get downloadLyricsDesc;

  /// No description provided for @wifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Only'**
  String get wifiOnly;

  /// No description provided for @wifiOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Download assets only when connected to Wi-Fi'**
  String get wifiOnlyDesc;

  /// No description provided for @autoDownloadNewSongs.
  ///
  /// In en, this message translates to:
  /// **'Auto-Download for New Songs'**
  String get autoDownloadNewSongs;

  /// No description provided for @autoDownloadNewSongsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically download assets when adding new songs'**
  String get autoDownloadNewSongsDesc;

  /// No description provided for @downloadSettingsNote.
  ///
  /// In en, this message translates to:
  /// **'You can change these settings later in the app preferences.'**
  String get downloadSettingsNote;

  /// No description provided for @downloadContent.
  ///
  /// In en, this message translates to:
  /// **'Download Content?'**
  String get downloadContent;

  /// No description provided for @downloadContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assets will be downloaded as you use the app'**
  String get downloadContentSubtitle;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @feedback_title.
  ///
  /// In en, this message translates to:
  /// **'Enjoying Aurora Music?'**
  String get feedback_title;

  /// No description provided for @feedback_description.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps make Aurora Music better! Found a bug or have an idea? We\'d love to hear from you.'**
  String get feedback_description;

  /// No description provided for @report_bug.
  ///
  /// In en, this message translates to:
  /// **'Report Bug'**
  String get report_bug;

  /// No description provided for @suggest_feature.
  ///
  /// In en, this message translates to:
  /// **'Suggest Feature'**
  String get suggest_feature;

  /// No description provided for @maybe_later.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybe_later;

  /// No description provided for @dont_ask_again.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get dont_ask_again;

  /// No description provided for @send_feedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get send_feedback;

  /// No description provided for @send_feedback_desc.
  ///
  /// In en, this message translates to:
  /// **'Report bugs or suggest features'**
  String get send_feedback_desc;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @settingsHighendUi.
  ///
  /// In en, this message translates to:
  /// **'High-end UI'**
  String get settingsHighendUi;

  /// No description provided for @settingsHighendUiDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable advanced visual effects and animations'**
  String get settingsHighendUiDesc;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get restartRequired;

  /// No description provided for @restartRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'The app needs to restart to apply the UI mode change. Restart now?'**
  String get restartRequiredDesc;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get restartNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
