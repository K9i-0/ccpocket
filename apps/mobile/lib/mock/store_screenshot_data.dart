import 'package:flutter/material.dart';

import '../models/messages.dart';
import 'mock_scenarios.dart';

// =============================================================================
// Store Screenshot Scenarios
// =============================================================================

/// 01: Session list with 1 running + recent sessions (plain overview)
final storeSessionListRecentScenario = MockScenario(
  name: 'Session List (Recent)',
  icon: Icons.history,
  description: '01: Minimal running, recent sessions prominent',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 02: Session list with 3 running sessions (2 tool approval + 1 plan approval)
final storeSessionListScenario = MockScenario(
  name: 'Session List',
  icon: Icons.home_outlined,
  description: '02: Running sessions with approvals',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 03: Chat session with multi-question approval UI
final storeChatMultiQuestionScenario = MockScenario(
  name: 'Multi-Question Approval',
  icon: Icons.quiz,
  description: '03: Mobile-optimized approval UI with multiple questions',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 04: Chat session with markdown bullet list in input field
final storeChatMarkdownInputScenario = MockScenario(
  name: 'Markdown Input',
  icon: Icons.format_list_bulleted,
  description: '04: Bullet list in chat input field',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 05: Session list with named recent sessions
final storeSessionListNamedScenario = MockScenario(
  name: 'Session List (Named)',
  icon: Icons.label,
  description: '05: Named sessions for organization',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 06: Chat session with image attachment + bottom sheet
final storeChatImageAttachScenario = MockScenario(
  name: 'Image Attach',
  icon: Icons.image,
  description: '06: Image attachment with bottom sheet',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 07: Diff screen with realistic git diff
final storeDiffScenario = MockScenario(
  name: 'Git Diff',
  icon: Icons.difference,
  description: '07: Git diff viewer',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 08: Session list with New Session bottom sheet open
final storeNewSessionScenario = MockScenario(
  name: 'New Session',
  icon: Icons.add_circle_outline,
  description: '08: New session bottom sheet',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

// Legacy aliases (kept for existing chat history rendering)
final storeChatCodingScenario = MockScenario(
  name: 'Coding Session',
  icon: Icons.code,
  description: 'Feature implementation with file edits',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

final storeChatTaskScenario = MockScenario(
  name: 'Task Planning',
  icon: Icons.checklist,
  description: 'Refactoring with thinking + TodoWrite',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

final List<MockScenario> storeScreenshotScenarios = [
  storeSessionListRecentScenario,
  storeSessionListScenario,
  storeChatMultiQuestionScenario,
  storeChatMarkdownInputScenario,
  storeSessionListNamedScenario,
  storeChatImageAttachScenario,
  storeDiffScenario,
  storeNewSessionScenario,
  storeChatCodingScenario,
  storeChatTaskScenario,
];

// =============================================================================
// Running Sessions (for Session List screenshot)
// =============================================================================

List<SessionInfo> storeRunningSessions() => [
  SessionInfo(
    id: 'store-run-1',
    provider: 'claude',
    projectPath: '/Users/dev/projects/shopify-app',
    status: 'running',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 15))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 2))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    lastMessage:
        'Implementing the new checkout flow with Stripe integration...',
  ),
  SessionInfo(
    id: 'store-run-2',
    provider: 'codex',
    projectPath: '/Users/dev/projects/rust-cli',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(seconds: 30))
        .toIso8601String(),
    gitBranch: 'feat/parser',
    lastMessage: 'Running the test suite to verify parser changes.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'store-tool-1',
      toolName: 'Bash',
      input: {'command': 'cargo test --release'},
    ),
  ),
  SessionInfo(
    id: 'store-run-3',
    provider: 'claude',
    projectPath: '/Users/dev/projects/my-portfolio',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    gitBranch: 'feat/dark-mode',
    lastMessage: "I've designed the implementation plan for dark mode support.",
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'store-plan-1',
      toolName: 'ExitPlanMode',
      input: {'plan': 'Dark Mode Implementation Plan'},
    ),
  ),
];

/// Minimal running sessions: 1 compact card so Recent section is visible.
List<SessionInfo> storeRunningSessionsMinimal() => [
  SessionInfo(
    id: 'store-run-min-1',
    provider: 'claude',
    projectPath: '/Users/dev/projects/shopify-app',
    status: 'running',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 12))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    lastMessage:
        'Implementing the new checkout flow with Stripe integration...',
  ),
];

// =============================================================================
// Recent Sessions (for Session List screenshot)
// =============================================================================

List<RecentSession> storeRecentSessions() => [
  RecentSession(
    sessionId: 'store-recent-1',
    provider: 'claude',
    summary: 'Add product search with Algolia integration',
    firstPrompt: 'Integrate Algolia search into the product listing page',
    created: DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    gitBranch: 'feat/search',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-2',
    provider: 'claude',
    summary: 'Fix WebSocket reconnection on network change',
    firstPrompt: 'WebSocket drops when switching from WiFi to cellular',
    created: DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    gitBranch: 'fix/ws-reconnect',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-3',
    provider: 'codex',
    summary: 'Implement streaming JSON parser for large files',
    firstPrompt: 'Add a streaming JSON parser that handles files over 1GB',
    created: DateTime.now()
        .subtract(const Duration(hours: 6))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    gitBranch: 'feat/json-parser',
    projectPath: '/Users/dev/projects/rust-cli',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-4',
    provider: 'claude',
    summary: 'Set up CI/CD pipeline with GitHub Actions',
    firstPrompt: 'Create a CI/CD pipeline for build, test, and deploy',
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 2))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    gitBranch: 'chore/ci-cd',
    projectPath: '/Users/dev/projects/my-portfolio',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-5',
    provider: 'claude',
    summary: 'Refactor auth module to use OAuth 2.0 PKCE flow',
    firstPrompt: 'Migrate the authentication from session-based to OAuth 2.0',
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 8))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 6))
        .toIso8601String(),
    gitBranch: 'refactor/auth-oauth2',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-6',
    provider: 'codex',
    summary: 'Write unit tests for CLI argument parser',
    firstPrompt: 'Add comprehensive tests for the argument parsing module',
    created: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 18))
        .toIso8601String(),
    gitBranch: 'test/cli-args',
    projectPath: '/Users/dev/projects/rust-cli',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-7',
    provider: 'claude',
    summary: 'Add responsive layout for tablet and desktop',
    firstPrompt: 'Make the app responsive across phone, tablet, and desktop',
    created: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 2, hours: 12))
        .toIso8601String(),
    gitBranch: 'feat/responsive',
    projectPath: '/Users/dev/projects/my-portfolio',
    isSidechain: false,
  ),
];

