import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../services/question_draft_store.dart';
import 'approval_areas.dart';
import 'ask_user_widgets.dart';

/// Approval area for AskUserQuestion.
/// Supports three modes:
/// - Single question, single select → full-width buttons + Other
/// - Single question, multi select → toggle buttons + Confirm + Other
/// - Multiple questions → PageView with one question per page + Other
class SessionCardAskUserArea extends StatefulWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final bool preferQuestionIds;
  final ValueChanged<String> onAnswer;
  final VoidCallback onTap;

  const SessionCardAskUserArea({
    super.key,
    required this.permission,
    required this.statusColor,
    required this.preferQuestionIds,
    required this.onAnswer,
    required this.onTap,
  });

  @override
  State<SessionCardAskUserArea> createState() => _AskUserAreaState();
}

class _AskUserAreaState extends State<SessionCardAskUserArea> {
  late final PageController _pageController;

  /// Shared with the chat screen's question widget for the same toolUseId.
  late QuestionDraft _draft;

  /// 0 to questions.length (where questions.length == summary page).
  int _currentPage = 0;

  /// questionIndex -> chosen label
  Map<int, String> get _singleAnswers => _draft.singleAnswers;

  /// questionIndex -> set of chosen labels
  Map<int, Set<String>> get _multiAnswers => _draft.multiAnswers;

  /// Keep track of which questions have their "Other" input shown
  Set<int> get _customInputs => _draft.customInputs;

  QuestionDraftStore get _store => QuestionDraftStore.instance;

  List<dynamic> get _questions =>
      widget.permission.input['questions'] as List<dynamic>? ?? [];

  String _answerKeyForQuestion(Map<String, dynamic> question, int index) {
    final questionId = question['id'] as String?;
    final questionText = question['question'] as String?;
    return widget.preferQuestionIds
        ? questionId ?? questionText ?? 'question_$index'
        : questionText ?? questionId ?? 'question_$index';
  }

  bool get _isMultiQuestion => _questions.length > 1;

  bool get _allowsCustomInput => !widget.permission.isQuestionApproval;

