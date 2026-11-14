export interface Evidence {
  id: string;
  title: string;
  subtitle: string;
  source: string;
  body: string;
}

export interface Choice {
  id: string;
  label: string;
  target: string;
  requires: string[];
  requiresFlags: string[];
  grants: string[];
  sets: string[];
  hint: string;
}

export interface StoryNode {
  id: string;
  chapter: string;
  location: string;
  title: string;
  paragraphs: string[];
  choices: Choice[];
}

export interface HistoryEntry {
  from: string;
  choiceId: string;
  to: string;
  at: number;
}

export interface GameState {
  schemaVersion: number;
  nodeId: string;
  evidenceIds: string[];
  flags: string[];
  history: HistoryEntry[];
  updatedAt: number;
}

export interface TransitionResult {
  ok: boolean;
  state: GameState;
  message: string;
}

export interface LoadResult {
  status: string;
  state: GameState | null;
  message: string;
}
