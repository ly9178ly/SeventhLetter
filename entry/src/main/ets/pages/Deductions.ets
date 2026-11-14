import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Deduction, Evidence, GameState, Hypothesis } from '../model/StoryModels';
import { createGame, deduce } from '../engine/StoryEngine';
import { DEDUCTIONS, EVIDENCE } from '../data/StoryData';
import { repository } from '../storage/PreferencesPort';
import { Ink } from '../components/Theme';
import { TitleBar } from '../components/TitleBar';

@Entry
@Component
struct Deductions {
  @State game: GameState = createGame();
  @State ready: boolean = false;
  @State busy: boolean = false;
  @State caseId: string = 'identity';
  @State selected: string[] = [];
  @State answer: string = '';
  @State message: string = '';
  private scroller: Scroller = new Scroller();

  onPageShow(): void { this.load(); }

  async load(): Promise<void> {
    const result = await repository(getContext(this) as common.UIAbilityContext).load();
    if (result.state && result.state.flags.includes('met_shen')) {
      this.game = result.state;
      this.ready = true;
    } else { this.ready = false; this.message = result.message || '先在第一章末尾跟随沈予进入第二章，再开展核对。'; }
  }

  active(): Deduction { return DEDUCTIONS.find(item => item.id === this.caseId) ?? DEDUCTIONS[0]; }

  candidates(): Evidence[] { return EVIDENCE.filter(item => this.active().candidates.includes(item.id)); }

  toggle(id: string): void {
    if (this.busy || !this.game.evidenceIds.includes(id)) { return; }
    if (this.selected.includes(id)) { this.selected = this.selected.filter(item => item !== id); }
    else if (this.selected.length < 2) { this.selected = this.selected.concat([id]); }
    else { this.message = '一次选择两份材料。请先取消一项，再更换。'; }
  }

  async submit(): Promise<void> {
    if (this.busy || !this.ready) { return; }
    const result = deduce(this.game, this.caseId, this.selected, this.answer);
    if (!result.ok) { this.message = result.message; return; }
    this.busy = true;
    try {
      await repository(getContext(this) as common.UIAbilityContext).save(result.state);
      this.game = result.state;
      this.message = '核对成立并已保存。' + result.message;
    } catch (error) { this.message = '核对尚未保存，请点击再次核对重试。'; }
    this.busy = false;
  }

  build() {
    Column() {
      TitleBar({ title: '证据推理', subtitle: '两份材料，一个有依据的判断' })
      if (this.ready) {
        Row({ space: 6 }) {
          ForEach(DEDUCTIONS, (item: Deduction, index: number) => {
            Button((this.game.flags.includes(item.id) ? '✓ ' : '') + ['身份', '被困原因', '声音记录'][index], { type: ButtonType.Normal })
              .id('case-' + item.id).layoutWeight(1).height(42).fontSize(12).borderRadius(8)
              .backgroundColor(this.caseId === item.id ? Ink.gold : Ink.surface)
              .fontColor(this.caseId === item.id ? Ink.background : Ink.text).enabled(!this.busy)
              .onClick(() => {
                this.caseId = item.id; this.selected = []; this.answer = ''; this.message = '';
                this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
              })
          }, (item: Deduction) => item.id)
        }.width('100%').margin({ bottom: 14 })
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            Text(this.active().question).fontSize(23).fontColor(Ink.text).lineHeight(32).width('100%')
            Text(this.active().hint).fontSize(12).fontColor(Ink.muted).lineHeight(21).width('100%')
            if (this.game.flags.includes(this.caseId)) {
              Text('已核对：' + this.active().conclusion).fontSize(13).fontColor(Ink.gold).lineHeight(24).width('100%')
            }
            Text('① 选择两份证据  ' + this.selected.length + ' / 2').fontSize(13).fontColor(Ink.gold).width('100%')
            ForEach(this.candidates(), (item: Evidence) => {
              Button({ type: ButtonType.Normal }) {
                Column({ space: 7 }) {
                  Text(this.game.evidenceIds.includes(item.id) ? (this.selected.includes(item.id) ? '✓ ' : '○ ') + item.title : '未取得的材料')
                    .fontSize(15).fontColor(Ink.text).width('100%').textAlign(TextAlign.Start)
                  Text(this.game.evidenceIds.includes(item.id) ? item.subtitle : '来源：' + item.source)
                    .fontSize(11).fontColor(Ink.muted).width('100%').textAlign(TextAlign.Start).lineHeight(20)
                }.padding(15).width('100%')
              }.id('evidence-' + item.id).width('100%').borderRadius(8).backgroundColor(Ink.surface)
                .border({ width: 1, color: this.selected.includes(item.id) ? Ink.gold : Ink.line })
                .enabled(!this.busy && this.game.evidenceIds.includes(item.id)).opacity(this.game.evidenceIds.includes(item.id) ? 1 : 0.5)
                .onClick(() => { this.toggle(item.id); })
            }, (item: Evidence) => this.caseId + ':' + item.id)
            Button('先读证据全文', { type: ButtonType.Normal }).fontSize(12).fontColor(Ink.gold)
              .backgroundColor(Ink.surface).enabled(!this.busy).onClick(() => { router.pushUrl({ url: 'pages/Archive' }); })
            Text('② 选择证据支持的判断').fontSize(13).fontColor(Ink.gold).width('100%')
            ForEach(this.active().hypotheses, (item: Hypothesis) => {
              Button({ type: ButtonType.Normal }) {
                Text((this.answer === item.id ? '● ' : '○ ') + item.label).fontSize(14).fontColor(Ink.text)
                  .width('100%').lineHeight(24).textAlign(TextAlign.Start).padding(15)
              }.id('answer-' + item.id).width('100%').backgroundColor(Ink.surface).borderRadius(8)
                .border({ width: 1, color: this.answer === item.id ? Ink.gold : Ink.line }).enabled(!this.busy)
                .onClick(() => { this.answer = item.id; this.message = ''; })
            }, (item: Hypothesis) => this.caseId + ':' + item.id)
            Text('选错不会扣分或锁死；可以重读材料，重新核对。').fontSize(11).fontColor(Ink.muted)
              .width('100%').lineHeight(21).margin({ bottom: 15 })
          }.width('100%')
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        if (this.message !== '') {
          Text(this.message).fontSize(12).fontColor(Ink.gold).lineHeight(21).width('100%')
            .constraintSize({ maxHeight: 118 }).margin({ top: 8, bottom: 8 })
        }
        Button(this.busy ? '正在保存…' : '核对并保存', { type: ButtonType.Normal }).id('submit-deduction')
          .width('100%').height(47).backgroundColor(Ink.gold).fontColor(Ink.background).borderRadius(8)
          .enabled(!this.busy && this.selected.length === 2 && this.answer !== '').onClick(() => { this.submit(); })
          .margin({ top: 8, bottom: 18 })
      } else {
        Text(this.message).fontSize(15).fontColor(Ink.muted).lineHeight(26).width('100%')
      }
    }.padding({ left: 24, right: 24 }).width('100%').height('100%').backgroundColor(Ink.background)
  }
}
