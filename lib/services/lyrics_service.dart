import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/timed_lyrics.dart';

class TimedLyricsService {
  static const String apiBaseUrl = 'https://lrclib.net/api';

  Future<List<TimedLyric>?> fetchTimedLyrics(String artist, String title) async {
    try {
      print('⏳ Začínám hledat texty pro: $artist - $title');

      // Nejprve zkusíme načíst z lokálního úložiště
      final localLyrics = await loadLyricsFromFile(artist, title);
      if (localLyrics != null) {
        print('✅ Nalezeny lokální texty');
        return localLyrics;
      }

      // Nejprve zkusíme přímé vyhledání pomocí /api/get
      final directUrl = Uri.parse('$apiBaseUrl/get').replace(queryParameters: {
        'track_name': title,
        'artist_name': artist,
      });
      print('🔍 Zkouším přímé vyhledání: ${directUrl.toString()}');

      final directResponse = await http.get(
        directUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v0.0.85 (https://github.com/D4v31x/Aurora-Music)'
        },
      );

      print('📥 Přímé vyhledání status: ${directResponse.statusCode}');

      if (directResponse.statusCode == 200) {
        final directData = json.decode(directResponse.body);
        print('📦 Nalezena přímá shoda');
        return _processLyricsResponse(directData, artist, title);
      }

      // Pokud přímé vyhledání selže, zkusíme search API
      print('🔄 Přímé vyhledání selhalo, zkouším search API');
      final searchUrl = Uri.parse('$apiBaseUrl/search').replace(queryParameters: {
        'track_name': title,
        'artist_name': artist,
      });

      final searchResponse = await http.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v1.0.0 (https://github.com/yourusername/auroramusic)'
        },
      );

      if (searchResponse.statusCode == 200) {
        final List searchResults = json.decode(searchResponse.body);
        print('🎯 Počet nalezených výsledků: ${searchResults.length}');

        if (searchResults.isNotEmpty) {
          final firstResult = searchResults[0];
          return _processLyricsResponse(firstResult, artist, title);
        }
      }

      print('❌ Texty nenalezeny');
      return null;

    } catch (e, stackTrace) {
      print('❌ Chyba při stahování textů:');
      print('🔴 Error: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<TimedLyric>?> _processLyricsResponse(
    Map<String, dynamic> data, 
    String artist, 
    String title
  ) async {
    try {
      final String? syncedLyrics = data['syncedLyrics'];
      if (syncedLyrics == null || syncedLyrics.isEmpty) {
        print('⚠️ Synchronizované texty nejsou k dispozici');
        return null;
      }

      print('📝 Zpracovávám synchronizované texty');
      final lyrics = _parseLrc(syncedLyrics);
      
      if (lyrics.isNotEmpty) {
        print('💾 Ukládám texty lokálně');
        await _saveLyricsToFile(artist, title, syncedLyrics);
      }

      return lyrics;
    } catch (e) {
      print('❌ Chyba při zpracování odpovědi: $e');
      return null;
    }
  }

  // Parsuje obsah LRC souboru do seznamu TimedLyric
  List<TimedLyric> _parseLrc(String lrcContent) {
    print('🔍 Začínám parsovat LRC obsah');
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final lines = lrcContent.split('\n');
    List<TimedLyric> timedLyrics = [];

    print('📝 Celkový počet řádků: ${lines.length}');

    for (var i = 0; i < lines.length; i++) {
      try {
        final line = lines[i];
        final match = regex.firstMatch(line);
        
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final millisStr = match.group(3)!;
          final text = match.group(4)!.trim();

          final millis = int.parse(millisStr) * (millisStr.length == 2 ? 10 : 1);
          
          if (text.isNotEmpty) {
            final time = Duration(
              minutes: minutes, 
              seconds: seconds, 
              milliseconds: millis
            );
            timedLyrics.add(TimedLyric(time: time, text: text));
            print('✅ Řádek $i: [${time.toString()}] $text');
          } else {
            print('⚠️ Řádek $i: Prázdný text');
          }
        } else {
          print('ℹ️ Řádek $i: Neodpovídá formátu LRC: $line');
        }
      } catch (e) {
        print('❌ Chyba při parsování řádku $i:');
        print('🔴 Error: $e');
        continue;
      }
    }

    timedLyrics.sort((a, b) => a.time.compareTo(b.time));
    print('✨ Úspěšně zpracováno ${timedLyrics.length} časovaných textů');
    return timedLyrics;
  }

  // Uloží LRC soubor do lokálního úložiště
  Future<void> _saveLyricsToFile(String artist, String title, String content) async {
    try {
      print('💾 Začínám ukládat LRC soubor');
      final directory = await getApplicationDocumentsDirectory();
      
      final safeArtist = artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      print('📝 Vyčištěné názvy: $safeArtist - $safeTitle');
      
      final filePath = '${directory.path}/lyrics/${safeArtist}_$safeTitle.lrc';
      print('📂 Cesta k souboru: $filePath');
      
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsString(content);
      print('✅ LRC soubor úspěšně uložen');
    } catch (e) {
      print('❌ Chyba při ukládání LRC souboru:');
      print('🔴 Error: $e');
    }
  }

  // Načte LRC soubor z lokálního úložiště
  Future<List<TimedLyric>?> loadLyricsFromFile(String artist, String title) async {
    try {
      print('🔍 Hledám lokální LRC soubor');
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/lyrics/${artist}_$title.lrc';
      print('📂 Kontroluji cestu: $filePath');
      
      final file = File(filePath);
      if (await file.exists()) {
        print('✅ Soubor nalezen, načítám obsah');
        final content = await file.readAsString();
        print('📝 Načteno ${content.length} znaků');
        return _parseLrc(content);
      } else {
        print('ℹ️ Soubor neexistuje');
      }
      return null;
    } catch (e) {
      print('❌ Chyba při načítání lokálního souboru:');
      print('🔴 Error: $e');
      return null;
    }
  }
}
