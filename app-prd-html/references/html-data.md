# HTML 数据与组件

`scripts/build_prd.py` 使用 Python 3.9+ 标准库，输出单个 HTML，将引用的图片/视频内嵌。`--timezone` 使用 IANA 时区，如 `Asia/Shanghai`；未传入时取运行环境本地时间，应优先使用用户时区。可传 `--manifest path.json` 输出素材校验摘要，不记录绝对路径。

## 文档字段

|字段|用途|
|---|---|
|`document_id`|稳定且唯一的文档标识，用于隔离本地草稿；不要在不同项目之间复用|
|`hub_url`, `hub_project_id`|可选；统一目录绝对地址和项目 ID，用于生成顶部返回入口|
|`project`, `title`|侧栏名称与正文标题|
|`background`, `goals`|段落数组，通常各一段|
|`accent`|可选六位十六进制强调色，默认 `#b53f35`|
|`updated_at`|可选带时区 ISO 时间；正常修改时省略，让生成器写实际时间|
|`sections`|功能数组；每项 `id`、`title`、`status`、`blocks`|
|`media`|可选素材字典，键为组件引用的素材 ID|

章节 ID 使用小写字母、数字、连字符且全局唯一。状态为 `todo` 待开发、`integrating` 待接入、`needs-info` 待补充、`done` 已完成、`reference` 现有能力。目录和正文使用同一字段。示例的待补充是正常业务状态，不是应删除的脚手架占位符。

正文按纯文本渲染，不支持 HTML/Markdown 嵌入。用多段文字或表格，不将 HTML 拼入字段。

## 组件

所有组件可选 `title` 和 `note`，仅在有助于理解时填写。

```json
{"type":"text","paragraphs":["条件满足时执行动作，完成后返回来源页。"]}
```

```json
{"type":"table","columns":["入口","条件","交互"],"rows":[
  {"cells":["列表","选择条目","打开详情；返回保留位置。"],"media":["list","detail"]}
]}
```

`rows[].media` 可省略。存在时自动增加「页面」列和展开按钮，素材显示在当前行下方。

```json
{"type":"gallery","media":["option-a","option-b"]}
```

图库始终一行，用于并列选中态；窄屏横向滚动。图片标题来自素材 `title`。

```json
{"type":"states","items":[
  {"label":"未保存","media":["before"],"note":"操作前状态。"},
  {"label":"已保存","media":["after"],"note":"成功后的状态。"}
]}
```

每个状态可带多张图片，支持成对前后对照。不能只切换图片却保留旧标题。

```json
{"type":"motion","video":"completion-motion","stills":["after"]}
```

视频默认暂停、无循环；支持重播、原生控制和静态切换。为视频提供 poster 图片。若章节希望文字左置、视频右置，可设 `section.layout` 为 `media-aside`，并将最后一个组件设为 `motion`；其他情况默认纵向排列。

```json
{"type":"links","items":[
  {"id":"service-guide","title":"服务接入文档","url":""}
]}
```

链接 ID 全文唯一。空 URL 显示待补充；浏览器保存草稿，功能区可导出已填链接的完整 HTML。链接只接受 http/https。重建同一路径 HTML 时保留旧文件的已填链接；主动清除用 `--reset-links`。

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
- 浏览器中未导出的链接草稿，应先导出或通过可用浏览器读取输入、合入数据，再生成；磁盘生成器不能读取另一个浏览器的 localStorage。
- 接手手写 HTML 可继续原结构小改；迁移前提取已填链接与素材，并比较功能行为。
- 示例不含真实 App 截图；使用时必须读取当前项目素材，或明确写页面待补充。
