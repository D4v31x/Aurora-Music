/// Undo service for reversible actions.
///
/// Provides undo/redo functionality for user actions like
/// removing songs from playlists, metadata edits, etc.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Types of actions that can be undone
enum UndoableActionType {
  removeFromPlaylist,
  addToPlaylist,
  deletePlaylist,
  renamePlaylist,
  removeFromQueue,
  clearQueue,
  metadataEdit,
  toggleLike,
}

/// Represents an action that can be undone
class UndoableAction {
  final String id;
  final UndoableActionType type;
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> data;
  final Future<void> Function() undoAction;
  final Future<void> Function()? redoAction;

  UndoableAction({
    required this.id,
    required this.type,
    required this.description,
    required this.data,
    required this.undoAction,
    this.redoAction,
  }) : timestamp = DateTime.now();
}

/// Service for managing undo/redo operations
class UndoService extends ChangeNotifier {
  static const int _maxUndoHistory = 20;
  static const Duration _undoWindowDuration = Duration(seconds: 10);

  final List<UndoableAction> _undoStack = [];
  final List<UndoableAction> _redoStack = [];
  Timer? _undoWindowTimer;
  UndoableAction? _lastAction;

  /// Whether there are actions that can be undone
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are actions that can be redone
  bool get canRedo => _redoStack.isNotEmpty;

  /// Get the most recent undoable action
  UndoableAction? get lastAction => _undoStack.isNotEmpty ? _undoStack.last : null;

  /// Whether the undo window is still active for the last action
  bool get isUndoWindowActive {
    if (_lastAction == null) return false;
    return DateTime.now().difference(_lastAction!.timestamp) < _undoWindowDuration;
  }

  /// Register an action that can be undone
  void registerAction(UndoableAction action) {
    _undoStack.add(action);
    _lastAction = action;

    // Clear redo stack when new action is registered
    _redoStack.clear();

    // Trim history if too long
    while (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeAt(0);
    }

    // Start/restart undo window timer
    _undoWindowTimer?.cancel();
    _undoWindowTimer = Timer(_undoWindowDuration, () {
      _lastAction = null;
      notifyListeners();
    });

    notifyListeners();
  }

  /// Undo the most recent action
  Future<bool> undo() async {
    if (_undoStack.isEmpty) return false;

    final action = _undoStack.removeLast();
    try {
      await action.undoAction();

      // Add to redo stack if redo is available
      if (action.redoAction != null) {
        _redoStack.add(action);
      }

      // Update last action
      _lastAction = _undoStack.isNotEmpty ? _undoStack.last : null;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Undo failed: $e');
      // Put the action back if undo failed
      _undoStack.add(action);
      return false;
    }
  }

  /// Redo the most recently undone action
  Future<bool> redo() async {
    if (_redoStack.isEmpty) return false;

    final action = _redoStack.removeLast();
    if (action.redoAction == null) return false;

    try {
      await action.redoAction!();
      _undoStack.add(action);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Redo failed: $e');
      // Put the action back if redo failed
      _redoStack.add(action);
      return false;
    }
  }

  /// Create an undo action for removing a song from a playlist
  static UndoableAction createRemoveFromPlaylistAction({
    required String playlistId,
    required SongModel song,
    required int index,
    required Future<void> Function() undoCallback,
    Future<void> Function()? redoCallback,
  }) {
    return UndoableAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_remove_playlist',
      type: UndoableActionType.removeFromPlaylist,
      description: 'Removed "${song.title}" from playlist',
      data: {
        'playlistId': playlistId,
        'songId': song.id,
        'songTitle': song.title,
        'index': index,
      },
      undoAction: undoCallback,
      redoAction: redoCallback,
    );
  }

  /// Create an undo action for removing a song from the queue
  static UndoableAction createRemoveFromQueueAction({
    required SongModel song,
    required int index,
    required Future<void> Function() undoCallback,
    Future<void> Function()? redoCallback,
  }) {
    return UndoableAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_remove_queue',
      type: UndoableActionType.removeFromQueue,
      description: 'Removed "${song.title}" from queue',
      data: {
        'songId': song.id,
        'songTitle': song.title,
        'index': index,
      },
      undoAction: undoCallback,
      redoAction: redoCallback,
    );
  }

  /// Create an undo action for toggling like status
  static UndoableAction createToggleLikeAction({
    required SongModel song,
    required bool wasLiked,
    required Future<void> Function() undoCallback,
  }) {
    return UndoableAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_toggle_like',
      type: UndoableActionType.toggleLike,
      description: wasLiked ? 'Unliked "${song.title}"' : 'Liked "${song.title}"',
      data: {
        'songId': song.id,
        'songTitle': song.title,
        'wasLiked': wasLiked,
      },
      undoAction: undoCallback,
      redoAction: undoCallback, // Toggle is symmetric
    );
  }

  /// Clear all undo history
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _lastAction = null;
    _undoWindowTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _undoWindowTimer?.cancel();
    super.dispose();
  }
}

/// Mixin to add undo capability to a widget
mixin UndoCapabilityMixin<T extends StatefulWidget> on State<T> {
  final UndoService _undoService = UndoService();

  UndoService get undoService => _undoService;

  /// Show an undo snackbar for the last action
  void showUndoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final success = await _undoService.undo();
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Action undone'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _undoService.dispose();
    super.dispose();
  }
}
