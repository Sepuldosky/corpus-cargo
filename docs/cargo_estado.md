# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-26 (**entries 44-45 `[PENDIENTE]`, a verificar con la planilla Q**: un solo
serializador de dueño. El render y la hidratación salen a `Instances.RenderOwner`/`HydrateOwner` —una rutina,
el dueño como parámetro— y **`cont_<key>` pasa a ser archivo de dueño de primera clase**, con sus blobs
adentro: eso saca a **CRG-58 de INTENCION** y arregla el bug de que una crate con `persistKey` **perdía sus
uniques al reiniciar**. `cont_<key>` tiene ahora **un solo escritor** (`Containers.Save`); el wallet del
trader se queda aparte en `trader_<key>` (decisión del autor, por CRG-21). **CRG-59 acuñada.** Y la entidad
suelta sus referencias vivas —Entity y sets con Players de clave que `duplicator.CopyEntTable` copiaba— a
`Containers._live`/`Trade._live`, con API pública nueva (`Trade.StockOf`/`HasViewer`/`ClearViewers`,
`Containers.EntityOf`). El saneo **rompió el NextBot de Sidorovich** y se arregló en la misma tanda (4.ª raíz,
decisión del autor). Convar dev `cargo_dev_persist_key`, vacía por default: sin ella ninguna entidad declaraba
`persistKey` y la ruta del dueño persistente no tenía cómo ejercerse en juego. Harness **418** (eran 393, y
los 393 quedaron intactos durante el refactor). Antes, **entry 43 `[APLICADO]`, confirmada en juego**: el framework estrenó
`Corpus.Data.List`/`Delete` y el **scope** de COR-19, y Cargo es su primer consumidor real —
`cargo_dev_purge_legacy` lista y purga los `inst_*` legacy de terceros con **dry-run por
default** (sin gate de admin todavía, CRG-45), y los dos archivos de catálogo `autogen_defs` e
`icon_overrides` declaran `scope = "config"`. **No mueve un solo archivo.** Los cinco checks de
la planilla **T** de corpus que tocan este repo están en PASA (T5, T6, T7 dry-run, T8 borrado
2 de 2, T9 inventario intacto); el ✗ que queda abierto, T4, es del framework. Harness 393/393.
Antes, **entries 41-42 `[APLICADO]`, confirmadas en juego —
planilla P, los cinco checks en PASA**). El blob de instancia **dejó de tener
archivo propio**: viaja embebido en el archivo de su dueño (`inv_<steamid64>`) bajo `instances`, y
`Instances._live` es la única verdad de runtime (CRG-56/57/58, §12 reescrita). La medición que lo
originó: **354 huérfanas sobre 370 archivos** en la data real, todas estado de mundo que nunca
debió persistirse — la causa era `Instances.Create` escribiendo sin saber de quién era la
instancia. Cierra de paso **roadmap #13** (murió el `file.Delete` crudo) y la deuda del
**CHANGELOG #10** (`cargo_persistence 0` ahora sí no escribe nada). Plan madre:
[`../../dev/PLAN_cargo_persistencia_gc.md`](../../dev/PLAN_cargo_persistencia_gc.md).
Antes: **entries 36-40 `[APLICADO]`, confirmadas en juego,
commiteadas y pusheadas** — pasada de compat/economía + saga VJ. La 36: MTs-255-12 a slot largo
(su `SWEP.Class` EFT es "Revolver" y la regla sidearm ganaba), **precios por familia**
(`Capture.WeaponValueFor`: `weapon_vj_*` a $200 plano), attachments ARC9 con `value = 100`, y
**Quick Loadouts apagado** ya no corre el strip incondicional en el primer spawn. Las 37-40, la
**saga de armas VJ**, en su forma final: el `PlayerCanPickupWeapon` de VJ corre **embebido en el
world gate** (un solo hook — la lección: el orden de `hook.Call` entre hooks distintos NO es de
inserción), las armas **NPC-only** (`MadeForNPCsOnly`) no son tomables por ninguna ruta / nunca
se acuñan / se purgan al spawn, la toma respeta `vj_npc_wep_ply_pickup 0`, el drop cae al piso
sin re-captura, y el **regalo de munición se neutraliza antes de existir** (copia propia de
`Primary` con `PickUpAmmoAmount = 0` en la instancia — sin fantasma en el history de DGL4).
Antes: **entry 35** (banco de sonidos de UI + persona del trader) y **34** (suministros HL2 +
mochilas genéricas + `Items.SetModel`), ambas `[APLICADO]` y confirmadas.)

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
- **Compat Quick Loadouts** (entry 32, confirmada en juego): takeover de su hook `PlayerLoadout`
  (`corpus_cargo_quickloadout.lua`, ÚLTIMO en el manifest) — los heals de Cargo corren siempre
  antes del strip, los cargadores se banquean a los blobs, el cinturón no se drena, y el loadout
  llega como **entrega de ítems** vía la captura (dedup anónimo, sin éter). Mid-round el arma en
  mano vuelve a la mano. Sin el mod montado el archivo es inerte; kill-switch
  `cargo_quickloadout_compat`. Referencia: `dev/Cargo_QuickLoadouts_Referencia.md`.
