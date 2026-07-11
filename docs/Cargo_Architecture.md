# Cargo — Documento de Arquitectura

> **Uso de este documento:** Referencia autocontenida para sesiones futuras de planificación (Claude Opus) e implementación (Claude Code). No se requiere el chat de diseño original.
>
> **Estado:** Block 1 de Cargo (ver §13). Cubre el inventario de jugador: contrato de ítems, slots y sub-slots, peso, providers de dinero/facción, grid de UI, contenedores en mundo, inspección y stat-bars. El banco de trabajo (crafteo, reparación, desarme, upgrades) es un subsistema propio, documentado aparte en [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md) — mismo patrón de desprendimiento que ya usó Caliber con Scavenger.
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
| Workbench (craft/reparación/desarme, upgrades pendiente) | Cerrado en su mayoría — ver documento aparte |
| Efectos de armadura y escudos de jugador | Pendiente — Caliber Block 3 |
| Crafting profundo (recetas de materiales, categorías) | Pendiente — diseño posterior |
