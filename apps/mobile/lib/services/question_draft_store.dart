import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// In-progress answers for one pending question request (keyed by toolUseId).
///
/// The same request can be visible in several places at once (e.g. the running
/// session card and the chat screen on tablet / desktop layouts). Both surfaces
/// read and write this shared draft so selections, custom text, the current
/// page and the answered flag stay in sync.
class QuestionDraft extends ChangeNotifier {
  /// questionIndex -> chosen label (or combined text for multi select).
  final Map<int, String> singleAnswers = {};

  /// questionIndex -> chosen labels for multi select questions.
  final Map<int, Set<String>> multiAnswers = {};

  /// Questions whose "Other" input is expanded.
  final Set<int> customInputs = {};

  final Map<int, TextEditingController> _controllers = {};

  int _currentPage = 0;
  bool _answered = false;
  int _refCount = 0;

  int get currentPage => _currentPage;

  bool get answered => _answered;

  /// Shared controller for the custom ("Other") text of [questionIndex].
  TextEditingController controllerFor(int questionIndex) =>
      _controllers.putIfAbsent(questionIndex, TextEditingController.new);

  /// Trimmed custom text for [questionIndex], or empty when none.
  String customText(int questionIndex) =>
      _controllers[questionIndex]?.text.trim() ?? '';

  void clearCustomText(int questionIndex) =>
      _controllers[questionIndex]?.clear();

  /// Applies [mutation] and notifies every surface showing this draft.
  void update(VoidCallback mutation) {
    mutation();
    notifyListeners();
  }

  void setPage(int page) {
    if (_currentPage == page) return;
    _currentPage = page;
    notifyListeners();
  }

  /// Marks the draft as answered. Returns false when it was already answered,
  /// so callers can avoid sending the same answer twice.
  bool markAnswered() {
    if (_answered) return false;
    _answered = true;
    notifyListeners();
    return true;
  }

  void reset() {
    singleAnswers.clear();
    multiAnswers.clear();
    customInputs.clear();
    for (final controller in _controllers.values) {
      controller.clear();
    }
    _currentPage = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}

/// Registry of [QuestionDraft]s shared by every widget showing a question.
///
/// Drafts are reference counted: a draft lives while at least one widget holds
/// it and is discarded when the last one releases it.
class QuestionDraftStore {
  QuestionDraftStore();

  static final QuestionDraftStore instance = QuestionDraftStore();

  final Map<String, QuestionDraft> _drafts = {};

  QuestionDraft acquire(String toolUseId) {
    final draft = _drafts.putIfAbsent(toolUseId, QuestionDraft.new);
    draft._refCount++;
    return draft;
  }

  void release(String toolUseId, QuestionDraft draft) {
    draft._refCount--;
    if (draft._refCount > 0) return;
    if (identical(_drafts[toolUseId], draft)) {
      _drafts.remove(toolUseId);
    }
    // TextFields that still reference the shared controllers are torn down
    // later in the same frame, so dispose after it completes.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => draft.dispose())
      ..ensureVisualUpdate();
  }

  @visibleForTesting
  bool contains(String toolUseId) => _drafts.containsKey(toolUseId);
}
