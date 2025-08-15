import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/timed_lyrics.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';

class FullLyricsScreen extends StatefulWidget {
const FullLyricsScreen({super.key});

static Route<void> route() {
return PageRouteBuilder(
pageBuilder: (context, animation, secondaryAnimation) => const FullLyricsScreen(),
transitionsBuilder: (context, animation, secondaryAnimation, child) {
return FadeTransition(
opacity: animation,
child: child,
);
},
transitionDuration: const Duration(milliseconds: 300),
);
}

@override
State<FullLyricsScreen> createState() => _FullLyricsScreenState();
}

class _FullLyricsScreenState extends State<FullLyricsScreen> {
late AudioPlayerService audioPlayerService;
late TimedLyricsService timedLyricsService;
List<TimedLyric>? _timedLyrics;
int _currentLyricIndex = 0;
final Map<int, Uint8List?> _artworkCache = {};
final ScrollController _scrollController = ScrollController();
final GlobalKey _activeLineKey = GlobalKey();

@override
void initState() {
super.initState();
audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
timedLyricsService = TimedLyricsService();
_loadCurrentSongLyrics();
audioPlayerService.currentSongStream.listen((song) {
_loadCurrentSongLyrics();
});
}

Future<void> _loadCurrentSongLyrics() async {
if (audioPlayerService.currentSong != null) {
// Reset scroll position and current index first
if (mounted) {
setState(() {
_timedLyrics = null;
_currentLyricIndex = 0;
});

if (_scrollController.hasClients) {
_scrollController.jumpTo(0);
}
}

final song = audioPlayerService.currentSong!;
// Attempt to load from local storage
var lyrics = await timedLyricsService.loadLyricsFromFile(
song.artist ?? 'Unknown',
song.title ?? 'Unknown',
);

// If not available locally, fetch from API
lyrics ??= await timedLyricsService.fetchTimedLyrics(
song.artist ?? 'Unknown',
song.title ?? 'Unknown',
);

if (mounted) {
setState(() {
_timedLyrics = lyrics ?? [];
});
}

// Update artwork
await _updateArtwork(song);
}
}

Future<void> _updateArtwork(SongModel song) async {
try {
final artwork = await _getArtwork(song.id);
if (mounted) {
setState(() {
_artworkCache[song.id] = artwork;
});
}
} catch (e) {
if (mounted) {
setState(() {
_artworkCache[song.id] = null;
});
}
}
}

Future<Uint8List?> _getArtwork(int id) async {
try {
final artwork = await OnAudioQuery().queryArtwork(
id,
ArtworkType.AUDIO,
quality: 100,
size: 1000,
);
return artwork;
} catch (e) {
return null;
}
}

void _scrollToCurrentLyric() {
if (_scrollController.hasClients && _timedLyrics != null) {
final itemCount = _timedLyrics!.length;
if (itemCount == 0) return;

// Get the current viewport dimensions
final viewportHeight = _scrollController.position.viewportDimension;
final currentOffset = _scrollController.offset;
final maxScroll = _scrollController.position.maxScrollExtent;

// Calculate the position of the current lyric
const itemHeight = 50.0; // Approximate height of each lyric item
final currentPosition = _currentLyricIndex * itemHeight;

// Don't scroll if we're at the top and the current lyric is visible
if (currentPosition < viewportHeight / 2 && currentOffset <= 0) {
return;
}

// Don't scroll if we're at the bottom and the current lyric is visible
if (currentPosition > maxScroll - viewportHeight / 2 && 
currentOffset >= maxScroll) {
return;
}

// Calculate the target scroll offset to center the current lyric
final targetOffset = currentPosition - (viewportHeight / 2) + (itemHeight / 2);

// Only scroll if the target offset is different from current
if ((targetOffset - currentOffset).abs() > itemHeight / 2) {
_scrollController.animateTo(
targetOffset.clamp(0.0, maxScroll),
duration: const Duration(milliseconds: 300),
curve: Curves.easeInOut,
);
}
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
extendBodyBehindAppBar: true,
appBar: _buildAppBar(context),
body: ValueListenableBuilder<SongModel?>(
valueListenable: audioPlayerService.currentSongNotifier,
builder: (context, currentSong, _) {
return Stack(
children: [
// Background with artwork
if (currentSong != null)
Container(
decoration: BoxDecoration(
color: Colors.black,
image: _artworkCache[currentSong.id] != null
? DecorationImage(
image: MemoryImage(_artworkCache[currentSong.id]!),
fit: BoxFit.cover,
opacity: 0.7,
)
    : null,
),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
child: Container(
color: Colors.black.withOpacity(0.5),
),
),
),

// Main Content
Column(
children: [
// Song Info
if (currentSong != null) _buildSongInfo(currentSong),

// Lyrics Content
Expanded(
child: _buildLyricsContent(),
),

// Playback Controls
_buildPlaybackControls(),
],
),
],
);
},
),
);
}

