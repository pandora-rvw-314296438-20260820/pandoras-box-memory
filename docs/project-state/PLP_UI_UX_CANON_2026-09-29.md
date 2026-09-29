# PLP Boracay mobile UI/UX canon - 2026-09-29

## Status

**OWNER DECISION - CANONICAL VISUAL BASELINE**

Effective: **2026-09-29 20:15 PHT**

This record preserves the owner's explicit instruction that the attached mobile screenshots are the current UI/UX identity for **PLP Boracay / Pueblo La Perla**.

Scope: PLP Boracay Enterprise mobile content surfaces, with the Owner's Home and Overview screens as the canonical examples. Future PLP mobile work should preserve this visual language unless the owner explicitly supersedes it.

This owner decision takes precedence over earlier PLP visual interpretations that conflict with these screenshots. It is consistent with the prior correction that PLP content pages are light/ivory editorial luxury while Pandora command/navigation surfaces may remain black.

## Source evidence

Screenshot A:
- source filename: `Screenshot_2026-09-29-20-14-25-627_com.banataosystems.pandora.plp.jpg`
- dimensions: 709 x 1536
- SHA-256: `028a7c929f1cf5340957df814de0a98795d5b2803d931937544d5715e20611d7`
- screen shown: PLP Overview

Screenshot B:
- source filename: `6319.jpg`
- dimensions: 709 x 1536
- SHA-256: `94fc0b4ebafd8b3c5c9cef0ea58491b6584e261da0e11e8ab747acd86b407a68`
- screen shown: PLP Owner's Home

The screenshots were supplied directly by the owner in the ChatGPT session on 2026-09-29. The Android status/navigation chrome and the "Quit Screen Recorder" overlay are recording/device artifacts and are **not** part of the PLP design.

## Canonical visual grammar

- Warm ivory/off-white content canvas. The dominant screenshot background is approximately RGB 249/248/243 to 250/247/240; preserve the warm editorial character rather than using sterile white.
- Near-black typography with very high contrast.
- Large editorial serif display headings for page identity and primary statements.
- Restrained sans-serif for body copy, supporting labels, metrics labels, and controls.
- Muted olive-gold accent for small uppercase section labels and tracked secondary brand text.
- Small uppercase labels use generous letter spacing and deliberate restraint.
- Thin warm-gray hairline dividers instead of boxed cards.
- Very generous whitespace and vertical rhythm.
- Mostly square/flat editorial content composition; avoid generic SaaS cards, excessive rounded containers, glassmorphism, gradients, neon, heavy shadows, and visual clutter.
- Metrics are integrated into the page with typography and hairline separators rather than placed in dashboard tiles.
- Content should read like a quiet luxury-resort operating book, not a generic analytics dashboard.

## Canonical top shell

### Owner's Home

- Left: dark rounded-square hamburger control.
- Brand block: **PLP Boracay** in serif with **LUXURY RESORT** as small tracked olive-gold secondary text.
- Right: simple outlined square refresh control.
- First page eyebrow: **OWNER'S HOME**.
- Main display title: **Pueblo La Perla**.
- Welcome/identity line is secondary and letter-spaced.
- Intro copy is calm, large enough to read easily, and intentionally sparse.

### Overview

- Left: same dark rounded-square hamburger control.
- Brand block: **PUEBLO LA PERLA** in tracked serif uppercase with **OVERVIEW** below in small olive-gold tracked text.
- Main eyebrow: **OVERVIEW**.
- Hero statement: **The resort, in one quiet view.**
- Intro copy explains the operating picture without dashboard noise.

These two header treatments are both valid PLP expressions within the same design language. Do not replace them with a generic app bar.

## Canonical operating-content pattern

The visible owner dashboard composition establishes the following preferred hierarchy:

1. page eyebrow / context
2. large editorial title or statement
3. short supporting copy
4. hairline divider
5. quiet three-column operating metrics
6. section heading or tracked section label
7. large, sparse movement/exception rows
8. persistent Pandora command surface

Metrics shown in the reference:
- Occupancy
- Revenue
- Available rooms
- Arrivals
- Departures

The important design rule is the presentation, not the sample zero values. Live data must remain provider-backed and must never be hardcoded merely to match the screenshot.

## Persistent Pandora command surface

The bottom command composer is part of the canonical PLP mobile shell:

- full-width black/dark command bar near the bottom safe area
- left Pandora/cube command icon area
- text prompt such as **Message Pandora**
- microphone control
- narrow vertical divider
- upward send arrow
- strong contrast against the ivory content canvas
- persistent across PLP workspaces where context permits

The command surface should feel integrated and permanent, not like a floating chatbot card.

## Design invariants

Preserve unless the owner explicitly changes them:

- PLP content canvas remains warm light/ivory.
- PLP uses editorial serif display typography as a defining visual asset.
- Black is reserved for strong Pandora/navigation/command surfaces, not used to turn the whole PLP content page dark.
- Olive-gold is restrained and primarily used for hierarchy, labels, and brand detail.
- Hairline rules and whitespace do most of the structural work.
- Owner-facing operational data is calm and sparse; avoid metric-card overload.
- The mobile shell must remain elegant, immediately understandable, and luxury-resort specific.
- Do not copy Android system UI or screen-recording overlays into product UI.
- Do not reintroduce a conventional dense SaaS dashboard without explicit owner approval.

## Relation to earlier PLP Memory

This record reinforces the existing correction in `docs/capabilities/evidence/PLP_METALLIC_NIGHT_BRAND_ALIGNMENT_2026-09-25.json` that PLP content pages must remain light/ivory editorial luxury. If another older PLP design note conflicts with this 2026-09-29 owner-supplied visual baseline, treat this record as the newer owner authority.

## Verification boundary

This record is a **design/owner-decision memory**, not proof that every current PLP screen already implements the canon. Source changes, CI success, APK builds, deployments, and post-merge device screenshots remain separate verification requirements.

For future PLP UI work, visual acceptance should compare the rendered result against this canonical grammar and the owner-supplied reference screenshots before calling the work complete.
