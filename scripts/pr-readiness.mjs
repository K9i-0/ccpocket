import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

export const MAX_REVIEW_FILES = 150;
export const LARGE_PR_FILES = 50;
export const SMALL_PR_FILES = 10;

const MANAGED_LABELS = [
  'size:S',
  'size:M',
  'size:L',
  'size:XL',
  'status:needs-author',
  'status:needs-split',
  'review:coderabbit',
  'ready-for-maintainer-review',
  'risk:high',
];

const LABELS = {
  'size:S': { color: '0e8a16', description: 'Changes 10 files or fewer' },
  'size:M': { color: 'fbca04', description: 'Changes 11-50 files' },
  'size:L': { color: 'd93f0b', description: 'Changes 51-150 files' },
  'size:XL': { color: 'b60205', description: 'Changes more than 150 files' },
  'status:needs-author': {
    color: 'd93f0b',
    description: 'Author action is required before maintainer review',
  },
  'status:needs-split': {
    color: 'b60205',
    description: 'PR must be split into smaller independent changes',
  },
  'review:coderabbit': {
    color: '5319e7',
    description: 'PR passed intake and is ready for CodeRabbit review',
  },
  'ready-for-maintainer-review': {
    color: '0e8a16',
    description: 'Intake, CI, and CodeRabbit review are complete',
  },
  'review:override': {
    color: '006b75',
    description: 'Maintainer override for automated readiness gates',
  },
  'risk:high': {
    color: 'b60205',
    description: 'Touches a security, protocol, process, or release boundary',
  },
};

const CODERABBIT_REVIEWERS = new Set(['coderabbitai[bot]', 'coderabbitai']);

const REQUIRED_SECTIONS = [
  'Summary',
  'Why This Is A PR',
  'Changes',
  'Scope Check',
  'Test Evidence',
  'Risk and Rollback',
  'UI Evidence',
  'Author Checklist',
];

const GENERATED_UI_PATHS = [
  /\.g\.dart$/,
  /\.gr\.dart$/,
  /\.freezed\.dart$/,
  /^apps\/mobile\/lib\/l10n\/app_localizations[^/]*\.dart$/,
];

const REVIEW_POLICY_PATHS = [
  /^\.coderabbit\.ya?ml$/,
  /^\.github\/PULL_REQUEST_TEMPLATE\.md$/,
  /^\.github\/workflows\//,
  /^scripts\/pr-readiness(?:\.test)?\.mjs$/,
  /^(?:AGENTS|CLAUDE)\.md$/,
  /^\.(?:agents|claude|codex)\//,
  /^\.mcp\.json$/,
];

