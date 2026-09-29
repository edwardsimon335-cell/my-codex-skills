# My Codex Skills

个人 Codex Skill 集合，用于统一管理、版本追踪和持续迭代。

## Skills

- `animate`：为界面与组件设计并实现有目的的动画。
- `app-site-seo-geo`：为公开 App 官网构建或审查多语言 SEO 与 AI 搜索可发现性。
- `artifact-template-app-store-screenshot-studio`：制作与迭代 App Store 商店截图及宣传图。
- `emil-design-eng`：面向 UI 打磨、组件设计和动效决策的设计工程指南。
- `product-prototype-design`：生成可检查、可验证的低保真产品原型包。
- `ui-ux-pro-max`：面向 Web 与移动端的 UI/UX 设计知识库和检索工具。

## 安装

克隆仓库后，将需要的 Skill 复制到 Codex Skills 目录：

```bash
git clone https://github.com/edwardsimon335-cell/my-codex-skills.git
cp -R my-codex-skills/<skill-name> ~/.codex/skills/
```

也可以用符号链接便于在本地编辑后直接同步：

```bash
ln -s "$(pwd)/my-codex-skills/<skill-name>" ~/.codex/skills/<skill-name>
```

每个 Skill 目录以 `SKILL.md` 为入口，并可按需包含 `agents/`、`assets/`、`references/`、`scripts/` 和 `data/`。
