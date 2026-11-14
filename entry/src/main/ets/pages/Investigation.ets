import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Choice, GameState, StoryNode } from '../model/StoryModels';
import { canChoose, choose, createGame, nodeById } from '../engine/StoryEngine';
import { STORY } from '../data/ChapterOne';
import { repository } from '../storage/PreferencesPort';
import { Ink } from '../components/Theme';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct Investigation {
  @State game: GameState = createGame();
  @State ready: boolean = false;
  @State busy: boolean = false;
  @State message: string = '';
  @State saveMessage: string = '';
  private scroller: Scroller = new Scroller();

  onPageShow(): void { this.load(); }

  async load(): Promise<void> {
    this.ready = false;
    const result = await repository(getContext(this) as common.UIAbilityContext).load();
    if (result.state) {
      this.game = result.state;
      this.ready = true;
      this.message = '';
      this.saveMessage = '进度已恢复 · 每次选择后自动保存';
    } else { this.message = result.message || '还没有调查存档，请返回主页开始新调查。'; }
  }

  current(): StoryNode { return nodeById(this.game.nodeId) ?? STORY[0]; }

  async act(choice: Choice): Promise<void> {
    if (this.busy || !this.ready) { return; }
    const result = choose(this.game, choice.id);
    if (!result.ok) { this.message = result.message; return; }
    this.busy = true;
    this.message = '';
    try {
      await repository(getContext(this) as common.UIAbilityContext).save(result.state);
      const gained = result.state.evidenceIds.length - this.game.evidenceIds.length;
      this.game = result.state;
      this.saveMessage = gained > 0 ? '新证据已归档 · 进度已保存' : '进度已自动保存';
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (error) { this.message = '保存失败，这次选择尚未生效。请再次点击选项重试。'; }
    this.busy = false;
  }

  async save(): Promise<void> {
    if (this.busy || !this.ready) { return; }
    this.busy = true;
    try {
      await repository(getContext(this) as common.UIAbilityContext).save(this.game);
      this.saveMessage = '已手动保存，可放心退出应用';
      this.message = '';
    } catch (error) { this.message = '存档暂未写入，请点击保存重试。'; }
    this.busy = false;
  }

  build() {
    Column() {
      TitleBar({ title: '旧馆调查', subtitle: 'THE SEVENTH LETTER' })
      if (this.ready) {
        Row() {
          Text(this.current().location).fontSize(12).fontColor(Ink.gold)
          Blank()
          Text('证据 ' + this.game.evidenceIds.length + ' / 4').fontSize(11).fontColor(Ink.muted)
        }.width('100%').padding({ bottom: 16 })
        Scroll(this.scroller) {
          Column({ space: 0 }) {
            Text(this.current().chapter).fontSize(11).fontColor(Ink.muted).letterSpacing(2)
              .width('100%').margin({ top: 10, bottom: 17 })
            Text(this.current().title).fontSize(29).fontFamily('serif').fontColor(Ink.text)
              .fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 25 })
            ForEach(this.current().paragraphs, (paragraph: string) => {
              Text(paragraph).fontSize(16).lineHeight(29).fontColor(Ink.text)
                .width('100%').margin({ bottom: 19 })
            }, (paragraph: string) => paragraph)
            Row() {
              Divider().color(Ink.line).layoutWeight(1)
              Text('你决定').fontSize(11).fontColor(Ink.gold).margin({ left: 14, right: 14 })
              Divider().color(Ink.line).layoutWeight(1)
            }.margin({ top: 12, bottom: 22 })
            ForEach(this.current().choices, (choice: Choice, index: number) => {
              Column({ space: 7 }) {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 14 }) {
                    Text('0' + (index + 1)).fontSize(12).fontColor(Ink.gold)
                    Text(choice.label).fontSize(14).fontColor(Ink.text).layoutWeight(1)
                      .textAlign(TextAlign.Start).lineHeight(22)
                    Text(canChoose(this.game, choice) ? '→' : '锁定').fontSize(12).fontColor(Ink.muted)
                  }.padding(16).width('100%')
                }.width('100%').constraintSize({ minHeight: 56 }).backgroundColor(Ink.surface)
                  .borderRadius(10).border({ width: 1, color: Ink.line })
                  .enabled(!this.busy && canChoose(this.game, choice))
                  .opacity(canChoose(this.game, choice) ? 1 : 0.5)
                  .onClick(() => { this.act(choice); })
                if (!canChoose(this.game, choice)) {
                  Text(choice.hint || '还需要更多线索').fontSize(11).fontColor(Ink.muted).width('100%')
                }
              }.width('100%').margin({ bottom: 13 })
            }, (choice: Choice) => this.game.nodeId + ':' + choice.id)
          }.width('100%').padding({ bottom: 12 })
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      } else {
        Blank()
        Text(this.message || '正在展开调查档案…').fontColor(Ink.text).lineHeight(25)
        Button('重新读取').backgroundColor(Ink.surface).fontColor(Ink.gold)
          .margin({ top: 18 }).onClick(() => { this.load(); })
        Blank()
      }
      if (this.ready && this.message !== '') {
        Text(this.message).fontSize(12).fontColor('#F1B7A1').lineHeight(20).width('100%')
          .padding({ top: 8, bottom: 8 })
      }
      if (this.ready) {
        Text(this.busy ? '正在写入存档…' : this.saveMessage).fontSize(10).fontColor(Ink.muted)
          .width('100%').padding({ top: 12, bottom: 12 })
        Row({ space: 8 }) {
          Button('证据档案', { type: ButtonType.Normal }).layoutWeight(1).fontSize(12)
            .height(44).borderRadius(8).backgroundColor(Ink.surface).fontColor(Ink.text).enabled(!this.busy)
            .onClick(() => { router.pushUrl({ url: 'pages/Archive' }); })
          Button('调查记录', { type: ButtonType.Normal }).layoutWeight(1).fontSize(12)
            .height(44).borderRadius(8).backgroundColor(Ink.surface).fontColor(Ink.text).enabled(!this.busy)
            .onClick(() => { router.pushUrl({ url: 'pages/Records' }); })
          Button('保存', { type: ButtonType.Normal }).width(66).fontSize(12)
            .height(44).borderRadius(8).backgroundColor(Ink.gold).fontColor(Ink.background).enabled(!this.busy)
            .onClick(() => { this.save(); })
        }.width('100%').margin({ bottom: 18 })
      }
    }.padding({ left: 24, right: 24 }).width('100%').height('100%').backgroundColor(Ink.background)
  }
}
