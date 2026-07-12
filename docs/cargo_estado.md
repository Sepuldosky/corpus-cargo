# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-11 (íconos ARC9 CONFIRMADOS por el autor:
fuente = PNG del propio ARC9 + recaptura desde su menú; entry 5 `[APLICADO]`.
Quedan pendientes de verificar entries 6/7 — reinicio completo)

---

## Qué existe hoy

- **Block 1 (inventario) verificado en juego** (pasadas #1-#3) + batch #4 (feed
  de pickup). 23+ archivos Lua; mapa → [`../CLAUDE.md`](../CLAUDE.md).
- **Sistema de imágenes de ítems (#5) — entry 5 `[APLICADO 2026-07-11]`**
  (9 pasadas in-game): render a RT + caché en disco + footprint + editor,
  Plan A (alpha real). **Armas ARC9 (MirrorVMWM): el ícono viene del select
  icon del PROPIO ARC9** (`arc9_presets/<base>_icon.arc9.png`), re-cropeado
  en 2D al footprint; se regenera abriendo el menú de customize ≥1 s
  (watcher, `cargo_icon_arc9_menu_capture`). Resolución 128 px/celda —
  confirmado "funciona correctamente" (deuda: la fuente ARC9 256² upscalea).
- **Persistencia de armas equipadas** (entry 6, `[PENDIENTE]`): defs autogen
  persistidas, `Decide` conserva equipadas, reconcile diferido, heal de blobs
  huérfanos. Confirmado parcial (toolgun sobrevive respawn).
- **Armas de mundo** (entry 7, `[PENDIENTE]`): drops = SWEP real, sin
  auto-pickup, USE agarra (HL2), WALK+USE toma. "Funciona todo bien" (5.ª/6.ª).
- Todo commiteado local (`b6d31f8`/`3e43d4f`/`ed346d2` + lo de esta sesión),
  **sin push**.

## Pendiente de verificar (próxima pasada in-game)

- **Entry 6 (persistencia), único cierre abierto:** 9A-91 equipado sobrevive
  recargar mapa **+ reinicio/reconexión completa**; sin duplicados en el grid.
  Confirmado parcial (toolgun). Al pasar → `[APLICADO]`.
- **Entry 7 (armas de mundo):** "funciona todo bien" (5.ª/6.ª pasada); falta
  el ok formal para cerrar → `[APLICADO]`.
- **CHANGELOG #4** (feed sin mod L4D) sigue sin re-verificar.

## Remanentes / deuda conocida

- **Diseñado sin implementar:** UI fullscreen (§15), comercio (`Cargo_Trade`).
  Orden: cerrar #5 → VGUI fullscreen → comercio.
- **El editor de íconos NO afecta la cámara de armas ARC9** (la foto de ARC9 es
  el encuadre; el override de tamaño sí aplica). Captura ensamblada + armas de
  mundo aún no bajadas al spec (`Cargo_ItemImages_Arquitectura.md` §; solo CHANGELOG).
- **Manejo de armas #16-22 diseño parcial** (#17 parcial implementado); manos
  default (#4, Apex Hands aprobado); `Corpus.Data` sin `Delete`; peso nominal
  attachments; instancias huérfanas sin GC; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Cerrar entries 6/7** (verificación de reinicio completo) → a `[APLICADO]`,
   bajar captura de armas de mundo al spec, borrar el handoff de `dev/`.
2. Después: VGUI fullscreen (§15) que consume las imágenes, y comercio.

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
