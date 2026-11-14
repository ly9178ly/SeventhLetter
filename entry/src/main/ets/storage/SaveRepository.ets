import { GameState, LoadResult } from '../model/StoryModels';
import { validState } from '../engine/StoryEngine';

export interface StoragePort {
  read(): Promise<string>;
  write(value: string): Promise<void>;
}

export class SaveRepository {
  private port: StoragePort;
  constructor(port: StoragePort) { this.port = port; }

  async load(): Promise<LoadResult> {
    let raw: string;
    try {
      raw = await this.port.read();
    } catch (error) {
      return { status: 'error', state: null, message: '暂时无法读取存档。请重试；原记录不会自动覆盖。' };
    }
    try {
      if (raw === '') { return { status: 'missing', state: null, message: '' }; }
      if (raw.length > 150000) { return { status: 'damaged', state: null, message: '存档超过支持的大小，原记录已保留。' }; }
      const state = JSON.parse(raw) as GameState;
      if (!validState(state)) {
        return { status: 'damaged', state: null, message: '存档内容或版本不受支持，原记录已保留。' };
      }
      return { status: 'ready', state, message: '' };
    } catch (error) {
      return { status: 'damaged', state: null, message: '存档内容无法解析，原记录已保留。可重试读取或确认后重新开始。' };
    }
  }

  async save(state: GameState): Promise<void> {
    if (!validState(state)) { throw new Error('拒绝保存无效调查状态'); }
    await this.port.write(JSON.stringify(state));
  }
}
