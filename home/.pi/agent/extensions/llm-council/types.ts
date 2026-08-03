// ── Shared (rendering/display) ────────────────────────────────────────────

export interface SpinnerUserConfig {
  prefixChars?: string[];
  interval?: number;
  color?: string;
}

export interface PrefixUserConfig {
  prefix?: string;
  color?: string;
}

export interface StatusUserConfig {
  doneLabel?: string;
  doneColor?: string;
  errorLabel?: string;
  errorColor?: string;
  workingLabel?: string;
  workingColor?: string;
  waitingIcon?: string;
  waitingIconColor?: string;
  synthesizingLabel?: string;
  waitingLabel?: string;
  elapsedColor?: string;
}

export interface ToolHeaderUserConfig {
  titleColor?: string;
  summaryColor?: string;
}

export interface ExpandHintUserConfig {
  color?: string;
}

export interface QuestionPreviewUserConfig {
  maxLength?: number;
}

export interface SharedUserConfig {
  spinner?: SpinnerUserConfig;
  successPrefix?: PrefixUserConfig;
  errorPrefix?: PrefixUserConfig;
  branch?: PrefixUserConfig;
  status?: StatusUserConfig;
  toolHeader?: ToolHeaderUserConfig;
  expandHint?: ExpandHintUserConfig;
  questionPreview?: QuestionPreviewUserConfig;
}

// ── Member ────────────────────────────────────────────────────────────────

export interface MemberDisplayUserConfig {
  labelColor?: string;
  modelColor?: string;
}

export interface ChairmanDisplayUserConfig {
  icon?: string;
  labelColor?: string;
  modelColor?: string;
}

export interface CouncilMemberUserConfig {
  model: string;
  displayName?: string;
  label?: string;
  systemPrompt?: string;
}

export interface MemberUserConfig {
  council?: CouncilMemberUserConfig[];
  defaultSystemPrompt?: string;
  display?: MemberDisplayUserConfig;
  tools?: string[] | null;
  thinking?: string | null;
  extensions?: string[] | null;
  skills?: string[] | null;
  contextFiles?: boolean;
}

// ── Chairman ───────────────────────────────────────────────────────────────

export interface ChairmanUserConfig {
  model?: string;
  displayName?: string;
  systemPrompt?: string;
  exposePersonas?: boolean;
  display?: ChairmanDisplayUserConfig;
  tools?: string[] | null;
  thinking?: string | null;
  extensions?: string[] | null;
  skills?: string[] | null;
  contextFiles?: boolean;
}

// ── Top-level ──────────────────────────────────────────────────────────────

export interface LlmCouncilUserConfig {
  shared?: SharedUserConfig;
  member?: MemberUserConfig;
  chairman?: ChairmanUserConfig;
}