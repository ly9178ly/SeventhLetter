import { Choice, GameState, StoryNode, TransitionResult } from '../model/StoryModels';
import { DEDUCTIONS, ENDINGS, EVIDENCE, KNOWN_FLAGS, STORY } from '../data/StoryData';

export function nodeById(id: string): StoryNode | undefined {
  return STORY.find((node: StoryNode) => node.id === id);
}

export function createGame(now: number = Date.now(), endingIds: string[] = []): GameState {
  return { schemaVersion: 2, nodeId: 'arrival', evidenceIds: [], flags: [], history: [], updatedAt: now, endingIds: endingIds.slice() };
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
  const endingIds = state.endingIds.slice();
  const ending = ENDINGS.find(item => item.nodeId === choice.target);
  if (ending && !endingIds.includes(ending.id)) { endingIds.push(ending.id); }
  return {
    ok: true, message: '',
    state: { schemaVersion: 2, nodeId: choice.target, evidenceIds, flags, history, updatedAt: now, endingIds }
  };
}

export function validState(state: GameState): boolean {
  if (!state || state.schemaVersion !== 2 || typeof state.nodeId !== 'string' || !nodeById(state.nodeId) ||
    !Array.isArray(state.evidenceIds) || !Array.isArray(state.flags) || !Array.isArray(state.history) ||
    !Number.isFinite(state.updatedAt) || state.updatedAt < 0 || state.history.length > 200 ||
    !Array.isArray(state.endingIds) || state.endingIds.length > ENDINGS.length) { return false; }
  if (state.evidenceIds.length > EVIDENCE.length || state.flags.length > KNOWN_FLAGS.length) { return false; }
  if (!state.evidenceIds.every((id: string, index: number) =>
    typeof id === 'string' && EVIDENCE.some(item => item.id === id) && state.evidenceIds.indexOf(id) === index)) { return false; }
  if (!state.flags.every((id: string, index: number) =>
    KNOWN_FLAGS.includes(id) && state.flags.indexOf(id) === index)) { return false; }
  if (!state.endingIds.every((id: string, index: number) =>
    ENDINGS.some(item => item.id === id) && state.endingIds.indexOf(id) === index)) { return false; }
  if (!DEDUCTIONS.every(item => !state.flags.includes(item.id) ||
    item.evidenceIds.every(id => state.evidenceIds.includes(id)))) { return false; }
  return state.history.every(item => {
    if (!item || !Number.isFinite(item.at) || item.at < 0) { return false; }
    const from = nodeById(item.from);
    return !!from?.choices.some(choice => choice.id === item.choiceId && choice.target === item.to);
  });
}

export function deduce(state: GameState, caseId: string, selected: string[], answer: string,
  now: number = Date.now()): TransitionResult {
  const rule = DEDUCTIONS.find(item => item.id === caseId);
  if (!state.flags.includes('met_shen')) {
    return { ok: false, state, message: '见过沈予、进入第二章后才能开展证据核对。' };
  }
  if (!rule || selected.length !== rule.evidenceIds.length ||
    !rule.evidenceIds.every(id => selected.includes(id) && state.evidenceIds.includes(id))) {
    return { ok: false, state, message: '这两份材料还不足以相互印证。请重读来源，再换一组证据。' };
  }
  if (rule.answer !== answer) {
    return { ok: false, state, message: '这个判断超出了证据能支持的范围。没有扣分，可以重新核对。' };
  }
  const flags = state.flags.slice();
  if (!flags.includes(rule.id)) { flags.push(rule.id); }
  return { ok: true, message: rule.conclusion, state: {
    schemaVersion: 2, nodeId: state.nodeId, evidenceIds: state.evidenceIds.slice(), flags,
    history: state.history.slice(), updatedAt: now, endingIds: state.endingIds.slice()
  } };
}

export function letterDraft(state: GameState): string {
  const lines: string[] = ['致林知秋，以及应当收到这份说明的人：'];
  lines.push(state.flags.includes('identity') ? '原版合影与清场确认单证实，我参与过三年前那晚的清场，并签下确认。' : '我还没有把自己的身份与清场记录核对清楚，这部分不能写成已证实的事实。');
  lines.push(state.flags.includes('cause') ? '你事先提醒过门锁故障。事故通报确认：故障未处理、清场未核实延误了发现，你在那晚遇难。' : '关于被困和遇难的具体过程，我仍需核对事前提醒与事故通报。');
  lines.push(state.flags.includes('witness') ? '我听见过异常，甚至问过里面是否还有人，却接受了“管道声”的解释，没有走过去核查。后来我写下“未发现异常声音”。这是我的错误。' : '我还需要把自己的旧草稿和当晚录音对照，不能用猜测代替自己说过和做过的事。');
  lines.push('周启明和沈予需要分别说明自己的行为。我不会替他们代签，也不会用他们的错误抹去自己的责任。');
  if (state.flags.includes('heard')) {
    lines.push('我曾在原音箱熄灯时听见回答，也在音箱断电后听见声音。来源仍不确定，不能拿它们认定事故原因。');
  } else { lines.push('今晚音箱断电后的声音来源不明。我将它单独记录，不把它写成已经证明的事故原因。'); }
  lines.push('这封信不请求你替我证明原谅。我能补交的是证言，不能替你取回失去的明天。');
  lines.push('落款：由我亲自署名。是否交存，仍等待最后一次确认。');
  return lines.join('\n\n');
}
