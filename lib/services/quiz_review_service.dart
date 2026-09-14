import '../models/study_session_model.dart';
import '../models/word_model.dart';
import 'study_schedule_service.dart';

class QuizMistakeEvent {
  final StudyHistoryMode mode;
  final StudyAnswerRecord answer;
  const QuizMistakeEvent(this.mode, this.answer);

  String get label => answer.skipped ? '스킵 / 정답 확인' :
      answer.success ? '재도전 정답' : '오답';
}

class QuizReviewEntry {
  final Word word;
  final List<QuizMistakeEvent> events;
  final Set<StudyHistoryMode> pendingModes;
  final Set<StudyHistoryMode> historyModes;
  const QuizReviewEntry(this.word, this.events, this.pendingModes, this.historyModes);
}

class QuizReviewService {
  const QuizReviewService();

  List<QuizReviewEntry> entries({required String dbFileName, required List<Word> words,
      required List<StudySessionRecord> sessions, bool cumulative = false}) {
    final events = <String, List<QuizMistakeEvent>>{};
    final priorModes = <String, Set<StudyHistoryMode>>{};
    final latest = <String, Map<StudyHistoryMode, StudyAnswerRecord>>{};
    for (final session in sessions) {
      if (session.dbFileName != dbFileName || session.mode == StudyHistoryMode.flashcard) continue;
      for (final answer in session.answers) {
        if (answer.hadPriorQuizMistake) {
          priorModes.putIfAbsent(answer.wordKey, () => {}).add(session.mode);
        }
        final modes = latest.putIfAbsent(answer.wordKey, () => {});
        final previous = modes[session.mode];
        if (previous == null || !answer.at.isBefore(previous.at)) modes[session.mode] = answer;
        if (answer.needsQuizReview) {
          events.putIfAbsent(answer.wordKey, () => []).add(QuizMistakeEvent(session.mode, answer));
        }
      }
    }
    final result = <QuizReviewEntry>[];
    for (final word in words) {
      final key = StudyScheduleService.wordKey(word);
      final mistakes = events[key] ?? <QuizMistakeEvent>[];
      mistakes.sort((a, b) => b.answer.at.compareTo(a.answer.at));
      final pending = <StudyHistoryMode>{};
      for (final mode in [StudyHistoryMode.multipleChoice, StudyHistoryMode.spelling]) {
        final last = latest[key]?[mode];
        final legacyPending = mode == StudyHistoryMode.multipleChoice
            ? word.pendingMcqReview > 0 : word.pendingSpellingReview > 0;
        if (last?.needsQuizReview ?? legacyPending) pending.add(mode);
      }
      final historyModes = {...mistakes.map((e) => e.mode), ...pending, ...?priorModes[key]};
      if ((cumulative ? historyModes : pending).isNotEmpty) {
        result.add(QuizReviewEntry(word, mistakes, pending, historyModes));
      }
    }
    result.sort((a, b) {
      if (a.events.isEmpty && b.events.isEmpty) return a.word.word.compareTo(b.word.word);
      if (a.events.isEmpty) return 1;
      if (b.events.isEmpty) return -1;
      return b.events.first.answer.at.compareTo(a.events.first.answer.at);
    });
    return result;
  }
}
