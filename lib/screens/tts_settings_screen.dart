import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tts_service.dart';

class TtsSettingsScreen extends StatelessWidget {
  const TtsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('발음 및 듣기 음성')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: TtsVoiceSettingsPanel(),
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
  Map<String, String>? _selectedMaleVoice;
  Map<String, String>? _selectedFemaleVoice;

  @override
  void initState() {
    super.initState();
    final ttsService = context.read<TtsService>();
    _voicesFuture = ttsService.getEnglishVoices();
    _selectedMaleVoice = ttsService.selectedMaleVoice;
    _selectedFemaleVoice = ttsService.selectedFemaleVoice;
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
        final femaleVoice = _selectedFemaleVoice ?? ttsService.selectedFemaleVoice;
        final maleVoice = _selectedMaleVoice ?? ttsService.selectedMaleVoice;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기본 음성은 단어 발음과 AI 대화의 여성 화자에 사용됩니다. '
              '남성 음성은 AI 대화 듣기에서 화자를 구분할 때 사용됩니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _VoiceSelector(
              label: '기본 발음 · 여성 화자',
              value: _availableKey(femaleVoice, voicesByKey),
              voicesByKey: voicesByKey,
              onPreview: (voice) => ttsService.speakWithVoice(
                voice,
                'Hello, this is the default pronunciation voice.',
              ),
              onChanged: (voice) async {
                await ttsService.setFemaleVoice(voice);
                if (mounted) setState(() => _selectedFemaleVoice = voice);
              },
            ),
            const SizedBox(height: 14),
            _VoiceSelector(
              label: 'AI 대화 · 남성 화자',
              value: _availableKey(maleVoice, voicesByKey),
              voicesByKey: voicesByKey,
              onPreview: (voice) => ttsService.speakWithVoice(
                voice,
                'Hello, this is the second dialogue voice.',
              ),
              onChanged: (voice) async {
                await ttsService.setMaleVoice(voice);
                if (mounted) setState(() => _selectedMaleVoice = voice);
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              onPressed: selectedVoice == null ? null : () => onPreview(selectedVoice),
              icon: const Icon(CupertinoIcons.play_fill),
            ),
          ],
        ),
      ],
    );
  }
}