  @override
  void initState() {
    super.initState();
    _attachDraft(widget.permission.toolUseId);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant SessionCardAskUserArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.permission.toolUseId == widget.permission.toolUseId) {
      return;
    }
    _detachDraft(oldWidget.permission.toolUseId);
    _attachDraft(widget.permission.toolUseId);
    _syncPageControllerToDraft();
  }

  void _attachDraft(String toolUseId) {
    _draft = _store.acquire(toolUseId);
    _draft.addListener(_onDraftChanged);
    _currentPage = _draft.currentPage;
  }

  void _detachDraft(String toolUseId) {
    _draft.removeListener(_onDraftChanged);
    _store.release(toolUseId, _draft);
  }

  /// Another surface (e.g. the chat screen) changed the shared draft.
  void _onDraftChanged() {
    if (!mounted) return;
    setState(() {});
    if (_draft.currentPage != _currentPage) {
      _syncPageControllerToDraft();
    }
  }

  void _syncPageControllerToDraft() {
    _currentPage = _draft.currentPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final page = _draft.currentPage;
      if (_pageController.page?.round() != page) {
        _pageController.jumpToPage(page);
      }
    });
  }

  @override
  void dispose() {
    _detachDraft(widget.permission.toolUseId);
    _pageController.dispose();
    super.dispose();
  }

  void _sendAnswer(String result) {
    if (!_draft.markAnswered()) return;
    widget.onAnswer(result);
  }

  void _answerSingle(int questionIndex, String label) {
    _draft.update(() {
      _singleAnswers[questionIndex] = label;

      // Only clear custom input for single-select questions
      final q = _questions[questionIndex] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;
      if (!isMulti) {
        _draft.clearCustomText(questionIndex);
      }
    });
    if (!_isMultiQuestion) {
      // Single question → send immediately
      _sendAnswer(label);
    } else {
      _goToPage(questionIndex + 1);
    }
  }

  void _confirmMultiSelect(int questionIndex) {
    final selected = _multiAnswers[questionIndex];
    if (selected == null || selected.isEmpty) return;
    final answer = selected.join(', ');
    if (!_isMultiQuestion) {
      final question = _questions[questionIndex] as Map<String, dynamic>;
      final answerKey = _answerKeyForQuestion(question, questionIndex);
      _sendAnswer(
        jsonEncode({
          'questions': _questions,
          'answers': {answerKey: selected.toList(growable: false)},
        }),
      );
    } else {
      _draft.update(() {
        _singleAnswers[questionIndex] = answer;
      });
      _goToPage(_currentPage + 1);
    }
  }

  void _submitCustomText(int questionIndex) {
    // Determine the combined text for submission
    String finalAnswer = '';

    final q = _questions[questionIndex] as Map<String, dynamic>;
    final isMulti = q['multiSelect'] as bool? ?? false;

    final customText = _draft.customText(questionIndex);

    if (isMulti) {
      final selected = _multiAnswers[questionIndex] ?? {};
      final parts = [...selected];
      if (customText.isNotEmpty) parts.add(customText);
      finalAnswer = parts.join(', ');
    } else {
      finalAnswer = _singleAnswers[questionIndex]?.trim() ?? '';
    }

    if (finalAnswer.isEmpty) return;

    if (!_isMultiQuestion) {
      if (isMulti) {
        final answerKey = _answerKeyForQuestion(q, questionIndex);
        final answer = <String>[...(_multiAnswers[questionIndex] ?? {})];
        if (customText.isNotEmpty) answer.add(customText);
        _sendAnswer(
          jsonEncode({
            'questions': _questions,
            'answers': {answerKey: answer},
          }),
        );
      } else {
        _sendAnswer(finalAnswer);
      }
      return;
    }

    final next = questionIndex + 1;
    if (next <= _questions.length) {
      _goToPage(next);
    }
  }

  void _submitAll() {
    final answers = <String, dynamic>{};
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;
      final answerKey = _answerKeyForQuestion(q, i);

      if (isMulti) {
        final selected = _multiAnswers[i] ?? {};
        final answer = <String>[...selected];
        final customText = _draft.customText(i);
        if (customText.isNotEmpty) answer.add(customText);
        if (answer.isNotEmpty) answers[answerKey] = answer;
      } else {
        final answer = _singleAnswers[i]?.trim() ?? '';
        if (answer.isNotEmpty) answers[answerKey] = answer;
      }
    }
    _sendAnswer(jsonEncode({'questions': _questions, 'answers': answers}));
  }

  bool get _allRequiredAnswered {
    for (var i = 0; i < _questions.length; i++) {
      final question = _questions[i] as Map<String, dynamic>;
      if (!(question['required'] as bool? ?? true)) continue;
      if (question['multiSelect'] as bool? ?? false) {
        final selected = _multiAnswers[i] ?? {};
        final customText = _draft.customText(i);
        if (selected.isEmpty && customText.isEmpty) return false;
      } else if ((_singleAnswers[i]?.trim() ?? '').isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _resetAll() {
    _currentPage = 0;
    _draft.reset();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleMultiSelectLabel(int questionIndex, String label) {
    _draft.update(() {
      final selected = _multiAnswers.putIfAbsent(questionIndex, () => {});
      if (selected.contains(label)) {
        selected.remove(label);
      } else {
        selected.add(label);
      }

      final parts = [...selected];
      final customText = _draft.customText(questionIndex);
      if (customText.isNotEmpty) parts.add(customText);

      _singleAnswers[questionIndex] = parts.join(', ');
    });
  }

  void _onCustomTextChanged(int questionIndex, String text) {
    _draft.update(() {
      final q = _questions[questionIndex] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;

      if (isMulti) {
        final selected = _multiAnswers[questionIndex] ?? {};
        final parts = [...selected];
        if (text.trim().isNotEmpty) parts.add(text.trim());
        _singleAnswers[questionIndex] = parts.join(', ');
      } else {
        _singleAnswers[questionIndex] = text.trim();
        // Clear single-select chips when typing
        if (text.trim().isNotEmpty) {
          _multiAnswers[questionIndex]?.clear();
        }
      }
    });
  }

  void _showCustomInput(int questionIndex) {
    if (!_allowsCustomInput) return;
    _draft.update(() {
      _customInputs.add(questionIndex);
    });
  }

  TextEditingController _getOrCreateController(int questionIndex) {
    return _draft.controllerFor(questionIndex);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _draft.setPage(index);
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    if (questions.isEmpty) return const SizedBox.shrink();

    if (_draft.answered) {
      return const _AnsweredQuestionNotice();
    }

    final firstQ = questions[0] as Map<String, dynamic>;
    final options = firstQ['options'] as List<dynamic>? ?? [];

    return SessionApprovalSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMultiQuestion) ...[
            SessionCardQuestionPageView(
              questions: questions,
              currentPage: _currentPage,
              pageController: _pageController,
              statusColor: widget.statusColor,
              isMultiQuestion: _isMultiQuestion,
              allowsCustomInput: _allowsCustomInput,
              singleAnswers: _singleAnswers,
              multiAnswers: _multiAnswers,
              customInputs: _customInputs,
              getOrCreateController: _getOrCreateController,
              onAnswerSingle: _answerSingle,
              onToggleMultiSelectLabel: _toggleMultiSelectLabel,
              onConfirmMultiSelect: _confirmMultiSelect,
              onSubmitCustomText: _submitCustomText,
              onCustomTextChanged: _onCustomTextChanged,
              onShowCustomInput: _showCustomInput,
              onPageChanged: _onPageChanged,
              onGoToPage: _goToPage,
              onResetAll: _resetAll,
              onSubmitAll: _submitAll,
              canSubmitAll: _allRequiredAnswered,
            ),
          ] else if (options.isNotEmpty) ...[
            SessionCardQuestionLayout(
              question: firstQ,
              questionIndex: 0,
              statusColor: widget.statusColor,
              isMultiQuestion: _isMultiQuestion,
              allowsCustomInput: _allowsCustomInput,
              singleAnswers: _singleAnswers,
              multiAnswers: _multiAnswers,
              customInputs: _customInputs,
              getOrCreateController: _getOrCreateController,
              onAnswerSingle: _answerSingle,
              onToggleMultiSelectLabel: _toggleMultiSelectLabel,
              onConfirmMultiSelect: _confirmMultiSelect,
              onSubmitCustomText: _submitCustomText,
              onCustomTextChanged: _onCustomTextChanged,
              onShowCustomInput: _showCustomInput,
            ),
          ] else ...[
            SessionCardQuestionText(question: firstQ),
            const SizedBox(height: 6),
            SessionCardOpenButton(onTap: widget.onTap),
          ],
        ],
      ),
    );
  }
}

/// Shown once the shared question draft was answered on any surface.
class _AnsweredQuestionNotice extends StatelessWidget {
  const _AnsweredQuestionNotice();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SessionApprovalSection(
      key: const ValueKey('session_card_question_answered'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context).answered,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
