
# PLP AI assistant canon - 2026-10-04

## Status

**OWNER DECISION + VERIFIED IMPLEMENTATION**

Effective owner direction: **2026-10-04 PHT**

Canonical Pandora repository: `pandora-rvw-314296438-20260820/pandoras-box`

This record supersedes only the earlier PLP requirement that a full-width Pandora command composer remain permanently visible on every PLP page. The rest of the approved PLP visual canon remains intact: existing page design, ivory/black/gold hierarchy, typography, imagery, cards, spacing, navigation, and shell identity must not be redesigned unless the owner explicitly changes them.

## Owner decision

PLP uses one assistant across the workspace.

- Remove every rendered per-page chat/command composer.
- The only persistent chat affordance is the existing PLP logo at the bottom-right.
- Tapping the logo opens a compact chat panel over the current business page.
- The business page remains mounted, visible, and contextual while compact chat is open.
- The assistant must provide **Minimize**, **Expand/Restore**, and **Close** controls.
- Full-screen chat is entered only after explicit client choice to Expand.
- Minimize returns to the PLP logo.
- Close dismisses the assistant UI without deleting the thread.
- New Chat and Recent Chats remain available.
- All conversations continue into Recent Chats rather than creating page-specific chat histories.
- Preserve the shell-owned hamburger/navigation control on every PLP surface and in every assistant state.
- Do not redesign PLP pages while implementing this assistant.

## Command-layer behavior

The assistant is both conversational and operational.

Authorized users may issue natural-language commands such as adding administrators, changing roles and access, managing guests/reservations/rooms/experiences, sending messages, and invoking supported PLP workflows.

Execution invariants:

- tenant-scoped
- permission-aware
- auditable
- confirmation for sensitive/destructive actions
- verified provider/data readback before claiming success
- clear distinction between answering, proposing an action, and executing an action
- real PLP state must update; chat may not maintain a fake parallel business state
- existing governed command execution, attachments, voice, model selection, and conversation persistence are preserved

## Verified implementation

The implementation was delivered through PR **#969**, `PLP: logo-first compact AI assistant`.

PR final head before merge:

`0d0fd31be13500fc8e36c614813e6b1b1aa5bb35`

Merged to canonical `main` as:

`32c7a0690d93308397107c458f3f790ec26d2b09`

The PR head tree and merge commit tree are identical:

`b5e4e10c42b5351f63aed05250abed60f4e8e59a`

This proves the exact tested PR content is the content merged to main.

Provider verification on the final PR head showed all relevant workflows successful:

- Pandora Node 24 #1640
- Pandora mobile UX behavior #480
- Pandora mobile exact-source gate #5447
- PLP Pandora Enterprise Android exact-source #1228
- Dependency Review #4335
- Canonical release evidence #5381
- Windows Worker Contract #5381
- Operations Runtime Seams #1026
- Pandora Edge source artifact #3773
- Euro-Fish Pandora Enterprise Android exact-source #428

The PLP exact-source workflow also completed installed-APK emulator acceptance, including build, package/ABI/signing/model-separation checks, x86_64 emulator candidate creation, emulator boot, installed-app lifecycle/unauthenticated-flow exercise, evidence upload, and exact APK evidence binding.

## Important implementation details

The implementation preserves the business workspace instead of replacing it with chat.

- `PandoraConversationLayer` can disable the legacy composer clearance for PLP.
- PLP business content is not offstaged merely because chat is visible.
- The PLP assistant has explicit launcher / compact / expanded states.
- The existing PLP asset `assets/workspaces/plp.webp` is used for the launcher.
- The PLP shell no longer renders `PlpCommandDock` as a page-level bottom composer.
- The shell-owned floating hamburger remains above the assistant overlay.
- Compact assistant keyboard behavior raises the assistant rather than reflowing the underlying PLP business page.
- Embedded PLP business surfaces delegate IME resizing to the parent shell.
- Embedded bootstrap/error states also remain fixed behind the assistant keyboard.

## Failure and lesson learned

An earlier implementation attempt removed the per-page composer but inherited keyboard-resize behavior from both the outer Pandora shell and embedded PLP shell. When the compact assistant opened the keyboard, the business page moved underneath it. A CI acceptance test exposed the defect.

The working fix was not a visual patch. It established explicit IME ownership:

1. the assistant owns keyboard movement;
2. the outer Pandora shell stops resizing the PLP business page while the PLP assistant is visible;
3. embedded `PlpEnterpriseShell` surfaces do not resize themselves for the IME;
4. bootstrap/error surfaces follow the same embedded rule;
5. widget acceptance verifies the underlying page remains fixed while the compact assistant moves above the keyboard.

General lesson: when a floating/overlay assistant owns the composer, only that assistant should respond to the keyboard inset. Nested business shells must not independently resize for the same IME event.

## Superseded information

The 2026-09-29 PLP UI canon section describing a permanently visible full-width bottom Pandora command composer is superseded by this record.

The rest of that visual canon remains valid and must be preserved.

## Verification boundary

Verified:

- owner decision
- implementation in canonical source
- exact-source CI
- PLP native APK build
- installed emulator acceptance
- merge to canonical main
- identical tested and merged Git tree

Not asserted by this record:

- Play Store publication
- physical Redmi/HyperOS acceptance
- production-device rollout to the PLP client
