import { readFile, writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

export interface BackupMeta {
  appVersion: string;
  dbVersion: number;
  backedUpAt: string;
  sizeBytes: number;
}

const BACKUP_DIR = join(homedir(), ".ccpocket", "prompt-history-backup");
const BACKUP_FILE = join(BACKUP_DIR, "backup.db");
const META_FILE = join(BACKUP_DIR, "meta.json");

export class PromptHistoryBackupStore {
  async init(): Promise<void> {
    await mkdir(BACKUP_DIR, { recursive: true });
  }

  async save(data: Buffer, appVersion: string, dbVersion: number): Promise<BackupMeta> {
    await mkdir(BACKUP_DIR, { recursive: true });
    await writeFile(BACKUP_FILE, data);
    const meta: BackupMeta = {
      appVersion,
      dbVersion,
      backedUpAt: new Date().toISOString(),
      sizeBytes: data.length,
    };
    await writeFile(META_FILE, JSON.stringify(meta, null, 2), "utf-8");
    return meta;
  }

  async load(): Promise<{ data: Buffer; meta: BackupMeta } | null> {
    try {
      const [data, metaRaw] = await Promise.all([
        readFile(BACKUP_FILE),
        readFile(META_FILE, "utf-8"),
      ]);
      const meta = JSON.parse(metaRaw) as BackupMeta;
      return { data, meta };
    } catch {
      return null;
    }
  }

  async getMeta(): Promise<BackupMeta | null> {
    try {
      const metaRaw = await readFile(META_FILE, "utf-8");
      return JSON.parse(metaRaw) as BackupMeta;
    } catch {
      return null;
    }
  }
}
