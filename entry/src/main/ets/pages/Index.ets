import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { GameState } from '../model/StoryModels';
import { createGame, nodeById } from '../engine/StoryEngine';
import { repository } from '../storage/PreferencesPort';
import { Ink } from '../components/Theme';

@Entry
@Component
struct Index {
  @State saved: GameState | null = null;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State message: string = '';
  @State hasRecord: boolean = false;

  onPageShow(): void { this.refresh(); }

  async refresh(): Promise<void> {
    this.loading = true;
    const result = await repository(getContext(this) as common.UIAbilityContext).load();
    this.saved = result.state;
    this.message = result.message;
    this.hasRecord = result.status !== 'missing';
    this.loading = false;
  }

  begin(): void {
    if (this.loading || this.busy) { return; }
    if (this.hasRecord) {
      AlertDialog.show({
        title: '开始新的调查？', message: '这会替换当前自动存档。已经完成的调查记录也会清空。',
        primaryButton: { value: '保留当前调查', action: () => {} },
        secondaryButton: { value: '开始新调查', action: () => { this.startNew(); } }
      });
    } else { this.startNew(); }
  }

  async startNew(): Promise<void> {
    this.busy = true;
    try {
      const state = createGame();
      await repository(getContext(this) as common.UIAbilityContext).save(state);
      this.saved = state;
      this.hasRecord = true;
      router.pushUrl({ url: 'pages/Investigation' });
    } catch (error) { this.message = '新调查未能保存，请重试。'; }
    this.busy = false;
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Row() {
          Text('第 七 封 信').fontSize(12).fontColor(Ink.gold).letterSpacing(4)
          Blank()
          Text('离线互动叙事').fontSize(11).fontColor(Ink.muted)
        }.width('100%').padding({ top: 24, bottom: 34 })
        Column({ space: 12 }) {
          Text('旧馆档案  /  VOL. 01').fontSize(11).fontColor(Ink.muted).letterSpacing(3)
          Text('未寄出的\n第七封信').fontSize(40).fontWeight(FontWeight.Medium)
            .fontFamily('serif').fontColor(Ink.text).lineHeight(53).letterSpacing(5)
          Text('六封信指向过去。\n最后一封，正等你写下收件人。')
            .fontSize(14).fontColor(Ink.muted).lineHeight(25)
        }.alignItems(HorizontalAlign.Start).width('100%')
        Image($r('app.media.letter_cover')).width('100%').height(190).objectFit(ImageFit.Contain)
          .margin({ top: 12, bottom: 12 }).accessibilityText('一封封着暗红火漆的旧信，编号07')
        Text('「如果你又坐在这里，先不要回头。」').fontSize(13).fontColor(Ink.gold)
          .width('100%').margin({ bottom: 25 })
        if (this.message !== '') {
          Text(this.message).fontColor('#F1B7A1').fontSize(13).lineHeight(21)
            .width('100%').margin({ bottom: 12 })
          Button('重新读取存档').fontColor(Ink.text).backgroundColor(Ink.surface)
            .onClick(() => { this.refresh(); }).margin({ bottom: 12 })
        }
        if (this.saved !== null) {
          Button('继续调查    →', { type: ButtonType.Normal })
            .width('100%').height(53).borderRadius(10).backgroundColor(Ink.gold)
            .fontColor(Ink.background).fontSize(16).fontWeight(FontWeight.Medium)
            .enabled(!this.loading && !this.busy)
            .onClick(() => { router.pushUrl({ url: 'pages/Investigation' }); })
          Text(nodeById(this.saved.nodeId)?.title ?? '上次的调查')
            .fontSize(11).fontColor(Ink.muted).margin({ top: 10, bottom: 14 })
        }
        Button(this.loading ? '正在读取档案…' : (this.busy ? '正在保存…' : '开始新的调查'), { type: ButtonType.Normal })
          .width('100%').height(51).borderRadius(10)
          .backgroundColor(this.saved === null ? Ink.gold : Ink.surface)
          .fontColor(this.saved === null ? Ink.background : Ink.text).fontSize(15)
          .enabled(!this.loading && !this.busy).onClick(() => { this.begin(); })
        Row({ space: 12 }) {
          Button('证据档案', { type: ButtonType.Normal }).layoutWeight(1).height(48)
            .backgroundColor(Ink.surface).fontColor(Ink.text).borderRadius(10)
            .onClick(() => { router.pushUrl({ url: 'pages/Archive' }); })
          Button('调查记录', { type: ButtonType.Normal }).layoutWeight(1).height(48)
            .backgroundColor(Ink.surface).fontColor(Ink.text).borderRadius(10)
            .onClick(() => { router.pushUrl({ url: 'pages/Records' }); })
        }.width('100%').margin({ top: 12, bottom: 28 })
        Text('第一章 · 可玩开发版 0.1\n纯本地运行 · 无需联网').fontSize(10).fontColor(Ink.muted)
          .lineHeight(19).textAlign(TextAlign.Center).margin({ bottom: 26 })
      }.padding({ left: 28, right: 28 }).width('100%').constraintSize({ maxWidth: 560 })
    }.width('100%').height('100%').backgroundColor(Ink.background).scrollBar(BarState.Off)
  }
}