const HIGH_RISK_PATHS = [
  ...REVIEW_POLICY_PATHS,
  /^firestore\.rules$/,
  /^firebase\.json$/,
  /^functions\//,
  /^packages\/bridge\/src\/(?:websocket|claude-process|codex-process|proxy|auth)/,
  /^scripts\/.*(?:release|submit|patch|sign)/i,
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function stripComments(value) {
  return value.replace(/<!--[\s\S]*?-->/g, '').trim();
}

function isMeaningful(value) {
  const normalized = stripComments(value)
    .replace(/^[-*]\s*$/gm, '')
    .replace(/\s+/g, ' ')
    .trim();
  return normalized.length > 0;
}

export function getSection(body, title) {
  body = body.replace(/\r\n?/g, '\n');
  const heading = new RegExp(`^##\\s+${escapeRegExp(title)}\\s*$`, 'im');
  const match = heading.exec(body);
  if (!match) return '';

  const start = match.index + match[0].length;
  const remainder = body.slice(start);
  const nextHeading = /^##\s+/m.exec(remainder);
  return stripComments(
    nextHeading ? remainder.slice(0, nextHeading.index) : remainder,
  );
}

export function getField(section, label) {
  const lines = section.split('\n');
  const startPattern = new RegExp(
    `^\\s*-\\s+${escapeRegExp(label)}\\s*:\\s*(.*)$`,
    'i',
  );
  const nextFieldPattern = /^\s*-\s+(?:\[[ xX]\]\s+)?[^:]+:\s*/;
  const start = lines.findIndex((line) => startPattern.test(line));
  if (start < 0) return '';

  const firstLine = lines[start].match(startPattern)?.[1] ?? '';
  const values = [firstLine];
  for (let index = start + 1; index < lines.length; index += 1) {
    if (nextFieldPattern.test(lines[index])) break;
    values.push(lines[index]);
  }
  return stripComments(values.join('\n'));
}

function hasLinkedIssue(value) {
  return (
    /https?:\/\/github\.com\/[^/]+\/[^/]+\/(?:issues|pull)\/\d+/i.test(value) ||
    /(?:^|\s)#\d+(?:\s|$)/.test(value)
  );
}

function hasExplicitReason(value) {
  return /^(?:none|n\/a|not applicable|なし|該当なし)\s*(?:[-—:]\s*)\S.{4,}$/i.test(
    value.trim(),
  );
}

function isCompletedField(value) {
  if (!isMeaningful(value)) return false;
  if (/^(?:none|n\/a|not applicable|なし|該当なし)\s*$/i.test(value.trim())) {
    return false;
  }
  return true;
}

function hasAttachment(value) {
  return /https:\/\/(?:github\.com\/user-attachments|user-images\.githubusercontent\.com|github-production-user-asset-[^.]+\.s3\.amazonaws\.com)\//i.test(
    value,
  );
}

function hasCheckedItem(section, text) {
  return new RegExp(
    `^\\s*-\\s+\\[[xX]\\]\\s+${escapeRegExp(text)}\\s*$`,
    'm',
  ).test(section);
}

export function sizeLabel(fileCount) {
  if (fileCount <= SMALL_PR_FILES) return 'size:S';
  if (fileCount <= 50) return 'size:M';
  if (fileCount <= MAX_REVIEW_FILES) return 'size:L';
  return 'size:XL';
}

export function isUiRelatedPath(path) {
  if (GENERATED_UI_PATHS.some((pattern) => pattern.test(path))) return false;
  return path.startsWith('apps/mobile/lib/') || path.startsWith('apps/mobile/assets/');
}

export function isHighRiskPath(path) {
  return HIGH_RISK_PATHS.some((pattern) => pattern.test(path));
}

export function isReviewPolicyPath(path) {
  return REVIEW_POLICY_PATHS.some((pattern) => pattern.test(path));
}

export function requiresReviewPolicyOverride({ files, author, maintainer, override }) {
  return files.some(isReviewPolicyPath) && author !== maintainer && !override;
}

