/// Replacement visualizer screen — hosts a [VisualizerController] +
/// [VisualizerPainter] rendering one of the built-in [VisualizerTemplate]s.
/// Entirely replaces the old single-mode bar/circular/mirror/line
/// visualizer (see spec section 21: one canonical visualizer engine).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../engine_runtime/visualizer_controller.dart';
import '../engine_runtime/visualizer_engine.dart';
import '../model/visualizer_template.dart';
import '../render/visualizer_painter.dart';
import '../templates/builtin_templates.dart';

class VisualizerScreen extends StatefulWidget {
  const VisualizerScreen({super.key});

  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen>
    with SingleTickerProviderStateMixin {
  static const String _kPrefKey = 'visualizer_template_id';

  late final VisualizerController _controller;
  late final List<VisualizerTemplate> _templates;
  int _templateIndex = 0;
  bool _micGranted = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    _templates = BuiltinTemplates.all;
    final audioService = context.read<AudioPlayerService>();
    _controller = VisualizerController(
      audioService: audioService,
      vsync: this,
      initialTemplate: _templates.first,
    );
    unawaited(_loadTemplateChoice());
    unawaited(_checkAndRequestPermission());
  }

  Future<void> _loadTemplateChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kPrefKey);
    if (savedId == null) return;
    final index = _templates.indexWhere((t) => t.id == savedId);
    if (index != -1 && mounted) {
      setState(() => _templateIndex = index);
      _controller.setTemplate(_templates[index]);
    }
  }

  Future<void> _saveTemplateChoice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, id);
  }

  Future<void> _checkAndRequestPermission() async {
    if (_isRequestingPermission) return;
    _isRequestingPermission = true;
    try {
      final status = await Permission.microphone.request();
      if (!mounted) return;
      final granted = status.isGranted;
      setState(() => _micGranted = granted);
      if (granted) _controller.start();
    } finally {
      _isRequestingPermission = false;
    }
  }

  void _switchTemplate(int delta) {
    final next = (_templateIndex + delta) % _templates.length;
    final index = next < 0 ? next + _templates.length : next;
    setState(() => _templateIndex = index);
    _controller.setTemplate(_templates[index]);
    unawaited(_saveTemplateChoice(_templates[index].id));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final template = _templates[_templateIndex];

    return Scaffold(
      backgroundColor: template.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_micGranted)
            _buildPermissionPrompt(context)
          else
            ValueListenableBuilder<VisualizerRenderState>(
              valueListenable: _controller.renderStateNotifier,
              builder: (context, renderState, _) => RepaintBoundary(
                child: CustomPaint(
                  painter: VisualizerPainter(
                    state: renderState,
                    imageResolver: _controller.imageResolver,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

          // ── Top chrome: close + template switcher ───────────────────────
          Positioned(
            top: topPad,
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const iconoir.NavArrowDown(
                      color: Colors.white, width: 28, height: 28),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: AppLocalizations.of(context).closeVisualiser,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const iconoir.NavArrowLeft(
                            color: Colors.white, width: 22, height: 22),
                        onPressed: () => _switchTemplate(-1),
                        tooltip: AppLocalizations.of(context).previousMode,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        template.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: FontConstants.fontFamily,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const iconoir.NavArrowRight(
                            color: Colors.white, width: 22, height: 22),
                        onPressed: () => _switchTemplate(1),
                        tooltip: AppLocalizations.of(context).nextMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).microphoneAccessNeeded,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: FontConstants.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).microphoneAccessDesc,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: FontConstants.fontFamily,
                color: Color(0xA6FFFFFF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed:
                  _isRequestingPermission ? null : _checkAndRequestPermission,
              child: Text(AppLocalizations.of(context).grantPermission),
            ),
          ],
        ),
      ),
    );
  }
}
