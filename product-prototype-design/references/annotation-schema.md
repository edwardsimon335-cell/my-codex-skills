# Chinese PRD annotation schema

Use this schema for every expanded page element and hotspot. Keep each value concise, concrete, and traceable to the manifest or existing product behavior. Never invent an API, data source, permission, analytics event, or state that the product has not defined.

## Required fields

### 元素标题

Use the user-facing name. For a hotspot, prefer its accessible label. Keep the stable ID as adjacent technical metadata, not as the title.

### 展示内容

Describe the actual copy, image, control value, or data shown and its source.

- Static copy: identify the localizable product copy.
- User content: identify the local photo, analysis record, saved look, or other store.
- Remote or service data: name the existing service or response without inventing an endpoint.
- Unknown source: say the current specification does not declare a finer source and flag it for implementation confirmation.

### 展示条件

State when the item appears, hides, disables, or becomes selected. Include relevant page state, permission, entitlement, task state, or user-data conditions.

### 交互结果

Describe the action, resulting screen/state, side effects, and preserved context. For non-interactive elements, say which colocated hotspot owns the interaction or state that the element is display-only.

### 状态集合

Always render this field. List only real states: default, loading, empty, success, failure, disabled, selected, or product-specific states. For a simple item, use a compact default such as “当前仅覆盖默认状态；其他状态沿用页面级规则”。

### 适配规则

Always render this field. Cover fixed versus scrolling placement, width behavior, large text, and long-content handling. For a simple item, reference the page-level responsive rule in one sentence instead of repeating it.

The user may describe 状态集合 or 适配规则 as both required and conditional. Resolve this by always showing the field while expanding it only when behavior differs from the page default.

## Conditional fields

Render these only when applicable:

- **权限与额度**: login, subscription, quota, local/system permission, or entitlement dependencies.
- **异常处理**: async work, network, camera, purchase, persistence, retries, or partial failures.
- **无障碍**: interactive controls and meaningful media; include role, spoken label, focus order, minimum target, and decorative exclusion where applicable.
- **数据埋点**: only key entry, conversion, task, capture, and purchase events. State event intent and allowed context; do not invent event names unless the project already defines them.
- **内容规范**: date/number formatting, localization, truncation, placeholders, image ratios, or semantic color alternatives.
- **验收口径**: complex, ambiguous, stateful, or geometry-sensitive elements. Make the check observable.

## Compact rendering

- Keep technical metadata to one or two lines: stable ID, Chinese type, rectangle, coordinate space, and accuracy.
- Keep each required field to one sentence when possible.
- Do not render empty conditional headings.
- Put shared safe-area, typography, motion, and responsive rules at page or package level; reference them from individual elements.
- Preserve machine-readable values in the manifest even when the HTML displays translated Chinese labels.
