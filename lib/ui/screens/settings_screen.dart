import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/m_theme.dart';

/// Full preferences dashboard. Every control writes through
/// [LibraryService.setSetting] so values survive a restart.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Map<String, String> _repeatOptions = <String, String>{
    'off': 'Off',
    'all': 'Repeat all',
    'one': 'Repeat one',
  };
  static const Map<String, String> _behaviourOptions = <String, String>{
    'queue': 'Play the whole queue',
    'single': 'Play a single track',
    'resume': 'Resume last session',
  };
  static const Map<String, String> _languageOptions = <String, String>{
    'en': 'English',
    'ar': 'العربية',
  };
  static const Map<String, String> _sidebarOptions = <String, String>{
    'expanded': 'Expanded',
    'compact': 'Compact icons',
    'auto': 'Auto-hide on wide screens',
  };
  static const Map<String, Object> _defaults = <String, Object>{
    'darkTheme': true,
    'redGlass': true,
    'backgroundIntensity': 1.0,
    'glowIntensity': 1.0,
    'animationIntensity': 1.0,
    'compactMode': false,
    'volume': 0.8,
    'autoplay': true,
    'repeat': 'off',
    'shuffle': false,
    'defaultBehaviour': 'queue',
    'language': 'en',
    'rtl': false,
    'uiScale': 1.0,
    'sidebarBehaviour': 'expanded',
  };

  final TextEditingController _apiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiCtrl.text = context.read<LibraryService>().youtubeApiKey;
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    super.dispose();
  }

  Future<void> _write<T>(String key, T value) async {
    await context.read<LibraryService>().setSetting<T>(key, value);
    if (mounted) setState(() {});
  }

  Future<void> _applyRepeat(String mode) async {
    final player = context.read<MezoxPlayerController>();
    final wantOne = mode == 'one';
    final wantAll = mode == 'all';
    if (player.repeatOne != wantOne) player.toggleRepeatOne();
    if (player.repeatAll != wantAll) player.toggleRepeatAll();
  }

  Future<void> _saveApiKey() async {
    final key = _apiCtrl.text.trim();
    await context.read<LibraryService>().setYoutubeApiKey(key);
    if (!mounted) return;
    context.read<YouTubeService>().setApiKey(key);
    MToast.show(context, key.isEmpty ? 'YouTube API key cleared' : 'YouTube API key saved');
    setState(() {});
  }

  Future<void> _exportData() async {
    final json = context.read<LibraryService>().exportData();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: MColors.primary.withOpacity(0.4)),
        ),
        title: const SectionLabel('Export library data'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy this JSON to back up or move your playlists, likes and history.',
                style: TextStyle(color: MColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                height: 260,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MColors.glassBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    style: const TextStyle(
                      color: MColors.bright,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: MColors.muted)),
          ),
          GlowButton(
            label: 'Copy JSON',
            icon: Icons.copy,
            compact: true,
            filled: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (mounted) MToast.show(context, 'Export JSON copied');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importData() async {
    final ctrl = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: MColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: MColors.primary.withOpacity(0.4)),
          ),
          title: const SectionLabel('Import library data'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste M MUSIC export JSON. This replaces your current library data.',
                  style: TextStyle(color: MColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  maxLines: 10,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  decoration: const InputDecoration(hintText: '{"version":1,...}'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: MColors.bright, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: MColors.muted)),
            ),
            GlowButton(
              label: 'Import',
              icon: Icons.file_upload_outlined,
              compact: true,
              filled: true,
              onPressed: () async {
                try {
                  await context.read<LibraryService>().importData(ctrl.text.trim());
                  if (!mounted) return;
                  Navigator.pop(context);
                  MToast.show(context, 'Library data imported');
                } catch (e) {
                  setDialogState(() => error = 'Invalid data: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _resetPreferences() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: MColors.primary.withOpacity(0.4)),
        ),
        title: const SectionLabel('Reset preferences'),
        content: const Text(
          'All appearance, playback and interface settings return to their defaults. Your playlists, likes and API key are kept.',
          style: TextStyle(color: MColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: MColors.muted)),
          ),
          GlowButton(
            label: 'Reset',
            icon: Icons.restart_alt,
            compact: true,
            filled: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final lib = context.read<LibraryService>();
    for (final entry in _defaults.entries) {
      await lib.setSetting(entry.key, entry.value);
    }
    if (!mounted) return;
    await context.read<MezoxPlayerController>().setVolume(0.8);
    if (!mounted) return;
    MToast.show(context, 'Preferences reset to defaults');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();

    double number(String key, double fallback, double min, double max) {
      final raw = lib.getSetting<double>(key, fallback);
      if (raw.isNaN) return fallback;
      return raw.clamp(min, max).toDouble();
    }

    String choice(String key, String fallback) =>
        lib.getSetting<String>(key, fallback);

    bool flag(String key, bool fallback) =>
        lib.getSetting<bool>(key, fallback);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: const [
              MLogo(size: 44),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Settings'),
                    SizedBox(height: 6),
                    Text(
                      'Make M MUSIC yours — every change is saved instantly.',
                      style: TextStyle(color: MColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const SectionLabel('Appearance'),
        const SizedBox(height: 10),
        _SwitchRow(
          icon: Icons.dark_mode_outlined,
          title: 'Dark theme',
          subtitle: 'Signature M MUSIC black and red mode.',
          value: flag('darkTheme', true),
          onChanged: (v) async {
            await _write<bool>('darkTheme', v);
            if (context.mounted) MToast.show(context, 'Dark theme preference saved');
          },
        ),
        _SwitchRow(
          icon: Icons.auto_awesome,
          title: 'Red glass',
          subtitle: 'Frosted red glass panels across the interface.',
          value: flag('redGlass', true),
          onChanged: (v) async {
            await _write<bool>('redGlass', v);
            if (context.mounted) MToast.show(context, 'Red glass preference saved');
          },
        ),
        _SliderRow(
          icon: Icons.wallpaper_outlined,
          title: 'Background effects',
          subtitle: 'Intensity of the animated red backdrop.',
          value: number('backgroundIntensity', 1.0, 0.0, 1.0),
          min: 0.0,
          max: 1.0,
          display: '${(number('backgroundIntensity', 1.0, 0.0, 1.0) * 100).round()}%',
          onChanged: (v) => _write<double>('backgroundIntensity', v),
          onEnd: (v) => MToast.show(context, 'Background intensity saved'),
        ),
        _SliderRow(
          icon: Icons.brightness_5_outlined,
          title: 'Glow intensity',
          subtitle: 'How hard the neon accents burn.',
          value: number('glowIntensity', 1.0, 0.0, 1.0),
          min: 0.0,
          max: 1.0,
          display: '${(number('glowIntensity', 1.0, 0.0, 1.0) * 100).round()}%',
          onChanged: (v) => _write<double>('glowIntensity', v),
          onEnd: (v) => MToast.show(context, 'Glow intensity saved'),
        ),
        _SliderRow(
          icon: Icons.animation_outlined,
          title: 'Animation intensity',
          subtitle: 'Motion and transition energy.',
          value: number('animationIntensity', 1.0, 0.0, 1.0),
          min: 0.0,
          max: 1.0,
          display: '${(number('animationIntensity', 1.0, 0.0, 1.0) * 100).round()}%',
          onChanged: (v) => _write<double>('animationIntensity', v),
          onEnd: (v) => MToast.show(context, 'Animation intensity saved'),
        ),
        _SwitchRow(
          icon: Icons.compress,
          title: 'Compact mode',
          subtitle: 'Tighter spacing and denser lists.',
          value: flag('compactMode', false),
          onChanged: (v) async {
            await _write<bool>('compactMode', v);
            if (context.mounted) MToast.show(context, 'Compact mode saved');
          },
        ),

        const SizedBox(height: 10),
        const SectionLabel('Playback'),
        const SizedBox(height: 10),
        _SliderRow(
          icon: Icons.volume_up_outlined,
          title: 'Default volume',
          subtitle: 'Level used when a track starts playing.',
          value: number('volume', 0.8, 0.0, 1.0),
          min: 0.0,
          max: 1.0,
          display: '${(number('volume', 0.8, 0.0, 1.0) * 100).round()}%',
          onChanged: (v) async {
            await _write<double>('volume', v);
            if (!context.mounted) return;
            await context.read<MezoxPlayerController>().setVolume(v);
          },
          onEnd: (v) => MToast.show(context, 'Default volume saved'),
        ),
        _SwitchRow(
          icon: Icons.play_circle_outline,
          title: 'Autoplay',
          subtitle: 'Start the next track when the current one ends.',
          value: flag('autoplay', true),
          onChanged: (v) async {
            await _write<bool>('autoplay', v);
            if (context.mounted) MToast.show(context, 'Autoplay saved');
          },
        ),
        _ChoiceRow(
          icon: Icons.repeat,
          title: 'Repeat',
          subtitle: 'Default repeat behaviour for new queues.',
          value: choice('repeat', 'off'),
          options: _repeatOptions,
          onChanged: (v) async {
            await _write<String>('repeat', v);
            await _applyRepeat(v);
            if (context.mounted) MToast.show(context, 'Repeat set to ${_repeatOptions[v] ?? v}');
          },
        ),
        _SwitchRow(
          icon: Icons.shuffle,
          title: 'Shuffle',
          subtitle: 'Start new queues in a random order.',
          value: flag('shuffle', false),
          onChanged: (v) async {
            await _write<bool>('shuffle', v);
            if (!context.mounted) return;
            final player = context.read<MezoxPlayerController>();
            if (player.shuffle != v) player.toggleShuffle();
            if (context.mounted) MToast.show(context, 'Shuffle saved');
          },
        ),
        _ChoiceRow(
          icon: Icons.queue_music_outlined,
          title: 'Default behaviour',
          subtitle: 'What happens when you open a collection.',
          value: choice('defaultBehaviour', 'queue'),
          options: _behaviourOptions,
          onChanged: (v) async {
            await _write<String>('defaultBehaviour', v);
            if (context.mounted) {
              MToast.show(context, 'Default behaviour: ${_behaviourOptions[v] ?? v}');
            }
          },
        ),

        const SizedBox(height: 10),
        const SectionLabel('Interface'),
        const SizedBox(height: 10),
        _ChoiceRow(
          icon: Icons.language,
          title: 'Language',
          subtitle: 'Display language for M MUSIC copy.',
          value: choice('language', 'en'),
          options: _languageOptions,
          onChanged: (v) async {
            await _write<String>('language', v);
            await _write<bool>('rtl', v == 'ar');
            if (context.mounted) MToast.show(context, 'Language set to ${_languageOptions[v] ?? v}');
          },
        ),
        _SwitchRow(
          icon: Icons.format_textdirection_r_to_l,
          title: 'RTL layout',
          subtitle: 'Mirror the interface for right-to-left reading.',
          value: flag('rtl', false),
          onChanged: (v) async {
            await _write<bool>('rtl', v);
            if (context.mounted) MToast.show(context, 'RTL layout saved');
          },
        ),
        _SliderRow(
          icon: Icons.zoom_in_outlined,
          title: 'UI scaling',
          subtitle: 'Overall size of interface elements.',
          value: number('uiScale', 1.0, 0.8, 1.4),
          min: 0.8,
          max: 1.4,
          display: '${(number('uiScale', 1.0, 0.8, 1.4) * 100).round()}%',
          onChanged: (v) => _write<double>('uiScale', v),
          onEnd: (v) => MToast.show(context, 'UI scaling saved'),
        ),
        _ChoiceRow(
          icon: Icons.view_sidebar_outlined,
          title: 'Sidebar behaviour',
          subtitle: 'How the navigation sidebar behaves.',
          value: choice('sidebarBehaviour', 'expanded'),
          options: _sidebarOptions,
          onChanged: (v) async {
            await _write<String>('sidebarBehaviour', v);
            if (context.mounted) {
              MToast.show(context, 'Sidebar: ${_sidebarOptions[v] ?? v}');
            }
          },
        ),

        const SizedBox(height: 10),
        const SectionLabel('Data'),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Icons.search_off_outlined,
          title: 'Clear search history',
          subtitle: 'Remove every saved search term.',
          label: 'Clear',
          onPressed: () async {
            await lib.clearSearchHistory();
            if (context.mounted) MToast.show(context, 'Search history cleared');
          },
        ),
        _ActionRow(
          icon: Icons.history_toggle_off,
          title: 'Clear recently played',
          subtitle: 'Empty your listening history.',
          label: 'Clear',
          onPressed: () async {
            await lib.clearRecentlyPlayed();
            if (context.mounted) MToast.show(context, 'Recently played cleared');
          },
        ),
        _ActionRow(
          icon: Icons.file_upload_outlined,
          title: 'Export playlist data',
          subtitle: 'Copy your library as shareable JSON text.',
          label: 'Export',
          onPressed: _exportData,
        ),
        _ActionRow(
          icon: Icons.file_download_outlined,
          title: 'Import data',
          subtitle: 'Restore a library from exported JSON.',
          label: 'Import',
          onPressed: _importData,
        ),
        _ActionRow(
          icon: Icons.restart_alt,
          title: 'Reset preferences',
          subtitle: 'Return every setting to its default value.',
          label: 'Reset',
          onPressed: _resetPreferences,
        ),

        const SizedBox(height: 10),
        const SectionLabel('YouTube API key'),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a YouTube Data API v3 key for faster, richer search results. Search still works without one.',
                style: TextStyle(color: MColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiCtrl,
                obscureText: false,
                decoration: const InputDecoration(
                  hintText: 'AIza...',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GlowButton(
                  label: 'Save key',
                  icon: Icons.save_outlined,
                  filled: true,
                  compact: true,
                  onPressed: _saveApiKey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        const SectionLabel('About'),
        const SizedBox(height: 10),
        GlassPanel(
          child: Row(
            children: const [
              MLogo(size: 40),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'M MUSIC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Version 1.0.0 — Listen. Enjoy. Repeat.',
                      style: TextStyle(color: MColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: MColors.bright, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    required this.onEnd,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MColors.bright, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: MColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: MColors.bright,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onEnd,
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.containsKey(value) ? value : options.keys.first;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: MColors.bright, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: selected,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in options.entries)
                  DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: MColors.bright, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          GlowButton(
            label: label,
            icon: Icons.arrow_forward_rounded,
            compact: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
