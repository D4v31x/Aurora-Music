// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get aboutArtist => 'Acerca del artista';

  @override
  String get add => 'Añadir';

  @override
  String get addedToPlaylist => 'Añadido a la lista de reproducción';

  @override
  String addedToNamedPlaylist(String name) {
    return 'Añadido a $name';
  }

  @override
  String get addExclusion => 'Añadir exclusión';

  @override
  String get addSeparator => 'Añadir separador';

  @override
  String get addSongs => 'Añadir canciones';

  @override
  String get addSongsToPlaylist =>
      'Añadir canciones a la lista de reproducción';

  @override
  String get addToPlaylist => 'Añadir a la lista de reproducción';

  @override
  String get adjustSync => 'Ajustar la sincronización';

  @override
  String get album => 'Álbum';

  @override
  String get albums => 'Álbumes';

  @override
  String get allSongs => 'Todas las canciones';

  @override
  String get appName => 'Aurora Music';

  @override
  String get artist => 'Artista';

  @override
  String get artistName => 'Nombre del artista';

  @override
  String get artists => 'Artistas';

  @override
  String get artistSeparation => 'Separación de artistas';

  @override
  String get artistSeparationDesc =>
      'Configurar cómo se reparten los ingresos entre varios artistas';

  @override
  String get audioQuality => 'Calidad de audio';

  @override
  String get audioQualityDesc =>
      'Especificaciones técnicas del archivo de audio';

  @override
  String get auroraMusic => 'Aurora Music';

  @override
  String get autoPlaylists => 'Listas de reproducción automáticas';

  @override
  String get autoTag => 'Etiqueta automática';

  @override
  String get smartPlaylists => 'Listas de reproducción inteligentes';

  @override
  String get createSmartPlaylist =>
      'Crear una lista de reproducción inteligente…';

  @override
  String get editSmartPlaylist => 'Editar lista de reproducción inteligente';

  @override
  String get smartPlaylistNameHint => 'Nombre de la lista de reproducción';

  @override
  String get smartPlaylistRules => 'Normas';

  @override
  String get addRule => 'Añadir regla';

  @override
  String get saveSmartPlaylist => 'Guardar';

  @override
  String get matchAll => 'Cumplir TODAS las normas';

  @override
  String get matchAny => 'Cualquier regla';

  @override
  String get limitResultsLabel => 'Limitar los resultados';

  @override
  String get noLimit => 'Sin límite';

  @override
  String get deleteSmartPlaylistConfirm =>
      '¿Quieres eliminar esta lista de reproducción inteligente? Esto solo elimina las reglas guardadas; tus canciones no se verán afectadas.';

  @override
  String smartPlaylistPreviewCount(int count) {
    return 'Ahora mismo hay $count canciones que coinciden';
  }

  @override
  String get saveAsClip => 'Guardar como clip';

  @override
  String get generatingClip => 'Generando el vídeo…';

  @override
  String get clipDuration => 'Duración del vídeo';

  @override
  String get clipStartOffset => 'Punto de partida';

  @override
  String get saveClip => 'Guardar clip';

  @override
  String get clipSavedToDevice => 'El vídeo se ha guardado en el dispositivo';

  @override
  String get clipSaveFailed =>
      'No se ha podido guardar el vídeo. Inténtalo de nuevo, por favor.';

  @override
  String get playlistSavedToDevice =>
      'Lista de reproducción guardada en el dispositivo';

  @override
  String get trackTags => 'Etiquetas de pista';

  @override
  String get editTrackTags => 'Editar etiquetas';

  @override
  String get addTrackTag => 'Añadir etiqueta';

  @override
  String get noTrackTagsYet =>
      'Aún no hay etiquetas. Añade una para ir directamente a una parte de esta pista.';

  @override
  String get trackTagNameHint =>
      'p. ej., título de la canción o nombre del artista';

  @override
  String get trackTagPosition => 'Cargo';

  @override
  String get useCurrentPosition => 'Utilizar la posición actual';

  @override
  String get isThisASet => 'Añadir marcas de tiempo a esta pista';

  @override
  String get tagPartsForEasySwitching =>
      'Marca cualquier momento: capítulos, pasajes destacados, marcadores o cualquier otra cosa.';

  @override
  String get tagThisTrack => 'Añadir etiquetas';

  @override
  String get pasteSetlist => 'Importar marcas de tiempo';

  @override
  String get pasteSetlistDialogTitle => 'Importar marcas de tiempo';

  @override
  String get pasteSetlistHint =>
      'Pega aquí las marcas de tiempo, por ejemplo:\n0:00 Introducción\n3:45 Nombre del capítulo';

  @override
  String get importAction => 'Importar';

  @override
  String tagsImportedMessage(int count) {
    return 'Etiquetas $count importadas';
  }

  @override
  String get noTagsFoundInPaste =>
      'No se han encontrado marcas de tiempo en el texto pegado.';

  @override
  String get bitrate => 'Velocidad de bits';

  @override
  String get buyMeCoffee => 'Invítame a un café';

  @override
  String get cancel => 'Cancelar';

  @override
  String get coffeeSupport => 'Apóyanos con un café';

  @override
  String get composer => 'Compositor';

  @override
  String get connectWithUs => 'Ponte en contacto con nosotros';

  @override
  String get copied => 'Copiado';

  @override
  String get copy => 'Copiar';

  @override
  String get create => 'Crear';

  @override
  String get createFirstPlaylist =>
      'Pulsa el botón de arriba para crear tu primera lista de reproducción';

  @override
  String get createPlaylist => 'Crear lista de reproducción';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get dateAdded => 'Fecha de incorporación';

  @override
  String get dateModified => 'Fecha de modificación';

  @override
  String get delete => 'Eliminar';

  @override
  String get deletePlaylist => 'Eliminar lista de reproducción';

  @override
  String get deletePlaylistConfirm => '¿Estás seguro de que quieres borrar?';

  @override
  String get deletePlaylistConfirmation =>
      '¿Estás seguro de que quieres eliminar esta lista de reproducción?';

  @override
  String get deselectAll => 'Deseleccionar todo';

  @override
  String get details => 'Ver detalles';

  @override
  String get discard => 'Descartar';

  @override
  String get dontShowAgain => 'No volver a mostrar';

  @override
  String get duration => 'Duración';

  @override
  String get enableArtistSeparation => 'Activar separación por artista';

  @override
  String get enableArtistSeparationDesc =>
      'Separar automáticamente los nombres de artistas compuestos';

  @override
  String get enjoyingAurora => '¿Te está gustando Aurora?';

  @override
  String get enjoyingAuroraDesc =>
      'Si te encanta usar Aurora Music, plantéate apoyar su desarrollo. ¡Tu apoyo ayuda a que siga siendo gratuita!';

  @override
  String get error => 'Error';

  @override
  String get exclusionHint => 'p. ej., CA/CC';

  @override
  String get exclusions => 'Exclusiones';

  @override
  String get exclusionsDesc => 'Nombres de artistas que nunca deben separarse';

  @override
  String get exit => 'Salir';

  @override
  String get exitApp => 'Salir de la aplicación';

  @override
  String get exitAppConfirm => '¿Quieres salir?';

  @override
  String get expandLyrics => 'Ver la letra completa';

  @override
  String get extraLarge => 'Extragrande';

  @override
  String get favoriteSongs => 'Canciones favoritas';

  @override
  String get fileInfo => 'Información del archivo';

  @override
  String get fileInfoDesc => 'Mantén pulsado sobre los valores para copiarlos';

  @override
  String get fileName => 'Nombre del archivo';

  @override
  String get filePath => 'Ruta del archivo';

  @override
  String get folder => 'Carpeta';

  @override
  String get folders => 'Carpetas';

  @override
  String get fontSize => 'Tamaño de la fuente';

  @override
  String get format => 'Formato';

  @override
  String get forYou => 'Para ti';

  @override
  String get general => 'General';

  @override
  String get genre => 'Género';

  @override
  String get getStarted => 'Empezar';

  @override
  String get goodQuality => 'Buena calidad';

  @override
  String get gotIt => '¡Entendido!';

  @override
  String get grantPermission => 'Conceder permiso';

  @override
  String get highQuality => 'Alta calidad';

  @override
  String get home => 'Inicio';

  @override
  String get kofi => 'Ko-fi';

  @override
  String get buyMeACoffee => 'Invítame a un café';

  @override
  String get donationNote =>
      'No te preocupes, siempre puedes hacer una donación más adelante en «Configuración».';

  @override
  String get language => 'Idioma';

  @override
  String get large => 'Grande';

  @override
  String get later => 'Más tarde';

  @override
  String get library => 'Biblioteca';

  @override
  String get libraryError => 'Error al cargar la biblioteca de música';

  @override
  String get libraryLoaded => 'Se ha cargado la biblioteca musical';

  @override
  String get libraryUpdated => 'Se ha actualizado la biblioteca';

  @override
  String get loading => 'Cargando';

  @override
  String get loadingLibrary => 'Cargando la biblioteca';

  @override
  String get lossless => 'Sin pérdidas';

  @override
  String get lowQuality => 'Baja calidad';

  @override
  String get lyrics => 'Letra de la canción';

  @override
  String get lyricsAhead => 'A continuación están las letras de las canciones';

  @override
  String get lyricsBehind => 'Las letras están más abajo';

  @override
  String get lyricsSynced => 'Las letras están sincronizadas';

  @override
  String get maybeLater => 'Quizás más tarde';

  @override
  String get medium => 'Medio';

  @override
  String get metadata => 'Metadatos';

  @override
  String get metadataSaved => 'Los metadatos se han guardado correctamente';

  @override
  String get metadataApplied => 'Los metadatos se han descargado correctamente';

  @override
  String get metadataDownloadFailed =>
      'La descarga ha fallado. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get chooseArtworkFromDevice => 'Elige un dispositivo';

  @override
  String get mostPlayed => 'Los más reproducidos';

  @override
  String get newPlaylist => 'Nueva lista de reproducción';

  @override
  String get next => 'Siguiente';

  @override
  String get no => 'No';

  @override
  String get noAlbumsFound => 'No se han encontrado álbumes';

  @override
  String get noArtistInfo => 'No hay información disponible sobre el artista';

  @override
  String get noArtistsFound => 'No se han encontrado artistas';

  @override
  String get noData => 'No hay datos que mostrar';

  @override
  String get noExclusions => 'No hay exclusiones configuradas';

  @override
  String get noLyrics => 'Letra no disponible';

  @override
  String get noLyricsDesc =>
      'No hemos podido encontrar la letra de esta canción';

  @override
  String get noLyricsFound => 'No se han encontrado letras';

  @override
  String get noPermissionExplanation =>
      'Si no concedes los permisos necesarios, Aurora Music no podrá acceder a tu biblioteca musical.';

  @override
  String get noPlaylists => 'No hay listas de reproducción disponibles';

  @override
  String get noResults => 'No se han encontrado resultados';

  @override
  String get noSeparators => 'No hay separadores configurados';

  @override
  String get noSongPlaying => 'No se está reproduciendo ninguna canción';

  @override
  String get noSongsAvailable => 'No hay canciones disponibles';

  @override
  String get noSongsInPlaylist =>
      'No hay canciones en esta lista de reproducción';

  @override
  String get nowPlaying => 'Ahora en pantalla';

  @override
  String get onboardingAlbumArt => 'Preciosas portadas de discos';

  @override
  String get onboardingAlbumArtwork => 'Portada del álbum';

  @override
  String get onboardingAlbumArtworkDesc =>
      'Obtiene carátulas de álbumes de alta calidad para mejorar tu biblioteca';

  @override
  String get onboardingAppInfoSubtitle => 'Tu compañero musical personal';

  @override
  String get onboardingAppInfoTitle => 'Bienvenidos a Aurora Music';

  @override
  String get onboardingAudioAccess => 'Acceso al audio';

  @override
  String get onboardingAudioAccessDesc =>
      'Es necesario para reproducir y gestionar tu biblioteca musical';

  @override
  String get onboardingBack => 'Atrás';

  @override
  String get onboardingBeautifulArtwork => 'Preciosa portada del álbum';

  @override
  String get onboardingBeautifulArtworkDesc =>
      'Recupera y muestra automáticamente las carátulas de los álbumes tal y como deben verse';

  @override
  String get onboardingBluetooth => 'Bluetooth';

  @override
  String get onboardingBluetoothDesc =>
      'Es necesario para conectarse a dispositivos Bluetooth';

  @override
  String get onboardingChooseLanguage => 'Elige tu idioma';

  @override
  String get languageNotListedHint =>
      '¿No aparece tu idioma en la lista? Selecciona «Inglés» y pasa a la página siguiente.';

  @override
  String get onboardingCompletionSubtitle => 'Empieza a disfrutar de tu música';

  @override
  String get onboardingCompletionTitle => '¡Ya está todo listo!';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingDynamicColors => 'Colores dinámicos';

  @override
  String get onboardingDynamicColorsDesc =>
      'Combinar los colores del fondo de pantalla con los del sistema';

  @override
  String get onboardingGrantPermissions => 'Conceder permisos';

  @override
  String get onboardingInternetSubtitle => 'Cómo utiliza Aurora Music Internet';

  @override
  String get onboardingInternetTitle => 'Uso de Internet';

  @override
  String get onboardingLocalMusic => 'Música en tu dispositivo';

  @override
  String get onboardingLocalMusicDesc =>
      'Lleva tus archivos de música en la palma de tu mano';

  @override
  String get onboardingLyrics => 'Letra de la canción';

  @override
  String get onboardingLyricsDesc =>
      'Descargas de letras sincronizadas para tus canciones';

  @override
  String get onboardingLyricsSupport => 'Ayuda con las letras de las canciones';

  @override
  String get onboardingLyricsSupportDesc =>
      'Ver la letra sincronizada mientras escuchas';

  @override
  String get onboardingMaterialDesign => 'Diseño «Material You»';

  @override
  String get onboardingMaterialDesignDesc =>
      'Colores dinámicos que se adaptan a tus preferencias';

  @override
  String get onboardingMusicMetadata => 'Metadatos musicales';

  @override
  String get onboardingMusicMetadataDesc =>
      'Obtiene información sobre el artista, detalles del álbum e información sobre las canciones';

  @override
  String get onboardingNotifications => 'Notificaciones';

  @override
  String get onboardingNotificationsDesc =>
      'Mostrar controles de reproducción y actualizaciones';

  @override
  String get onboardingOptional => 'Opcional';

  @override
  String get onboardingPermissionsSubtitle =>
      'Aurora Music necesita estos permisos para funcionar correctamente';

  @override
  String get onboardingPermissionsTitle => 'Conceder permisos';

  @override
  String get onboardingPrivacyNote =>
      'Tu privacidad es importante. Todos los archivos de música permanecen en tu dispositivo.';

  @override
  String get onboardingRequesting => 'Solicitando...';

  @override
  String get onboardingRequired => 'Obligatorio';

  @override
  String get onboardingAudioRequired =>
      'Es necesario tener acceso al audio para continuar. Por favor, concede el permiso indicado anteriormente.';

  @override
  String get onboardingSelectLanguage => 'Selecciona tu idioma preferido';

  @override
  String get onboardingSmartPlaylists => 'Listas de reproducción inteligentes';

  @override
  String get onboardingSmartPlaylistsDesc =>
      'Crea y gestiona tus colecciones de música';

  @override
  String get onboardingStartListening => 'Empieza a escuchar';

  @override
  String get onboardingStorageAccess => 'Acceso al almacenamiento';

  @override
  String get onboardingStorageAccessDesc =>
      'Es necesario para leer archivos de música de tu dispositivo';

  @override
  String get onboardingVisualizerAccess => 'Visualizador';

  @override
  String get onboardingVisualizerAccessDesc =>
      'Permite que el visualizador lea la sesión de audio de tu dispositivo para mostrar el espectro en tiempo real. No se graba ningún audio en ningún momento.';

  @override
  String get onboardingThemeSubtitle =>
      'Elige un tema que se adapte a tu estilo';

  @override
  String get onboardingThemeTitle => 'Personaliza tu look';

  @override
  String get beta_welcome_title => 'Programa de pruebas beta';

  @override
  String get beta_welcome_thanks =>
      'Gracias por participar en nuestro programa de pruebas beta y por ayudarnos a mejorar Aurora Music.';

  @override
  String get beta_expect_bugs_title => 'Prepárate para los errores';

  @override
  String get beta_expect_bugs_desc =>
      'Es posible que se produzcan fallos o comportamientos inesperados. Se trata de una versión de prueba.';

  @override
  String get beta_feedback_title => 'La opinión de los usuarios es importante';

  @override
  String get beta_feedback_desc =>
      'Vuestros comentarios y sugerencias nos ayudan a mejorar la aplicación para todos.';

  @override
  String get beta_updates_title => 'Actualizaciones frecuentes';

  @override
  String get beta_updates_desc =>
      'A medida que avanzamos en el desarrollo, se publican periódicamente nuevas funciones y correcciones.';

  @override
  String get oneTimeSupport => 'Asistencia rápida y puntual';

  @override
  String get openFolder => 'Abrir en el Gestor de archivos';

  @override
  String get openFolderInfo =>
      'Utiliza tu gestor de archivos para acceder a esta ubicación';

  @override
  String get ownTimer => 'Temporizador propio';

  @override
  String get permDeny => 'Permisos denegados';

  @override
  String get permissionExplanation =>
      'Aurora Music necesita estos permisos para funcionar correctamente. Concede los permisos en los ajustes de la aplicación.';

  @override
  String get permissionLater =>
      'Puedes conceder permisos más adelante en la configuración de la aplicación.';

  @override
  String get permissionRequired => 'Se requiere autorización';

  @override
  String get playAll => 'Reproducir todo';

  @override
  String get playingFrom => 'Reproducción desde';

  @override
  String get playlist => 'Lista de reproducción';

  @override
  String get playlistName => 'Nombre de la lista de reproducción';

  @override
  String get playlists => 'Listas de reproducción';

  @override
  String get possibleReasons => 'Posibles motivos:';

  @override
  String get privacyNotice =>
      'Al seguir utilizando esta aplicación, aceptas nuestra Política de privacidad.';

  @override
  String get privacyPolicyLink => 'Lee nuestra Política de privacidad';

  @override
  String get quality => 'Calidad';

  @override
  String get qualityDesc =>
      'Calidad de audio en función del formato y la tasa de bits';

  @override
  String get queue => 'Cola';

  @override
  String get queueEmpty => 'La cola está vacía';

  @override
  String get reasonFormat =>
      'El formato de archivo no permite editar los metadatos';

  @override
  String get reasonPermissions =>
      'No se han concedido los permisos de almacenamiento';

  @override
  String get reasonReadonly =>
      'El archivo es de solo lectura o se encuentra en un dispositivo de almacenamiento externo';

  @override
  String get recentlyAdded => 'Añadidos recientemente';

  @override
  String get recentlyPlayed => 'Últimos juegos';

  @override
  String get recentlyPlayedArtists =>
      'Artistas que se han reproducido recientemente';

  @override
  String get recentlyPlayedSongs => 'Canciones escuchadas recientemente';

  @override
  String get refreshing => 'Qué refrescante...';

  @override
  String get refreshLyrics => 'Actualizar la letra de la canción';

  @override
  String get remove => 'Eliminar';

  @override
  String get removeSong => 'Eliminar canción';

  @override
  String get removeSongConfirmation =>
      '¿Quieres eliminar esta canción de la lista de reproducción?';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get renamePlaylist => 'Cambiar el nombre de la lista de reproducción';

  @override
  String get repeat => 'Repetir';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetArtistSeparationDesc =>
      'Esto restablecerá todos los separadores y exclusiones predeterminados.';

  @override
  String get resetToDefaults => 'Restablecer valores predeterminados';

  @override
  String get result => 'Resultado';

  @override
  String get results => 'Resultados';

  @override
  String get retry => 'Volver a intentarlo';

  @override
  String get sampleRate => 'Frecuencia de muestreo';

  @override
  String get save => 'Guardar';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get saveChangesDesc => '¿Quieres guardar los cambios?';

  @override
  String get saveFailed => 'Error al guardar';

  @override
  String get saveFailedDesc =>
      'No se han podido guardar los metadatos en este archivo.';

  @override
  String get scanFailed => 'Error al escanear';

  @override
  String get scanningSongs => 'Escanear canciones';

  @override
  String get search => 'Buscar';

  @override
  String get searchAlbums => 'Buscar álbumes';

  @override
  String get searchArtists => 'Buscar artistas';

  @override
  String get searchFailed => 'La búsqueda no se ha podido realizar';

  @override
  String get searchLyrics => 'Buscar letras de canciones';

  @override
  String get searchMetadata => 'Buscar metadatos';

  @override
  String get searchTracks => 'Buscar canciones';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectArtist => 'Seleccionar artista';

  @override
  String get selected => 'seleccionado';

  @override
  String get selectPlaylist => 'Seleccionar lista de reproducción';

  @override
  String get separator => 'Separador';

  @override
  String get separatorHint => 'p. ej. / o con la participación de';

  @override
  String get separators => 'Separadores';

  @override
  String get set => 'Conjunto';

  @override
  String get setMinutes => 'Establecer la duración de las reuniones';

  @override
  String get settings => 'Configuración';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsAboutApp => 'Acerca de Aurora Music';

  @override
  String get settingsAboutSubtitle => 'Versión, comentarios y actualizaciones';

  @override
  String get settingsAccentColor => 'Color de contraste';

  @override
  String get settingsAppearance => 'Aspecto';

  @override
  String get settingsAppearanceSubtitle => 'Theme, colors & layout';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsBackground => 'Background';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsCacheInfo => 'Cache Information';

  @override
  String get settingsCacheInfoDesc => 'View storage usage';

  @override
  String get settingsCheckingUpdates => 'Checking for updates...';

  @override
  String get settingsCheckUpdates => 'Check for Updates';

  @override
  String get settingsCheckUpdatesDesc => 'Get latest version';

  @override
  String get settingsClearCache => 'Clear Cache';

  @override
  String get settingsClearCacheDesc => 'Remove all cached data';

  @override
  String get settingsClearCacheMessage =>
      'All cached data will be deleted and rebuilt as needed.';

  @override
  String get settingsClearCacheTitle => 'Clear Cache?';

  @override
  String get settingsDataWindow => 'Data Window';

  @override
  String get settingsDataWindowDesc => 'How far back the recap screen looks';

  @override
  String get settingsGapless => 'Gapless Playback';

  @override
  String get settingsGaplessDesc => 'Seamless track transitions';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsCrossfadeDesc =>
      'Smoothly blend the end of one track into the next';

  @override
  String get crossfadeDuration => 'Crossfade Duration';

  @override
  String get crossfadeDurationDesc =>
      'How long the overlap between tracks lasts';

  @override
  String get settingsInsights => 'Insights';

  @override
  String get settingsInsightsSubtitle => 'Listening recap period';

  @override
  String get settingsLast7Days => 'Last 7 Days';

  @override
  String get settingsLast30Days => 'Last 30 Days';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLayout => 'Layout';

  @override
  String get settingsLibraryFolders => 'Library Folders';

  @override
  String get settingsLibraryFoldersSubtitle =>
      'Include or exclude scan folders';

  @override
  String get settingsMaterialYou => 'Material You';

  @override
  String get settingsMaterialYouDesc => 'Dynamic colors from wallpaper';

  @override
  String get settingsMonthlyRecap => 'Monthly Recap';

  @override
  String get settingsMonthlyRecapDesc =>
      'Show a banner every month (takes precedence over weekly)';

  @override
  String get settingsNormalization => 'Volume Normalization';

  @override
  String get settingsNormalizationDesc =>
      'Consistent volume levels · Requires ReplayGain tags in your files';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get playbackSpeedDesc => 'Adjust audio playback rate';

  @override
  String get adjustPitchWithSpeed => 'Adjust pitch with speed';

  @override
  String get adjustPitchWithSpeedDesc =>
      'When off, tempo changes without pitch shift';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsPlaybackSubtitle => 'Speed, gapless & normalization';

  @override
  String get settingsRecapBannerDesc =>
      'The banner appears on the home screen at the start of each new week or month counted from your very first play. Tapping \"Later\" hides it for the session; tapping \"Show\" marks it as seen.';

  @override
  String get settingsRecapContent => 'Recap Content';

  @override
  String get settingsRecapContentDesc =>
      'Controls how much history the recap screen displays when you open it manually or via the banner.';

  @override
  String get settingsPreviewRecap => 'Preview Recap';

  @override
  String get settingsPreviewRecapDesc =>
      'See how your recap looks right now with the current settings';

  @override
  String get settingsRecapSchedule => 'Recap Schedule';

  @override
  String get settingsStorage => 'Storage';

  @override
  String settingsCacheItems(String count) {
    return '$count items';
  }

  @override
  String get settingsMemoryCache => 'Memory Cache';

  @override
  String get settingsStorageSubtitle => 'Cache & media files';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsTools => 'Tools';

  @override
  String get settingsResetSetup => 'Reset Setup';

  @override
  String get settingsResetSetupDesc => 'Restart the onboarding flow';

  @override
  String get settingsUpdateAvailable => 'Update available!';

  @override
  String get settingsUpToDate => 'You\'re up to date';

  @override
  String get settingsWeeklyRecap => 'Weekly Recap';

  @override
  String get settingsWeeklyRecapDesc =>
      'Show a banner every week after your first play';

  @override
  String get settingsVersion => 'Version';

  @override
  String get share => 'Share';

  @override
  String get showChangelog => 'Show Changelog';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get size => 'Size';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get small => 'Small';

  @override
  String get songInfo => 'Song Info';

  @override
  String get songs => 'Songs';

  @override
  String get songsLoaded => 'Songs loaded';

  @override
  String get standardQuality => 'Standard Quality';

  @override
  String get startType => 'Start typing to search';

  @override
  String get storagePermissionNeeded =>
      'To edit metadata, Aurora Music needs permission to manage files. Please grant \'All files access\' in settings.';

  @override
  String get suggestedArtists => 'Artists For You';

  @override
  String get suggestedTracks => 'Suggested Tracks';

  @override
  String get supportAurora => 'Support Aurora';

  @override
  String get supportAuroraBtn => 'Support Aurora';

  @override
  String get supportAuroraDescShort => 'Help keep the app free';

  @override
  String get supportAuroraMessage =>
      'Help keep Aurora Music free and support future development. Every contribution means a lot!';

  @override
  String get supportAuroraTitle => 'Support Aurora Music';

  @override
  String get tapAddToAddSongs => 'Tap + to add songs';

  @override
  String get reorderSongs => 'Reorder Songs';

  @override
  String get done => 'Done';

  @override
  String get thankYouSupport => 'Thank you for your support!';

  @override
  String get theme => 'Theme';

  @override
  String get title => 'Title';

  @override
  String get topResult => 'Top Result';

  @override
  String get total => 'Total';

  @override
  String get track => 'Track';

  @override
  String get trackInfo => 'Track Info';

  @override
  String get trackInfoDesc => 'Tap the edit icon to modify track information';

  @override
  String get trackInfoEditDesc =>
      'Edit fields below, then tap the check icon to save';

  @override
  String get tracks => 'Tracks';

  @override
  String get unknown => 'Unknown';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get updateMessage => 'A new version is available';

  @override
  String get updateNow => 'Update Now';

  @override
  String get viewArtist => 'View artist';

  @override
  String get viewDetails => 'View details';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get whatsNew => 'What\'s new';

  @override
  String get view_changelog => 'View changelog and new features';

  @override
  String get year => 'Year';

  @override
  String get yes => 'Yes';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get yourPlaylists => 'Your Playlists';

  @override
  String get homeLayout => 'Home Layout';

  @override
  String get homeLayoutDesc => 'Customize section order on Home tab';

  @override
  String get customizeHomeTab => 'Customize Home Tab';

  @override
  String get dragToReorder => 'Drag to reorder sections';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get resetLayoutConfirm => 'Reset layout to default?';

  @override
  String get resetLayoutMessage =>
      'This will restore the original section order and visibility.';

  @override
  String get sectionVisibility => 'Toggle section visibility';

  @override
  String get listeningHistory => 'Listening History';

  @override
  String get libraryStats => 'Library Stats';

  @override
  String get back => 'Back';

  @override
  String get continueButton => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get feedback_title => 'Enjoying Aurora Music?';

  @override
  String get maybe_later => 'Maybe Later';

  @override
  String get send_feedback => 'Send Feedback';

  @override
  String get send_feedback_desc => 'Report bugs or suggest features';

  @override
  String get contributeTranslations => 'Contribute Translations';

  @override
  String get contributeTranslationsDesc =>
      'Help translate Aurora Music on Crowdin';

  @override
  String get contributeTranslationsTitle => 'Help Us Translate';

  @override
  String get contributeTranslationsSubtitle =>
      'Aurora Music is available in multiple languages thanks to our amazing community. Help us reach even more users by translating the app into your language — it only takes a few minutes to get started.';

  @override
  String get contributeTranslationsOpenCrowdin => 'Open Crowdin';

  @override
  String get close => 'Close';

  @override
  String get settingsHighendUi => 'High-end UI';

  @override
  String get settingsHighendUiDesc =>
      'Enable advanced visual effects and animations';

  @override
  String get restartRequired => 'Restart Required';

  @override
  String get restartRequiredDesc =>
      'The app needs to restart to apply the UI mode change. Restart now?';

  @override
  String get restartNow => 'Restart Now';

  @override
  String get clearUpcoming => 'Clear upcoming';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get playNext => 'Play next';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get play => 'Play';

  @override
  String get viewAlbum => 'View Album';

  @override
  String get shuffleAll => 'Shuffle All';

  @override
  String get noSongsFound => 'No songs found';

  @override
  String get noFoldersFound => 'No folders found';

  @override
  String get deleteSong => 'Delete Song';

  @override
  String get modifySystemSettingsPermission =>
      'Allow \"Modify system settings\" in the page that opened, then try again.';

  @override
  String errorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String songsAddedToQueue(int count) {
    return '$count songs added to queue';
  }

  @override
  String songAddedToQueue(String title) {
    return '\"$title\" added to queue';
  }

  @override
  String songSetAsRingtone(String title) {
    return '\"$title\" set as ringtone';
  }

  @override
  String failedToSetRingtone(String error) {
    return 'Failed to set ringtone: $error';
  }

  @override
  String deleteSongConfirm(String title) {
    return 'Delete \"$title\" from your device? This cannot be undone.';
  }

  @override
  String songDeleted(String title) {
    return '\"$title\" deleted';
  }

  @override
  String failedToDelete(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String songCount(int count) {
    return '$count songs';
  }

  @override
  String get badgeNew => 'NEW';

  @override
  String get paused => 'Paused';

  @override
  String get readyToPlay => 'Ready to play';

  @override
  String get tapSongToStartListening => 'Tap a song to start listening';

  @override
  String get clearCachedLyrics => 'Clear cached lyrics';

  @override
  String lyricsCleared(String title) {
    return 'Cached lyrics cleared for \"$title\"';
  }

  @override
  String get noLyricsCached => 'No cached lyrics found for this song';

  @override
  String get setAsRingtone => 'Set as ringtone';

  @override
  String get songInfoEdit => 'Song info / Edit';

  @override
  String get goToAlbum => 'Go to album';

  @override
  String get goToArtist => 'Go to artist';

  @override
  String get deleteFromDevice => 'Delete from device';

  @override
  String get checkOutThisSong => 'Check out this song!';

  @override
  String get backgroundLowEndStyle => 'Background Style';

  @override
  String get backgroundLowEndStyleDesc => 'How the app background looks';

  @override
  String get backgroundBlobs => 'Animated Blobs';

  @override
  String get backgroundSolid => 'Solid Color';

  @override
  String get backgroundHighEndStyle => 'Now Playing Background';

  @override
  String get backgroundHighEndStyleDesc =>
      'Background style in the Now Playing screen';

  @override
  String get backgroundBlurredArtwork => 'Blurred Artwork';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get accentColorDesc => 'Choose the app accent color';

  @override
  String get backgroundBlur => 'Background Blur';

  @override
  String get backgroundBlurDesc => 'Artwork blur intensity';

  @override
  String get backgroundDarkness => 'Background Darkness';

  @override
  String get backgroundDarknessDesc => 'Overlay opacity on artwork';

  @override
  String get microphoneAccessNeeded => 'Microphone access needed';

  @override
  String get microphoneAccessDesc =>
      'Aurora needs microphone access to tap your device\'s audio session for the live visualizer. No audio is ever recorded or stored.';

  @override
  String get recapWeek => 'week';

  @override
  String get recapMonth => 'month';

  @override
  String get recapPeriodWeek => 'Week';

  @override
  String get recapPeriodMonth => 'Month';

  @override
  String get recapWeekly => 'Weekly';

  @override
  String get recapMonthly => 'Monthly';

  @override
  String get recapIntroAppName => 'AURORA MUSIC';

  @override
  String recapIntroTitle(String period) {
    return 'Your $period\nRecap';
  }

  @override
  String get recapIntroSubtitle =>
      'Let\'s see what you\'ve been\nlistening to.';

  @override
  String recapPlayedEyebrow(String period) {
    return 'This $period you played music';
  }

  @override
  String get recapTimeSingular => 'time';

  @override
  String get recapTimePlural => 'times';

  @override
  String get recapListenedForEyebrow => 'You listened for';

  @override
  String get recapListenedForLabel => 'of music';

  @override
  String get recapTopTrackEyebrow => 'Your #1 track';

  @override
  String get recapPlays => 'plays';

  @override
  String get recapTopTracksTitle => 'Top Tracks';

  @override
  String get recapTopArtistEyebrow => 'Your top artist';

  @override
  String get recapTopArtistsTitle => 'Top Artists';

  @override
  String get recapNothingToWrap => 'Nothing to wrap yet';

  @override
  String recapNothingToWrapBody(String period) {
    return 'Play some music this $period and come back.';
  }

  @override
  String get recapSwipeUp => 'SWIPE UP';

  @override
  String get recapYourSoundLabel => 'YOUR SOUND';

  @override
  String get recapYouListenMost => 'YOU LISTEN MOST';

  @override
  String recapOnDay(String day) {
    return 'on ${day}s';
  }

  @override
  String recapAroundTime(String time) {
    return 'around $time';
  }

  @override
  String get recapVibesHitDifferent => 'That\'s when the vibes hit different.';

  @override
  String get recapThatsAWrap => 'THAT\'S A WRAP';

  @override
  String recapInNumbers(String period) {
    return 'Your $period\nin Numbers';
  }

  @override
  String get recapNumberOneTrack => '#1 TRACK';

  @override
  String get recapStatTotalPlays => 'Total Plays';

  @override
  String get recapStatTimeListened => 'Time Listened';

  @override
  String get recapStatUniqueTracks => 'Unique Tracks';

  @override
  String get recapStatTopArtist => 'Top Artist';

  @override
  String get recapDone => 'Done';

  @override
  String get recapWeekdayMonday => 'Monday';

  @override
  String get recapWeekdayTuesday => 'Tuesday';

  @override
  String get recapWeekdayWednesday => 'Wednesday';

  @override
  String get recapWeekdayThursday => 'Thursday';

  @override
  String get recapWeekdayFriday => 'Friday';

  @override
  String get recapWeekdaySaturday => 'Saturday';

  @override
  String get recapWeekdaySunday => 'Sunday';

  @override
  String get recapBannerTitle => 'Music recap is here';

  @override
  String get recapBannerShow => 'Show';

  @override
  String get recapBannerLater => 'Later';

  @override
  String get eqTitle => 'Equalizer';

  @override
  String get eqOn => 'ON';

  @override
  String get eqOff => 'OFF';

  @override
  String get eqNotAvailable => 'Equalizer not available on this device.';

  @override
  String get eqOpenSystem => 'Open System Equalizer';

  @override
  String get eqSavePreset => 'Save Preset';

  @override
  String get eqPresetNameHint => 'e.g. My Bass Boost';

  @override
  String get eqPresetNameEmpty => 'Name cannot be empty.';

  @override
  String eqPresetNameBuiltIn(String name) {
    return '\"$name\" is a built-in preset name.';
  }

  @override
  String get eqResetAllBands => 'Reset all bands';

  @override
  String get eqPresetsLabel => 'PRESETS';

  @override
  String get eqYourPresetsLabel => 'YOUR PRESETS';

  @override
  String get eqSaveCurrent => 'Save current';

  @override
  String get eqSettingsSubtitle => 'Adjust audio frequencies per band';

  @override
  String get eqEmptyPresets => 'Dial in your sound, then tap \"Save current\".';

  @override
  String get lyricsHint =>
      'Paste unsynced lyrics here…\n\nOne line per verse line.';

  @override
  String get lyricsSelectLrcFile => 'Please select a .lrc file';

  @override
  String get lyricsNoLyricsInFile => 'No lyrics found in that file';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get lyricsImportTooltip => 'Import .lrc file';

  @override
  String get importPlaylistM3u => 'Import playlist (.m3u)';

  @override
  String get setSyncFolder => 'Set sync folder…';

  @override
  String get syncNow => 'Sync now';

  @override
  String get searchPlaylists => 'Search playlists…';

  @override
  String get pleaseSelectM3uFile => 'Please select an .m3u or .m3u8 file';

  @override
  String get noMatchingSongsForPlaylist =>
      'No matching songs found for that playlist';

  @override
  String importedPlaylist(String name, int count) {
    return 'Imported \"$name\" ($count songs)';
  }

  @override
  String playlistsSyncWith(String folder) {
    return 'Playlists will sync with: $folder';
  }

  @override
  String couldNotSetSyncFolder(String error) {
    return 'Could not set sync folder: $error';
  }

  @override
  String get setSyncFolderFirst => 'Set a sync folder first';

  @override
  String get playlistsSynced => 'Playlists synced';

  @override
  String get alreadyUpToDate => 'Already up to date';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get searchFolders => 'Search folders…';

  @override
  String get songInfoPath => 'Path';

  @override
  String get closeVisualiser => 'Close visualiser';

  @override
  String get previousMode => 'Previous mode';

  @override
  String get nextMode => 'Next mode';

  @override
  String get sortBy => 'Sort by';

  @override
  String get colorTheme => 'Color Theme';

  @override
  String get insightsTotalPlays => 'Total\nPlays';

  @override
  String get insightsTracksHeard => 'Tracks\nHeard';

  @override
  String get insightsEstListening => 'Est.\nListening';

  @override
  String get dismiss => 'Dismiss';

  @override
  String updateVersionAvailable(String version) {
    return 'Version $version is now available.';
  }

  @override
  String get updateNewVersionAvailable => 'A new version is now available.';

  @override
  String get lyricsPasteLyricsTitle => 'Paste Lyrics';

  @override
  String get lyricsUseLyrics => 'Use Lyrics';

  @override
  String get lyricsPaste => 'Paste';

  @override
  String get lyricsNoLyricsYet => 'No lyrics yet';

  @override
  String get lyricsPasteToGetStarted => 'Paste lyrics to get started';

  @override
  String get lyricsNoTimestampsYet =>
      'No timestamps yet — tap the stamp button while the song plays.';

  @override
  String get lyricsAllLinesStampedHint =>
      'All lines stamped — tap Save to finish.';

  @override
  String get lyricsAllStamped => '✓  All lines stamped';

  @override
  String get lyricsPasteFirst => 'Paste lyrics first';

  @override
  String lyricsTapToStamp(int current, int total) {
    return '⏱  TAP TO STAMP LINE $current / $total';
  }

  @override
  String get lyricsNextLabel => 'Next';

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