Widget _buildSongInfo(SongModel currentSong) {
return Container(
width: double.infinity,
padding: EdgeInsets.only(
top: MediaQuery.of(context).padding.top + 60,
left: 24,
right: 24,
bottom: 16,
),
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.black.withOpacity(0.6),
Colors.transparent,
],
stops: const [0.0, 1.0],
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Text(
currentSong.title ?? 'Unknown',
style: const TextStyle(
color: Colors.white,
fontSize: 22,
fontWeight: FontWeight.bold,
letterSpacing: 0.3,
fontFamily: 'ProductSans',
),
textAlign: TextAlign.center,
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 8),
Text(
currentSong.artist ?? 'Unknown Artist',
style: TextStyle(
color: Colors.white.withOpacity(0.7),
fontSize: 16,
letterSpacing: 0.2,
fontFamily: 'ProductSans',
),
textAlign: TextAlign.center,
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
],
),
);
}

Widget _buildLyricsContent() {
  return StreamBuilder<Duration>(
    stream: audioPlayerService.audioPlayer.positionStream,
    builder: (context, snapshot) {
      // Show loading state while lyrics are being fetched
      if (_timedLyrics == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading lyrics...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontFamily: 'ProductSans',
                ),
              ),
            ],
          ),
        );
      }

      // Show "No lyrics available" only when we're sure there are no lyrics
      if (_timedLyrics!.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 48,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No lyrics available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontFamily: 'ProductSans',
                ),
              ),
            ],
          ),
        );
      }

      // Rest of the existing lyrics display code...
      final position = snapshot.data ?? Duration.zero;
      final newIndex = _getCurrentLyricIndex(position);

      if (newIndex != _currentLyricIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _currentLyricIndex = newIndex);
            _scrollToCurrentLyric();
          }
        });
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        itemCount: _timedLyrics?.length ?? 0,
        itemBuilder: (context, index) {
          final lyric = _timedLyrics![index];
          final isCurrent = index == _currentLyricIndex;

          return Container(
            key: isCurrent ? _activeLineKey : null,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: isCurrent ? 22 : 18,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                height: 1.5,
                fontFamily: 'ProductSans',
              ),
              child: Text(
                lyric.text,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      );
    },
  );
}

int _getCurrentLyricIndex(Duration position) {
if (_timedLyrics == null || _timedLyrics!.isEmpty) {
return _currentLyricIndex;
}

for (int i = 0; i < _timedLyrics!.length; i++) {
if (i == _timedLyrics!.length - 1) {
return i;
}

if (position < _timedLyrics![i + 1].time) {
return i;
}
}

return _currentLyricIndex;
}

