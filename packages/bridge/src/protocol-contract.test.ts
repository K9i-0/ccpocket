import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parseClientMessage } from "./parser.js";
import {
  clientProtocolRange,
  negotiateProtocolVersion,
} from "./protocol-version.js";

function fixture(name: string): string {
  return readFileSync(
    new URL(`../../../test/fixtures/protocol/v1/${name}.json`, import.meta.url),
    "utf8",
  );
}

describe("protocol v1 contract fixtures", () => {
  it.each(["legacy-client-capabilities", "current-client-capabilities"])(
    "accepts %s",
    (name) => {
      const message = parseClientMessage(fixture(name));
      expect(message?.type).toBe("client_capabilities");
      if (message?.type !== "client_capabilities") return;

      expect(
        negotiateProtocolVersion(clientProtocolRange(message)),
      ).toBe(1);
    },
  );

  it.each(["legacy-session-list", "current-session-list"])(
    "keeps %s as a frozen server fixture",
    (name) => {
      const message = JSON.parse(fixture(name)) as Record<string, unknown>;
      expect(message.type).toBe("session_list");
      expect(message.sessions).toEqual([]);
    },
  );
});
