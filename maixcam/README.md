# MaixCAM 开发助手

**以 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（MIT）为基底的 fork**，
不是它的插件，是一个独立的应用：自己编译、自己的 home、自己的界面与知识库。

来源：`deepseek-ai/deepseek-harness` @ `c291e79`（master），MIT。

---

## 这是什么

一个面向 **MaixCAM / MaixPy** 的开发助手。它要治的病很具体：

> 当年打电赛的时候，MaixCAM 比较新，模型训练数据里几乎没有它相关的代码，
> 所以幻觉很严重，写不出能用的代码。

所以这个助手的核心不是「会聊天」，而是**答案有据可查**：先检索本地知识库，答必带出处，
API 名字逐个核对，查不到就说不知道。

## 它由三块组成

| 块 | 在哪 | 说明 |
| --- | --- | --- |
| **前端（壳）** | `packages/client/ui-theme/src/styles/maixcam.css` + 若干品牌改动 | 深色科技风主题。**改的是令牌层，上游 CSS 一行没动** |
| **知识库能力** | `maixcam/assistant-shell/` | 语料加载与校验、混合检索、符号白名单校验、三个 agent 工具、知识库面板 |
| **检索纪律（Skill）** | `maixcam/skills/maixcam-kb/SKILL.md` | 把「检索循环」交给 agent：查 → 读 → 逐个核对 API → 再查 → 直到清楚 |

## 关于检索的一个教训（写在最前面）

这一层我**手写过三版**，每一版都更差，原因是同一个：

**我把 agent 该做的事塞进了检索工具里。**
工具自己调 LLM 扩查询、自己拍相关性阈值、自己决定拆几个面 —— 但工具不可能知道
agent 看完成果之后还缺什么。**循环是 agent 的事，一个工具调用模拟不了。**

正确的分工是：

- **检索保持笨而可靠**：一问 → 一批文章 + 出处；
- **循环交给 agent**：`maixcam-kb` skill 规定查到什么程度才算够。

`lib/retrieve.js` 里另有一版基于 **LangChain.js** 的实现（`MultiQueryRetriever` +
`EnsembleRetriever` + `BM25Retriever` + `MemoryVectorStore`），独立验证过但**尚未接入** ——
按上面的分工，它多半也不需要。

## 怎么跑

```bat
maixcam\start.cmd          :: 起在 8890，并打开浏览器
maixcam\start.cmd 9001     :: 换端口
```

它用**自己的 home**：`C:\Users\chuan\.dsh-maixcam`。
会话、工作区、设置、凭据、preset 全部与机器上其它 dsh 安装互不相干。

```bat
set DSH_HOME=C:\Users\chuan\.dsh-maixcam
node apps/cli/lib/bin.js --profile maixcam --patch maixcam\app.patch.yml --port 8890
```

> 每次启动 token 都会变，旧 URL 会失效。用 `start.cmd`，别存 URL。

## 从源码构建

```bash
pnpm install --frozen-lockfile
pnpm run build            # 宿主 + 客户端 + Web 前端
pnpm run build:lib:client # 只改了客户端半边时（快）
pnpm run build:web        # 只改了 index.html / 静态资源时
```

## 改了上游哪些地方

```
apps/web/index.html                     标题 + lang=zh-CN
apps/web/public/favicon.svg             鲸鱼 → MaixCAM 摄像头模组
apps/web/public/manifest.webmanifest    name / short_name
apps/web/public/bg.jpg                  背景插画
packages/bundle/web-app/cordis.patch.yml  默认 preset → maixcam-assistant
packages/client/locale/…/zh.ts, en.ts   brand.localBuild → MaixCAM 开发助手
packages/client/ui-sidebar/…/SidebarRoot.tsx          品牌标记 fallback
packages/client/ui-conversation/…/EmptyHero.tsx       首屏动画鲸鱼 → MaixCamHeroMark
packages/client/ui-settings-models/…/locales.ts       欢迎文案
packages/client/ui-theme/src/client/styles.ts         挂上 maixcam.css
packages/client/ui-theme/src/styles/maixcam.css       深色科技风主题（新）
pnpm-workspace.yaml                     加 maixcam/assistant-shell
maixcam/                                应用自己的东西（新）
```

## 还没做的

- **资料库视图**：像 ima 那样在 Web 端浏览全部文档（按模块分组）。需要一条
  `/api/maixcam/library` 路由 + 面板里的一块浏览界面。
- **接入 LangChain 版检索**，或明确决定不接。
- **评测闭环**：教学主线那套 eval（recall / MRR / citation precision）**从没在这个分支跑过** ——
  检索的每一轮改动都是凭手感调的。这是最该补的一块。

---

# 怎么改这个应用

## 前端主题：只动令牌，不动上游 CSS

`packages/client/ui-theme/src/styles/maixcam.css` 是唯一的换肤入口。
上游的设计系统分两层：

| 层 | 例子 | 谁在读 |
| --- | --- | --- |
| **原始色板** | `--dsw-static-deepseek-500` | 被语义层引用 |
| **语义层** | `--dsw-alias-label-primary`、`--dsw-alias-bg-base` | **组件只读这一层** |

所以换肤的主杠杆是覆盖**语义层** —— 上游那 340 行 `design-platform.css` 一行都不用改，
以后同步上游不会冲突。品牌色那一档额外直接改 `--dsw-static-deepseek-*` 整族，一处改、处处跟着变。

### 两个踩过的坑（都会静默失效）

