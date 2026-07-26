# CLAUDE.md

Guía para trabajar en **Cargo** — el módulo de inventario del ecosistema Corpus (addon GLua para Garry's Mod). Léela antes de tocar código o docs de este repo.

## Qué es

Cargo es el módulo de **inventario** del ecosistema Corpus: contrato de ítems (dos clases), grid estilo STALKER/GAMMA con **gradas de footprint `w × h`** (solo render — sin gestión espacial, enmienda 2026-07-11), slots de equipamiento con sub-slots genéricos, peso→movimiento, providers de dinero/facción, contenedores en mundo y puente de attachments ARC9. Es un addon Gmod independiente con su propio git, que **hard-depende** de Corpus (la única dependencia dura del ecosistema — cita COR-11) y de nadie más.

Es sobre todo un **hub de consumo** —Coagulant, Craving y Caliber registran sus ítems contra el framework que Cargo expone—, pero **NO es hoja** en el grafo de deps: consume Coagulant (`OnEncumbrance`, contrato congelado y ya en producción) y Cortex (`GetFactionInfo`, mock-first a la espera de su Block). Ambos con lazy-check + `pcall` y degradación honesta (contrato #9).

**Regla cardinal (cita CRG-1; su sede es `../corpus/docs/CORPUS_Architecture.md` §5):** Cargo posee el "cómo se define, pesa, guarda y renderiza" un ítem; el módulo dueño posee el "qué hace" (`onUse`, semántica de condición, contenido del blob). Cargo transporta blobs sin interpretarlos. Ver §3 de [`docs/Cargo_Architecture.md`](docs/Cargo_Architecture.md).

**Regla cardinal (cita COR-1 y COR-10):** nada de lógica de dominio sube a Corpus, y la lógica de dominio ajena no baja a Cargo (la medicina es de Coagulant, la mitigación de armadura es de Caliber Block 3 — acá solo existe el punto de enganche).

## Docs del proyecto — jerarquía de lectura

Antes de tocar código o diseño, lee en este orden (los tres primeros son **docs vivos**):

1. **Estado de HOY** → [`docs/cargo_estado.md`](docs/cargo_estado.md). Foto del AHORA, ≤1 pantalla. **Léelo ANTES** que la arquitectura.
2. **Rumbo** → [`docs/cargo_roadmap.txt`](docs/cargo_roadmap.txt). Qué sigue y en qué orden.
3. **Historial de parches** → [`docs/CHANGELOG.md`](docs/CHANGELOG.md). `[PENDIENTE]`/`[APLICADO YYYY-MM-DD]`, nunca se borra ni renumera.
4. **Metodología de trabajo** → [`../corpus/docs/corpus_flujo_trabajo.txt`](../corpus/docs/corpus_flujo_trabajo.txt). **Doc canónico compartido** por todo el ecosistema — no se duplica acá.
5. **Arquitectura del módulo** → [`docs/Cargo_Architecture.md`](docs/Cargo_Architecture.md) (Block 1: inventario). Doc particular autocontenido.
6. **Arquitectura del banco de trabajo** → [`docs/Workbench_Arquitectura.md`](docs/Workbench_Arquitectura.md). Subsistema propio (craft/reparación/desarme), **bloque futuro — NO implementado**.
7. **Convenciones de commit** → [`docs/cargo_convenciones_commits.txt`](docs/cargo_convenciones_commits.txt). Alcances específicos de **este** repo.

Los mockups congelados de la UI viven en [`docs/mockups/`](docs/mockups/) — dicen QUÉ va dónde, no cómo maquetarlo (son CSS; VGUI no tiene flexbox: todo es Dock/SetPos/Paint manual).

## Idioma

**CRG-48 —** tres capas, no las mezcles:

- **Código (comentarios e identificadores): inglés** (estilo fijado al estrenar este repo — difiere de corpus/caliber, iguala el del archivo que edites).
- **Strings de cara al jugador (UI, nombres de ítems, notices, menús, helps de convar): inglés** — es el idioma del mod (decisión del autor, primera pasada en juego 2026-07-10). Nada en español debe llegar a pantalla.
- **Docs, mensajes de commit y logs de consola (`Corpus.Log`): español** (precedente del ecosistema); los `<tipo>` de commit en inglés (ver convenciones).

## El workspace multi-repo

Este repo (`corpus-cargo/`) es una de las **ocho** carpetas del workspace `corpus.code-workspace` — siete repos git + `dev/`, que no es repo. La raíz `corpus/` es el framework del que todos hard-dependen; los otros cuatro **módulos** hermanos (`corpus-cortex/`, `corpus-caliber/`, `corpus-coagulant/`, `corpus-craving/`) se detectan en runtime vía `Corpus.GetModule`, nunca se asumen. La séptima raíz, `corpus-stalker/`, no es un módulo sino el **addon de contenido** de la Zona (anomalías, artefactos, defs, y los assets que Cargo consume por detección — el modelo de Sidorovich, sin hard-dep). La investigación de mods de terceros (ARC9 etc.) vive fuera de git en `dev/other/` — consulta `../dev/mods_workshop_mapa.md` antes de diseñar cualquier integración con mods ajenos.

## Mapa de archivos

Un **manifest de carga explícito** (`corpus_cargo_init.lua`, único archivo en `lua/autorun/`) registra el módulo, declara el contrato público y hace `include()` en orden determinista — patrón template tomado de Caliber (boot diferido a `Initialize`, sonda `CorpusReady`, falla ruidoso sin framework). Los sub-archivos viven en `lua/corpus_cargo/<realm>/`, **fuera** de `lua/autorun/`. Las entidades van en `lua/entities/` (las carga el sistema de scripted_ents, no el manifest) y resuelven el módulo en runtime, nunca en file-scope.

| Archivo | Realm | Rol |
|---|---|---|
| [`lua/autorun/corpus_cargo_init.lua`](lua/autorun/corpus_cargo_init.lua) | shared | Entry + registro (`cargo`) + **bloque CONTRACT** + manifest |
| [`lua/corpus_cargo/shared/corpus_cargo_util.lua`](lua/corpus_cargo/shared/corpus_cargo_util.lua) | shared | Blobs de net (JSON comprimido) + re-normalización de claves numéricas |
| [`lua/corpus_cargo/shared/corpus_cargo_items.lua`](lua/corpus_cargo/shared/corpus_cargo_items.lua) | shared | **Contrato de ítems** (§3): `Items.Register`, categorías, **tabs fijas de display** (§7.1), filtro único, **sub-slots** (`DeclareSubSlot`, §4) |
| [`lua/corpus_cargo/shared/corpus_cargo_trade.lua`](lua/corpus_cargo/shared/corpus_cargo_trade.lua) | shared | Matemática **pura** de precio (`value × condición × spread`) — `Cargo_Trade` §4/§5. El server es la autoridad; el cliente usa la misma función para pintar. + **Registro de persona del trader** (`SetDefaultPersona`/`GetDefaultPersona`, entry 35): perfil cosmético que registra un addon de contenido |
| [`lua/corpus_cargo/shared/corpus_cargo_slots.lua`](lua/corpus_cargo/shared/corpus_cargo_slots.lua) | shared | Slots de equipamiento (data, incl. Accessory 1/2 genéricos y los 3 de herramienta sandbox con clase exacta) + quick F1–F4 (disponibilidad por traje) + cinturón (`BELT_COUNT`) |
| [`lua/corpus_cargo/shared/corpus_cargo_weight.lua`](lua/corpus_cargo/shared/corpus_cargo_weight.lua) | shared | Curva pura peso→velocidad (§5) + capacidad base+mochila |
| [`lua/corpus_cargo/shared/corpus_cargo_movecompat.lua`](lua/corpus_cargo/shared/corpus_cargo_movecompat.lua) | shared | **Compat #34** (§5 enmienda): hook `Move` re-aplica la curva sobre mods que pisan walk/run cada tick (mult publicado por NW2Float `cargo_speed_mult`, piso 30); gated por `cargo_movement_compat` + el `sv_bm_enabled` del mod |
| [`lua/corpus_cargo/shared/corpus_cargo_ammo.lua`](lua/corpus_cargo/shared/corpus_cargo_ammo.lua) | shared | Tipos de munición HL2 como ítems (§16.2: modelo, peso, `max_stack`, etiqueta de calibre) + caras throwable canónicas (`cargo_throw_frag/slam`, §4) + remap `LegacyThrowIds` |
| [`lua/corpus_cargo/shared/corpus_cargo_supplies.lua`](lua/corpus_cargo/shared/corpus_cargo_supplies.lua) | shared | Suministros HL2 default (Health Kit/Vial/Battery, semántica de pickup del engine — no es medicina) + dos mochilas genéricas **sin modelo** (la cajita es el default; un addon de contenido las re-viste vía `Items.SetModel`) — entry 34 |
| [`lua/corpus_cargo/shared/corpus_cargo_arc9.lua`](lua/corpus_cargo/shared/corpus_cargo_arc9.lua) | shared | **Puente ARC9** (§10): hooks de inventario verificados + helpers de attach/detach/stats |
| [`lua/corpus_cargo/shared/corpus_cargo_dev.lua`](lua/corpus_cargo/shared/corpus_cargo_dev.lua) | shared | `cargo_selftest` + kit de ítems demo (`cargo_dev_give`) + adquisición por ítem (`cargo_dev_items` / `cargo_dev_give_item`, entry 34) + barras demo |
| [`lua/corpus_cargo/server/corpus_cargo_instances.lua`](lua/corpus_cargo/server/corpus_cargo_instances.lua) | server | Blobs de instancia únicos y uid. **Sin archivo propio**: el blob viaja embebido en el archivo de su dueño y `_live` es la fuente runtime (CRG-56/57, §12) |
| [`lua/corpus_cargo/server/corpus_cargo_money.lua`](lua/corpus_cargo/server/corpus_cargo_money.lua) | server | Interfaz de dinero + provider nativo USD (§6) |
| [`lua/corpus_cargo/server/corpus_cargo_inventory.lua`](lua/corpus_cargo/server/corpus_cargo_inventory.lua) | server | Inventario por SteamID64: stacks, equip, quick, cinturón (§15.2, solo forma), eyección obligatoria, net |
| [`lua/corpus_cargo/server/corpus_cargo_movement.lua`](lua/corpus_cargo/server/corpus_cargo_movement.lua) | server | Aplica la curva a walk/run + lazy-check Coagulant + publica el mult (NW2Float) para movecompat |
| [`lua/corpus_cargo/server/corpus_cargo_ammopool.lua`](lua/corpus_cargo/server/corpus_cargo_ammopool.lua) | server | Espejo cinturón↔pool a 4 Hz (§16.3-16.5, §16.9: el stack throwable equipado cuenta y paga primero), unload (#26), `WorldAmmoSpec` + veto puro de `item_ammo_*` |
| [`lua/corpus_cargo/server/corpus_cargo_weapon_weights.lua`](lua/corpus_cargo/server/corpus_cargo_weapon_weights.lua) | server | Pesos reales clase→kg para defs autogen (GAMMA DB 0.9.5 / `EFT approx` / **peso declarado por el propio ARC9MW**; fallback 2.5 kg). El manifest la carga **antes** de `capture.lua`: el re-registro al boot re-pesa lo ya capturado |
| [`lua/corpus_cargo/server/corpus_cargo_weapon_trivia.lua`](lua/corpus_cargo/server/corpus_cargo_weapon_trivia.lua) | server | **Excepciones** de trivia, no la fuente: la trivia sale de `SWEP.Description`/`SWEP.Trivia` del propio SWEP (ver contrato #12). Acá viven los huecos que el pack no escribió, las herencias mentirosas y las armas HL2 (que no son SWEPs) |
| [`lua/corpus_cargo/server/corpus_cargo_icons.lua`](lua/corpus_cargo/server/corpus_cargo_icons.lua) | server | Registro de overrides de cámara/footprint de íconos (def-level, persiste en `Corpus.Data` y viaja en el snapshot de defs) — ItemImages §4.3/§10 |
| [`lua/corpus_cargo/server/corpus_cargo_containers.lua`](lua/corpus_cargo/server/corpus_cargo_containers.lua) | server | Contenedores en mundo, transferencias, Take/Move all (§8) — **es el primitivo inventario-en-entidad** que reusa el trader |
| [`lua/corpus_cargo/server/corpus_cargo_trade.lua`](lua/corpus_cargo/server/corpus_cargo_trade.lua) | server | Traders (`AttachTrader` = contenedor + spread + wallet), sesión y **basket atómico**: valida TODO y recién ahí mueve (`Cargo_Trade` §2/§3) |
| [`lua/corpus_cargo/server/corpus_cargo_weapon_prices.lua`](lua/corpus_cargo/server/corpus_cargo_weapon_prices.lua) | server | `def.value` clase→precio de las armas capturadas (gemela de `weapon_weights`; sin entrada = **no comerciable**, incl. las tools sandbox) |
| [`lua/corpus_cargo/server/corpus_cargo_capture.lua`](lua/corpus_cargo/server/corpus_cargo_capture.lua) | server | Captura de armas del engine → ítems (spawn desarmado). **Post-equip vía `WeaponEquip`, sin vetar `PlayerCanPickupWeapon` en la ruta de give** — compat con mods de pickup (lección L4D IPS, ver header). El **world gate** del mismo archivo **sí** veta `PlayerCanPickupWeapon`, pero solo para armas **en reposo** en el mundo (edad > 0,5 s o spawneadas por nuestro drop): sin pickup por contacto, WALK+USE toma (roadmap #16, CHANGELOG #7). Defs `autogen` (crowbar/stunstick caen en `melee`) + `Capture.Ignore` para SWEPs de manos |
| [`lua/corpus_cargo/server/corpus_cargo_holster.lua`](lua/corpus_cargo/server/corpus_cargo_holster.lua) | server | Orden STALKER + holster (#22/#4): resuelve el intent `slotkey` contra `rec.equip`, re-apretar enfunda (Hands o nada, userinfo `cargo_holster_hands`), manos default al spawn. **Transición reciclada de Simple Holster** (entry 33): cascada de anims + undraw reverso, exclusión de bases que ya animan (ARC9 &co.), candados `StartCommand`/`m_flNextAttack`, memoria `m_hLastWeapon`, rate-limit 0,5 s |
| [`lua/corpus_cargo/server/corpus_cargo_quickloadout.lua`](lua/corpus_cargo/server/corpus_cargo_quickloadout.lua) | server | **Compat Quick Loadouts** (entry 32, sin UI): takeover de su hook `PlayerLoadout` (va ÚLTIMO en el manifest a propósito) — los heals de Cargo corren siempre antes del strip, banquea cargadores a los blobs, mid-round re-selecciona el arma en mano; el loadout llega como gives anónimos a la captura (entrega de ítems). Inerte sin el mod (COR-5) |
| [`lua/corpus_cargo/client/corpus_cargo_theme.lua`](lua/corpus_cargo/client/corpus_cargo_theme.lua) | client | Paleta/fuentes/helpers de pintado (única fuente de estilo) + paletas runtime y teñido DGL4 (§15.5) + `DrawCircle`/`DrawCircleOutlined` (primitiva única de círculo) + `SkinScroll` |
| [`lua/corpus_cargo/client/corpus_cargo_sounds.lua`](lua/corpus_cargo/client/corpus_cargo_sounds.lua) | client | Banco de sonidos de UI (entry 35): cues nombrados (abrir/cerrar por estado, drop) + selección por categoría del grid (mapa del autor en `corpus/sound/corpus/cargo/items/about.txt`; sidearm=`wpn`, largas=`wpnbig` por `equip_slots`). Gate `file.Exists` cacheado: sin el banco montado, mudo y sin errores (COR-17: assets no versionados) |
| [`lua/corpus_cargo/client/corpus_cargo_icons.lua`](lua/corpus_cargo/client/corpus_cargo_icons.lua) | client | Pipeline de íconos (modelo→RT→PNG en `data/`, caché local por cliente) — `Cargo_ItemImages_Arquitectura.md` |
| [`lua/corpus_cargo/client/corpus_cargo_iconeditor.lua`](lua/corpus_cargo/client/corpus_cargo_iconeditor.lua) | client | Editor dev `cargo_icon_edit` (encuadre orbit/zoom/pan + footprint manual → override en data) — ItemImages §8 |
| [`lua/corpus_cargo/client/corpus_cargo_statuspanel.lua`](lua/corpus_cargo/client/corpus_cargo_statuspanel.lua) | client | `StatusPanel.RegisterBar` + render (§11) |
| [`lua/corpus_cargo/client/corpus_cargo_pickup.lua`](lua/corpus_cargo/client/corpus_cargo_pickup.lua) | client | Feed de pickup en pantalla (`cargo_pickup_feed`) — señala el ítem recogido |
| [`lua/corpus_cargo/client/corpus_cargo_tooltip.lua`](lua/corpus_cargo/client/corpus_cargo_tooltip.lua) | client | Tooltip de inspección (§9): stats ARC9/manual, zonas, sub-slots |
| [`lua/corpus_cargo/client/corpus_cargo_grid.lua`](lua/corpus_cargo/client/corpus_cargo_grid.lua) | client | Grid por **gradas** (footprint `w×h`, §7 enmendado) + overlays por esquina (PaintOver, no CSS) |
| [`lua/corpus_cargo/client/corpus_cargo_ui.lua`](lua/corpus_cargo/client/corpus_cargo_ui.lua) | client | Frame **fullscreen 3 columnas / 3 estados** (§15: Solo/Loot/Trade — los tres construidos; equip STALKER, quick, cinturón, círculos sandbox, botón $, tabs, footer) + binds. En Trade la columna izquierda y la deal bar las arma `client/corpus_cargo_trade.lua` |
| [`lua/corpus_cargo/client/corpus_cargo_transfer.lua`](lua/corpus_cargo/client/corpus_cargo_transfer.lua) | client | Estado/wire de contenedores (§8): net + intents; el frame Loot vive en `corpus_cargo_ui.lua` |
| [`lua/corpus_cargo/client/corpus_cargo_trade.lua`](lua/corpus_cargo/client/corpus_cargo_trade.lua) | client | Sesión de comercio: snapshot del trader, **basket (intent puro: no mueve nada)**, columna de stock + deal bar del estado Trade |
| [`lua/corpus_cargo/client/corpus_cargo_hotkeys.lua`](lua/corpus_cargo/client/corpus_cargo_hotkeys.lua) | client | Teclas STALKER 1-7 (#22): intercepta `slot1`-`slot7` en `PlayerBindPress` y manda solo el intent (`cargo_weapon_slots` lo apaga); comando `cargo_holster`. Jamás intercepta `slot8` (el intent 8 es wheel-only) |
| [`lua/corpus_cargo/client/corpus_cargo_wheel.lua`](lua/corpus_cargo/client/corpus_cargo_wheel.lua) | client | **Wheel radial** (§17): HUDPaint sin VGUI, hold `cargo_key_wheel` (default G) / `+cargo_wheel`; commit = intent `slotkey` existente (+8 wheel-only del throwable); hub de info universal (AmmoInfo/CaliberOf verificados contra ARC9); chips quick/tools con anclajes configurables |
| [`lua/corpus_cargo/client/corpus_cargo_options.lua`](lua/corpus_cargo/client/corpus_cargo_options.lua) | client | Tab único `Corpus.UI.RegisterTab("cargo", …)` |
| [`lua/weapons/corpus_cargo_hands.lua`](lua/weapons/corpus_cargo_hands.lua) | shared | SWEP **"Hands"** — Apex Hands reciclado (créditos en el header, Workshop 2792160770) con fix de brazos oscuros (2.º intento, confirmado in-game 2026-07-12: `render.SuppressEngineLighting` + caja de luz propia muestreada en `EyePos` dentro de `PreDrawViewModel`/`PreDrawPlayerHands`, restaurada en los `Post`; el 1.er intento con `SetLightingOriginEntity` **falló y se revirtió** — CHANGELOG #9); assets propios salvo el .mdl (path original, no se recompila) |
| [`lua/entities/corpus_cargo_crate.lua`](lua/entities/corpus_cargo_crate.lua) | shared | Caja de prueba spawnable (E → panel de transferencia) |
| [`lua/entities/corpus_cargo_trader.lua`](lua/entities/corpus_cargo_trader.lua) | shared | Trader demo spawnable (E → estado Trade) — `Cargo_Trade` §10; sin IA: el comercio no le debe nada al comportamiento. + **Capa persona** (entry 35): idles de plaza rotados + voz por proximidad/eventos de trade (callbacks `OnTradeOpened/Dealt/Closed` que dispara el server de trade) — genérica: sin persona registrada es un citizen mudo |
| [`lua/entities/corpus_cargo_item.lua`](lua/entities/corpus_cargo_item.lua) | shared | Ítem dropeado en mundo (E → recoger) |

## Contratos que no debes romper

1. **Namespace: tabla única registrada** (cita COR-2; el invariante by-ref del que depende es COR-7)**.** Cada archivo abre con `local CARGO = Corpus.GetModule("cargo")` (el init la registró antes). Ningún archivo declara globals sueltos. Depende del invariante by-ref del registro de Corpus.
2. **Cargo transporta, no interpreta** (cita CRG-1)**.** El contenido del blob de instancia (condición, zonas, material de placa) lo define el módulo dueño; Cargo lo guarda y lo renderiza. `onUse` corre en el dueño; Cargo solo consume 1 unidad si devuelve `true` (COR-13). El registro de la def **y** de su `onUse` va en **ambos realms** (shared): ver COR-12, sede `../corpus/docs/CORPUS_Architecture.md` §5.
3. **Un solo primitivo de sub-slot** (cita CRG-8, sede `docs/Cargo_Architecture.md` §4)**.** Óptica-Head, exo/escudo-Body y placas-Body pasan TODOS por `Cargo.Items.DeclareSubSlot` + el filtro `"category:a,b"` de `MatchesFilter`. Nada de variantes ad-hoc.
4. **Eyección obligatoria** (cita CRG-9, sede `docs/Cargo_Architecture.md` §4)**.** Todo flujo que destruye un ítem con sub-slots ocupados eyecta primero (`EjectSubSlots`, con `skipCap`) — una placa o un generador jamás se pierden como efecto colateral.
5. **CRG-7 — Sin lavado de desgaste.** Los stacks solo se fusionan con condición idéntica; una placa gastada que vuelve de un sub-slot es un stack aparte.
6. **CRG-43 — Persistencia namespaced** (aplica COR-3; el remedio es a COR-8)**.** Todo vía `Corpus.Data` namespace `cargo`: `inv_<steamid64>`, `cont_<key>`, más los archivos de catálogo (`autogen_defs`, `icon_overrides`). **No hay clave `inst_<uid>`**: el blob de instancia viaja embebido en el archivo de su dueño (CRG-56, sede `docs/Cargo_Architecture.md` §12). El round-trip JSON **no** preserva tipos de clave: re-normaliza claves numéricas al cargar (`Util.NumberKeys` — quick slots, tanto server como client).
7. **Net namespaced** (cita COR-4)**.** Todo mensaje vía `Corpus.Net.Register("cargo", msg)` → `corpus_cargo_<msg>`. Nunca `AddNetworkString` crudo. **CRG-6 —** El server posee el inventario; el cliente solo envía intents y renderiza snapshots. Toda mutación termina en **Save + Sync + refresh de movimiento** (header de `corpus_cargo_inventory.lua`).
8. **ARC9: stats lectura-only, attach por SU API** (cita CRG-23, sede `docs/Cargo_Architecture.md` §10.3)**.** Los stats se leen con `GetProcessedValue` (claves reales: `DamageMax`/`Spread`/`RPM`, no "Damage"/"Accuracy"); instalar/quitar va por `SWEP:Attach`/`DetachAllFromSubSlot` (client-side, replica solo). La reconciliación con el menú C es por los hooks `ARC9_PlayerGetAtts/GiveAtt/TakeAtt` — no existe hook de attach puro. **CRG-24 — Los nombres de API de terceros y del engine (ARC9, mods de movimiento) nunca se asumen de memoria: se verifican contra `dev/other/`** (este bloque ya lo pagó y los dejó anotados en el header de `corpus_cargo_arc9.lua`).
9. **Detección, nunca asunción** (cita COR-5)**.** Cortex (facción), Coagulant (stamina) y ARC9 se consultan con lazy-check + pcall; sin ellos el header omite facción, la penalización queda en velocidad y el puente se apaga — degradación honesta, jamás crash.
10. **Prefijo de archivo por módulo** (cita COR-6)**:** `corpus_cargo_*.lua` en todo lo que cargue el engine.
11. **CRG-21 — Un solo inventario-en-entidad.** Contenedor, trader (y mañana el cadáver de Cortex) son **el mismo primitivo**: `Containers.Attach`. Un trader es ese contenedor **+ una capa de precio** (`Trade.AttachTrader`), nunca un inventario paralelo.
12. **CRG-41 — La trivia la pone el SWEP, no una tabla.** Un arma capturada se describe con su
    propio `SWEP.Description` + `SWEP.Trivia`, leídos de `weapons.Get(class)` (que ya
    resuelve la herencia por `SWEP.Base`). `Capture.WeaponTrivia` es la **excepción**
    —huecos del pack, herencias mentirosas, armas HL2 sin SWEP—, jamás la ruta normal:
    catalogar a mano cada arma de cada pack ARC9 es exactamente el trabajo que este
    diseño evita. Ni `trivia` ni `trivia_rows` se persisten: se re-derivan en cada boot,
    así que un pack nuevo cubre solo a las armas ya capturadas.
13. **El precio lo dice el servidor** (cita CRG-18, CRG-19 y CRG-20, sede `docs/Cargo_Trade_Arquitectura.md` §3-§4)**.** El basket del cliente es **intent puro**: no mueve nada y su total es decorado. En `Confirm` el server re-resuelve cada línea, la re-precia y valida **tres** cosas: existencia (la ref todavía está, y el count se recorta a lo disponible), que el jugador no quede en rojo, y que el wallet del trader alcance (si declaró uno finito). Recién si TODO pasa, mueve. **El peso NO es un gate** (derogado en la 1.ª pasada en juego, CHANGELOG #21): el jugador puede comprar por encima de su capacidad y salir sobrecargado — la curva de peso ya se lo cobra en velocidad; el límite de carga sigue rigiendo lo que se recoge del suelo. Por eso la transferencia de la compra va con `skipCap`. No hay ruta de rollback porque no hay mutación antes de la validación. Un ítem **sin `def.value` no se comercia** (ausencia = "no está a la venta", no "gratis").

## Trampas de VGUI y HUD (heredadas del proyecto — no las redescubras)

- **CRG-27 —** `DNumSlider` y `DPropertySheet:Dock(FILL)` colapsan dentro de `DScrollPanel` — filas manuales.
- **CRG-27 (misma norma) — `DIconLayout:Dock(FILL)` dentro de `DScrollPanel` también colapsa** (canvas se dimensiona a los hijos, el hijo llena el canvas): celdas recortadas y `Refresh()` repoblando un layout de altura cero. Usa `Dock(TOP)` + `InvalidateLayout(true)` — pagado en la primera pasada en juego de este repo.
- Overlays de celda = `PaintOver`/paneles con `SetPos`, no flexbox.
- Texto en celdas/filas siempre con `Theme.FitText` (elipsis) — los nombres largos desbordan.
- Refresca en sitio leyendo `CARGO.ClientState` desde los `Paint` (así está hecho el frame); no reconstruyas el panel en callbacks de valor.
- (cita CRG-26, sede `docs/Cargo_Architecture.md` §17.5) **`draw.RoundedBox` con radio = mitad NO produce un círculo** — su radio está cuantizado a los materiales de esquina de GMod. Todo círculo pasa por `Theme.DrawCircle`/`DrawCircleOutlined` (polígono triangulado, primitiva única del theme) — pagado in-game en los círculos sandbox (entry 13).
- (cita CRG-25, sede `docs/Cargo_Architecture.md` §17.7) **GMod DESENGANCHA un hook de `HUDPaint` que erra**: un error de pintado y la superficie muere en silencio la sesión entera. Pintado y commit van en `pcall` + `Corpus.Log` ruidoso (patrón del wheel, pagado en la 1.ª pasada del entry 13).
- (cita CRG-28, sede `docs/Cargo_Architecture.md` §17.6) **`HUDPaint` no tiene clipping de panel**: todo lo que pueda sangrar (hatching, rellenos parciales) se recorta con `render.SetScissorRect` — pagado con el hatching de los quickslots del wheel.
- **Leer `gui.MousePos` ANTES de apagar `gui.EnableScreenClicker`**: apagado el screen clicker, no está garantizado que siga reportando la posición del cursor libre.
- (cita CRG-24) **Los nombres de API de ARC9 y de los mods de movimiento se verifican contra `dev/other/`, nunca de memoria** (contrato #8 para ARC9; los headers de `corpus_cargo_arc9.lua`, `corpus_cargo_wheel.lua` y `corpus_cargo_movecompat.lua` anotan lo ya verificado).

## Verificación

No hay test runner de GMod — el patrón es cargar mapa y confirmar (flujo §1 PASO 4), **la corre el autor**. Este repo suma dos capas previas:

1. **`cargo_selftest`** (consola, en el realm que lo invoca): auto-test determinista de la superficie pura (contrato, filtros, curva, claves JSON, providers). En listen server, realm server: `lua_run Corpus.GetModule("cargo")._SelfTest()`.
2. **Harness offline** (LuaJIT vía `pip install lupa` + stubs de GMod, carga el framework real de `corpus/`): mismo patrón que verificó Corpus, Craving y Coagulant. El script es **permanente**, vive fuera de los repos en [`../dev/harness_cargo.py`](../dev/harness_cargo.py) y se corre con `python dev/harness_cargo.py` desde la raíz del workspace — **no se reconstruye por sesión**: es el referente citable de la evidencia `tipo: harness` (FLU-31) que respalda las normas CRG en `ids.yaml`. Tirarlo y regenerarlo **borra esa evidencia**. Al cierre: **373 checks verdes en ambos realms**.

Flujo en juego: spawn **desarmado** (la captura convierte physgun/toolgun/loadouts en ítems — equipar desde el inventario) → `cargo_dev_give` → tecla I → equipar, ver peso afectar velocidad, F1 usa el quick slot → spawnear `Cargo Crate` (Entities → Corpus) → E → transferir. Con ARC9 montado: `arc9_free_atts` queda en 0 (takeover), los attachments viven en Cargo, y la ruta de adquisición dev es `cargo_dev_atts [n] [filtro]` (las entidades de mundo `arc9_att_*` requieren `arc9_atts_generate_entities 1`, default 0 de ARC9).

Al cerrar un cambio con superficie de runtime: refresca [`docs/cargo_estado.md`](docs/cargo_estado.md) en sitio y actualiza [`docs/CHANGELOG.md`](docs/CHANGELOG.md) (`[PENDIENTE]` → `[APLICADO YYYY-MM-DD]`, sin borrar ni renumerar).

## Git / commits

Sigue [`docs/cargo_convenciones_commits.txt`](docs/cargo_convenciones_commits.txt): `<tipo>(<alcance>): <descripción>` — tipo en inglés, descripción en español, minúscula inicial, sin punto final, imperativo. **Tipos** (§2): `feat`, `fix`, `refactor`, `docs`, `chore`, `test`. **Alcances** de este repo (§3, el doc manda): `items`, `inventory`, `weight`, `money`, `containers`, `arc9`, `ammo`, `capture`, `trade`, `ui`, `icons`, `dev`, `init`, `docs` (+ `workbench`, reservado hasta que abra su bloque).

**Este repo está publicado en GitHub** (`github.com/Sepuldosky/corpus-cargo`, público, remote `origin` cableado y **al día con `origin/main`**). No hagas commit ni push salvo que se pida explícitamente.

**No agregues el trailer `Co-Authored-By: Claude` (ni ninguna atribución de co-autoría a Claude/Anthropic) en los mensajes de commit.** Esto sobreescribe el comportamiento por defecto del harness.