export function evaluateIntake({ body, files, fileCount, draft = false }) {
  const errors = [];
  const warnings = [];
  const oversized = fileCount > MAX_REVIEW_FILES;
  const large = fileCount > LARGE_PR_FILES && !oversized;
  const uiRelated = files.some(isUiRelatedPath);
  const pathHighRisk = files.some(isHighRiskPath);

  if (oversized) {
    errors.push(
      `This PR changes ${fileCount} files. The project limit is ${MAX_REVIEW_FILES}; split it into independently reviewable PRs.`,
    );
    return {
      errors,
      warnings,
      oversized,
      large,
      uiRelated,
      highRisk: pathHighRisk,
      lightweight: false,
      size: sizeLabel(fileCount),
    };
  }

  const sections = Object.fromEntries(
    REQUIRED_SECTIONS.map((title) => [title, getSection(body, title)]),
  );
  for (const title of REQUIRED_SECTIONS) {
    if (!isMeaningful(sections[title])) {
      errors.push(`Complete the “${title}” section.`);
    }
  }

  const relatedIssue = getField(sections['Why This Is A PR'], 'Related Issue / Prompt Request');
  if (!hasLinkedIssue(relatedIssue) && !hasExplicitReason(relatedIssue)) {
    errors.push(
      'Link the related Issue / Prompt Request, or write “None — <reason>”.',
    );
  }
  if (large && !hasLinkedIssue(relatedIssue)) {
    errors.push('PRs changing more than 50 files must link a prior Issue or Prompt Request.');
  }

  const riskSelections = ['Low', 'Medium', 'High'].filter((risk) =>
    hasCheckedItem(sections['Risk and Rollback'], risk),
  );
  const highRisk = pathHighRisk || riskSelections.includes('High');
  const lightweight = fileCount <= SMALL_PR_FILES && !highRisk;

  const requiredFields = [
    ['Why This Is A PR', 'Why this is ready for PR review'],
    ['Scope Check', 'Single primary goal'],
    ['Scope Check', 'Intentionally out of scope'],
    ['Scope Check', 'Split plan or why this cannot be split'],
    ['Test Evidence', 'Automated tests (command and result)'],
    ['Test Evidence', 'Manual validation'],
    ['Test Evidence', 'Target platform and version'],
    ['Risk and Rollback', 'Main risks'],
    ['Risk and Rollback', 'Rollback plan'],
  ];
  const lightweightAdvisoryFields = new Set([
    'Why this is ready for PR review',
    'Intentionally out of scope',
    'Split plan or why this cannot be split',
    'Manual validation',
    'Target platform and version',
  ]);
  for (const [sectionName, fieldName] of requiredFields) {
    if (!isCompletedField(getField(sections[sectionName], fieldName))) {
      const message = `Complete “${fieldName}” in the ${sectionName} section.`;
      if (lightweight && lightweightAdvisoryFields.has(fieldName)) {
        warnings.push(`Small low-risk PR: ${message}`);
      } else {
        errors.push(message);
      }
    }
  }

  if (riskSelections.length !== 1) {
    errors.push('Select exactly one risk level: Low, Medium, or High.');
  }

  const noVisualChange = hasCheckedItem(
    sections['UI Evidence'],
    'No user-visible UI change',
  );
  const visualChange = hasCheckedItem(
    sections['UI Evidence'],
    'User-visible UI change',
  );
  if (Number(noVisualChange) + Number(visualChange) !== 1) {
    errors.push('Select exactly one UI Evidence option.');
  }

  if (visualChange) {
    const before = getField(sections['UI Evidence'], 'Before');
    const after = getField(sections['UI Evidence'], 'After');
    const device = getField(sections['UI Evidence'], 'Device / platform');
    if (!hasAttachment(before) && !hasExplicitReason(before)) {
      errors.push('Attach a Before image, or write “N/A — <reason>” for a new UI.');
    }
    if (!hasAttachment(after)) {
      errors.push('Attach an After image or recording using a GitHub upload.');
    }
    if (!isMeaningful(device)) {
      errors.push('Complete “Device / platform” for the UI evidence.');
    }
  }

  if (
    uiRelated &&
    noVisualChange &&
    !isMeaningful(getField(sections['UI Evidence'], 'No-visual-change reason'))
  ) {
    errors.push(
      'Files under the mobile UI area changed; explain why there is no user-visible change.',
    );
  }

  const authorChecklist = sections['Author Checklist'];
  const attestations = [
    'I reviewed the complete diff and can explain and maintain this change.',
    'This PR contains no unrelated changes.',
    'User-facing or breaking changes are documented, or documentation is not applicable.',
  ];
  for (const attestation of attestations) {
    if (!hasCheckedItem(authorChecklist, attestation)) {
      errors.push(`Confirm: “${attestation}”`);
    }
  }

  if (draft) {
    warnings.push('Draft PRs are not sent to CodeRabbit or maintainers.');
  }
  if (large) {
    warnings.push('This is a large PR; maintainers may still request further splitting.');
  }
  if (highRisk) {
    warnings.push('High-risk paths changed and require focused maintainer review.');
  }

  return {
    errors,
    warnings,
    oversized,
    large,
    uiRelated,
    highRisk,
    lightweight,
    size: sizeLabel(fileCount),
  };
}

