import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Text } from "@earendil-works/pi-tui";
import { execFile } from "node:child_process";
import { existsSync, statSync, readdirSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { resolve, extname, basename, join, dirname } from "node:path";

// ── Constants ────────────────────────────────────────────────────────

const API_BASE = "https://generativelanguage.googleapis.com/v1beta";
const UPLOAD_BASE = "https://generativelanguage.googleapis.com/upload/v1beta";
const DEFAULT_MODEL = "gemini-3-flash-preview";
const DEFAULT_MAX_SIZE_MB = 50;
const DEFAULT_RANGE_FRAMES = 6;
const MIN_FRAME_INTERVAL = 5;

const YOUTUBE_REGEX =
  /(?:(?:www\.|m\.)?youtube\.com\/(?:watch\?.*v=|shorts\/|live\/|embed\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/;

const VIDEO_EXTENSIONS: Record<string, string> = {
  ".mp4": "video/mp4",
  ".mov": "video/quicktime",
  ".webm": "video/webm",
  ".avi": "video/x-msvideo",
  ".mpeg": "video/mpeg",
  ".mpg": "video/mpeg",
  ".wmv": "video/x-ms-wmv",
  ".flv": "video/x-flv",
  ".3gp": "video/3gpp",
  ".3gpp": "video/3gpp",
};

const YOUTUBE_PROMPT = `Extract the complete content of this YouTube video. Include:
1. Video title, channel name, and duration
2. A brief summary (2-3 sentences)
3. Full transcript with timestamps
4. Descriptions of any code, terminal commands, diagrams, slides, or UI shown on screen

Format as markdown.`;

const VIDEO_PROMPT = `Extract the complete content of this video. Include:
1. Video title (infer from content if not explicit), duration
2. A brief summary (2-3 sentences)
3. Full transcript with timestamps
4. Descriptions of any code, terminal commands, diagrams, slides, or UI shown on screen

Format as markdown.`;

// ── Types ────────────────────────────────────────────────────────────

interface VideoFrame {
  data: string;
  mimeType: string;
  timestamp: string;
}

interface FrameResult {
  data?: string;
  mimeType?: string;
  error?: string;
}

interface ExtractedContent {
  url: string;
  title: string;
  content: string;
  error: string | null;
  thumbnail?: { data: string; mimeType: string };
  frames?: VideoFrame[];
  duration?: number;
}

interface VideoFileInfo {
  absolutePath: string;
  mimeType: string;
  sizeBytes: number;
}

// ── Utilities ────────────────────────────────────────────────────────

function formatSeconds(s: number): string {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
  return `${m}:${String(sec).padStart(2, "0")}`;
}

function errorMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

function readExecError(err: unknown): {
  code?: string;
  stderr: string;
  message: string;
} {
  if (!err || typeof err !== "object") return { stderr: "", message: String(err) };
  const code = (err as { code?: string }).code;
  const message = (err as { message?: string }).message ?? "";
  const stderrRaw = (err as { stderr?: Buffer | string }).stderr;
  const stderr = Buffer.isBuffer(stderrRaw)
    ? stderrRaw.toString("utf-8")
    : typeof stderrRaw === "string"
      ? stderrRaw
      : "";
  return { code, stderr, message };
}

function isTimeoutError(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  if ((err as { killed?: boolean }).killed) return true;
  const name = (err as { name?: string }).name;
  const code = (err as { code?: string }).code;
  const message = (err as { message?: string }).message ?? "";
  return (
    name === "AbortError" || code === "ETIMEDOUT" || message.toLowerCase().includes("timed out")
  );
}

function trimErrorText(text: string): string {
  return text.replace(/\s+/g, " ").trim().slice(0, 200);
}

function mapFfmpegError(err: unknown): string {
  const { code, stderr, message } = readExecError(err);
  if (code === "ENOENT") return "ffmpeg is not installed. Install with: brew install ffmpeg";
  if (isTimeoutError(err)) return "ffmpeg timed out extracting frame";
  if (stderr.includes("403")) return "Stream URL returned 403 — may have expired, try again";
  const snippet = trimErrorText(stderr || message);
  return snippet ? `ffmpeg failed: ${snippet}` : "ffmpeg failed";
}

function mapYtDlpError(err: unknown): string {
  const { code, stderr, message } = readExecError(err);
  if (code === "ENOENT") return "yt-dlp is not installed. Install with: brew install yt-dlp";
  if (isTimeoutError(err)) return "yt-dlp timed out fetching video info";
  const lower = stderr.toLowerCase();
  if (lower.includes("private")) return "Video is private or unavailable";
  if (lower.includes("sign in")) return "Video is age-restricted and requires authentication";
  if (lower.includes("not available"))
    return "Video is unavailable in your region or has been removed";
  if (lower.includes("live")) return "Cannot extract frames from a live stream";
  const snippet = trimErrorText(stderr || message);
  return snippet ? `yt-dlp failed: ${snippet}` : "yt-dlp failed";
}

function extractHeadingTitle(text: string): string | null {
  const match = text.match(/^#{1,2}\s+(.+)/m);
  if (!match) return null;
  const cleaned = match[1].replace(/\*+/g, "").trim();
  return cleaned || null;
}

function normalizeSpaces(s: string): string {
  return s.replace(/[\u00A0\u2000-\u200B\u202F\u205F\u3000\uFEFF]/g, " ");
}

// ── YouTube Detection ────────────────────────────────────────────────

function isYouTubeURL(url: string): {
  isYouTube: boolean;
  videoId: string | null;
} {
  try {
    const parsed = new URL(url);
    if (parsed.pathname === "/playlist") return { isYouTube: false, videoId: null };
  } catch {
    /* ignore */
  }
  const match = url.match(YOUTUBE_REGEX);
  if (!match) return { isYouTube: false, videoId: null };
  return { isYouTube: true, videoId: match[1] };
}

// ── Local Video Detection ────────────────────────────────────────────

function isVideoFile(input: string): VideoFileInfo | null {
  const isFilePath =
    input.startsWith("/") ||
    input.startsWith("./") ||
    input.startsWith("../") ||
    input.startsWith("file://");
  if (!isFilePath) return null;

  let filePath = input;
  if (input.startsWith("file://")) {
    try {
      filePath = decodeURIComponent(new URL(input).pathname);
    } catch {
      return null;
    }
  }

  const ext = extname(filePath).toLowerCase();
  const mimeType = VIDEO_EXTENSIONS[ext];
  if (!mimeType) return null;

  const absolutePath = resolveFilePath(filePath);
  if (!absolutePath) return null;

  let stat: ReturnType<typeof statSync>;
  try {
    stat = statSync(absolutePath);
  } catch {
    return null;
  }
  if (!stat.isFile()) return null;

  const maxBytes = DEFAULT_MAX_SIZE_MB * 1024 * 1024;
  if (stat.size > maxBytes) return null;

  return { absolutePath, mimeType, sizeBytes: stat.size };
}

function resolveFilePath(filePath: string): string | null {
  const absolutePath = resolve(filePath);
  if (existsSync(absolutePath)) return absolutePath;

  const dir = dirname(absolutePath);
  const base = basename(absolutePath);
  if (!existsSync(dir)) return null;

  try {
    const normalizedBase = normalizeSpaces(base);
    const match = readdirSync(dir).find((f) => normalizeSpaces(f) === normalizedBase);
    return match ? join(dir, match) : null;
  } catch {
    return null;
  }
}

// ── Async exec helper ────────────────────────────────────────────────

function execFileAsync(
  cmd: string,
  args: string[],
  opts: { timeout?: number; maxBuffer?: number; encoding?: "utf-8" | "buffer" },
): Promise<{ stdout: Buffer | string; stderr: Buffer | string }> {
  return new Promise((resolve, reject) => {
    execFile(
      cmd,
      args,
      {
        timeout: opts.timeout,
        maxBuffer: opts.maxBuffer ?? 5 * 1024 * 1024,
        encoding: opts.encoding === "utf-8" ? "utf-8" : ("buffer" as any),
      },
      (err, stdout, stderr) => {
        if (err) return reject(Object.assign(err, { stderr, stdout }));
        resolve({ stdout: stdout ?? "", stderr: stderr ?? "" });
      },
    );
  });
}

// ── YouTube Frame Extraction ─────────────────────────────────────────

type StreamInfo = { streamUrl: string; duration: number | null };
type StreamResult = StreamInfo | { error: string };

async function getYouTubeStreamInfo(videoId: string): Promise<StreamResult> {
  try {
    const { stdout } = await execFileAsync(
      "yt-dlp",
      ["--print", "duration", "-g", `https://www.youtube.com/watch?v=${videoId}`],
      { timeout: 15000, encoding: "utf-8" },
    );
    const output = (stdout as string).trim();
    const lines = output.split(/\r?\n/);
    const rawDuration = lines[0]?.trim();
    const streamUrl = lines[1]?.trim();
    if (!streamUrl) return { error: "yt-dlp failed: missing stream URL" };
    const parsedDuration =
      rawDuration && rawDuration !== "NA" ? Number.parseFloat(rawDuration) : NaN;
    const duration = Number.isFinite(parsedDuration) ? parsedDuration : null;
    return { streamUrl, duration };
  } catch (err) {
    return { error: mapYtDlpError(err) };
  }
}

async function extractFrameFromStream(streamUrl: string, seconds: number): Promise<FrameResult> {
  try {
    const { stdout } = await execFileAsync(
      "ffmpeg",
      [
        "-ss",
        String(seconds),
        "-i",
        streamUrl,
        "-frames:v",
        "1",
        "-f",
        "image2pipe",
        "-vcodec",
        "mjpeg",
        "pipe:1",
      ],
      { timeout: 30000, maxBuffer: 5 * 1024 * 1024 },
    );
    const buffer = Buffer.isBuffer(stdout) ? stdout : Buffer.from(stdout);
    if (buffer.length === 0) return { error: "ffmpeg failed: empty output" };
    return { data: buffer.toString("base64"), mimeType: "image/jpeg" };
  } catch (err) {
    return { error: mapFfmpegError(err) };
  }
}

async function extractYouTubeFrame(
  videoId: string,
  seconds: number,
  streamInfo?: StreamInfo,
): Promise<FrameResult> {
  const info = streamInfo ?? (await getYouTubeStreamInfo(videoId));
  if ("error" in info) return info;
  return extractFrameFromStream(info.streamUrl, seconds);
}

async function extractYouTubeFrames(
  videoId: string,
  timestamps: number[],
  streamInfo?: StreamInfo,
): Promise<{
  frames: VideoFrame[];
  duration: number | null;
  error: string | null;
}> {
  const info = streamInfo ?? (await getYouTubeStreamInfo(videoId));
  if ("error" in info) return { frames: [], duration: null, error: info.error };
  const results = await Promise.all(
    timestamps.map(async (t) => {
      const frame = await extractFrameFromStream(info.streamUrl, t);
      if ("error" in frame) return { error: frame.error };
      return { ...frame, timestamp: formatSeconds(t) } as VideoFrame;
    }),
  );
  const frames = results.filter((f): f is VideoFrame => "data" in f);
  const errorResult = results.find((f): f is { error: string } => "error" in f);
  return {
    frames,
    duration: info.duration,
    error: frames.length === 0 && errorResult ? errorResult.error : null,
  };
}

async function fetchYouTubeThumbnail(
  videoId: string,
): Promise<{ data: string; mimeType: string } | null> {
  try {
    const res = await fetch(`https://img.youtube.com/vi/${videoId}/hqdefault.jpg`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    const buffer = Buffer.from(await res.arrayBuffer());
    if (buffer.length === 0) return null;
    return { data: buffer.toString("base64"), mimeType: "image/jpeg" };
  } catch {
    return null;
  }
}

// ── Local Video Frame Extraction ─────────────────────────────────────

async function extractVideoFrame(filePath: string, seconds: number = 1): Promise<FrameResult> {
  try {
    const { stdout } = await execFileAsync(
      "ffmpeg",
      [
        "-ss",
        String(seconds),
        "-i",
        filePath,
        "-frames:v",
        "1",
        "-f",
        "image2pipe",
        "-vcodec",
        "mjpeg",
        "pipe:1",
      ],
      { timeout: 10000, maxBuffer: 5 * 1024 * 1024 },
    );
    const buffer = Buffer.isBuffer(stdout) ? stdout : Buffer.from(stdout);
    if (buffer.length === 0) return { error: "ffmpeg failed: empty output" };
    return { data: buffer.toString("base64"), mimeType: "image/jpeg" };
  } catch (err) {
    return { error: mapFfmpegError(err) };
  }
}

async function getLocalVideoDuration(filePath: string): Promise<number | { error: string }> {
  try {
    const { stdout } = await execFileAsync(
      "ffprobe",
      ["-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", filePath],
      { timeout: 10000, encoding: "utf-8" },
    );
    const duration = Number.parseFloat((stdout as string).trim());
    if (!Number.isFinite(duration)) return { error: "ffprobe failed: invalid duration output" };
    return duration;
  } catch (err) {
    const { code, stderr, message } = readExecError(err);
    if (code === "ENOENT")
      return {
        error: "ffprobe is not installed. Install ffmpeg which includes ffprobe",
      };
    const snippet = trimErrorText(stderr || message);
    return {
      error: snippet ? `ffprobe failed: ${snippet}` : "ffprobe failed",
    };
  }
}

async function extractLocalFrames(
  filePath: string,
  timestamps: number[],
): Promise<{ frames: VideoFrame[]; error: string | null }> {
  const results = await Promise.all(
    timestamps.map(async (t) => {
      const frame = await extractVideoFrame(filePath, t);
      if ("error" in frame) return { error: frame.error };
      return { ...frame, timestamp: formatSeconds(t) } as VideoFrame;
    }),
  );
  const frames = results.filter((f): f is VideoFrame => "data" in f);
  const firstError = results.find((f): f is { error: string } => "error" in f);
  return {
    frames,
    error: frames.length === 0 && firstError ? firstError.error : null,
  };
}

// ── Gemini API ───────────────────────────────────────────────────────

async function queryGeminiApiWithVideo(
  prompt: string,
  videoUri: string,
  apiKey: string,
  options: {
    model?: string;
    mimeType?: string;
    signal?: AbortSignal;
    timeoutMs?: number;
  } = {},
): Promise<string> {
  const model = options.model ?? DEFAULT_MODEL;
  const timeoutMs = options.timeoutMs ?? 120000;
  const signal = options.signal
    ? AbortSignal.any([options.signal, AbortSignal.timeout(timeoutMs)])
    : AbortSignal.timeout(timeoutMs);

  const url = `${API_BASE}/models/${model}:generateContent?key=${apiKey}`;
  const fileData: Record<string, string> = { fileUri: videoUri };
  if (options.mimeType) fileData.mimeType = options.mimeType;

  const body = {
    contents: [{ parts: [{ fileData }, { text: prompt }] }],
  };

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal,
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${errorText.slice(0, 300)}`);
  }

  const data = (await res.json()) as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };

  const text = data.candidates?.[0]?.content?.parts
    ?.map((p) => p.text)
    .filter(Boolean)
    .join("\n");

  if (!text) throw new Error("Gemini API returned empty response");
  return text;
}

async function uploadToFilesApi(
  info: VideoFileInfo,
  apiKey: string,
  signal?: AbortSignal,
): Promise<{ name: string; uri: string }> {
  const displayName = basename(info.absolutePath);

  const initRes = await fetch(`${UPLOAD_BASE}/files`, {
    method: "POST",
    headers: {
      "x-goog-api-key": apiKey,
      "X-Goog-Upload-Protocol": "resumable",
      "X-Goog-Upload-Command": "start",
      "X-Goog-Upload-Header-Content-Length": String(info.sizeBytes),
      "X-Goog-Upload-Header-Content-Type": info.mimeType,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ file: { display_name: displayName } }),
    signal,
  });

  if (!initRes.ok) {
    const text = await initRes.text();
    throw new Error(`File upload init failed: ${initRes.status} (${text.slice(0, 200)})`);
  }

  const uploadUrl = initRes.headers.get("x-goog-upload-url");
  if (!uploadUrl) throw new Error("No upload URL in response headers");

  const fileData = await readFile(info.absolutePath);
  const uploadRes = await fetch(uploadUrl, {
    method: "PUT",
    headers: {
      "Content-Length": String(info.sizeBytes),
      "X-Goog-Upload-Offset": "0",
      "X-Goog-Upload-Command": "upload, finalize",
    },
    body: fileData,
    signal,
  });

  if (!uploadRes.ok) {
    const text = await uploadRes.text();
    throw new Error(`File upload failed: ${uploadRes.status} (${text.slice(0, 200)})`);
  }

  const result = (await uploadRes.json()) as {
    file: { name: string; uri: string };
  };
  return result.file;
}

async function pollFileState(
  fileName: string,
  apiKey: string,
  signal?: AbortSignal,
  timeoutMs: number = 120000,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (signal?.aborted) throw new Error("Aborted");
    const res = await fetch(`${API_BASE}/${fileName}?key=${apiKey}`, {
      signal,
    });
    if (!res.ok) throw new Error(`File state check failed: ${res.status}`);
    const data = (await res.json()) as { state: string };
    if (data.state === "ACTIVE") return;
    if (data.state === "FAILED") throw new Error("File processing failed");
    await new Promise((r) => setTimeout(r, 5000));
  }
  throw new Error("File processing timed out");
}

function deleteGeminiFile(fileName: string, apiKey: string): void {
  fetch(`${API_BASE}/${fileName}?key=${apiKey}`, { method: "DELETE" }).catch(() => {});
}

// ── YouTube Extraction ───────────────────────────────────────────────

async function extractYouTube(
  url: string,
  apiKey: string,
  signal?: AbortSignal,
  prompt?: string,
  model?: string,
): Promise<ExtractedContent | null> {
  const { videoId } = isYouTubeURL(url);
  const canonicalUrl = videoId ? `https://www.youtube.com/watch?v=${videoId}` : url;
  const effectivePrompt = prompt ?? YOUTUBE_PROMPT;
  const effectiveModel = model ?? DEFAULT_MODEL;

  try {
    if (signal?.aborted) return null;
    const text = await queryGeminiApiWithVideo(effectivePrompt, canonicalUrl, apiKey, {
      model: effectiveModel,
      signal,
      timeoutMs: 120000,
    });

    const result: ExtractedContent = {
      url,
      title: extractHeadingTitle(text) ?? "YouTube Video",
      content: text,
      error: null,
    };

    if (videoId) {
      const thumb = await fetchYouTubeThumbnail(videoId);
      if (thumb) result.thumbnail = thumb;
    }

    return result;
  } catch {
    return null;
  }
}

// ── Local Video Extraction ───────────────────────────────────────────

async function extractVideo(
  info: VideoFileInfo,
  apiKey: string,
  signal?: AbortSignal,
  options?: { prompt?: string; model?: string },
): Promise<ExtractedContent | null> {
  const effectivePrompt = options?.prompt ?? VIDEO_PROMPT;
  const effectiveModel = options?.model ?? DEFAULT_MODEL;

  let fileName: string | null = null;
  try {
    if (signal?.aborted) return null;
    const uploaded = await uploadToFilesApi(info, apiKey, signal);
    fileName = uploaded.name;

    await pollFileState(fileName, apiKey, signal, 120000);

    const text = await queryGeminiApiWithVideo(effectivePrompt, uploaded.uri, apiKey, {
      model: effectiveModel,
      mimeType: info.mimeType,
      signal,
      timeoutMs: 120000,
    });

    const result: ExtractedContent = {
      url: info.absolutePath,
      title: extractHeadingTitle(text) ?? basename(info.absolutePath, extname(info.absolutePath)),
      content: text,
      error: null,
    };

    const thumbnail = await extractVideoFrame(info.absolutePath);
    if (!("error" in thumbnail)) {
      result.thumbnail = thumbnail;
    }

    return result;
  } catch {
    return null;
  } finally {
    if (fileName) deleteGeminiFile(fileName, apiKey);
  }
}

// ── Timestamp Parsing ────────────────────────────────────────────────

function parseTimestamp(ts: string): number | null {
  const num = Number(ts);
  if (!isNaN(num) && num >= 0) return Math.floor(num);
  const parts = ts.split(":").map(Number);
  if (parts.some((p) => isNaN(p) || p < 0)) return null;
  if (parts.length === 3) return Math.floor(parts[0] * 3600 + parts[1] * 60 + parts[2]);
  if (parts.length === 2) return Math.floor(parts[0] * 60 + parts[1]);
  return null;
}

type TimestampSpec =
  | { type: "single"; seconds: number }
  | { type: "range"; start: number; end: number };

function parseTimestampSpec(ts: string): TimestampSpec | null {
  const dashIdx = ts.indexOf("-", 1);
  if (dashIdx > 0) {
    const start = parseTimestamp(ts.slice(0, dashIdx));
    const end = parseTimestamp(ts.slice(dashIdx + 1));
    if (start !== null && end !== null && end > start) return { type: "range", start, end };
  }
  const seconds = parseTimestamp(ts);
  return seconds !== null ? { type: "single", seconds } : null;
}

function computeRangeTimestamps(
  start: number,
  end: number,
  maxFrames: number = DEFAULT_RANGE_FRAMES,
): number[] {
  if (maxFrames <= 1) return [start];
  const duration = end - start;
  const idealInterval = duration / (maxFrames - 1);
  if (idealInterval < MIN_FRAME_INTERVAL) {
    const timestamps: number[] = [];
    for (let t = start; t <= end && timestamps.length < maxFrames; t += MIN_FRAME_INTERVAL) {
      timestamps.push(t);
    }
    return timestamps;
  }
  return Array.from({ length: maxFrames }, (_, i) => Math.round(start + i * idealInterval));
}

function buildFrameResult(
  url: string,
  label: string,
  requestedCount: number,
  frames: VideoFrame[],
  error: string | null,
  duration?: number,
): ExtractedContent {
  if (frames.length === 0) {
    const msg = error ?? "Frame extraction failed";
    return {
      url,
      title: `Frames ${label} (0/${requestedCount})`,
      content: msg,
      error: msg,
    };
  }
  return {
    url,
    title: `Frames ${label} (${frames.length}/${requestedCount})`,
    content: `${frames.length} frames extracted from ${label}`,
    error: null,
    frames,
    duration,
  };
}

// ── Main Extraction Orchestrator ─────────────────────────────────────

function safeVideoInfo(url: string): {
  info: VideoFileInfo | null;
  error?: string;
} {
  try {
    return { info: isVideoFile(url) };
  } catch (err) {
    return { info: null, error: errorMessage(err) };
  }
}

async function extractContent(
  url: string,
  apiKey: string | undefined,
  signal?: AbortSignal,
  options?: {
    prompt?: string;
    timestamp?: string;
    frames?: number;
    model?: string;
  },
): Promise<ExtractedContent> {
  if (signal?.aborted) {
    return { url, title: "", content: "", error: "Aborted" };
  }

  // ── Frames only (no timestamp) — sample across full video ──
  if (options?.frames && !options.timestamp) {
    const frameCount = options.frames;
    const ytInfo = isYouTubeURL(url);

    if (ytInfo.isYouTube && ytInfo.videoId) {
      const streamInfo = await getYouTubeStreamInfo(ytInfo.videoId);
      if ("error" in streamInfo) {
        return {
          url,
          title: "Frames",
          content: streamInfo.error,
          error: streamInfo.error,
        };
      }
      if (streamInfo.duration === null) {
        const error = "Cannot determine video duration. Use a timestamp range instead.";
        return { url, title: "Frames", content: error, error };
      }
      const dur = Math.floor(streamInfo.duration);
      const timestamps = computeRangeTimestamps(0, dur, frameCount);
      const result = await extractYouTubeFrames(ytInfo.videoId, timestamps, streamInfo);
      const label = `${formatSeconds(0)}-${formatSeconds(dur)}`;
      return buildFrameResult(
        url,
        label,
        timestamps.length,
        result.frames,
        result.error,
        streamInfo.duration,
      );
    }

    const localVideo = safeVideoInfo(url);
    if (localVideo.error) {
      return { url, title: "", content: "", error: localVideo.error };
    }
    if (localVideo.info) {
      const durationResult = await getLocalVideoDuration(localVideo.info.absolutePath);
      if (typeof durationResult !== "number") {
        return {
          url,
          title: "Frames",
          content: durationResult.error,
          error: durationResult.error,
        };
      }
      const dur = Math.floor(durationResult);
      const timestamps = computeRangeTimestamps(0, dur, frameCount);
      const result = await extractLocalFrames(localVideo.info.absolutePath, timestamps);
      const label = `${formatSeconds(0)}-${formatSeconds(dur)}`;
      return buildFrameResult(
        url,
        label,
        timestamps.length,
        result.frames,
        result.error,
        durationResult,
      );
    }

    return {
      url,
      title: "",
      content: "",
      error: "Frame extraction only works with YouTube and local video files",
    };
  }

  // ── Timestamp-based frame extraction ──
  if (options?.timestamp) {
    const spec = parseTimestampSpec(options.timestamp);
    if (!spec) {
      return {
        url,
        title: "",
        content: "",
        error: `Invalid timestamp format: "${options.timestamp}". Use "H:MM:SS", "MM:SS", "85", or "start-end".`,
      };
    }

    const frameCount = options.frames;
    const ytInfo = isYouTubeURL(url);

    if (ytInfo.isYouTube && ytInfo.videoId) {
      const streamInfo = await getYouTubeStreamInfo(ytInfo.videoId);
      if ("error" in streamInfo) {
        const label =
          spec.type === "range"
            ? `${formatSeconds(spec.start)}-${formatSeconds(spec.end)}`
            : frameCount
              ? `${formatSeconds(spec.seconds)}-${formatSeconds(spec.seconds + (frameCount - 1) * MIN_FRAME_INTERVAL)}`
              : `at ${options.timestamp}`;
        return {
          url,
          title: `Frames ${label}`,
          content: streamInfo.error,
          error: streamInfo.error,
        };
      }

      if (spec.type === "range") {
        const label = `${formatSeconds(spec.start)}-${formatSeconds(spec.end)}`;
        if (streamInfo.duration !== null && spec.end > streamInfo.duration) {
          const error = `Timestamp ${formatSeconds(spec.end)} exceeds video duration (${formatSeconds(Math.floor(streamInfo.duration))})`;
          return {
            url,
            title: `Frames ${label}`,
            content: error,
            error,
          };
        }
        const timestamps = frameCount
          ? computeRangeTimestamps(spec.start, spec.end, frameCount)
          : computeRangeTimestamps(spec.start, spec.end);
        const result = await extractYouTubeFrames(ytInfo.videoId, timestamps, streamInfo);
        return buildFrameResult(
          url,
          label,
          timestamps.length,
          result.frames,
          result.error,
          result.duration ?? undefined,
        );
      }

      if (frameCount) {
        const end = spec.seconds + (frameCount - 1) * MIN_FRAME_INTERVAL;
        const label = `${formatSeconds(spec.seconds)}-${formatSeconds(end)}`;
        if (streamInfo.duration !== null && end > streamInfo.duration) {
          const error = `Timestamp ${formatSeconds(end)} exceeds video duration (${formatSeconds(Math.floor(streamInfo.duration))})`;
          return {
            url,
            title: `Frames ${label}`,
            content: error,
            error,
          };
        }
        const timestamps = computeRangeTimestamps(spec.seconds, end, frameCount);
        const result = await extractYouTubeFrames(ytInfo.videoId, timestamps, streamInfo);
        return buildFrameResult(
          url,
          label,
          timestamps.length,
          result.frames,
          result.error,
          result.duration ?? undefined,
        );
      }

      // Single frame
      if (streamInfo.duration !== null && spec.seconds > streamInfo.duration) {
        const error = `Timestamp ${formatSeconds(spec.seconds)} exceeds video duration (${formatSeconds(Math.floor(streamInfo.duration))})`;
        return {
          url,
          title: `Frame at ${options.timestamp}`,
          content: error,
          error,
        };
      }
      const frame = await extractYouTubeFrame(ytInfo.videoId, spec.seconds, streamInfo);
      if ("error" in frame) {
        return {
          url,
          title: `Frame at ${options.timestamp}`,
          content: frame.error!,
          error: frame.error!,
        };
      }
      return {
        url,
        title: `Frame at ${options.timestamp}`,
        content: `Video frame at ${options.timestamp}`,
        error: null,
        thumbnail: frame as { data: string; mimeType: string },
      };
    }

    // Local video with timestamp
    const localVideo = safeVideoInfo(url);
    if (localVideo.error) {
      return { url, title: "", content: "", error: localVideo.error };
    }
    if (localVideo.info) {
      if (spec.type === "range") {
        const timestamps = frameCount
          ? computeRangeTimestamps(spec.start, spec.end, frameCount)
          : computeRangeTimestamps(spec.start, spec.end);
        const result = await extractLocalFrames(localVideo.info.absolutePath, timestamps);
        const label = `${formatSeconds(spec.start)}-${formatSeconds(spec.end)}`;
        return buildFrameResult(url, label, timestamps.length, result.frames, result.error);
      }

      if (frameCount) {
        const end = spec.seconds + (frameCount - 1) * MIN_FRAME_INTERVAL;
        const timestamps = computeRangeTimestamps(spec.seconds, end, frameCount);
        const result = await extractLocalFrames(localVideo.info.absolutePath, timestamps);
        const label = `${formatSeconds(spec.seconds)}-${formatSeconds(end)}`;
        return buildFrameResult(url, label, timestamps.length, result.frames, result.error);
      }

      const frame = await extractVideoFrame(localVideo.info.absolutePath, spec.seconds);
      if ("error" in frame) {
        return {
          url,
          title: `Frame at ${options.timestamp}`,
          content: frame.error!,
          error: frame.error!,
        };
      }
      return {
        url,
        title: `Frame at ${options.timestamp}`,
        content: `Video frame at ${options.timestamp}`,
        error: null,
        thumbnail: frame as { data: string; mimeType: string },
      };
    }

    return {
      url,
      title: "",
      content: "",
      error: "Timestamp extraction only works with YouTube and local video files",
    };
  }

  // ── Full video extraction (no frames/timestamp) ──
  const localVideo = safeVideoInfo(url);
  if (localVideo.error) {
    return { url, title: "", content: "", error: localVideo.error };
  }
  if (localVideo.info) {
    if (!apiKey) {
      return {
        url,
        title: "",
        content: "",
        error:
          "Video analysis requires a Google API key. Configure it via /login or set GEMINI_API_KEY.",
      };
    }
    try {
      const result = await extractVideo(localVideo.info, apiKey, signal, options);
      if (signal?.aborted) return { url, title: "", content: "", error: "Aborted" };
      return (
        result ?? {
          url,
          title: "",
          content: "",
          error: "Video extraction returned no content.",
        }
      );
    } catch (err) {
      if (errorMessage(err).toLowerCase().includes("abort"))
        return { url, title: "", content: "", error: "Aborted" };
      return { url, title: "", content: "", error: errorMessage(err) };
    }
  }

  // YouTube
  const ytInfo = isYouTubeURL(url);
  if (ytInfo.isYouTube) {
    if (!apiKey) {
      return {
        url,
        title: "",
        content: "",
        error:
          "YouTube analysis requires a Google API key. Configure it via /login or set GEMINI_API_KEY.",
      };
    }
    try {
      const ytResult = await extractYouTube(url, apiKey, signal, options?.prompt, options?.model);
      if (ytResult) return ytResult;
      if (signal?.aborted) return { url, title: "", content: "", error: "Aborted" };
    } catch (err) {
      if (errorMessage(err).toLowerCase().includes("abort"))
        return { url, title: "", content: "", error: "Aborted" };
    }
    return {
      url,
      title: "",
      content: "",
      error: "Could not extract YouTube video content.",
    };
  }

  return {
    url,
    title: "",
    content: "",
    error: "Not a video file or YouTube URL. Use web_fetch for web pages.",
  };
}

// ── Extension Registration ───────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "video_extract",
    label: "Video Extract",
    description:
      "Extract content from YouTube videos and local video files. Supports full video analysis via Gemini API, frame extraction at specific timestamps or ranges, and sampling frames across the entire video. When using Gemini analysis, pass a specific question via prompt for best results. This directs the AI to focus on that aspect of the video, producing much better results than a generic extraction.",
    promptSnippet:
      "Extract content from YouTube or local video files. Prefer frame extraction (timestamp/frames) over prompt-based Gemini analysis.",
    promptGuidelines: [
      "Prefer frame extraction (timestamp and/or frames parameters) to understand video visuals — it's fast and doesn't require Gemini API calls.",
      "Use the prompt parameter only when you need deep analysis like full transcription or content understanding that frames alone can't provide.",
      "For quick visual checks, use frames (e.g. frames: 6) to sample across the video, or timestamp with a specific time.",
    ],
    parameters: Type.Object({
      url: Type.String({
        description: "YouTube URL or local video file path (.mp4, .mov, .webm, etc.)",
      }),
      prompt: Type.Optional(
        Type.String({
          description:
            "Question or instruction for video analysis. Pass the user's specific question here — e.g. 'describe the book shown at the advice for beginners section'. Without this, a generic transcript extraction is used which may miss what the user is asking about.",
        }),
      ),
      timestamp: Type.Optional(
        Type.String({
          description:
            "Extract video frame(s) at a timestamp or time range. Single: '1:23:45', '23:45', or '85' (seconds). Range: '23:41-25:00' extracts evenly-spaced frames across that span (default 6). Use frames with ranges to control density; single+frames uses a fixed 5s interval. Requires yt-dlp + ffmpeg for YouTube, ffmpeg for local video.",
        }),
      ),
      frames: Type.Optional(
        Type.Integer({
          minimum: 1,
          maximum: 12,
          description:
            "Number of frames to extract. Use with timestamp range for custom density, with single timestamp to get N frames at 5s intervals, or alone to sample across the entire video. Requires yt-dlp + ffmpeg for YouTube, ffmpeg for local video.",
        }),
      ),
      model: Type.Optional(
        Type.String({
          description:
            "Override the Gemini model for video analysis (e.g. 'gemini-2.5-flash', 'gemini-3-flash-preview'). Defaults to gemini-3-flash-preview.",
        }),
      ),
    }),

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const apiKey = (await ctx.modelRegistry.getApiKeyForProvider("google")) ?? undefined;

      const isFrameOnly = (params.timestamp || params.frames) && !params.prompt;
      if (!isFrameOnly) {
        onUpdate?.({
          content: [{ type: "text", text: "Analyzing video with Gemini…" }],
          details: { phase: "analyzing" },
        });
      }

      const result = await extractContent(params.url, apiKey, signal, {
        prompt: params.prompt,
        timestamp: params.timestamp,
        frames: params.frames,
        model: params.model,
      });

      if (result.error) {
        throw new Error(result.error);
      }

      const content: Array<{
        type: string;
        text?: string;
        data?: string;
        mimeType?: string;
      }> = [];

      // Add frames first
      if (result.frames?.length) {
        for (const frame of result.frames) {
          content.push({
            type: "image",
            data: frame.data,
            mimeType: frame.mimeType,
          });
          content.push({
            type: "text",
            text: `Frame at ${frame.timestamp}`,
          });
        }
      } else if (result.thumbnail) {
        content.push({
          type: "image",
          data: result.thumbnail.data,
          mimeType: result.thumbnail.mimeType,
        });
      }

      content.push({ type: "text", text: result.content });

      const imageCount = (result.frames?.length ?? 0) + (result.thumbnail ? 1 : 0);
      return {
        content,
        details: {
          url: params.url,
          title: result.title,
          totalChars: result.content.length,
          hasImage: imageCount > 0,
          imageCount,
          prompt: params.prompt,
          timestamp: params.timestamp,
          frames: params.frames,
          duration: result.duration,
        },
      };
    },

    renderCall(args, theme, context) {
      const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
      const { url, prompt, timestamp, frames, model } = args as {
        url?: string;
        prompt?: string;
        timestamp?: string;
        frames?: number;
        model?: string;
      };
      if (!url) {
        text.setText(theme.fg("toolTitle", theme.bold("video ")) + theme.fg("error", "(no URL)"));
        return text;
      }
      const lines: string[] = [];
      const display = url.length > 60 ? url.slice(0, 57) + "..." : url;
      lines.push(theme.fg("toolTitle", theme.bold("video ")) + theme.fg("accent", display));
      if (timestamp) lines.push(theme.fg("dim", "  timestamp: ") + theme.fg("warning", timestamp));
      if (typeof frames === "number")
        lines.push(theme.fg("dim", "  frames: ") + theme.fg("warning", String(frames)));
      if (prompt) {
        const d = prompt.length > 250 ? prompt.slice(0, 247) + "..." : prompt;
        lines.push(theme.fg("dim", "  prompt: ") + theme.fg("muted", `"${d}"`));
      }
      if (model) lines.push(theme.fg("dim", "  model: ") + theme.fg("warning", model));
      text.setText(lines.join("\n"));
      return text;
    },

    renderResult(result, { expanded, isPartial }, theme, context) {
      const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);

      if (isPartial) {
        text.setText(theme.fg("warning", "Extracting…"));
        return text;
      }

      if (context.isError) {
        const msg = result.content.find((c) => c.type === "text")?.text || "Error";
        text.setText(theme.fg("error", msg));
        return text;
      }

      const details = result.details as {
        title?: string;
        totalChars?: number;
        imageCount?: number;
        duration?: number;
        prompt?: string;
        timestamp?: string;
        frames?: number;
      };

      const title = details?.title || "Video";
      const imgCount = details?.imageCount ?? 0;
      const imageBadge =
        imgCount > 1
          ? theme.fg("accent", ` [${imgCount} images]`)
          : imgCount === 1
            ? theme.fg("accent", " [image]")
            : "";
      let statusLine =
        theme.fg("success", title) +
        theme.fg("muted", ` (${details?.totalChars ?? 0} chars)`) +
        imageBadge;
      if (typeof details?.duration === "number") {
        statusLine += theme.fg("muted", ` | ${formatSeconds(Math.floor(details.duration))} total`);
      }

      if (!expanded) {
        text.setText(statusLine);
        return text;
      }

      const lines = [statusLine];
      if (details?.prompt) {
        const d =
          details.prompt.length > 250 ? details.prompt.slice(0, 247) + "..." : details.prompt;
        lines.push(theme.fg("dim", `  prompt: "${d}"`));
      }
      if (details?.timestamp) lines.push(theme.fg("dim", `  timestamp: ${details.timestamp}`));
      if (typeof details?.frames === "number")
        lines.push(theme.fg("dim", `  frames: ${details.frames}`));
      const content = result.content.find((c) => c.type === "text")?.text || "";
      const preview = content.length > 500 ? content.slice(0, 500) + "..." : content;
      lines.push(theme.fg("dim", preview));
      text.setText(lines.join("\n"));
      return text;
    },
  });
}
