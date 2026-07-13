# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-13 (**Bloque del wheel IMPLEMENTADO, sin
verificar** — entry 13 `[PENDIENTE]`, 4 commits en modo auto desde el diseño
ratificado en Desktop: primitiva de círculo del theme (#21 fix), slot
`throwable` de stack con `×N` real en el espejo §16, columna con fila baja
apilada Clear Sky + hide/align de tools + status panel al fondo, y el **wheel
menu (#31)** como front-end radial de las teclas 1-7 con cero server nuevo.
Harness verde en ambos realms (+35 checks); checklist en juego abajo. El
Bloque D del handoff (#30 #28 #24 #29) sigue SIN implementar.)

---

## Qué existe hoy

- **Block 1 (inventario) verificado en juego** (pasadas #1-#3) + batch #4 (feed
  de pickup). 23+ archivos Lua; mapa → [`../CLAUDE.md`](../CLAUDE.md).
- **Sistema de imágenes de ítems (#5) — entry 5 `[APLICADO 2026-07-11]`**:
  render a RT + caché en disco + footprint + editor, Plan A (alpha real).
  **Armas ARC9 (MirrorVMWM): el ícono viene del select icon del PROPIO ARC9**
  (`arc9_presets/<base>_icon.arc9.png`), re-cropeado en 2D al footprint; se
  regenera abriendo el menú de customize ≥1 s (watcher,
  `cargo_icon_arc9_menu_capture`). Resolución de render **256 px/celda**
  (subida de 128 en entry 8, confirmada); la captura ARC9 "funciona
  correctamente" pero su fuente 256² upscalea (deuda aceptada, abajo).
- **Persistencia de armas equipadas — entry 6 `[APLICADO 2026-07-11]`**: defs
  autogen persistidas, `Decide` conserva equipadas, reconcile diferido, heal
  de blobs huérfanos. Sobrevive reinicio/reconexión completa, confirmado.
- **Armas de mundo — entry 7 `[APLICADO 2026-07-11]`**: drops = SWEP real,
  sin auto-pickup, USE agarra/suelta (HL2), WALK+USE toma, take-back con la
  misma instancia. Confirmado completo.
- **UI fullscreen §15 — entry 8 `[APLICADO 2026-07-12]`**: 3 columnas / 3
  estados, gradas por footprint, cinturón, círculos = slots de herramienta,
  botón $. 3 pasadas + 2 rondas de ajustes, todo confirmado. Última tanda:
  header sin subtítulo, grid sin bloque oscuro (solo hover), loadout de
  sandbox no auto-stockeado (`cargo_capture_sandbox_tools` 0), render no-ARC9
  256 px/celda, toolgun `{3,2}`.
- **Todo (entries 1-8) commiteado y pusheado a `origin/main`** (2026-07-12):
  el remoto estaba 12 commits atrás y se puso al día; sin divergencia.
- **Holster + orden STALKER + manos default — entry 9 `[APLICADO 2026-07-12]`**:
  SWEP "Hands" (`corpus_cargo_hands`, Apex Hands reciclado), teclas 1-7 por
  `PlayerBindPress`→intent→server, re-apretar enfunda, spawn enfundado,
  crowbar capturado cae en `melee`. Convars `cargo_weapon_slots` /
  `cargo_holster_hands` (tab Q); comando `cargo_holster`. **Fix de brazos
  oscuros (2.º intento: `SuppressEngineLighting` + caja de luz propia
  muestreada en `EyePos` con piso, en `PreDrawViewModel`/`PreDrawPlayerHands`)
  confirmado in-game**, aplicó en vivo sin reiniciar. Queda remitir el fix a
  Twilight (acción del autor).
- **Bloque A — entry 10 `[APLICADO 2026-07-12]`**: drop nativo `cargo_drop` +
  **reconciliador universal de `PlayerDroppedWeapon`** (el arma botada deja de
  quedar fantasma en el equipo y vuelve como su misma instancia),
  `cargo_lose_on_death` + `cargo_persistence`, **persistencia del cargador** en
  el blob (#18), modelos dev de comida/medkit. Confirmado en juego en 3 pasadas.
- **Bloque B — munición, entry 11 `[APLICADO 2026-07-12]`** (§16 nueva): **el
  cinturón ES la reserva real**, no un almacén. Los 11 tipos de HL2 son ítems
  (modelo verificado contra los VPK, peso, `max_stack`); espejo a 4 Hz
  `GetAmmoCount(tipo) == suma del cinturón`, **agnóstico de base** (cero hooks de
  ARC9); armas del mismo tipo HL2 **comparten** reserva. **El éter murió**:
  `arc9_mult_defaultammo` forzado a 0 + `StripAmmo`+`Push` al spawn + gate del
  reconciliador. Munición del mapa → **grid**. Muerte vacía cinturón **y** pool.
  Convars: `cargo_ammo_pool`, `cargo_ammo_arc9_takeover`,
  `cargo_ammo_world_pickup`. **Confirmado en juego**; único bug de la pasada
  (modelos de AR2 cruzados) arreglado dentro del entry.

## Pendiente de verificar

- **Entry 13 (wheel + throwable + columna) — checklist consolidado en juego:**
  1. Wheel: hold de G abre (aviso en consola si G ya tenía bind), soltar
     commitea, deadzone/fuera cancela, sector vacío no hace nada.
  2. Re-seleccionar el arma en mano en su sector **enfunda** (== re-press).
  3. Hover sobre sector / chip quick / chip tool actualiza el **hub** (los 3).
  4. Cargador y reserva del hub coinciden con el HUD y el cinturón; fire mode
     solo en armas ARC9.
  5. Granada dev (`cargo_dev_give`): equipar el stack al slot Throwable
     (menú "Equip on..." o drag), aparece en el wheel, lanzar baja el `×N`;
     la última granada vacía el slot y quita el SWEP.
  6. Círculos **se ven circulares** (sandbox + botón `$` + hub del wheel).
  7. Anclajes quick/tools en las 4 posiciones; anclajes iguales → tools cae
     al lado libre con aviso en consola, sin romper.
  8. Cambiar la tecla del wheel desde el tab Q y que persista.
  9. Columna: fila baja apilada (Throwable sobre Melee), hide/show de tools,
     alineación left/center, status panel llega al fondo.
  10. **Regresión:** teclas 1-7, holster, cinturón, quick F1-F4, grid,
      contenedores, peso y persistencia (reconectar con la granada equipada).
- **CHANGELOG #4** (feed de pickup sin el mod L4D) sigue sin re-verificar — el
  frente suelto más viejo.

## Frentes abiertos (anotados, NO arreglados)

- **Hallazgos de la pasada del Bloque C** (2026-07-12) → roadmap **#28-#30**:
  **#28** no hay drop de armas EQUIPADAS desde su slot; **#29** el color de la
  UI debe ser neutro estilo spawnmenu e integrarse en runtime con el preset del
  HUD DGL4 (autor usa PCV de Opposing Force; mockup nuevo
  `docs/mockups/cargo_theme_dynamic_mock_v1_1.html`); **#30** el ícono de arma
  del spawnmenu no llega al inventario (sin toolgun no se pueden obtener
  physgun/toolgun/camera). El **#31 (wheel)** salió de esta lista: está
  implementado, pendiente de verificación (entry 13).
- **Retícula del grid**: se pierde con el inventario vacío y se corta en el último
  ítem cuando hay pocos → **roadmap #24** (causa probable ya diagnosticada: la
  dibuja el propio `DIconLayout`, cuyo alto es el del contenido).
- **Categorías fijas de tabs** → **roadmap #23** (bloque propio, sin diseñar).

## Remanentes / deuda conocida

- **Diseñado sin implementar:** comercio (`Cargo_Trade`) — siguiente bloque
  cuando #8 cierre.
- **Munición, lo que el Bloque B dejó abierto a propósito:** (a) **cargadores
  rellenables con toggle** (lo único que queda de #19); (b) **binding de
  ammo-atts de EFT** (§16.6): los tipos de bala de EFT son attachments que **no**
  cambian el tipo HL2, solo la balística — la palanca es que el stack activo del
  cinturón decida qué ammo-att va montado, dando munición realmente distinta
  sobre el mismo pool (`def.ammo.att` ya reservado en el schema); (c) **hueco del
  éter declarado**: `SWEP.ForceDefaultAmmo` saltea la convar que forzamos —
  ningún arma instalada lo usa, escalación anotada (ledger de conservación);
  (d) las entidades `arc9_ammo` reparten por su propio `Touch` y el espejo las
  absorbe al cinturón en vez del grid.
- **El editor de íconos NO afecta la cámara de armas ARC9** (la foto de ARC9 es
  el encuadre; el override de tamaño sí aplica). **Fuente de íconos ARC9
  256² — deuda aceptada** (2.ª pasada 2026-07-12): ARC9 hornea su select icon
  a 256² en pantallas ≤1100px y 512² arriba, en un RT de file-scope que Cargo
  no puede redimensionar sin forkear ARC9 (COMPAT-RUNTIME). A ≥1440p sale 512
  gratis; forzarlo en 1080p exigiría una captura ensamblada propia (camino ya
  cerrado, no se reabre). Los íconos de render **no-ARC9** sí subieron a 256
  px/celda (entry 8, 2.ª pasada). Captura de armas de mundo aún no bajada al
  spec (`Cargo_ItemImages_Arquitectura.md`; solo CHANGELOG entry 7).
- **Manejo de armas #16-22 diseño parcial** (#17 parcial; #22 parcial: falta
  matar notificaciones de GMod + verificar 7.º slot vs HUD D/GL4); **remitir
  el fix de brazos oscuros a Twilight** (ya confirmado, acción del autor);
  `Corpus.Data` sin `Delete`; peso nominal attachments; instancias huérfanas
  sin GC; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Pasada en juego del autor sobre el entry 13** (checklist arriba) →
   `[PENDIENTE]` → `[APLICADO]` + bajar el diseño a la arquitectura (§4
   enmienda, §15.2 enmienda, §17 nueva del wheel — lo manda el §8 del prompt
   semilla `../../dev/PROMPT_CC_Cargo_wheel_y_equipcolumn.md`).
2. **Bloque D — pendientes de UX (#30 · #28 · #24 · #29)**, en ese orden, con
   la semilla `../../dev/HANDOFF_cargo_bloque_d_ux_pendientes.md` (causas ya
   diagnosticadas con `archivo:línea`; reglas de modo auto). El **#29** ya
   tiene mockup nuevo: `docs/mockups/cargo_theme_dynamic_mock_v1_1.html`
   (teñido DGL4 en runtime) — el wheel y los círculos ya nacen tiñibles.
3. **Remitir el fix de brazos oscuros a Twilight** (acción del autor); resto
   del #22 (notificaciones de GMod + 7.º slot vs HUD DGL4).
4. Después: **categorías fijas de tabs** (#23, bloque propio) y **comercio**
   (`Cargo_Trade_Arquitectura.md`). Deuda no bloqueante: bajar la captura de
   armas de mundo al spec de `Cargo_ItemImages_Arquitectura.md`.

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
