import { readFile, stat } from "node:fs/promises";
import { describe, expect, it } from "vitest";
import {
  appendInputAttachmentContext,
  materializeInputFiles,
  removeInputAttachmentFiles,
} from "./input-attachments.js";

describe("input attachments", () => {
  it("materializes sanitized files and adds readable paths to agent input", async () => {
    const files = await materializeInputFiles([
      {
        name: "../synthetic-notes.txt",
        mimeType: "text/plain",
        base64: Buffer.from("synthetic attachment").toString("base64"),
      },
    ]);
    try {
      expect(files).toHaveLength(1);
      expect(files[0].name).toBe(".._synthetic-notes.txt");
      expect(await readFile(files[0].path, "utf8")).toBe(
        "synthetic attachment",
      );

      const input = appendInputAttachmentContext("Review it", files);
      expect(input).toContain('".._synthetic-notes.txt"');
      expect(input).toContain(JSON.stringify(files[0].path));
      expect(input.endsWith("Review it")).toBe(true);
    } finally {
      await removeInputAttachmentFiles(files.map((file) => file.path));
    }
  });

  it("rejects invalid Base64 and enforces the file-count limit", async () => {
    await expect(
      materializeInputFiles([
        { name: "bad.bin", mimeType: "application/octet-stream", base64: "!" },
      ]),
    ).rejects.toThrow("invalid data");

    await expect(
      materializeInputFiles(
        Array.from({ length: 6 }, (_, index) => ({
          name: `file-${index}.txt`,
          mimeType: "text/plain",
          base64: "",
        })),
      ),
    ).rejects.toThrow("maximum of 5 files");
  });

  it("removes materialized files", async () => {
    const files = await materializeInputFiles([
      { name: "temporary.txt", mimeType: "text/plain", base64: "" },
    ]);
    await removeInputAttachmentFiles(files.map((file) => file.path));
    await expect(stat(files[0].path)).rejects.toMatchObject({ code: "ENOENT" });
  });
});
