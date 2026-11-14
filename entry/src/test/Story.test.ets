import { describe, it, expect } from '@ohos/hypium';
import { canChoose, choose, createGame, deduce, letterDraft, nodeById, validState } from '../main/ets/engine/StoryEngine';
import { GameState } from '../main/ets/model/StoryModels';
import { DEDUCTIONS, ENDINGS, EVIDENCE, KNOWN_FLAGS, STORY } from '../main/ets/data/StoryData';
import { SaveRepository, StoragePort } from '../main/ets/storage/SaveRepository';

class MockStorage implements StoragePort {
  value: string = '';
  failRead: boolean = false;
  failWrite: boolean = false;
  writes: number = 0;
  async read(): Promise<string> {
    if (this.failRead) { throw new Error('mock read failure'); }
    return this.value;
  }
  async write(value: string): Promise<void> {
    if (this.failWrite) { throw new Error('mock write failure'); }
    this.value = value;
    this.writes++;
  }
}

function play(ids: string[]): GameState {
  let state = createGame(1000);
  ids.forEach((id: string, index: number) => {
    const result = choose(state, id, 1001 + index);
    expect(result.ok).assertTrue();
    state = result.state;
  });
  return state;
}

const route: string[] = ['enter', 'open_letter', 'follow_photo', 'turn_photo', 'ask_photo',
  'ask_register', 'compare_photo', 'record_facts'];

function fullInvestigation(): GameState {
  let state = play(route.concat(['meet_shen', 'to_archive', 'door_docs', 'maintenance_back',
    'photo_docs', 'original_back', 'report_docs', 'aftermath_back']));
  state = deduce(state, 'identity', ['original', 'clearance'], 'volunteer').state;
  state = deduce(state, 'cause', ['letter2', 'incident'], 'fault').state;
  ['confront_shen', 'to_apology', 'read_self', 'to_writing'].forEach(id => {
    const result = choose(state, id); expect(result.ok).assertTrue(); state = result.state;
  });
  return state;
}

