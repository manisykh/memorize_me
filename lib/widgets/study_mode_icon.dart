import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/study_session_model.dart';

IconData studyModeIcon(StudyHistoryMode mode) => switch (mode) {
  StudyHistoryMode.flashcard => CupertinoIcons.layers_alt_fill,
  StudyHistoryMode.multipleChoice => CupertinoIcons.square_list_fill,
  StudyHistoryMode.spelling => CupertinoIcons.pencil_outline,
};

Color studyModeColor(StudyHistoryMode mode, Brightness brightness) => switch (mode) {
  StudyHistoryMode.flashcard => brightness == Brightness.dark
      ? const Color(0xFF76CFAB) : const Color(0xFF267A61),
  StudyHistoryMode.multipleChoice => brightness == Brightness.dark
      ? const Color(0xFF85BCF5) : const Color(0xFF346EB2),
  StudyHistoryMode.spelling => brightness == Brightness.dark
      ? const Color(0xFFF394B2) : const Color(0xFFB74471),
};
