import { common } from '@kit.AbilityKit';
import { HistoryEntry } from '../model/StoryModels';
import { nodeById } from '../engine/StoryEngine';
import { repository } from '../storage/PreferencesPort';
import { Ink } from '../components/Theme';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct Records {
  @State entries: HistoryEntry[] = [];
  @State message: string = '正在读取调查记录…';
  @State savedAt: string = '';

  async aboutToAppear(): Promise<void> {
    const result = await repository(getContext(this) as common.UIAbilityContext).load();
    this.entries = result.state?.history.slice().reverse() ?? [];
    this.message = result.message || (this.entries.length === 0 ? '还没有调查记录。开始调查后，你的每一次选择都会留在这里。' : '从最近一次选择开始，回看你留下的路径。');
    this.savedAt = result.state ? new Date(result.state.updatedAt).toLocaleString() : '';
  }

  label(entry: HistoryEntry): string {
    return nodeById(entry.from)?.choices.find(choice => choice.id === entry.choiceId)?.label ?? entry.choiceId;
  }

  build() {
    Column() {
      TitleBar({ title: '调查记录', subtitle: '记忆会出错，记录也许不会' })
      Scroll() {
        Column({ space: 16 }) {
          Text(this.message).fontColor(Ink.muted).fontSize(13).lineHeight(23).width('100%')
          if (this.savedAt !== '') {
            Text('最近进度保存于 ' + this.savedAt).fontColor(Ink.gold).fontSize(11).width('100%')
          }
          ForEach(this.entries, (entry: HistoryEntry, index: number) => {
            Row({ space: 15 }) {
              Text(('0' + (this.entries.length - index)).slice(-2)).fontColor(Ink.gold).fontSize(12)
                .alignSelf(ItemAlign.Start).margin({ top: 3 })
              Column({ space: 9 }) {
                Text(nodeById(entry.from)?.location ?? '').fontColor(Ink.muted).fontSize(10)
                Text(this.label(entry)).fontColor(Ink.text).fontSize(15).lineHeight(24)
                Text('→ ' + (nodeById(entry.to)?.title ?? '')).fontColor(Ink.gold).fontSize(12)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%').padding(19).backgroundColor(Ink.surface).borderRadius(9)
          }, (entry: HistoryEntry, index: number) => index + ':' + entry.at)
          Text('最多保留最近200次选择；重开会清空当前调查。').fontSize(10).fontColor(Ink.muted)
            .margin({ top: 10, bottom: 30 })
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(Ink.background).padding({ left: 24, right: 24 })
  }
}