async function request(path, { method = 'GET', body, allow404 = false } = {}) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) throw new Error('GITHUB_TOKEN is required');

  const response = await fetch(`https://api.github.com${path}`, {
    method,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'ccpocket-pr-readiness',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (allow404 && response.status === 404) return null;
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`${method} ${path} failed (${response.status}): ${detail}`);
  }
  if (response.status === 204) return null;
  return response.json();
}

async function paginate(path) {
  const results = [];
  for (let page = 1; page <= 10; page += 1) {
    const separator = path.includes('?') ? '&' : '?';
    const values = await request(`${path}${separator}per_page=100&page=${page}`);
    results.push(...values);
    if (values.length < 100) break;
  }
  return results;
}

async function ensureRepositoryLabels(repo) {
  const repositoryLabels = await paginate(`/repos/${repo}/labels`);
  const existing = new Set(repositoryLabels.map((label) => label.name));
  for (const [name, configuration] of Object.entries(LABELS)) {
    if (existing.has(name)) continue;
    try {
      await request(`/repos/${repo}/labels`, {
        method: 'POST',
        body: { name, ...configuration },
      });
    } catch (error) {
      // A queued workflow run may have created the same label first.
      if (!String(error).includes('(422)')) throw error;
    }
  }
}

async function syncLabels(repo, number, currentLabels, desiredLabels) {
  const current = new Set(currentLabels);
  const desired = new Set(desiredLabels);
  const toAdd = [...desired].filter((label) => !current.has(label));
  const toRemove = MANAGED_LABELS.filter(
    (label) => current.has(label) && !desired.has(label),
  );

  if (toAdd.length > 0) {
    await request(`/repos/${repo}/issues/${number}/labels`, {
      method: 'POST',
      body: { labels: toAdd },
    });
  }
  for (const label of toRemove) {
    await request(
      `/repos/${repo}/issues/${number}/labels/${encodeURIComponent(label)}`,
      { method: 'DELETE', allow404: true },
    );
  }
}

function latestReviewFor(reviews, predicate) {
  return reviews
    .filter(predicate)
    .sort((left, right) =>
      String(right.submitted_at ?? '').localeCompare(String(left.submitted_at ?? '')),
    )[0];
}

export function codeRabbitGate(reviews, statuses, headSha) {
  const review = latestReviewFor(
    reviews,
    (item) =>
      item.commit_id === headSha &&
      CODERABBIT_REVIEWERS.has(String(item.user?.login ?? '').toLowerCase()),
  );
  if (review) {
    if (review.state === 'APPROVED') {
      return { state: 'success', detail: 'CodeRabbit approved the latest commit.' };
    }
    if (review.state === 'CHANGES_REQUESTED') {
      return { state: 'failure', detail: 'Resolve CodeRabbit change requests.' };
    }
    return { state: 'pending', detail: `CodeRabbit review state: ${review.state}.` };
  }

  const status = statuses
    .filter((item) => {
      if (String(item.context ?? '').toLowerCase() !== 'coderabbit') return false;
      const creator = item.creator?.login;
      // CodeRabbit's current commit statuses use a null creator. Reject an
      // explicitly foreign creator while retaining compatibility with that output.
      return (
        !creator || CODERABBIT_REVIEWERS.has(String(creator).toLowerCase())
      );
    })
    .sort((left, right) =>
      String(right.updated_at ?? right.created_at ?? '').localeCompare(
        String(left.updated_at ?? left.created_at ?? ''),
      ),
    )[0];
  if (
    status?.state === 'success' &&
    /^review completed$/i.test(String(status.description ?? '').trim())
  ) {
    return {
      state: 'success',
      detail: 'CodeRabbit completed the latest review with no change request.',
    };
  }
  if (status?.state === 'failure' || status?.state === 'error') {
    return { state: 'failure', detail: 'Resolve CodeRabbit check failures.' };
  }
  return { state: 'pending', detail: 'Waiting for CodeRabbit review on the latest commit.' };
}

