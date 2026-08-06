import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { getAgentDir } from '@earendil-works/pi-coding-agent';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, join, resolve } from 'node:path';

type CloakPatternSpec =
  | string
  | {
      pattern: string;
      replace?: string;
      flags?: string;
    };

interface CloakRuleConfig {
  filePattern: string | string[];
  cloakPattern: CloakPatternSpec | CloakPatternSpec[];
  replace?: string;
}

interface CloakConfig {
  enabled?: boolean;
  cloakCharacter?: string;
  cloakLength?: number | null;
  tryAllPatterns?: boolean;
  patterns?: CloakRuleConfig[];
}

interface CompiledCloakPattern {
  source: string;
  regex: RegExp;
  replace?: string;
}

interface CompiledCloakRule {
  filePatterns: string[];
  fileRegexes: RegExp[];
  patterns: CompiledCloakPattern[];
}

interface RuntimeState {
  configPath: string;
  config: CloakConfig;
  rules: CompiledCloakRule[];
  error?: string;
}

const DEFAULT_CONFIG_PATH = join(getAgentDir(), 'cloak.json');
const DEFAULT_CONFIG: CloakConfig = {
  enabled: true,
  cloakCharacter: '*',
  cloakLength: null,
  tryAllPatterns: true,
  patterns: [],
};

