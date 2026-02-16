import 'package:flutter/material.dart';

/// Types of approval items in the swipe queue.
enum ApprovalType { toolApproval, askQuestion, planApproval, textInput }

/// A single option for [ApprovalType.askQuestion].
class QuestionOption {
  final String label;
  final String description;

  const QuestionOption({required this.label, required this.description});
}

/// Dummy approval item for the swipe queue prototype.
class ApprovalItem {
  final String id;
  final ApprovalType type;
  final String sessionName;
  final String projectPath;
  final IconData sessionIcon;

  // Tool approval
  final String? toolName;
  final String? toolSummary;
  final String? diffPreview;

  // Ask question
  final String? question;
  final List<QuestionOption>? options;
  final bool multiSelect;

  // Plan approval
  final String? planSummary;
  final String? planFullText;

  // Text input
  final String? inputPrompt;
  final String? inputHint;

  const ApprovalItem({
    required this.id,
    required this.type,
    required this.sessionName,
    required this.projectPath,
    required this.sessionIcon,
    this.toolName,
    this.toolSummary,
    this.diffPreview,
    this.question,
    this.options,
    this.multiSelect = false,
    this.planSummary,
    this.planFullText,
    this.inputPrompt,
    this.inputHint,
  });
}

/// Sample data for the swipe queue prototype.
final List<ApprovalItem> sampleApprovalItems = [
  // 1. Tool approval — Bash
  const ApprovalItem(
    id: 'q1',
    type: ApprovalType.toolApproval,
    sessionName: 'API Server',
    projectPath: '~/projects/api-server',
    sessionIcon: Icons.dns_outlined,
    toolName: 'Bash',
    toolSummary: 'npm install express cors dotenv',
  ),

  // 2. Tool approval — Edit with diff
  const ApprovalItem(
    id: 'q2',
    type: ApprovalType.toolApproval,
    sessionName: 'Mobile App',
    projectPath: '~/projects/mobile-app',
    sessionIcon: Icons.phone_iphone,
    toolName: 'Edit',
    toolSummary: 'lib/main.dart',
    diffPreview:
        '- import \'package:flutter/material.dart\';\n'
        '+ import \'package:flutter/material.dart\';\n'
        '+ import \'package:provider/provider.dart\';\n'
        '  \n'
        '  void main() {\n'
        '-   runApp(const MyApp());\n'
        '+   runApp(\n'
        '+     MultiProvider(\n'
        '+       providers: [...],\n'
        '+       child: const MyApp(),\n'
        '+     ),\n'
        '+   );\n'
        '  }',
  ),

  // 3. Ask question — binary choice (2 options, swipe-selectable)
  const ApprovalItem(
    id: 'q2b',
    type: ApprovalType.askQuestion,
    sessionName: 'Deployment',
    projectPath: '~/projects/deploy',
    sessionIcon: Icons.cloud_upload_outlined,
    question: 'Deploy to production now?',
    options: [
      QuestionOption(label: 'No, wait', description: 'Defer to next sprint.'),
      QuestionOption(
        label: 'Yes, deploy',
        description: 'Ship it to production.',
      ),
    ],
  ),

  // 4. Ask question — single select (3 options, swipe-selectable)
  const ApprovalItem(
    id: 'q3',
    type: ApprovalType.askQuestion,
    sessionName: 'Backend',
    projectPath: '~/projects/backend',
    sessionIcon: Icons.storage_outlined,
    question: 'Which database should we use?',
    options: [
      QuestionOption(
        label: 'PostgreSQL (Recommended)',
        description: 'Full-featured relational DB, great for complex queries.',
      ),
      QuestionOption(
        label: 'SQLite',
        description: 'Lightweight embedded database, no server needed.',
      ),
      QuestionOption(
        label: 'MongoDB',
        description: 'Document-based NoSQL, flexible schema.',
      ),
    ],
  ),

  // 4. Plan approval
  const ApprovalItem(
    id: 'q4',
    type: ApprovalType.planApproval,
    sessionName: 'Auth Feature',
    projectPath: '~/projects/auth-service',
    sessionIcon: Icons.lock_outline,
    planSummary:
        'JWT authentication with refresh tokens, '
        'middleware integration, and role-based access control.',
    planFullText:
        '# Authentication Implementation Plan\n\n'
        '## Step 1: Data Layer\n'
        '- Create User model with Freezed\n'
        '- Add JWT token pair (access + refresh)\n'
        '- SQLite migration for users table\n\n'
        '## Step 2: Auth Service\n'
        '- Login / Register / Logout endpoints\n'
        '- Token refresh logic with rotation\n'
        '- Password hashing with bcrypt\n\n'
        '## Step 3: Middleware\n'
        '- Auth middleware for protected routes\n'
        '- Role-based access control (admin/user)\n'
        '- Rate limiting on auth endpoints\n\n'
        '## Step 4: Frontend Integration\n'
        '- SecureStorage for tokens\n'
        '- Auto-refresh on 401\n'
        '- Login/Register screens\n\n'
        '## Step 5: Testing\n'
        '- Unit tests for auth service\n'
        '- Integration tests for token flow\n'
        '- E2E tests for login/register',
  ),

  // 5. Tool approval — Write
  const ApprovalItem(
    id: 'q5',
    type: ApprovalType.toolApproval,
    sessionName: 'CI/CD',
    projectPath: '~/projects/infra',
    sessionIcon: Icons.rocket_launch_outlined,
    toolName: 'Write',
    toolSummary: '.github/workflows/deploy.yml',
  ),

  // 6. Text input
  const ApprovalItem(
    id: 'q6',
    type: ApprovalType.textInput,
    sessionName: 'Config',
    projectPath: '~/projects/config',
    sessionIcon: Icons.settings_outlined,
    inputPrompt: 'Please enter your OpenAI API key for the integration.',
    inputHint: 'sk-...',
  ),

  // 7. Ask question — multi select
  const ApprovalItem(
    id: 'q7',
    type: ApprovalType.askQuestion,
    sessionName: 'Frontend',
    projectPath: '~/projects/frontend',
    sessionIcon: Icons.web_outlined,
    question: 'Which features do you want to enable?',
    multiSelect: true,
    options: [
      QuestionOption(
        label: 'Dark Mode',
        description: 'Theme switching with system preference sync.',
      ),
      QuestionOption(
        label: 'Internationalization',
        description: 'Multi-language support with ARB files.',
      ),
      QuestionOption(
        label: 'Analytics',
        description: 'Firebase Analytics for usage tracking.',
      ),
      QuestionOption(
        label: 'Push Notifications',
        description: 'FCM integration for real-time alerts.',
      ),
    ],
  ),

  // 8. Tool approval — Bash (git)
  const ApprovalItem(
    id: 'q8',
    type: ApprovalType.toolApproval,
    sessionName: 'Refactor',
    projectPath: '~/projects/refactor',
    sessionIcon: Icons.construction_outlined,
    toolName: 'Bash',
    toolSummary:
        'git checkout -b feature/auth && git push -u origin feature/auth',
  ),
];
