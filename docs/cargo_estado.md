# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-14 (**slice 1 del COMERCIO confirmado en
juego**: entries **19** y **20** → `[APLICADO]`. De las dos pasadas siguientes
quedan **21** y **22** `[PENDIENTE]`: el peso deja de bloquear una transacción,
la línea del basket es un **agregado sobre todos los stacks** del ítem (bug
real: el stack gemelo era inalcanzable) y el click carga 25% del `max_stack`,
con **SHIFT+click = todo**.)

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
- **`Inventory.HasItem(ply, id)`** (entry 18): presencia sobre **ambas** clases
  de ítem. `CountItem`/`TakeItem` son de stacks — un `unique` (`{id, uid}`) no
  existe para ellos. Los módulos que solo preguntan "¿lleva uno?" (Coagulant
  con su torniquete) van por acá.
- **Comercio, slice 1** (entry 20, `Cargo_Trade` §2-§5/§8/§10): `def.value` +
  curva de condición + spread; **el trader ES un contenedor** (`Containers.Attach`)
  con capa de precio — el primitivo inventario-en-entidad de §2 no se construyó
  de nuevo; entidad demo `corpus_cargo_trader`; **estado Trade** del frame con
  basket, strips Buy/Sell y neto; **`Confirm` atómico** en server (valida dinero,
  peso y existencia, y recién ahí mueve). El basket del cliente es intent puro.
  **El peso NO bloquea una transacción** (enmienda del autor, entry 21): se puede
  comprar sobrecargado — la curva de peso lo cobra en velocidad; el límite sigue
  vigente para lo que se recoge del suelo. Click = stack entero; parcial con click
  derecho.
- **Harness offline: 318 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN); `cargo_selftest` 76 client / 69 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Entries 21 y 22 (enmiendas del comercio):** el peso no bloquea una compra;
  click = 25% del `max_stack`, SHIFT+click = todo, click derecho = cantidad
  exacta; y una línea del basket abarca **todos** los stacks de ese ítem (vender
  240 balas que viven como 2×120 se lleva las 240).

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

- **Comercio:** faltan los slices **2** (dinero como entidad: botar / línea de
  solo-dinero en el basket) y **3** (jugador-trader con doble confirm, que
  incluye el traspaso P2P) — `Cargo_Trade` §12.bis. Los `value` son números de
  arranque, a calibrar en juego; el trader demo no persiste entre mapas; el
  cliente formatea el dinero con el shape del provider nativo USD.
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

1. **Slice 2 del comercio**: el dinero como entidad (`Cargo_Trade` §7 — botar
   efectivo desde el botón $, línea de solo-dinero en el basket). Después el
   slice 3 (jugador-trader con doble confirm). La entry 21 se confirma de paso
   en esa misma pasada (checklist en el artifact).
2. Remitir el fix de brazos oscuros a Twilight (acción del autor).
3. Cuando se prioricen: **#36** (slot HL2 alineado), **#37** (drop VJ,
   diagnóstico contra el mod vivo), **#35** (footsteps), **#38** (trivia).

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
