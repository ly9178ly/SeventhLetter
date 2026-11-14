import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { StoragePort, SaveRepository } from './SaveRepository';

class PreferencesPort implements StoragePort {
  private static pending: Promise<void> = Promise.resolve();
  private context: common.Context;
  constructor(context: common.Context) { this.context = context; }

  async read(): Promise<string> {
    await PreferencesPort.pending;
    const store = await preferences.getPreferences(this.context, { name: 'seventh_letter_v1' });
    const value = await store.get('autosave', '');
    if (typeof value !== 'string') { throw new Error('存档类型异常'); }
    return value;
  }

  async write(value: string): Promise<void> {
    const operation = PreferencesPort.pending.then(() => this.flushValue(value));
    PreferencesPort.pending = operation.catch(() => {});
    await operation;
  }

  private async flushValue(value: string): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: 'seventh_letter_v1' });
    // Restore the cached value if flushing fails, so a later read cannot report an unsaved state.
    const previous = await store.get('autosave', '');
    try {
      await store.put('autosave', value);
      await store.flush();
    } catch (error) {
      await store.put('autosave', previous);
      throw new Error('Preferences flush failed');
    }
  }
}

export function repository(context: common.Context): SaveRepository {
  return new SaveRepository(new PreferencesPort(context));
}
