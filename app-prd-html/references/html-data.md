# HTML 数据与组件

`scripts/build_prd.py` 使用 Python 3.9+ 标准库，输出单个 HTML，将引用的图片/视频内嵌。`--timezone` 使用 IANA 时区，如 `Asia/Shanghai`；未传入时取运行环境本地时间，应优先使用用户时区。可传 `--manifest path.json` 输出素材校验摘要，不记录绝对路径。

## 文档字段

|字段|用途|
|---|---|
|`document_id`|稳定且唯一的文档标识，用于隔离本地草稿；不要在不同项目之间复用|
|`hub_url`, `hub_project_id`|可选；仅在用户明确要求链接到需求目录时填写，用于生成顶部返回入口；本地交付默认省略|
|`project`, `title`|侧栏名称与正文标题|
|`background`, `goals`|段落数组，通常各一段|
|`accent`|可选六位十六进制强调色，默认 `#b53f35`|
|`updated_at`|可选带时区 ISO 时间；正常修改时省略，让生成器写实际时间|
|`sections`|功能数组；每项 `id`、`title`、`status`、`blocks`|
|`media`|可选素材字典，键为组件引用的素材 ID|

章节 ID 使用小写字母、数字、连字符且全局唯一。状态为 `todo` 待开发、`integrating` 待接入、`needs-info` 待补充、`done` 已完成、`reference` 现有能力。目录和正文使用同一字段。示例的待补充是正常业务状态，不是应删除的脚手架占位符。

正文按纯文本渲染，不支持 HTML/Markdown 嵌入。用段落、列表或表格，不将 HTML 拼入字段。功能内部按主要流程、页面交互逻辑、边界场景、其他内容排列。

## 组件

所有组件可选 `title` 和 `note`，仅在有助于理解时填写。

```json
{"type":"text","paragraphs":["条件满足时执行动作，完成后返回来源页。"]}
```

```json
{"type":"list","title":"主要流程","ordered":true,"items":["进入功能。","确认后保存，返回来源页。"]}
```

`ordered` 默认 false；流程用有序列表，并列规则用无序列表。表格的 `cells` 也支持字符串数组，按无序列表呈现多条规则。

需要进一步说明时，列表项可写为 `{"text":"操作文案按日期变化。","children":["当天：显示常用杯量。","历史日期：显示 View details。"]}`，`children` 可继续嵌套。主流程、图文规则组和表格单元格中的列表均支持此结构。不同场景使用同级条目，同一规则的细分使用子列表。

```json
{"type":"illustrated","title":"页面交互逻辑","media":["before","after"],"groups":[
  {"title":"显示与操作","items":[{"text":"按所选日期展示。","children":["有数据：展示当日统计。","无数据：显示空态。"]},"点击卡片进入详情，返回保留日期。"]}
]}
```

`illustrated` 支持1～2张页面，桌面左文右图；窄屏转为上下排列，两张图仍并列对照并可在区域内横向滚动。每组规则与对应截图放在同一组件中。

横向排列时卡片高度对齐，宽度按内容特征分配；纵向排列时宽度对齐，高度由内容决定。图片保持原比例，不将所有卡片强制等宽等高。

```json
{"type":"table","columns":["入口","条件","交互"],"rows":[
  {"cells":["列表","选择条目",["打开详情。","返回时保留位置。"]],"media":["list","detail"]}
]}
```

`rows[].media` 可省略。存在时自动增加「页面」列和展开按钮，素材显示在当前行下方。

```json
{"type":"gallery","media":["option-a","option-b"]}
```

能平铺对照的页面状态优先用图库横向展示；窄屏在图库内横向滚动。图片标题来自素材 `title`，各状态的说明应在相邻内容中保留。

```json
{"type":"states","items":[
  {"label":"未保存","media":["before"],"note":"操作前状态。"},
  {"label":"已保存","media":["after"],"note":"成功后的状态。"}
]}
```

仅在状态不适合平铺时使用切换。每个状态可带多张图片，标题、图片和说明同步更新。

```json
{"type":"motion","video":"completion-motion","stills":["after"]}
```

视频默认暂停、无循环；支持重播、原生控制和静态切换。为视频提供 poster 图片。若章节希望文字左置、视频右置，可设 `section.layout` 为 `media-aside`，并将最后一个组件设为 `motion`；其他情况默认纵向排列。

```json
{"type":"links","items":[
  {"id":"service-guide","title":"服务接入文档","url":""}
]}
```

链接 ID 全文唯一。用户提供的相关文档 URL 放入对应功能，以不可编辑的链接展示，支持打开和一键复制，复制按钮仅显示图标，无衬底和边框，保留点击热区；空 URL 显示待补充。链接只接受 http/https。重建同一路径 HTML 时保留旧文件的已填链接；主动清除用 `--reset-links`。

单个外链卡片占满正文宽度，与上下板块对齐。图片大图支持点击弹窗外遮罩、关闭按钮或 Esc 关闭，点击弹窗内内容不关闭，关闭后保持阅读位置。

## 素材

```json
{
  "media": {
    "after": {
      "kind":"image", "file":"media/after.png", "title":"保存成功",
      "provenance":"app-render", "source":"现有组件使用演示数据渲染"
    },
    "completion-motion": {
      "kind":"video", "file":"media/completion.mp4", "title":"保存反馈 · 动效",
      "provenance":"app-capture", "source":"模拟器录屏", "poster":"after"
    }
  }
}
```

路径相对 `prd.json`，也可用本机绝对路径，生成文件不嵌入源文件路径。图片支持 PNG/JPEG/WebP/GIF，视频支持 MP4/WebM，推荐短 H.264 MP4。超过 20MB 时生成器提示压缩或改用相对路径包，不截断素材。

`provenance` 必填：`app-capture` 实机/模拟器截图或录屏；`app-render` 现有 UI 组件真实渲染；`design-reference` 设计示意。模板显示来源类别，避免将原型描述为实际实现。可选 `source` 只进入 manifest，不写凭证或个人信息。

## 迭代

- 同一 JSON 作为可维护内容源，素材引用用相对路径，避免直接改生成文件后又被旧数据覆盖。
- 接手旧版可编辑链接文档时，先将已填写链接合入数据源，再转为只读链接；磁盘生成器不能读取另一个浏览器的 localStorage。
- 接手手写 HTML 可继续原结构小改；迁移前提取已填链接与素材，并比较功能行为。
- 示例不含真实 App 截图；使用时必须读取当前项目素材，或明确写页面待补充。
