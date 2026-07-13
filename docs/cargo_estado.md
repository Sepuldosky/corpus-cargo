# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-13 (reporte de la ronda 1 de flecos:
**entry 4 → `[APLICADO]`**; 15 confirmado a-c (queda solo la degradación
sin addon, 15d); 17 confirmado a/c/d (el 17b estaba mal redactado: DGL4
también veta el historial stock — re-check con su resourcehistory apagado).
Frentes nuevos anotados: **#36** slot HL2 alineado, **#37** drop VJ que
vuelve solo, **#38** trivia real. Artefacto actualizado a ronda 2.)

---

## Qué existe hoy

- **Todo el arco de entries 1-14 y 16 `[APLICADO]` y confirmado en juego.**
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
- **Harness offline: 235 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN); `cargo_selftest` 52 client / 45 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar (ronda 2, artefacto)

- **Entry 15 — solo el (d):** desmontar `corpus_stalker` → los dev items
  degradan a modelo anterior/letra sin errores (a-c ya confirmados; el
  autor lo dejó pendiente por tiempo).
- **Entry 17 — solo el (b), corregido:** con el elemento `resourcehistory`
  de DGL4 APAGADO (o DGL4 desmontado), `cargo_hide_pickup_history 0`
  revive el historial stock (a/c/d ya confirmados; el ✗ de la ronda 1 era
  el veto propio de DGL4, no bug de Cargo).

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
- **Categorías fijas de tabs** → **roadmap #23** (bloque propio, sin diseñar).

## Remanentes / deuda conocida

- **Diseñado sin implementar:** comercio (`Cargo_Trade`) — siguiente bloque.
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

1. **Ronda 2 del artefacto** (dos checks): 15d (degradación sin addon) y
   17b corregido (resourcehistory de DGL4 apagado). Con ese reporte flipean
   15 y 17 y se borra la semilla `dev/HANDOFF_cargo_flecos_15_22_4.md`.
2. Remitir el fix de brazos oscuros a Twilight (acción del autor).
3. Después: **categorías fijas de tabs** (#23, exige sesión de diseño del set
   fijo) y **comercio** (`Cargo_Trade_Arquitectura.md`). El **#35**
   (footsteps) se investiga con el mod vivo cuando el autor lo priorice.

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
