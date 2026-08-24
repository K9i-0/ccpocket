import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { extname, join } from "node:path";
import { rm, writeFile } from "node:fs/promises";

export interface InputFileAttachment {
  base64: string;
  mimeType: string;
  name: string;
}

export interface MaterializedInputFile {
  name: string;
  path: string;
}

export const MAX_INPUT_FILE_COUNT = 5;
export const MAX_INPUT_FILE_BYTES = 10 * 1024 * 1024;
export const MAX_INPUT_FILES_TOTAL_BYTES = 20 * 1024 * 1024;

function safeFileName(name: string): string {
  const normalized = name
    .replace(/[\\/\u0000-\u001f\u007f]/g, "_")
    .trim()
    .slice(0, 120);
  return normalized || "attachment";
}

function safeExtension(name: string): string {
  const extension = extname(name).toLowerCase();
  return /^\.[a-z0-9]{1,12}$/.test(extension) ? extension : "";
}

function decodeAttachment(file: InputFileAttachment): Buffer {
  const maxEncodedLength = Math.ceil(MAX_INPUT_FILE_BYTES / 3) * 4 + 4;
  if (file.base64.length > maxEncodedLength) {
    throw new Error(`File "${safeFileName(file.name)}" exceeds 10 MB.`);
  }
  if (
    file.base64.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(file.base64)
  ) {
    throw new Error(`File "${safeFileName(file.name)}" has invalid data.`);
  }
  const bytes = Buffer.from(file.base64, "base64");
  if (bytes.length > MAX_INPUT_FILE_BYTES) {
    throw new Error(`File "${safeFileName(file.name)}" exceeds 10 MB.`);
  }
  return bytes;
}

export async function materializeInputFiles(
  files: InputFileAttachment[],
): Promise<MaterializedInputFile[]> {
  if (files.length > MAX_INPUT_FILE_COUNT) {
    throw new Error(`A maximum of ${MAX_INPUT_FILE_COUNT} files can be attached.`);
  }

  const decoded = files.map((file) => ({
    name: safeFileName(file.name),
    bytes: decodeAttachment(file),
  }));
  const totalBytes = decoded.reduce((total, file) => total + file.bytes.length, 0);
  if (totalBytes > MAX_INPUT_FILES_TOTAL_BYTES) {
    throw new Error("Attached files exceed the 20 MB total limit.");
  }

  const materialized: MaterializedInputFile[] = [];
  try {
    for (const file of decoded) {
      const path = join(
        tmpdir(),
        `ccpocket-attachment-${randomUUID()}${safeExtension(file.name)}`,
      );
      await writeFile(path, file.bytes, { mode: 0o600 });
      materialized.push({ name: file.name, path });
    }
    return materialized;
  } catch (error) {
    await removeInputAttachmentFiles(materialized.map((file) => file.path));
    throw error;
  }
}

export function appendInputAttachmentContext(
  text: string,
  files: MaterializedInputFile[],
): string {
  if (files.length === 0) return text;
  const context = [
    "The user attached these local files for this turn. Read them from the paths below when needed:",
    ...files.map(
      (file) => `- ${JSON.stringify(file.name)}: ${JSON.stringify(file.path)}`,
    ),
  ].join("\n");
  return `${context}\n\n${text}`;
}

export async function removeInputAttachmentFiles(
  paths: Iterable<string>,
): Promise<void> {
  await Promise.all(
    Array.from(paths, (path) => rm(path, { force: true }).catch(() => {})),
  );
}
