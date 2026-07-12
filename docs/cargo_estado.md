# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-12 (**UI fullscreen §15 + ajustes de la
1.ª pasada** — entry 8 `[PENDIENTE]`. 1.ª pasada confirmó cinturón, botón $,
peso y traspasos; los ajustes aplicados: retícula alineada, footprints
calibrados con piso 3×2 de armas, círculos sandbox = slots dedicados reales,
tabs con wrap, transferencia por cantidad. Harness verde; **falta 2.ª
pasada en juego**)

---

## Qué existe hoy

- **Block 1 (inventario) verificado en juego** (pasadas #1-#3) + batch #4 (feed
  de pickup). 23+ archivos Lua; mapa → [`../CLAUDE.md`](../CLAUDE.md).
- **Sistema de imágenes de ítems (#5) — entry 5 `[APLICADO 2026-07-11]`**:
  render a RT + caché en disco + footprint + editor, Plan A (alpha real).
  **Armas ARC9 (MirrorVMWM): el ícono viene del select icon del PROPIO ARC9**
  (`arc9_presets/<base>_icon.arc9.png`), re-cropeado en 2D al footprint; se
  regenera abriendo el menú de customize ≥1 s (watcher,
  `cargo_icon_arc9_menu_capture`). Resolución 128 px/celda — confirmado
  "funciona correctamente" (deuda: la fuente ARC9 256² upscalea).
- **Persistencia de armas equipadas — entry 6 `[APLICADO 2026-07-11]`**: defs
  autogen persistidas, `Decide` conserva equipadas, reconcile diferido, heal
  de blobs huérfanos. Sobrevive reinicio/reconexión completa, confirmado.
- **Armas de mundo — entry 7 `[APLICADO 2026-07-11]`**: drops = SWEP real,
  sin auto-pickup, USE agarra/suelta (HL2), WALK+USE toma, take-back con la
  misma instancia. Confirmado completo.
- Todo commiteado local (`b6d31f8`…hasta el cierre de estos tres entries),
  **sin push**.

## Pendiente de verificar

- **CHANGELOG #8 (UI fullscreen §15)**: 1.ª pasada hecha (belt, botón $,
  peso y traspasos OK) y su feedback ya aplicado + verificado offline
  (selftest 29/36). Falta la **2.ª pasada**: alineación de retícula,
  tamaños de gradas (rifles/pistolas/armor/casco/cámara), círculos sandbox
  como slots (colocar/seleccionar, tooltip al hover), tabs sin recorte,
  transferencia por cantidad.
- **CHANGELOG #4** (feed de pickup sin el mod L4D) sigue sin re-verificar —
  el único frente suelto de rondas anteriores.

## Remanentes / deuda conocida

- **Diseñado sin implementar:** comercio (`Cargo_Trade`) — siguiente bloque
  cuando #8 cierre. La **semántica** del cinturón (alimentación, cargadores,
  munición ARC9/EFT vs HL2) es roadmap #19, dueño a decidir con Caliber.
- **El editor de íconos NO afecta la cámara de armas ARC9** (la foto de ARC9 es
  el encuadre; el override de tamaño sí aplica). Fuente de íconos ARC9
  256² → deuda de nitidez si algún día molesta (nota en CHANGELOG entry 5).
  Captura de armas de mundo aún no bajada al spec
  (`Cargo_ItemImages_Arquitectura.md`; solo CHANGELOG entry 7).
- **Manejo de armas #16-22 diseño parcial** (#17 parcial implementado); manos
  default (#4, Apex Hands aprobado); `Corpus.Data` sin `Delete`; peso nominal
  attachments; instancias huérfanas sin GC; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Pasada en juego del entry 8** (UI fullscreen) → si pasa, cerrar
   `[PENDIENTE]` → `[APLICADO]` y commitear los parches del bloque.
2. **Borrar el handoff** `dev/HANDOFF_cargo_iconos_persistencia.md` (los tres
   entries que cubría ya cerraron) y bajar captura de armas de mundo al spec
   de `Cargo_ItemImages_Arquitectura.md` cuando haya tiempo (no bloqueante).
3. Después: comercio (`Cargo_Trade_Arquitectura.md`).

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
