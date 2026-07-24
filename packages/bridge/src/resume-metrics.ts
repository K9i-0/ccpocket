import type { Provider } from "./parser.js";
import type { SessionHistoryMessage } from "./sessions-index.js";

export interface ResumeHistoryMetrics {
  messageCount: number;
  imageCount: number;
  inlineImageCount: number;
  imagePathCount: number;
  inlineImageBytes: number;
}

export interface ResumePerformanceMetrics extends ResumeHistoryMetrics {
  provider: Provider;
  sourceSessionId: string;
  outcome: "success" | "failed";
  historyLoadMs: number;
  sessionCreateMs: number;
  nameLoadMs: number;
  totalMs: number;
}

function estimatedBase64Bytes(value: string): number {
  if (value.length === 0) return 0;
  const padding = value.endsWith("==")
    ? 2
    : value.endsWith("=")
      ? 1
      : 0;
  // Persisted image payloads are normalized base64. Use length only so metrics
  // do not duplicate multi-megabyte strings during an already-heavy restore.
  return Math.max(0, Math.floor((value.length * 3) / 4) - padding);
}

export function summarizeResumeHistory(
  history: SessionHistoryMessage[],
): ResumeHistoryMetrics {
  let imageCount = 0;
  let inlineImageCount = 0;
  let imagePathCount = 0;
  let inlineImageBytes = 0;

  for (const message of history) {
    const inlineImages = message.imageBase64 ?? [];
    const imagePaths = message.imagePaths ?? [];
    inlineImageCount += inlineImages.length;
    imagePathCount += imagePaths.length;
    for (const image of inlineImages) {
      inlineImageBytes += estimatedBase64Bytes(image.data);
    }

    const explicitImageCount = inlineImages.length + imagePaths.length;
    const hintedImageCount =
      typeof message.imageCount === "number" &&
      Number.isFinite(message.imageCount)
        ? Math.max(0, Math.floor(message.imageCount))
        : 0;
    imageCount += Math.max(explicitImageCount, hintedImageCount);
  }

  return {
    messageCount: history.length,
    imageCount,
    inlineImageCount,
    imagePathCount,
    inlineImageBytes,
  };
}

export function formatResumePerformanceLog(
  metrics: ResumePerformanceMetrics,
): string {
  return [
    "[ws][resume-perf]",
    `provider=${metrics.provider}`,
    `sourceSessionId=${metrics.sourceSessionId}`,
    `outcome=${metrics.outcome}`,
    `messages=${metrics.messageCount}`,
    `images=${metrics.imageCount}`,
    `inlineImages=${metrics.inlineImageCount}`,
    `imagePaths=${metrics.imagePathCount}`,
    `inlineImageBytes=${metrics.inlineImageBytes}`,
    `historyMs=${Math.round(metrics.historyLoadMs)}`,
    `createMs=${Math.round(metrics.sessionCreateMs)}`,
    `nameMs=${Math.round(metrics.nameLoadMs)}`,
    `totalMs=${Math.round(metrics.totalMs)}`,
  ].join(" ");
}