async function ciGate(repo, commitSha) {
  if (!commitSha) {
    return { state: 'failure', detail: 'The PR has no testable head commit.' };
  }

  const result = await request(
    `/repos/${repo}/commits/${commitSha}/check-runs?filter=latest&per_page=100`,
  );
  const requiredJobs = ['repository', 'mobile', 'bridge', 'functions'];
  const checks = new Map(result.check_runs?.map((check) => [check.name, check]) ?? []);
  const missing = requiredJobs.filter((name) => !checks.has(name));
  if (missing.length > 0) {
    return {
      state: 'pending',
      detail: `Waiting for Test jobs: ${missing.join(', ')}.`,
    };
  }

  const pending = requiredJobs.filter((name) => checks.get(name).status !== 'completed');
  if (pending.length > 0) {
    return { state: 'pending', detail: `Test jobs still running: ${pending.join(', ')}.` };
  }

  const failed = requiredJobs.filter((name) => checks.get(name).conclusion !== 'success');
  if (failed.length > 0) {
    return { state: 'failure', detail: `Test jobs failed: ${failed.join(', ')}.` };
  }
  return { state: 'success', detail: 'All Test workflow jobs passed.' };
}

function gateIcon(state) {
  if (state === 'success') return '✅';
  if (state === 'failure') return '❌';
  if (state === 'skipped') return '➖';
  return '⏳';
}

export function shouldEvaluateCi({ oversized, override }) {
  return !oversized || override;
}

export function ciCheckSha(pr) {
  return pr.head?.sha ?? null;
}

export function deferredCodeRabbitGate({ draft, oversized, intakePassed, override }) {
  if (draft) {
    return { state: 'pending', detail: 'Not requested while the PR is a draft.' };
  }
  if (override) {
    return { state: 'skipped', detail: 'Skipped by maintainer override.' };
  }
  if (oversized) {
    return { state: 'skipped', detail: 'Not requested for an oversized PR.' };
  }
  if (!intakePassed) {
    return { state: 'pending', detail: 'Not requested until intake passes.' };
  }
  return { state: 'pending', detail: 'Not requested.' };
}

export function isCodeRabbitReviewEligible({
  draft,
  oversized,
  intakePassed,
  override,
}) {
  return !draft && !override && !oversized && intakePassed;
}

function readinessComment({ intake, ci, coderabbit, draft, override, fileCount }) {
  const intakeState = intake.errors.length === 0 ? 'success' : 'failure';
  const actionItems = [...intake.errors];
  if (ci.state === 'failure') actionItems.push(ci.detail);
  if (coderabbit.state === 'failure') actionItems.push(coderabbit.detail);

  const lines = [
    '<!-- ccpocket-pr-readiness -->',
    '## PR Readiness',
    '',
    '| Gate | Status |',
    '| --- | --- |',
    `| Intake (${fileCount} files) | ${gateIcon(intakeState)} ${intakeState} |`,
    `| CI | ${gateIcon(ci.state)} ${ci.detail} |`,
    `| CodeRabbit | ${gateIcon(coderabbit.state)} ${coderabbit.detail} |`,
    `| Draft | ${draft ? '⏳ Draft' : '✅ Ready'} |`,
  ];

  if (override) lines.push('| Maintainer override | ✅ Applied |');
  if (actionItems.length > 0) {
    lines.push('', '### Action required', '', ...actionItems.map((item) => `- ${item}`));
  }
  if (intake.warnings.length > 0) {
    lines.push('', '### Notes', '', ...intake.warnings.map((item) => `- ${item}`));
  }
  lines.push(
    '',
    'Maintainer review starts only after every gate passes. This comment updates automatically.',
  );
  return lines.join('\n');
}

