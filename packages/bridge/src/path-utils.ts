import { posix, win32 } from "node:path";

function getPathApi(platform: NodeJS.Platform) {
  return platform === "win32" ? win32 : posix;
}

export function stripWindowsExtendedPathPrefix(input: string): string {
  if (!input.startsWith("\\\\?\\")) return input;

  if (input.startsWith("\\\\?\\UNC\\")) {
    return `\\\\${input.slice("\\\\?\\UNC\\".length)}`;
  }

  const trimmed = input.slice("\\\\?\\".length);
  return /^[A-Za-z]:[\\/]/.test(trimmed) ? trimmed : input;
}

export function normalizePlatformPath(
  input: string,
  platform: NodeJS.Platform = process.platform,
): string {
  const pathApi = getPathApi(platform);
  const value =
    platform === "win32" ? stripWindowsExtendedPathPrefix(input) : input;
  return pathApi.normalize(value);
}

export function resolvePlatformPath(
  input: string,
  platform: NodeJS.Platform = process.platform,
): string {
  const pathApi = getPathApi(platform);
  return pathApi.resolve(normalizePlatformPath(input, platform));
}

export function resolvePlatformPathFrom(
  basePath: string,
  input: string,
  platform: NodeJS.Platform = process.platform,
): string {
  const pathApi = getPathApi(platform);
  const normalizedInput = normalizePlatformPath(input, platform);
  if (pathApi.isAbsolute(normalizedInput)) {
    return pathApi.resolve(normalizedInput);
  }
  return pathApi.resolve(
    resolvePlatformPath(basePath, platform),
    normalizedInput,
  );
}

export function isPathWithinAllowedDirectory(
  targetPath: string,
  allowedDir: string,
  platform: NodeJS.Platform = process.platform,
): boolean {
  const pathApi = getPathApi(platform);
  const resolvedTarget = resolvePlatformPath(targetPath, platform);
  const resolvedAllowedDir = resolvePlatformPath(allowedDir, platform);

  if (resolvedTarget === resolvedAllowedDir) return true;

  const relativePath = pathApi.relative(resolvedAllowedDir, resolvedTarget);
  return (
    relativePath !== "" &&
    !relativePath.startsWith("..") &&
    !pathApi.isAbsolute(relativePath)
  );
}
