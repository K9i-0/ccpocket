const mcpApprovalHeader = 'Approve app tool call?';
const mcpApprovalApproveOnce = 'Approve Once';
const mcpApprovalApproveSession = 'Approve this Session';
const mcpApprovalDeny = 'Deny';
const mcpApprovalCancel = 'Cancel';

Map<String, dynamic>? firstRequestUserInputQuestion(
  Map<String, dynamic> input,
) {
  final questions = input['questions'];
  if (questions is! List || questions.isEmpty) return null;
  final first = questions.first;
  return first is Map<String, dynamic>
      ? first
      : Map<String, dynamic>.from(first as Map);
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

bool isMcpApprovalRequestUserInput(Map<String, dynamic> input) {
  if (requestUserInputHeader(input) != mcpApprovalHeader) return false;
  final labels = requestUserInputOptionLabels(input).toSet();
  return labels.contains(mcpApprovalApproveOnce) &&
      labels.contains(mcpApprovalDeny) &&
      labels.contains(mcpApprovalCancel);
}