async function upsertReadinessComment(repo, number, body) {
  const comments = await paginate(`/repos/${repo}/issues/${number}/comments`);
  const existing = comments.find(
    (comment) =>
      comment.user?.login === 'github-actions[bot]' &&
      String(comment.body ?? '').includes('<!-- ccpocket-pr-readiness -->'),
  );
  if (existing?.body === body) return;
  if (existing) {
    await request(`/repos/${repo}/issues/comments/${existing.id}`, {
      method: 'PATCH',
      body: { body },
    });
    return;
  }
  await request(`/repos/${repo}/issues/${number}/comments`, {
    method: 'POST',
    body: { body },
  });
}

async function setReadinessStatus(repo, sha, state, description, targetUrl) {
  const normalizedDescription = description.slice(0, 140);
  const combinedStatus = await request(`/repos/${repo}/commits/${sha}/status`);
  const current = combinedStatus.statuses?.find(
    (status) => status.context === 'PR Readiness',
  );
  if (
    current?.state === state &&
    current.description === normalizedDescription &&
    current.target_url === targetUrl
  ) {
    return;
  }

  await request(`/repos/${repo}/statuses/${sha}`, {
    method: 'POST',
    body: {
      state,
      context: 'PR Readiness',
      description: normalizedDescription,
      target_url: targetUrl,
    },
  });
}

async function syncMaintainerReviewRequest({ repo, pr, reviews, ready, maintainer }) {
  if (!maintainer || pr.user.login === maintainer) return;
  const requested = pr.requested_reviewers.some((reviewer) => reviewer.login === maintainer);
  const alreadyReviewed = reviews.some(
    (review) => review.user?.login === maintainer && review.commit_id === pr.head.sha,
  );

  if (ready && !requested && !alreadyReviewed) {
    await request(`/repos/${repo}/pulls/${pr.number}/requested_reviewers`, {
      method: 'POST',
      body: { reviewers: [maintainer] },
    });
  } else if (!ready && requested) {
    await request(`/repos/${repo}/pulls/${pr.number}/requested_reviewers`, {
      method: 'DELETE',
      body: { reviewers: [maintainer] },
    });
  }
}

function pullRequestNumber(payload) {
  return payload.pull_request?.number ?? payload.workflow_run?.pull_requests?.[0]?.number;
}

