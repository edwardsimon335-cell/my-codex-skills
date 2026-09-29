---
name: product-prototype-design
description: Design new or iterate existing product prototypes, then deliver coordinate-accurate low-fidelity packages with manifest-driven SVG pages, concise Chinese PRD annotations, current/all-page HTML review modes, linked highlighting, and deterministic validation. Use for initial product prototype design, interaction redesign, PRD wireframes, hotspot maps, or AI-readable prototype deliverables; do not use for finished visual UI rendering or implementation unless separately requested.
---

# Product Prototype Design

Design or refine the product interaction first, then generate an inspectable low-fidelity prototype package from one machine-readable manifest. Represent information architecture, flows, structure, coordinates, states, hotspots, and requirements without adding finished UI styling.

## Before editing

1. Read [references/prototype-design-method.md](references/prototype-design-method.md) when creating an initial prototype or changing information architecture, flows, page structure, or interaction patterns.
2. Read [references/annotation-schema.md](references/annotation-schema.md) for the required and conditional PRD fields.
3. Read [references/package-contract.md](references/package-contract.md) for package structure, preview behavior, and verification.
4. Inspect the target project's product requirements, current implementation when available, prototype sources, generator, manifest, and repository instructions.

## Choose the working mode

- **Initial design:** start from product goals, users, constraints, and existing functional route. Define information architecture, primary flows, page/state inventory, shared interaction rules, and coordinate wireframes before generating files.
- **Prototype iteration:** audit the existing manifest and preview, preserve unaffected routes and coordinates, then change only the requested interactions, states, annotations, or presentation.
- **Documentation upgrade:** keep the product design unchanged and improve PRD annotations, review modes, indexes, or validation.

If a request spans modes, complete design decisions before package generation. Do not mistake an existing app for an instruction to reproduce its dated interaction patterns; preserve its function route while improving the prototype within the user's scope.

## Scope and output location

- Create or update the user-specified output directory directly. Do **not** create a duplicate or backup directory unless the user explicitly asks for one.
- Do not change application code, APIs, databases, assets, or product routes unless the user separately authorizes those changes.
- Treat the manifest as the source of truth. Generated SVG, HTML, indexes, README, and hashes must not be hand-edited.
- Preserve unrelated files and user changes in an existing package.

## Design and generation workflow

1. Establish or audit the product's information architecture and end-to-end functional routes. Do not add or remove business capabilities without authorization.
2. Define page hierarchy, reusable chrome, navigation, entry/exit paths, state preservation, async/error/empty/permission states, and responsive/accessibility behavior.
3. Review interaction quality across the whole product: hierarchy, screen efficiency, discoverability, gesture conflicts, fixed/scroll regions, loading scope, destructive confirmation, and continuity after returning.
4. Model screens, states, reusable components, coordinate spaces, elements, hotspots, targets, and preserved state in the manifest.
5. Keep the canvas coordinate system explicit. Use responsive relative regions; do not encode interactions as device-specific absolute screen taps.
6. Add concise Chinese PRD annotations for every expanded element and hotspot using the schema reference. Required fields always render; ordinary values may use a one-sentence default. Conditional fields render only when relevant.
7. Generate one independent SVG per state. SVGs show bounds, image placeholders, safe-area guides, hotspot numbering, and embedded metadata, but no production colors, textures, photography, glass, shadows, or finished icon art.
8. Generate one self-contained HTML review page with:
   - current-view mode with the canvas centered between annotations and leader lines;
   - all-pages mode that lays out every state and its complete annotations across the available browser width;
   - browser fullscreen support;
   - element/hotspot visibility filters;
   - synchronized highlighting between annotations and canvas regions on pointer hover and keyboard focus;
   - click-to-pin highlighting for touch or non-hover review;
   - related highlighting for an element and hotspot that share an exact region.
9. Generate the human hotspot index, package README, and SHA-256 artifact list.
10. Validate and visually inspect before delivery.

## Reusable resources

- Start the review page from [assets/prototype-preview.template.html](assets/prototype-preview.template.html). Replace `__PRODUCT_NAME__`, `__PROTOTYPE_MANIFEST__`, `__CHINESE_TYPE_LABELS__`, and `__CHINESE_ACTION_LABELS__` during generation.
- Start Schema V2-compatible packages from [assets/prototype_manifest.schema.json](assets/prototype_manifest.schema.json), then extend it only for real product requirements.
- [assets/build_prototype.reference.rb](assets/build_prototype.reference.rb) is the verified DECONSTRUCT reference generator. Reuse its expansion, SVG, preview, index, README, and hashing mechanics. Retain its product-specific validations only when they apply; replace them with equivalent invariants for other products.

## Delivery checks

- Required PRD annotation fields exist for every expanded element and hotspot.
- Chinese type and action mappings cover every declared type/action; fail generation when a mapping is missing.
- Hotspot IDs are unique within a state, targets resolve, minimum target size is respected, and unauthorized overlaps fail validation.
- Content height equals normalized content bounds plus the declared bottom inset; no blank composite-canvas tail remains.
- Current and all-pages views render at desktop and narrow widths.
- Hover/focus/click highlighting works in both directions and does not depend on color alone.
- Generated HTML JavaScript parses, JSON parses, every SVG is valid XML, and two consecutive builds produce identical hashes.
- Open the generated preview for the user after successful verification when the host supports it.
