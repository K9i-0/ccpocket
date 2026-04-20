import 'package:flutter/material.dart';

import '../models/messages.dart';
import 'mock_scenarios.dart';

// =============================================================================
// Store Screenshot Scenarios
// =============================================================================

/// 01: Session list with 1 running + named recent sessions
final storeSessionListRecentScenario = MockScenario(
  name: 'Session List (Recent)',
  icon: Icons.history,
  description: '01: Minimal running, named recent sessions',
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

/// 05: Chat session with image attachment + bottom sheet
final storeChatImageAttachScenario = MockScenario(
  name: 'Image Attach',
  icon: Icons.image,
  description: '05: Image attachment with bottom sheet',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 06: Diff screen with realistic git diff
final storeDiffScenario = MockScenario(
  name: 'Git Diff',
  icon: Icons.difference,
  description: '06: Git diff viewer',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// Line-number width test: files with 1-digit to 5-digit line numbers.
final storeDiffLineNumberScenario = MockScenario(
  name: 'Diff Line Numbers',
  icon: Icons.format_list_numbered,
  description: 'Diff with 1~5 digit line numbers',
  steps: [],
  section: MockScenarioSection.chat,
);

/// 07: Session list with New Session bottom sheet open
final storeNewSessionScenario = MockScenario(
  name: 'New Session',
  icon: Icons.add_circle_outline,
  description: '07: New session bottom sheet',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// iPad 01: Workspace with chat + git pane
final storeIpadWorkspaceOverviewScenario = MockScenario(
  name: 'Workspace Overview',
  icon: Icons.space_dashboard_outlined,
  description: 'iPad 01: Three-pane workspace with Git review',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// iPad 02: Workspace with chat + explorer pane
final storeIpadWorkspaceExplorerScenario = MockScenario(
  name: 'Workspace Explorer',
  icon: Icons.folder_copy_outlined,
  description: 'iPad 02: Three-pane workspace with file explorer',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// iPad 03: Approval UI in context with session list
final storeIpadApprovalContextScenario = MockScenario(
  name: 'Approval In Context',
  icon: Icons.rule_folder_outlined,
  description: 'iPad 03: Approval workflow beside the session list',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// iPad 04: Multiple sessions waiting for approval
final storeIpadApprovalQueueScenario = MockScenario(
  name: 'Approval Queue',
  icon: Icons.pending_actions_outlined,
  description: 'iPad 04: Multiple running sessions waiting for approval',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// iPad 05: Workspace overview in dark theme
final storeIpadDarkWorkspaceScenario = MockScenario(
  name: 'Dark Workspace',
  icon: Icons.dark_mode_outlined,
  description: 'iPad 05: Three-pane workspace in dark theme',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

final List<MockScenario> storeScreenshotScenarios = [
  storeSessionListRecentScenario,
  storeSessionListScenario,
  storeChatMultiQuestionScenario,
  storeChatMarkdownInputScenario,
  storeChatImageAttachScenario,
  storeDiffScenario,
  storeNewSessionScenario,
  storeIpadWorkspaceOverviewScenario,
  storeIpadWorkspaceExplorerScenario,
  storeIpadApprovalContextScenario,
  storeIpadApprovalQueueScenario,
  storeIpadDarkWorkspaceScenario,
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
    sessionId: 'store-recent-2',
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
    sessionId: 'store-recent-3',
    provider: 'codex',
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
    sessionId: 'store-recent-4',
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
    sessionId: 'store-recent-5',
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
              'description': 'No visible alert, only update the badge count.',
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
              'description': 'Shipping, delivery, and order status changes.',
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
              'description': 'Send events to your existing analytics backend.',
            },
            {
              'label': 'No tracking',
              'description': 'Skip analytics for now. Can be added later.',
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

/// Mock project file list for file peek detection in the markdown input
/// screenshot. Paths match the assistant message referencing shopify-app.
const storeMarkdownInputFileList = [
  'lib/main.dart',
  'lib/app.dart',
  'lib/features/checkout/checkout_screen.dart',
  'lib/features/checkout/checkout_bloc.dart',
  'lib/features/products/product_list.dart',
  'lib/features/auth/auth_service.dart',
  'lib/services/api_client.dart',
  'lib/services/stripe_service.dart',
  'test/checkout_test.dart',
];

/// Pre-populated input text for the markdown input screenshot.
const storeMarkdownInputText =
    'Refactor the checkout module:\n'
    '- Extract payment logic into PaymentService\n'
    '  - Move Stripe API calls to dedicated methods\n'
    '  - Add retry logic for transient failures\n'
    '- Write unit tests\n'
    '  - ';

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
const storeMockDiff =
    '''diff --git a/lib/services/api_client.dart b/lib/services/api_client.dart
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
// Mock Diff — Line Number Width Test (1-digit to 5-digit)
// =============================================================================

/// Diff with files at various line-number scales to verify dynamic gutter width.
const lineNumberTestDiff = '''diff --git a/config.yaml b/config.yaml
index aaa..bbb 100644
--- a/config.yaml
+++ b/config.yaml
@@ -2,4 +2,5 @@
 name: my-app
 version: 1.0.0
-debug: true
+debug: false
+verbose: true
 port: 8080
diff --git a/lib/utils/logger.dart b/lib/utils/logger.dart
index ccc..ddd 100644
--- a/lib/utils/logger.dart
+++ b/lib/utils/logger.dart
@@ -42,7 +42,9 @@ class Logger {
   void info(String message) {
     if (_level <= LogLevel.info) {
-      _output('[INFO] \$message');
+      final timestamp = DateTime.now().toIso8601String();
+      _output('[\$timestamp] [INFO] \$message');
+      _history.add(message);
     }
   }

diff --git a/lib/services/database.dart b/lib/services/database.dart
index eee..fff 100644
--- a/lib/services/database.dart
+++ b/lib/services/database.dart
@@ -348,8 +348,12 @@ class DatabaseService {
   Future<List<Map<String, dynamic>>> query(
     String table, {
     String? where,
-    List<dynamic>? whereArgs,
+    List<Object?>? whereArgs,
+    String? orderBy,
+    int? limit,
   }) async {
-    return _db.query(table, where: where, whereArgs: whereArgs);
+    return _db.query(
+      table, where: where, whereArgs: whereArgs,
+      orderBy: orderBy, limit: limit,
+    );
   }

diff --git a/lib/core/engine.dart b/lib/core/engine.dart
index ggg..hhh 100644
--- a/lib/core/engine.dart
+++ b/lib/core/engine.dart
@@ -1024,6 +1024,10 @@ class RenderEngine {
     final batch = _prepareBatch(objects);
     _submitToGPU(batch);
+    if (batch.hasTransparency) {
+      _sortByDepth(batch);
+      _blendPass(batch);
+    }
     _frameCount++;
   }

diff --git a/generated/translations_en.dart b/generated/translations_en.dart
index iii..jjj 100644
--- a/generated/translations_en.dart
+++ b/generated/translations_en.dart
@@ -10482,7 +10482,8 @@ class TranslationsEn {
   static const settingsTitle = 'Settings';
   static const settingsTheme = 'Theme';
-  static const settingsLanguage = 'Language';
+  static const settingsLanguage = 'Display Language';
+  static const settingsRegion = 'Region';
   static const settingsAbout = 'About';
 ''';