- **El holster anima el enfundado** (entry 33, confirmada en juego): reciclaje de Simple Holster —
  cascada `ACT_VM_HOLSTER→…` con **undraw** reverso para armas sin anim dedicada, exclusión de
  bases que ya animan (ARC9 &co.), candados `StartCommand` + `m_flNextAttack` (absoluto, fix del
  original), memoria `m_hLastWeapon` (Q alterna arma↔manos) y rate-limit 0,5 s. Spawn va
  `instant` (#4). Kill-switch `cargo_holster_anim`. Referencia:
  `dev/Cargo_SimpleHolster_Referencia.md`.
- **Hands pega como puños** (entry 26, confirmado en juego): puñetazo **3-4** dmg
  (era 37-47) y se acabó el tirón al volver a `idle` — el port medía la duración
  de la secuencia **equivocada** (`SequenceDuration()` sin argumento, leída
  después de pedir el cambio). LMB = mano izquierda, RMB = derecha. **En 3.ª
  persona no alterna, y no es un defecto:** el hold type `fist` tiene **una sola**
  actividad de ataque (`sh_anim.lua`: `ACT_MP_ATTACK_STAND_PRIMARYFIRE` →
  `index + 5`), no existe gesto de puño izquierdo en el set de anims de jugador —
  el `weapon_fists` de Valve tiene exactamente la misma limitación. Aceptado.
- **Suministros HL2 + mochilas genéricas + `Items.SetModel`** (entry 34, confirmada
  en juego): el framework base trae Health Kit/Vial/Battery como ítems (valores y
  sonidos de pickup del ENGINE — no es medicina, Coagulant intacto) y dos mochilas
  para Back (+12/+24 kg) **sin modelo a propósito**: la cajita de cartón es el
  default honesto de todo def setting-agnostic, y un addon de contenido lo
  re-viste desde afuera con `Items.SetModel(id, model)` (orden-independiente,
  sobrevive re-registro, gana al `model` declarado). `corpus-stalker` lo consume
  para venda/botiquín (wick/spec45as) y las mochilas (hgn backpack-1/2, mapeo
  confirmado en juego). Adquisición dev por ítem: `cargo_dev_items [filtro]` +
  `cargo_dev_give_item <id|texto> [n]`.
- **Sonidos de UI + persona del trader** (entry 35, `[APLICADO]`): banco de GAMMA
  del framework (`corpus/sound/corpus/cargo/`, COR-17) cableado con gate
  `file.Exists` — mochila/estuche al abrir/cerrar por estado, drop, y selección
  por categoría en el clic del grid (sidearm=wpn, largas=wpnbig, por
  `equip_slots`). El trader demo: `Trade.SetDefaultPersona` (perfil cosmético de
  un addon de contenido) + callbacks `OnTradeOpened/Dealt/Closed` + idles de
  plaza rotados + voz por proximidad (saludo/espera 1 min/despedida). Sin
  persona: citizen mudo; sin banco: UI muda, consola limpia.
- **Harness offline: 425 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN); `cargo_selftest` 83 client / 76 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Nada.** Las entries 44-45 (B3) quedaron confirmadas el 2026-07-26 con la **planilla Q en 5/5**,
  tras **seis rondas**: Q1 (la crate persistente conserva su unique, con ícono y footprint) · Q2 (el
  trader efímero re-siembra en un mapa nuevo, verifica D1) · Q3 (`gm_save`/`gm_load` deja crate y
  trader usables, con la cara del NextBot neutra y parpadeando) · Q4 (el slice 1 del comercio
  intacto) · Q5 (Sidorovich muere, deja ragdoll y respawnea). Harness **425 verdes**, checker limpio,
  espejo regenerado. **Commiteado y pusheado** en los tres repos.
  **Las rondas no fueron ruido: tres de los cinco defectos de la tanda los encontró el CAMPO DE
  NOTAS de checks marcados PASA**, no un check en rojo.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- **Deuda de premisa para B4, anotada:** `gm_load` **no carga desde la consola** en la instalación
  del autor (el menú SAVES sí; descartados sus addons apagándolos todos). El PROMPT de B4 no asume
  `gm_load <nombre>` como ruta de verificación.