// =============================================================================
// Recent Sessions with Names (for Named Sessions screenshot)
// =============================================================================

List<RecentSession> storeRecentSessionsNamed() => [
  RecentSession(
    sessionId: 'store-named-1',
    provider: 'claude',
    name: 'Stripe Checkout Redesign',
    summary: 'Redesign the checkout flow with Stripe integration',
    firstPrompt: 'Redesign the checkout page with Stripe Elements',
    created: DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(minutes: 20))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-named-2',
    provider: 'claude',
    name: 'WebSocket Bug Fix',
    summary: 'Fix WebSocket reconnection on network change',
    firstPrompt: 'WebSocket drops when switching from WiFi to cellular',
    created: DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    gitBranch: 'fix/ws-reconnect',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-named-3',
    provider: 'codex',
    name: 'Streaming JSON Parser',
    summary: 'Implement streaming JSON parser for large files',
    firstPrompt: 'Add a streaming JSON parser that handles files over 1GB',
    created: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    gitBranch: 'feat/json-parser',
    projectPath: '/Users/dev/projects/rust-cli',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-named-4',
    provider: 'claude',
    name: 'CI/CD Pipeline',
    summary: 'Set up CI/CD pipeline with GitHub Actions',
    firstPrompt: 'Create a CI/CD pipeline for build, test, and deploy',
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 2))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    gitBranch: 'chore/ci-cd',
    projectPath: '/Users/dev/projects/my-portfolio',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-named-5',
    provider: 'claude',
    name: 'OAuth 2.0 Migration',
    summary: 'Refactor auth module to use OAuth 2.0 PKCE flow',
    firstPrompt: 'Migrate the authentication from session-based to OAuth 2.0',
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 8))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 6))
        .toIso8601String(),
    gitBranch: 'refactor/auth-oauth2',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-named-6',
    provider: 'codex',
    name: 'CLI Argument Tests',
    summary: 'Write unit tests for CLI argument parser',
    firstPrompt: 'Add comprehensive tests for the argument parsing module',
    created: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 18))
        .toIso8601String(),
    gitBranch: 'test/cli-args',
    projectPath: '/Users/dev/projects/rust-cli',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-named-7',
    provider: 'claude',
    name: 'Responsive Layout',
    summary: 'Add responsive layout for tablet and desktop',
    firstPrompt: 'Make the app responsive across phone, tablet, and desktop',
    created: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 2, hours: 12))
        .toIso8601String(),
    gitBranch: 'feat/responsive',
    projectPath: '/Users/dev/projects/my-portfolio',
    isSidechain: false,
  ),
];

