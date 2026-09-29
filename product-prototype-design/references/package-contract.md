# Prototype package contract

## Recommended files

```text
<target>/
├── prototype_manifest.json
├── prototype_manifest.schema.json
├── build_prototype.rb
├── prototype-preview.template.html
├── prototype-preview.html
├── hotspot-index.md
├── artifact-hashes.json
├── README.md
└── pages/
    └── <screen-state>.svg
```

`prototype_manifest.json` is the only product-data source. The generator and template are maintained sources. The preview, SVGs, index, README, and hash list are generated artifacts.

## Manifest invariants

- Declare schema/prototype version, product, baseline version, implementation status, coordinate system, safe areas, coordinate spaces, accuracy policy, interaction guidelines, responsive rules, shared components, screens, and states.
- Each state declares a stable ID, title, SVG output path, content height, accuracy, elements, hotspots, and optional component references.
- Each element declares ID, semantic type, rectangle, coordinate space, accuracy, and a Chinese description.
- Each hotspot declares ID, rectangle, coordinate space, accuracy, semantic role, Chinese label, action, and any target/preserve/enabled/overlap properties.
- Shared IDs may repeat only across mutually exclusive states. Expanded IDs must be unique inside one state.
- State transitions must resolve to declared screens/states.

## Coordinate and canvas rules

- Keep the reference device and logical-point unit explicit.
- Store rectangles as `[x, y, width, height]` from the top-left origin.
- Distinguish viewport, scroll-content, and overlay coordinates.
- Compute composite content height from the last scroll-content edge plus the applicable bottom inset, rounded to the package grid.
- Use only one viewport canvas when all scroll content fits. Do not append a blank area merely because a fixed safe-area guide exists.
- Fixed UI and overlay UI may be drawn on a taller composite canvas for context, but they do not increase the scroll-content extent.

## SVG contract

- One SVG per state with embedded metadata.
- Solid element outlines, dashed hotspot outlines, numbered hotspot markers, safe-area guides, and image-placeholder crosses.
- The SVG is a coordinate wireframe, not a finished UI mockup.

## HTML contract

### Current view

- One selected state, centered canvas, left/right annotations, and leader lines.
- On narrow widths, place annotations below the canvas and hide leader lines.

### All-pages view

- Render every state and complete visible annotations in a responsive full-width board.
- Do not hide states behind tabs, pagination, or virtualization unless the user requests it.

### Linked inspection

- Give each expanded item a key scoped by screen, state, kind, and stable ID.
- Build transparent inspection regions from manifest rectangles.
- Pointer hover, keyboard focus, and click-to-pin activate all nodes sharing the key.
- If an element and hotspot share the exact state and rectangle, highlight them as related items.
- Filters must remove both annotations and matching inspection regions.

## Verification

Run, or provide equivalents for:

```bash
ruby build_prototype.rb
ruby -c build_prototype.rb
jq empty prototype_manifest.json artifact-hashes.json
for file in pages/*.svg; do xmllint --noout "$file"; done
```

Extract the final executable `<script>` from the generated HTML and pipe it to `node --check`. Run the generator twice and compare hashes. Finally inspect both `prototype-preview.html` and `prototype-preview.html?view=all` in a browser at desktop and narrow widths.
