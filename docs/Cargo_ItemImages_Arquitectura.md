# Cargo — Sistema de Imágenes de Ítems (Arquitectura)

> **Uso de este documento:** Referencia autocontenida para sesiones futuras de
> planificación (Claude Opus) e implementación (Claude Code). No se requiere el
> chat de diseño original.
>
> **Estado:** Bloque de diseño cerrado (sesión Opus, ratificado por el autor
> 2026-07-11). Subsistema propio desprendido de Cargo — mismo patrón que
> `Workbench_Arquitectura.md`. Roadmap Cargo #5.
>
> **Relación de dependencia:** Este subsistema es **prerequisito duro** del
> rediseño de UI fullscreen (§15 de `Cargo_Architecture.md`): el grid en
> "gradas" con footprint variable solo vale con imágenes reales; con el fallback
> de letra un footprint 6×2 es basura visual. Este bloque se implementa **antes o
> junto** con el bloque VGUI fullscreen.
>
> **Dependencia dura:** Corpus. **Sin dependencias soft** — es cosmético y
> client-side; no consume ni expone nada de otro módulo.

---

## Índice

1. [Visión general](#1-visión-general)
2. [Jerarquía de fuente del icono](#2-jerarquía-de-fuente-del-icono)
3. [Pipeline de generación](#3-pipeline-de-generación)
4. [Encuadre](#4-encuadre)
5. [Footprint (tamaño en celdas)](#5-footprint-tamaño-en-celdas)
6. [Resolución y formato](#6-resolución-y-formato)
7. [Caché e invalidación](#7-caché-e-invalidación)
8. [Editor dev](#8-editor-dev)
9. [Riesgo técnico: transparencia](#9-riesgo-técnico-transparencia)
10. [Consumidores y sincronización](#10-consumidores-y-sincronización)
11. [Fronteras y pendientes declarados](#11-fronteras-y-pendientes-declarados)
12. [Estado del documento](#12-estado-del-documento)

---

## 1. Visión general

Hoy las celdas del grid caen a la **inicial del nombre** cuando el def no trae
`icon`. Con la captura de armas del engine activa (CHANGELOG #2/#3) casi todas las
armas del jugador son defs autogeneradas sin icono a mano — el inventario se ve
como una grilla de letras. Este subsistema **genera la imagen del ítem a partir de
su modelo 3D**, la encuadra para que calce en la celda y la cachea a disco.

Referencia del autor: mod de inventario de Resident Evil que genera imágenes de
los ítems y permite ajustarlas para que calcen en la celda. El camino en GMod es
el mismo que usa el editor de iconos nativo del sandbox (Edit Icon sobre un
spawnicon): render del modelo a un RenderTarget, captura a PNG, `Material()` desde
`data/`.

Principio: **cosmético y client-side puro, cero costo de net**. El servidor nunca
genera ni transporta imágenes; cada cliente construye su propia caché local.

---

## 2. Jerarquía de fuente del icono

Al resolver la imagen de un def, en orden estricto (gana el primero que exista):

1. **`def.icon` explícito** — material hecho a mano (VTF/VMT o PNG en `materials/`).
   Para ítems con arte propio; gana siempre.
2. **Render generado desde el modelo** — este subsistema. Si el def declara
   `model` (o se puede resolver, ver §3), se genera.
3. **Letra (inicial del nombre)** — **último recurso**, solo cuando no hay modelo
   resoluble. Deja de ser el fallback normal y pasa a ser **señal de error**: si
   ves una letra en el grid, es que ese def no tiene ni icono ni modelo — hay algo
   que arreglar, no un estado esperado.

---

## 3. Pipeline de generación

Client-side, en cinco pasos:

1. **Resolver el modelo.** `def.model` directo → si es un def de arma autogenerada,
   se reutiliza la **cadena de resolución de modelo ya existente en los drops**
   (CHANGELOG #3): `def.model` → `WorldModel` del SWEP scripted → mapa de modelos de
   armas de engine (pistol/357/smg/ar2/shotgun/physgun/toolgun/cámara/…). Sin
   modelo resoluble → cae a letra (§2.3).
2. **Render a RT.** `ClientsideModel` del modelo, montado en un `RenderTarget`
   propio, con la cámara del **encuadre** del def (§4). Un solo RT reutilizable de
   512×512, no uno por ítem.
3. **Capturar a PNG.** `render.Capture` del RT → bytes PNG, crop al aspect del
   footprint (§5).
4. **Escribir a caché.** `file.Write` en `data/corpus/cargo/icons/<archivo>.png`
   (namespace de `Corpus.Data`). Nombre = hash de invalidación (§7).
5. **Cargar como material.** `Material("data/corpus/cargo/icons/<archivo>.png",
   "smooth")` → se entrega al consumidor (grid, slot, tooltip…).

### Generación lazy con presupuesto

Regla dura contra el hitch: **nada de generar todo el inventario en el frame en que
se abre.** Cola de renders procesada a **N por frame** (presupuesto configurable,
arrancar en 1–2). Mientras un ícono está en cola, la celda muestra el placeholder
de letra; se reemplaza en caliente cuando el render termina. Sesiones siguientes
leen del disco (paso 5 directo, sin pasos 1–4) → costo cero al reabrir.

Precedente de que el camino existe y no hay que inventarlo: `PositionSpawnIcon` +
render a RT están en el engine y su código (el del Edit Icon del sandbox) es
legible como referencia. **Verificar contra código vivo** antes de implementar —
regla del proyecto: las APIs de terceros/engine no se asumen de memoria.

---

## 4. Encuadre

Cómo queda posicionada la cámara respecto del modelo (distancia, ángulo, FOV,
offset). Tres niveles, gana el más específico:

1. **Auto** — `PositionSpawnIcon` da una cámara razonable para cualquier modelo a
   partir de su bounding box. Es el default y cubre la mayoría.
2. **`def.icon_cam` (código)** — override en la definición del ítem, para defs de
   mano donde el auto no calza (arma que queda torcida, modelo con origen raro).
3. **Override runtime en data (JSON)** — override persistido vía `Corpus.Data`,
   keyed por id de def. **No es lujo:** las defs autogeneradas de la captura de
   armas **no tienen código que editar** — su único canal de ajuste es este. Lo
   escribe el editor dev (§8).

Orden de lectura: override de data → `def.icon_cam` → auto. El editor puede
"canonizar" un override de data al def imprimiendo el Lua (§8).

---

## 5. Footprint (tamaño en celdas)

**El footprint vive en este subsistema**, no en el doc de UI: es una propiedad del
ítem que solo tiene sentido una vez que existe la imagen que lo llena. `size = {w,
h}` en unidades de celda (rifle 6×2, pistola 3×2, placa 2×3 vertical, venda 1×1).

Dos niveles:

1. **`def.size = {w, h}` explícito** — gana siempre.
2. **Auto por OBB cuantizado** *(decisión del autor 2026-07-11: sí, con auto)* —
   se toma el aspect del bounding box del modelo proyectado en la cámara del
   encuadre (§4) y se **cuantiza a un set cerrado de footprints permitidos**, con
   **techo por categoría**. Nunca un tamaño arbitrario: eso rompería el flow de
   gradas del grid.

Set permitido (candidato, ajustable): `1×1, 2×1, 1×2, 2×2, 3×1, 3×2, 2×3, 5×2,
6×2, 3×3, 4×3`. Techo por categoría (ej.: `ammo` nunca supera 2×1; `medical` nunca
supera 2×2; `weapons` permite hasta 6×2) — evita que un modelo mal escalado infle
la celda. El mapeo aspect→footprint y los techos se afinan empíricamente.

El mismo editor de encuadre (§8) fija el footprint manualmente cuando el auto no
convence — es literalmente el "ajustarlas para que calcen en la celda" de la
referencia RE.

---

## 6. Resolución y formato

- Render al **aspect del footprint**, **64 px por celda**: rifle 6×2 = 384×128;
  venda 1×1 = 64×64; placa 2×3 = 128×192.
- RT de trabajo 512×512, crop al capturar. Sobra para el grid y aguanta el
  zoom del tooltip de inspección (§9 de `Cargo_Architecture.md`).
- PNG (por la transparencia — ver §9). `Material` con flag `smooth`.

---

## 7. Caché e invalidación

Nombre de archivo = `<defid>_<hash>.png`, donde
`hash = hash(model + encuadre_efectivo + footprint_efectivo)`.

- Cambia cualquier entrada del hash (nuevo modelo, encuadre editado, footprint
  distinto) → **nombre nuevo → re-render automático** la próxima vez que se pida.
- Los archivos huérfanos (hash viejo) se ignoran; limpieza **lazy** (barrido
  ocasional de `data/corpus/cargo/icons/` que borra los que no matchean ningún def
  activo). No es crítico — son PNG chicos.
- **Regenerar-todo** *(decisión del autor 2026-07-11: sí)* — comando dev que
  invalida y re-encola toda la caché de una (§8), para cuando cambie un parámetro
  global de estilo (resolución, fondo, iluminación del RT) y todos los íconos
  deban rehacerse.

---

## 8. Editor dev

`cargo_icon_edit <defid>` — abre un preview en vivo del modelo en el RT con
controles:

- **Encuadre:** orbit / zoom / pan sobre el modelo. Guarda al **override de data**
  (§4.3).
- **Footprint:** fijar `w × h` manualmente (dentro del set permitido, §5). Guarda
  al override de data.
- **Save** → persiste override de encuadre + footprint a `Corpus.Data` (keyed por
  defid), invalida el hash de ese ítem, re-renderiza.
- **Print Lua** → imprime a consola el bloque `icon_cam = {...}, size = {w, h}`
  listo para pegar en el def, **para canonizar** el ajuste cuando el ítem tiene
  código editable (los autogenerados se quedan en el override de data).

Comando aparte:

- `cargo_icon_regen_all` → invalida y re-encola toda la caché (§7). Respeta el
  presupuesto por frame (§3) — no congela al ejecutarlo con un inventario grande.

Ambos comandos dev quedan **sin gate de admin** por ahora, con el mismo TODO que el
resto de comandos dev de Cargo (espera la primitiva de permisos de Corpus —
roadmap #12).

---

## 9. Riesgo técnico: transparencia

El look STALKER pide PNG con **canal alpha** (el ítem recortado sobre el fondo del
slot, no un cuadro opaco). El alpha en `render.Capture` sobre un RT es
históricamente **quisquilloso en GMod** — es el punto de fallo más probable de todo
el subsistema.

- **Plan A:** capturar con alpha real (fondo del RT transparente). Es lo ideal.
- **Plan B (fallback ya decidido):** **hornear el color del fondo del slot** en el
  PNG. El ítem se renderiza sobre un cuadro del mismo color que la celda →
  visualmente idéntico dentro del grid, sin depender del alpha. Se pierde
  transparencia real (un ícono sobre un slot resaltado se vería con su cuadro),
  costo menor.

**Gate de verificación en juego:** probar el Plan A al **inicio** de la
implementación, antes de construir el resto. Si el alpha no sale limpio, se baja a
Plan B sin drama. No se asume cuál funciona — se verifica. (Disciplina del
proyecto: verificar antes de finalizar.)

---

## 10. Consumidores y sincronización

Un solo sistema alimenta **todas** las superficies que muestran un ítem: grid de
inventario, slots de equipamiento, quick slots, cinturón de munición (§15), y el
zoom del tooltip de inspección (§9 de `Cargo_Architecture.md`). Ninguna de esas
superficies conoce el pipeline — piden `GetIcon(defid)` y reciben un `Material` (o
el placeholder de letra si aún está en cola).

**Sync de overrides:** los overrides de **encuadre y footprint** son datos del def
(no de instancia), así que viajan al cliente en el **snapshot de defs que Cargo ya
sincroniza** (mismo canal por el que llegan las defs autogeneradas de la captura).
El cliente los aplica al resolver el hash (§7). Los PNG **no** se sincronizan nunca
— cada cliente los genera local.

---

## 11. Fronteras y pendientes declarados

| Pendiente | Nota |
|---|---|
| Gate de admin de los comandos dev | Compartido con el resto de Cargo — espera primitiva de permisos de Corpus (roadmap #12) |
| Afinado del mapeo aspect→footprint y techos por categoría | Empírico; se calibra en juego con inventario real |
| Plan A vs B de transparencia | Se decide en el gate de verificación (§9), no antes |
| Modelos sin `WorldModel` ni mapeo | Caen a letra (§2.3) — señal de error, no estado esperado; se resuelve agregando modelo o icono al def |

---

## 12. Estado del documento

Bloque de diseño cerrado en sesión (Opus) y ratificado por el autor antes de este
volcado (Sonnet). **Prerequisito declarado** del bloque de UI fullscreen (§15 de
`Cargo_Architecture.md`): se implementa antes o junto con él.

| Sección | Estado |
|---|---|
| Jerarquía de fuente, pipeline, encuadre, footprint, resolución, caché, editor, sync | **Cerrado — este documento** |
| Transparencia (Plan A/B) | **Cerrado en diseño** — Plan concreto pendiente del gate de verificación en juego |
| Mapeo aspect→footprint y techos por categoría | Cerrado el mecanismo; valores a calibrar empíricamente |