export default function storyTest(): void {
  describe('SeventhLetter engine and mock persistence', () => {
    it('new investigation has no evidence and independent arrays', 0, () => {
      const first = createGame(1000);
      const second = createGame(1000);
      first.evidenceIds.push('letter1');
      expect(second.evidenceIds.length).assertEqual(0);
      expect(second.nodeId).assertEqual('arrival');
      expect(validState(second)).assertTrue();
    });
    it('locked option is rejected without modifying original state', 0, () => {
      const state = play(['enter']);
      const before = JSON.stringify(state);
      const result = choose(state, 'call_name');
      expect(result.ok).assertFalse();
      expect(JSON.stringify(state)).assertEqual(before);
    });
    it('first letter unlocks the name and saves the evidence once', 0, () => {
      const state = play(['enter', 'open_letter', 'keep_letter']);
      const option = nodeById('reading')!.choices.find(item => item.id === 'call_name')!;
      expect(canChoose(state, option)).assertTrue();
      const again = choose(state, 'open_letter');
      expect(again.state.evidenceIds.length).assertEqual(1);
      expect(state.nodeId).assertEqual('reading');
    });
    it('unknown choice is rejected', 0, () => {
      const state = createGame();
      expect(choose(state, 'not_a_choice').ok).assertFalse();
      expect(state.history.length).assertEqual(0);
    });
    it('complete factual route reaches chapter end with four unique clues', 0, () => {
      const state = play(route);
      expect(state.nodeId).assertEqual('chapter_end');
      expect(state.evidenceIds.length).assertEqual(4);
      expect(state.flags.includes('recorded')).assertTrue();
      expect(state.flags.includes('heard')).assertFalse();
      expect(validState(state)).assertTrue();
    });
    it('unexplained voice route requires its earlier flag', 0, () => {
      const state = play(['enter', 'open_letter', 'keep_letter', 'call_name', 'trace_voice',
        'turn_photo', 'ask_photo', 'ask_register', 'compare_photo', 'record_voice']);
      expect(state.flags.includes('answered')).assertTrue();
      expect(state.flags.includes('heard')).assertTrue();
      expect(state.nodeId).assertEqual('chapter_end');
    });
    it('factual route cannot claim to have heard a voice', 0, () => {
      const state = play(route.slice(0, -1));
      expect(choose(state, 'record_voice').ok).assertFalse();
    });
    it('journal retains most recent 200 entries', 0, () => {
      let state = play(['enter', 'open_letter', 'keep_letter']);
      for (let index = 0; index < 120; index++) {
        state = choose(state, 'open_letter', 2000 + index * 2).state;
        state = choose(state, 'keep_letter', 2001 + index * 2).state;
      }
      expect(state.history.length).assertEqual(200);
      expect(state.evidenceIds.length).assertEqual(1);
      expect(validState(state)).assertTrue();
    });
    it('story has unique identifiers and all references are defined', 0, () => {
      STORY.forEach((node, index) => {
        expect(STORY.findIndex(item => item.id === node.id)).assertEqual(index);
        node.choices.forEach((choice, choiceIndex) => {
          expect(node.choices.findIndex(item => item.id === choice.id)).assertEqual(choiceIndex);
          expect(nodeById(choice.target) !== undefined).assertTrue();
          choice.grants.concat(choice.requires).forEach(id => {
            expect(EVIDENCE.some(item => item.id === id)).assertTrue();
          });
        });
      });
    });
    it('all story nodes are reachable and no reachable state is stuck', 0, () => {
      const queue: GameState[] = [createGame()];
      const seen: string[] = [];
      const nodes: string[] = [];
      while (queue.length > 0) {
        const state = queue.shift()!;
        const key = state.nodeId + ':' + state.evidenceIds.slice().sort().join(',') + ':' + state.flags.slice().sort().join(',');
        if (seen.includes(key)) { continue; }
        seen.push(key);
        if (!nodes.includes(state.nodeId)) { nodes.push(state.nodeId); }
        const available = nodeById(state.nodeId)!.choices.filter(item => canChoose(state, item));
        expect(available.length > 0).assertTrue();
        available.forEach(item => { queue.push(choose(state, item.id).state); });
        DEDUCTIONS.forEach(item => {
          if (!state.flags.includes(item.id)) {
            const result = deduce(state, item.id, item.evidenceIds, item.answer);
            if (result.ok) { queue.push(result.state); }
          }
        });
        expect(seen.length < 20000).assertTrue();
      }
      expect(nodes.length).assertEqual(STORY.length);
    });
    it('every flag reference has a known producer', 0, () => {
      STORY.forEach(node => node.choices.forEach(choice => {
        choice.sets.concat(choice.requiresFlags).forEach(id => { expect(KNOWN_FLAGS.includes(id)).assertTrue(); });
      }));
      DEDUCTIONS.forEach(item => { expect(KNOWN_FLAGS.includes(item.id)).assertTrue(); });
    });
    it('old first chapter ending now continues to chapter two', 0, () => {
      const result = choose(play(route), 'meet_shen');
      expect(result.ok).assertTrue();
      expect(result.state.nodeId).assertEqual('shen');
      expect(result.state.evidenceIds.includes('letter3')).assertTrue();
    });
    it('unowned evidence cannot be used for deduction', 0, () => {
      const state = play(route.concat(['meet_shen']));
      const before = JSON.stringify(state);
      expect(deduce(state, 'identity', ['original', 'clearance'], 'volunteer').ok).assertFalse();
      expect(JSON.stringify(state)).assertEqual(before);
    });
    it('deduction rejects wrong pair duplicates extra materials and wrong answer', 0, () => {
      const state = fullInvestigation();
      expect(deduce(state, 'witness', ['letter6', 'letter5'], 'unchecked').ok).assertFalse();
      expect(deduce(state, 'witness', ['letter6', 'letter6'], 'unchecked').ok).assertFalse();
      expect(deduce(state, 'witness', ['letter6', 'recording', 'letter5'], 'unchecked').ok).assertFalse();
      expect(deduce(state, 'witness', ['letter6', 'recording'], 'certain').ok).assertFalse();
      expect(state.flags.includes('witness')).assertFalse();
    });
    it('deduction accepts either order and repeated confirmation is idempotent', 0, () => {
      const state = fullInvestigation();
      const first = deduce(state, 'witness', ['recording', 'letter6'], 'unchecked');
      const second = deduce(first.state, 'witness', ['letter6', 'recording'], 'unchecked');
      expect(first.ok && second.ok).assertTrue();
      expect(second.state.flags.filter(id => id === 'witness').length).assertEqual(1);
      expect(state.flags.includes('witness')).assertFalse();
      expect(validState(second.state)).assertTrue();
    });
    it('main ending requires all three findings and final confirmation', 0, () => {
      let state = fullInvestigation();
      expect(state.evidenceIds.length).assertEqual(EVIDENCE.length);
      expect(choose(state, 'sign_letter').ok).assertFalse();
      state = deduce(state, 'witness', ['letter6', 'recording'], 'unchecked').state;
      const pending = choose(state, 'sign_letter');
      expect(pending.state.nodeId).assertEqual('confirm_seventh');
      expect(pending.state.endingIds.length).assertEqual(0);
      const final = choose(pending.state, 'seal_seventh');
      expect(final.state.nodeId).assertEqual('ending_seventh');
      expect(final.state.endingIds.includes('seventh')).assertTrue();
      expect(validState(final.state)).assertTrue();
    });
    it('all four endings can be collected and replay preserves findings', 0, () => {
      let state = deduce(fullInvestigation(), 'witness', ['letter6', 'recording'], 'unchecked').state;
      const actions: string[] = ['deny_papers', 'seal_blank', 'reconsider_blank', 'return_papers', 'seal_return',
        'reconsider_return', 'keep_draft', 'seal_unsent', 'reconsider_unsent', 'sign_letter', 'seal_seventh'];
      actions.forEach(id => { const result = choose(state, id); expect(result.ok).assertTrue(); state = result.state; });
      expect(state.endingIds.length).assertEqual(ENDINGS.length);
      expect(state.flags.includes('witness')).assertTrue();
      const restarted = createGame(2000, state.endingIds);
      expect(restarted.evidenceIds.length).assertEqual(0);
      expect(restarted.history.length).assertEqual(0);
      expect(restarted.endingIds.length).assertEqual(4);
      restarted.endingIds.pop();
      expect(state.endingIds.length).assertEqual(4);
    });
    it('cancel ending choice leaves gallery unchanged', 0, () => {
      let state = fullInvestigation();
      ['deny_papers', 'cancel_blank', 'return_papers', 'cancel_return', 'keep_draft', 'cancel_unsent'].forEach(id => {
        const result = choose(state, id); expect(result.ok).assertTrue(); state = result.state;
      });
      expect(state.nodeId).assertEqual('writing');
      expect(state.endingIds.length).assertEqual(0);
    });
    it('draft distinguishes unverified claims from established responsibility', 0, () => {
      const pending = fullInvestigation();
      expect(letterDraft(pending).includes('我还需要把自己的旧草稿和当晚录音对照')).assertTrue();
      const checked = deduce(pending, 'witness', ['letter6', 'recording'], 'unchecked').state;
      expect(letterDraft(checked).includes('这是我的错误')).assertTrue();
      expect(letterDraft(checked).includes('你在那晚遇难')).assertTrue();
      expect(letterDraft(checked).includes('我还需要把自己的旧草稿和当晚录音对照')).assertFalse();
    });
    it('legacy v1 save upgrades without rewriting source or dropping progress', 0, async () => {
      const store = new MockStorage();
      const old = play(route);
      store.value = JSON.stringify(old).replace('"schemaVersion":2', '"schemaVersion":1').replace(',"endingIds":[]', '');
      const raw = store.value;
      const loaded = await new SaveRepository(store).load();
      expect(loaded.status).assertEqual('ready');
      expect(loaded.state!.schemaVersion).assertEqual(2);
      expect(loaded.state!.nodeId).assertEqual('chapter_end');
      expect(loaded.state!.evidenceIds.length).assertEqual(4);
      expect(loaded.state!.history.length).assertEqual(old.history.length);
      expect(loaded.state!.endingIds.length).assertEqual(0);
      expect(store.value).assertEqual(raw);
      expect(store.writes).assertEqual(0);
    });
    it('malformed legacy save and missing gallery in v2 are rejected', 0, async () => {
      const store = new MockStorage();
      store.value = '{"schemaVersion":1,"nodeId":"chapter_end"}';
      expect((await new SaveRepository(store).load()).status).assertEqual('damaged');
      store.value = JSON.stringify(createGame()).replace(',"endingIds":[]', '');
      expect((await new SaveRepository(store).load()).status).assertEqual('damaged');
    });
    it('forged findings and invalid gallery ids are rejected', 0, () => {
      const state = createGame(); state.flags = ['identity'];
      expect(validState(state)).assertFalse();
      state.flags = []; state.endingIds = ['unknown'];
      expect(validState(state)).assertFalse();
      state.endingIds = ['seventh', 'seventh'];
      expect(validState(state)).assertFalse();
    });
    it('mock roundtrip restores node clues flags and choice history', 0, async () => {
      const store = new MockStorage();
      const state = play(route);
      await new SaveRepository(store).save(state);
      const restored = await new SaveRepository(store).load();
      expect(restored.status).assertEqual('ready');
      expect(JSON.stringify(restored.state)).assertEqual(JSON.stringify(state));
    });
    it('empty storage returns missing and does not write', 0, async () => {
      const store = new MockStorage();
      expect((await new SaveRepository(store).load()).status).assertEqual('missing');
      expect(store.writes).assertEqual(0);
    });
    it('malformed JSON is preserved and reported damaged', 0, async () => {
      const store = new MockStorage(); store.value = '{broken';
      expect((await new SaveRepository(store).load()).status).assertEqual('damaged');
      expect(store.value).assertEqual('{broken');
      expect(store.writes).assertEqual(0);
    });
    it('unsupported save version is preserved', 0, async () => {
      const store = new MockStorage();
      const state = createGame(); state.schemaVersion = 99;
      store.value = JSON.stringify(state);
      expect((await new SaveRepository(store).load()).status).assertEqual('damaged');
      expect(store.writes).assertEqual(0);
    });
    it('unknown node duplicate evidence and unknown flags fail validation', 0, () => {
      const badNode = createGame(); badNode.nodeId = 'missing';
      const duplicate = createGame(); duplicate.evidenceIds = ['letter1', 'letter1'];
      const badFlag = createGame(); badFlag.flags = ['invalid'];
      expect(validState(badNode)).assertFalse();
      expect(validState(duplicate)).assertFalse();
      expect(validState(badFlag)).assertFalse();
    });
    it('read failure returns retryable error without rewriting', 0, async () => {
      const store = new MockStorage(); store.failRead = true;
      expect((await new SaveRepository(store).load()).status).assertEqual('error');
      expect(store.writes).assertEqual(0);
    });
    it('write failure propagates and previous saved state remains', 0, async () => {
      const store = new MockStorage();
      await new SaveRepository(store).save(createGame(1000));
      const before = store.value;
      store.failWrite = true;
      let rejected = false;
      try { await new SaveRepository(store).save(play(route)); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      expect(store.value).assertEqual(before);
    });
    it('invalid state is never written', 0, async () => {
      const store = new MockStorage();
      const state = createGame(); state.nodeId = 'missing';
      let rejected = false;
      try { await new SaveRepository(store).save(state); } catch (error) { rejected = true; }
      expect(rejected).assertTrue();
      expect(store.writes).assertEqual(0);
    });
    it('oversized save is rejected without changes', 0, async () => {
      const store = new MockStorage(); store.value = 'x'.repeat(150001);
      expect((await new SaveRepository(store).load()).status).assertEqual('damaged');
      expect(store.writes).assertEqual(0);
    });
  });
}