// =============================================================================
// Chat History: Multi-Question Approval
// =============================================================================

/// A chat session that ends with a multi-question AskUserQuestion.
/// Used for the "mobile-optimized approval UI" store screenshot.
final List<ServerMessage> storeChatMultiQuestion = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-mq',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/shopify-app',
  ),
  const StatusMessage(status: ProcessStatus.running),
  const UserInputMessage(
    text:
        'Set up the new notification system. Use Firebase Cloud Messaging '
        'and handle both foreground and background notifications.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-mq-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I'll set up FCM for push notifications. Before I begin, I have "
              "a few questions about how you'd like to configure the system.",
        ),
        const ToolUseContent(
          id: 'store-mq-ask-1',
          name: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question':
                    'How should notifications be displayed when the app is in the foreground?',
                'header': 'Foreground',
                'options': [
                  {
                    'label': 'In-app banner (Recommended)',
                    'description':
                        'Show a custom overlay banner at the top of the screen.',
                  },
                  {
                    'label': 'System notification',
                    'description':
                        'Display as a standard OS notification even when active.',
                  },
                  {
                    'label': 'Silent with badge',
                    'description':
                        'No visible alert, only update the badge count.',
                  },
                ],
                'multiSelect': false,
              },
              {
                'question': 'Which notification channels should I create?',
                'header': 'Channels',
                'options': [
                  {
                    'label': 'Order updates',
                    'description':
                        'Shipping, delivery, and order status changes.',
                  },
                  {
                    'label': 'Promotions',
                    'description': 'Sales, discounts, and marketing campaigns.',
                  },
                  {
                    'label': 'System alerts',
                    'description':
                        'Security, account, and maintenance notifications.',
                  },
                ],
                'multiSelect': true,
              },
              {
                'question': 'Should I add notification analytics tracking?',
                'header': 'Analytics',
                'options': [
                  {
                    'label': 'Firebase Analytics (Recommended)',
                    'description':
                        'Track open rate, engagement, and delivery via Firebase.',
                  },
                  {
                    'label': 'Custom analytics',
                    'description':
                        'Send events to your existing analytics backend.',
                  },
                  {
                    'label': 'No tracking',
                    'description':
                        'Skip analytics for now. Can be added later.',
                  },
                ],
                'multiSelect': false,
              },
            ],
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const PermissionRequestMessage(
    toolUseId: 'store-mq-ask-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
        {
          'question':
              'How should notifications be displayed when the app is in the foreground?',
          'header': 'Foreground',
          'options': [
            {
              'label': 'In-app banner (Recommended)',
              'description':
                  'Show a custom overlay banner at the top of the screen.',
            },
            {
              'label': 'System notification',
              'description':
                  'Display as a standard OS notification even when active.',
            },
            {
              'label': 'Silent with badge',
              'description':
                  'No visible alert, only update the badge count.',
            },
          ],
          'multiSelect': false,
        },
        {
          'question': 'Which notification channels should I create?',
          'header': 'Channels',
          'options': [
            {
              'label': 'Order updates',
              'description':
                  'Shipping, delivery, and order status changes.',
            },
            {
              'label': 'Promotions',
              'description': 'Sales, discounts, and marketing campaigns.',
            },
            {
              'label': 'System alerts',
              'description':
                  'Security, account, and maintenance notifications.',
            },
          ],
          'multiSelect': true,
        },
        {
          'question': 'Should I add notification analytics tracking?',
          'header': 'Analytics',
          'options': [
            {
              'label': 'Firebase Analytics (Recommended)',
              'description':
                  'Track open rate, engagement, and delivery via Firebase.',
            },
            {
              'label': 'Custom analytics',
              'description':
                  'Send events to your existing analytics backend.',
            },
            {
              'label': 'No tracking',
              'description':
                  'Skip analytics for now. Can be added later.',
            },
          ],
          'multiSelect': false,
        },
      ],
    },
  ),
  const StatusMessage(status: ProcessStatus.waitingApproval),
];

