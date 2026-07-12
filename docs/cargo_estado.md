# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-12 (**holster + orden de armas + manos
default implementados** — entry 9 `[PENDIENTE]`, roadmap #22 parcial + #4:
teclas 1-7 → slots (1 melee … 7 camera), re-apretar enfunda, SWEP
`corpus_cargo_hands` "Hands" reciclado de Apex Hands con créditos, elección
Hands/nada en el tab Q. Mecanismo confirmado en juego; fix de brazos oscuros
en **2.º intento** (control manual del lighting del viewmodel) pendiente de
verificar. Commiteado, sin push)

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
- **Holster + orden STALKER + manos default — entry 9 `[PENDIENTE]`**
  (2026-07-12): SWEP "Hands" (`corpus_cargo_hands`, Apex Hands reciclado +
  fix de lighting), teclas 1-7 por `PlayerBindPress`→intent→server,
  re-apretar enfunda, spawn enfundado, crowbar capturado cae en `melee`.
  Convars `cargo_weapon_slots` / `cargo_holster_hands` (tab Q); comando
  `cargo_holster`. Sin commit todavía.

## Pendiente de verificar

- **CHANGELOG #9** (holster/hotkeys/manos): el mecanismo funciona (1.ª
  pasada 2026-07-12); el 1.er intento del fix de brazos oscuros falló, ya
  está el **2.º intento** (control manual del lighting del viewmodel en
  `PreDrawViewModel` + muestreo en `EyePos` con piso) pendiente de verificar.
  Resto del checklist sin verificar aún.
- **CHANGELOG #4** (feed de pickup sin el mod L4D) sigue sin re-verificar —
  el único frente suelto de rondas anteriores.

## Remanentes / deuda conocida

- **Diseñado sin implementar:** comercio (`Cargo_Trade`) — siguiente bloque
  cuando #8 cierre. La **semántica** del cinturón (alimentación, cargadores,
  munición ARC9/EFT vs HL2) es roadmap #19, dueño a decidir con Caliber.
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
  matar notificaciones de GMod + verificar 7.º slot vs HUD D/GL4); fix de
  brazos oscuros pendiente de confirmar y **remitir a Twilight**;
  `Corpus.Data` sin `Delete`; peso nominal attachments; instancias huérfanas
  sin GC; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Verificar en juego el entry 9** (checklist en el CHANGELOG) y commitear
   cuando el autor lo pida.
2. **Borrar el handoff** `dev/HANDOFF_cargo_iconos_persistencia.md` (los tres
   entries que cubría ya cerraron) y bajar captura de armas de mundo al spec
   de `Cargo_ItemImages_Arquitectura.md` cuando haya tiempo (no bloqueante).
3. Después: comercio (`Cargo_Trade_Arquitectura.md`).

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
