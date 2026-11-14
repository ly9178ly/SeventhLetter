import { Choice, GameState, StoryNode, TransitionResult } from '../model/StoryModels';
import { EVIDENCE, KNOWN_FLAGS, STORY } from '../data/ChapterOne';

export function nodeById(id: string): StoryNode | undefined {
  return STORY.find((node: StoryNode) => node.id === id);
}

export function createGame(now: number = Date.now()): GameState {
  return { schemaVersion: 1, nodeId: 'arrival', evidenceIds: [], flags: [], history: [], updatedAt: now };
}

export function canChoose(state: GameState, choice: Choice): boolean {
  return choice.requires.every((id: string) => state.evidenceIds.includes(id)) &&
    choice.requiresFlags.every((id: string) => state.flags.includes(id));
}

export function choose(state: GameState, choiceId: string, now: number = Date.now()): TransitionResult {
  const node = nodeById(state.nodeId);
  const choice = node?.choices.find((item: Choice) => item.id === choiceId);
  if (!choice || !canChoose(state, choice) || !nodeById(choice.target)) {
    return { ok: false, state, message: '线索尚未齐全，或这个选项已经失效。' };
  }
  const evidenceIds = state.evidenceIds.slice();
  const flags = state.flags.slice();
  choice.grants.forEach((id: string) => { if (!evidenceIds.includes(id)) { evidenceIds.push(id); } });
  choice.sets.forEach((id: string) => { if (!flags.includes(id)) { flags.push(id); } });
  const history = state.history.slice();
  history.push({ from: state.nodeId, choiceId, to: choice.target, at: now });
  // Bound the local journal; it is a play record, not a rule input.
  if (history.length > 200) { history.shift(); }
  return {
    ok: true, message: '',
    state: { schemaVersion: 1, nodeId: choice.target, evidenceIds, flags, history, updatedAt: now }
  };
}

export function validState(state: GameState): boolean {
  if (!state || state.schemaVersion !== 1 || typeof state.nodeId !== 'string' || !nodeById(state.nodeId) ||
    !Array.isArray(state.evidenceIds) || !Array.isArray(state.flags) || !Array.isArray(state.history) ||
    !Number.isFinite(state.updatedAt) || state.updatedAt < 0 || state.history.length > 200) { return false; }
  if (state.evidenceIds.length > EVIDENCE.length || state.flags.length > KNOWN_FLAGS.length) { return false; }
  if (!state.evidenceIds.every((id: string, index: number) =>
    typeof id === 'string' && EVIDENCE.some(item => item.id === id) && state.evidenceIds.indexOf(id) === index)) { return false; }
  if (!state.flags.every((id: string, index: number) =>
    KNOWN_FLAGS.includes(id) && state.flags.indexOf(id) === index)) { return false; }
  return state.history.every(item => {
    if (!item || !Number.isFinite(item.at) || item.at < 0) { return false; }
    const from = nodeById(item.from);
    return !!from?.choices.some(choice => choice.id === item.choiceId && choice.target === item.to);
  });
}
