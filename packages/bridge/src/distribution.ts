export const BRIDGE_STABLE_MAJOR = 1;
export const BRIDGE_STABLE_PACKAGE_SPEC =
  `@ccpocket/bridge@${BRIDGE_STABLE_MAJOR}`;
export const BRIDGE_STABLE_SETUP_COMMAND =
  `npx --yes ${BRIDGE_STABLE_PACKAGE_SPEC} setup`;

export function usesUnboundedBridgeLatest(contents: string): boolean {
  return /@ccpocket\/bridge@latest(?:\s|['"<]|$)/.test(contents);
}
