# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-11 (tres pasadas en juego — CHANGELOG #1-#3 `[APLICADO]`; batch #4 (feed de pickup + baja de L4D) en el árbol, **pendiente de re-verificar**; **primer commit del repo hecho**)

---

## Qué existe hoy

- **Block 1 (inventario) verificado en juego en tres pasadas** (#1 el slice
  completo, #2 fixes de UI/inglés/slots/ARC9, #3 bind fiable + captura post-equip
  + drops con modelo real). 23 archivos Lua; mapa → [`../CLAUDE.md`](../CLAUDE.md).
- **Módulo publicado en GitHub (2026-07-11):** el módulo entero (código + docs,
  incluidos el batch #4 y estos docs) commiteado y pusheado a `main`.
- **Batch #4 (incluido en ese commit, pendiente de re-verificar en juego):**
  **feed de pickup** en pantalla (`corpus_cargo_pickup.lua` — señala el ítem
  recogido, convar `cargo_pickup_feed`) y **baja del mod "L4D Item Pickup System"**
  de `dev/other/` (causaba el bug de ítems del toolgun inagarrables; la lección de
  compat post-equip se conserva en el header de `corpus_cargo_capture.lua`).
- **Verificación offline** (patrón en memoria de proyecto): sintaxis 23/23 +
  harness LuaJIT con framework real de `corpus/` — selftest 26/19 + integración
  41/9 (server/client) en verde.

## Pendiente de verificar

- **CHANGELOG #4 en juego (SIN el mod L4D):** spawn desarmado con el feed
  listando el loadout; recoger un arma de mundo por contacto (toolgun/spawnmenu)
  ahora que nada bloquea `AllowPlayerPickup`; drop recogido con E muestra su
  línea; `cargo_pickup_feed 0` lo apaga.

## Remanentes / deuda conocida

- **Pendientes de diseño (sesión Opus + Claude Design):** UI fullscreen estilo
  STALKER (funcionalidad y disposición quedan; cambia la forma — incluye la
  pantalla de traslado/trueque) y **sistema de imágenes de ítems** (generación
  estilo mod de inventario RE). Roadmap #3 y #5.
- **Manos default:** reciclaje de Apex Hands **aprobado por el autor** (créditos
  + takedown-on-request; arreglar bug de brazos oscuros — repro: se oscurece
  mirando al horizonte — y remitir fix a Twilight). Roadmap #4 y mapa de mods.
- **`Corpus.Data` sin `Delete`** (candidata a primitiva); **captura dedup-por-clase**
  (segunda arma de mundo de la misma clase se absorbe); **peso nominal** de
  attachments ARC9 (0.3 kg); instancias huérfanas sin GC; comandos dev sin gate
  de admin (TODO esperando primitiva); sin `addon.json`.

## Próximo paso

1. **Re-verificación en juego del CHANGELOG #4** (feed de pickup + baja del mod L4D,
   ver "Pendiente de verificar") → `[APLICADO]` y refrescar acá.
2. Después: [`cargo_roadmap.txt`](cargo_roadmap.txt) — sesión de diseño de UI
   fullscreen, manos default (Apex Hands), sistema de imágenes, Workbench.

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño → [`Cargo_Architecture.md`](Cargo_Architecture.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
