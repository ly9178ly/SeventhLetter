import { common } from '@kit.AbilityKit';
import { Ending } from '../model/StoryModels';
import { ENDINGS } from '../data/StoryData';
import { nodeById } from '../engine/StoryEngine';
import { repository } from '../storage/PreferencesPort';
import { Ink } from '../components/Theme';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct Endings {
  @State owned: string[] = [];
  @State expanded: string = '';
  @State message: string = '正在读取收录记录…';

  async aboutToAppear(): Promise<void> {
    const result = await repository(getContext(this) as common.UIAbilityContext).load();
    this.owned = result.state?.endingIds ?? [];
    this.message = result.message || '实际到达后才收录正文；重开调查仍保留这些记录。';
  }

  build() {
    Column() {
      TitleBar({ title: '结局图鉴', subtitle: '写下的、留下的，和没有寄出的' })
      Scroll() {
        Column({ space: 16 }) {
          Text('已收录 ' + this.owned.length + ' / ' + ENDINGS.length).fontColor(Ink.gold).fontSize(25).width('100%')
          Text(this.message).fontColor(Ink.muted).fontSize(12).lineHeight(23).width('100%')
          ForEach(ENDINGS, (item: Ending, index: number) => {
            Column({ space: 14 }) {
              Text('结局 0' + (index + 1) + (this.owned.includes(item.id) ? ' · 已收录' : ' · 未收录'))
                .fontColor(Ink.muted).fontSize(11).width('100%')
              Text(this.owned.includes(item.id) ? item.title : '尚未写下的结尾').fontColor(Ink.text).fontSize(24).width('100%')
              Text(item.direction).fontColor(Ink.gold).fontSize(13).lineHeight(23).width('100%')
              if (this.owned.includes(item.id)) {
                Button(this.expanded === item.id ? '收起结尾' : '回看结尾', { type: ButtonType.Normal })
                  .id('ending-' + item.id).fontColor(Ink.gold).backgroundColor(Ink.background).fontSize(12)
                  .onClick(() => { this.expanded = this.expanded === item.id ? '' : item.id; })
                if (this.expanded === item.id) {
                  Text(nodeById(item.nodeId)?.paragraphs.join('\n\n') ?? '').fontColor(Ink.text)
                    .fontSize(14).lineHeight(26).width('100%')
                }
              }
            }.padding(20).backgroundColor(Ink.surface).borderRadius(9).width('100%')
          }, (item: Ending) => item.id)
          Text('回看正文不会改变调查进度。要体验另一种选择，可在剧情结尾返回抉择前。')
            .fontSize(11).fontColor(Ink.muted).lineHeight(22).width('100%').margin({ bottom: 25 })
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
    }.padding({ left: 24, right: 24 }).width('100%').height('100%').backgroundColor(Ink.background)
  }
}
