import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/timed_lyrics.dart';

class TimedLyricsService {
  // Stáhne LRC soubor pro danou skladbu a uloží ho lokálně
  Future<List<TimedLyric>?> fetchTimedLyrics(String artist, String title) async {
    final query = '$artist $title'.replaceAll(' ', '+');
    final url = Uri.parse('https://lrclib.net/search/$query'); // Aktualizujte URL dle potřeby

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Předpokládejme, že API vrací URL k LRC souboru
        final data = json.decode(response.body);
        final lrcUrl = data['lrc_url'];

        if (lrcUrl != null) {
          final lrcResponse = await http.get(Uri.parse(lrcUrl));
          if (lrcResponse.statusCode == 200) {
            final lyrics = _parseLrc(lrcResponse.body);
            await _saveLyricsToFile(artist, title, lrcResponse.body);
            return lyrics;
          }
        }
      }
    } catch (e) {
      print('Chyba při stahování LRC souboru: $e');
    }
    return null;
  }

  // Parsuje obsah LRC souboru do seznamu TimedLyric
  List<TimedLyric> _parseLrc(String lrcContent) {
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');
    final lines = lrcContent.split('\n');
    List<TimedLyric> timedLyrics = [];

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();

        final time = Duration(minutes: minutes, seconds: seconds, milliseconds: millis * 10);
        timedLyrics.add(TimedLyric(time: time, text: text));
      }
    }

    timedLyrics.sort((a, b) => a.time.compareTo(b.time));
    return timedLyrics;
  }

  // Uloží LRC soubor do lokálního úložiště
  Future<void> _saveLyricsToFile(String artist, String title, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/lyrics/${artist}_$title.lrc';
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  // Načte LRC soubor z lokálního úložiště
  Future<List<TimedLyric>?> loadLyricsFromFile(String artist, String title) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/lyrics/${artist}_$title.lrc';
    final file = File(filePath);

    if (await file.exists()) {
      final content = await file.readAsString();
      return _parseLrc(content);
    }
    return null;
  }
}
