import { Choice, Evidence, StoryNode } from '../model/StoryModels';

export function option(id: string, label: string, target: string, grants: string[] = [],
  requires: string[] = [], sets: string[] = [], requiresFlags: string[] = [], hint: string = ''): Choice {
  return { id, label, target, grants, requires, sets, requiresFlags, hint };
}

export const EVIDENCE: Evidence[] = [
  {
    id: 'letter1', title: '第一封信', subtitle: '收件人：明天的我', source: '旧馆阅览区 · 第七张桌子',
    body: '如果你又坐在这里，先不要回头。\n\n你会听见三下敲击声。那不是有人在找你，是我在确认你还记得。\n\n别相信墙上的日期。去找那张少了一个人的合影。\n\n—— 林知秋，11月14日\n\n纸张边缘有新鲜的折痕。落款年份的位置被仔细剪去。'
  },
  {
    id: 'notice', title: '闭馆通知', subtitle: '今晚 21:17 后禁止进入', source: '走廊 · 通知栏',
    body: '旧馆将于11月14日21:17关闭。\n维护期间禁止进入。值班员：周启明。\n\n纸面很新，左下角却露出旧通知的一角：三年前的同月同日，闭馆时间也是21:17。'
  },
  {
    id: 'photo', title: '少了一人的合影', subtitle: '第四个人留下了影子', source: '走廊 · 通知栏背面',
    body: '图书整理志愿者合影。画面中有三名学生，地上却有四道影子。\n\n最右侧的墙砖纹路错开了一截，像有人后期抹掉了什么。照片背后写着：请把我的位置留着。'
  },
  {
    id: 'register', title: '值班登记页', subtitle: '21:17 的同一笔迹', source: '旧值班室 · 周启明',
    body: '三年前11月14日：林知秋，21:17入馆。\n今晚11月14日：你的名字，21:17入馆。\n\n周启明说登记本曾经受潮，名字是照旧表补写的。但两条记录的墨迹都没有晕开。'
  }
];