// =============================================================================
// Chat History: Markdown Input (short history, then user types a bullet list)
// =============================================================================

/// A chat session where the user is typing a markdown bullet list.
/// The input controller will be pre-populated separately in the wrapper.
final List<ServerMessage> storeChatMarkdownInput = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-md',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/shopify-app',
  ),
  const StatusMessage(status: ProcessStatus.idle),
  const UserInputMessage(
    text: 'Show me the current project structure and key entry points.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-md-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "Here's your project structure:\n\n"
              "```\n"
              "shopify-app/\n"
              "├── lib/\n"
              "│   ├── main.dart\n"
              "│   ├── app.dart\n"
              "│   ├── features/\n"
              "│   │   ├── checkout/\n"
              "│   │   ├── products/\n"
              "│   │   └── auth/\n"
              "│   └── services/\n"
              "│       ├── api_client.dart\n"
              "│       └── stripe_service.dart\n"
              "└── test/\n"
              "```\n\n"
              "Key entry points:\n"
              "- **`lib/main.dart`** — App initialization and provider setup\n"
              "- **`lib/app.dart`** — MaterialApp configuration and routing\n"
              "- **`lib/features/checkout/`** — Checkout flow (Stripe integration)\n\n"
              "What would you like to work on?",
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ResultMessage(
    subtype: 'success',
    cost: 0.0089,
    duration: 3200,
    sessionId: 'store-chat-md',
    inputTokens: 4200,
    outputTokens: 850,
  ),
  const StatusMessage(status: ProcessStatus.idle),
];

/// Pre-populated input text for the markdown input screenshot.
const storeMarkdownInputText =
    'Refactor the checkout module:\n'
    '- Extract payment logic into PaymentService\n'
    '- Add error handling for Stripe API failures\n'
    '- Write unit tests for the new service\n';

// =============================================================================
// Chat History: Image Attachment (short history for context)
// =============================================================================

/// A chat session with brief history. The image attachment and bottom sheet
/// are handled separately by the wrapper.
final List<ServerMessage> storeChatImageAttach = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-img',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/my-portfolio',
  ),
  const StatusMessage(status: ProcessStatus.idle),
  const UserInputMessage(
    text: 'Help me rebuild the hero section of my portfolio site.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-img-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I'd be happy to help rebuild the hero section! Could you share "
              "a screenshot or design mockup of what you have in mind? "
              "That way I can match the layout and style accurately.\n\n"
              "In the meantime, I'll review your current hero component.",
        ),
        const ToolUseContent(
          id: 'store-img-r1',
          name: 'Read',
          input: {'file_path': 'src/components/Hero.tsx'},
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-img-r1',
    toolName: 'Read',
    content:
        'export function Hero() {\n'
        '  return (\n'
        '    <section className="hero">\n'
        '      <h1>Welcome</h1>\n'
        '      <p>Full-stack developer</p>\n'
        '    </section>\n'
        '  );\n'
        '}',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-img-a2',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I see your current hero is quite minimal. Share a design "
              "reference image and I'll create a modern, responsive hero "
              "section with animations.",
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ResultMessage(
    subtype: 'success',
    cost: 0.0156,
    duration: 5400,
    sessionId: 'store-chat-img',
    inputTokens: 8200,
    outputTokens: 1420,
  ),
  const StatusMessage(status: ProcessStatus.idle),
];

