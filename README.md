<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/cargo_lockup_dark.svg">
    <img src="assets/cargo_lockup_light.svg" width="200" alt="Cargo">
  </picture>
</p>

# Cargo

**Inventory** module of the [Corpus](https://github.com/Sepuldosky/corpus) ecosystem for
**Garry's Mod**: STALKER/GAMMA-style grid, item framework, holster-based equipment,
weight→movement, containers and an ARC9 attachment bridge. Independent addon that
**hard-depends** on Corpus (the ecosystem's only hard dependency) and detects the other
modules at runtime, never assumes them. It's mostly a **consumption hub** — the other
modules register their items (medical, consumables) against the framework Cargo exposes —
but it's **not a leaf** in the graph: it also consumes Coagulant (stamina drain from being
overweight) and Cortex (faction/rank for the header), both with lazy-check and honest
degradation.

**Design rule:** Cargo owns the "how an item is defined, weighed, stored and rendered"; the
owning module owns the "what it does". Cargo carries instance blobs without interpreting them.

## Features

- **Uniform cell grid** with a `w×h` footprint per item, live-rendered icons
  (RT + on-disk cache) and a framing editor; per-corner condition/stack overlays.
- **Item framework** with two classes, categories, stacks (merge only with identical
  condition), generic sub-slots (plates, optics, exo) with mandatory ejection on destroy.
- **Fullscreen UI, 3 columns / 3 states** (Solo/Loot/Trade) + inspection
  tooltip, pickup feed and a **radial wheel menu** (hold G) over keys 1-7.
- **STALKER-style equipment**: weapon slots on keys 1-7, pressing again holsters (own
  hands SWEP), F1-F4 quick slots, stackable grenade slot (`×N`), direct drop from the
  slot, unarmed spawn — capture turns engine weapons into items (including spawnmenu
  tools) and drops are the real SWEP in world.
- **Picking up is a deliberate gesture**: WALK+USE takes an item off the ground (world
  weapons, Cargo's own drops, cash, ammo crates, registered third-party pickups) through
  a single gate; USE alone just carries it like an HL2 prop. Optional arm animation via
  *[GCAL] Improved Manual Pickup* if it's mounted — soft dependency, degrades cleanly
  without it.
- **The belt IS the ammo reserve**: HL2 ammo types are items, a base-agnostic mirror
  (zero ARC9 hooks), weapons of the same type share the reserve.
- **Weight → speed** (pure curve, base capacity + backpack), money with a native
  provider, world containers with transfers.
- **Trade (slices 1-2)**: the trader IS a container with a pricing layer (same
  primitive, not a parallel inventory); price = `value × condition × spread`, a
  pure-intent basket on the client and an atomic `Confirm` on the server. Cash exists as
  a world entity — droppable, and offerable as a cash-only line in the basket. Without
  `value`, an item isn't for sale.
- **Theme with runtime palettes**: neutral spawnmenu-style base that tints live with the
  DGL4 HUD preset if it's mounted; GAMMA palette available via convar.
- **ARC9 bridge**: attachments live in the inventory, live stats via `GetProcessedValue`,
  reconciliation with the C menu. Degrades gracefully if ARC9 isn't present.
- **Full persistence** per SteamID64 via `Corpus.Data` — inventory, equipped items,
  loaded magazines and instances survive restart and reconnection.

In design / not implemented: **Workbench** (crafting/repair/disassembly). Of trade
(`Cargo_Trade`), slice 3 is still missing (player-trader with double confirmation,
including P2P transfer).

## Requirements

- **Corpus** (hard dependency — without it, Cargo won't boot).
- Optional: **ARC9** (attachments + live stats), **DGL4** (the UI tints with its HUD
  preset), and *[GCAL] Improved Manual Pickup* (pickup gesture animation). Cargo
  degrades gracefully if they aren't present.

Player-facing language (UI, items, menus) is **English**; docs and commits are in Spanish.

## Documentation

- [`docs/Cargo_Architecture.md`](docs/Cargo_Architecture.md) — module architecture (inventory, item contract).
- [`docs/Cargo_ItemImages_Arquitectura.md`](docs/Cargo_ItemImages_Arquitectura.md) — item image system.
- [`docs/Cargo_Trade_Arquitectura.md`](docs/Cargo_Trade_Arquitectura.md) — trade (slices 1-2 in production; slice 3 in design).
- [`docs/Workbench_Arquitectura.md`](docs/Workbench_Arquitectura.md) — workbench (future subsystem, no code yet).
- [`docs/cargo_estado.md`](docs/cargo_estado.md) · [`docs/cargo_roadmap.txt`](docs/cargo_roadmap.txt) · [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — living docs.
- [`docs/CREDITOS.md`](docs/CREDITOS.md) — third-party asset credits (license obligation: two Sketchfab CC BY 4.0 ammo models, plus the pickup-animation reuse below).
- [`CLAUDE.md`](CLAUDE.md) — guide for assistance with Claude Code.

## Credits

- The **"Hands"** SWEP (default unarmed state) is a port of
  [*Apex Legends: Holster/Melee SWEP*](https://steamcommunity.com/sharedfiles/filedetails/?id=2792160770)
  by **Twilight Sparkle & Buu342** (with credits to Internet Overdoser, V92 and WebKnight;
  animations by Respawn Entertainment). The mod **declares no license** and has been
  unmaintained for years; **there's no explicit permission from its authors**. It's
  recycled under the community's standard policy: **full credits preserved** and
  **immediate removal of the assets if their authors request it** — get in touch and
  they're taken down. Changes from the original: class renamed to the module's namespace
  so both addons can coexist mounted, plus a custom viewmodel lighting fix (dark arms).
- **ARC9** weapon icons reuse the select icon that ARC9 itself generates
  (COMPAT-RUNTIME: its output is consumed via API, no code is copied).
- The two ammo box models (`ammo_sniper`, `ammo_winchester`) are Sketchfab assets by
  **jsandwich96** under **CC BY 4.0**, converted to Source format (modification
  disclosed per the license). Full writeup in [`docs/CREDITOS.md`](docs/CREDITOS.md).
- The WALK+USE pickup gesture reuses tuning values from *[GCAL] Improved Manual Pickup*
  and plays through **GCAL — Garry's Mod Compliant Armature Layer** (by **Midawek**),
  consumed via API and a runtime model reference — no files ship in Cargo's `.gma`. Full
  writeup in [`docs/CREDITOS.md`](docs/CREDITOS.md).
