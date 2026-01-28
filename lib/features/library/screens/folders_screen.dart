import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/common_screen_scaffold.dart';
import 'folder_detail_screen.dart';

/// Screen displaying all music folders on the device.
class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final foldersFuture = OnAudioQuery().queryAllPath();

    return CommonScreenScaffold(
      title: 'Folders',
      showBackButton: false,
      slivers: [
        FutureBuilder<List<String>>(
          future: foldersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white))),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                    child: Text('No folders found',
                        style: TextStyle(color: Colors.white))),
              );
            }

            final folders = snapshot.data!;
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final folder = folders[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: glassmorphicContainer(
                            child: ListTile(
                              leading:
                                  const Icon(Icons.folder, color: Colors.white),
                              title: Text(
                                folder.split('/').last,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                folder,
                                style: const TextStyle(color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FolderDetailScreen(
                                      folderPath: folder,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: folders.length,
              ),
            );
          },
        ),
      ],
    );
  }
}