Widget _buildPlaybackControls() {
return ClipRRect(
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
child: Container(
padding: EdgeInsets.only(
top: 20,
bottom: MediaQuery.of(context).padding.bottom + 20,
left: 20,
right: 20,
),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.1),
border: Border(
top: BorderSide(
color: Colors.white.withOpacity(0.2),
width: 1,
),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
_buildProgressBar(),
const SizedBox(height: 20),
Row(
mainAxisAlignment: MainAxisAlignment.spaceEvenly,
children: [
_buildControlButton(
icon: audioPlayerService.isShuffle ? Icons.shuffle : Icons.shuffle,
color: audioPlayerService.isShuffle ? Colors.blue : Colors.white,
onPressed: audioPlayerService.toggleShuffle,
),
_buildControlButton(
icon: Icons.skip_previous,
onPressed: audioPlayerService.back,
),
_buildPlayPauseButton(),
_buildControlButton(
icon: Icons.skip_next,
onPressed: audioPlayerService.skip,
),
_buildControlButton(
icon: audioPlayerService.isRepeat ? Icons.repeat_one : Icons.repeat,
color: audioPlayerService.isRepeat ? Colors.blue : Colors.white,
onPressed: audioPlayerService.toggleRepeat,
),
],
),
],
),
),
),
);
}

Widget _buildControlButton({
required IconData icon,
required VoidCallback onPressed,
Color color = Colors.white,
double size = 24,
}) {
return Container(
width: 44,
height: 44,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.white.withOpacity(0.1),
),
child: IconButton(
icon: Icon(icon, color: color, size: size),
onPressed: onPressed,
),
);
}

Widget _buildPlayPauseButton() {
return Container(
width: 64,
height: 64,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.blue.withOpacity(0.2),
border: Border.all(color: Colors.blue.withOpacity(0.3)),
),
child: IconButton(
icon: Icon(
audioPlayerService.isPlaying ? Icons.pause : Icons.play_arrow,
color: Colors.white,
size: 32,
),
onPressed: () {
if (audioPlayerService.isPlaying) {
audioPlayerService.pause();
} else {
audioPlayerService.resume();
}
},
),
);
}

Widget _buildProgressBar() {
return StreamBuilder<Duration>(
stream: audioPlayerService.audioPlayer.positionStream,
builder: (context, snapshot) {
final position = snapshot.data ?? Duration.zero;
final duration = audioPlayerService.audioPlayer.duration ?? Duration.zero;

return Column(
mainAxisSize: MainAxisSize.min,
children: [
SliderTheme(
data: SliderThemeData(
trackHeight: 2,
thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
activeTrackColor: Colors.white,
inactiveTrackColor: Colors.white.withOpacity(0.3),
thumbColor: Colors.white,
overlayColor: Colors.white.withOpacity(0.2),
),
child: Slider(
value: position.inMilliseconds.toDouble(),
max: duration.inMilliseconds.toDouble(),
onChanged: (value) {
audioPlayerService.audioPlayer.seek(
Duration(milliseconds: value.toInt()),
);
},
),
),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
_formatDuration(position),
style: TextStyle(
color: Colors.white.withOpacity(0.7),
fontSize: 12,
),
),
Text(
_formatDuration(duration),
style: TextStyle(
color: Colors.white.withOpacity(0.7),
fontSize: 12,
),
),
],
),
),
],
);
},
);
}

PreferredSizeWidget _buildAppBar(BuildContext context) {
return AppBar(
backgroundColor: Colors.transparent,
elevation: 0,
leading: Container(
margin: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.black26,
borderRadius: BorderRadius.circular(12),
),
child: IconButton(
icon: const Icon(
Icons.keyboard_arrow_down,
color: Colors.white,
size: 32,
),
onPressed: () => Navigator.pop(context),
),
),
);
}

String _formatDuration(Duration duration) {
String twoDigits(int n) => n.toString().padLeft(2, '0');
final minutes = twoDigits(duration.inMinutes.remainder(60));
final seconds = twoDigits(duration.inSeconds.remainder(60));
return '$minutes:$seconds';
}

@override
void dispose() {
_scrollController.dispose();
super.dispose();
}
}