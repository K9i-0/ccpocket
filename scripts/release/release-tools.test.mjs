import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  monitorRuns,
  parseArgs,
  releaseTargets,
  summarizeRuns,
} from './monitor.mjs';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const checksScript = path.join(scriptDirectory, 'run-checks.sh');

function runInfo(overrides = {}) {
  return {
    databaseId: 101,
    headBranch: 'windows/v1.2.3+4',
    headSha: 'abc1234',
    status: 'in_progress',
    conclusion: '',
    workflowName: 'Windows Release',
    url: 'https://example.test/runs/101',
    createdAt: '2026-08-29T00:00:00Z',
    ...overrides,
  };
}

test('parses monitor options and creates release targets', () => {
  assert.deepEqual(
    parseArgs([
      'release',
      '--version',
      '1.2.3+4',
      '--platforms',
      'ios,windows',
      '--poll-ms',
      '5',
    ]),
    {
      phase: 'release',
      version: '1.2.3+4',
      platforms: 'ios,windows',
      pollMs: 5,
    },
  );
  assert.deepEqual(releaseTargets('1.2.3+4', 'ios,windows'), [
    {
      key: 'ios',
      branch: 'ios/v1.2.3+4',
      workflow: 'iOS Release (Shorebird)',
    },
    {
      key: 'windows',
      branch: 'windows/v1.2.3+4',
      workflow: 'Windows Release',
    },
  ]);
  assert.throws(
    () => releaseTargets('1.2.3', 'ios'),
    /X\.Y\.Z\+N format/,
  );
  assert.throws(
    () => releaseTargets('1.2.3+4', 'ios,ios'),
    /duplicates/,
  );
});

test('summarizes only the newest exact tag and SHA run', () => {
  const targets = releaseTargets('1.2.3+4', 'windows');
  const summary = summarizeRuns(targets, 'abc1234', [
    runInfo({
      databaseId: 102,
      status: 'completed',
      conclusion: 'failure',
      createdAt: '2026-08-29T00:02:00Z',
      headSha: 'wrong-sha',
    }),
    runInfo({
      databaseId: 103,
      workflowName: 'Unrelated Workflow',
      status: 'completed',
      conclusion: 'success',
      createdAt: '2026-08-29T00:03:00Z',
    }),
    runInfo({ databaseId: 100, createdAt: '2026-08-29T00:00:00Z' }),
    runInfo({
      databaseId: 101,
      status: 'completed',
      conclusion: 'success',
      createdAt: '2026-08-29T00:01:00Z',
    }),
  ]);
  assert.equal(summary.items[0].run.databaseId, 101);
  assert.equal(summary.items[0].state, 'success');
  assert.equal(summary.counts.success, 1);
});

test('prints only status transitions and the terminal success', async () => {
  const target = releaseTargets('1.2.3+4', 'windows');
  const sequences = [
    [],
    [],
    [runInfo()],
    [runInfo()],
    [runInfo({ status: 'completed', conclusion: 'success' })],
  ];
  const output = [];
  let clock = 0;
  const result = await monitorRuns({
    phase: 'release',
    targets: target,
    sha: 'abc1234',
    fetchRuns: async () => {
      clock += 1_000;
      return sequences.shift();
    },
    fetchFailure: async () => ({}),
    sleep: async () => {},
    now: () => clock,
    write: (line) => output.push(line),
    discoveryPollMs: 1,
    pollMs: 1,
    slowPollMs: 1,
    slowAfterMs: 10_000,
    heartbeatMs: 10_000,
    timeoutMs: 60_000,
  });
  assert.equal(result.ok, true);
  assert.equal(output.length, 3);
  assert.match(output[0], /^RELEASE waiting /);
  assert.match(output[1], /^RELEASE running /);
  assert.match(output[2], /^RELEASE success /);
});

test('reports compact failure details without dumping logs', async () => {
  const output = [];
  const result = await monitorRuns({
    phase: 'preflight',
    targets: [{ key: 'test', branch: 'main', workflow: 'Test' }],
    sha: 'abc1234',
    fetchRuns: async () => [
      runInfo({
        headBranch: 'main',
        workflowName: 'Test',
        status: 'completed',
        conclusion: 'failure',
      }),
    ],
    fetchFailure: async () => ({
      jobNames: ['mobile-windows'],
      stepNames: ['Run Flutter tests on Windows'],
      logPath: '/tmp/ccpocket-release-101.log',
    }),
    sleep: async () => {},
    now: () => 0,
    write: (line) => output.push(line),
    discoveryPollMs: 1,
    pollMs: 1,
    slowPollMs: 1,
    slowAfterMs: 1,
    heartbeatMs: 1,
    timeoutMs: 100,
  });
  assert.equal(result.ok, false);
  assert.equal(output.length, 1);
  assert.match(output[0], /target=test/);
  assert.match(output[0], /jobs=mobile-windows/);
  assert.match(output[0], /steps=Run Flutter tests on Windows/);
  assert.match(output[0], /log=\/tmp\/ccpocket-release-101\.log/);
});