**坑一：只改语义层，侧栏还是白的。**

我把 `--dsw-alias-*` 全换成深色之后，主面板黑了，**侧栏却仍是白底浅灰字，几乎看不见** ——
因为有些组件（实测是侧栏）**直接引用原始色板** `--dsw-static-neutral-bluish-*`，绕过了语义层。

修法：**把原始中性色阶整族反转**（低序号 = 暗表面，高序号 = 亮文字；与上游用法一致，只是方向反过来）。
反转之后任何引用原始色板的组件都自动落进深色体系，不用逐个去改。

**坑二：用户自己发的话完全看不见。**

用户消息气泡的底色实测是 `rgb(230,252,255)` —— 正是 `--dsw-static-blue-50`。
我只反转了中性色阶，**强调色的浅色调一个没动**，于是气泡是白的、字却跟着
`--dsw-alias-label-primary` 变成了亮的 —— **白底浅字**。

同一类漏掉的还有 `deepseek-100/200`、`amber-100`、`green-100`。
规则：**深色主题里，浅色调必须整族转暗**，因为它们的用途是「淡色底」，而淡色底上现在放的是亮字。

### 怎么自己扫出这类漏网的亮面

肉眼找一个漏改的令牌很费劲。用一段脚本扫全页面，**只要还有一块亮着的背景就报出来**：

```js
const isLight = (c) => { const m = /rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/.exec(c)
  if (!m) return false; const a = m[4] === undefined ? 1 : Number(m[4]); if (a < 0.5) return false
  return +m[1] > 170 && +m[2] > 170 && +m[3] > 170 }

;[...document.querySelectorAll('*')]
  .filter((e) => isLight(getComputedStyle(e).backgroundColor))
  .map((e) => ({ cls: e.className.toString().slice(0, 50), bg: getComputedStyle(e).backgroundColor }))
```

改完一轮跑一次，返回 `0` 才算干净。

### 背景插画

`apps/web/public/bg.jpg` + `maixcam.css` 里的 `body::before`。三个必须配的点：

1. **不外扩也行，但漂移的 `scale` 最小要 ≥ 1** —— 一旦开 `filter: blur()`，边缘会糊开，
   那时必须 `inset: -6%` 外扩，否则四边出现透明亮边。现在不虚化（糊了认不出画的是什么），
   所以 `inset: 0` 就够。
2. **`body::after` 必须有** —— 插画很亮，不压一层暗色，上面的字读不了。
3. **`#root` 必须 `position: relative; z-index: 1`** —— 那两个伪元素是 `position: fixed`，
   而 `#root` 是静态流，**不抬层就会被背景整个盖住**（页面全黑）。

## 加一个 Skill

放到 `maixcam/skills/<name>/SKILL.md`，目录 bundle 形式，YAML frontmatter 必填 `name` 与 `description`。
preset 里 `skill-filesystem` 的 `customSkillDirs` 已指向这个目录，**新增/改名/删除都无需重启**。

`description` 很关键：它决定 agent 什么时候会去加载这个 skill。
写清「什么情况下用它」，不要写「这个 skill 是什么」。

## 接口在哪

| 位置 | 是什么 |
| --- | --- |
| `lib/index.js` 的 `search()` | 检索唯一入口，**路由和 agent 工具共用**它 —— 所以界面看到的和模型看到的一定是同一件事 |
| `/api/maixcam/status` | 语料与索引状态（切片数、符号数、指纹、嵌入模型） |
| `/api/maixcam/search` | `?q=&k=&aspects=`，返回命中与模块覆盖度 |
| `/api/maixcam/symbol` | `?name=`，符号精确签名 + 白名单核对 |
| `lib/tools.js` | 三个 agent 工具的定义与**渲染** —— 模型看到的文本在这里成型 |
| `lib/client.js` | 浏览器半边：品牌座位 + 知识库面板。**手写的 lazy-CJS bundle，改完不用构建**，但宿主进程要重启 |

## 两条硬约束

**一、语料与索引对不上时，拒绝服务而不是降级。**
向量是按 `chunk_id` 顺序存的，两份产物一旦错位，检索会安静地返回牛头不对马嘴的片段 ——
不报错，只有错答案。所以 `corpus.js` 加载时逐条核对，不一致就抛错、
`/api/maixcam/search` 返 503 并说明原因，**不返回空结果**。

**二、工具失败要说清原因，不要返回空列表。**
空结果会被模型读成「知识库里没有」，然后继续凭记忆回答 —— 那正是这个项目要治的病。
所以检索不可用时抛「知识库不可用：<原因>」。


---

## 装到别人的机器上

```
setup.cmd                  ← 双击这个（根目录）
maixcam\install.ps1        安装逻辑：检查环境 / 装依赖 / 构建 / 建 home / 建快捷方式
maixcam\launch.vbs         快捷方式实际执行的东西（无窗口启动）
maixcam\maixcam.ico        图标，安装时从 apps/web/public/favicon.svg 自动生成
maixcam\start.cmd          前台启动，带控制台窗口，调试时用
```

`install.ps1` 支持 `-SkipBuild`（已构建过）与 `-ShortcutsOnly`（只重建快捷方式）。

**图标是怎么来的**：用无头 Chrome/Edge 把 `favicon.svg` 渲染成 256×256 PNG，
再套一层 ICO 容器（ICO 允许直接内嵌 PNG，Vista 以后都支持）。
所以改 favicon 之后删掉 `maixcam.ico` 重跑安装，图标就跟着换。