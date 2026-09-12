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
