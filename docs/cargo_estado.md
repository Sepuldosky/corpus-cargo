# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-13 (**roadmap #23 cerrado**: sesión de
diseño con el autor → set FIJO de 8 tabs de display sobre las categorías
internas → entry **19 `[PENDIENTE]`**. Sigue abierto el **18**
(`Inventory.HasItem`, lo confirma el re-test G4 de Coagulant). Frentes que
dejó la pasada anterior: **#36**, **#37**, **#38**. Lo próximo es el bloque
grande de **comercio**.)

---

## Qué existe hoy

- **Todo el arco de entries 1-17 `[APLICADO]` y confirmado en juego.**
  En orden: Block 1 (inventario: contrato de ítems, slots/sub-slots, peso,
  providers, contenedores), captura de armas del engine, imágenes de ítems
  (render a RT + editor), persistencia completa de equipadas, armas de mundo
  por WALK+USE, UI fullscreen 3 columnas/3 estados con gradas, holster +
  orden STALKER + SWEP "Hands", drop nativo + reconciliador universal,
  **munición: el cinturón ES el pool** (§16, espejo 4 Hz agnóstico de base)
  + su UX (reorder, unload, gate de ítems), **wheel menu** (§17) + **slot
  throwable** (§4) + columna apilada, Bloque D de UX (#30 spawnmenu, #28
  drop de slot, #24 retícula, **#29 paletas runtime + teñido DGL4**) y los
  frentes de la 2.ª pasada (#32 taxonomía de granadas + cajas por WALK+USE,
  #33 hub ARC9 completo, #34 compat con mods de movimiento).
- **Tabs de display con set FIJO de 8** (#23, entry 19): `All · Weapons ·
  Ammo · Gear · Mods · Meds · Food · Misc` — agrupación sobre las categorías
  internas, que quedan intactas para el grammar `"category:a,b"`. La fila se
  dibuja siempre entera y lo no mapeado cae en Misc (§7.1).
- **Harness offline: 279 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN); `cargo_selftest` 66 client / 59 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Entry 19 (tabs fijas, #23):** fila en UNA línea con las 8 tabs siempre
  presentes (vacías atenuadas), cada ítem bajo su tab, sub-slots intactos.
- **Entry 18 (`Inventory.HasItem`):** lo confirma el re-test G4 de la ronda 4
  de Coagulant (torniquete `unique` desde la UI — el resto del CHANGELOG está
  `[APLICADO]` y confirmado).

## Frentes abiertos (anotados, NO arreglados)

- **Drop de armas VJ vuelve solo al inventario** → **roadmap #37** (reporte
  4c: re-captura instantánea del drop; diagnóstico contra el mod vivo).
- **Slot del menú HL2 desalineado del slot Cargo** → **roadmap #36** (pedido
  17c: la RPD de EFT es Slot 4 de engine aunque esté equipada como primary).
- **Texturas negras en playermodels ZONA** (SEVA Woodland/Heavy/EXO-Heavy
  cuerpo; Cadpat/Freedom/Monolith chaleco) — lado addon `corpus_stalker`
  (territorio del autor; huelen a `.vmt/.vtf` faltantes en el copy).
- **Footsteps mudos al togglear `sv_bm_enabled`** → **roadmap #35** (lado
  mod: better movement v2; el remedio `sv_bm_slow_footsteps 0` NO funcionó —
  la sospecha del math.huge queda sin confirmar; investigar con el mod vivo).

## Remanentes / deuda conocida

- **Diseñado sin implementar:** comercio (`Cargo_Trade`) — siguiente bloque.
- **Munición (§16.6/§16.7):** cargadores rellenables con toggle; binding de
  ammo-atts de EFT (`def.ammo.att` reservado en el schema); hueco
  `SWEP.ForceDefaultAmmo` declarado (escalación anotada: ledger de
  conservación); las entidades `arc9_ammo` reparten por su propio `Touch` y
  el espejo las absorbe al cinturón en vez del grid.
- **Íconos:** fuente ARC9 256² a 1080p (deuda aceptada, 2.ª pasada
  2026-07-12); el editor no afecta la cámara de armas ARC9; captura de armas
  de mundo sin bajar al spec de `Cargo_ItemImages_Arquitectura.md`.
- **Remitir el fix de brazos oscuros a Twilight** (ya confirmado, acción del
  autor).
- `Corpus.Data` sin `Delete`; peso nominal de attachments; instancias
  huérfanas sin GC; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Comercio** (`Cargo_Trade_Arquitectura.md`, diseño cerrado §1-12) — el
   bloque grande: implementarlo por vertical slices, reusando el primitivo de
   contenedores (§8) y la interfaz de dinero (§6). Semilla:
   [`../../dev/HANDOFF_cargo_23_comercio.md`](../../dev/HANDOFF_cargo_23_comercio.md) §3.2.
2. Remitir el fix de brazos oscuros a Twilight (acción del autor).
3. Cuando se prioricen: **#36** (slot HL2 alineado), **#37** (drop VJ,
   diagnóstico contra el mod vivo), **#35** (footsteps), **#38** (trivia).

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
