# Product prototype design method

Use this reference for initial design and for iterations that change information architecture, navigation, flows, or page structure.

## 1. Establish the boundary

Extract:

- product goal and primary user jobs;
- current or required functional route;
- platforms, reference devices, languages, accessibility expectations, and offline behavior;
- data, permission, entitlement, camera, purchase, or persistence constraints;
- what may change in the prototype and what must remain unchanged.

Inspect existing product screens or code when available, but treat them as behavioral evidence rather than mandatory visual structure. Ask only when a missing decision would materially alter the product route.

## 2. Build the experience model

Define, in order:

1. Information architecture and global destinations.
2. Primary user flows and alternate/error paths.
3. Page hierarchy: primary pages, secondary pages, sheets, dialogs, menus, and transient states.
4. State inventory for every page: default, loading, populated, empty, failure, disabled, permission, entitlement, and task lifecycle states that actually exist.
5. Shared components: headers, navigation, tabs, filters, cards, banners, dialogs, and camera controls.
6. State preservation on navigation and return.

Do not add a screen when a local state, sheet, or inline disclosure is sufficient. Do not hide a distinct task behind an overloaded component merely to reduce screen count.

## 3. Design interaction quality

Audit the product as one system, not as isolated pages:

- Give each page one clear primary purpose and action hierarchy.
- Put persistent page identity and global actions in consistent fixed chrome.
- Use screen space efficiently without reducing touch targets or readability.
- Keep filters single-line and scrollable when wrapping would consume content space.
- Prefer local loading/feedback over blocking the whole page when the task is local.
- Keep destructive operations confirmed and explicit.
- Preserve scroll, selected tabs/filters, and draft state when returning.
- Avoid overlapping tap and drag regions; keep one primary gesture per region.
- Define empty, failure, permission, entitlement, and recovery paths before calling the flow complete.
- Use platform safe areas and minimum touch targets; specify large-text and reduced-motion behavior.

## 4. Convert the design to coordinates

- Choose a reference canvas and logical unit.
- Define safe areas, fixed chrome, scroll viewport, bottom clearance, and overlay spaces first.
- Place major regions before individual controls.
- Use stable IDs that describe product meaning rather than visual appearance.
- Express responsive behavior as rules, not as additional arbitrary device canvases.
- For image and camera regions, declare aspect ratios, crop policy, focus bounds, and output semantics.

## 5. Review before generating

Verify:

- every required product function has an entry, result, and recovery route;
- no new feature or removed capability slipped into the design;
- primary navigation, secondary navigation, back behavior, and preserved state are coherent;
- all important states appear in the page/state matrix;
- hotspot bounds are operable and non-conflicting;
- requirements can be understood from the manifest without seeing finished UI.

Then proceed to package generation and PRD annotation.
