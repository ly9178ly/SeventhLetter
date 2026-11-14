import { Deduction, Ending, Evidence, StoryNode } from '../model/StoryModels';
import { EVIDENCE as FIRST_EVIDENCE, STORY as FIRST_STORY } from './ChapterOne';
import { LATER_EVIDENCE, LATER_STORY } from './LaterChapters';

export const EVIDENCE: Evidence[] = FIRST_EVIDENCE.concat(LATER_EVIDENCE);
export const STORY: StoryNode[] = FIRST_STORY.concat(LATER_STORY);
export const KNOWN_FLAGS: string[] = ['answered', 'questioned', 'recorded', 'heard', 'met_shen', 'staged', 'identity', 'cause', 'witness'];
export const ENDINGS: Ending[] = [
  { id: 'blank', nodeId: 'ending_blank', title: '空白收件人', direction: '选择否认关联，结束核查。' },
  { id: 'return', nodeId: 'ending_return', title: '归还', direction: '把材料交回周启明，由他处理。' },
  { id: 'unsent', nodeId: 'ending_unsent', title: '未寄出', direction: '保留草稿与材料，暂时不开口。' },
  { id: 'seventh', nodeId: 'ending_seventh', title: '第七封信', direction: '核对事实，保留证据，署名承担自己的责任。' }
];

export const DEDUCTIONS: Deduction[] = [
  {
    id: 'identity', question: '你与三年前的清场有什么关系？', hint: '需要知道你在哪里，以及你签过什么。',
    candidates: ['original', 'clearance', 'photo', 'notice'], evidenceIds: ['original', 'clearance'],
    hypotheses: [
      { id: 'visitor', label: '我只是今晚收到消息的访客' },
      { id: 'volunteer', label: '我是当晚签过清场确认的志愿者' },
      { id: 'stranger', label: '合影中多出的人无法辨认' }
    ], answer: 'volunteer', conclusion: '原版合影与清场单共同确认：你曾参与当晚清场，不能以“后来听说”代替自己的经历。'
  },
  {
    id: 'cause', question: '为什么林知秋没有及时被发现？', hint: '将事前提醒与事故后确认的事实相互核对。',
    candidates: ['letter2', 'incident', 'register', 'letter3'], evidenceIds: ['letter2', 'incident'],
    hypotheses: [
      { id: 'ritual', label: '她因校园传闻而主动躲起来' },
      { id: 'fault', label: '门锁故障未处理，清场未逐室核查' },
      { id: 'murder', label: '现有证据已证明有人蓄意杀害她' }
    ], answer: 'fault', conclusion: '事前门锁提醒与事故通报相互印证：已知故障和未核查清场延误发现，林知秋遇难。不能据此断言蓄意杀人。'
  },
  {
    id: 'witness', question: '你当时真的没有听见异常吗？', hint: '一份自己的旧说明，加上另一份独立保存的声音记录。',
    candidates: ['letter6', 'recording', 'letter5', 'register'], evidenceIds: ['letter6', 'recording'],
    hypotheses: [
      { id: 'silence', label: '我当晚没有发现任何异常声音' },
      { id: 'certain', label: '我当时确知有人被困并决定伤害她' },
      { id: 'unchecked', label: '我听到疑似求救，接受解释却未核查' }
    ], answer: 'unchecked', conclusion: '自己的草稿与原录音相互印证：你听见了并提出疑问，随后未去核查。承认这一点，无需虚构自己当时知道全部后果。'
  }
];
