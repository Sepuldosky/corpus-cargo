# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-23 (**pasada unificada COA-2 + Cargo**: se confirmó el
**addendum 2 de la 26** (`FORCE_SCALE = 0.2`, el cadáver trastabilla) → `[APLICADO]`. La **27** se
cerró en ronda 2 (confirmada en juego 2026-07-23): Sidorovich ✓, toma del piso de clase equipada ✓
(**#28**), y strips parejos vía **#30** (BUY crece por el footer de peso). El **addendum de la 25**
era arsenal nuevo, no regresión: 11 clases `makeshift` catalogadas (**#31**), dump `sin peso: 0 |
sin precio: 0` ✓. Antes, 2026-07-14: entries 21/22 —basket agregado,
click 25% / SHIFT = todo, peso no bloquea.)

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
  basket, strips Buy/Sell y neto; **`Confirm` atómico** en server (valida
  existencia, dinero del jugador y wallet del trader, y recién ahí mueve). El
  basket del cliente es intent puro.
  **El peso NO bloquea una transacción** (entry 21): se puede comprar sobrecargado
  — la curva de peso lo cobra en velocidad; el límite sigue vigente para lo que se
  recoge del suelo (techo duro: **2× la capacidad**). Una línea del basket es un
  **agregado sobre todos los stacks** del ítem (entry 22); click = 25% del
  `max_stack`, **SHIFT+click = todo**, click derecho = cantidad exacta.
- **Trivia de armas: la pone el SWEP, no una tabla** (entry 23, roadmap #38).
  La captura lee `SWEP.Description` y el bloque `SWEP.Trivia` de
  `weapons.Get(class)` (ya heredados por la cadena `SWEP.Base`) → `def.trivia`
  + `def.trivia_rows`; el tooltip pinta **"Specs"** bajo los stats, sin exigir
  el arma en la mano. **Cualquier pack ARC9 que se monte después queda cubierto
  solo.** `corpus_cargo_weapon_trivia.lua` es la *excepción* (40 entradas):
  huecos del pack, herencias mentirosas (el M16A1 hereda de `arc9_eft_m4a1`) y
  las armas HL2, que no son SWEPs. **ARC9MW: las 87 clases** con peso y precio
  — los pesos los **declara el propio pack** en su `SWEP.Trivia` (54/87
  transcritos; el resto `real approx`).
- **Cada arma sabe a qué slot va** (entry 24, roadmap #39). Los tres slots de
  arma filtran por `category:weapons`, así que **cualquier** arma entraba en
  cualquiera (un RPG en Sidearm). El def autogen ahora setea `equip_slots`,
  **derivándolo del propio SWEP** (`SWEP.Class` por arma, `SubCategory` por
  pack, ambos resueltos por herencia): pistolas → Sidearm, largas →
  Primary/Secondary, melee → categoría `melee`, sin clasificar → libre.
  `SWEP.Slot` **no** es la señal (inconsistente entre packs). Lo ya equipado en
  un slot ilegal se reconcilia al spawn.
- **El arsenal real del autor, pesado y precificado** (entry 25, roadmap #40).
  Su volcado (`cargo_dev_dump_weapons`) tenía **369 SWEPs y 184 sin peso**:
  packs EFT que no están en `dev/other/` (SMG, escopetas, LMG, melee, gear,
  `makeshift`), el pack entero de **CS:GO** (`arc9_go`) y `arc9_wtt`. El volcado
  alcanzó para catalogarlos **sin tener el pack**. Hoy: **360 armas vivas, las
  360 con peso Y precio, cero huecos** (sin `value` no se comercian, y ese
  hueco era el mismo). El M60E4 pesa **10,5 kg**. El propio `cargo_dev_dump_weapons`
  ya **no grita lobo**: las plantillas de SWEP y las clases de `Capture.Ignore`
  salen `n/a`, no `MISSING`, y trae **columna de precio** + resumen de huecos
  reales.
- **Hands pega como puños** (entry 26, confirmado en juego): puñetazo **3-4** dmg
  (era 37-47) y se acabó el tirón al volver a `idle` — el port medía la duración
  de la secuencia **equivocada** (`SequenceDuration()` sin argumento, leída
  después de pedir el cambio). LMB = mano izquierda, RMB = derecha. **En 3.ª
  persona no alterna, y no es un defecto:** el hold type `fist` tiene **una sola**
  actividad de ataque (`sh_anim.lua`: `ACT_MP_ATTACK_STAND_PRIMARYFIRE` →
  `index + 5`), no existe gesto de puño izquierdo en el set de anims de jugador —
  el `weapon_fists` de Valve tiene exactamente la misma limitación. Aceptado.
- **Harness offline: 355 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN); `cargo_selftest` 76 client / 69 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Nada de esta tanda** — la ronda 2 cerró en juego el 2026-07-23: **W1** strips parejos (#30) y
  **X1** dump `sin peso: 0 | sin precio: 0` con las 11 makeshift (#31), más **W3** (#28) y el **cap
  del torniquete** (#29). Todo `[APLICADO 2026-07-23]`.

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
   slice 3 (jugador-trader con doble confirm). Semilla del chat nuevo:
   [`../../dev/HANDOFF_cargo_trade_slice2.md`](../../dev/HANDOFF_cargo_trade_slice2.md).
   La entry 27 se confirma de paso en esa pasada (checklist en el artifact).
2. Remitir el fix de brazos oscuros a Twilight (acción del autor).
3. **#41 — explosivos ARC9 como stack throwable** (bloque propio, pedido del
   autor): hoy las granadas de EFT/CS:GO/MW2019 se equipan en Primary. El
   clasificador ya las etiqueta `thrown`; falta el destino (son `unique` y el
   slot Throwable pide un **stack**). Enlaza con el #32.
4. Cuando se prioricen: **#42** (el lanzagranadas capturado no dispara — perdió
   su attachment de munición; sospecha: el puente ARC9 §10), **#36** (slot HL2
   alineado), **#37** (drop VJ), **#35** (footsteps).

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