async function evaluatePullRequest({ repo, number, maintainer }) {
  const pr = await request(`/repos/${repo}/pulls/${number}`);
  if (pr.state !== 'open') {
    console.log(`PR #${number} is not open.`);
    return;
  }

  const currentLabels = pr.labels.map((label) => label.name);
  const override = currentLabels.includes('review:override');
  const files =
    pr.changed_files > MAX_REVIEW_FILES && !override
      ? []
      : await paginate(`/repos/${repo}/pulls/${number}/files`);
  const paths = files.map((file) => file.filename);
  const intake = evaluateIntake({
    body: pr.body ?? '',
    files: paths,
    fileCount: pr.changed_files,
    draft: pr.draft,
  });
  if (
    requiresReviewPolicyOverride({
      files: paths,
      author: pr.user.login,
      maintainer,
      override,
    })
  ) {
    intake.errors.push(
      'External changes to review-policy files require a maintainer-authored PR or the review:override label.',
    );
  }

  const reviews = await paginate(`/repos/${repo}/pulls/${number}/reviews`);
  const intakePassed = intake.errors.length === 0;
  const reviewEligible = isCodeRabbitReviewEligible({
    draft: pr.draft,
    oversized: intake.oversized,
    intakePassed,
    override,
  });
  const ci = shouldEvaluateCi({ oversized: intake.oversized, override })
    ? await ciGate(repo, ciCheckSha(pr))
    : { state: 'skipped', detail: 'Not run for an oversized PR.' };
  const commitStatuses = reviewEligible
    ? await paginate(`/repos/${repo}/commits/${pr.head.sha}/statuses`)
    : [];
  const coderabbit = reviewEligible
    ? codeRabbitGate(reviews, commitStatuses, pr.head.sha)
    : deferredCodeRabbitGate({
        draft: pr.draft,
        oversized: intake.oversized,
        intakePassed,
        override,
      });
  const ready =
    !pr.draft &&
    (override ||
      (intakePassed && ci.state === 'success' && coderabbit.state === 'success'));

  const desiredLabels = [intake.size];
  if (intake.highRisk) desiredLabels.push('risk:high');
  if (reviewEligible) desiredLabels.push('review:coderabbit');
  if (ready) desiredLabels.push('ready-for-maintainer-review');
  if (
    !pr.draft &&
    !override &&
    ((!intake.oversized && intake.errors.length > 0) ||
      ci.state === 'failure' ||
      coderabbit.state === 'failure')
  ) {
    desiredLabels.push('status:needs-author');
  }
  if (intake.oversized && !override) desiredLabels.push('status:needs-split');
  await syncLabels(repo, number, currentLabels, desiredLabels);

  const comment = readinessComment({
    intake,
    ci,
    coderabbit,
    draft: pr.draft,
    override,
    fileCount: pr.changed_files,
  });
  await upsertReadinessComment(repo, number, comment);

  let statusState = 'pending';
  let statusDescription = 'Waiting for CI and CodeRabbit approval';
  if (ready) {
    statusState = 'success';
    statusDescription = override
      ? 'Ready by maintainer override'
      : 'Ready for maintainer review';
  } else if (
    intake.errors.length > 0 ||
    ci.state === 'failure' ||
    coderabbit.state === 'failure'
  ) {
    statusState = 'failure';
    statusDescription = intake.oversized
      ? `Split this PR: ${pr.changed_files} files exceeds the ${MAX_REVIEW_FILES}-file limit`
      : 'Author action is required before review';
  } else if (pr.draft) {
    statusDescription = 'Draft PRs are not ready for review';
  }
  await setReadinessStatus(repo, pr.head.sha, statusState, statusDescription, pr.html_url);
  await syncMaintainerReviewRequest({ repo, pr, reviews, ready, maintainer });

  if (intake.oversized && !override) {
    await request(`/repos/${repo}/pulls/${number}`, {
      method: 'PATCH',
      body: { state: 'closed' },
    });
    console.log(`Closed PR #${number}: ${pr.changed_files} files exceeds the limit.`);
    return;
  }

  console.log(
    `PR #${number}: intake=${intakePassed}, ci=${ci.state}, coderabbit=${coderabbit.state}, ready=${ready}`,
  );
}

export async function main() {
  const payload = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const repo = process.env.GITHUB_REPOSITORY;
  const maintainer = process.env.MAINTAINER_LOGIN;
  if (!repo) throw new Error('GITHUB_REPOSITORY is required.');
  await ensureRepositoryLabels(repo);

  const number = pullRequestNumber(payload);
  if (number) {
    await evaluatePullRequest({ repo, number, maintainer });
    return;
  }

  // Scheduled/manual runs detect CodeRabbit review changes without relying on
  // the read-only pull_request_review token used for external fork PRs.
  const openPullRequests = await paginate(`/repos/${repo}/pulls?state=open`);
  const reviewCandidates =
    process.env.GITHUB_EVENT_NAME === 'schedule'
      ? openPullRequests.filter((pullRequest) => {
          const labels = new Set(pullRequest.labels.map((label) => label.name));
          const hasSizeLabel = MANAGED_LABELS.some(
            (label) => label.startsWith('size:') && labels.has(label),
          );
          return labels.has('review:coderabbit') || !hasSizeLabel;
        })
      : openPullRequests;
  const failures = [];
  for (const pullRequest of reviewCandidates) {
    try {
      await evaluatePullRequest({ repo, number: pullRequest.number, maintainer });
    } catch (error) {
      failures.push(`#${pullRequest.number}: ${error.message}`);
      console.error(`Failed to evaluate PR #${pullRequest.number}:`, error);
    }
  }

  if (failures.length > 0) {
    throw new Error(`Failed to evaluate ${failures.length} PR(s): ${failures.join('; ')}`);
  }
}

const isDirectExecution =
  process.argv[1] && fileURLToPath(import.meta.url) === fs.realpathSync(process.argv[1]);
if (isDirectExecution) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
