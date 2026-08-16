// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get aboutArtist => 'Об Исполнителе';

  @override
  String get add => 'Добавить';

  @override
  String get addedToPlaylist => 'Добавлено в плейлист';

  @override
  String addedToNamedPlaylist(String name) {
    return 'Добавлено в $name';
  }

  @override
  String get addExclusion => 'Добавить Исключение';

  @override
  String get addSeparator => 'Добавить Разделитель';

  @override
  String get addSongs => 'Добавить Песни';

  @override
  String get addSongsToPlaylist => 'Добавить Песни в Плейлист';

  @override
  String get addToPlaylist => 'Добавить в Плейлист';

  @override
  String get adjustSync => 'Настройка Синхронизации';

  @override
  String get album => 'Альбом';

  @override
  String get albums => 'Альбомы';

  @override
  String get allSongs => 'Все песни';

  @override
  String get appName => 'Aurora Music';

  @override
  String get artist => 'Исполнитель';

  @override
  String get artistName => 'Имя исполнителя';

  @override
  String get artists => 'Исполнители';

  @override
  String get artistSeparation => 'Разделитель Исполнителей';

  @override
  String get artistSeparationDesc =>
      'Настройте как разделяются несколько исполнителей';

  @override
  String get audioQuality => 'Качество Звука';

  @override
  String get audioQualityDesc => 'Технические характеристики аудиофайла';

  @override
  String get auroraMusic => 'Aurora Music';

  @override
  String get autoPlaylists => 'Автоплейлист';

  @override
  String get autoTag => 'Автотег';

  @override
  String get smartPlaylists => 'Умные плейлисты';

  @override
  String get createSmartPlaylist => 'Создать интеллектуальный плейлист…';

  @override
  String get editSmartPlaylist => 'Редактировать интеллектуальный плейлист';

  @override
  String get smartPlaylistNameHint => 'Название плейлиста';

  @override
  String get smartPlaylistRules => 'Правила';

  @override
  String get addRule => 'Добавить правило';

  @override
  String get saveSmartPlaylist => 'Сохранить';

  @override
  String get matchAll => 'Соответствовать ВСЕМ правилам';

  @override
  String get matchAny => 'Правило «Соответствие ЛЮБОМУ»';

  @override
  String get limitResultsLabel => 'Ограничить результаты';

  @override
  String get noLimit => 'Без ограничений';

  @override
  String get deleteSmartPlaylistConfirm =>
      'Удалить этот интеллектуальный плейлист? При этом будут удалены только сохраненные правила — на ваши песни это никак не повлияет.';

  @override
  String smartPlaylistPreviewCount(int count) {
    return 'Сейчас найдено $count песен';
  }

  @override
  String get saveAsClip => 'Сохранить как клип';

  @override
  String get generatingClip => 'Создание клипа…';

  @override
  String get clipDuration => 'Продолжительность клипа';

  @override
  String get clipStartOffset => 'Начальная точка';

  @override
  String get saveClip => 'Сохранить клип';

  @override
  String get clipSavedToDevice => 'Клип сохранен на устройстве';

  @override
  String get clipSaveFailed =>
      'Не удалось сохранить клип. Пожалуйста, попробуйте ещё раз.';

  @override
  String get playlistSavedToDevice => 'Плейлист сохранен на устройстве';

  @override
  String get trackTags => 'Теги треков';

  @override
  String get editTrackTags => 'Редактировать теги';

  @override
  String get addTrackTag => 'Добавить тег';

  @override
  String get noTrackTagsYet =>
      'Тегов пока нет. Добавьте тег, чтобы сразу перейти к определенному участку этого трека.';

  @override
  String get trackTagNameHint => 'например, название песни или исполнитель';

  @override
  String get trackTagPosition => 'Должность';

  @override
  String get useCurrentPosition => 'Использовать текущее положение';

  @override
  String get isThisASet => 'Добавить временные метки к этой дорожке';

  @override
  String get tagPartsForEasySwitching =>
      'Отмечайте любые моменты — главы, важные фрагменты, закладки или что угодно.';

  @override
  String get tagThisTrack => 'Добавить теги';

  @override
  String get pasteSetlist => 'Импорт временных меток';

  @override
  String get pasteSetlistDialogTitle => 'Импорт временных меток';

  @override
  String get pasteSetlistHint =>
      'Вставьте сюда временные метки, например:\n0:00 Вступление\n3:45 Название главы';

  @override
  String get importAction => 'Импорт';

  @override
  String tagsImportedMessage(int count) {
    return 'Импортировано $count тегов';
  }

  @override
  String get noTagsFoundInPaste =>
      'В вставленном тексте не найдено временных меток.';

  @override
  String get bitrate => 'Битрейт';

  @override
  String get buyMeCoffee => 'Купи Мне Кофе';

  @override
  String get cancel => 'Закрыть';

  @override
  String get coffeeSupport => 'Поддержать кружкой кофе';

  @override
  String get composer => 'Композитор';

  @override
  String get connectWithUs => 'Связаться с нами';

  @override
  String get copied => 'Скопировано';

  @override
  String get copy => 'Скопировать';

  @override
  String get create => 'Создать';

  @override
  String get createFirstPlaylist =>
      'Нажми на кнопку выше, чтобы создать ваш первый плейлист';

  @override
  String get createPlaylist => 'Создать Плейлист';

  @override
  String get darkMode => 'Тёмная Тема';

  @override
  String get dateAdded => 'Дата Добавления';

  @override
  String get dateModified => 'Дата Изменения';

  @override
  String get delete => 'Удалить';

  @override
  String get deletePlaylist => 'Удалить Плейлист';

  @override
  String get deletePlaylistConfirm => 'Вы уверены, что хотите удалить';

  @override
  String get deletePlaylistConfirmation =>
      'Вы действительно хотите удалить этот плейлист?';

  @override
  String get deselectAll => 'Отменить выбор всех';

  @override
  String get details => 'Подробнее';

  @override
  String get discard => 'Отменить';

  @override
  String get dontShowAgain => 'Не показывать снова';

  @override
  String get duration => 'Длительность';

  @override
  String get enableArtistSeparation => 'Включить Разделение Исполнителей';

  @override
  String get enableArtistSeparationDesc =>
      'Автоматически разделять составные имена исполнителей';

  @override
  String get enjoyingAurora => 'Нравится Aurora?';

  @override
  String get enjoyingAuroraDesc =>
      'Если вам нравится пользоваться Aurora Music, подумайте о том, чтобы поддержать её разработку. Ваша поддержка помогает сохранить бесплатный доступ к приложению!';

  @override
  String get error => 'Ошибка';

  @override
  String get exclusionHint => 'например, переменный/постоянный ток';

  @override
  String get exclusions => 'Исключения';

  @override
  String get exclusionsDesc =>
      'Имена исполнителей, которые не должны разделяться';

  @override
  String get exit => 'Выйти';

  @override
  String get exitApp => 'Выйти из приложения';

  @override
  String get exitAppConfirm => 'Вы хотите выйти?';

  @override
  String get expandLyrics => 'Показать текст песни';

  @override
  String get extraLarge => 'Огромный';

  @override
  String get favoriteSongs => 'Любимые песни';

  @override
  String get fileInfo => 'Сведения о файле';

  @override
  String get fileInfoDesc =>
      'Нажмите и удерживайте значения, чтобы скопировать их';

  @override
  String get fileName => 'Имя файла';

  @override
  String get filePath => 'Путь к файлу';

  @override
  String get folder => 'Папка';

  @override
  String get folders => 'Папки';

  @override
  String get fontSize => 'Размер шрифта';

  @override
  String get format => 'Формат';

  @override
  String get forYou => 'Для вас';

  @override
  String get general => 'Общие сведения';

  @override
  String get genre => 'Жанр';

  @override
  String get getStarted => 'Начать работу';

  @override
  String get goodQuality => 'Хорошее качество';

  @override
  String get gotIt => 'Понял!';

  @override
  String get grantPermission => 'Предоставить разрешение';

  @override
  String get highQuality => 'Высокое качество';

  @override
  String get home => 'Главная';

  @override
  String get kofi => 'Ko-fi';

  @override
  String get buyMeACoffee => 'Купите мне кофе';

  @override
  String get donationNote =>
      'Необязательно - вы можете нас всегда поддержать в настройках';

  @override
  String get language => 'Язык';

  @override
  String get large => 'Большой';

  @override
  String get later => 'Позже';

  @override
  String get library => 'Библиотека';

  @override
  String get libraryError => 'Ошибка загрузки музыкальной библиотеки';

  @override
  String get libraryLoaded => 'Музыкальная библиотека загружена';

  @override
  String get libraryUpdated => 'Библиотека обновлена';

  @override
  String get loading => 'Загрузка';

  @override
  String get loadingLibrary => 'Загрузка библиотеки';

  @override
  String get lossless => 'Без потерь';

  @override
  String get lowQuality => 'Низкое Качество';

  @override
  String get lyrics => 'Текст';

  @override
  String get lyricsAhead => 'Текст опережает';

  @override
  String get lyricsBehind => 'Текст отстаёт';

  @override
  String get lyricsSynced => 'Текст синхронизирован';

  @override
  String get maybeLater => 'Позже';

  @override
  String get medium => 'Средний';

  @override
  String get metadata => 'Метаданные';

  @override
  String get metadataSaved => 'Метаданные успешно изменены';

  @override
  String get metadataApplied => 'Метаданные успешно загружены';

  @override
  String get metadataDownloadFailed =>
      'Загрузка не удалась. Проверьте подключение и попробуйте ещё раз.';

  @override
  String get chooseArtworkFromDevice => 'Выберите устройство';

  @override
  String get mostPlayed => 'Часто Прослушиваемое';

  @override
  String get newPlaylist => 'Новый Плейлист';

  @override
  String get next => 'Следующее';

  @override
  String get no => 'Нет';

  @override
  String get noAlbumsFound => 'Альбомов не найдено';

  @override
  String get noArtistInfo => 'Информация об артисте не доступна';

  @override
  String get noArtistsFound => 'Артистов не найдено';

  @override
  String get noData => 'Нет данных для отображения';

  @override
  String get noExclusions => 'Исключения не настроены';

  @override
  String get noLyrics => 'Текст недоступен';

  @override
  String get noLyricsDesc => 'Мы не нашли текст для этой песни';

  @override
  String get noLyricsFound => 'Текст не найден';

  @override
  String get noPermissionExplanation =>
      'Без разрешений Aurora Music не сможет получить доступ к вашей библиотеке музыки.';

  @override
  String get noPlaylists => 'Плейлистов нет';

  @override
  String get noResults => 'Результатов не найдено';

  @override
  String get noSeparators => 'Разделители не настроены';

  @override
  String get noSongPlaying => 'Никакая песня не воспроизводится';

  @override
  String get noSongsAvailable => 'Песен нет';

  @override
  String get noSongsInPlaylist => 'В этом плейлисте нет песен';

  @override
  String get nowPlaying => 'Сейчас играет';

  @override
  String get onboardingAlbumArt => 'Красивые обложки альбомов';

  @override
  String get onboardingAlbumArtwork => 'Обложка альбома';

  @override
  String get onboardingAlbumArtworkDesc =>
      'Загружает высококачественные обложки альбомов для улучшения вашей медиатеки';

  @override
  String get onboardingAppInfoSubtitle => 'Ваш личный музыкальный спутник';

  @override
  String get onboardingAppInfoTitle => 'Добро пожаловать в «Aurora Music»';

  @override
  String get onboardingAudioAccess => 'Доступ к аудиоматериалам';

  @override
  String get onboardingAudioAccessDesc =>
      'Необходимо для воспроизведения и управления вашей музыкальной библиотекой';

  @override
  String get onboardingBack => 'Назад';

  @override
  String get onboardingBeautifulArtwork => 'Красивая обложка альбома';

  @override
  String get onboardingBeautifulArtworkDesc =>
      'Автоматически загружать и отображать обложки альбомов так, как их задумывали авторы';

  @override
  String get onboardingBluetooth => 'Bluetooth';

  @override
  String get onboardingBluetoothDesc =>
      'Необходимо для подключения к устройствам Bluetooth';

  @override
  String get onboardingChooseLanguage => 'Выберите язык';

  @override
  String get languageNotListedHint =>
      'Вашего языка нет в списке? Выберите «Английский» и перейдите на следующую страницу.';

  @override
  String get onboardingCompletionSubtitle => 'Начните наслаждаться музыкой';

  @override
  String get onboardingCompletionTitle => 'Всё готово!';

  @override
  String get onboardingContinue => 'Продолжить';

  @override
  String get onboardingDynamicColors => 'Динамические цвета';

  @override
  String get onboardingDynamicColorsDesc =>
      'Подбор цветов обоев в соответствии с системой';

  @override
  String get onboardingGrantPermissions => 'Предоставить права доступа';

  @override
  String get onboardingInternetSubtitle =>
      'Как компания «Aurora Music» использует Интернет';

  @override
  String get onboardingInternetTitle => 'Использование Интернета';

  @override
  String get onboardingLocalMusic => 'Музыка на вашем устройстве';

  @override
  String get onboardingLocalMusicDesc =>
      'Ваши музыкальные файлы всегда под рукой';

  @override
  String get onboardingLyrics => 'Текст';

  @override
  String get onboardingLyricsDesc =>
      'Скачивает синхронизированные тексты песен';

  @override
  String get onboardingLyricsSupport => 'Поддержка текстов песен';

  @override
  String get onboardingLyricsSupportDesc =>
      'Просматривайте синхронизированные тексты песен во время прослушивания';

  @override
  String get onboardingMaterialDesign => 'Дизайн «Material You»';

  @override
  String get onboardingMaterialDesignDesc =>
      'Динамичные цвета, которые подстраиваются под ваши предпочтения';

  @override
  String get onboardingMusicMetadata => 'Метаданные музыки';

  @override
  String get onboardingMusicMetadataDesc =>
      'Получает сведения об исполнителе, данные об альбоме и информацию о треках';

  @override
  String get onboardingNotifications => 'Уведомления';

  @override
  String get onboardingNotificationsDesc =>
      'Показать элементы управления воспроизведением и обновления';

  @override
  String get onboardingOptional => 'Необязательно';

  @override
  String get onboardingPermissionsSubtitle =>
      'Для правильной работы приложению «Aurora Music» необходимы следующие разрешения';

  @override
  String get onboardingPermissionsTitle => 'Предоставить права доступа';

  @override
  String get onboardingPrivacyNote =>
      'Ваша конфиденциальность важна для нас. Все музыкальные файлы хранятся на вашем устройстве.';

  @override
  String get onboardingRequesting => 'Ожидается запрос...';

  @override
  String get onboardingRequired => 'Обязательно';

  @override
  String get onboardingAudioRequired =>
      'Для продолжения требуется доступ к аудио. Пожалуйста, предоставьте указанное выше разрешение.';

  @override
  String get onboardingSelectLanguage => 'Выберите желаемый язык';

  @override
  String get onboardingSmartPlaylists => 'Умный Плейлист';

  @override
  String get onboardingSmartPlaylistsDesc =>
      'Создавайте и управляйте своими музыкальными коллекциями';

  @override
  String get onboardingStartListening => 'Начать прослушивание';

  @override
  String get onboardingStorageAccess => 'Доступ к хранилищу';

  @override
  String get onboardingStorageAccessDesc =>
      'Требуется доступ к музыкальным файлам на вашем устройстве';

  @override
  String get onboardingVisualizerAccess => 'Визуализатор';

  @override
  String get onboardingVisualizerAccessDesc =>
      'Позволяет визуализатору считывать данные аудиосессии вашего устройства для отображения спектра в режиме реального времени. Аудио никогда не записывается.';

  @override
  String get onboardingThemeSubtitle =>
      'Выберите тему, которая соответствует вашему стилю';

  @override
  String get onboardingThemeTitle => 'Создайте свой собственный образ';

  @override
  String get beta_welcome_title => 'Программа бета-тестирования';

  @override
  String get beta_welcome_thanks =>
      'Благодарим вас за участие в нашей программе бета-тестирования и за помощь в совершенствовании Aurora Music.';

  @override
  String get beta_expect_bugs_title => 'Будьте готовы к ошибкам';

  @override
  String get beta_expect_bugs_desc =>
      'Возможны сбои в работе или непредвиденные явления. Это тестовая версия.';

  @override
  String get beta_feedback_title => 'Отзывы имеют значение';

  @override
  String get beta_feedback_desc =>
      'Ваши отзывы и предложения помогают нам сделать приложение лучше для всех.';

  @override
  String get beta_updates_title => 'Частые обновления';

  @override
  String get beta_updates_desc =>
      'По мере продолжения разработки регулярно выпускаются новые функции и исправления.';

  @override
  String get oneTimeSupport => 'Быстрая разовая поддержка';

  @override
  String get openFolder => 'Открыть в диспетчере файлов';

  @override
  String get openFolderInfo =>
      'Воспользуйтесь файловым менеджером, чтобы перейти в этот каталог';

  @override
  String get ownTimer => 'Собственный таймер';

  @override
  String get permDeny => 'Доступ запрещен';

  @override
  String get permissionExplanation =>
      'Приложению Aurora Music требуются эти разрешения для правильной работы. Пожалуйста, предоставьте эти разрешения в настройках приложения.';

  @override
  String get permissionLater =>
      'Вы можете предоставить разрешения позже в настройках приложения';

  @override
  String get permissionRequired => 'Требуется разрешение';

  @override
  String get playAll => 'Воспроизвести всё';

  @override
  String get playingFrom => 'Воспроизведение с';

  @override
  String get playlist => 'Плейлист';

  @override
  String get playlistName => 'Название плейлиста';

  @override
  String get playlists => 'Плейлисты';

  @override
  String get possibleReasons => 'Возможные причины:';

  @override
  String get privacyNotice =>
      'Продолжая пользоваться этим приложением, вы соглашаетесь с нашей Политикой конфиденциальности.';

  @override
  String get privacyPolicyLink =>
      'Ознакомьтесь с нашей Политикой конфиденциальности';

  @override
  String get quality => 'Качество';

  @override
  String get qualityDesc => 'Качество звука зависит от формата и битрейта';

  @override
  String get queue => 'Очередь';

  @override
  String get queueEmpty => 'Очередь пуста';

  @override
  String get reasonFormat =>
      'Данный формат файла не поддерживает редактирование метаданных';

  @override
  String get reasonPermissions => 'Права на хранение не предоставлены';

  @override
  String get reasonReadonly =>
      'Файл доступен только для чтения или находится на внешнем носителе';

  @override
  String get recentlyAdded => 'Недавно добавленные';

  @override
  String get recentlyPlayed => 'Недавно воспроизведенные';

  @override
  String get recentlyPlayedArtists => 'Недавно прослушанные исполнители';

  @override
  String get recentlyPlayedSongs => 'Недавно прослушанные песни';

  @override
  String get refreshing => 'Освежает...';

  @override
  String get refreshLyrics => 'Обновить тексты песен';

  @override
  String get remove => 'Удалить';

  @override
  String get removeSong => 'Удалить песню';

  @override
  String get removeSongConfirmation => 'Удалить эту песню из плейлиста?';

  @override
  String get rename => 'Переименовать';

  @override
  String get renamePlaylist => 'Переименовать плейлист';

  @override
  String get repeat => 'Повторить';

  @override
  String get reset => 'Сброс';

  @override
  String get resetArtistSeparationDesc =>
      'Это приведет к восстановлению всех разделителей и исключений по умолчанию.';

  @override
  String get resetToDefaults => 'Сброс на настройки по умолчанию';

  @override
  String get result => 'Результат';

  @override
  String get results => 'Результаты';

  @override
  String get retry => 'Повторить попытку';

  @override
  String get sampleRate => 'Частота дискретизации';

  @override
  String get save => 'Сохранить';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get saveChangesDesc => 'Хотите сохранить изменения?';

  @override
  String get saveFailed => 'Сохранение не удалось';

  @override
  String get saveFailedDesc => 'Не удалось сохранить метаданные в этом файле.';

  @override
  String get scanFailed => 'Сканирование не удалось';

  @override
  String get scanningSongs => 'Сканирование песен';

  @override
  String get search => 'Поиск';

  @override
  String get searchAlbums => 'Поиск альбомов';

  @override
  String get searchArtists => 'Поиск исполнителей';

  @override
  String get searchFailed => 'Поиск не удался';

  @override
  String get searchLyrics => 'Поиск текстов песен';

  @override
  String get searchMetadata => 'Поиск по метаданным';

  @override
  String get searchTracks => 'Поиск треков';

  @override
  String get selectAll => 'Выделить всё';

  @override
  String get selectArtist => 'Выбрать исполнителя';

  @override
  String get selected => 'выбранный';

  @override
  String get selectPlaylist => 'Выбрать плейлист';

  @override
  String get separator => 'Разделитель';

  @override
  String get separatorHint => 'например, / или при участии';

  @override
  String get separators => 'Разделители';

  @override
  String get set => 'Набор';

  @override
  String get setMinutes => 'Установить продолжительность';

  @override
  String get settings => 'Настройки';

  @override
  String get settingsAbout => 'О нас';

  @override
  String get settingsAboutApp => 'О компании «Aurora Music»';

  @override
  String get settingsAboutSubtitle => 'Версия, отзывы и обновления';

  @override
  String get settingsAccentColor => 'Акцентный цвет';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsAppearanceSubtitle => 'Тема, цвета и макет';

  @override
  String get settingsAudio => 'Аудио';

  @override
  String get settingsBackground => 'Общая информация';

  @override
  String get settingsCacheCleared => 'Кэш очищен';

  @override
  String get settingsCacheInfo => 'Информация о кэше';

  @override
  String get settingsCacheInfoDesc =>
      'Просмотреть использование дискового пространства';

  @override
  String get settingsCheckingUpdates => 'Проверка наличия обновлений...';

  @override
  String get settingsCheckUpdates => 'Проверить наличие обновлений';

  @override
  String get settingsCheckUpdatesDesc => 'Скачать последнюю версию';

  @override
  String get settingsClearCache => 'Очистить кэш';

  @override
  String get settingsClearCacheDesc => 'Удалить все данные из кэша';

  @override
  String get settingsClearCacheMessage =>
      'Все данные из кэша будут удалены и при необходимости восстановлены.';

  @override
  String get settingsClearCacheTitle => 'Очистить кэш?';

  @override
  String get settingsDataWindow => 'Окно данных';

  @override
  String get settingsDataWindowDesc =>
      'Насколько далеко назад отображается экран с кратким обзором';

  @override
  String get settingsGapless => 'Воспроизведение без пауз';

  @override
  String get settingsGaplessDesc => 'Плавные переходы между треками';

  @override
  String get settingsAutomix => 'Automix';

  @override
  String get settingsAutomixDesc =>
      'Автоматически создаёт плавный переход между треками';

  @override
  String get playlistAutomixTitle => 'AutoMix';

  @override
  String get playlistAutomixSubtitle =>
      'Автоматические переходы в стиле DJ для этого плейлиста';

  @override
  String get playlistAutomixOn => 'Включено';

  @override
  String get playlistAutomixOff => 'Выключено';

  @override
  String get playlistAutomixBeatMatching => 'Совпадение бита';

  @override
  String get playlistAutomixHarmonicMixing => 'Гармоническое сведение';

  @override
  String get playlistAutomixTempoMatching => 'Совпадение темпа';

  @override
  String get playlistAutomixTransitionDuration => 'Длительность перехода';

  @override
  String get playlistAutomixAutomatic => 'Автоматически';

  @override
  String playlistAutomixAnalyzing(int current, int total) {
    return 'Анализ плейлиста… $current / $total треков';
  }

  @override
  String get settingsCrossfade => 'Переход';

  @override
  String get settingsCrossfadeDesc =>
      'Плавный переход от конца одной дорожки к следующей';

  @override
  String get crossfadeDuration => 'Продолжительность плавного перехода';

  @override
  String get crossfadeDurationDesc =>
      'Как долго длится перекрытие между треками';

  @override
  String get settingsInsights => 'Аналитика';

  @override
  String get settingsInsightsSubtitle =>
      'Период повторения прослушанного материала';

  @override
  String get settingsLast7Days => 'Последние 7 дней';

  @override
  String get settingsLast30Days => 'Последние 30 дней';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLayout => 'Макет';

  @override
  String get settingsLibraryFolders => 'Пакеты библиотеки';

  @override
  String get settingsLibraryFoldersSubtitle =>
      'Включить или исключить папки для сканирования';

  @override
  String get settingsMaterialYou => 'Material You';

  @override
  String get settingsMaterialYouDesc => 'Динамичные цвета из обоев';

  @override
  String get settingsMonthlyRecap => 'Ежемесячный обзор';

  @override
  String get settingsMonthlyRecapDesc =>
      'Показывать баннер каждый месяц (имеет приоритет над еженедельным)';

  @override
  String get settingsNormalization => 'Нормализация громкости';

  @override
  String get settingsNormalizationDesc =>
      'Стабильный уровень громкости · Требуется наличие тегов ReplayGain в файлах';

  @override
  String get playbackSpeed => 'Скорость воспроизведения';

  @override
  String get playbackSpeedDesc => 'Настройка скорости воспроизведения звука';

  @override
  String get adjustPitchWithSpeed =>
      'Регулировка высоты тона в зависимости от скорости';

  @override
  String get adjustPitchWithSpeedDesc =>
      'В выключенном состоянии темп изменяется без изменения высоты тона';

  @override
  String get settingsPlayback => 'Воспроизведение';

  @override
  String get settingsPlaybackSubtitle =>
      'Скорость, воспроизведение без пауз и нормализация';

  @override
  String get settingsRecapBannerDesc =>
      'Баннер появляется на главном экране в начале каждой новой недели или месяца, отсчитываемых с момента вашего первого запуска игры. Нажатие кнопки «Позже» скрывает его на время текущего сеанса; нажатие кнопки «Показать» помечает его как просмотренный.';

  @override
  String get settingsRecapContent => 'Краткое содержание';

  @override
  String get settingsRecapContentDesc =>
      'Определяет, какой объем истории отображается на экране сводки при его открытии вручную или через баннер.';

  @override
  String get settingsPreviewRecap => 'Краткий обзор предварительного просмотра';

  @override
  String get settingsPreviewRecapDesc =>
      'Посмотрите, как выглядит ваш обзор в данный момент с текущими настройками';

  @override
  String get settingsRecapSchedule => 'Расписание повторов';

  @override
  String get settingsStorage => 'Хранение';

  @override
  String settingsCacheItems(String count) {
    return '$count товаров';
  }

  @override
  String get settingsMemoryCache => 'Кэш-память';

  @override
  String get settingsStorageSubtitle => 'Кэш и мультимедийные файлы';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsTools => 'Инструменты';

  @override
  String get settingsResetSetup => 'Сброс настроек';

  @override
  String get settingsResetSetupDesc =>
      'Перезапустить процесс адаптации новых сотрудников';

  @override
  String get settingsUpdateAvailable => 'Доступно обновление!';

  @override
  String get settingsUpToDate => 'Вы в курсе последних новостей';

  @override
  String get settingsWeeklyRecap => 'Еженедельный обзор';

  @override
  String get settingsWeeklyRecapDesc =>
      'Показывать баннер каждую неделю после первого прослушивания';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get share => 'Поделиться';

  @override
  String get showChangelog => 'Показать журнал изменений';

  @override
  String get shuffle => 'Перемешать';

  @override
  String get size => 'Размер';

  @override
  String get sleepTimer => 'Таймер выключения';

  @override
  String get small => 'Маленький';

  @override
  String get songInfo => 'Информация о песне';

  @override
  String get songs => 'Песни';

  @override
  String get songsLoaded => 'Песни загружены';

  @override
  String get standardQuality => 'Стандартное качество';

  @override
  String get startType => 'Начните вводить текст для поиска';

  @override
  String get storagePermissionNeeded =>
      'Для редактирования метаданных приложению Aurora Music требуется разрешение на управление файлами. Пожалуйста, предоставьте доступ ко «всем файлам» в настройках.';

  @override
  String get suggestedArtists => 'Художники для вас';

  @override
  String get suggestedTracks => 'Рекомендуемые треки';

  @override
  String get supportAurora => 'Поддержите «Аврору»';

  @override
  String get supportAuroraBtn => 'Поддержите «Аврору»';

  @override
  String get supportAuroraDescShort =>
      'Помогите сохранить приложение бесплатным';

  @override
  String get supportAuroraMessage =>
      'Помогите сохранить бесплатный доступ к Aurora Music и поддержать его дальнейшее развитие. Каждый вклад имеет огромное значение!';

  @override
  String get supportAuroraTitle => 'Поддержите «Aurora Music»';

  @override
  String get tapAddToAddSongs => 'Нажмите «+», чтобы добавить песни';

  @override
  String get reorderSongs => 'Изменить порядок песен';

  @override
  String get done => 'Готово';

  @override
  String get thankYouSupport => 'Спасибо за вашу поддержку!';

  @override
  String get theme => 'Тема';

  @override
  String get title => 'Название';

  @override
  String get topResult => 'Лучший результат';

  @override
  String get total => 'Итого';

  @override
  String get track => 'Трек';

  @override
  String get trackInfo => 'Информация о треке';

  @override
  String get trackInfoDesc =>
      'Нажмите на значок редактирования, чтобы изменить информацию о треке';

  @override
  String get trackInfoEditDesc =>
      'Измените данные в полях ниже, а затем нажмите на значок галочки, чтобы сохранить';

  @override
  String get tracks => 'Треки';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get unknownArtist => 'Неизвестный художник';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get updateMessage => 'Доступна новая версия';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get viewArtist => 'Посмотреть информацию об исполнителе';

  @override
  String get viewDetails => 'Посмотреть подробности';

  @override
  String get welcomeBack => 'С возвращением!';

  @override
  String get whatsNew => 'Что нового';

  @override
  String get view_changelog => 'Просмотреть журнал изменений и новые функции';

  @override
  String get year => 'Год';

  @override
  String get yes => 'Да';

  @override
  String get yourLibrary => 'Ваша библиотека';

  @override
  String get yourPlaylists => 'Ваши плейлисты';

  @override
  String get homeLayout => 'Планировка дома';

  @override
  String get homeLayoutDesc =>
      'Настройка порядка разделов на вкладке «Главная»';

  @override
  String get customizeHomeTab => 'Настройка вкладки «Главная»';

  @override
  String get dragToReorder => 'Перетащите, чтобы изменить порядок разделов';

  @override
  String get resetToDefault => 'Сброс к настройкам по умолчанию';

  @override
  String get resetLayoutConfirm => 'Сбросить макет до значений по умолчанию?';

  @override
  String get resetLayoutMessage =>
      'Это восстановит исходный порядок разделов и их отображение.';

  @override
  String get sectionVisibility => 'Включить/выключить отображение раздела';

  @override
  String get listeningHistory => 'История прослушиваний';

  @override
  String get libraryStats => 'Статистика библиотеки';

  @override
  String get back => 'Назад';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get skip => 'Пропустить';

  @override
  String get feedback_title => 'Вам нравится Aurora Music?';

  @override
  String get maybe_later => 'Может, позже';

  @override
  String get send_feedback => 'Отправить отзыв';

  @override
  String get send_feedback_desc =>
      'Сообщите об ошибках или предложите новые функции';

  @override
  String get contributeTranslations => 'Присылайте переводы';

  @override
  String get contributeTranslationsDesc =>
      'Помогите перевести «Aurora Music» на Crowdin';

  @override
  String get contributeTranslationsTitle => 'Помогите нам с переводом';

  @override
  String get contributeTranslationsSubtitle =>
      'Приложение Aurora Music доступно на нескольких языках благодаря нашему замечательному сообществу. Помогите нам охватить ещё больше пользователей, переведя приложение на ваш язык — начать работу можно всего за несколько минут.';

  @override
  String get contributeTranslationsOpenCrowdin => 'Открыть Crowdin';

  @override
  String get close => 'Закрыть';

  @override
  String get settingsHighendUi => 'Интерфейс пользователя премиум-класса';

  @override
  String get settingsHighendUiDesc =>
      'Включить расширенные визуальные эффекты и анимацию';

  @override
  String get restartRequired => 'Требуется перезапуск';

  @override
  String get restartRequiredDesc =>
      'Для применения изменений режима интерфейса необходимо перезапустить приложение. Перезапустить сейчас?';

  @override
  String get restartNow => 'Перезапустить сейчас';

  @override
  String get clearUpcoming => 'Очистить предстоящие';

  @override
  String get addToQueue => 'Добавить в очередь';

  @override
  String get playNext => 'Следующий трек';

  @override
  String get removeFromQueue => 'Удалить из очереди';

  @override
  String get play => 'Играть';

  @override
  String get viewAlbum => 'Посмотреть альбом';

  @override
  String get shuffleAll => 'Перемешать всё';

  @override
  String get noSongsFound => 'Песни не найдены';

  @override
  String get noFoldersFound => 'Папки не найдены';

  @override
  String get deleteSong => 'Удалить песню';

  @override
  String get modifySystemSettingsPermission =>
      'На открывшейся странице разрешите «Изменение системных настроек», а затем попробуйте ещё раз.';

  @override
  String errorMessage(String message) {
    return 'Ошибка: $message';
  }

  @override
  String songsAddedToQueue(int count) {
    return '$count песен добавлено в очередь';
  }

  @override
  String songAddedToQueue(String title) {
    return '«$title» добавлено в очередь';
  }

  @override
  String songSetAsRingtone(String title) {
    return '«$title» установлено в качестве мелодии звонка';
  }

  @override
  String failedToSetRingtone(String error) {
    return 'Не удалось установить мелодию звонка: $error';
  }

  @override
  String deleteSongConfirm(String title) {
    return 'Удалить «$title» с вашего устройства? Это действие нельзя отменить.';
  }

  @override
  String songDeleted(String title) {
    return '«$title» удалено';
  }

  @override
  String failedToDelete(String error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String songCount(int count) {
    return '$count песен';
  }

  @override
  String get badgeNew => 'НОВОЕ';

  @override
  String get paused => 'Приостановлено';

  @override
  String get readyToPlay => 'Готовы к игре';

  @override
  String get tapSongToStartListening =>
      'Нажмите на песню, чтобы начать прослушивание';

  @override
  String get clearCachedLyrics => 'Очистить кэшированные тексты песен';

  @override
  String lyricsCleared(String title) {
    return 'Кэшированные тексты песен для «$title» удалены';
  }

  @override
  String get noLyricsCached => 'Текст песни в кэше не найден';

  @override
  String get setAsRingtone => 'Установить в качестве мелодии звонка';

  @override
  String get songInfoEdit => 'Информация о песне / Редактировать';

  @override
  String get goToAlbum => 'Перейти к альбому';

  @override
  String get goToArtist => 'Перейти к исполнителю';

  @override
  String get deleteFromDevice => 'Удалить с устройства';

  @override
  String get checkOutThisSong => 'Послушайте эту песню!';

  @override
  String get backgroundLowEndStyle => 'Стиль фона';

  @override
  String get backgroundLowEndStyleDesc => 'Как выглядит фон приложения';

  @override
  String get backgroundBlobs => 'Анимированные кляксы';

  @override
  String get backgroundSolid => 'Однотонный';

  @override
  String get backgroundHighEndStyle => 'Фон для текущего воспроизведения';

  @override
  String get backgroundHighEndStyleDesc =>
      'Стиль фона на экране «Воспроизведение»';

  @override
  String get backgroundBlurredArtwork => 'Размытые иллюстрации';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get accentColorDesc => 'Выберите цвет акцента для приложения';

  @override
  String get backgroundBlur => 'Размытие фона';

  @override
  String get backgroundBlurDesc => 'Интенсивность размытия изображения';

  @override
  String get backgroundDarkness => 'Темнота на заднем плане';

  @override
  String get backgroundDarknessDesc => 'Прозрачность наложения на иллюстрацию';

  @override
  String get microphoneAccessNeeded => 'Требуется доступ к микрофону';

  @override
  String get microphoneAccessDesc =>
      'Приложению Aurora требуется доступ к микрофону для подключения к аудиосессии вашего устройства с целью работы визуализатора в режиме реального времени. Аудиосигнал не записывается и не сохраняется.';

  @override
  String get recapWeek => 'неделя';

  @override
  String get recapMonth => 'месяц';

  @override
  String get recapPeriodWeek => 'Неделя';

  @override
  String get recapPeriodMonth => 'Месяц';

  @override
  String get recapWeekly => 'Еженедельно';

  @override
  String get recapMonthly => 'Ежемесячно';

  @override
  String get recapIntroAppName => 'AURORA MUSIC';

  @override
  String recapIntroTitle(String period) {
    return 'Ваш $period\nКраткое изложение';
  }

  @override
  String get recapIntroSubtitle => 'Давай посмотрим, что ты\nслушал.';

  @override
  String recapPlayedEyebrow(String period) {
    return 'В этом $period вы слушали музыку';
  }

  @override
  String get recapTimeSingular => 'время';

  @override
  String get recapTimePlural => 'раз';

  @override
  String get recapListenedForEyebrow => 'Вы прислушались к';

  @override
  String get recapListenedForLabel => 'музыки';

  @override
  String get recapTopTrackEyebrow => 'Ваш трек № 1';

  @override
  String get recapPlays => 'спектакли';

  @override
  String get recapTopTracksTitle => 'Лучшие треки';

  @override
  String get recapTopArtistEyebrow => 'Ваш любимый исполнитель';

  @override
  String get recapTopArtistsTitle => 'Лучшие артисты';

  @override
  String get recapNothingToWrap => 'Пока нечего заворачивать';

  @override
  String recapNothingToWrapBody(String period) {
    return 'Послушай немного музыки, $period, а потом вернись.';
  }

  @override
  String get recapSwipeUp => 'ПРОВЕДИ ПАЛЬЦЕМ ВВЕРХ';

  @override
  String get recapYourSoundLabel => 'ВАШ ЗВУК';

  @override
  String get recapYouListenMost => 'ЧТО ВЫ СЛУШАЕТЕ ЧАЩЕ ВСЕГО';

  @override
  String recapOnDay(String day) {
    return 'за $day секунд';
  }

  @override
  String recapAroundTime(String time) {
    return 'около $time';
  }

  @override
  String get recapVibesHitDifferent =>
      'И вот тогда атмосфера стала совсем другой.';

  @override
  String get recapThatsAWrap => 'НА ЭТОМ ВСЁ';

  @override
  String recapInNumbers(String period) {
    return 'Ваш $period\nв цифрах';
  }

  @override
  String get recapNumberOneTrack => '#1 ТРЕК';

  @override
  String get recapStatTotalPlays => 'Общее количество просмотров';

  @override
  String get recapStatTimeListened => 'Время прослушивания';

  @override
  String get recapStatUniqueTracks => 'Уникальные треки';

  @override
  String get recapStatTopArtist => 'Лучший артист';

  @override
  String get recapDone => 'Готово';

  @override
  String get recapWeekdayMonday => 'Понедельник';

  @override
  String get recapWeekdayTuesday => 'вторник';

  @override
  String get recapWeekdayWednesday => 'среда';

  @override
  String get recapWeekdayThursday => 'четверг';

  @override
  String get recapWeekdayFriday => 'Пятница';

  @override
  String get recapWeekdaySaturday => 'Суббота';

  @override
  String get recapWeekdaySunday => 'Воскресенье';

  @override
  String get recapBannerTitle => 'Обзор музыкальных событий можно найти здесь';

  @override
  String get recapBannerShow => 'Показать';

  @override
  String get recapBannerLater => 'Позже';

  @override
  String get eqTitle => 'Эквалайзер';

  @override
  String get eqOn => 'ВКЛ.';

  @override
  String get eqOff => 'ВЫКЛ.';

  @override
  String get eqNotAvailable =>
      'На данном устройстве функция эквалайзера недоступна.';

  @override
  String get eqOpenSystem => 'Эквалайзер с открытой системой';

  @override
  String get eqSavePreset => 'Сохранить пресет';

  @override
  String get eqPresetNameHint => 'например, «My Bass Boost»';

  @override
  String get eqPresetNameEmpty => 'Поле «Имя» не может быть пустым.';

  @override
  String eqPresetNameBuiltIn(String name) {
    return '«$name» — это название встроенной предустановки.';
  }

  @override
  String get eqResetAllBands => 'Сбросить настройки всех диапазонов';

  @override
  String get eqPresetsLabel => 'ПРЕДУСТАНОВКИ';

  @override
  String get eqYourPresetsLabel => 'ВАШИ ПРЕДУСТАНОВКИ';

  @override
  String get eqSaveCurrent => 'Сохранить текущее';

  @override
  String get eqSettingsSubtitle =>
      'Настройка частот звука по каждому диапазону';

  @override
  String get eqEmptyPresets =>
      'Настройте звук, а затем нажмите «Сохранить текущие настройки».';

  @override
  String get lyricsHint =>
      'Вставьте сюда несинхронизированные тексты песен…\n\nПо одной строке на каждую строку куплета.';

  @override
  String get lyricsSelectLrcFile => 'Пожалуйста, выберите файл .lrc';

  @override
  String get lyricsNoLyricsInFile => 'В этом файле не найдено текстов песен';

  @override
  String importFailed(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get lyricsImportTooltip => 'Импортировать файл .lrc';

  @override
  String get importPlaylistM3u => 'Импортировать плейлист (.m3u)';

  @override
  String get setSyncFolder => 'Установить папку для синхронизации…';

  @override
  String get syncNow => 'Синхронизировать сейчас';

  @override
  String get searchPlaylists => 'Поиск плейлистов…';

  @override
  String get pleaseSelectM3uFile =>
      'Пожалуйста, выберите файл с расширением .m3u или .m3u8';

  @override
  String get noMatchingSongsForPlaylist =>
      'Песен, соответствующих этому плейлисту, не найдено';

  @override
  String importedPlaylist(String name, int count) {
    return 'Импортировано «$name» ($count песен)';
  }

  @override
  String playlistsSyncWith(String folder) {
    return 'Плейлисты будут синхронизированы с: $folder';
  }

  @override
  String couldNotSetSyncFolder(String error) {
    return 'Не удалось настроить папку синхронизации: $error';
  }

  @override
  String get setSyncFolderFirst => 'Сначала настройте папку для синхронизации';

  @override
  String get playlistsSynced => 'Синхронизированы плейлисты';

  @override
  String get alreadyUpToDate => 'Уже актуально';

  @override
  String syncFailed(String error) {
    return 'Ошибка синхронизации: $error';
  }

  @override
  String exportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get searchFolders => 'Поиск папок…';

  @override
  String get songInfoPath => 'Путь';

  @override
  String get closeVisualiser => 'Закрыть визуализатор';

  @override
  String get previousMode => 'Предыдущий режим';

  @override
  String get nextMode => 'Следующий режим';

  @override
  String get sortBy => 'Сортировать по';

  @override
  String get colorTheme => 'Цветовая схема';

  @override
  String get insightsTotalPlays => 'Всего\nПросмотров';

  @override
  String get insightsTracksHeard => 'Треки\nПрослушано';

  @override
  String get insightsEstListening => 'Приблизительно\nПрослушивание';

  @override
  String get dismiss => 'Отклонить';

  @override
  String updateVersionAvailable(String version) {
    return 'Теперь доступна версия $version.';
  }

  @override
  String get updateNewVersionAvailable => 'Теперь доступна новая версия.';

  @override
  String get lyricsPasteLyricsTitle => 'Вставить текст песни';

  @override
  String get lyricsUseLyrics => 'Использовать тексты песен';

  @override
  String get lyricsPaste => 'Вставить';

  @override
  String get lyricsNoLyricsYet => 'Текста песни пока нет';

  @override
  String get lyricsPasteToGetStarted => 'Вставьте текст песни, чтобы начать';

  @override
  String get lyricsNoTimestampsYet =>
      'Метки времени пока отсутствуют — нажмите кнопку с отметкой во время воспроизведения песни.';

  @override
  String get lyricsAllLinesStampedHint =>
      'Все строки отмечены — нажмите «Сохранить», чтобы завершить.';

  @override
  String get lyricsAllStamped => '✓  Все строки проштампованы';

  @override
  String get lyricsPasteFirst => 'Сначала вставьте текст песни';

  @override
  String lyricsTapToStamp(int current, int total) {
    return '⏱  Нажмите, чтобы поставить отметку на строке $current / $total';
  }

  @override
  String get lyricsNextLabel => 'Далее';

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