// =============================================================================
// Mock Diff (for Diff screen screenshot)
// =============================================================================

/// Realistic unified diff showing a typical code change.
const storeMockDiff = '''diff --git a/lib/services/api_client.dart b/lib/services/api_client.dart
index 3a4b2c1..8f9e0d2 100644
--- a/lib/services/api_client.dart
+++ b/lib/services/api_client.dart
@@ -1,6 +1,7 @@
 import 'dart:convert';
 import 'package:http/http.dart' as http;
+import 'package:retry/retry.dart';

 class ApiClient {
   final String baseUrl;
@@ -15,12 +16,22 @@ class ApiClient {
   });

   Future<Map<String, dynamic>> get(String path) async {
-    final response = await http.get(
-      Uri.parse('\$baseUrl\$path'),
-      headers: _headers,
+    final response = await RetryOptions(
+      maxAttempts: 3,
+      delayFactor: const Duration(milliseconds: 500),
+    ).retry(
+      () => http.get(
+        Uri.parse('\$baseUrl\$path'),
+        headers: _headers,
+      ),
+      retryIf: (e) => e is http.ClientException,
     );

-    if (response.statusCode != 200) {
-      throw ApiException('GET \$path failed: \${response.statusCode}');
+    if (response.statusCode >= 500) {
+      throw ServerException('GET \$path failed: \${response.statusCode}');
+    }
+
+    if (response.statusCode >= 400) {
+      throw ClientException('GET \$path failed: \${response.statusCode}');
     }

     return jsonDecode(response.body) as Map<String, dynamic>;
diff --git a/lib/services/stripe_service.dart b/lib/services/stripe_service.dart
index 5c1d3e4..a7b8f9c 100644
--- a/lib/services/stripe_service.dart
+++ b/lib/services/stripe_service.dart
@@ -22,8 +22,14 @@ class StripeService {
       'amount': amount,
       'currency': currency,
     });
-    return PaymentIntent.fromJson(response);
+    final intent = PaymentIntent.fromJson(response);
+    _logger.info('Created payment intent: \${intent.id}');
+    return intent;
   }
+
+  Future<void> confirmPayment(String intentId) async {
+    await _api.post('/payments/\$intentId/confirm');
+    _logger.info('Confirmed payment: \$intentId');
+  }
 }
diff --git a/test/services/api_client_test.dart b/test/services/api_client_test.dart
new file mode 100644
index 0000000..b2c4e5a
--- /dev/null
+++ b/test/services/api_client_test.dart
@@ -0,0 +1,18 @@
+import 'package:test/test.dart';
+import 'package:shopify_app/services/api_client.dart';
+
+void main() {
+  group('ApiClient', () {
+    late ApiClient client;
+
+    setUp(() {
+      client = ApiClient(baseUrl: 'https://api.example.com');
+    });
+
+    test('retries on ClientException', () async {
+      // Verify retry behavior
+      expect(
+        () => client.get('/test'),
+        throwsA(isA<ServerException>()),
+      );
+    });
+  });
+}
''';

// =============================================================================
// Chat History: Coding Session
// =============================================================================