export const STORY: StoryNode[] = [
  {
    id: 'arrival', chapter: '第一章 · 纸上的敲门声', location: '旧馆门前', title: '灯还亮着',
    paragraphs: ['21:09。新图书馆闭馆后，旧馆的窗户却亮着一格暖黄。',
      '你的手机收到一条没有署名的消息：「第七张桌子。信还在等你。」',
      '你并不记得约过谁。门从里面开了一条缝，像是有人刚刚松开把手。'],
    choices: [option('enter', '推门，进入旧馆', 'reading')]
  },
  {
    id: 'reading', chapter: '第一章 · 纸上的敲门声', location: '阅览区 · 07桌', title: '空着的第七张桌子',
    paragraphs: ['六张桌子覆着防尘布。只有第七张露着桌面，一封没有邮票的信压在借阅灯下。',
      '墙上的钟停在21:17。你看了看手机，时间才刚过21:10。',
      '走廊尽头传来椅子被拖动的声音。'],
    choices: [option('open_letter', '拆开桌上的信', 'letter', ['letter1']),
      option('look_notice', '先去查看走廊通知', 'corridor', ['notice']),
      option('call_name', '轻声念出「林知秋」', 'voice', [], ['letter1'], ['answered'], [], '需要先读到第一封信的署名')]
  },
  {
    id: 'letter', chapter: '第一章 · 纸上的敲门声', location: '阅览区 · 07桌', title: '写给明天的你',
    paragraphs: ['「如果你又坐在这里，先不要回头。」',
      '落款是林知秋。这个名字你在失踪学生的旧报道里见过。信的日期是今天，年份却被剪掉了。',
      '咚。咚。咚。身后的玻璃响了三下。窗外是四楼。'],
    choices: [option('keep_letter', '收好信，回到桌边', 'reading'),
      option('follow_photo', '按信里的提示寻找合影', 'corridor', ['notice'])]
  },
  {
    id: 'corridor', chapter: '第一章 · 纸上的敲门声', location: '走廊 · 通知栏', title: '相同的闭馆时间',
    paragraphs: ['通知写着21:17闭馆，值班员一栏是「周启明」。旧通知的边角从下面露出来。',
      '通知栏旁是一排泛黄的活动合影。其中一张被翻了过去。',
      '背后有人开口：「那张照片，我们换过了。」'],
    choices: [option('turn_photo', '翻过那张合影', 'photo', ['photo'], ['letter1'], [], [], '第一封信提到了缺失的合影'),
      option('ask_guard', '询问值班员周启明', 'guard'),
      option('back_reading', '回阅览区寻找线索', 'reading')]
  },
  {
    id: 'photo', chapter: '第一章 · 纸上的敲门声', location: '走廊 · 通知栏', title: '第四道影子',
    paragraphs: ['三个人，四道影子。照片最右边有一截接不上的墙砖纹路。',
      '有人修过图。这至少能解释空出来的位置。',
      '你把照片凑近灯光。玻璃里，你身后的影子似乎比你慢了半拍。也许只是灯在闪。'],
    choices: [option('ask_photo', '带着合影询问周启明', 'guard'),
      option('return_corridor', '先回到走廊', 'corridor')]
  },
  {
    id: 'guard', chapter: '第一章 · 纸上的敲门声', location: '旧值班室', title: '他早就知道你的名字',
    paragraphs: ['周启明没有问你是谁，只把一杯还温着的水推过来。',
      '「群里说今晚有人来找旧资料。」他指了指监控屏幕，画面正对第七张桌子。',
      '他的解释很合理。可你收到的那条消息，从没提过你的名字。'],
    choices: [option('ask_register', '核对今晚的入馆登记', 'register', ['register'], ['notice']),
      option('challenge', '出示合影：被抹掉的人是谁？', 'confession', [], ['photo'], ['questioned'], [], '需要取得少了一人的合影'),
      option('leave_guard', '暂时离开值班室', 'corridor')]
  },
  {
    id: 'register', chapter: '第一章 · 纸上的敲门声', location: '旧值班室', title: '尚未发生的登记',
    paragraphs: ['你的名字已经写在今晚的登记页上，时间是21:17。手机显示21:14。',
      '「系统时间不准，都是手工补的。」周启明说。',
      '翻到三年前的同一天，林知秋的名字也停在21:17。两行字，像出自同一只刚握起的笔。'],
    choices: [option('compare_photo', '把登记页与合影放在一起', 'deduction', [], ['photo'], [], [], '还需要合影作为第二条证据'),
      option('continue_search', '回走廊补全证据', 'corridor')]
  },
  {
    id: 'confession', chapter: '第一章 · 纸上的敲门声', location: '旧值班室', title: '被删去的位置',
    paragraphs: ['「照片是我改的。」周启明终于抬头，「她家里人不想再看到。」',
      '「可那第四道影子——原图里也有。我不知道站在那里的是谁。」',
      '他说完，又像在等你纠正他。'],
    choices: [option('check_register', '要求查看入馆登记', 'register', ['register'], ['notice']),
      option('leave_confession', '带着疑问回到走廊', 'corridor')]
  },
  {
    id: 'voice', chapter: '第一章 · 纸上的敲门声', location: '阅览区 · 07桌', title: '有人回答了',
    paragraphs: ['你念出林知秋的名字。借阅灯的电流声忽然停了。',
      '「别用这个名字叫我。」',
      '声音来自头顶。你看见墙角的旧扬声器，电源指示灯没有亮。'],
    choices: [option('trace_voice', '去走廊追查声音的来源', 'corridor', ['notice'])]
  },
  {
    id: 'deduction', chapter: '第一章 · 纸上的敲门声', location: '阅览区 · 07桌', title: '有人在安排重演',
    paragraphs: ['你把证据排开：新的旧通知、被处理的照片、提前写好的入馆记录。',
      '至少有一个活人，在把今晚布置成三年前的样子。',
      '你尚不知道他的目的。但这一次，你决定留下自己的记录。'],
    choices: [option('record_facts', '记录可证实的事实，保留所有证据', 'chapter_end', [], ['register', 'photo'], ['recorded']),
      option('record_voice', '同时记录那句无法解释的回答', 'chapter_end', [], ['register', 'photo'], ['recorded', 'heard'], ['answered'], '需要先在阅览区念出林知秋的名字')]
  },
  {
    id: 'chapter_end', chapter: '第一章 · 纸上的敲门声', location: '旧馆 · 21:17', title: '第七个收件人',
    paragraphs: ['21:17。墙上的钟向前走了一格。',
      '手机又亮了：「这次，你终于把信留下了。」',
      '桌上多了一只空信封。收件人一栏印着你的名字；寄件人一栏，也是。',
      '信封背面夹着一张旧照片的底片。「先别写。」一个女生站在走廊门口，「你还没想起自己坐在哪里。」'],
    choices: [option('meet_shen', '跟她去档案室，查清照片的来历', 'shen', ['letter3'], [], ['met_shen']),
      option('revisit', '返回阅览区，复查遗漏的细节', 'reading')]
  }
];

export const KNOWN_FLAGS: string[] = ['answered', 'questioned', 'recorded', 'heard'];