function toArray<T>(value: T | T[] | undefined): T[] {
  if (value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}

function normalizeSlashes(value: string): string {
  return value.split('\\').join('/');
}

function expandHome(value: string): string {
  if (value === '~') return homedir();
  if (value.startsWith('~/')) return join(homedir(), value.slice(2));
  return value;
}

function normalizePath(value: string): string {
  return normalizeSlashes(expandHome(value.trim()));
}

function stripLeadingAt(value: string): string {
  return value.startsWith('@') ? value.slice(1) : value;
}

function escapeRegex(value: string): string {
  return value.replace(/[|\\{}()[\]^$+?.]/g, '\\$&');
}

function globToRegExp(glob: string): RegExp {
  const normalized = normalizePath(glob);
  let pattern = '^';

  for (let index = 0; index < normalized.length; index++) {
    const char = normalized[index]!;
    const next = normalized[index + 1];
    const afterNext = normalized[index + 2];

    if (char === '*' && next === '*') {
      if (afterNext === '/') {
        pattern += '(?:.*/)?';
        index += 2;
      } else {
        pattern += '.*';
        index += 1;
      }
      continue;
    }

    if (char === '*') {
      pattern += '[^/]*';
      continue;
    }

    if (char === '?') {
      pattern += '[^/]';
      continue;
    }

    pattern += escapeRegex(char);
  }

  pattern += '$';
  return new RegExp(pattern);
}

function ensureGlobalFlags(flags?: string): string {
  const unique = new Set((flags ?? '').split('').filter(Boolean));
  unique.add('g');
  return Array.from(unique).join('');
}

function compilePattern(spec: CloakPatternSpec, ruleReplace?: string): CompiledCloakPattern {
  if (typeof spec === 'string') {
    return {
      source: spec,
      regex: new RegExp(spec, 'g'),
      replace: ruleReplace,
    };
  }

  return {
    source: spec.pattern,
    regex: new RegExp(spec.pattern, ensureGlobalFlags(spec.flags)),
    replace: spec.replace ?? ruleReplace,
  };
}

function compileRule(rule: CloakRuleConfig): CompiledCloakRule {
  const filePatterns = toArray(rule.filePattern);
  const cloakPatterns = toArray(rule.cloakPattern);

  return {
    filePatterns,
    fileRegexes: filePatterns.map(globToRegExp),
    patterns: cloakPatterns.map((pattern) => compilePattern(pattern, rule.replace)),
  };
}

export function loadState(configPath: string = DEFAULT_CONFIG_PATH): RuntimeState {
  try {
    const raw = readFileSync(configPath, 'utf8');
    const parsed = JSON.parse(raw) as CloakConfig;
    const config: CloakConfig = {
      ...DEFAULT_CONFIG,
      ...parsed,
      patterns: parsed.patterns ?? [],
    };

    return {
      configPath,
      config,
      rules: (config.patterns ?? []).map(compileRule),
    };
  } catch (error) {
    const isMissingFile = error instanceof Error && 'code' in error && error.code === 'ENOENT';

    return {
      configPath,
      config: DEFAULT_CONFIG,
      rules: [],
      error: isMissingFile
        ? `pi-cloak config not found at ${configPath}`
        : `pi-cloak failed to load ${configPath}: ${error instanceof Error ? error.message : String(error)}`,
    };
  }
}

function getPathCandidates(rawPath: string, cwd: string): string[] {
  const cleanPath = normalizePath(stripLeadingAt(rawPath));
  const absolutePath = normalizePath(resolve(cwd, expandHome(stripLeadingAt(rawPath))));

  return Array.from(new Set([cleanPath, absolutePath, basename(cleanPath), basename(absolutePath)]));
}

function ruleMatchesPath(rule: CompiledCloakRule, rawPath: string, cwd: string): boolean {
  const candidates = getPathCandidates(rawPath, cwd);
  return candidates.some((candidate) => rule.fileRegexes.some((regex) => regex.test(candidate)));
}

function repeatToLength(seed: string, length: number): string {
  if (length <= 0) return '';
  if (!seed) return '';

  const pieces: string[] = [];
  let totalLength = 0;
  while (totalLength < length) {
    pieces.push(seed);
    totalLength += seed.length;
  }

  return pieces.join('').slice(0, length);
}

function applyReplacementTemplate(template: string, match: string, captures: string[]): string {
  let result = '';

  for (let index = 0; index < template.length; index++) {
    const char = template[index]!;
    if (char !== '$') {
      result += char;
      continue;
    }

    const next = template[index + 1];
    if (!next) {
      result += '$';
      continue;
    }

    if (next === '$') {
      result += '$';
      index += 1;
      continue;
    }

    if (next === '&') {
      result += match;
      index += 1;
      continue;
    }

    if (/\d/.test(next)) {
      let end = index + 1;
      while (end + 1 < template.length && /\d/.test(template[end + 1]!) && end - index < 2) {
        end += 1;
      }

      const groupIndex = Number(template.slice(index + 1, end + 1)) - 1;
      result += captures[groupIndex] ?? '';
      index = end;
      continue;
    }

    result += `$${next}`;
    index += 1;
  }

  return result;
}

function buildMaskedReplacement(
  match: string,
  captures: string[],
  replace: string | undefined,
  cloakCharacter: string,
  cloakLength: number | null | undefined,
): string {
  const visible = replace ? applyReplacementTemplate(replace, match, captures) : match.slice(0, 1);
  const targetLength = cloakLength ?? Math.max(match.length, visible.length);
  const truncatedVisible = visible.slice(0, targetLength);
  const maskedLength = Math.max(0, targetLength - truncatedVisible.length);
  return truncatedVisible + repeatToLength(cloakCharacter, maskedLength);
}

function applyPatternsToLine(
  line: string,
  patterns: CompiledCloakPattern[],
  config: CloakConfig,
): { line: string; changed: boolean } {
  let updated = line;
  let changed = false;

  for (const pattern of patterns) {
    let matchedThisPattern = false;
    const next = updated.replace(pattern.regex, (match: string, ...args: unknown[]) => {
      const captures = args.slice(0, Math.max(0, args.length - 2)).map((value) => String(value ?? ''));
      const replacement = buildMaskedReplacement(
        match,
        captures,
        pattern.replace,
        config.cloakCharacter ?? '*',
        config.cloakLength,
      );

      if (replacement !== match) {
        matchedThisPattern = true;
      }

      return replacement;
    });

    if (matchedThisPattern) {
      updated = next;
      changed = true;
      if (!config.tryAllPatterns) {
        break;
      }
    }
  }

  return { line: updated, changed };
}

export function cloakText(rawText: string, rawPath: string, cwd: string, state: RuntimeState): string {
  if (!state.config.enabled) return rawText;

  const matchingRules = state.rules.filter((rule) => ruleMatchesPath(rule, rawPath, cwd));
  if (matchingRules.length === 0) return rawText;

  const newline = rawText.includes('\r\n') ? '\r\n' : '\n';
  const lines = rawText.split(/\r?\n/);
  let changed = false;

  const cloakedLines = lines.map((line) => {
    let updated = line;

    for (const rule of matchingRules) {
      const result = applyPatternsToLine(updated, rule.patterns, state.config);
      if (result.changed) {
        updated = result.line;
        changed = true;
      }
    }

    return updated;
  });

  return changed ? cloakedLines.join(newline) : rawText;
}

export default function (pi: ExtensionAPI) {
  let state = loadState();

  const reloadConfig = () => {
    state = loadState();
  };

  pi.on('session_start', async (_event, ctx) => {
    reloadConfig();

    if (state.error && ctx.hasUI) {
      ctx.ui.notify(state.error, 'warning');
    }
  });

  pi.registerCommand('cloak-status', {
    description: 'Show pi-cloak config status',
    handler: async (_args, ctx) => {
      reloadConfig();

      const summary = state.error
        ? `${state.error}\npatterns: ${state.rules.length}`
        : `pi-cloak enabled=${state.config.enabled !== false} patterns=${state.rules.length} config=${state.configPath}`;

      ctx.ui.notify(summary, state.error ? 'warning' : 'info');
    },
  });

  pi.on('tool_result', async (event, ctx) => {
    if (event.toolName !== 'read') return undefined;
    if (!state.config.enabled) return undefined;

    const rawPath = typeof event.input?.path === 'string' ? event.input.path : '';
    if (!rawPath) return undefined;

    let changed = false;
    const content = event.content.map((part) => {
      if (part.type !== 'text' || typeof part.text !== 'string') {
        return part;
      }

      const cloakedText = cloakText(part.text, rawPath, ctx.cwd, state);
      if (cloakedText === part.text) {
        return part;
      }

      changed = true;
      return {
        ...part,
        text: cloakedText,
      };
    });

    if (!changed) return undefined;
    return { content };
  });
}
