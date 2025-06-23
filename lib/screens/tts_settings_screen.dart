import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';

class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  State<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends State<TtsSettingsScreen> {
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
    final ttsService = context.read<TtsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('TTS 목소리 설정')),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _voicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('음성 목록을 불러오는 중 오류 발생:\n${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('사용 가능한 영어 음성이 없습니다.'));
          }

          final voices = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: voices.length,
            itemBuilder: (context, index) {
              final voice = voices[index];
              final isFemale = _selectedFemaleVoice?['name'] == voice['name'];
              final isMale = _selectedMaleVoice?['name'] == voice['name'];
              final voiceName = voice['name'] ?? 'Unknown Voice';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.play_circle),
                        onPressed:
                            () =>
                                ttsService.speakWithVoice(voice, 'Hello, this is a sample voice.'),
                        tooltip: '목소리 들어보기',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          voiceName,
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FilterChip(
                        label: const Text('여성'),
                        selectedColor: Colors.pink.shade100,
                        selected: isFemale,
                        onSelected: (selected) {
                          ttsService.setFemaleVoice(voice);
                          setState(() => _selectedFemaleVoice = voice);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('남성'),
                        selectedColor: Colors.blue.shade100,
                        selected: isMale,
                        onSelected: (selected) {
                          ttsService.setMaleVoice(voice);
                          setState(() => _selectedMaleVoice = voice);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
