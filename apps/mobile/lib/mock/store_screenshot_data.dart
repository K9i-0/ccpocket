import 'package:flutter/material.dart';

import '../models/messages.dart';
import 'mock_scenarios.dart';

// =============================================================================
// Store Screenshot Scenarios
// =============================================================================

/// 01: Self-hosted agents running on Mac/Linux, controlled from mobile.
final storeSelfHostedAgentsScenario = MockScenario(
  name: 'Self-Hosted Agents',
  icon: Icons.history,
  description: '01: Self-hosted agent sessions controlled from mobile',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// Backward-compatible alias for older screenshot automation.
final storeSessionListRecentScenario = storeSelfHostedAgentsScenario;

/// 02: Recent sessions from Codex CLI, Codex App, and Claude Code.
final storeRecentSessionsScenario = MockScenario(
  name: 'Recent Sessions',
  icon: Icons.devices,
  description: '02: Continue sessions across devices',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// 03: Session list with 3 running sessions (2 tool approval + 1 plan approval)
final storeApprovalListScenario = MockScenario(
  name: 'Approval List',
  icon: Icons.home_outlined,
  description: '03: Running sessions with approvals',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// Backward-compatible alias for older screenshot automation.
final storeSessionListScenario = storeApprovalListScenario;

/// 04: Chat session with multi-question approval UI.
final storeChatMultiQuestionScenario = MockScenario(
  name: 'Multi-Question Approval',
  icon: Icons.quiz,
  description: '04: Mobile-optimized Codex approval UI',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// Legacy scenario kept for local mock preview coverage.
final storeChatMarkdownInputScenario = MockScenario(
  name: 'Markdown Input',
  icon: Icons.format_list_bulleted,
  description: 'Legacy: Bullet list in chat input field',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 05: Phone-width project Explorer.
final storeProjectExplorerScenario = MockScenario(
  name: 'Project Explorer',
  icon: Icons.folder_copy_outlined,
  description: '05: Browse project files from phone',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// 06: Git review and actions.
final storeGitActionsScenario = MockScenario(
  name: 'Git Actions',
  icon: Icons.difference,
  description: '06: Review and ship agent-edited changes',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// Backward-compatible alias for older screenshot automation.
final storeDiffScenario = storeGitActionsScenario;

/// 07: MCP images and Mac screenshots in context.
final storeImagesScreenshotsScenario = MockScenario(
  name: 'Images & Screenshots',
  icon: Icons.screenshot_monitor,
  description: '07: Review MCP images and Mac screenshots in chat',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// Line-number width test: files with 1-digit to 5-digit line numbers.
final storeDiffLineNumberScenario = MockScenario(
  name: 'Diff Line Numbers',
  icon: Icons.format_list_numbered,
  description: 'Diff with 1~5 digit line numbers',
  steps: [],
  section: MockScenarioSection.chat,
);

/// Legacy scenario kept for local mock preview coverage.
final storeNewSessionScenario = MockScenario(
  name: 'New Session',
  icon: Icons.add_circle_outline,
  description: 'Legacy: New session bottom sheet',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

/// 08: Offline pending message and reconnect state.
final storeNetworkResilienceScenario = MockScenario(
  name: 'Network Resilience',
  icon: Icons.dark_mode_outlined,
  description: '08: Dark theme with a pending mobile prompt',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// iPad 01: Workspace with chat + git pane
final storeIpadWorkspaceOverviewScenario = MockScenario(
  name: 'Workspace Overview',
  icon: Icons.space_dashboard_outlined,
  description: 'iPad 01: Three-pane Codex workspace with Git review',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// iPad 02: Workspace with chat + explorer pane
final storeIpadWorkspaceExplorerScenario = MockScenario(
  name: 'Workspace Explorer',
  icon: Icons.folder_copy_outlined,
  description: 'iPad 02: Three-pane Codex workspace with file explorer',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// iPad 03: Approval UI in context with session list
final storeIpadApprovalContextScenario = MockScenario(
  name: 'Approval In Context',
  icon: Icons.rule_folder_outlined,
  description: 'iPad 03: Codex approval workflow beside the session list',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// iPad 04: Multiple sessions waiting for approval
final storeIpadApprovalQueueScenario = MockScenario(
  name: 'Approval Queue',
  icon: Icons.pending_actions_outlined,
  description: 'iPad 04: Multiple Codex sessions waiting for approval',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

/// iPad 05: Workspace overview in dark theme
final storeIpadDarkWorkspaceScenario = MockScenario(
  name: 'Dark Workspace',
  icon: Icons.dark_mode_outlined,
  description: 'iPad 05: Codex workspace in dark theme',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
  provider: MockScenarioProvider.codex,
);

final List<MockScenario> storeScreenshotScenarios = [
  storeSelfHostedAgentsScenario,
  storeRecentSessionsScenario,
  storeApprovalListScenario,
  storeChatMultiQuestionScenario,
  storeProjectExplorerScenario,
  storeGitActionsScenario,
  storeImagesScreenshotsScenario,
  storeNetworkResilienceScenario,
  storeIpadWorkspaceOverviewScenario,
  storeIpadWorkspaceExplorerScenario,
  storeIpadApprovalContextScenario,
  storeIpadApprovalQueueScenario,
  storeIpadDarkWorkspaceScenario,
];

// =============================================================================
// Running Sessions (for Session List screenshots)
// =============================================================================

List<SessionInfo> storeHomeRunningSessions() => [
  SessionInfo(
    id: 'store-home-1',
    provider: 'codex',
    projectPath: '/Users/dev/projects/web-store',
    status: 'running',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 15))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 2))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    lastMessage:
        'Refactoring the checkout flow and preparing the diff for review...',
    queuedInput: const QueuedInputItem(
      itemId: 'store-home-queued',
      text: 'Stage the checkout files after the current turn finishes.',
      createdAt: '2026-05-01T02:00:00.000Z',
      imageCount: 1,
    ),
  ),
  SessionInfo(
    id: 'store-home-2',
    provider: 'claude',
    projectPath: '/Users/dev/projects/docs-site',
    status: 'running',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 9))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    gitBranch: 'docs/api-refresh',
    lastMessage: 'Claude Code is checking the setup guide and release copy.',
  ),
];

List<SessionInfo> storeApprovalRunningSessions() => [
  SessionInfo(
    id: 'store-run-1',
    provider: 'codex',
    projectPath: '/Users/dev/projects/web-store',
    status: 'running',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 15))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 2))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    lastMessage:
        'Refactoring the checkout flow and preparing the diff for review...',
  ),
  SessionInfo(
    id: 'store-run-2',
    provider: 'codex',
    projectPath: '/Users/dev/projects/api-server',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(seconds: 30))
        .toIso8601String(),
    gitBranch: 'feat/rate-limits',
    lastMessage: 'Running the API test suite before merging.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'store-tool-1',
      toolName: 'Bash',
      input: {'command': 'pnpm test -- api/rate-limit'},
    ),
  ),
  SessionInfo(
    id: 'store-run-3',
    provider: 'codex',
    projectPath: '/Users/dev/projects/dashboard',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    gitBranch: 'feat/offline-queue',
    lastMessage:
        "I've designed the implementation plan for offline resend support.",
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'store-plan-1',
      toolName: 'ExitPlanMode',
      input: {'plan': 'Offline resend implementation plan'},
    ),
  ),
];

/// Minimal running sessions: keeps Recent Sessions as the focus.
List<SessionInfo> storeRunningSessionsMinimal() => [
  // Empty on purpose: the Recent Sessions screenshot should not look like the
  // home/running-session screenshot.
];

// =============================================================================
// Recent Sessions (for Session List screenshot)
// =============================================================================

List<RecentSession> storeRecentSessions() => [
  RecentSession(
    sessionId: 'store-recent-1',
    provider: 'codex',
    name: 'Stripe Checkout Redesign',
    summary: 'Codex refactored the checkout flow with Stripe integration',
    firstPrompt: 'Use Codex to redesign the checkout page with Stripe Elements',
    created: DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(minutes: 20))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    projectPath: '/Users/dev/projects/web-store',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-2',
    provider: 'codex',
    name: 'WebSocket Bug Fix',
    summary: 'Codex fixed WebSocket reconnection on network change',
    firstPrompt: 'Fix the WebSocket drop when switching from WiFi to cellular',
    created: DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    gitBranch: 'fix/ws-reconnect',
    projectPath: '/Users/dev/projects/web-store',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-3',
    provider: 'codex',
    name: 'API Rate Limits',
    summary: 'Codex added rate-limit tests for the API routes',
    firstPrompt: 'Add rate-limit handling and tests for the API routes',
    created: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    gitBranch: 'feat/rate-limits',
    projectPath: '/Users/dev/projects/api-server',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-4',
    provider: 'codex',
    name: 'CI/CD Pipeline',
    summary: 'Codex set up CI/CD with GitHub Actions',
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
    summary: 'Claude Code session is also available in the same list',
    firstPrompt:
        'Migrate authentication from session-based auth to OAuth 2.0 PKCE',
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 8))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 6))
        .toIso8601String(),
    gitBranch: 'refactor/auth-oauth2',
    projectPath: '/Users/dev/projects/web-store',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-6',
    provider: 'codex',
    name: 'API Test Coverage',
    summary: 'Write unit tests for request validation',
    firstPrompt: 'Add comprehensive tests for request validation middleware',
    created: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 18))
        .toIso8601String(),
    gitBranch: 'test/request-validation',
    projectPath: '/Users/dev/projects/api-server',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-7',
    provider: 'codex',
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
    model: 'gpt-5.5-codex',
    projectPath: '/Users/dev/projects/web-store',
  ),
  const StatusMessage(status: ProcessStatus.running),
  const UserInputMessage(
    text:
        'Codex, finish the checkout refactor and ask before changing the '
        'database migration, analytics events, or payment retry behavior.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-mq-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I reviewed the checkout flow and found three decisions that "
              "should be confirmed before I edit the remaining files.",
        ),
        const ToolUseContent(
          id: 'store-mq-ask-1',
          name: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question':
                    'How should I handle existing carts during the migration?',
                'header': 'Migration',
                'options': [
                  {
                    'label': 'Preserve carts (Recommended)',
                    'description':
                        'Keep active carts and migrate line items in place.',
                  },
                  {
                    'label': 'Create fresh carts',
                    'description':
                        'Start new checkout sessions after the deploy.',
                  },
                  {
                    'label': 'Ask again later',
                    'description': 'Leave migration code unchanged for now.',
                  },
                ],
                'multiSelect': false,
              },
              {
                'question': 'Which checks should I run before committing?',
                'header': 'Checks',
                'options': [
                  {
                    'label': 'Unit tests',
                    'description':
                        'Run the focused checkout and payment test suites.',
                  },
                  {
                    'label': 'Type check',
                    'description': 'Verify generated types and API contracts.',
                  },
                  {
                    'label': 'Lint',
                    'description':
                        'Run formatting and lint checks before staging.',
                  },
                ],
                'multiSelect': true,
              },
              {
                'question': 'Should I stage the edited checkout files?',
                'header': 'Git',
                'options': [
                  {
                    'label': 'Stage checkout files (Recommended)',
                    'description':
                        'Prepare the current diff for commit review.',
                  },
                  {
                    'label': 'Leave unstaged',
                    'description':
                        'Keep the diff visible without changing the index.',
                  },
                  {
                    'label': 'Revert risky file',
                    'description': 'Revert only the payment retry module.',
                  },
                ],
                'multiSelect': false,
              },
            ],
          },
        ),
      ],
      model: 'gpt-5.5-codex',
    ),
  ),
  const PermissionRequestMessage(
    toolUseId: 'store-mq-ask-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
        {
          'question':
              'How should I handle existing carts during the migration?',
          'header': 'Migration',
          'options': [
            {
              'label': 'Preserve carts (Recommended)',
              'description':
                  'Keep active carts and migrate line items in place.',
            },
            {
              'label': 'Create fresh carts',
              'description': 'Start new checkout sessions after the deploy.',
            },
            {
              'label': 'Ask again later',
              'description': 'Leave migration code unchanged for now.',
            },
          ],
          'multiSelect': false,
        },
        {
          'question': 'Which checks should I run before committing?',
          'header': 'Checks',
          'options': [
            {
              'label': 'Unit tests',
              'description':
                  'Run the focused checkout and payment test suites.',
            },
            {
              'label': 'Type check',
              'description': 'Verify generated types and API contracts.',
            },
            {
              'label': 'Lint',
              'description': 'Run formatting and lint checks before staging.',
            },
          ],
          'multiSelect': true,
        },
        {
          'question': 'Should I stage the edited checkout files?',
          'header': 'Git',
          'options': [
            {
              'label': 'Stage checkout files (Recommended)',
              'description': 'Prepare the current diff for commit review.',
            },
            {
              'label': 'Leave unstaged',
              'description':
                  'Keep the diff visible without changing the index.',
            },
            {
              'label': 'Revert risky file',
              'description': 'Revert only the payment retry module.',
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
    model: 'gpt-5.5-codex',
    projectPath: '/Users/dev/projects/web-store',
  ),
  const StatusMessage(status: ProcessStatus.idle),
  const UserInputMessage(
    text: 'Codex, inspect the checkout module before editing.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-md-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I found the key checkout files:\n\n"
              "```\n"
              "web-store/\n"
              "├── package.json\n"
              "├── src/\n"
              "│   ├── app/\n"
              "│   │   └── checkout/\n"
              "│   │       └── page.tsx\n"
              "│   ├── components/\n"
              "│   │   └── checkout/\n"
              "│   │       ├── payment-form.tsx\n"
              "│   │       └── order-summary.tsx\n"
              "│   └── lib/\n"
              "│       ├── api.ts\n"
              "│       └── stripe.ts\n"
              "└── tests/\n"
              "    └── checkout.spec.ts\n"
              "```\n\n"
              "Likely edit points:\n"
              "- **`src/app/checkout/page.tsx`** — Checkout route and data loading\n"
              "- **`src/components/checkout/`** — Payment form and order summary\n"
              "- **`src/lib/stripe.ts`** — Stripe client and payment intent helpers\n\n"
              "I can refactor the payment logic, update tests, and stage the "
              "resulting diff when you're ready.",
        ),
      ],
      model: 'gpt-5.5-codex',
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
/// screenshot. Paths match the assistant message referencing web-store.
const storeMarkdownInputFileList = [
  'package.json',
  'src/app/checkout/page.tsx',
  'src/components/checkout/payment-form.tsx',
  'src/components/checkout/order-summary.tsx',
  'src/components/product-grid.tsx',
  'src/components/auth/sign-in-form.tsx',
  'src/lib/api.ts',
  'src/lib/stripe.ts',
  'tests/checkout.spec.ts',
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
const storeMockDiff = '''diff --git a/src/lib/api.ts b/src/lib/api.ts
index 3a4b2c1..8f9e0d2 100644
--- a/src/lib/api.ts
+++ b/src/lib/api.ts
@@ -1,6 +1,7 @@
 import { getSession } from "@/lib/auth";
 import { ApiError } from "@/lib/errors";
+import { retry } from "@/lib/retry";

 export async function apiFetch<T>(path: string, init?: RequestInit) {
   const session = await getSession();
@@ -15,12 +16,22 @@ export async function apiFetch<T>(path: string, init?: RequestInit) {
     },
   };

-  const response = await fetch(`\${process.env.API_BASE_URL}\${path}`, request);
+  const response = await retry(
+    () => fetch(`\${process.env.API_BASE_URL}\${path}`, request),
+    {
+      retries: 2,
+      shouldRetry: (error) =>
+        error instanceof TypeError || error.status >= 500,
+    },
+  );

-  if (!response.ok) {
-    throw new ApiError(response.status, await response.text());
+  if (response.status >= 500) {
+    throw new ApiError(response.status, "Server error");
+  }
+  if (response.status >= 400) {
+    throw new ApiError(response.status, await response.text());
   }

   return response.json() as Promise<T>;
diff --git a/src/lib/stripe.ts b/src/lib/stripe.ts
index 5c1d3e4..a7b8f9c 100644
--- a/src/lib/stripe.ts
+++ b/src/lib/stripe.ts
@@ -22,8 +22,14 @@ export async function createPaymentIntent(cart: Cart) {
     metadata: { cartId: cart.id },
   });
-  return intent;
+  logger.info({ intentId: intent.id }, "created payment intent");
+  return intent;
+}
+
+export async function confirmPayment(intentId: string) {
+  await stripe.paymentIntents.confirm(intentId);
+  logger.info({ intentId }, "confirmed payment");
 }
diff --git a/tests/checkout.spec.ts b/tests/checkout.spec.ts
new file mode 100644
index 0000000..b2c4e5a
--- /dev/null
+++ b/tests/checkout.spec.ts
@@ -0,0 +1,18 @@
+import { describe, expect, it, vi } from "vitest";
+import { apiFetch } from "../src/lib/api";
+
+describe("apiFetch", () => {
+  it("retries transient server failures", async () => {
+    const fetchMock = vi
+      .fn()
+      .mockRejectedValueOnce(new TypeError("network"))
+      .mockResolvedValueOnce(new Response('{"ok":true}'));
+    vi.stubGlobal("fetch", fetchMock);
+
+    const result = await apiFetch<{ ok: boolean }>("/checkout");
+
+    expect(result.ok).toBe(true);
+    expect(fetchMock).toHaveBeenCalledTimes(2);
+  });
+});
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