test('stops quickly when a workflow never starts', async () => {
  const output = [];
  let clock = 0;
  const result = await monitorRuns({
    phase: 'release',
    targets: releaseTargets('1.2.3+4', 'ios,windows'),
    sha: 'abc1234',
    fetchRuns: async () => {
      clock += 1_000;
      return [];
    },
    sleep: async () => {},
    now: () => clock,
    write: (line) => output.push(line),
    discoveryPollMs: 1,
    discoveryTimeoutMs: 2_500,
    pollMs: 1,
    slowPollMs: 1,
    slowAfterMs: 1,
    heartbeatMs: 10_000,
    timeoutMs: 60_000,
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'discovery-timeout');
  assert.match(output.at(-1), /^RELEASE discovery-timeout /);
});

test('times out a stuck gh process and uses bounded retries', () => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'release-monitor-timeout.'),
  );
  const binDirectory = path.join(directory, 'bin');
  fs.mkdirSync(binDirectory);
  writeExecutable(
    path.join(binDirectory, 'gh'),
    '#!/usr/bin/env bash\nsleep 2\n',
  );
  try {
    const sha = spawnSync('git', ['rev-parse', 'HEAD'], {
      encoding: 'utf8',
    }).stdout.trim();
    const result = spawnSync(
      process.execPath,
      [
        path.join(scriptDirectory, 'monitor.mjs'),
        'preflight',
        '--sha',
        sha,
        '--discovery-poll-ms',
        '1',
      ],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          PATH: `${binDirectory}:${process.env.PATH}`,
          CCPOCKET_RELEASE_COMMAND_TIMEOUT_MS: '20',
        },
        timeout: 2_000,
      },
    );
    assert.equal(result.status, 1);
    assert.match(result.stdout, /PREFLIGHT gh-error attempt=1\/3/);
    assert.match(result.stdout, /PREFLIGHT gh-error attempt=3\/3/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

function writeExecutable(filePath, source) {
  fs.writeFileSync(filePath, source, { mode: 0o755 });
}

function checksEnvironment({ flutterSource }) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'release-tools-test.'));
  const binDirectory = path.join(directory, 'bin');
  fs.mkdirSync(binDirectory);
  writeExecutable(
    path.join(binDirectory, 'dart'),
    '#!/usr/bin/env bash\nprintf "45 issues found.\\n"\n',
  );
  writeExecutable(path.join(binDirectory, 'flutter'), flutterSource);
  return {
    directory,
    env: { ...process.env, PATH: `${binDirectory}:${process.env.PATH}` },
  };
}

test('run-checks prints three compact lines on success', () => {
  const fixture = checksEnvironment({
    flutterSource:
      '#!/usr/bin/env bash\nprintf "00:01 +1713 ~4: All tests passed!\\n"\n',
  });
  try {
    const result = spawnSync('bash', [checksScript], {
      encoding: 'utf8',
      env: fixture.env,
    });
    assert.equal(result.status, 0, result.stderr);
    const lines = result.stdout.trim().split('\n');
    assert.equal(lines[0], 'ANALYZE success issues=45');
    assert.match(
      lines[1],
      /^TEST success passed=1713 skipped=4 duration=\d+s$/,
    );
    assert.match(lines[2], /^CHECKS success duration=\d+s$/);
  } finally {
    fs.rmSync(fixture.directory, { recursive: true, force: true });
  }
});

test('run-checks keeps the full failure log and prints a bounded tail', () => {
  const fixture = checksEnvironment({
    flutterSource:
      '#!/usr/bin/env bash\nprintf "progress\\rEXCEPTION\\rExpected true\\r" >&2\nexit 1\n',
  });
  let retainedLogDirectory = '';
  try {
    const result = spawnSync('bash', [checksScript], {
      encoding: 'utf8',
      env: fixture.env,
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /TEST failed log=/);
    assert.match(result.stderr, /EXCEPTION/);
    assert.match(result.stderr, /Expected true/);
    const logPath = result.stderr.match(/TEST failed log=(.+)/)?.[1].trim();
    assert.ok(logPath);
    assert.equal(fs.existsSync(logPath), true);
    retainedLogDirectory = path.dirname(logPath);
  } finally {
    fs.rmSync(fixture.directory, { recursive: true, force: true });
    if (retainedLogDirectory) {
      fs.rmSync(retainedLogDirectory, { recursive: true, force: true });
    }
  }
});
