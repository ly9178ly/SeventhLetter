import { router } from '@kit.ArkUI';
import { Ink } from './Theme';

@Component
export struct TitleBar {
  @Prop title: string = '';
  @Prop subtitle: string = '';

  build() {
    Row({ space: 14 }) {
      Button('‹', { type: ButtonType.Normal })
        .fontSize(30).fontColor(Ink.text).backgroundColor(Ink.surface)
        .width(44).height(44).borderRadius(12)
        .accessibilityText('返回上一页')
        .onClick(() => { router.back(); })
      Column({ space: 4 }) {
        Text(this.title).fontSize(21).fontColor(Ink.text).fontWeight(FontWeight.Medium)
        Text(this.subtitle).fontSize(11).fontColor(Ink.muted).letterSpacing(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding({ top: 16, bottom: 20 })
  }
}