/// A realistic coding session where the user asks to add a dark mode toggle.
/// Shows: user input → file read → file edits → completion summary → result.
final List<ServerMessage> storeChatCodingSession = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-coding',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/shopify-app',
  ),
  const StatusMessage(status: ProcessStatus.running),
  const UserInputMessage(
    text:
        'Add a dark mode toggle to the settings page. '
        'Use the existing ThemeProvider and persist the preference.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I'll implement the dark mode toggle. Let me check your current theme setup first.",
        ),
        const ToolUseContent(
          id: 'store-r1',
          name: 'Read',
          input: {'file_path': 'lib/theme/theme_provider.dart'},
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-r1',
    toolName: 'Read',
    content:
        'class ThemeProvider extends ChangeNotifier {\n'
        '  ThemeMode _mode = ThemeMode.system;\n'
        '  ThemeMode get mode => _mode;\n'
        '\n'
        '  void setThemeMode(ThemeMode mode) {\n'
        '    _mode = mode;\n'
        '    notifyListeners();\n'
        '  }\n'
        '}',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a2',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "Found the ThemeProvider. I'll add persistence with SharedPreferences and a toggle method.",
        ),
        const ToolUseContent(
          id: 'store-e1',
          name: 'Edit',
          input: {
            'file_path': 'lib/theme/theme_provider.dart',
            'old_string':
                '  void setThemeMode(ThemeMode mode) {\n'
                '    _mode = mode;\n'
                '    notifyListeners();\n'
                '  }',
            'new_string':
                '  Future<void> setThemeMode(ThemeMode mode) async {\n'
                '    _mode = mode;\n'
                '    notifyListeners();\n'
                "    final prefs = await SharedPreferences.getInstance();\n"
                "    await prefs.setString('theme_mode', mode.name);\n"
                '  }\n'
                '\n'
                '  void toggle() {\n'
                '    setThemeMode(\n'
                '      _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,\n'
                '    );\n'
                '  }',
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-e1',
    toolName: 'Edit',
    content: 'File edited successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a3',
      role: 'assistant',
      content: [
        const TextContent(
          text: "Now I'll add the toggle switch to the settings screen.",
        ),
        const ToolUseContent(
          id: 'store-e2',
          name: 'Edit',
          input: {
            'file_path': 'lib/screens/settings_screen.dart',
            'old_string': '    // Theme section',
            'new_string':
                '    SwitchListTile(\n'
                "      title: const Text('Dark Mode'),\n"
                "      subtitle: Text(isDark ? 'On' : 'Off'),\n"
                '      secondary: Icon(\n'
                '        isDark ? Icons.dark_mode : Icons.light_mode,\n'
                '      ),\n'
                '      value: isDark,\n'
                '      onChanged: (_) => themeProvider.toggle(),\n'
                '    ),',
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-e2',
    toolName: 'Edit',
    content: 'File edited successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a4',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "Done! Here's what I changed:\n\n"
              "**`lib/theme/theme_provider.dart`**\n"
              "- Added `toggle()` convenience method\n"
              "- Added SharedPreferences persistence in `setThemeMode()`\n\n"
              "**`lib/screens/settings_screen.dart`**\n"
              "- Added `SwitchListTile` with dark/light mode icon\n"
              "- Wired to ThemeProvider's toggle method\n\n"
              "The user's preference is now persisted across app restarts.",
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ResultMessage(
    subtype: 'success',
    cost: 0.0234,
    duration: 12800,
    sessionId: 'store-chat-coding',
    inputTokens: 15420,
    outputTokens: 2830,
  ),
  const StatusMessage(status: ProcessStatus.idle),
];

// =============================================================================
// Chat History: Task Planning
// =============================================================================

/// A session showing thinking + TodoWrite + edits for an OAuth refactor.
final List<ServerMessage> storeChatTaskPlanning = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-task',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/shopify-app',
  ),
  const StatusMessage(status: ProcessStatus.running),
  const UserInputMessage(
    text:
        'Refactor the authentication module to use OAuth 2.0 with PKCE. '
        'Keep backward compatibility with existing sessions.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t1',
      role: 'assistant',
      content: [
        const ThinkingContent(
          thinking:
              "This is a significant refactor. I need to:\n"
              "1. Understand the current session-based auth flow\n"
              "2. Design the OAuth 2.0 PKCE implementation\n"
              "3. Ensure backward compatibility with existing sessions\n"
              "4. Update token storage and refresh logic\n\n"
              "The PKCE flow requires: authorization endpoint, token endpoint, "
              "code verifier/challenge generation, and secure token storage. "
              "I should use the existing SecureStorage service for tokens.\n\n"
              "For backward compatibility, I'll add a migration path that "
              "converts existing session tokens to OAuth tokens on first use.",
        ),
        const TextContent(
          text:
              "I'll refactor the auth module to OAuth 2.0 PKCE. Let me start by reviewing the current implementation and planning the migration.",
        ),
        const ToolUseContent(
          id: 'store-todo-1',
          name: 'TodoWrite',
          input: {
            'todos': [
              {
                'content': 'Review current auth implementation',
                'status': 'completed',
              },
              {
                'content': 'Implement PKCE code verifier/challenge',
                'status': 'completed',
              },
              {'content': 'Create OAuth token manager', 'status': 'completed'},
              {
                'content': 'Add token refresh with retry logic',
                'status': 'in_progress',
                'activeForm': 'Adding token refresh logic',
              },
              {
                'content': 'Migrate existing sessions to OAuth tokens',
                'status': 'pending',
              },
              {
                'content': 'Update API client interceptors',
                'status': 'pending',
              },
              {'content': 'Write integration tests', 'status': 'pending'},
            ],
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-todo-1',
    toolName: 'TodoWrite',
    content: 'Todo list updated successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t2',
      role: 'assistant',
      content: [
        const TextContent(
          text: "Creating the PKCE helper and OAuth token manager.",
        ),
        const ToolUseContent(
          id: 'store-w1',
          name: 'Write',
          input: {
            'file_path': 'lib/auth/pkce.dart',
            'content':
                "import 'dart:convert';\n"
                "import 'dart:math';\n"
                "import 'package:crypto/crypto.dart';\n\n"
                "class PKCE {\n"
                "  final String verifier;\n"
                "  final String challenge;\n\n"
                "  PKCE._(this.verifier, this.challenge);\n\n"
                "  factory PKCE.generate() {\n"
                "    final random = Random.secure();\n"
                "    final bytes = List.generate(32, (_) => random.nextInt(256));\n"
                "    final verifier = base64Url.encode(bytes);\n"
                "    final digest = sha256.convert(utf8.encode(verifier));\n"
                "    final challenge = base64Url.encode(digest.bytes);\n"
                "    return PKCE._(verifier, challenge);\n"
                "  }\n"
                "}\n",
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-w1',
    toolName: 'Write',
    content: 'File created successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t3',
      role: 'assistant',
      content: [
        const TextContent(
          text: "Now updating the token refresh logic with automatic retry.",
        ),
        const ToolUseContent(
          id: 'store-e3',
          name: 'Edit',
          input: {
            'file_path': 'lib/auth/token_manager.dart',
            'old_string': '  Future<String> getAccessToken() async {',
            'new_string':
                '  Future<String> getAccessToken({int retries = 3}) async {',
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-e3',
    toolName: 'Edit',
    content: 'File edited successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t4',
      role: 'assistant',
      content: [
        const ToolUseContent(
          id: 'store-todo-2',
          name: 'TodoWrite',
          input: {
            'todos': [
              {
                'content': 'Review current auth implementation',
                'status': 'completed',
              },
              {
                'content': 'Implement PKCE code verifier/challenge',
                'status': 'completed',
              },
              {'content': 'Create OAuth token manager', 'status': 'completed'},
              {
                'content': 'Add token refresh with retry logic',
                'status': 'completed',
              },
              {
                'content': 'Migrate existing sessions to OAuth tokens',
                'status': 'in_progress',
                'activeForm': 'Migrating existing sessions',
              },
              {
                'content': 'Update API client interceptors',
                'status': 'pending',
              },
              {'content': 'Write integration tests', 'status': 'pending'},
            ],
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-todo-2',
    toolName: 'TodoWrite',
    content: 'Todo list updated successfully.',
  ),
  const StatusMessage(status: ProcessStatus.running),
];
