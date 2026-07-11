const mcpApprovalHeader = 'Approve app tool call?';
const mcpApprovalApproveOnce = 'Approve Once';
const mcpApprovalApproveSession = 'Approve this Session';
const mcpApprovalAllow = 'Allow';
const mcpApprovalAllowSession = 'Allow for this session';
const mcpApprovalAlways = 'Always allow';
const mcpApprovalAllowAndRemember = "Allow and don't ask me again";
const mcpApprovalDeny = 'Deny';
const mcpApprovalDecline = 'Decline';
const mcpApprovalCancel = 'Cancel';

const _mcpApprovalAcceptLabels = {mcpApprovalApproveOnce, mcpApprovalAllow};

const _mcpApprovalSessionLabels = {
  mcpApprovalApproveSession,
  mcpApprovalAllowSession,
};

const _mcpApprovalAlwaysLabels = {
  mcpApprovalAlways,
  mcpApprovalAllowAndRemember,
};

const _mcpApprovalDeclineLabels = {mcpApprovalDeny, mcpApprovalDecline};

Map<String, dynamic>? firstRequestUserInputQuestion(
  Map<String, dynamic> input,
) {
  final questions = requestUserInputQuestions(input);
  return questions.isEmpty ? null : questions.first;
}

List<Map<String, dynamic>> requestUserInputQuestions(
  Map<String, dynamic> input,
) {
  final questions = input['questions'];
  if (questions is! List || questions.isEmpty) return const [];

  final parsed = <Map<String, dynamic>>[];
  for (final value in questions) {
    if (value is! Map) return const [];

    Map<String, dynamic> question;
    try {
      question = Map<String, dynamic>.from(value);
    } catch (_) {
      return const [];
    }

    final text = question['question'];
    if (text is! String || text.trim().isEmpty) return const [];
    if (question.containsKey('header') && question['header'] is! String) {
      return const [];
    }
    if (question.containsKey('multiSelect') &&
        question['multiSelect'] is! bool) {
      return const [];
    }

    if (question.containsKey('options')) {
      final options = question['options'];
      if (options is! List) return const [];
      final parsedOptions = <Map<String, dynamic>>[];
      for (final value in options) {
        if (value is! Map) return const [];
        Map<String, dynamic> option;
        try {
          option = Map<String, dynamic>.from(value);
        } catch (_) {
          return const [];
        }
        if (option['label'] is! String ||
            (option['label'] as String).trim().isEmpty ||
            (option.containsKey('description') &&
                option['description'] is! String)) {
          return const [];
        }
        parsedOptions.add(option);
      }
      question['options'] = parsedOptions;
    }
    parsed.add(question);
  }
  return parsed;
}

List<String> requestUserInputOptionLabels(Map<String, dynamic> input) {
  final firstQuestion = firstRequestUserInputQuestion(input);
  final options = firstQuestion?['options'];
  if (options is! List) return const [];
  return options
      .whereType<Map>()
      .map((option) => option['label'])
      .whereType<String>()
      .toList(growable: false);
}

String? requestUserInputHeader(Map<String, dynamic> input) {
  return firstRequestUserInputQuestion(input)?['header'] as String?;
}

String? requestUserInputQuestionText(Map<String, dynamic> input) {
  return firstRequestUserInputQuestion(input)?['question'] as String?;
}

bool hasRequestUserInputQuestions(Map<String, dynamic> input) {
  return requestUserInputQuestions(input).isNotEmpty;
}

bool _containsAny(Set<String> labels, Set<String> candidates) =>
    labels.any(candidates.contains);

bool isMcpApprovalRequestUserInput(Map<String, dynamic> input) {
  if (requestUserInputHeader(input) != mcpApprovalHeader) return false;
  final labels = requestUserInputOptionLabels(input).toSet();
  final hasApprove =
      _containsAny(labels, _mcpApprovalAcceptLabels) ||
      _containsAny(labels, _mcpApprovalSessionLabels) ||
      _containsAny(labels, _mcpApprovalAlwaysLabels);
  final hasDismiss =
      _containsAny(labels, _mcpApprovalDeclineLabels) ||
      labels.contains(mcpApprovalCancel);
  return hasApprove && hasDismiss;
}

bool isMcpApprovalOptionLabel(String label) {
  return _mcpApprovalAcceptLabels.contains(label) ||
      _mcpApprovalSessionLabels.contains(label) ||
      _mcpApprovalAlwaysLabels.contains(label) ||
      _mcpApprovalDeclineLabels.contains(label) ||
      label == mcpApprovalCancel;
}
