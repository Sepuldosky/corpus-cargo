# Cargo — Comercio (Arquitectura)

> **Uso de este documento:** Referencia autocontenida para sesiones futuras de
> planificación (Claude Opus) e implementación (Claude Code). No se requiere el
> chat de diseño original.
>
> **Estado:** Bloque de diseño cerrado (sesión Opus, ratificado por el autor
> 2026-07-11). Subsistema propio desprendido de Cargo — mismo patrón que
> `Workbench_Arquitectura.md`. Sale del bloque "UI fullscreen estilo STALKER"
> (roadmap Cargo #3) porque introduce el **primitivo inventario-en-entidad**, que
> se reusa para lootear cadáveres (cruce a Cortex) y no es solo inventario de
> jugador.
>
> **Dependencia dura:** Corpus. **Soft:** provider de dinero (§6 de
> `Cargo_Architecture.md`, USD nativo o DarkRP), provider de facción/rango (Cortex,
> para el header del trader). **Depende de:** el rediseño de UI fullscreen (§15 de
> `Cargo_Architecture.md`) — la columna izquierda es donde vive el trader; y del
> sistema de imágenes (`Cargo_ItemImages_Arquitectura.md`) para los íconos del stock.

---

## Índice

1. [Visión general](#1-visión-general)
2. [Primitivo: inventario-en-entidad](#2-primitivo-inventario-en-entidad)
3. [Transacción basket con confirm](#3-transacción-basket-con-confirm)
4. [Precio: value × condición × spread](#4-precio-value--condición--spread)
5. [Configuración de spread](#5-configuración-de-spread)
6. [Jugador-trader y doble confirm](#6-jugador-trader-y-doble-confirm)
7. [Dinero: entidad, botar y traspaso P2P](#7-dinero-entidad-botar-y-traspaso-p2p)
8. [Layout](#8-layout)
9. [Cruce con loot de cadáveres (Cortex)](#9-cruce-con-loot-de-cadáveres-cortex)
10. [NPC trader de ejemplo](#10-npc-trader-de-ejemplo)
11. [Fronteras y pendientes declarados](#11-fronteras-y-pendientes-declarados)
12. [Estado del documento](#12-estado-del-documento)

---

## 1. Visión general

Cierra el comercio de STALKER GAMMA: el jugador abre un trader (NPC o jugador),
mueve ítems a un **basket** de compra/venta, ajusta con dinero directo si hace
falta, y **confirma** una transacción atómica. Reutiliza el mismo grid de gradas y
la misma columna contextual que loot (§15 de `Cargo_Architecture.md`) — no es una
pantalla nueva, es el estado "trade" del inventario fullscreen.

Alcance funcional **nuevo** respecto de Block 1 (esto no es solo forma): campo de
precio en el def, spread configurable, el primitivo de inventario colgado de una
entidad, y el dinero como entidad del mundo.

---

## 2. Primitivo: inventario-en-entidad

**El primitivo central del bloque.** Un inventario deja de estar atado solo a un
SteamID64: puede colgar de una **entidad**. Un trader NPC es una entidad con un
record de inventario (su stock); un contenedor en mundo (§8 de
`Cargo_Architecture.md`) ya es un caso de esto; un cadáver será otro (§9).

- Mismo schema de inventario que el del jugador (slots + stacks + blobs de
  instancia, §3 de `Cargo_Architecture.md`). No se inventa un formato nuevo.
- Persistencia vía `Corpus.Data`, keyed por un id de entidad estable (no por
  SteamID). Traders persistentes conservan stock entre sesiones; efímeros (cadáver,
  caja de campo) pueden no persistir — decisión por entidad, igual que la capacidad
  de contenedor.
- **Autoritativo en servidor.** El cliente ve un snapshot del inventario de la
  entidad mientras la sesión de trade/loot está abierta; toda mutación pasa por el
  servidor (evita el festival de duplicación).

Diseñar este primitivo **genérico desde ya** paga triple: trader, contenedor y
cadáver son el mismo mecanismo.

---

## 3. Transacción basket con confirm

*(Decisión del autor 2026-07-11: basket con confirm, no transacción inmediata por
ítem.)* Patrón GAMMA puro.

### Flujo

1. Mover un ítem del inventario propio al lado **Sell** (o del stock al lado
   **Buy**) lo agrega al **basket** — no ejecuta nada todavía. Cantidad por click
   (enmienda 2026-07-14, CHANGELOG #22; **re-votada por el autor el 2026-08-19**,
   CHANGELOG #70 / roadmap #67): **click = 25% del `max_stack`**,
   **SHIFT+click = EL STACK CLICADO** (lo que esa celda dice: 120 en una llena, 80
   en la del resto), **ALT+SHIFT+click = todo**, **click derecho = cantidad
   exacta**. SHIFT cargaba *todo* y eso convertía un cargador en la reserva entera.
   Una línea de stack sigue siendo un **agregado** sobre todas las entries del mismo
   `id + condición` (`max_stack` parte un pilón en varias) — el ítem lógico, no la
   celda —, y ese agregado sigue siendo el **techo** de la línea: es lo que mantiene
   alcanzable al stack gemelo, que es para lo que nació el 2026-07-14. Lo que cambió
   no es el agregado: es qué tecla lo pide. Se puede, porque **dos entries del mismo
   `id` y `condición` son fungibles** y lo que un clic nombra es una *cantidad*, no
   una celda (CRG-72). **Y eso sigue valiendo ACÁ y sólo acá:** desde el 2026-08-19 un
   ref de stack **sí** puede nombrar una celda (`cid`, **CRG-73** — roadmap #68), pero
   el basket lo ignora a propósito. `Trade.RefKey` y `MatchesRef` agrupan por
   `id + condición` y nada más, con dos controles negativos en el harness que lo
   sostienen: si el basket empezara a nombrar la celda, una compra de 800 balas se
   partiría en siete líneas y el techo dejaría de ser uno.
2. El ítem en basket queda **marcado visualmente** (borde ámbar + contador de unidades
   pendientes en la celda). **El lock NO está implementado (slice 1):** el basket es
   *intent puro del cliente* —el servidor no guarda estado de basket— y el ítem sigue
   siendo usable y equipable mientras pende (el frame deja el teclado al juego: F1-F4 y
   1-7 siguen vivas; la columna de equipo acepta drops en estado Trade). Botarlo **no es
   directo**: en estado Trade el click derecho del grid propio abre `Trade.AmountMenu`, no
   `OpenItemMenu`, así que no hay opción Drop en la celda — hay que equiparlo primero y usar
   el Drop del slot.
   La defensa **no es un lock sino la re-resolución**: `PruneBasket` (cliente) descarta o
   recorta cada línea rancia en cada sync, y en `Confirm` el servidor re-resuelve cada ref
   contra el inventario real, recorta el count a lo disponible y **aborta la transacción
   entera** si la ref ya no existe. El lock pasa a ser **requisito** recién con el
   jugador-trader (§6), donde deja de ser conveniencia: ahí sí hay un segundo jugador al
   que estafar.
3. Los strips **Buy** y **Sell** acumulan el total de cada lado; el footer muestra
   el **neto** de la transacción (`+/− dinero`).
4. **Confirm** valida y ejecuta **atómico**. **Cancel** vacía el basket — nada se había
   movido.

### Validación atómica (en Confirm, servidor)

**CRG-18 —** Todo o nada, en un solo paso:

- **Dinero suficiente:** el neto no deja el wallet en negativo (provider, §6 de
  `Cargo_Architecture.md`).
- ~~**Peso resultante:** lo que el jugador se lleva no excede su capacidad.~~
  **CRG-19 — La compra transfiere con `skipCap`: el peso no valida una transacción**
  (enmienda 2026-07-14 — decisión del autor, 1.ª pasada en juego del slice 1,
  CHANGELOG #21; reformulado en positivo el 2026-07-19). Comprar es un acto deliberado
  y negarle el trato al jugador porque saldría sobrecargado convierte al trader en una
  niñera. **Puede comprar por encima de su capacidad y salir sobrecargado**, y la curva
  de peso (§5 de `Cargo_Architecture.md`) ya se lo cobra en velocidad. El límite de carga
  sigue vigente **para lo que se recoge del suelo** (CRG-13).
- **Stock/propiedad:** el trader todavía tiene lo que se le compra; el jugador
  todavía tiene lo que vende (relevante en multiplayer / jugador-trader).

Si cualquier validación falla → **no se movió nada** (no hay rollback porque no hay nada
que revertir: `Confirm` valida todo y **recién después** muta), basket intacto, mensaje de
qué faltó (voz de interfaz: "Not enough money: you're $340 short", no un error genérico).
Si pasa → mover ítems, ajustar wallets de ambos lados, vaciar basket.

### Protocolo de net

Un solo mensaje de Confirm con las **listas** de ambos lados (ids de instancia +
counts) + el ajuste de dinero. No un mensaje por ítem. El servidor recomputa el
precio del lado del servidor (nunca confía en el total que manda el cliente) y
valida. Barato aunque el basket sea grande.

---

## 4. Precio: value × condición × spread

Precio de un ítem = **`def.value`** (precio base, campo nuevo en la definición del
ítem) **× multiplicador de condición × spread del trader**.

- **`def.value`** — precio base de referencia del ítem, en la moneda del provider
  activo (§6 de `Cargo_Architecture.md`). Campo nuevo; **CRG-20:** ítems sin `value` no son
  comerciables (no aparecen con precio).
- **Multiplicador de condición** — un arma al 41% vale menos que una al 100%. Curva
  simple sobre la condición del blob (§3 de `Cargo_Architecture.md`). Ítems
  stackeables sin condición usan 1.0.
- **Spread del trader** — el trader **compra barato y vende caro**. Dos factores:
  `buy_mult` (lo que paga al jugador, ej. 0.5 = mitad del value) y `sell_mult` (lo
  que cobra al jugador, ej. 1.0 = value completo). Configurable (§5).

El servidor es la autoridad del precio (§3, protocolo de net).

---

## 5. Configuración de spread

*(Decisión del autor 2026-07-11: número configurable, con definiciones por NPC y por
jugador — para jugadores que quieran ser traders.)*

- **Por NPC trader:** `buy_mult` / `sell_mult` en la definición de la entidad trader
  (§10). Un trader tacaño compra al 0.4; uno generoso al 0.6.
- **Por jugador-trader:** el mismo par de multiplicadores configurable por el jugador
  que monta tienda (§6). Así el dinero gana funcionalidad real: un jugador puede vivir
  de comprar barato y vender caro a otros.
- **Default global:** un `buy_mult` / `sell_mult` de fallback (ej. 0.5 / 1.0) cuando
  la entidad no declara los suyos.

---

## 6. Jugador-trader y doble confirm

Un jugador puede ser trader de otro. Esto **cambia el modelo de confianza** respecto
del trader NPC y hay que diseñarlo con cuidado:

- **Ambos inventarios están vivos** durante la sesión (no un stock estático). La
  columna izquierda del que abre la sesión muestra el inventario del otro jugador.
- **Doble confirm obligatorio:** los dos lados arman su basket y **ambos deben
  aceptar** antes de ejecutar. Sin esto es festival de estafas (uno confirma, el otro
  quita cosas). El lock del basket (§3, **no implementado en slice 1**) deja de ser
  conveniencia y pasa a ser **requisito**: mientras un lado revisa, lo ofertado por el
  otro no puede cambiar.
- **Ejecución atómica de ambos lados:** la validación de §3 corre para los dos
  jugadores (dinero y existencia de cada uno — el peso no valida, ver §3) antes de
  mover nada. Falla de un lado → **no se mueve nada**, en ninguno de los dos (no hay
  rollback: se valida todo y recién después se muta).
- Estado de la sesión: `A propone → B propone → A acepta → B acepta → ejecuta`. Si
  cualquiera modifica su basket después de aceptar, se **resetean las aceptaciones**
  (nadie acepta a ciegas un basket que cambió).

El traspaso directo de dinero (§7) es el caso degenerado de esto: una sesión de trade
con basket de solo-dinero de un lado.

---

## 7. Dinero: entidad, botar y traspaso P2P

*(Decisión del autor 2026-07-11: botón de dinero + botar/entregar dinero directo.)*

Consecuencia de diseño: **"botar" dinero exige que el efectivo exista como entidad del
mundo**, porque hoy el dinero es solo un número del provider (§6 de
`Cargo_Architecture.md`). Se introduce una **entidad de dinero** con un monto.

- **Entidad cash:** entidad del mundo con un `amount`. Recogible (mismo flujo de
  pickup que un ítem). Peso **cero** en v1.
- **Botón de dinero** (§15.3 de `Cargo_Architecture.md`), según estado:
  - **Solo:** prompt de monto → resta del wallet → spawnea la entidad cash con ese
    monto frente al jugador. Recogerla lo suma de vuelta al wallet de quien la
    recoja.
  - **Trade:** agrega el monto como **línea de solo-dinero al basket** de tu lado.
    Entregar dinero sin ningún objeto, o cuadrar un trueque desigual.
- **Traspaso P2P:** **no es un mecanismo aparte** — es una sesión de trade (§6) con
  basket de solo-dinero de un lado y nada del otro. Un solo mecanismo cubre trueque,
  entrega de dinero y pago; no se construye una vía de transferencia separada.

Regla anti-abuso: el monto a botar / ofertar se valida contra el wallet en el
servidor en el momento de ejecutar (no al escribir el número), igual que el resto de
la transacción.

---

## 8. Layout

Reutiliza el estado "trade" del inventario fullscreen (§15.1 de
`Cargo_Architecture.md`):

- **Columna izquierda:** stock del trader (NPC) o inventario del otro jugador
  (jugador-trader). Header con identidad/facción/dinero del trader. Strip **Buy** con
  su total.
- **Columna derecha:** inventario propio, con **precio de venta** visible en cada ítem
  comerciable (no aparece en los estados solo/loot). Strip **Sell** con su total.
- **Footer:** neto de la transacción + **Cancel / Confirm** (doble confirm en
  jugador-trader, §6).
- Ítems en basket marcados (borde ámbar). Fuente de verdad de layout: el mock
  `cargo_fullscreen_ui_mock_v1.html`, estado trade.

---

## 9. Cruce con loot de cadáveres (Cortex)

El primitivo de §2 es exactamente lo que necesita el loot de cadáveres, que es un
cruce con Cortex (dueño del NPC). Se **declara ahora** para diseñar §2 genérico, se
resuelve cuando el bloque dueño cierre:

- Un cadáver (NPC muerto, o jugador) es una **entidad con inventario** (§2) — su
  loadout + lo que llevaba. Abrirlo es el estado "loot" (§15.1 de
  `Cargo_Architecture.md`), no "trade": sin precios, con Take all.
- **Frontera (voto del autor, 2026-07-19):** *qué* deja caer un NPC al morir es
  semántica de Cortex/Caliber (loot table, muerte). El **cadáver looteable es un
  contenedor de Cargo** (CRG-21: contenedor, trader y cadáver son el mismo
  primitivo) y su **GC — *cuándo* se limpia un cadáver looteado — es de CARGO**:
  mantiene el loot agnóstico al diseño de Cortex (que queda como capa de IA sobre
  la base de NPC) y el dueño del primitivo de inventario-en-entidad es quien ya
  reacciona vía `CallOnRemove`. *Cómo se ve y se transfiere ese inventario* también
  es de Cargo. La loot table se cierra al diseñar el bloque dueño — regla del flujo
  (dueño se decide en diseño).
- Enlaza con el pendiente de "loot on death" del roadmap Cargo #15. Lo que queda
  pendiente ahí es **cuándo** se limpia un cadáver looteado, no un GC de blobs: desde
  CHANGELOG #41 el blob no tiene archivo propio (CRG-56) y la clase "instancia huérfana"
  dejó de existir.

---

## 10. NPC trader de ejemplo

Para probar el subsistema sin esperar a Cortex, un **NPC trader de ejemplo**
(`corpus_cargo_trader`, entidad spawnable):

- Entidad con inventario (§2) poblado con stock demo (armas, munición, médico,
  armadura — como el mock).
- `buy_mult` / `sell_mult` propios (§5).
- Interactuar (mirar + use) abre el estado trade (§15.1 de `Cargo_Architecture.md`).
- Sirve de dos cosas a la vez: valida el comercio **y** valida el primitivo
  inventario-en-entidad, que es lo que después habilita traders reales de Cortex y
  loot de cadáveres.

Header del trader: usa el provider de facción de Cortex si está montado (el NPC
reporta su facción/rango); degradación honesta a "Trader" genérico si no.

---

## 11. Fronteras y pendientes declarados

| Pendiente | Dueño futuro | Nota |
|---|---|---|
| Loot table de NPC (qué dropea al morir) | Cortex / Caliber | Cargo provee el inventario-en-entidad y la UI de loot; el contenido y la muerte son del dueño (§9) |
| GC de cadáveres looteados | Cargo | **Cuándo** se limpia un cadáver ya looteado (enlaza roadmap #15; adjudicado en `Cortex_ContratosEntrantes.md` §3.2 — el dueño del primitivo inventario-en-entidad es quien ya reacciona vía `CallOnRemove`). El GC de blobs NO es parte: la clase "instancia huérfana" murió con CRG-56 |
| Persistencia de traders NPC reales | Cortex | El primitivo persiste; qué traders existen y su stock inicial es de Cortex |
| Gate de admin del spawn del trader de ejemplo | Cargo | Mismo TODO que el resto de comandos dev — espera primitiva de permisos (roadmap #12) |
| Economía balanceada (values reales de los ítems) | Cargo (contenido) | `def.value` existe como campo; los números se calibran en juego |
| Impuesto / comisión de jugador-trader | — | Fuera de alcance v1; el spread por-jugador ya da la palanca económica |

---

## 12.bis Estado de implementación (se actualiza por slice)

El bloque se implementa en **3 vertical slices** (corte validado con el autor
2026-07-13). Diseño intacto: lo de abajo dice qué de este documento ya es código.

| Slice | Alcance | Estado |
|---|---|---|
| **1 — comercio con NPC** | `def.value` + curva de condición + spread (§4/§5), trader = contenedor + capa de precio (§2), entidad `corpus_cargo_trader` con stock demo (§10), estado **Trade** del frame (§8), **basket con confirm atómico** (§3) | **CHANGELOG #20 — APLICADO 2026-07-14** (+ enmiendas de las pasadas: **#21**, el peso deja de ser gate de la transacción; **#22**, la línea del basket es un agregado sobre todos los stacks del ítem y el **click carga 25% del `max_stack`**, SHIFT+click todo, click derecho cantidad exacta) |
| **2 — dinero como entidad** | entidad cash, botón $ en Solo (botar) y en Trade (línea de solo-dinero) (§7) | pendiente |
| **3 — jugador-trader** | sesión P2P, doble confirm, máquina de estados, spread por-jugador, traspaso P2P (§6/§7) | pendiente |

**Decisión de implementación (slice 1):** §2 pedía un primitivo genérico de
inventario-en-entidad. **Ya existía**: `Containers.Attach` (§8 de
`Cargo_Architecture.md`) — items en la entidad, capacidad, persistencia por
clave, derrame al removerse. El trader **es** ese contenedor con `buy_mult`,
`sell_mult` y wallet encima; **CRG-22:** el net de transferencia del contenedor
**deliberadamente no se cablea** a un trader: nada cruza salvo por `Confirm`.
Cuando Cortex traiga traders reales o cadáveres looteables, hereda un único
primitivo, no dos.

**Deuda declarada del slice 1:** los `value` (tabla `weapon_prices` + defs) son
números de arranque, a calibrar en juego (§11 ya lo declaraba); el trader demo es
de sesión (no persiste entre mapas, a propósito); el cliente formatea el dinero
con el shape del provider nativo USD (un provider externo con otro formato solo
afecta la decoración de las etiquetas, no los números); y **el lock del basket (§3)
no existe** — el ítem pendiente sigue siendo usable y equipable (botarlo no es directo:
el click derecho del grid propio abre el menú de cantidad, no el de ítem), y lo que
sostiene la transacción es la re-resolución en `Confirm`, no un candado. Aceptable
contra un NPC (el único que puede sabotearse el trato es el propio jugador);
**obligatorio en el slice 3** (§6), donde hay un segundo jugador al que estafar.

---

## 12. Estado del documento

Bloque de diseño cerrado en sesión (Opus) y ratificado por el autor antes de este
volcado (Sonnet). Sale del bloque de UI fullscreen (roadmap #3); desprendido a doc
propio por traer el primitivo inventario-en-entidad (reusado en loot).

| Sección | Estado |
|---|---|
| Inventario-en-entidad, basket con confirm, precio/spread, dinero/entidad/P2P, layout | **Cerrado — este documento** |
| Jugador-trader y doble confirm | **Cerrado en diseño** — máquina de estados a afinar en implementación |
| Loot de cadáveres (Cortex) | Pendiente — se cierra al diseñar el bloque dueño (§9) |
| Values económicos reales | Pendiente — calibración empírica en juego |
