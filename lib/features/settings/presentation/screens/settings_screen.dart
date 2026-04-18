import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _eBirdController = TextEditingController();
  final _birdNetController = TextEditingController();
  bool _eBirdObscured = true;

  @override
  void dispose() {
    _eBirdController.dispose();
    _birdNetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    settingsAsync.whenData((settings) {
      if (_eBirdController.text.isEmpty && settings.eBirdApiKey.isNotEmpty) {
        _eBirdController.text = settings.eBirdApiKey;
      }
      if (_birdNetController.text.isEmpty &&
          settings.birdNetBaseUrl.isNotEmpty) {
        _birdNetController.text = settings.birdNetBaseUrl;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: 'API Keys'),
            _ApiKeyField(
              label: 'eBird API Key',
              hint: 'Get free key at ebird.org/api/keygen',
              controller: _eBirdController,
              obscured: _eBirdObscured,
              onToggleObscure: () =>
                  setState(() => _eBirdObscured = !_eBirdObscured),
              onSave: (v) => notifier.setEBirdApiKey(v),
              hasValue: settings.hasEBirdKey,
              helpUrl: 'https://ebird.org/api/keygen',
            ),
            const SizedBox(height: 12),
            _ApiKeyField(
              label: 'BirdNET Endpoint URL',
              hint: 'https://your-birdnet-instance.com/api/v1',
              controller: _birdNetController,
              obscured: false,
              onSave: (v) => notifier.setBirdNetUrl(v),
              hasValue: settings.hasBirdNetUrl,
              helpUrl:
                  'https://github.com/kahst/BirdNET-Analyzer',
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Recording'),
            _DurationSelector(
              current: settings.recordingDurationSeconds,
              onChanged: (v) => notifier.setRecordingDuration(v),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Identification'),
            _ConfidenceSlider(
              value: settings.minConfidence,
              onChanged: (v) => notifier.setMinConfidence(v),
            ),
            const SizedBox(height: 32),
            _InfoCard(),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  const _ApiKeyField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscured,
    required this.onSave,
    required this.hasValue,
    required this.helpUrl,
    this.onToggleObscure,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscured;
  final void Function(String) onSave;
  final bool hasValue;
  final String helpUrl;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            if (hasValue)
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.confidenceHigh),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscured,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleObscure != null)
                  IconButton(
                    icon: Icon(
                        obscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: onToggleObscure,
                  ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => launchUrl(Uri.parse(helpUrl)),
                ),
              ],
            ),
          ),
          onFieldSubmitted: onSave,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => onSave(controller.text),
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({required this.current, required this.onChanged});

  final int current;
  final void Function(int) onChanged;

  static const _options = [5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Max recording duration',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _options
              .map(
                (s) => ChoiceChip(
                  label: Text('${s}s'),
                  selected: current == s,
                  onSelected: (_) => onChanged(s),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ConfidenceSlider extends StatelessWidget {
  const _ConfidenceSlider({required this.value, required this.onChanged});

  final double value;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Minimum confidence',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.05,
          max: 0.9,
          divisions: 17,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('More results', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            Text('Higher accuracy', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text('About BirdNET',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bird Sound Identifier uses BirdNET AI by Cornell Lab of Ornithology. '
              'You can self-host BirdNET-Analyzer for unlimited use, or enter a '
              'community endpoint URL above.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('BirdNET-Analyzer on GitHub',
                  style: TextStyle(fontSize: 13)),
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/kahst/BirdNET-Analyzer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
