import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tts_service.dart';

class TtsSettingsScreen extends StatelessWidget {
  const TtsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학습 음성')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: const TtsVoiceSettingsPanel(),
            ),
          ),
        ),
      ),
    );
  }
}

class TtsVoiceSettingsPanel extends StatefulWidget {
  const TtsVoiceSettingsPanel({super.key});

  @override
  State<TtsVoiceSettingsPanel> createState() => _TtsVoiceSettingsPanelState();
}

class _TtsVoiceSettingsPanelState extends State<TtsVoiceSettingsPanel> {
  late Future<List<Map<String, String>>> _voicesFuture;
  Map<String, String>? _selectedVoice;

  @override
  void initState() {
    super.initState();
    final ttsService = context.read<TtsService>();
    _voicesFuture = ttsService.getEnglishVoices();
    _selectedVoice = ttsService.selectedVoice;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ttsService = context.read<TtsService>();

    return FutureBuilder<List<Map<String, String>>>(
      future: _voicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('음성 목록을 불러오지 못했습니다.\n${snapshot.error}');
        }

        final voices = snapshot.data ?? const <Map<String, String>>[];
        if (voices.isEmpty) {
          return const Text('기기에서 사용할 수 있는 영어 음성이 없습니다.');
        }

        final voicesByKey = <String, Map<String, String>>{
          for (final voice in voices) _voiceKey(voice): voice,
        };
        final selectedVoice = _selectedVoice ?? ttsService.selectedVoice;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '플래시카드의 단어 발음과 학습 중 듣기 재생에 사용할 영어 음성을 선택합니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _VoiceSelector(
              label: '학습 음성',
              value: _availableKey(selectedVoice, voicesByKey),
              voicesByKey: voicesByKey,
              onPreview:
                  (voice) => ttsService.speakWithVoice(
                    voice,
                    'Hello, this is your learning voice.',
                  ),
              onChanged: (voice) async {
                await ttsService.setVoice(voice);
                if (mounted) setState(() => _selectedVoice = voice);
              },
            ),
          ],
        );
      },
    );
  }

  String? _availableKey(
    Map<String, String>? voice,
    Map<String, Map<String, String>> voicesByKey,
  ) {
    if (voice == null) return null;
    final key = _voiceKey(voice);
    return voicesByKey.containsKey(key) ? key : null;
  }

  String _voiceKey(Map<String, String> voice) {
    return '${voice['name'] ?? ''}::${voice['locale'] ?? ''}';
  }
}

class _VoiceSelector extends StatelessWidget {
  final String label;
  final String? value;
  final Map<String, Map<String, String>> voicesByKey;
  final Future<void> Function(Map<String, String> voice) onPreview;
  final Future<void> Function(Map<String, String> voice) onChanged;

  const _VoiceSelector({
    required this.label,
    required this.value,
    required this.voicesByKey,
    required this.onPreview,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedVoice = value == null ? null : voicesByKey[value];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                hint: const Text('음성 선택'),
                items: [
                  for (final entry in voicesByKey.entries)
                    DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value['name'] ?? '이름 없는 음성',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (key) {
                  final voice = key == null ? null : voicesByKey[key];
                  if (voice != null) onChanged(voice);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '미리 듣기',
              onPressed:
                  selectedVoice == null ? null : () => onPreview(selectedVoice),
              icon: const Icon(CupertinoIcons.play_fill),
            ),
          ],
        ),
      ],
    );
  }
}
