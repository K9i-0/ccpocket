import assert from 'node:assert/strict';
import test from 'node:test';

import {
  MAX_REVIEW_FILES,
  evaluateIntake,
  getField,
  getSection,
  isHighRiskPath,
  isReviewPolicyPath,
  isUiRelatedPath,
  requiresReviewPolicyOverride,
  sizeLabel,
} from './pr-readiness.mjs';

function body(overrides = {}) {
  const values = {
    summary: 'Fix connection recovery after a transient disconnect.',
    related: '#123',
    why: 'The issue and implementation scope are already agreed.',
    changes: '- Retry the connection once.\n- Add regression coverage.',
    primaryGoal: 'Restore a disconnected Bridge session.',
    outOfScope: 'Changing the WebSocket protocol.',
    splitPlan: 'The production change and regression test form one atomic fix.',
    automated: '`npm run test:bridge` — passed.',
    manual: 'Disconnected and reconnected a local test client successfully.',
    platform: 'macOS 15, Node.js 22.',
    risk: 'Low',
    risks: 'A retry could occur once after an intentional disconnect.',
    rollback: 'Revert this PR.',
    noVisual: true,
    visual: false,
    noVisualReason: 'Bridge-only behavior; no mobile rendering changes.',
    before: '',
    after: '',
    device: '',
    ...overrides,
  };
  const checked = (selected) => (selected ? 'x' : ' ');

  return `## Summary

${values.summary}

## Why This Is A PR

- Related Issue / Prompt Request: ${values.related}
- Why this is ready for PR review: ${values.why}

## Changes

${values.changes}

## Scope Check

- Single primary goal: ${values.primaryGoal}
- Intentionally out of scope: ${values.outOfScope}
- Split plan or why this cannot be split: ${values.splitPlan}

## Test Evidence

- Automated tests (command and result): ${values.automated}
- Manual validation: ${values.manual}
- Target platform and version: ${values.platform}

## Risk and Rollback

- [${checked(values.risk === 'Low')}] Low
- [${checked(values.risk === 'Medium')}] Medium
- [${checked(values.risk === 'High')}] High
- Main risks: ${values.risks}
- Rollback plan: ${values.rollback}

## UI Evidence

- [${checked(values.noVisual)}] No user-visible UI change
- [${checked(values.visual)}] User-visible UI change
- No-visual-change reason: ${values.noVisualReason}
- Before: ${values.before}
- After: ${values.after}
- Device / platform: ${values.device}

## Author Checklist

- [x] I reviewed the complete diff and can explain and maintain this change.
- [x] This PR contains no unrelated changes.
- [x] User-facing or breaking changes are documented, or documentation is not applicable.
`;
}

test('extracts markdown sections and multiline fields', () => {
  const source = `${body()}\n`;
  const section = getSection(source, 'Test Evidence');
  assert.match(section, /npm run test:bridge/);
  assert.equal(
    getField(section, 'Target platform and version'),
    'macOS 15, Node.js 22.',
  );
});

test('accepts a complete non-UI PR', () => {
  const result = evaluateIntake({
    body: body(),
    files: ['packages/bridge/src/session.ts', 'packages/bridge/src/session.test.ts'],
    fileCount: 2,
  });
  assert.deepEqual(result.errors, []);
  assert.equal(result.uiRelated, false);
  assert.equal(result.size, 'size:S');
});

test('requires a reason when mobile files claim no visual change', () => {
  const result = evaluateIntake({
    body: body({ noVisualReason: '' }),
    files: ['apps/mobile/lib/features/session_list/session_list_screen.dart'],
    fileCount: 1,
  });
  assert.ok(result.errors.some((error) => error.includes('no user-visible change')));
});

test('requires before and after attachments for a visual change', () => {
  const result = evaluateIntake({
    body: body({ noVisual: false, visual: true, noVisualReason: '' }),
    files: ['apps/mobile/lib/features/session_list/session_list_screen.dart'],
    fileCount: 1,
  });
  assert.ok(result.errors.some((error) => error.includes('Before image')));
  assert.ok(result.errors.some((error) => error.includes('After image')));
});

test('accepts N/A with reason for a new UI and an uploaded After image', () => {
  const result = evaluateIntake({
    body: body({
      noVisual: false,
      visual: true,
      noVisualReason: '',
      before: 'N/A — this screen is new.',
      after: '![New screen](https://github.com/user-attachments/assets/example)',
      device: 'iPhone 16 Pro, iOS 18.',
    }),
    files: ['apps/mobile/lib/features/example/example_screen.dart'],
    fileCount: 1,
  });
  assert.deepEqual(result.errors, []);
});

test('requires a linked issue for PRs changing more than 50 files', () => {
  const result = evaluateIntake({
    body: body({ related: 'None — isolated maintenance change.' }),
    files: Array.from({ length: 51 }, (_, index) => `docs/file-${index}.md`),
    fileCount: 51,
  });
  assert.ok(result.errors.some((error) => error.includes('must link a prior Issue')));
  assert.equal(result.size, 'size:L');
});

test('rejects a bare N/A in a required validation field', () => {
  const result = evaluateIntake({
    body: body({ automated: 'N/A' }),
    files: ['docs/maintenance.md'],
    fileCount: 1,
  });
  assert.ok(
    result.errors.some((error) =>
      error.includes('Automated tests (command and result)'),
    ),
  );
});

test('rejects PRs above the hard file limit before parsing the body', () => {
  const result = evaluateIntake({
    body: '',
    files: [],
    fileCount: MAX_REVIEW_FILES + 1,
  });
  assert.equal(result.oversized, true);
  assert.equal(result.errors.length, 1);
  assert.equal(result.size, 'size:XL');
});

test('classifies generated UI files and high-risk paths', () => {
  assert.equal(isUiRelatedPath('apps/mobile/lib/router/app_router.gr.dart'), false);
  assert.equal(isUiRelatedPath('apps/mobile/lib/features/chat/chat_screen.dart'), true);
  assert.equal(isHighRiskPath('.github/workflows/release.yml'), true);
  assert.equal(isHighRiskPath('.coderabbit.yaml'), true);
  assert.equal(isHighRiskPath('packages/bridge/src/websocket.ts'), true);
  assert.equal(isHighRiskPath('docs/architecture.md'), false);
  assert.equal(isReviewPolicyPath('.coderabbit.yaml'), true);
  assert.equal(isReviewPolicyPath('.github/workflows/test.yml'), true);
  assert.equal(isReviewPolicyPath('scripts/pr-readiness.mjs'), true);
  assert.equal(isReviewPolicyPath('CLAUDE.md'), true);
  assert.equal(isReviewPolicyPath('.claude/agents/code-reviewer.md'), true);
  assert.equal(isReviewPolicyPath('.codex/rules/default.rules'), true);
  assert.equal(isReviewPolicyPath('packages/bridge/src/session.ts'), false);
  assert.equal(sizeLabel(10), 'size:S');
  assert.equal(sizeLabel(11), 'size:M');
  assert.equal(sizeLabel(51), 'size:L');
  assert.equal(sizeLabel(151), 'size:XL');
});

test('requires maintainer override for external review-policy changes', () => {
  const policyChange = {
    files: ['.coderabbit.yaml'],
    author: 'external-contributor',
    maintainer: 'K9i-0',
  };
  assert.equal(requiresReviewPolicyOverride({ ...policyChange, override: false }), true);
  assert.equal(requiresReviewPolicyOverride({ ...policyChange, override: true }), false);
  assert.equal(
    requiresReviewPolicyOverride({
      ...policyChange,
      author: 'K9i-0',
      override: false,
    }),
    false,
  );
});
