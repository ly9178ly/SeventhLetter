import { common } from '@kit.AbilityKit';
import { Evidence } from '../model/StoryModels';
import { EVIDENCE } from '../data/ChapterOne';
import { repository } from '../storage/PreferencesPort';
import { Ink } from '../components/Theme';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct Archive {
  @State owned: string[] = [];
  @State expanded: string = '';
  @State message: string = '正在整理档案…';

  async aboutToAppear(): Promise<void> {
    const result = await repository(getContext(this) as common.UIAbilityContext).load();
    this.owned = result.state?.evidenceIds ?? [];
    this.message = result.message || '只记录你亲手找到的证据。点击已归档的卡片阅读全文。';
  }

  build() {
    Column() {
      TitleBar({ title: '证据档案', subtitle: '不要急着相信任何一种解释' })
      Scroll() {
        Column({ space: 15 }) {
          Row() {
            Text('本章归档').fontSize(12).fontColor(Ink.muted)
            Blank()
            Text(this.owned.length + ' / ' + EVIDENCE.length).fontSize(26).fontColor(Ink.gold)
          }.width('100%').margin({ top: 6 })
          Text(this.message).fontSize(13).fontColor(Ink.muted).lineHeight(22).width('100%')
            .margin({ bottom: 10 })
          ForEach(EVIDENCE, (item: Evidence, index: number) => {
            Column({ space: 13 }) {
              Row() {
                Text('档案 0' + (index + 1)).fontSize(10)
                  .fontColor(this.owned.includes(item.id) ? '#64736A' : Ink.muted).letterSpacing(2)
                Blank()
                Text(this.owned.includes(item.id) ? (this.expanded === item.id ? '收起 −' : '阅读 +') : '尚未找到')
                  .fontSize(11).fontColor(this.owned.includes(item.id) ? '#64736A' : Ink.muted)
              }.width('100%')
              Text(this.owned.includes(item.id) ? item.title : '未归档的线索').fontSize(23).fontFamily('serif')
                .fontColor(this.owned.includes(item.id) ? Ink.paperInk : Ink.muted).width('100%')
              if (this.owned.includes(item.id)) {
                Text(item.subtitle).fontSize(12).fontColor('#59675D').width('100%')
                if (this.expanded === item.id) {
                  Divider().color('#C4BDA9')
                  Text(item.body).fontSize(15).fontColor(Ink.paperInk).lineHeight(29).width('100%')
                  Text('来源 / ' + item.source).fontSize(10).fontColor('#64736A').width('100%').margin({ top: 8 })
                }
              }
            }.padding(21).width('100%').borderRadius(5)
              .backgroundColor(this.owned.includes(item.id) ? Ink.paper : Ink.surface)
              .onClick(() => {
                if (this.owned.includes(item.id)) { this.expanded = this.expanded === item.id ? '' : item.id; }
              })
              .accessibilityText(this.owned.includes(item.id) ? item.title + '，点击展开或收起全文' : '未归档的线索')
          }, (item: Evidence) => item.id)
          Text('文字可以被改写。留下的痕迹未必会。').fontSize(11).fontColor(Ink.muted)
            .margin({ top: 12, bottom: 30 })
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
    }.padding({ left: 24, right: 24 }).height('100%').width('100%').backgroundColor(Ink.background)
  }
}
