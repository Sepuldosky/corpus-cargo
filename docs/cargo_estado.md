# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-11 (bloques de diseño **UI fullscreen + imágenes de ítems + comercio** cerrados y documentados; próximo paso = **implementar el sistema de imágenes** en Claude Code, y **commit después de eso**)

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
  de `dev/other/`.
- **Diseño nuevo cerrado (2026-07-11), solo docs — sin código todavía:** tres
  documentos producidos en la sesión de diseño (Opus + mockup HTML):
  **`Cargo_ItemImages_Arquitectura.md`** (imágenes de ítems, roadmap #5),
  **§15 de `Cargo_Architecture.md`** (UI fullscreen — forma; roadmap #3, incluye
  cinturón de munición-forma #19 y círculos sandbox #21) y
  **`Cargo_Trade_Arquitectura.md`** (comercio: inventario-en-entidad, basket con
  confirm, spread, jugador-trader, dinero-entidad + P2P, NPC trader de ejemplo).
  Mockup de referencia: `cargo_fullscreen_ui_mock_v1.html`.

## Pendiente de verificar

- **CHANGELOG #4 en juego (SIN el mod L4D):** spawn desarmado con el feed
  listando el loadout; recoger un arma de mundo por contacto (toolgun/spawnmenu);
  drop recogido con E muestra su línea; `cargo_pickup_feed 0` lo apaga. (Sigue
  pendiente — no confundir con los bloques de diseño recién cerrados.)

## Remanentes / deuda conocida

- **Diseñado pero SIN implementar:** UI fullscreen (#3), imágenes de ítems (#5),
  comercio. Orden de implementación: **#5 primero** (prerequisito de las gradas),
  luego VGUI fullscreen, luego comercio (comparten layout/grid).
- **Manejo de armas §16-22 — diseño parcial:** #21 (sandbox) y la FORMA del
  cinturón #19 quedaron dentro de §15; **#16, #17, #18, #20, #22 siguen sin diseñar**
  (frontera Cargo/Caliber se decide al diseñar el bloque).
- **Manos default (#4):** reciclaje de Apex Hands aprobado (créditos +
  takedown-on-request; arreglar bug de brazos oscuros — repro: se oscurece mirando
  al horizonte — y remitir fix a Twilight). Roadmap #4 y mapa de mods.
- **`Corpus.Data` sin `Delete`** (candidata a primitiva); **captura dedup-por-clase**;
  **peso nominal** de attachments ARC9 (0.3 kg); instancias huérfanas sin GC;
  comandos dev sin gate de admin (TODO esperando primitiva; alcanza a los nuevos
  `cargo_icon_edit`/`regen_all` y al spawn del NPC trader de ejemplo); sin `addon.json`.

## Próximo paso

1. **Implementar el sistema de imágenes de ítems** (roadmap #5,
   `Cargo_ItemImages_Arquitectura.md`) en Claude Code — render a RT + caché +
   encuadre/footprint + editor. **Gate de transparencia** (Plan A/B) al inicio.
2. Verificar en juego → **commit del repo** (decisión del autor: el commit va
   después de este paso). Cerrar de paso el CHANGELOG #4 pendiente.
3. Después: VGUI fullscreen (§15) que consume las imágenes, y comercio.

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
