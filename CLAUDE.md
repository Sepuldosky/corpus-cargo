# CLAUDE.md

Guía para trabajar en **Cargo** — el módulo de inventario del ecosistema Corpus (addon GLua para Garry's Mod). Léela antes de tocar código o docs de este repo.

## Qué es

Cargo es el módulo de **inventario** del ecosistema Corpus: contrato de ítems (dos clases), grid uniforme estilo STALKER/GAMMA, slots de equipamiento con sub-slots genéricos, peso→movimiento, providers de dinero/facción, contenedores en mundo y puente de attachments ARC9. Es un addon Gmod independiente con su propio git, que **hard-depende** de Corpus (la única dependencia dura del ecosistema) y de nadie más. Es hoja en el grafo de deps pero **hub de consumo**: Coagulant, Craving y Caliber registran sus ítems contra el framework que Cargo expone.

**Regla cardinal:** Cargo posee el "cómo se define, pesa, guarda y renderiza" un ítem; el módulo dueño posee el "qué hace" (`onUse`, semántica de condición, contenido del blob). Cargo transporta blobs sin interpretarlos. Ver §3 de [`docs/Cargo_Architecture.md`](docs/Cargo_Architecture.md).

**Regla cardinal:** nada de lógica de dominio sube a Corpus, y la lógica de dominio ajena no baja a Cargo (la medicina es de Coagulant, la mitigación de armadura es de Caliber Block 3 — acá solo existe el punto de enganche).

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

Tres capas, no las mezcles:

- **Código (comentarios e identificadores): inglés** (estilo fijado al estrenar este repo — difiere de corpus/caliber, iguala el del archivo que edites).
- **Strings de cara al jugador (UI, nombres de ítems, notices, menús, helps de convar): inglés** — es el idioma del mod (decisión del autor, primera pasada en juego 2026-07-10). Nada en español debe llegar a pantalla.
- **Docs, mensajes de commit y logs de consola (`Corpus.Log`): español** (precedente del ecosistema); los `<tipo>` de commit en inglés (ver convenciones).

## El workspace multi-repo

Este repo (`corpus-cargo/`) es una de seis raíces del workspace `corpus.code-workspace`. La raíz `corpus/` es el framework del que todos hard-dependen; las otras cuatro (`corpus-cortex/`, `corpus-caliber/`, `corpus-coagulant/`, `corpus-craving/`) son módulos hermanos que se detectan en runtime vía `Corpus.GetModule`, nunca se asumen. La investigación de mods de terceros (ARC9 etc.) vive fuera de git en `dev/other/` — consulta `../dev/mods_workshop_mapa.md` antes de diseñar cualquier integración con mods ajenos.

## Mapa de archivos

Un **manifest de carga explícito** (`corpus_cargo_init.lua`, único archivo en `lua/autorun/`) registra el módulo, declara el contrato público y hace `include()` en orden determinista — patrón template tomado de Caliber (boot diferido a `Initialize`, sonda `CorpusReady`, falla ruidoso sin framework). Los sub-archivos viven en `lua/corpus_cargo/<realm>/`, **fuera** de `lua/autorun/`. Las entidades van en `lua/entities/` (las carga el sistema de scripted_ents, no el manifest) y resuelven el módulo en runtime, nunca en file-scope.

| Archivo | Realm | Rol |
|---|---|---|
| [`lua/autorun/corpus_cargo_init.lua`](lua/autorun/corpus_cargo_init.lua) | shared | Entry + registro (`cargo`) + **bloque CONTRACT** + manifest |
| [`lua/corpus_cargo/shared/corpus_cargo_util.lua`](lua/corpus_cargo/shared/corpus_cargo_util.lua) | shared | Blobs de net (JSON comprimido) + re-normalización de claves numéricas |
| [`lua/corpus_cargo/shared/corpus_cargo_items.lua`](lua/corpus_cargo/shared/corpus_cargo_items.lua) | shared | **Contrato de ítems** (§3): `Items.Register`, categorías, filtro único, **sub-slots** (`DeclareSubSlot`, §4) |
| [`lua/corpus_cargo/shared/corpus_cargo_slots.lua`](lua/corpus_cargo/shared/corpus_cargo_slots.lua) | shared | Slots de equipamiento (data, incl. Accessory 1/2 genéricos y los 3 de herramienta sandbox con clase exacta) + quick F1–F4 (disponibilidad por traje) + cinturón (`BELT_COUNT`) |
| [`lua/corpus_cargo/shared/corpus_cargo_weight.lua`](lua/corpus_cargo/shared/corpus_cargo_weight.lua) | shared | Curva pura peso→velocidad (§5) + capacidad base+mochila |
| [`lua/corpus_cargo/shared/corpus_cargo_arc9.lua`](lua/corpus_cargo/shared/corpus_cargo_arc9.lua) | shared | **Puente ARC9** (§10): hooks de inventario verificados + helpers de attach/detach/stats |
| [`lua/corpus_cargo/shared/corpus_cargo_dev.lua`](lua/corpus_cargo/shared/corpus_cargo_dev.lua) | shared | `cargo_selftest` + kit de ítems demo (`cargo_dev_give`) + barras demo |
| [`lua/corpus_cargo/server/corpus_cargo_instances.lua`](lua/corpus_cargo/server/corpus_cargo_instances.lua) | server | Blobs de instancia únicos, uid, un archivo por instancia (§12) |
| [`lua/corpus_cargo/server/corpus_cargo_money.lua`](lua/corpus_cargo/server/corpus_cargo_money.lua) | server | Interfaz de dinero + provider nativo USD (§6) |
| [`lua/corpus_cargo/server/corpus_cargo_inventory.lua`](lua/corpus_cargo/server/corpus_cargo_inventory.lua) | server | Inventario por SteamID64: stacks, equip, quick, cinturón (§15.2, solo forma), eyección obligatoria, net |
| [`lua/corpus_cargo/server/corpus_cargo_movement.lua`](lua/corpus_cargo/server/corpus_cargo_movement.lua) | server | Aplica la curva a walk/run + lazy-check Coagulant |
| [`lua/corpus_cargo/server/corpus_cargo_containers.lua`](lua/corpus_cargo/server/corpus_cargo_containers.lua) | server | Contenedores en mundo, transferencias, Take/Move all (§8) |
| [`lua/corpus_cargo/server/corpus_cargo_capture.lua`](lua/corpus_cargo/server/corpus_cargo_capture.lua) | server | Captura de armas del engine → ítems (spawn desarmado). **Post-equip vía `WeaponEquip`, nunca vetando `PlayerCanPickupWeapon`** — compat con mods de pickup (lección L4D IPS, ver header del archivo). Defs `autogen` + `Capture.Ignore` para SWEPs de manos |
| [`lua/corpus_cargo/client/corpus_cargo_theme.lua`](lua/corpus_cargo/client/corpus_cargo_theme.lua) | client | Paleta/fuentes/helpers de pintado (única fuente de estilo) |
| [`lua/corpus_cargo/client/corpus_cargo_statuspanel.lua`](lua/corpus_cargo/client/corpus_cargo_statuspanel.lua) | client | `StatusPanel.RegisterBar` + render (§11) |
| [`lua/corpus_cargo/client/corpus_cargo_pickup.lua`](lua/corpus_cargo/client/corpus_cargo_pickup.lua) | client | Feed de pickup en pantalla (`cargo_pickup_feed`) — señala el ítem recogido |
| [`lua/corpus_cargo/client/corpus_cargo_tooltip.lua`](lua/corpus_cargo/client/corpus_cargo_tooltip.lua) | client | Tooltip de inspección (§9): stats ARC9/manual, zonas, sub-slots |
| [`lua/corpus_cargo/client/corpus_cargo_grid.lua`](lua/corpus_cargo/client/corpus_cargo_grid.lua) | client | Grid por **gradas** (footprint `w×h`, §7 enmendado) + overlays por esquina (PaintOver, no CSS) |
| [`lua/corpus_cargo/client/corpus_cargo_ui.lua`](lua/corpus_cargo/client/corpus_cargo_ui.lua) | client | Frame **fullscreen 3 columnas / 3 estados** (§15: Solo/Loot/Trade-reservado; equip STALKER, quick, cinturón, círculos sandbox, botón $, tabs, footer) + binds |
| [`lua/corpus_cargo/client/corpus_cargo_transfer.lua`](lua/corpus_cargo/client/corpus_cargo_transfer.lua) | client | Estado/wire de contenedores (§8): net + intents; el frame Loot vive en `corpus_cargo_ui.lua` |
| [`lua/corpus_cargo/client/corpus_cargo_options.lua`](lua/corpus_cargo/client/corpus_cargo_options.lua) | client | Tab único `Corpus.UI.RegisterTab("cargo", …)` |
| [`lua/entities/corpus_cargo_crate.lua`](lua/entities/corpus_cargo_crate.lua) | shared | Caja de prueba spawnable (E → panel de transferencia) |
| [`lua/entities/corpus_cargo_item.lua`](lua/entities/corpus_cargo_item.lua) | shared | Ítem dropeado en mundo (E → recoger) |

## Contratos que no debes romper

1. **Namespace: tabla única registrada.** Cada archivo abre con `local CARGO = Corpus.GetModule("cargo")` (el init la registró antes). Ningún archivo declara globals sueltos. Depende del invariante by-ref del registro de Corpus.
2. **Cargo transporta, no interpreta.** El contenido del blob de instancia (condición, zonas, material de placa) lo define el módulo dueño; Cargo lo guarda y lo renderiza. `onUse` corre en el dueño; Cargo solo consume 1 unidad si devuelve `true`.
3. **Un solo primitivo de sub-slot.** Óptica-Head, exo/escudo-Body y placas-Body pasan TODOS por `Cargo.Items.DeclareSubSlot` + el filtro `"category:a,b"` de `MatchesFilter`. Nada de variantes ad-hoc.
4. **Eyección obligatoria (§4).** Todo flujo que destruye un ítem con sub-slots ocupados eyecta primero (`EjectSubSlots`, con `skipCap`) — una placa o un generador jamás se pierden como efecto colateral.
5. **Sin lavado de desgaste.** Los stacks solo se fusionan con condición idéntica; una placa gastada que vuelve de un sub-slot es un stack aparte.
6. **Persistencia namespaced.** Todo vía `Corpus.Data` namespace `cargo`: `inv_<steamid64>`, `inst_<uid>`, `cont_<key>`. El round-trip JSON **no** preserva tipos de clave: re-normaliza claves numéricas al cargar (`Util.NumberKeys` — quick slots, tanto server como client).
7. **Net namespaced.** Todo mensaje vía `Corpus.Net.Register("cargo", msg)` → `corpus_cargo_<msg>`. Nunca `AddNetworkString` crudo. El server posee el inventario; el cliente solo envía intents y renderiza snapshots.
8. **ARC9: stats lectura-only, attach por SU API.** Los stats se leen con `GetProcessedValue` (claves reales: `DamageMax`/`Spread`/`RPM`, no "Damage"/"Accuracy"); instalar/quitar va por `SWEP:Attach`/`DetachAllFromSubSlot` (client-side, replica solo). La reconciliación con el menú C es por los hooks `ARC9_PlayerGetAtts/GiveAtt/TakeAtt` — no existe hook de attach puro. **Los nombres de ARC9 nunca se asumen de memoria: se verifican contra `dev/other/`** (este bloque ya lo pagó y los dejó anotados en el header de `corpus_cargo_arc9.lua`).
9. **Detección, nunca asunción.** Cortex (facción), Coagulant (stamina) y ARC9 se consultan con lazy-check + pcall; sin ellos el header omite facción, la penalización queda en velocidad y el puente se apaga — degradación honesta, jamás crash.
10. **Prefijo de archivo por módulo:** `corpus_cargo_*.lua` en todo lo que cargue el engine.

## Trampas de VGUI (heredadas del proyecto — no las redescubras)

- `DNumSlider` y `DPropertySheet:Dock(FILL)` colapsan dentro de `DScrollPanel` — filas manuales.
- **`DIconLayout:Dock(FILL)` dentro de `DScrollPanel` también colapsa** (canvas se dimensiona a los hijos, el hijo llena el canvas): celdas recortadas y `Refresh()` repoblando un layout de altura cero. Usa `Dock(TOP)` + `InvalidateLayout(true)` — pagado en la primera pasada en juego de este repo.
- Overlays de celda = `PaintOver`/paneles con `SetPos`, no flexbox.
- Texto en celdas/filas siempre con `Theme.FitText` (elipsis) — los nombres largos desbordan.
- Refresca en sitio leyendo `CARGO.ClientState` desde los `Paint` (así está hecho el frame); no reconstruyas el panel en callbacks de valor.

## Verificación

No hay test runner de GMod — el patrón es cargar mapa y confirmar (flujo §1 PASO 4), **la corre el autor**. Este repo suma dos capas previas:

1. **`cargo_selftest`** (consola, en el realm que lo invoca): auto-test determinista de la superficie pura (contrato, filtros, curva, claves JSON, providers). En listen server, realm server: `lua_run Corpus.GetModule("cargo")._SelfTest()`.
2. **Harness offline** (LuaJIT vía `pip install lupa` + stubs de GMod, carga el framework real de `corpus/`): mismo patrón que verificó Corpus Block 1. El script vive en el scratchpad de sesión, se reconstruye fácil.

Flujo en juego: spawn **desarmado** (la captura convierte physgun/toolgun/loadouts en ítems — equipar desde el inventario) → `cargo_dev_give` → tecla I → equipar, ver peso afectar velocidad, F1 usa el quick slot → spawnear `Cargo Crate` (Entities → Corpus) → E → transferir. Con ARC9 montado: `arc9_free_atts` queda en 0 (takeover), los attachments viven en Cargo, y la ruta de adquisición dev es `cargo_dev_atts [n] [filtro]` (las entidades de mundo `arc9_att_*` requieren `arc9_atts_generate_entities 1`, default 0 de ARC9).

Al cerrar un cambio con superficie de runtime: refresca [`docs/cargo_estado.md`](docs/cargo_estado.md) en sitio y actualiza [`docs/CHANGELOG.md`](docs/CHANGELOG.md) (`[PENDIENTE]` → `[APLICADO YYYY-MM-DD]`, sin borrar ni renumerar).

## Git / commits

Sigue [`docs/cargo_convenciones_commits.txt`](docs/cargo_convenciones_commits.txt): `<tipo>(<alcance>): <descripción>` — tipo en inglés, descripción en español, minúscula inicial, sin punto final, imperativo. Alcances de este repo: `items`, `inventory`, `weight`, `money`, `containers`, `arc9`, `ui`, `dev`, `init` (+ `docs`, `chore`).

**Este repo está publicado en GitHub** (`github.com/Sepuldosky/corpus-cargo`, público, remote `origin` cableado localmente, **sin commits todavía**). No hagas commit ni push salvo que se pida explícitamente.

**No agregues el trailer `Co-Authored-By: Claude` (ni ninguna atribución de co-autoría a Claude/Anthropic) en los mensajes de commit.** Esto sobreescribe el comportamiento por defecto del harness.
