// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get aboutArtist => 'कलाकार के बारे में';

  @override
  String get add => 'जोड़ें';

  @override
  String get addedToPlaylist => 'प्लेलिस्ट में जोड़ा गया';

  @override
  String addedToNamedPlaylist(String name) {
    return '$name में जोड़ा गया';
  }

  @override
  String get addExclusion => 'अपवाद जोड़ें';

  @override
  String get addSeparator => 'विभाजक जोड़ें';

  @override
  String get addSongs => 'गीत जोड़ें';

  @override
  String get addSongsToPlaylist => 'प्लेलिस्ट में गीत जोड़ें';

  @override
  String get addToPlaylist => 'प्लेलिस्ट में जोड़ें';

  @override
  String get adjustSync => 'सिंक समायोजित करें';

  @override
  String get album => 'एल्बम';

  @override
  String get albums => 'एल्बम';

  @override
  String get allSongs => 'सभी गीत';

  @override
  String get appName => 'ऑरोरा संगीत';

  @override
  String get artist => 'कलाकार';

  @override
  String get artistName => 'कलाकार का नाम';

  @override
  String get artists => 'कलाकार';

  @override
  String get artistSeparation => 'कलाकार पृथक्करण';

  @override
  String get artistSeparationDesc =>
      'कई कलाकारों को कैसे विभाजित किया जाए, कॉन्फ़िगर करें';

  @override
  String get audioQuality => 'ध्वनि गुणवत्ता';

  @override
  String get audioQualityDesc => 'ऑडियो फ़ाइल के तकनीकी विनिर्देश';

  @override
  String get auroraMusic => 'ऑरोरा संगीत';

  @override
  String get autoPlaylists => 'स्वचालित प्लेलिस्ट';

  @override
  String get autoTag => 'स्वचालित टैग';

  @override
  String get smartPlaylists => 'स्मार्ट प्लेलिस्ट';

  @override
  String get createSmartPlaylist => 'स्मार्ट प्लेलिस्ट बनाएँ…';

  @override
  String get editSmartPlaylist => 'स्मार्ट प्लेलिस्ट संपादित करें';

  @override
  String get smartPlaylistNameHint => 'प्लेलिस्ट का नाम';

  @override
  String get smartPlaylistRules => 'नियम';

  @override
  String get addRule => 'नियम जोड़ें';

  @override
  String get saveSmartPlaylist => 'बचाएँ';

  @override
  String get matchAll => 'सभी नियमों से मेल करें';

  @override
  String get matchAny => 'किसी भी नियम से मेल खाएं';

  @override
  String get limitResultsLabel => 'परिणाम सीमित करें';

  @override
  String get noLimit => 'कोई सीमा नहीं';

  @override
  String get deleteSmartPlaylistConfirm =>
      'क्या इस स्मार्ट प्लेलिस्ट को हटाना है? यह केवल सहेजे गए नियमों को हटाता है — आपके गाने प्रभावित नहीं होते।';

  @override
  String smartPlaylistPreviewCount(int count) {
    return 'अभी $count गाने मिल रहे हैं';
  }

  @override
  String get saveAsClip => 'क्लिप के रूप में सहेजें';

  @override
  String get generatingClip => 'क्लिप उत्पन्न हो रहा है…';

  @override
  String get clipDuration => 'क्लिप की अवधि';

  @override
  String get clipStartOffset => 'आरंभ बिंदु';

  @override
  String get saveClip => 'क्लिप सहेजें';

  @override
  String get clipSavedToDevice => 'क्लिप डिवाइस पर सहेजी गई';

  @override
  String get clipSaveFailed => 'क्लिप सहेज नहीं सके। कृपया फिर से प्रयास करें।';

  @override
  String get playlistSavedToDevice => 'प्लेलिस्ट डिवाइस पर सहेजी गई';

  @override
  String get trackTags => 'ट्रैक टैग्स';

  @override
  String get editTrackTags => 'टैग संपादित करें';

  @override
  String get addTrackTag => 'टैग जोड़ें';

  @override
  String get noTrackTagsYet =>
      'अभी तक कोई टैग नहीं है। इस ट्रैक के किसी हिस्से पर सीधे जाने के लिए एक टैग जोड़ें।';

  @override
  String get trackTagNameHint => 'उदाहरण के लिए गीत का शीर्षक या कलाकार';

  @override
  String get trackTagPosition => 'पद';

  @override
  String get useCurrentPosition => 'वर्तमान स्थिति का उपयोग करें';

  @override
  String get isThisASet => 'इस ट्रैक में टाइमस्टैम्प जोड़ें';

  @override
  String get tagPartsForEasySwitching =>
      'किसी भी क्षण को चिह्नित करें — अध्याय, मुख्य अंश, बुकमार्क, या कुछ भी।';

  @override
  String get tagThisTrack => 'टैग जोड़ें';

  @override
  String get pasteSetlist => 'टाइमस्टैम्प आयात करें';

  @override
  String get pasteSetlistDialogTitle => 'समय-मुद्राएँ आयात करें';

  @override
  String get pasteSetlistHint =>
      'यहाँ टाइमस्टैम्प पेस्ट करें, जैसे\n0:00 परिचय\n3:45 अध्याय का नाम';

  @override
  String get importAction => 'आयात';

  @override
  String tagsImportedMessage(int count) {
    return 'आयातित $count टैग';
  }

  @override
  String get noTagsFoundInPaste =>
      'पेस्ट किए गए टेक्स्ट में कोई टाइमस्टैम्प नहीं मिला।';

  @override
  String get bitrate => 'बिटरेट';

  @override
  String get buyMeCoffee => 'मुझे कॉफ़ी पिलाएँ';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get coffeeSupport => 'कॉफ़ी के साथ समर्थन';

  @override
  String get composer => 'रचनाकार';

  @override
  String get connectWithUs => 'हमसे जुड़ें';

  @override
  String get copied => 'नकल किया गया';

  @override
  String get copy => 'प्रतिलिपि';

  @override
  String get create => 'बनाएँ';

  @override
  String get createFirstPlaylist =>
      'अपना पहला प्लेलिस्ट बनाने के लिए ऊपर दिए गए बटन पर टैप करें।';

  @override
  String get createPlaylist => 'प्लेलिस्ट बनाएँ';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get dateAdded => 'जोड़ा गया दिनांक';

  @override
  String get dateModified => 'संशोधित तिथि';

  @override
  String get delete => 'मिटायें';

  @override
  String get deletePlaylist => 'प्लेलिस्ट हटाएँ';

  @override
  String get deletePlaylistConfirm => 'क्या आप वास्तव में हटाना चाहते हैं?';

  @override
  String get deletePlaylistConfirmation =>
      'क्या आप इस प्लेलिस्ट को हटाना चाहते हैं?';

  @override
  String get deselectAll => 'सभी को अनचुनें';

  @override
  String get details => 'विवरण देखें';

  @override
  String get discard => 'फेंको';

  @override
  String get dontShowAgain => 'फिर से न दिखाएँ';

  @override
  String get duration => 'अवधि';

  @override
  String get enableArtistSeparation => 'कलाकार पृथक्करण सक्षम करें';

  @override
  String get enableArtistSeparationDesc =>
      'संयुक्त कलाकार नामों को स्वचालित रूप से विभाजित करें';

  @override
  String get enjoyingAurora => 'क्या आप ऑरोरा का आनंद ले रहे हैं?';

  @override
  String get enjoyingAuroraDesc =>
      'यदि आप ऑरोरा म्यूजिक का उपयोग करना पसंद करते हैं, तो इसके विकास का समर्थन करने पर विचार करें। आपका समर्थन इसे मुफ्त बनाए रखने में मदद करता है!';

  @override
  String get error => 'त्रुटि';

  @override
  String get exclusionHint => 'उदा. एसी/डीसी';

  @override
  String get exclusions => 'अपवाद';

  @override
  String get exclusionsDesc =>
      'कलाकार के नाम जिन्हें कभी विभाजित नहीं किया जाना चाहिए';

  @override
  String get exit => 'निकास';

  @override
  String get exitApp => 'ऐप बंद करें';

  @override
  String get exitAppConfirm => 'क्या आप बाहर निकलना चाहते हैं?';

  @override
  String get expandLyrics => 'गीत के बोल प्रदर्शित करें';

  @override
  String get extraLarge => 'अति विशाल';

  @override
  String get favoriteSongs => 'पसंदीदा गाने';

  @override
  String get fileInfo => 'फ़ाइल जानकारी';

  @override
  String get fileInfoDesc =>
      'मूल्यों को कॉपी करने के लिए उन पर लंबा दबाव डालें।';

  @override
  String get fileName => 'फ़ाइल का नाम';

  @override
  String get filePath => 'फ़ाइल पथ';

  @override
  String get folder => 'फ़ोल्डर';

  @override
  String get folders => 'फ़ोल्डर';

  @override
  String get fontSize => 'फ़ॉन्ट का आकार';

  @override
  String get format => 'स्वरूप';

  @override
  String get forYou => 'आपके लिए';

  @override
  String get general => 'सामान्य';

  @override
  String get genre => 'शैली';

  @override
  String get getStarted => 'शुरू करें';

  @override
  String get goodQuality => 'अच्छी गुणवत्ता';

  @override
  String get gotIt => 'समझ गया!';

  @override
  String get grantPermission => 'अनुमति दें';

  @override
  String get highQuality => 'उच्च गुणवत्ता';

  @override
  String get home => 'होम';

  @override
  String get kofi => 'को-फ़ी';

  @override
  String get buyMeACoffee => 'मुझे कॉफ़ी पिलाएँ';

  @override
  String get donationNote =>
      'कोई दबाव नहीं - आप सेटिंग्स में बाद में भी दान कर सकते हैं।';

  @override
  String get language => 'भाषा';

  @override
  String get large => 'बड़ा';

  @override
  String get later => 'बाद में';

  @override
  String get library => 'पुस्तकालय';

  @override
  String get libraryError => 'संगीत लाइब्रेरी लोड करने में त्रुटि';

  @override
  String get libraryLoaded => 'संगीत पुस्तकालय लोड हो गया';

  @override
  String get libraryUpdated => 'पुस्तकालय अपडेट किया गया';

  @override
  String get loading => 'लोड हो रहा है';

  @override
  String get loadingLibrary => 'लाइब्रेरी लोड हो रही है';

  @override
  String get lossless => 'हानिरहित';

  @override
  String get lowQuality => 'निम्न गुणवत्ता';

  @override
  String get lyrics => 'गीत के बोल';

  @override
  String get lyricsAhead => 'गीत के बोल आगे हैं';

  @override
  String get lyricsBehind => 'गीत के बोल पीछे हैं।';

  @override
  String get lyricsSynced => 'गीत के बोल सिंक हो गए हैं।';

  @override
  String get maybeLater => 'शायद बाद में';

  @override
  String get medium => 'मध्यम';

  @override
  String get metadata => 'मेटाडेटा';

  @override
  String get metadataSaved => 'मेटाडेटा सफलतापूर्वक सहेजा गया';

  @override
  String get metadataApplied => 'मेटाडेटा सफलतापूर्वक डाउनलोड हो गया';

  @override
  String get metadataDownloadFailed =>
      'डाउनलोड विफल हो गया। अपना कनेक्शन जांचें और फिर से प्रयास करें।';

  @override
  String get chooseArtworkFromDevice => 'डिवाइस से चुनें';

  @override
  String get mostPlayed => 'सबसे ज़्यादा बजाए गए';

  @override
  String get newPlaylist => 'नई प्लेलिस्ट';

  @override
  String get next => 'अगला';

  @override
  String get no => 'नहीं';

  @override
  String get noAlbumsFound => 'कोई एल्बम नहीं मिला';

  @override
  String get noArtistInfo => 'कलाकार की जानकारी उपलब्ध नहीं है';

  @override
  String get noArtistsFound => 'कोई कलाकार नहीं मिला';

  @override
  String get noData => 'प्रदर्शित करने के लिए कोई डेटा नहीं है';

  @override
  String get noExclusions => 'कोई अपवाद कॉन्फ़िगर नहीं किए गए हैं';

  @override
  String get noLyrics => 'गीत के बोल उपलब्ध नहीं हैं';

  @override
  String get noLyricsDesc => 'हम इस गाने के बोल नहीं ढूंढ पाए।';

  @override
  String get noLyricsFound => 'कोई गीत के बोल नहीं मिले';

  @override
  String get noPermissionExplanation =>
      'अनुमति के बिना, ऑरोरा म्यूजिक आपकी संगीत लाइब्रेरी तक पहुँच नहीं पाएगा।';

  @override
  String get noPlaylists => 'कोई प्लेलिस्ट उपलब्ध नहीं हैं';

  @override
  String get noResults => 'कोई परिणाम नहीं मिला';

  @override
  String get noSeparators => 'कोई विभाजक कॉन्फ़िगर नहीं किए गए हैं';

  @override
  String get noSongPlaying => 'कोई गीत नहीं बज रहा है';

  @override
  String get noSongsAvailable => 'कोई गीत उपलब्ध नहीं हैं';

  @override
  String get noSongsInPlaylist => 'इस प्लेलिस्ट में कोई गीत नहीं हैं';

  @override
  String get nowPlaying => 'अब चल रहा है';

  @override
  String get onboardingAlbumArt => 'सुंदर एल्बम कला';

  @override
  String get onboardingAlbumArtwork => 'एल्बम की कलाकृति';

  @override
  String get onboardingAlbumArtworkDesc =>
      'आपकी लाइब्रेरी को बेहतर बनाने के लिए उच्च-गुणवत्ता वाले एल्बम कवर लाता है।';

  @override
  String get onboardingAppInfoSubtitle => 'आपका व्यक्तिगत संगीत साथी';

  @override
  String get onboardingAppInfoTitle => 'अरोरा म्यूजिक में आपका स्वागत है';

  @override
  String get onboardingAudioAccess => 'ऑडियो पहुँच';

  @override
  String get onboardingAudioAccessDesc =>
      'आपकी संगीत लाइब्रेरी को चलाने और प्रबंधित करने के लिए आवश्यक';

  @override
  String get onboardingBack => 'वापस';

  @override
  String get onboardingBeautifulArtwork => 'सुंदर एल्बम कवर';

  @override
  String get onboardingBeautifulArtworkDesc =>
      'स्वचालित रूप से एल्बम की कलाकृति प्राप्त करें और उसे वैसे ही प्रदर्शित करें जैसे इसे देखा जाना चाहिए।';

  @override
  String get onboardingBluetooth => 'ब्लूटूथ';

  @override
  String get onboardingBluetoothDesc =>
      'ब्लूटूथ डिवाइसों से कनेक्ट करने के लिए आवश्यक';

  @override
  String get onboardingChooseLanguage => 'अपनी भाषा चुनें';

  @override
  String get languageNotListedHint =>
      'आपकी भाषा सूचीबद्ध नहीं है? अंग्रेज़ी चुनें और अगले पृष्ठ पर जाएँ।';

  @override
  String get onboardingCompletionSubtitle =>
      'अपने संगीत का आनंद लेना शुरू करें';

  @override
  String get onboardingCompletionTitle => 'आप पूरी तरह तैयार हैं!';

  @override
  String get onboardingContinue => 'जारी रखें';

  @override
  String get onboardingDynamicColors => 'गतिशील रंग';

  @override
  String get onboardingDynamicColorsDesc => 'मैच सिस्टम वॉलपेपर रंग';

  @override
  String get onboardingGrantPermissions => 'अनुमति दें';

  @override
  String get onboardingInternetSubtitle =>
      'ऑरोरा म्यूजिक इंटरनेट का उपयोग कैसे करता है';

  @override
  String get onboardingInternetTitle => 'इंटरनेट का उपयोग';

  @override
  String get onboardingLocalMusic => 'आपके डिवाइस पर संगीत';

  @override
  String get onboardingLocalMusicDesc =>
      'अपने संगीत फ़ाइलों को अपने हाथ में रखें';

  @override
  String get onboardingLyrics => 'गीत के बोल';

  @override
  String get onboardingLyricsDesc =>
      'आपके गीतों के लिए सिंक्रोनाइज़्ड बोल डाउनलोड करें';

  @override
  String get onboardingLyricsSupport => 'गीत-लेखन सहायता';

  @override
  String get onboardingLyricsSupportDesc =>
      'सुनते समय सिंक्रोनाइज़ किए गए बोल देखें';

  @override
  String get onboardingMaterialDesign => 'मैटेरियल यू डिज़ाइन';

  @override
  String get onboardingMaterialDesignDesc =>
      'आपकी पसंद के अनुसार अनुकूलित होने वाले गतिशील रंग';

  @override
  String get onboardingMusicMetadata => 'संगीत मेटाडेटा';

  @override
  String get onboardingMusicMetadataDesc =>
      'कलाकार की जानकारी, एल्बम का विवरण और ट्रैक की जानकारी प्राप्त करता है।';

  @override
  String get onboardingNotifications => 'सूचनाएँ';

  @override
  String get onboardingNotificationsDesc => 'प्लेबैक नियंत्रण और अपडेट दिखाएँ';

  @override
  String get onboardingOptional => 'वैकल्पिक';

  @override
  String get onboardingPermissionsSubtitle =>
      'Aurora Music को ठीक से काम करने के लिए इन अनुमतियों की आवश्यकता है।';

  @override
  String get onboardingPermissionsTitle => 'अनुमति दें';

  @override
  String get onboardingPrivacyNote =>
      'आपकी गोपनीयता महत्वपूर्ण है। सभी संगीत फ़ाइलें आपके डिवाइस पर ही रहती हैं।';

  @override
  String get onboardingRequesting => 'अनुरोध कर रहा है...';

  @override
  String get onboardingRequired => 'आवश्यक';

  @override
  String get onboardingAudioRequired =>
      'जारी रखने के लिए ऑडियो एक्सेस आवश्यक है। कृपया ऊपर दी गई अनुमति प्रदान करें।';

  @override
  String get onboardingSelectLanguage => 'अपनी पसंदीदा भाषा चुनें';

  @override
  String get onboardingSmartPlaylists => 'स्मार्ट प्लेलिस्ट';

  @override
  String get onboardingSmartPlaylistsDesc =>
      'अपने संगीत संग्रह बनाएँ और प्रबंधित करें';

  @override
  String get onboardingStartListening => 'सुनना शुरू करें';

  @override
  String get onboardingStorageAccess => 'भंडारण पहुँच';

  @override
  String get onboardingStorageAccessDesc =>
      'आपके डिवाइस से संगीत फ़ाइलें पढ़ने के लिए आवश्यक';

  @override
  String get onboardingVisualizerAccess => 'दृश्यीकरण उपकरण';

  @override
  String get onboardingVisualizerAccessDesc =>
      'यह विज़ुअलाइज़र को आपके डिवाइस के ऑडियो सत्र को लाइव बार स्पेक्ट्रम के लिए पढ़ने की अनुमति देता है। कोई ऑडियो कभी रिकॉर्ड नहीं किया जाता।';

  @override
  String get onboardingThemeSubtitle => 'अपनी शैली के अनुरूप एक थीम चुनें';

  @override
  String get onboardingThemeTitle => 'अपनी लुक को कस्टमाइज़ करें';

  @override
  String get beta_welcome_title => 'बीटा परीक्षण कार्यक्रम';

  @override
  String get beta_welcome_thanks =>
      'हमारे बीटा परीक्षण कार्यक्रम में शामिल होने और ऑरोरा म्यूजिक को बेहतर बनाने में मदद करने के लिए धन्यवाद।';

  @override
  String get beta_expect_bugs_title => 'बग्स की उम्मीद करें';

  @override
  String get beta_expect_bugs_desc =>
      'आप क्रैश या अनपेक्षित व्यवहार का सामना कर सकते हैं। यह एक परीक्षण संस्करण है।';

  @override
  String get beta_feedback_title => 'प्रतिक्रिया मायने रखती है';

  @override
  String get beta_feedback_desc =>
      'आपकी रिपोर्टें और सुझाव हमें ऐप को सभी के लिए बेहतर बनाने में मदद करते हैं।';

  @override
  String get beta_updates_title => 'बार-बार अपडेट';

  @override
  String get beta_updates_desc =>
      'हम विकास जारी रखते हुए नई सुविधाएँ और सुधार नियमित रूप से जारी करते हैं।';

  @override
  String get oneTimeSupport => 'त्वरित एक-बार सहायता';

  @override
  String get openFolder => 'फ़ाइल मैनेजर में खोलें';

  @override
  String get openFolderInfo =>
      'इस स्थान पर नेविगेट करने के लिए अपने फ़ाइल प्रबंधक का उपयोग करें।';

  @override
  String get ownTimer => 'अपना टाइमर';

  @override
  String get permDeny => 'अनुमति अस्वीकार कर दी गई';

  @override
  String get permissionExplanation =>
      'Aurora Music को ठीक से काम करने के लिए इन अनुमतियों की आवश्यकता है। कृपया ऐप सेटिंग्स में ये अनुमतियाँ प्रदान करें।';

  @override
  String get permissionLater =>
      'आप बाद में ऐप सेटिंग्स में अनुमतियाँ दे सकते हैं।';

  @override
  String get permissionRequired => 'अनुमति आवश्यक';

  @override
  String get playAll => 'सभी चलाएँ';

  @override
  String get playingFrom => 'से खेलना';

  @override
  String get playlist => 'प्लेलिस्ट';

  @override
  String get playlistName => 'प्लेलिस्ट का नाम';

  @override
  String get playlists => 'प्लेलिस्ट';

  @override
  String get possibleReasons => 'संभावित कारण:';

  @override
  String get privacyNotice =>
      'इस ऐप का उपयोग जारी रखकर, आप हमारी गोपनीयता नीति से सहमत हैं।';

  @override
  String get privacyPolicyLink => 'हमारी गोपनीयता नीति पढ़ें';

  @override
  String get quality => 'गुणवत्ता';

  @override
  String get qualityDesc => 'फ़ॉर्मेट और बिटरेट के आधार पर ऑडियो गुणवत्ता';

  @override
  String get queue => 'कतार';

  @override
  String get queueEmpty => 'कतार खाली है';

  @override
  String get reasonFormat =>
      'फ़ाइल प्रारूप मेटाडेटा संपादन का समर्थन नहीं करता है।';

  @override
  String get reasonPermissions => 'भंडारण अनुमतियाँ प्रदान नहीं की गईं';

  @override
  String get reasonReadonly => 'फ़ाइल केवल-पठन या बाहरी भंडारण पर है।';

  @override
  String get recentlyAdded => 'हाल ही में जोड़ा गया';

  @override
  String get recentlyPlayed => 'हाल ही में खेला गया';

  @override
  String get recentlyPlayedArtists => 'हाल ही में बजाए गए कलाकार';

  @override
  String get recentlyPlayedSongs => 'हाल ही में बजाए गए गाने';

  @override
  String get refreshing => 'ताज़गी...';

  @override
  String get refreshLyrics => 'गीत के बोल ताज़ा करें';

  @override
  String get remove => 'हटाएँ';

  @override
  String get removeSong => 'गाना हटाएँ';

  @override
  String get removeSongConfirmation =>
      'क्या इस गाने को प्लेलिस्ट से हटाया जाए?';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get renamePlaylist => 'प्लेलिस्ट का नाम बदलें';

  @override
  String get repeat => 'दोहराएँ';

  @override
  String get reset => 'पुनः आरंभ करें';

  @override
  String get resetArtistSeparationDesc =>
      'यह सभी डिफ़ॉल्ट विभाजक और अपवर्गों को पुनर्स्थापित करेगा।';

  @override
  String get resetToDefaults => 'डिफ़ॉल्ट पर रीसेट करें';

  @override
  String get result => 'परिणाम';

  @override
  String get results => 'परिणाम';

  @override
  String get retry => 'दोबारा प्रयास करें';

  @override
  String get sampleRate => 'नमूना दर';

  @override
  String get save => 'बचाएँ';

  @override
  String get saveChanges => 'बदलाव सहेजें';

  @override
  String get saveChangesDesc => 'क्या आप अपने बदलाव सहेजना चाहते हैं?';

  @override
  String get saveFailed => 'बचाई गई असफल';

  @override
  String get saveFailedDesc => 'इस फ़ाइल में मेटाडेटा सहेजने में असमर्थ।';

  @override
  String get scanFailed => 'स्कैन विफल हो गया';

  @override
  String get scanningSongs => 'गीतों को स्कैन करना';

  @override
  String get search => 'खोजें';

  @override
  String get searchAlbums => 'एल्बम खोजें';

  @override
  String get searchArtists => 'कलाकार खोजें';

  @override
  String get searchFailed => 'खोज असफल हुई';

  @override
  String get searchLyrics => 'गीत के बोल खोजें';

  @override
  String get searchMetadata => 'मेटाडेटा खोजें';

  @override
  String get searchTracks => 'ट्रैक खोजें';

  @override
  String get selectAll => 'सभी चुनें';

  @override
  String get selectArtist => 'कलाकार चुनें';

  @override
  String get selected => 'चुना हुआ';

  @override
  String get selectPlaylist => 'प्लेलिस्ट चुनें';

  @override
  String get separator => 'विभाजक';

  @override
  String get separatorHint => 'उदाहरण के लिए / या फीचर्ड';

  @override
  String get separators => 'विभाजक';

  @override
  String get set => 'सेट';

  @override
  String get setMinutes => 'निर्धारित मिनट';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get settingsAbout => 'बारे में';

  @override
  String get settingsAboutApp => 'अरोरा म्यूजिक के बारे में';

  @override
  String get settingsAboutSubtitle => 'संस्करण, प्रतिक्रिया और अपडेट';

  @override
  String get settingsAccentColor => 'उल्लेखनीय रंग';

  @override
  String get settingsAppearance => 'दृश्यमानता';

  @override
  String get settingsAppearanceSubtitle => 'थीम, रंग और लेआउट';

  @override
  String get settingsAudio => 'ऑडियो';

  @override
  String get settingsBackground => 'पृष्ठभूमि';

  @override
  String get settingsCacheCleared => 'कैश साफ़ हो गया';

  @override
  String get settingsCacheInfo => 'कैश जानकारी';

  @override
  String get settingsCacheInfoDesc => 'भंडारण उपयोग देखें';

  @override
  String get settingsCheckingUpdates => 'अपडेट्स की जाँच...';

  @override
  String get settingsCheckUpdates => 'अपडेट्स के लिए जाँच करें';

  @override
  String get settingsCheckUpdatesDesc => 'नवीनतम संस्करण प्राप्त करें';

  @override
  String get settingsClearCache => 'कैश साफ़ करें';

  @override
  String get settingsClearCacheDesc => 'सभी कैश किए गए डेटा को हटाएँ';

  @override
  String get settingsClearCacheMessage =>
      'सभी कैश किए गए डेटा को आवश्यकतानुसार हटा दिया जाएगा और पुनर्निर्मित किया जाएगा।';

  @override
  String get settingsClearCacheTitle => 'कैश साफ़ करें?';

  @override
  String get settingsDataWindow => 'डेटा विंडो';

  @override
  String get settingsDataWindowDesc => 'रिकैप स्क्रीन कितनी पीछे तक दिखती है';

  @override
  String get settingsGapless => 'बिना रुकावट प्लेबैक';

  @override
  String get settingsGaplessDesc => 'निर्बाध ट्रैक संक्रमण';

  @override
  String get settingsAutomix => 'ऑटोमिक्स';

  @override
  String get settingsAutomixDesc =>
      'गानों के बीच अपने आप एक सहज प्रवाह बनाता है';

  @override
  String get playlistAutomixTitle => 'ऑटोमिक्स';

  @override
  String get playlistAutomixSubtitle =>
      'इस प्लेलिस्ट के लिए DJ स्टाइल स्‍वचालित संक्रमण';

  @override
  String get playlistAutomixOn => 'चालू';

  @override
  String get playlistAutomixOff => 'बंद';

  @override
  String get playlistAutomixBeatMatching => 'बीट मिलान';

  @override
  String get playlistAutomixHarmonicMixing => 'हार्मोनिक मिश्रण';

  @override
  String get playlistAutomixTempoMatching => 'टेम्पो मिलान';

  @override
  String get playlistAutomixTransitionDuration => 'संक्रमण अवधि';

  @override
  String get playlistAutomixAutomatic => 'स्‍वचालित';

  @override
  String playlistAutomixAnalyzing(int current, int total) {
    return 'प्लेलिस्ट का विश्लेषण… $current / $total ट्रैक';
  }

  @override
  String get settingsCrossfade => 'क्रॉसफ़ेड';

  @override
  String get settingsCrossfadeDesc =>
      'एक ट्रैक के अंत को दूसरे ट्रैक में सहजता से मिलाएँ।';

  @override
  String get crossfadeDuration => 'क्रॉसफ़ेड अवधि';

  @override
  String get crossfadeDurationDesc =>
      'ट्रैकों के बीच का ओवरलैप कितनी देर तक रहता है';

  @override
  String get settingsInsights => 'अंतर्दृष्टियाँ';

  @override
  String get settingsInsightsSubtitle => 'सुनने का पुनरावलोकन काल';

  @override
  String get settingsLast7Days => 'पिछले 7 दिन';

  @override
  String get settingsLast30Days => 'पिछले 30 दिन';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsLayout => 'लेआउट';

  @override
  String get settingsLibraryFolders => 'पुस्तकालय फ़ोल्डर';

  @override
  String get settingsLibraryFoldersSubtitle =>
      'स्कैन फ़ोल्डरों को शामिल करें या बाहर रखें';

  @override
  String get settingsMaterialYou => 'आपकी सामग्री';

  @override
  String get settingsMaterialYouDesc => 'वॉलपेपर से गतिशील रंग';

  @override
  String get settingsMonthlyRecap => 'मासिक सारांश';

  @override
  String get settingsMonthlyRecapDesc =>
      'हर महीने एक बैनर दिखाएँ (साप्ताहिक की तुलना में प्राथमिकता लेता है)';

  @override
  String get settingsNormalization => 'आयतन सामान्यीकरण';

  @override
  String get settingsNormalizationDesc =>
      'सुसंगत वॉल्यूम स्तर · आपकी फ़ाइलों में ReplayGain टैग्स की आवश्यकता है';

  @override
  String get playbackSpeed => 'प्लेबैक गति';

  @override
  String get playbackSpeedDesc => 'ऑडियो प्लेबैक दर समायोजित करें';

  @override
  String get adjustPitchWithSpeed => 'गति के साथ पिच समायोजित करें';

  @override
  String get adjustPitchWithSpeedDesc =>
      'बंद होने पर, पिच शिफ्ट के बिना टेम्पो बदलता है।';

  @override
  String get settingsPlayback => 'प्लेबैक';

  @override
  String get settingsPlaybackSubtitle => 'गति, अंतराल रहित और सामान्यीकरण';

  @override
  String get settingsRecapBannerDesc =>
      'बैनर आपके पहले खेलने से गिने गए प्रत्येक नए सप्ताह या महीने की शुरुआत में होम स्क्रीन पर दिखाई देता है। \"बाद में\" पर टैप करने से यह सत्र के लिए छिपा रहता है; \"दिखाएँ\" पर टैप करने से इसे देखा हुआ माना जाता है।';

  @override
  String get settingsRecapContent => 'सारांश सामग्री';

  @override
  String get settingsRecapContentDesc =>
      'यह नियंत्रित करता है कि जब आप रिकैप स्क्रीन को मैन्युअली या बैनर के माध्यम से खोलते हैं, तो वह कितनी पिछली जानकारी दिखाती है।';

  @override
  String get settingsPreviewRecap => 'अग्रिम पुनरावलोकन सारांश';

  @override
  String get settingsPreviewRecapDesc =>
      'वर्तमान सेटिंग्स के साथ आपका सारांश अभी कैसा दिखता है देखें।';

  @override
  String get settingsRecapSchedule => 'सारांश अनुसूची';

  @override
  String get settingsStorage => 'भंडारण';

  @override
  String settingsCacheItems(String count) {
    return '$count आइटम';
  }

  @override
  String get settingsMemoryCache => 'मेमोरी कैश';

  @override
  String get settingsStorageSubtitle => 'कैश और मीडिया फ़ाइलें';

  @override
  String get settingsTheme => 'थीम';

  @override
  String get settingsTools => 'उपकरण';

  @override
  String get settingsResetSetup => 'सेटअप रीसेट करें';

  @override
  String get settingsResetSetupDesc =>
      'ऑनबोर्डिंग प्रक्रिया को फिर से शुरू करें';

  @override
  String get settingsUpdateAvailable => 'अपडेट उपलब्ध है!';

  @override
  String get settingsUpToDate => 'आप अप-टू-डेट हैं';

  @override
  String get settingsWeeklyRecap => 'साप्ताहिक सारांश';

  @override
  String get settingsWeeklyRecapDesc =>
      'अपनी पहली प्ले के बाद हर हफ्ते एक बैनर दिखाएँ';

  @override
  String get settingsVersion => 'संस्करण';

  @override
  String get share => 'साझा करें';

  @override
  String get showChangelog => 'परिवर्तन-इतिहास दिखाएँ';

  @override
  String get shuffle => 'शफल';

  @override
  String get size => 'आकार';

  @override
  String get sleepTimer => 'नींद टाइमर';

  @override
  String get small => 'छोटा';

  @override
  String get songInfo => 'गीत की जानकारी';

  @override
  String get songs => 'गीत';

  @override
  String get songsLoaded => 'गीत लोड हुए';

  @override
  String get standardQuality => 'मानक गुणवत्ता';

  @override
  String get startType => 'खोजने के लिए टाइप करना शुरू करें';

  @override
  String get storagePermissionNeeded =>
      'मेटाडेटा संपादित करने के लिए, ऑरोरा म्यूजिक को फ़ाइलों का प्रबंधन करने की अनुमति चाहिए। कृपया सेटिंग्स में \'सभी फ़ाइलों तक पहुँच\' प्रदान करें।';

  @override
  String get suggestedArtists => 'कलाकार आपके लिए';

  @override
  String get suggestedTracks => 'सुझाए गए ट्रैक';

  @override
  String get supportAurora => 'अरोरा का समर्थन करें';

  @override
  String get supportAuroraBtn => 'अरोरा का समर्थन करें';

  @override
  String get supportAuroraDescShort => 'ऐप को मुफ्त बनाए रखने में मदद करें';

  @override
  String get supportAuroraMessage =>
      'Aurora Music को मुफ्त बनाए रखने और भविष्य के विकास का समर्थन करने में मदद करें। हर योगदान बहुत मायने रखता है!';

  @override
  String get supportAuroraTitle => 'अरोरा म्यूजिक का समर्थन करें';

  @override
  String get tapAddToAddSongs => 'गीत जोड़ने के लिए + पर टैप करें';

  @override
  String get reorderSongs => 'गीतों को फिर से क्रमबद्ध करें';

  @override
  String get done => 'हो गया';

  @override
  String get thankYouSupport => 'आपके समर्थन के लिए धन्यवाद!';

  @override
  String get theme => 'थीम';

  @override
  String get title => 'शीर्षक';

  @override
  String get topResult => 'शीर्ष परिणाम';

  @override
  String get total => 'कुल';

  @override
  String get track => 'ट्रैक';

  @override
  String get trackInfo => 'ट्रैक की जानकारी';

  @override
  String get trackInfoDesc =>
      'ट्रैक की जानकारी संशोधित करने के लिए संपादन आइकन पर टैप करें।';

  @override
  String get trackInfoEditDesc =>
      'नीचे दिए गए फ़ील्ड्स को संपादित करें, फिर सहेजने के लिए चेक आइकन पर टैप करें।';

  @override
  String get tracks => 'ट्रैक';

  @override
  String get unknown => 'अज्ञात';

  @override
  String get unknownArtist => 'अज्ञात कलाकार';

  @override
  String get updateAvailable => 'अपडेट उपलब्ध है';

  @override
  String get updateMessage => 'एक नया संस्करण उपलब्ध है';

  @override
  String get updateNow => 'अभी अपडेट करें';

  @override
  String get viewArtist => 'कलाकार देखें';

  @override
  String get viewDetails => 'विवरण देखें';

  @override
  String get welcomeBack => 'फिर से स्वागत है';

  @override
  String get whatsNew => 'क्या नया है';

  @override
  String get view_changelog => 'चेंजलॉग और नई सुविधाएँ देखें';

  @override
  String get year => 'वर्ष';

  @override
  String get yes => 'हाँ';

  @override
  String get yourLibrary => 'आपकी लाइब्रेरी';

  @override
  String get yourPlaylists => 'आपकी प्लेलिस्ट';

  @override
  String get homeLayout => 'घर का लेआउट';

  @override
  String get homeLayoutDesc => 'होम टैब पर अनुभाग का क्रम अनुकूलित करें';

  @override
  String get customizeHomeTab => 'होम टैब को अनुकूलित करें';

  @override
  String get dragToReorder => 'अनुभागों को पुनः व्यवस्थित करने के लिए खींचें';

  @override
  String get resetToDefault => 'डिफ़ॉल्ट पर रीसेट करें';

  @override
  String get resetLayoutConfirm => 'लेआउट को डिफ़ॉल्ट पर रीसेट करें?';

  @override
  String get resetLayoutMessage =>
      'यह मूल अनुभाग क्रम और दृश्यता को बहाल करेगा।';

  @override
  String get sectionVisibility => 'अनुभाग दृश्यता टॉगल करें';

  @override
  String get listeningHistory => 'श्रवण इतिहास';

  @override
  String get libraryStats => 'पुस्तकालय आँकड़े';

  @override
  String get back => 'वापस';

  @override
  String get continueButton => 'जारी रखें';

  @override
  String get skip => 'छोड़ें';

  @override
  String get feedback_title => 'क्या आप ऑरोरा म्यूजिक का आनंद ले रहे हैं?';

  @override
  String get maybe_later => 'शायद बाद में';

  @override
  String get send_feedback => 'प्रतिक्रिया भेजें';

  @override
  String get send_feedback_desc => 'बग रिपोर्ट करें या फीचर सुझाएँ';

  @override
  String get contributeTranslations => 'अनुवाद योगदान करें';

  @override
  String get contributeTranslationsDesc =>
      'Crowdin पर Aurora Music का अनुवाद करने में मदद करें';

  @override
  String get contributeTranslationsTitle => 'हमारा अनुवाद करने में मदद करें';

  @override
  String get contributeTranslationsSubtitle =>
      'हमारे अद्भुत समुदाय की बदौलत ऑरोरा म्यूजिक कई भाषाओं में उपलब्ध है। ऐप को अपनी भाषा में अनुवाद करके हमें और अधिक उपयोगकर्ताओं तक पहुँचने में मदद करें — शुरू करने में केवल कुछ ही मिनट लगते हैं।';

  @override
  String get contributeTranslationsOpenCrowdin => 'क्राउडइन खोलें';

  @override
  String get close => 'बंद करें';

  @override
  String get settingsHighendUi => 'उच्च-स्तरीय यूआई';

  @override
  String get settingsHighendUiDesc =>
      'उन्नत दृश्य प्रभाव और एनिमेशन सक्षम करें';

  @override
  String get restartRequired => 'पुनरारंभ आवश्यक';

  @override
  String get restartRequiredDesc =>
      'UI मोड परिवर्तन लागू करने के लिए ऐप को पुनः आरंभ करने की आवश्यकता है। क्या अभी पुनः आरंभ करें?';

  @override
  String get restartNow => 'अब पुनः आरंभ करें';

  @override
  String get clearUpcoming => 'स्पष्ट आगामी';

  @override
  String get addToQueue => 'कतार में जोड़ें';

  @override
  String get playNext => 'अगला चलाएँ';

  @override
  String get removeFromQueue => 'कतार से हटाएँ';

  @override
  String get play => 'बजाएँ';

  @override
  String get viewAlbum => 'एल्बम देखें';

  @override
  String get shuffleAll => 'सभी को मिलाएँ';

  @override
  String get noSongsFound => 'कोई गीत नहीं मिला';

  @override
  String get noFoldersFound => 'कोई फ़ोल्डर नहीं मिला';

  @override
  String get deleteSong => 'गाना हटाएँ';

  @override
  String get modifySystemSettingsPermission =>
      'खुले हुए पृष्ठ में \"सिस्टम सेटिंग्स संशोधित करें\" की अनुमति दें, फिर से प्रयास करें।';

  @override
  String errorMessage(String message) {
    return 'त्रुटि: $message';
  }

  @override
  String songsAddedToQueue(int count) {
    return '$count गाने कतार में जोड़े गए';
  }

  @override
  String songAddedToQueue(String title) {
    return '$title कतार में जोड़ा गया';
  }

  @override
  String songSetAsRingtone(String title) {
    return '$title रिंगटोन के रूप में सेट करें';
  }

  @override
  String failedToSetRingtone(String error) {
    return 'रिंगटोन सेट करने में असफल: $error';
  }

  @override
  String deleteSongConfirm(String title) {
    return 'क्या आप अपने डिवाइस से \"$title\" हटाना चाहते हैं? इसे वापस नहीं किया जा सकता।';
  }

  @override
  String songDeleted(String title) {
    return '\"$title\" हटाया गया';
  }

  @override
  String failedToDelete(String error) {
    return 'मिटने में असफल: $error';
  }

  @override
  String songCount(int count) {
    return '$count गाने';
  }

  @override
  String get badgeNew => 'नया';

  @override
  String get paused => 'रुक गया';

  @override
  String get readyToPlay => 'खेलने के लिए तैयार';

  @override
  String get tapSongToStartListening =>
      'सुनना शुरू करने के लिए किसी गाने पर टैप करें';

  @override
  String get clearCachedLyrics => 'कैश किए गए बोल साफ़ करें';

  @override
  String lyricsCleared(String title) {
    return '\"$title\" के लिए कैश किए गए गीत साफ़ कर दिए गए।';
  }

  @override
  String get noLyricsCached => 'इस गीत के लिए कोई कैश किए गए बोल नहीं मिले।';

  @override
  String get setAsRingtone => 'रिंगटोन के रूप में सेट करें';

  @override
  String get songInfoEdit => 'गाने की जानकारी / संपादित करें';

  @override
  String get goToAlbum => 'एल्बम पर जाएँ';

  @override
  String get goToArtist => 'कलाकार के पास जाएँ';

  @override
  String get deleteFromDevice => 'डिवाइस से हटाएँ';

  @override
  String get checkOutThisSong => 'यह गाना देखो!';

  @override
  String get backgroundLowEndStyle => 'पृष्ठभूमि शैली';

  @override
  String get backgroundLowEndStyleDesc => 'ऐप का बैकग्राउंड कैसा दिखता है';

  @override
  String get backgroundBlobs => 'एनिमेटेड ब्लॉब्स';

  @override
  String get backgroundSolid => 'एक रंग';

  @override
  String get backgroundHighEndStyle => 'अब पृष्ठभूमि में चल रहा है';

  @override
  String get backgroundHighEndStyleDesc =>
      'अब चल रहा है स्क्रीन में पृष्ठभूमि शैली';

  @override
  String get backgroundBlurredArtwork => 'धुंधली कलाकृति';

  @override
  String get accentColor => 'उल्लेखनीय रंग';

  @override
  String get accentColorDesc => 'ऐप का मुख्य रंग चुनें';

  @override
  String get backgroundBlur => 'पृष्ठभूमि धुंधलापन';

  @override
  String get backgroundBlurDesc => 'कलाकृति धुंधलापन तीव्रता';

  @override
  String get backgroundDarkness => 'पृष्ठभूमि अंधकार';

  @override
  String get backgroundDarknessDesc => 'कलाकृति पर ओवरले पारदर्शिता';

  @override
  String get microphoneAccessNeeded => 'माइक्रोफ़ोन की पहुँच आवश्यक है';

  @override
  String get microphoneAccessDesc =>
      'Aurora को लाइव विज़ुअलाइज़र के लिए आपके डिवाइस के ऑडियो सत्र तक पहुँचने हेतु माइक्रोफ़ोन की अनुमति चाहिए। कोई भी ऑडियो कभी रिकॉर्ड या संग्रहीत नहीं किया जाता।';

  @override
  String get recapWeek => 'सप्ताह';

  @override
  String get recapMonth => 'माह';

  @override
  String get recapPeriodWeek => 'सप्ताह';

  @override
  String get recapPeriodMonth => 'महीना';

  @override
  String get recapWeekly => 'साप्ताहिक';

  @override
  String get recapMonthly => 'मासिक';

  @override
  String get recapIntroAppName => 'ऑरोरा संगीत';

  @override
  String recapIntroTitle(String period) {
    return 'आपका $period पुनरावलोकन';
  }

  @override
  String get recapIntroSubtitle => 'चलो देखते हैं कि तुम क्या सुन रहे थे।';

  @override
  String recapPlayedEyebrow(String period) {
    return 'यह $period तुमने संगीत बजाया';
  }

  @override
  String get recapTimeSingular => 'समय';

  @override
  String get recapTimePlural => 'बार';

  @override
  String get recapListenedForEyebrow => 'तुमने सुनने के लिए';

  @override
  String get recapListenedForLabel => 'संगीत का';

  @override
  String get recapTopTrackEyebrow => 'आपका #1 ट्रैक';

  @override
  String get recapPlays => 'निकालता है';

  @override
  String get recapTopTracksTitle => 'शीर्ष ट्रैक';

  @override
  String get recapTopArtistEyebrow => 'आपका शीर्ष कलाकार';

  @override
  String get recapTopArtistsTitle => 'शीर्ष कलाकार';

  @override
  String get recapNothingToWrap => 'अभी तक लपेटने के लिए कुछ नहीं है';

  @override
  String recapNothingToWrapBody(String period) {
    return 'इस $period पर कुछ संगीत बजाओ और वापस आओ।';
  }

  @override
  String get recapSwipeUp => 'ऊपर स्वाइप करें';

  @override
  String get recapYourSoundLabel => 'आपकी आवाज़';

  @override
  String get recapYouListenMost => 'आप सबसे ज़्यादा सुनते हैं';

  @override
  String recapOnDay(String day) {
    return 'पर ${day}s';
  }

  @override
  String recapAroundTime(String time) {
    return 'के आसपास $time';
  }

  @override
  String get recapVibesHitDifferent => 'तभी माहौल कुछ अलग हो गया।';

  @override
  String get recapThatsAWrap => 'काम पूरा हुआ';

  @override
  String recapInNumbers(String period) {
    return 'आपके $period\nआंकड़ों में';
  }

  @override
  String get recapNumberOneTrack => '#1 ट्रैक';

  @override
  String get recapStatTotalPlays => 'कुल प्ले';

  @override
  String get recapStatTimeListened => 'सुने गए समय';

  @override
  String get recapStatUniqueTracks => 'अनूठे ट्रैक';

  @override
  String get recapStatTopArtist => 'शीर्ष कलाकार';

  @override
  String get recapDone => 'हो गया';

  @override
  String get recapWeekdayMonday => 'सोमवार';

  @override
  String get recapWeekdayTuesday => 'मंगलवार';

  @override
  String get recapWeekdayWednesday => 'बुधवार';

  @override
  String get recapWeekdayThursday => 'गुरुवार';

  @override
  String get recapWeekdayFriday => 'शुक्रवार';

  @override
  String get recapWeekdaySaturday => 'शनिवार';

  @override
  String get recapWeekdaySunday => 'रविवार';

  @override
  String get recapBannerTitle => 'संगीत का सारांश यहाँ है';

  @override
  String get recapBannerShow => 'दिखाएँ';

  @override
  String get recapBannerLater => 'बाद में';

  @override
  String get eqTitle => 'समानाकार';

  @override
  String get eqOn => 'चालू';

  @override
  String get eqOff => 'बंद';

  @override
  String get eqNotAvailable => 'इस डिवाइस पर इक्वलाइज़र उपलब्ध नहीं है।';

  @override
  String get eqOpenSystem => 'ओपन सिस्टम इक्वलाइज़र';

  @override
  String get eqSavePreset => 'प्रीसेट सहेजें';

  @override
  String get eqPresetNameHint => 'उदा. मेरा बास बूस्ट';

  @override
  String get eqPresetNameEmpty => 'नाम खाली नहीं हो सकता।';

  @override
  String eqPresetNameBuiltIn(String name) {
    return '\"$name\" एक अंतर्निर्मित प्रीसेट नाम है।';
  }

  @override
  String get eqResetAllBands => 'सभी बैंड रीसेट करें';

  @override
  String get eqPresetsLabel => 'पूर्वनिर्धारित सेटिंग्स';

  @override
  String get eqYourPresetsLabel => 'आपके प्रीसेट्स';

  @override
  String get eqSaveCurrent => 'वर्तमान सहेजें';

  @override
  String get eqSettingsSubtitle =>
      'प्रत्येक बैंड के अनुसार ऑडियो आवृत्तियों को समायोजित करें';

  @override
  String get eqEmptyPresets =>
      'अपनी ध्वनि समायोजित करें, फिर \"वर्तमान सहेजें\" पर टैप करें।';

  @override
  String get lyricsHint =>
      'अन-सिंक किए हुए बोल यहाँ पेस्ट करें…\n\nप्रति छंद एक पंक्ति।';

  @override
  String get lyricsSelectLrcFile => 'कृपया एक .lrc फ़ाइल चुनें';

  @override
  String get lyricsNoLyricsInFile => 'उस फ़ाइल में कोई गीत के बोल नहीं मिले।';

  @override
  String importFailed(String error) {
    return 'आयात विफल: $error';
  }

  @override
  String get lyricsImportTooltip => '.lrc फ़ाइल आयात करें';

  @override
  String get importPlaylistM3u => 'प्लेलिस्ट आयात करें (.m3u)';

  @override
  String get setSyncFolder => 'सिंक फ़ोल्डर सेट करें…';

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get searchPlaylists => 'प्लेलिस्ट खोजें…';

  @override
  String get pleaseSelectM3uFile => 'कृपया एक .m3u या .m3u8 फ़ाइल चुनें।';

  @override
  String get noMatchingSongsForPlaylist =>
      'उस प्लेलिस्ट के लिए कोई मेल खाने वाले गाने नहीं मिले।';

  @override
  String importedPlaylist(String name, int count) {
    return 'आयातित \"$name\" ($count गाने)';
  }

  @override
  String playlistsSyncWith(String folder) {
    return 'प्लेलिस्ट्स $folder के साथ सिंक होंगी।';
  }

  @override
  String couldNotSetSyncFolder(String error) {
    return 'सिंक फ़ोल्डर सेट नहीं हो सका: $error';
  }

  @override
  String get setSyncFolderFirst => 'पहले सिंक फ़ोल्डर सेट करें';

  @override
  String get playlistsSynced => 'प्लेलिस्ट सिंक हो गईं';

  @override
  String get alreadyUpToDate => 'पहले से ही अद्यतित';

  @override
  String syncFailed(String error) {
    return 'सिंक विफल: $error';
  }

  @override
  String exportFailed(String error) {
    return 'निर्यात विफल: $error';
  }

  @override
  String get searchFolders => 'खोज फ़ोल्डर…';

  @override
  String get songInfoPath => 'मार्ग';

  @override
  String get closeVisualiser => 'दृश्यीकरण बंद करें';

  @override
  String get previousMode => 'पिछला मोड';

  @override
  String get nextMode => 'अगला मोड';

  @override
  String get sortBy => 'के अनुसार क्रमबद्ध करें';

  @override
  String get colorTheme => 'रंग योजना';

  @override
  String get insightsTotalPlays => 'कुल प्ले';

  @override
  String get insightsTracksHeard => 'ट्रैक सुने हुए';

  @override
  String get insightsEstListening => 'अनुमानित। सुनना';

  @override
  String get dismiss => 'अस्वीकार करें';

  @override
  String updateVersionAvailable(String version) {
    return 'संस्करण $version अब उपलब्ध है।';
  }

  @override
  String get updateNewVersionAvailable => 'एक नया संस्करण अब उपलब्ध है।';

  @override
  String get lyricsPasteLyricsTitle => 'गीत के बोल चिपकाएँ';

  @override
  String get lyricsUseLyrics => 'गीत के बोल का उपयोग करें';

  @override
  String get lyricsPaste => 'पेस्ट';

  @override
  String get lyricsNoLyricsYet => 'अभी तक कोई गीत के बोल नहीं';

  @override
  String get lyricsPasteToGetStarted =>
      'शुरू करने के लिए गीत के बोल पेस्ट करें';

  @override
  String get lyricsNoTimestampsYet =>
      'अभी तक कोई टाइमस्टैम्प नहीं — जब गाना चल रहा हो तो स्टैम्प बटन दबाएँ।';

  @override
  String get lyricsAllLinesStampedHint =>
      'सभी लाइनें स्टैम्प हो गईं — समाप्त करने के लिए सेव पर टैप करें।';

  @override
  String get lyricsAllStamped => '✓ सभी लाइनें मुद्रित';

  @override
  String get lyricsPasteFirst => 'पहले बोल चिपकाएँ';

  @override
  String lyricsTapToStamp(int current, int total) {
    return '⏱ स्टैम्प लाइन $current / $total पर टैप करें';
  }

  @override
  String get lyricsNextLabel => 'अगला';

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
