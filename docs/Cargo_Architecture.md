# Cargo — Documento de Arquitectura

> **Uso de este documento:** Referencia autocontenida para sesiones futuras de planificación (Claude Opus) e implementación (Claude Code). No se requiere el chat de diseño original.
>
> **Estado:** Block 1 de Cargo (ver §13). Cubre el inventario de jugador: contrato de ítems, slots y sub-slots, peso, providers de dinero/facción, grid de UI, contenedores en mundo, inspección y stat-bars. El banco de trabajo (crafteo, reparación, desarme, upgrades) es un subsistema propio, documentado aparte en [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md) — mismo patrón de desprendimiento que ya usó Caliber con Scavenger. El comercio (trueque, basket, dinero, trader) es otro subsistema desprendido — [`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) — porque trae el primitivo de inventario-en-entidad, reusado para lootear cadáveres.
>
> **Dependencia dura:** Corpus. **Dependencias soft declaradas en este documento:** Cortex (facción/rango), Coagulant (drenaje de stamina por sobrepeso, vitales del panel de estado), Craving (hambre/sed del panel de estado), Caliber (protección de armadura, escudos de jugador — ambos en Block 3 de Caliber, aún no existe).

---

## Índice

1. [Visión general](#1-visión-general)
2. [Referencias visuales](#2-referencias-visuales)
3. [Contrato de ítems: dos clases](#3-contrato-de-ítems-dos-clases)
4. [Slots de equipamiento y sub-slots](#4-slots-de-equipamiento-y-sub-slots)
5. [Peso y movimiento](#5-peso-y-movimiento)
6. [Providers: dinero y facción/rango](#6-providers-dinero-y-facciónrango)
7. [Grid de inventario y UI](#7-grid-de-inventario-y-ui)
8. [Contenedores en mundo](#8-contenedores-en-mundo)
9. [Inspección de ítems (tooltip)](#9-inspección-de-ítems-tooltip)
10. [Attachments de armas](#10-attachments-de-armas)
11. [Stat-bars registrables](#11-stat-bars-registrables)
12. [Persistencia](#12-persistencia)
13. [Fronteras y pendientes declarados](#13-fronteras-y-pendientes-declarados)
14. [Estado de este documento](#14-estado-de-este-documento)
15. [UI fullscreen (rediseño de forma)](#15-ui-fullscreen-rediseño-de-forma)
16. [Sistema de munición: el cinturón ES el pool](#16-sistema-de-munición-el-cinturón-es-el-pool)

---

## 1. Visión general

**Cargo** es el framework de inventario de jugador de Corpus: contrato de ítems, grid de UI, peso, slots de equipamiento y contenedores. Es hoja en el grafo de dependencias — no depende de ningún otro módulo — pero es **hub de consumo**: Coagulant, Craving y Caliber registran sus propios ítems contra el framework que Cargo expone. Cargo posee el "cómo se ve y se guarda un ítem"; cada módulo dueño posee el "qué hace".

Modelo de referencia: **grid uniforme estilo STALKER/GAMMA**, no Tetris estilo EFT. Cada ítem ocupa una celda, auto-ordenada por categoría; el costo de cargar más no es espacial, es de **peso**. Decisión explícita: define el modelo de datos completo del módulo (ítems sin dimensiones), abarata la net-sync y fija la UX de transferencia con contenedores.

---

## 2. Referencias visuales

Layout congelado contra dos capturas de referencia (inventario STALKER GAMMA, loot STALKER Anomaly) y mockups iterados en Claude Design durante la sesión de diseño:

- Panel de equipamiento (slots + quick slots + panel de estado)
- Header de perfil (identidad, facción/rango, dinero) + grid de inventario + footer de peso
- Tooltip de inspección de ítem
- Tooltips de Head/Body/Back con sub-slots y condición por zona

Estos mocks son la fuente de verdad de layout hasta que exista una implementación VGUI real; en caso de divergencia, el código manda (mismo principio que rige todo el proyecto).

---

## 3. Contrato de ítems: dos clases

Todo ítem registrado contra Cargo cae en una de dos clases. La clase se declara en la definición del ítem y determina si existe un blob de instancia.

| Clase | Ejemplos | Persistencia | Stackea |
|---|---|---|---|
| **Stackeable** | munición, comida, componentes de crafteo, placas de armadura | solo un `count` | Sí |
| **Único (con instancia)** | armas, armaduras, mochilas, NVG | blob de datos propio, persistido por instancia | No, nunca |

### Contrato base (Cargo owns)

```lua
Cargo.Items.Register({
    id = "corpus_caliber_toz34",
    name = "TOZ-34 \"Bizon\"",
    weight = 3.2,
    class = "unique",           -- "stackable" | "unique"
    category = "weapons",
    icon = "...",
    display_stats = {           -- opcional: fallback manual si no hay ARC9
        accuracy = -8, handling = -21, damage = -11, firerate = -9,
    },
    trivia = "Escopeta superpuesta de caza...",
})
```

- **Cargo owns**: schema base (id, peso, icono, clase, categoría, stack), la API de registro, cómo se persiste el blob de instancia, cómo se renderiza en grid y tooltip.
- **El módulo dueño owns**: la semántica — cómo se degrada la condición, qué hace un ítem al usarse, qué contiene su blob de instancia. Caliber decide cómo se rompe la protección de una zona; Cargo solo guarda el número y lo muestra.

### Blob de instancia (ítems únicos)

Cada ítem único persiste un blob propio vía `Corpus.Data`, namespaced por instancia (no por definición — dos TOZ-34 en el mismo inventario tienen historiales independientes). Contenido mínimo genérico: condición (global o por zona, según declare el módulo dueño), sub-slots ocupados (§4), munición bindeada (grupo A/B). Todo lo demás es específico del módulo — Caliber define qué campos lleva la condición por zona de una armadura; Cargo no interpreta ese contenido, solo lo transporta.

---

## 4. Slots de equipamiento y sub-slots

### Slots de primer nivel

| Slot | Contenido | Notas |
|---|---|---|
| Head | Casco | sub-slot de accesorio (óptica: NVG, gafas) |
| Body | Chaleco/armadura | condición por zona (torso, estómago, brazos, piernas) · sub-slot de accesorio (exo/escudo) · slots de placa |
| Back | Mochila | modificador de capacidad de peso |
| Primary / Secondary / Sidearm | Armas | grupo de munición bindeado (A/B) |
| Melee | Arma cuerpo a cuerpo | — |
| Accessory 1 / Accessory 2 | Accesorios menores (categoría genérica `accessories`) | slots dedicados, sin sub-slots propios. *Enmienda 2026-07-10: nacieron como "PDA / Detector", renombrados por el autor en la primera pasada en juego — eso es mobiliario STALKER y Corpus es agnóstico de ambientación* |
| Quick slots F1–F4 | Consumibles bindeados | algunos condicionales — ver abajo |

### Primitivo genérico: sub-slots

Un ítem puede declarar **sub-slots propios**, cada uno con un filtro de categoría. Es el mismo primitivo en los tres casos siguientes — se implementa una vez:

- **Head → sub-slot óptica**: acopla NVG o gafas (compatibilidad con mods externos de visión nocturna, ver §12).
- **Body → sub-slot exo/escudo**: acopla armadura externa o generador de escudo de energía de jugador — punto de acoplamiento físico para Caliber Block 3, sin inventar un sistema nuevo.
- **Body → slots de placa**: 0–N slots según la armadura, cada uno acepta un ítem stackeable de clase "placa" con campo `material` (tabla de materiales Caliber).

Los quick slots F1–F4 usan el mismo principio en reversa: su **disponibilidad** (no su contenido) depende de un ítem equipado en otro slot — igual que el cinturón de artefactos desbloqueable por upgrade de traje en la referencia STALKER. Un slot F puede estar bloqueado (candado) hasta que el traje equipado lo habilite.

```lua
-- Firma ilustrativa del primitivo de sub-slot
Cargo.Items.DeclareSubSlot(itemDef, {
    id = "optic",
    filter = "category:optics",       -- qué categorías de ítem acepta
    maxItems = 1,
})
```

### Eyección obligatoria

Regla dura, aplica en todo flujo que destruye o reemplaza un ítem con sub-slots ocupados (desarme, reemplazo de armadura, muerte con drop): **los sub-slots se eyectan al inventario o al mundo antes de que el contenedor se destruya.** Un generador de escudo o una placa nunca se pierden como efecto colateral de perder el chaleco que los contenía.

---

## 5. Peso y movimiento

**Cargo nativo**: curva continua peso → velocidad de movimiento (walkspeed/runspeed). Funciona standalone, sin ningún módulo soft-dep presente — un servidor con solo Cargo montado ya tiene consecuencia real por sobrecarga.

**Coagulant soft-dep**: dueño del recurso de stamina. Si está presente, se suma *encima* de la penalización base: drenaje de stamina por sobrepeso, efectos de fatiga, interacción con vitales. Cargo nunca depende de la stamina de Coagulant para su propia consecuencia — evita degradación deshonesta si Coagulant no está montado.

Capacidad total = base del jugador + bonus de mochila equipada (Back). El footer de peso muestra el desglose (`base + mochila = total`) y colorea según proximidad al límite.

---

## 6. Providers: dinero y facción/rango

Mismo patrón en ambos casos — Cargo (o el módulo dueño del dato) define una interfaz, un provider nativo cubre el fallback, providers externos se registran y reemplazan.

### Dinero

- Interfaz: get / add / take / format.
- Provider nativo: **USD**, fallback cuando no hay nada más registrado.
- Providers externos: DarkRP u otros frameworks económicos se registran contra la misma interfaz; el símbolo y formato los define el provider activo.
- Cargo es dueño de la interfaz y del provider nativo; no impone un sistema económico.

### Facción y rango

- **Cortex es dueño del dato** (facción, rango, relaciones — es un concepto de IA/comportamiento, no de inventario). Framework pequeño dentro de Cortex para que otros mods de facciones se registren como provider.
- **Cargo solo renderiza** lo que el provider activo de Cortex reporta en el header de perfil — Cargo no almacena ni interpreta facción.
- Cruce Cargo→Cortex: Cargo emite qué traje está equipado en Body; Cortex resuelve la facción aparente (disguise) a partir de esa señal. Soft-dependency simétrica, sin acoplamiento directo — ambos pasan por el registro de Corpus.

---

## 7. Grid de inventario y UI

- **Grid uniforme**: 1 celda = 1 ítem, auto-sort por categoría, sin gestión espacial ni rotación.
- **Overlays estándar por celda**: stack count (arriba-derecha), condición % (abajo-derecha, solo ítems con condición), icono de efecto (abajo-izquierda: hemostático, radiactividad, batería), calibre (abajo-izquierda, solo munición).
- **Header de perfil**: identidad (Steam), facción/rango (provider Cortex), dinero (provider), retrato.
- **Filtro por categoría**: fila de tabs sobre el grid (todo, armas, munición, médico, comida, misc...).
- **Footer de peso**: barra + valor actual/máximo + desglose base/mochila.

> **Enmienda 2026-07-11 (bloque UI fullscreen).** La **forma** de la UI cambia a
> pantalla completa estilo STALKER/GAMMA — ver §15. La **funcionalidad y la
> disposición de las partes** de §7 se conservan 1:1 (grid con overlays por esquina,
> header de perfil con providers, tabs de categoría, footer de peso con desglose). Dos
> cambios de fondo:
>
> - El grid deja de ser **uniforme** (1 celda = 1 ítem) y pasa a **gradas**: cada ítem
>   ocupa `w × h` celdas según su **footprint** (definido en
>   `Cargo_ItemImages_Arquitectura.md` §5). El **modelo de datos no cambia** — sigue
>   siendo ítems sin gestión espacial, sin rotación, auto-sort por categoría; el
>   footprint es solo **render**, gobierna cuántas celdas pinta el ítem, no cómo se
>   guarda ni cuánto pesa. El costo de cargar sigue siendo peso, no espacio.
> - **Prerequisito duro:** las gradas dependen del sistema de imágenes
>   (`Cargo_ItemImages_Arquitectura.md`). Con el fallback de letra, un footprint 6×2 se
>   ve peor que el grid uniforme. Ese bloque se implementa **antes o junto** con este.

---

## 8. Contenedores en mundo

Mismo grid, panel de transferencia lado a lado (contenedor | inventario propio), con botones `Take all` / `Move all` — spec tomado de STALKER Anomaly.

- **Capacidad por contenedor**: configurable por ítem-contenedor; puede ser finita (caja de campo) o infinita (stash de base). Decisión de diseño por contenedor, no una regla global.
- El peso del jugador sigue gobernando cuánto puede *tomar*, aunque el contenedor no tenga límite propio.

---

## 9. Inspección de ítems (tooltip)

Al pasar el cursor sobre un ítem: nombre, peso, condición, trivia/descripción, stats comparativos con delta (barras + %), compatibilidad de munición si aplica.

**Fuente de stats — jerarquía de lectura:**

1. **ARC9**: los stats se leen vía `GetProcessedValue` (patrón lectura-only ya establecido en Caliber — Cargo nunca escribe esos valores, el menú ARC9 los posee).
2. **No-ARC9**: campo `display_stats` en la definición del ítem, llenado a mano por quien registra el ítem.

Ambas rutas alimentan el mismo componente visual — el tooltip no distingue origen, así todas las armas se ven homogéneas independientemente de su base.

---

## 10. Attachments de armas

Los attachments (miras, silenciadores, lanzagranadas, láseres) son **ítems de Cargo** que se acoplan a armas desde el inventario. Spec de UX tomado de STALKER; spec de integración construido sobre el sistema nativo de ARC9.

### 10.1 Clase y representación

Attachment = ítem **stackeable** (sin blob de instancia — los attachments no tienen condición propia en ARC9 ni la necesitan en v1). Categoría propia en el grid. En el mundo, los attachments de ARC9 EFT ya existen como entidades spawnables; al recogerlas se convierten en el ítem Cargo correspondiente.

### 10.2 Flujos de acople (UX, spec STALKER)

Dos rutas equivalentes, ambas se implementan:

1. **Click secundario** sobre el attachment en inventario → menú contextual "Acoplar a..." listando las armas compatibles equipadas o en inventario.
2. **Drag & drop** del attachment sobre el arma destino (en grid o en slot de equipamiento).

Desacople: desde la inspección del arma (el tooltip §9 gana una fila de attachments instalados) o click secundario sobre el arma → "Desacoplar...". El attachment desacoplado vuelve al inventario como ítem.

### 10.3 Integración ARC9 — el canal legítimo de escritura

Distinción crítica que resuelve parcialmente la bandera de Upgrades: el principio **lectura-only aplica a los stats** (`GetProcessedValue` — nadie escribe valores procesados). Instalar/remover attachments vía la **API propia de ARC9** es el canal de escritura *soportado* — es exactamente lo que hacen el menú de customización de ARC9 y sus entidades de attachment. Los stats cambian como *consecuencia* de que ARC9 procese sus propios attachments, no porque Corpus escriba valores. El contrato se preserva.

**Regla de reconciliación** (el jugador puede seguir usando el menú C de ARC9 directamente):

- El **estado del arma** (qué lleva puesto) es autoritativo en ARC9.
- El **inventario** (qué hay en la mochila) es autoritativo en Cargo.
- Cargo escucha los eventos de attach/detach de ARC9 para reconciliar: si el jugador instala desde el menú C un attachment que estaba en Cargo, Cargo lo descuenta; si desinstala, Cargo lo recibe.
- Decisión de fuente única: el inventario de attachments propio de ARC9 se puentea — Cargo pasa a ser el almacén; ARC9 conserva el estado montado y la matemática de stats. Evita el doble-inventario con drift.

> **Verificar contra código antes de implementar:** nombres exactos de la API de attach/detach y de los hooks de eventos en la versión de ARC9 que usa el pack de Darsu. Este proyecto ya aprendió (extractor EFT: `Penetration` vs nombres crudos, `armorDamage` ×0.01) que los nombres de ARC9 no se asumen de memoria — se leen del código vivo. Ítem explícito para el prompt de CC.

### 10.4 Compatibilidad y armas no-ARC9

- **Tooltip de attachment** muestra las armas compatibles (spec del mod "Attachments Info" de la guía GAMMA de referencia). Para ARC9, la compatibilidad de slot se lee de las declaraciones nativas del arma; nada se duplica a mano.
- **Armas no-ARC9** (TFA u otras): tabla de compatibilidad manual en la definición del ítem — mismo patrón de fallback que `display_stats` en §9. Alcance v1: ARC9 completo; no-ARC9 solo si el arma declara su tabla manualmente.

---

## 11. Stat-bars registrables

El panel de estado del jugador (columna de barras junto al equipamiento) expone una API genérica de registro; Cargo no conoce el contenido de cada barra, solo la renderiza.

```lua
-- Firma ilustrativa
Cargo.StatusPanel.RegisterBar(module, {
    id = "hydration",
    icon = "droplet",
    getValue = function(ply) return ... end,   -- 0-100
})
```

- **Craving**: hambre, hidratación.
- **Coagulant**: estado vital (overall de vida) y cantidad de sangre — no vida/sangrado por separado como en la referencia STALKER; decisión explícita del autor para el bloque de Coagulant.
- **Caliber (Block 3, pendiente)**: protección de armadura equipada.

Si el módulo dueño de una barra no está montado, la barra simplemente no se registra — degradación honesta, mismo principio que gobierna todo soft-dep del ecosistema.

---

## 12. Persistencia

Todo vía `Corpus.Data` (namespace `cargo`), sin necesidad de SQLite: no hay consultas relacionales ni volumen que lo justifique.

- **Instancias de ítem único**: un archivo por instancia, blob definido por el módulo dueño.
- **Inventario del jugador**: estructura de slots + stacks, indexado por SteamID64 (charset válido para el saneo de `Corpus.Data`, sin necesidad de tabla adicional).
- **Conocimiento de recetas** (usado por el banco de trabajo, ver `Workbench_Arquitectura.md`): mismo mecanismo, un archivo por jugador con el set de IDs desbloqueados.

---

## 13. Fronteras y pendientes declarados

Boundary-debt explícito, mismo espíritu que el flag de Scavenger en Caliber — se declara ahora para no perderlo, se resuelve cuando el bloque dueño cierre:

| Pendiente | Dueño futuro | Nota |
|---|---|---|
| Efectos de armadura de jugador (mitigación real por Body) | Caliber Block 3 | El ítem existe, pesa y se equipa desde ya; el efecto llega cuando Block 3 cierre |
| Escudos de energía de jugador vía sub-slot Body | Caliber Block 3 | Punto de acoplamiento (sub-slot) ya definido en este documento |
| Compatibilidad con mods externos de NVG/ópticas | Cargo (integración) | Sub-slot Head ya generalizado; falta mapear mods concretos |
| Categoría de materiales de crafteo | Cargo (contrato) + Caliber/Coagulant (contenido) | Reservada, sin schema de recetas — ver `Workbench_Arquitectura.md` |
| Upgrades de armas ARC9/EFT | Workbench | Bandera parcialmente resuelta: la API de attach/detach de ARC9 es un canal de escritura legítimo (ver §10.3) — los upgrades de arma pueden modelarse como attachments nativos ARC9 en vez de escritura de stats. Verificar API contra código antes de cerrar |
| Attachments no-ARC9 (TFA u otras bases) | Cargo (integración) | Solo con tabla de compatibilidad manual declarada por arma — sin alcance automático en v1 (§10.4) |

---

## 14. Estado de este documento

Bloque de diseño de Cargo (inventario) cerrado y validado en sesión de diseño (Opus) — ratificado por el autor antes de este volcado a documento (Sonnet). El banco de trabajo (crafteo/reparación/desarme/upgrades) es un bloque de diseño relacionado pero independiente, documentado en `Workbench_Arquitectura.md`.

| Sección | Estado |
|---|---|
| Contrato de ítems, slots/sub-slots, peso, providers, grid, contenedores, tooltip, stat-bars | **Cerrado — este documento** |
| Attachments de armas (UX + puente ARC9) | **Cerrado en diseño** — API exacta de ARC9 pendiente de verificación contra código |
| UI fullscreen (forma) | **Cerrado — §15**; VGUI es bloque de implementación aparte; depende de Cargo_ItemImages |
| Sistema de munición (el cinturón ES el pool) | **Cerrado — §16** (Bloque B, roadmap #19). Abierto: cargadores rellenables con toggle, y el binding de ammo-atts de EFT (§16.6) |
| Workbench (craft/reparación/desarme, upgrades pendiente) | Cerrado en su mayoría — ver documento aparte |
| Efectos de armadura y escudos de jugador | Pendiente — Caliber Block 3 |
| Crafting profundo (recetas de materiales, categorías) | Pendiente — diseño posterior |

---

## 15. UI fullscreen (rediseño de forma)

### 15.0 Alcance

Cambia la **forma**, no la funcionalidad. Todo lo de Block 1 (slots, sub-slots,
quick slots, peso, providers, stat-bars registrables, tabs, footer, contenedores)
se conserva; se reordena al layout STALKER/GAMMA a pantalla completa. Solo se agregan
elementos de **forma** nuevos: cinturón de munición (15.2), círculos de herramienta
sandbox (15.2) y botón de dinero en el header (15.3). El comercio fullscreen es un
subsistema aparte — `Cargo_Trade_Arquitectura.md`.

**Fuente de verdad de layout:** el mockup iterado en la sesión de diseño
(`mockups/cargo_fullscreen_ui_mock_v1.html`), mismo estatus que los mocks de §2 — manda
hasta que exista VGUI real; en divergencia, el código manda.

### 15.1 Layout: tres columnas, tres estados

Patrón GAMMA exacto. **Una sola implementación VGUI** de tres columnas; lo que cambia
entre estados es qué muestra la **columna izquierda** (contextual):

```
┌────────────────┬──────────────┬────────────────┐
│  IZQUIERDA      │   CENTRO     │   DERECHA       │
│  (contextual)   │  equipamiento│  inventario     │
│                 │  del jugador │  propio         │
│  · solo:  vacía │  (siempre)   │  (siempre)      │
│  · loot:  cont. │              │                 │
│  · trade: stock │              │                 │
└────────────────┴──────────────┴────────────────┘
```

| Estado | Trigger | Columna izquierda | Refs |
|---|---|---|---|
| **Solo** | tecla de inventario | vacía (mundo visible detrás) | §15 |
| **Loot** | usar contenedor en mundo | inventario del contenedor + Take all | §8 |
| **Trade** | interactuar con trader (NPC o jugador) | stock del trader / inventario del otro jugador + strips Buy/Sell | `Cargo_Trade_Arquitectura.md` |

- **Centro (equipamiento)** y **derecha (inventario propio)** son idénticos en los
  tres estados. La columna izquierda se muestra/oculta y cambia de contenido — no hay
  tres pantallas, hay una con un panel contextual.
- El grid de las columnas izquierda y derecha es el mismo componente de gradas
  (§7 enmendado + `Cargo_ItemImages` §5).

### 15.2 Columna de equipamiento (orden STALKER)

Reordena los slots de §4 a la disposición GAMMA. De arriba a abajo:

1. **Fila de accesorios y cabeza:** `Accessory 1 · Head · Accessory 2`.
2. **Fila alta (columnas verticales):** `Secondary · Body · Primary`. Body al centro
   (el más grande), armas a los lados. Badge de **grupo de munición A/B** (§3, §4) en
   la esquina del slot de arma. Barra segmentada de **condición** bajo cada slot.
3. **Fila baja:** `Sidearm · Back · Melee`.
4. **Quick slots F1–F4** (§4) — fila de cuatro. Disponibilidad condicional al traje
   equipado se conserva (candado).
5. **Círculos de herramienta sandbox** *(nuevo — roadmap #21)*: tres botones
   **circulares** (solo el símbolo: physgun, toolgun, camera; sin texto) entre los
   quick slots y el cinturón. Son herramientas muy usadas del sandbox; tenerlas a la
   vista evita buscarlas en el grid. **Toggle "hide"** al lado los oculta para quien no
   las quiera. Son atajos de equipar/seleccionar, no slots de almacenamiento.
6. **Cinturón de munición** *(nuevo — forma de roadmap #19, ver abajo)*.
7. **Panel de estado** (§11, stat-bars registrables) — al fondo de la columna.

#### Cinturón de munición (solo la FORMA)

Fila de **6 slots cuadrados** (tipo cinturón — la munición no es lo bastante grande
para justificar más espacio). Los ítems de munición del inventario se **mueven acá**
para **alimentar al arma activa**: la munición cargada deja de estar suelta en el grid
y pasa al equipo. En el mock, los stacks bindeados a los grupos A/B de las armas
equipadas viven en el cinturón, no en el grid.

> **Frontera cerrada:** este bloque cerró la **forma** del cinturón (la fila de slots y que
> la munición se mueva ahí). La **semántica** la cerró el Bloque B → **[§16](#16-sistema-de-munición-el-cinturón-es-el-pool)**:
> el cinturón no almacena munición, **ES** la reserva real del jugador. Lo único que sigue
> abierto de #19 es el sistema de cargadores rellenables con toggle (fuera del v1).

### 15.3 Botón de dinero en el header

*(Nuevo — decisión del autor 2026-07-11.)* Botón **circular** junto al valor de dinero
en el header de perfil (§7). Su comportamiento depende del estado (15.1):

- **Solo:** prompt de monto → resta del wallet (provider, §6) → **suelta una entidad de
  dinero** en el mundo (ver `Cargo_Trade_Arquitectura.md` §7). "Botar dinero".
- **Trade:** agrega el monto a **tu lado del basket** como línea de solo-dinero → sirve
  para entregar dinero directo sin ningún otro objeto, o para cuadrar un trueque
  desigual.

Detalle en `Cargo_Trade_Arquitectura.md` §7 — el botón es el disparador, la mecánica de
la entidad-dinero y el traspaso P2P viven allá porque son parte del subsistema de
comercio.

### 15.4 Qué NO entra en este bloque

- **Orden/holster de armas (roadmap #22):** es **comportamiento** (reordenar teclas
  1–7, re-apretar para enfundar, matar notificaciones de GMod), no forma. Solo se
  refleja en este bloque como el **orden visual** de los slots de equipamiento (15.2).
- **Semántica de munición (roadmap #19):** solo la forma del cinturón entra (15.2).
- **Comportamiento de pickup/drop (roadmap #16–18, #20):** ajenos a la forma de la UI.

---

## 16. Sistema de munición: el cinturón ES el pool

*(Bloque B, roadmap #19. Cierra la semántica que §15.2 dejó como forma vacía.)*

### 16.1 La decisión

**El cinturón no guarda munición: ES la reserva real del jugador.** Un stack colgado en un
slot del cinturón *es* el pool nativo del engine para su tipo de munición; el grid es solo
almacén en data. Las armas del **mismo tipo HL2 comparten la reserva** — como en HL2 mismo y
como en STALKER. Lo que queda distinto **por arma** es el **cargador** (`Clip1`), que ya
persiste en el blob de instancia (roadmap #18, §3).

Esto resuelve la contradicción que planteó el autor: dos armas ARC9 EFT de "calibres"
distintos pueden consumir el mismo tipo HL2 real. **No se implementa reserva por-arma con
swap** en cada cambio de arma.

### 16.2 Por qué el tipo de engine es la clave, y el calibre no

`def.ammo = { caliber = "9x19", hl2 = "Pistol" }`:

- **`hl2`** es el tipo de munición del engine y es **la clave del pool**. Es la verdad.
- **`caliber`** es una **etiqueta de display** (es sobre lo que agrupa el badge A/B del
  cinturón). En el def de un **arma**, `def.ammo` lleva *solo* la etiqueta: el tipo real de
  un arma sale de su entidad, nunca del def.

Verificado contra el código vivo de ARC9 (2026-07-12): un arma ARC9 declara `SWEP.Ammo` como
un tipo HL2 pelado (`"pistol"`), y **la reserva de ARC9 ES el pool nativo** — `SWEP:Ammo1()` es
literalmente `ply:GetAmmoCount(self:GetProcessedValue("Ammo"))`
(`Arc9 Base/lua/weapons/arc9_base/sh_reload.lua:578-586`). Por eso el modelo funciona **nativo**,
sin pelearse con ARC9 ni forkearlo.

Los 11 tipos base de HL2 quedan registrados como ítems (`cargo_ammo_<tipo>`) en
[`shared/corpus_cargo_ammo.lua`](../lua/corpus_cargo/shared/corpus_cargo_ammo.lua), cada uno con
modelo, peso por unidad, descripción y **`max_stack`** — el tope es lo que convierte a los seis
slots del cinturón en una **decisión** (cuánta munición y de qué calibre te colgás) en vez de
decoración. Los `.mdl` se verificaron parseando los VPK reales, no de memoria.

### 16.3 El espejo (`server/corpus_cargo_ammopool.lua`)

Invariante, para cada tipo que Cargo maneja:

```
ply:GetAmmoCount(tipo)  ==  suma de los stacks del cinturón de ese tipo
```

Las dos direcciones son reales:

| Dirección | Cuándo | Qué hace |
|---|---|---|
| **cinturón → pool** (`Push`) | al colgar/sacar un stack, y en cada spawn | `SetAmmo(total)` — asigna, nunca suma, así que empujar dos veces no infla nada |
| **pool → cinturón** (`Reconcile`) | poll a 4 Hz | el pool es la **verdad del consumo**: recargar lo drena, descargar el cargador lo devuelve, granadas y cohetes lo gastan directo. El cinturón lo sigue, así que el conteo de la celda es el conteo real |

**Por qué un poll y no hooks:** el pool lo muta la base de arma que el jugador tenga en la mano
(ARC9, HL2, TFA, la que sea). Pollear `GetAmmoCount` es **agnóstico de base** y cuesta once
lecturas de entero por jugador por tick. Es el contrato "detección, nunca asunción" pagado
honestamente: **el pool funciona sin ningún hook de ARC9**.

El drenaje va **por orden de slot** (1→6): predecible, y es el orden que el jugador eligió él
mismo al colgar los stacks. La munición que vuelve de un cargador y no entra en el cinturón
**no se destruye** — se va al grid.

### 16.4 El éter (el bloqueante que este bloque existe para matar)

> Reporte in-game del autor (2026-07-12): *"ARC9 EFT, cuando tomas un arma, te da munición del
> arma también. La munición no puede aparecer del éter."*

`SWEP:InitialDefaultClip` (`Arc9 Base/.../sh_deploy.lua:130-146`) hace
`ply:GiveAmmo(ClipSize * arc9_mult_defaultammo)` en cada entrega de arma, disparado por un
`timer.Simple(0.4)` desde su `Initialize` (`sh_init.lua:80-86`). **Contamina exactamente el pool
que el cinturón debe poseer.**

Se ataca en tres capas:

1. **La fuente.** Cargo fuerza `arc9_mult_defaultammo 0` (su default es **2**) al ready —
   mismo patrón de takeover que el puente de attachments ya usa con `arc9_free_atts`. Convar
   propia: `cargo_ammo_arc9_takeover`.
2. **El spawn.** En cada `PlayerLoadout`, `StripAmmo()` y después `Push()`: la reserva se
   reconstruye **del cinturón y de nada más**, diferido más allá de la ventana de 0.4 s de ARC9.
3. **El gate.** El reconciliador queda **suprimido** para un jugador hasta que su `Push` de
   spawn corrió, así que nada de lo que una base de arma regale durante la ventana de spawn
   puede colarse al cinturón por el espejo.

> **Deuda declarada, honesta:** la capa 1 **no es hermética por construcción**.
> `SWEP.ForceDefaultAmmo` **saltea la convar** (`sh_deploy.lua:140`). Hoy la neutralización es
> **completa** para los cinco packs instalados (grep 2026-07-12: ningún arma la usa con valor
> distinto de cero — solo las granadas EFT, y la ponen en 0), pero un pack futuro podría
> reabrir el hueco. **La escalación que queda anotada**, si el autor vuelve a ver munición
> aparecer: un **ledger de conservación** (pool + cargadores debe balancear; todo excedente sin
> un cargador que lo explique es éter y se clampea).

### 16.5 Munición del mundo, muerte y persistencia

- **Munición del mundo → el GRID.** Los `item_ammo_*` del mapa se vetan al engine y entran como
  ítem de Cargo al inventario (decisión del autor: *el grid es el almacén, el cinturón es el
  pool* — la encontrás, la guardás, y vos decidís cuánta te colgás). Nunca se vuelve reserva a
  espaldas del jugador. Convar: `cargo_ammo_world_pickup`.
  *Deuda:* las entidades de pickup propias de ARC9 (`arc9_ammo`/`arc9_ammo_big`) reparten
  munición por su propio `Touch`, no por `PlayerCanPickupItem`, así que el espejo las absorbe al
  **cinturón** en vez del grid. No es éter (las balas son reales y están contadas), pero saltea
  el grid. Son props de sandbox: queda como deuda, no se parchea a ciegas.
- **Muerte.** `WipeOnDeath` ahora vacía **también el pool real** — el cinturón *era* la reserva,
  así que borrarlo sin borrar el pool dejaba al cadáver respawneando armado.
- **Persistencia.** El pool nativo **no persiste**; el cinturón sí (vive en el record). Por eso
  se re-siembra desde el cinturón en cada spawn (16.3/16.4).

### 16.6 Munición "propia" de ARC9 EFT — la palanca que queda

Verificado: cada tipo de bala de EFT (FMJ, AP, HP…) es un **attachment** en un slot **por
calibre** (`ATT.Category = {"eft_ammo_9x19"}`, …). **Ningún** ammo-att de EFT setea `ATT.Ammo`:
⇒ **no cambian el tipo HL2**, siguen comiendo del mismo pool nativo. Lo único que cambian es
**balística** (`DamageMax/Min`, `Penetration`, `ArmorPiercing`, `PhysBulletMuzzleVelocity`…), vía
`ARC9EFT.GenerateEFTAttachment`. Esto **confirma** el punto 4 del autor.

De ahí sale la palanca para "simular" munición realmente distinta **sin tocar el pool**: que el
stack del cinturón que alimenta al arma **decida qué ammo-att de EFT va montado**. El campo
`def.ammo.att` queda **reservado en el schema** para eso. **Fuera del v1** (decisión del autor:
fundación primero) — es el bloque siguiente.

### 16.7 Qué NO entra

- **Cargadores rellenables con toggle** (lo único que queda abierto de #19).
- **Binding de ammo-atts de EFT** (16.6) — bloque propio.
- **Categorías fijas de tabs** (#23) y **retícula del grid** (#24): frentes ajenos.
