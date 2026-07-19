# Workbench (Cargo) — Arquitectura del banco de trabajo

> **Uso de este documento:** Subsistema autocontenido, desprendido de [`Cargo_Architecture.md`](Cargo_Architecture.md) por ganancia propia de complejidad — mismo patrón que Caliber usó para Scavenger. No se requiere el chat de diseño original ni el documento padre para entender este.
>
> **Estado:** Craft, Reparación y Desarme cerrados. Upgrades pendiente (ver §6).
>
> **Spec de referencia:** sistema de banco de STALKER GAMMA (guía de Steam Workshop citada en sesión de diseño). Se copia la estructura de cuatro pestañas y la economía de toolkits; se adapta la pestaña de reparación al modelo de condición por zona ya cerrado en Cargo, y se diseña Desarme desde cero (GAMMA no lo modela con este detalle).

---

## Índice

1. [Visión general y relación con Cargo](#1-visión-general-y-relación-con-cargo)
2. [Estructura de pestañas](#2-estructura-de-pestañas)
3. [Craft](#3-craft)
4. [Reparación](#4-reparación)
5. [Desarme](#5-desarme)
6. [Upgrades (pendiente)](#6-upgrades-pendiente)
7. [Economía de toolkits](#7-economía-de-toolkits)
8. [Registro: patrón de módulo dueño](#8-registro-patrón-de-módulo-dueño)
9. [Persistencia](#9-persistencia)
10. [Estado de este documento](#10-estado-de-este-documento)

---

## 1. Visión general y relación con Cargo

El banco de trabajo es la UI y el framework de mantenimiento de ítems: craftear, reparar, desarmar y (a futuro) mejorar. Vive dentro de Cargo — reutiliza su contrato de ítems (§3 de `Cargo_Architecture.md`), su clase "único con instancia" para condición por zona, y su sistema de placas — pero es su propio archivo de arquitectura porque acumuló reglas de economía y balance que no pertenecen al documento de inventario general.

**Propiedad** (cita **CRG-1**, sede `../../corpus/docs/CORPUS_Architecture.md` §5): el banco (UI, recetas, desarme, toolkits) es framework de **Cargo**. Cada módulo de dominio registra sus propias recetas y componentes contra ese framework — Caliber registra placas y materiales de armadura, Coagulant registra ítems médicos craftables. Es el mismo "Cargo posee el cómo, el dueño posee el qué" del contrato de ítems, aplicado al banco: no es un patrón nuevo.

---

## 2. Estructura de pestañas

Cuatro pestañas, spec de GAMMA con una corrección: la guía de referencia tiene Craft, Repair, Upgrades **y Desarme** — el desarme no es opcional, es la fuente de componentes de todo el sistema. Sin él, craftear no tiene origen económico.

| Pestaña | Función | Estado |
|---|---|---|
| **Craft** | Categorías → recetas bloqueadas por conocimiento → componentes → resultado | Cerrado |
| **Reparación** | Reemplazo de partes por zona, sin consumo de cargas | Cerrado |
| **Desarme** | Ítem → componentes, condición heredada por zona | Cerrado |
| **Upgrades** | Mejoras a armaduras/accesorios (armas: bandera de riesgo) | Pendiente |

Layout: listas de categorías y recetas en columnas verticales con scroll (las capturas de referencia lo muestran así; UI real usa sliders verticales para ambas listas).

---

## 3. Craft

- **Categorías** (columna izquierda): dispositivos, toolkits, médico, munición, partes, etc. — extensible por módulo dueño.
- **Recetas** (columna central): grid de íconos, bloqueadas hasta que el jugador tenga el conocimiento correspondiente.
- **Conocimiento**: se desbloquea leyendo documentos, manuales o libretas encontrados en el mundo — evento raro, se persiste una vez por jugador (§9).
- **Componentes** (columna derecha): cadena have/need por componente, cada uno con contador en vivo contra el inventario del jugador.
- **Toolkit requerido**: por tier (básico/avanzado). **Craftear consume 1 carga del toolkit.**
- **Resultado**: preview del ítem final + botón de confirmación.

```lua
-- Firma ilustrativa de registro de receta
Workbench.Craft.RegisterRecipe({
    id = "corpus_caliber_advanced_toolkit",
    category = "toolkits",
    knowledgeRequired = "manual_advanced_tools",
    components = { {id = "multitool", count = 1}, {id = "scrap_metal", count = 1} },
    toolTier = "basic",
    result = {id = "corpus_caliber_advanced_toolkit", count = 1},
})
```

---

## 4. Reparación

Adaptado del spec de GAMMA (que repara el ítem completo) al modelo de condición por zona ya cerrado en Cargo:

- Selección de ítem reparable desde el inventario.
- Condición mostrada **por zona** (torso, estómago, brazos, piernas en una armadura).
- Cada zona dañada acepta una **parte de reemplazo** (material Caliber) asignada individualmente.
- **CRG-54 — Regla de tope**: la condición de la parte asignada define el tope restaurado en esa zona — una parte al 94% no deja la zona al 100%. Mantiene demanda de partes de calidad y le da sentido al desarme selectivo (§5).
- **Reemplazar partes no consume cargas del toolkit** — solo requiere que el toolkit correspondiente esté presente. Asimetría deliberada frente a Craft: es la mitad de **CRG-53** (§7).
- **Zonas rotas se reparan aquí**, a diferencia de las placas (mecánica de campo, ver `Cargo_Architecture.md` §4), que solo restauran zonas placables (torso/estómago) y no reparan una zona ya rota. Dos dominios de reparación sin solapamiento: banco = mantenimiento profundo, placa = parche rápido de campo.

---

## 5. Desarme

Diseño nuevo (no está en el spec de GAMMA con este nivel de detalle). Tres reglas gobiernan todo el sistema:

### 5.1 Tabla explícita, no inversión automática

**CRG-50 —** Cada ítem declara opcionalmente su tabla de rendimiento de desarme en su definición; el módulo dueño la define. Invertir la receta de crafteo automáticamente rompe el balance (craftear consume un multitool entero; desarmar el resultado no debería devolverlo intacto). Ítems sin tabla declarada no son desarmables.

```lua
-- Firma ilustrativa
Workbench.Disassembly.RegisterYield(itemId, {
    { zone = "torso", componentId = "ballistic_fabric", count = 1 },
    { zone = "stomach", componentId = "ballistic_fabric", count = 1 },
    { zone = "arms", componentId = nil },  -- zona rota: sin rendimiento
    { common = true, componentId = "straps_buckles", count = 2 },
})
```

### 5.2 Herencia de condición

**CRG-51 —** Fórmula única que gobierna todo el sistema:

```
condición_de_parte = condición_de_zona × tasa_de_herramienta
```

Desarmar un ítem entrega componentes **por zona**, cada uno con la condición de su zona de origen multiplicada por la tasa de la herramienta usada. Una zona rota no entrega nada. Consecuencia emergente sin lógica adicional: armadura destrozada da partes mediocres al desarmarse; equipo prístino vale tanto puesto como desarmado. Determinístico — el jugador ve el preview exacto antes de confirmar.

### 5.3 Herramienta: tasa, no acceso

**CRG-52 —** Toda herramienta de corte puede desarmar cualquier ítem con tabla — no hay bloqueo de categoría por herramienta. La diferencia es la **tasa de recuperación**:

| Herramienta | Tasa | Efecto sobre la herramienta |
|---|---|---|
| Cuchillo | ~60% | desgasta condición (~-2%) |
| Multitool | ~80% | desgasta condición (~-2%) |
| Toolkit avanzado | 100% | desgasta condición (~-2%) |

### 5.4 Protecciones obligatorias para ítems únicos

- **Eyección antes de destruir** (cita **CRG-9**, sede [`Cargo_Architecture.md`](Cargo_Architecture.md) §4): sub-slots ocupados (placas, accesorios) se devuelven al inventario, nunca se consumen en el desarme. El desarme es un flujo destructivo más — la norma ya existe y acá solo se aplica.
- **Confirmación explícita**: desarmar un ítem único destruye la instancia sin undo — la UI exige confirmación separada del botón de acción.

---

## 6. Upgrades (pendiente)

Sin diseño cerrado, pero con la bandera de riesgo **parcialmente resuelta** y el spec de referencia levantado de la guía GAMMA:

**Canal ARC9 identificado** (cita **CRG-23**, sede [`Cargo_Architecture.md`](Cargo_Architecture.md) §10.3): el principio lectura-only aplica a los stats (`GetProcessedValue`); la API de attach/detach de ARC9 es el canal de escritura legítimo — es lo que usa el propio menú de customización de ARC9. Los upgrades de arma pueden modelarse como **attachments nativos ARC9** (los stats cambian porque ARC9 procesa sus propios attachments, no porque Corpus escriba valores). Ver `Cargo_Architecture.md` §10.3, incluida la regla de reconciliación. La API ya se verificó contra el código vivo (base ARC9 + pack EFT de Darsu, 2026-07-10, anotada en el header de `corpus_cargo_arc9.lua`) y el puente está en producción: lo que falta acá es el **diseño del árbol**, no la verificación.

**Mecánicas de GAMMA a copiar cuando este bloque abra** (levantadas de la guía de referencia):

- Upgrade consume el **kit de upgrade** (tiered, codificado por color/flechas); requiere el repair kit del tipo correspondiente **presente pero sin consumir cargas** — consistente con la asimetría de §7.
- Árbol de upgrades por **tiers con ramas mutuamente excluyentes** (elegir una rama del tier bloquea la hermana).
- **Desarmar equipo mejorado devuelve el kit de upgrade** — en GAMMA es probabilístico; en nuestro sistema determinístico (§5.2) la regla candidata es devolverlo sujeto a la tasa de herramienta. Decidir al cerrar el bloque.
- Territorio seguro sin dependencia de ARC9: **armaduras y accesorios**, dominio propio de Cargo/Caliber.

---

## 7. Economía de toolkits

**CRG-53 —** Tres operaciones, tres comportamientos distintos frente al toolkit — la asimetría es intencional y es lo que le da identidad a cada pestaña:

| Operación | Consumo de toolkit |
|---|---|
| Craft | consume 1 carga |
| Reparación | no consume carga, solo requiere presencia |
| Desarme | no consume carga del toolkit; desgasta la *herramienta de corte* usada (~-2% condición) |
| Upgrade (pendiente) | previsiblemente consume el kit de upgrade específico, no cargas genéricas |

---

## 8. Registro: patrón de módulo dueño

Igual que el contrato de ítems de Cargo (cita **CRG-1**): el banco es framework, el contenido es de cada módulo.

- **Cargo owns**: UI de las cuatro pestañas, motor de recetas/componentes, motor de desarme con herencia de condición, economía de toolkits.
- **Caliber owns**: recetas y materiales de armadura/armas, tabla de placas.
- **Coagulant owns**: recetas de ítems médicos craftables.
- Ningún módulo de dominio necesita el banco para funcionar — lo aprovecha si Cargo está presente, igual que el resto del ecosistema.

---

## 9. Persistencia

Vía `Corpus.Data`, namespace `cargo` (aplica **CRG-43**, que a su vez aplica **COR-3**; ojo con el remedio a **COR-8**: el round-trip JSON no preserva tipos de clave). Conocimiento de recetas: un archivo por jugador (indexado por SteamID64) con el set de IDs de receta desbloqueados — se escribe solo al leer un manual/documento nuevo, se carga una vez al spawn. Sin necesidad de SQLite ni motor relacional: no hay consultas cruzadas ni volumen que lo justifique (ver discusión de persistencia en sesión de diseño).

---

## 10. Estado de este documento

Craft, Reparación y Desarme cerrados y validados en sesión de diseño (Opus) — ratificado por el autor antes de este volcado a documento (Sonnet). Upgrades queda pendiente, con la bandera de riesgo ARC9 registrada en §6 para que no se pierda en la siguiente sesión de diseño.

| Sección | Estado |
|---|---|
| Estructura de 4 pestañas | **Cerrado** |
| Craft (categorías, recetas, componentes, toolkit) | **Cerrado** |
| Reparación (por zona, tope por calidad de parte, sin consumo de carga) | **Cerrado** |
| Desarme (tabla explícita, herencia de condición, tasa por herramienta, eyección) | **Cerrado** |
| Upgrades | Pendiente — canal ARC9 identificado (attachments nativos, ver §6) y su API ya verificada contra el código vivo (2026-07-10, puente en producción); falta **solo el diseño del árbol** |
