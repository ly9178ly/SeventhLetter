import { describe, it, expect } from '@ohos/hypium';
import { canChoose, choose, createGame, nodeById, validState } from '../main/ets/engine/StoryEngine';
import { GameState } from '../main/ets/model/StoryModels';
import { EVIDENCE, STORY } from '../main/ets/data/ChapterOne';
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
        expect(seen.length < 10000).assertTrue();
      }
      expect(nodes.length).assertEqual(STORY.length);
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
