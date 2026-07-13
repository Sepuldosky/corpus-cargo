# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-13 (tanda de CIERRE ejecutada: entries
**13/14/16 → `[APLICADO]`**, diseño bajado a la arquitectura (§4 throwable +
taxonomía, §5 movecompat, §15.2 columna apilada, §15.5 paletas/DGL4, §16.9
espejo, **§17 wheel** nueva), CLAUDE.md refrescado (mapa completo + trampas
de HUD) y las cuatro semillas de `dev/` borradas.)

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
- **Harness offline: 229 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN); `cargo_selftest` 52 client / 45 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Entry 15 (assets ZONA + pesos GAMMA) — checklist del autor en juego:**
  (a) playermodels "ZONA *" en el menú C con brazos propios;
  (b) `cargo_dev_give` con íconos STALKER (addon opcional `corpus_stalker` —
  renombrado 2026-07-13, antes `corpus_zona_assets` —, junction desde `dev/`);
  (c) arma EFT con peso real de la GAMMA DB (ej. AK-74M 3.4 kg) y el footer
  lo refleja; (d) sin el addon, los dev items degradan a su modelo
  anterior/letra sin errores. Soporte listo: el volcado de
  `cargo_dev_dump_weapons` ya se generó.
- **CHANGELOG #4** (feed de pickup sin el mod L4D) sigue sin re-verificar —
  el frente suelto más viejo.

## Frentes abiertos (anotados, NO arreglados)

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
- **Resto del #22:** matar notificaciones de GMod + verificar 7.º slot vs
  HUD DGL4. **Remitir el fix de brazos oscuros a Twilight** (ya confirmado,
  acción del autor).
- `Corpus.Data` sin `Delete`; peso nominal de attachments; instancias
  huérfanas sin GC; comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Tanda de flecos** (chat nuevo, semilla
   `../../dev/HANDOFF_cargo_flecos_15_22_4.md`): flip del **entry 15**
   (checklist del autor), resto del **#22** (matar notificaciones de GMod +
   verificar 7.º slot vs HUD DGL4) y re-verificación del **#4** (feed de
   pickup, el frente suelto más viejo). Los checklists in-game van con el
   **workflow nuevo de verificación** (artefacto browser con tick/cross +
   notas por ítem — en formalización en un chat paralelo; buscarlo antes
   del PASO 4).
2. Remitir el fix de brazos oscuros a Twilight (acción del autor).
3. Después: **categorías fijas de tabs** (#23, exige sesión de diseño del set
   fijo) y **comercio** (`Cargo_Trade_Arquitectura.md`). El **#35**
   (footsteps) se investiga con el mod vivo cuando el autor lo priorice.

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