- Antes, las entries 41-42 (B1) quedaron confirmadas el 2026-07-25 con la **planilla P**
  —la primera sección de planilla de Cargo— **en PASA los cinco**: P1 arranque limpio · P2
  ningún archivo suelto en el ciclo de vida de un ítem · P3 el relog conserva equipo,
  condición y sub-slots · P4 `cargo_persistence 0` no escribe nada · P5 el mundo es efímero
  y no deja rastro. Harness offline: **373 checks verdes** en ambos realms. **Sin commitear
  todavía** (GIT-7). Antes, la saga VJ (37-40) y la pasada de compat/economía (36) habían
  quedado confirmadas el 2026-07-24, ya commiteadas y pusheadas.

## Frentes abiertos (anotados, NO arreglados)

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
- Peso nominal de attachments; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **B4 — el savegame de GMod** ([`../../dev/PLAN_cargo_persistencia_gc.md`](../../dev/PLAN_cargo_persistencia_gc.md)):
   estrena la cadena `PreEntityCopy` → `PostEntityPaste`, y arranca sobre una entidad ya limpia —
   que es lo que la entry 45 dejó hecho y lo que Q3 midió. PROMPT escrito:
   [`../../dev/PROMPT_cargo_b4_savegame.txt`](../../dev/PROMPT_cargo_b4_savegame.txt). Lleva dos
   premisas medidas en juego que no se pueden ignorar: `gm_load` va **por el menú**, y el estado que
   una entidad necesita entre partidas **se valida por VALOR, no por momento**.
2. **Slice 2 del comercio** (desplazado por decisión del autor el 2026-07-25, D4 del plan
   madre): el dinero como entidad (`Cargo_Trade` §7 — botar efectivo desde el botón $,
   línea de solo-dinero en el basket). Después el slice 3 (jugador-trader con doble
   confirm). Semilla del chat nuevo:
   [`../../dev/HANDOFF_cargo_trade_slice2.md`](../../dev/HANDOFF_cargo_trade_slice2.md).
   La entry 27 se confirma de paso en esa pasada (checklist en el artifact).
3. Remitir el fix de brazos oscuros a Twilight (acción del autor).
4. **#41 — explosivos ARC9 como stack throwable** (bloque propio, pedido del
   autor): hoy las granadas de EFT/CS:GO/MW2019 se equipan en Primary. El
   clasificador ya las etiqueta `thrown`; falta el destino (son `unique` y el
   slot Throwable pide un **stack**). Enlaza con el #32.
5. Cuando se prioricen: **#42** (el lanzagranadas capturado no dispara — perdió
   su attachment de munición; sospecha: el puente ARC9 §10), **#36** (slot HL2
   alineado), **#35** (footsteps), **#44** (overlay de máscara
   de gas para cascos cerrados — los sonidos ya están en el banco, SIN DISEÑAR).
   (El **#37** —saga VJ completa— quedó resuelto y confirmado en las entries 37-40.)

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
