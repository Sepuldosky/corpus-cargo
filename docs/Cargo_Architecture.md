# Cargo — Documento de Arquitectura

> **Uso de este documento:** Referencia autocontenida para sesiones futuras de planificación (Claude Opus) e implementación (Claude Code). No se requiere el chat de diseño original.
>
> **Estado:** Block 1 de Cargo (ver §13). Cubre el inventario de jugador: contrato de ítems, slots y sub-slots, peso, providers de dinero/facción, grid de UI, contenedores en mundo, inspección y stat-bars. El banco de trabajo (crafteo, reparación, desarme, upgrades) es un subsistema propio, documentado aparte en [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md) — mismo patrón de desprendimiento que ya usó Caliber con Scavenger. El comercio (trueque, basket, dinero, trader) es otro subsistema desprendido — [`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) — porque trae el primitivo de inventario-en-entidad, reusado para lootear cadáveres.
>
> **Dependencia dura:** Corpus. **Soft-deps SALIENTES (Cargo consulta con lazy-check + `pcall`; ver §1):** Cortex (`GetFactionInfo` — facción/rango, arista anticipatoria) y Coagulant (`OnEncumbrance` — drenaje de stamina por sobrepeso, arista viva en ambos extremos). Son las únicas dos: no existe ninguna otra consulta de Cargo hacia un peer.
> **Consumidores ENTRANTES (registran CONTRA Cargo; Cargo no los detecta ni los nombra en su código — CRG-44):** Coagulant (la barra de sangre del panel — **una sola**; la vida la pinta su silueta propia, ver §11), Craving (hambre/sed — cita **CRV-13**, `corpus-craving/docs/Craving_Architecture.md` §1), Caliber (protección de armadura y escudos vía sub-slot Body, Block 3, aún no existe). La barra la registra siempre el **módulo dueño**; si el dueño no está montado, la barra simplemente no se registra (§11, CRG-44).

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
17. [Wheel menu (menú radial de armas)](#17-wheel-menu-menú-radial-de-armas)

---

## 1. Visión general

**Cargo** es el framework de inventario de jugador de Corpus: contrato de ítems, grid de UI, peso, slots de equipamiento y contenedores. Es sobre todo un **hub de consumo**: Coagulant, Craving y Caliber registran sus propios ítems contra el framework que Cargo expone. Cargo posee el "cómo se ve y se guarda un ítem"; cada módulo dueño posee el "qué hace".

Pero **no es hoja** en el grafo de dependencias: Cargo también consume hacia afuera. Dos aristas salen de acá, ambas con lazy-check + `pcall` y **degradación honesta** (nunca crash, nunca asunción — §6 de [`CORPUS_Architecture.md`](../../corpus/docs/CORPUS_Architecture.md)):

- **Coagulant** → `OnEncumbrance(ply, fraction)`, en `corpus_cargo_movement.lua`. Arista **viva en ambos extremos**: el contrato está congelado y Coagulant ya lo implementa. Sin Coagulant, la penalización de sobrepeso se queda solo en velocidad.
- **Cortex** → `GetFactionInfo(ply)`, en `corpus_cargo_inventory.lua`. Arista **anticipatoria**: el call-site existe, Cortex todavía no tiene código. Sin él, el header del inventario simplemente omite facción/rango.

Modelo de referencia: **grid estilo STALKER/GAMMA**, no Tetris estilo EFT. Los ítems se auto-ordenan por categoría, **sin gestión espacial ni rotación**; el costo de cargar más no es espacial, es de **peso**. Decisión explícita: define el modelo de datos completo del módulo (ítems sin ocupación espacial), abarata la net-sync y fija la UX de transferencia con contenedores.

> **Enmienda 2026-07-11 (bloque UI fullscreen) — ver §7 y §15.** El grid deja de ser **uniforme**: «cada ítem ocupa una celda» pasa a «cada ítem pinta `w × h` celdas según su **footprint**» (`Cargo_ItemImages_Arquitectura.md` §5; set permitido y techos/pisos por categoría en `corpus_cargo_items.lua`). El footprint es solo **render**: el modelo de datos NO cambia.

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

Todo ítem registrado contra Cargo cae en una de dos clases. La clase se declara en la definición del ítem y determina si el ítem tiene **uid y blob de instancia propios**. No determina si lleva condición: un stackeable con `has_condition` la lleva en la propia entry del stack.

| Clase | Ejemplos | Persistencia | Stackea |
|---|---|---|---|
| **Stackeable** | munición, comida, componentes de crafteo, placas de armadura | entry `{id, count, condition?}` — sin blob ni uid; `condition` existe cuando el def declara `has_condition`, y **el stack se parte por condición** (mezclar desgastes sería una reparación gratis) | Sí, solo con condición idéntica |
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

> **Registro en ambos realms (cita COR-12; sede: `../../corpus/docs/CORPUS_Architecture.md` §5).** La def **y** su `onUse` se registran en **shared** — el `onUse` solo *corre* en server, pero la UI client-side exige `isfunction(def.onUse)` para pintar el botón de uso. Registrar la def solo en server deja al cliente sin el ítem; registrar el `onUse` solo en server deja el botón muerto. El retorno de `onUse` gobierna el consumo: COR-13.

- **Cargo owns**: schema base (id, peso, icono, clase, categoría, stack), la API de registro, cómo se persiste el blob de instancia, cómo se renderiza en grid y tooltip.
- **El módulo dueño owns**: la semántica — cómo se degrada la condición, qué hace un ítem al usarse, qué contiene su blob de instancia. Caliber decide cómo se rompe la protección de una zona; Cargo solo guarda el número y lo muestra.

> **Sustitución de modelos (entry 34, decisión del autor 2026-07-23).** Un def **sin `model`** es el default honesto de un ítem setting-agnostic: dropea como la cajita de cartón (`models/props_junk/cardboard_box004a.mdl`, último eslabón de la cadena de resolución) y su ícono cae a la letra. `Cargo.Items.SetModel(id, model)` es el punto de extensión con el que un addon de **contenido** re-viste cualquier def sin poseerlo: el override se guarda y se aplica en el acto o cuando el def (re-)registre — orden-independiente entre addons (COR-5) y a prueba de re-registro (autogen/lua refresh) —, y gana sobre el `model` declarado. Un path no montado es inofensivo (`ModelUsable` gatea drop e íconos). Los defs siguen siendo del módulo dueño: solo cambia la piel.

### Lo que un def guarda de un tercero

**CRG-63 — Un identificador POSICIONAL de un tercero (un ordinal de su tabla) no se persiste jamás: se persiste su clave estable y el ordinal se resuelve en el momento de usarlo.** Es CRG-42 en otra superficie —"`SWEP.Slot` no es la señal"— y la regla general es la misma: no guardar un dato que el tercero puede reordenar sin avisar.

Sede acá y no en §13 a propósito: §13 es la tabla de **fronteras y deuda declarada**, y una norma vigente no vive en una lista de pendientes (el mismo argumento que sacó a CRG-45 de un roadmap). Esto es una regla sobre **qué campo lleva un def**, así que su lugar es el contrato de ítems.

El caso que la acuñó (roadmap #47, verificado contra el código vivo del mod — cita CRG-24): las 61 gafas de *[VManip] Neosun's Cooler Nightvision* se identifican en runtime por `ply:GetNWInt("nvg")`, que guarda el **índice** de la tabla global `ArcticNVGs`, no un nombre — y el propio mod construye su índice inverso con `pairs` sobre un array. Un parche que inserte una variante en el medio corre todos los índices posteriores, así que un ordinal persistido es un ítem que un día amanece **siendo otras gafas**. El def lleva el `ShortName` (`def.nvg_shortname`, campo que Cargo **transporta y no interpreta** — CRG-1) y el ordinal se resuelve contra la tabla viva en el instante de escribirlo.

Corolario que el mismo call site paga: **el nombre se valida ANTES**. El mod no valida, y un nombre inexistente baja a `SetNWInt("nvg", nil)`, que es un error de argumento.

### Blob de instancia (ítems únicos)

Cada ítem único persiste un blob propio vía `Corpus.Data`, namespaced por instancia (no por definición — dos TOZ-34 en el mismo inventario tienen historiales independientes). Contenido mínimo genérico: condición (global o por zona, según declare el módulo dueño), sub-slots ocupados (§4), munición bindeada (grupo A/B). Todo lo demás es específico del módulo — Caliber define qué campos lleva la condición por zona de una armadura; Cargo no interpreta ese contenido, solo lo transporta.

---

## 4. Slots de equipamiento y sub-slots

### Slots de primer nivel

| Slot | Contenido | Notas |
|---|---|---|
| Head | Casco **o** una óptica suelta | sub-slot de accesorio (óptica: NVG, gafas) · filtro `"category:helmets,optics"` — *ver "Las dos rutas de una óptica", abajo* |
| Body | Chaleco/armadura | condición por zona (torso, estómago, brazos, piernas) · sub-slot de accesorio (exo/escudo) · slots de placa |
| Back | Mochila | modificador de capacidad de peso |
| Primary / Secondary / Sidearm | Armas | grupo de munición bindeado (A/B) |
| Melee | Arma cuerpo a cuerpo | — |
| Throwable | Lanzable equipado (granada, SLAM) | slot de **stack**, no de instancia — *enmienda 2026-07-13, ver abajo* |
| Accessory 1 / Accessory 2 | Accesorios menores (categoría genérica `accessories`) | slots dedicados, sin sub-slots propios. *Enmienda 2026-07-10: nacieron como "PDA / Detector", renombrados por el autor en la primera pasada en juego — eso es mobiliario STALKER y Corpus es agnóstico de ambientación* |
| Quick slots F1–F4 | Consumibles bindeados | algunos condicionales — ver abajo |

> **Enmienda 2026-07-13 — slot `throwable` (entry 13) + taxonomía de granadas (entry 16, roadmap #32).**
>
> - **Primer slot de stack del equipo.** `rec.equip.throwable` guarda una **entry de stack**
>   `{id, count, condition?}`, no un uid de instancia (todos los consumidores de `rec.equip`
>   ramifican con `istable()`). Categoría `throwables`, give/take del `weapon_class` al
>   equipar/desequipar, badge `×N`, sin barra de condición. La **eyección obligatoria no
>   aplica**: un stack no tiene sub-slots que eyectar.
> - **El `×N` es reserva real.** El stack equipado entra al espejo de §16 (suma en
>   `BeltTotals`) y **se drena primero** al lanzar (slot-primero, después el cinturón);
>   al vaciarse, el slot se vacía y el SWEP se stripea. El give del equip va con `noAmmo`
>   (el default clip caería al pool → éter lavado al cinturón) y el equip/unequip hace
>   `AmmoPool.Push`. La captura ve el stack equipado (`EquippedDefOf`) para no recapturar
>   ni duplicar el give del equip. Detalle del espejo → §16.9.
> - **Taxonomía (#32):** la cara canónica de los tipos HL2 `Grenade`/`slam` es el
>   **lanzable** — `cargo_throw_frag` / `cargo_throw_slam` (categoría `throwables`,
>   registrados en `corpus_cargo_ammo.lua` junto al resto de los tipos manejados); la
>   granada del SMG1 sigue siendo munición de cinturón. Los ids muertos
>   (`cargo_ammo_grenade/slam`, `cargo_dev_frag`, `wpn_weapon_frag/slam`) remapean al
>   cargar records y contenedores vía `CARGO.Ammo.LegacyThrowIds`; el stack legacy del
>   cinturón baja al grid.
> - **Sin tecla propia:** el wheel lo alcanza con el intent wheel-only 8
>   (`CARGO.Slots.WheelSlots`, §17.1). Darle una tecla después es mover la entrada a
>   `Slots.Hotkeys` — extensión, no rediseño.

#### Cómo se deriva el slot de un arma capturada

**CRG-42 — `SWEP.Slot` NO es la señal.** El campo existe en la base de SWEP y parece la respuesta obvia, pero es **inconsistente entre packs**: cada autor lo usa con su propio criterio (o lo hereda sin tocarlo), así que dos rifles de dos packs distintos pueden declarar slots distintos y dos armas de clase distinta pueden declarar el mismo. Derivar de ahí produce un inventario que se ordena de una forma con un pack y de otra con otro.

La señal real es **`SWEP.Class` + `SWEP.SubCategory`**, resueltas **por herencia** (`weapons.Get(class)` ya resuelve la cadena de `SWEP.Base`, así que un pack que define su taxonomía en la base y no en cada arma sigue funcionando). Es el mismo principio que **CRG-41** aplica a la trivia: se le pregunta al SWEP por su propia identidad en vez de catalogar a mano cada arma de cada pack.

> **Sede movida el 2026-07-19** (deuda D-3/D-13). Vivía en `cargo_estado.md` §Qué existe hoy (entry 24) — un doc **volátil de nivel 2** que se reescribe en cada refresh: la norma estaba a un `estado.md` de distancia de desaparecer sin que nadie lo notara. Confirmada en juego en su momento (entry 24).

### Primitivo genérico: sub-slots

**CRG-8 —** Un ítem puede declarar **sub-slots propios**, cada uno con un filtro de categoría. Es el mismo primitivo en los tres casos siguientes — se implementa una vez:

- **Head → sub-slot óptica**: acopla NVG o gafas (compatibilidad con mods externos de visión nocturna, ver §12).
- **Body → sub-slot exo/escudo**: acopla armadura externa o generador de escudo de energía de jugador — punto de acoplamiento físico para Caliber Block 3, sin inventar un sistema nuevo.
- **Body → slots de placa**: 0–N slots según la armadura, cada uno acepta un ítem de `class = "stackable"` y **categoría `plates`** (el filtro del sub-slot es `"category:plates"`, como todo sub-slot — CRG-8) con campo `material` (tabla de materiales Caliber), y con **desgaste propio por unidad** si su def declara `has_condition`: la condición viaja con la unidad al montarla y arranca en 100 si venía de fábrica (`SubSlotAttach`). El eje es la CATEGORÍA, no la clase (§3).

Los quick slots F1–F4 usan el mismo principio en reversa: su **disponibilidad** (no su contenido) depende de un ítem equipado en otro slot — igual que el cinturón de artefactos desbloqueable por upgrade de traje en la referencia STALKER. Un slot F puede estar bloqueado (candado) hasta que el traje equipado lo habilite.

```lua
-- Firma ilustrativa del primitivo de sub-slot
Cargo.Items.DeclareSubSlot(itemDef, {
    id = "optic",
    filter = "category:optics",       -- qué categorías de ítem acepta
    maxItems = 1,
})
```

### Las dos rutas de una óptica (decisión del autor 2026-07-26, roadmap #47)

Unas gafas de visión nocturna entran por **dos** caminos, y los dos usan primitivos que ya existían — **CRG-8 intacto, ni una variante ad-hoc**:

- **Con casco:** montan en el **sub-slot óptica** del casco. Cero código nuevo: es exactamente lo que declara el bloque de arriba.
- **Sin casco:** ocupan **Head directamente**. Cuesta una sola cadena — el filtro del slot pasó de `"category:helmets"` a `"category:helmets,optics"`, y el grammar de `MatchesFilter` ya parseaba listas separadas por coma.

La regla que el jugador percibe es la correcta: *"o el casco con las gafas montadas, o las gafas solas"*. La ruta (A) sola rompía el PVS-14 con montura de cráneo —que el mod modela— y es absurda para unas gafas de sol; la (B) sola obligaba a elegir entre casco y visión nocturna.

**El costo real, y se asume:** un consumidor de esta superficie tiene que escuchar **las dos** señales de abajo, porque las gafas pueden entrar por cualquiera de los dos caminos. Cada ruta se verifica con la otra fuera de juego, o un camino roto pasa desapercibido.

> **Nota:** el campo `equip_slots` sigue disponible para **estrechar** qué slots acepta un def concreto. Si algún día se quisiera que solo ciertas ópticas puedan ir a `accessory1/2`, se resuelve con ese campo y sin tocar nada más.

### Señales de equipamiento

**CRG-62 — Cargo difunde que un slot de equipamiento cambió; la semántica de ese cambio vive en el consumidor, nunca en el inventario.** Es **CRG-1** aplicado al equipamiento: el inventario no sabe qué *significa* que alguien se ponga unas gafas, igual que no sabe qué significa `onUse`.

```lua
hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, defId_or_nil, blob_or_nil)
hook.Run("Corpus_Cargo_SubSlotChanged", ply, hostUid, subId)
```

- `defId` nil = **el slot se vació**. `blob` nil = el valor es una entry de stack (throwable, que no tiene instancia) o el slot se vació.
- `slotId` **nil** = *se re-aplicó el set entero* (`Inventory.RegiveEquipped`): el oyente re-lee todo en vez de diferenciar un slot. **Es la puerta del respawn**, y existe para que un oyente con estado de jugador no tenga que enganchar `PlayerLoadout` y apostar al orden de hooks — el bug que Quick Loadouts ya le costó a este repo.
- La señal se dispara **DESPUÉS** de que el record quedó consistente, nunca en el medio: un oyente que leyera `rec.equip` a mitad de camino vería un estado que no existió.

**Las puertas son CINCO, no cuatro.** El diseño contaba `Equip`, `Unequip`, `SubSlotAttach` y `SubSlotDetach`; el árbol mostró que **`DropEquipped` no pasa por `Unequip`** —manipula `rec.equip` y difunde por su cuenta, que es lo que el `Corpus_Cargo_BodyChanged` existente ya hacía en sus dos salidas— y que el reconciliador de `WeaponDrop` de `corpus_cargo_capture.lua` es donde se vacía el slot al soltar el arma **en la mano**. Una puerta que no difunde es un agujero que se descubre en juego seis meses después.

**`Corpus_Cargo_BodyChanged` no se toca y se sigue disparando.** Su firma es contrato vivo (el lector de disfraz del roadmap #10 cuelga de ella); la señal genérica se dispara **ADEMÁS**, jamás en su lugar.

> **Alternativa descartada, con su razón escrita:** `def.onEquip` / `def.onUnequip` en el contrato de ítem. Es más potente, pero mete una closure por def en un contrato que hoy tiene exactamente una (`onUse`) y obliga a que 61 defs derivados carguen la misma función. Una señal única con un solo oyente es menos superficie por el mismo resultado.

### Eyección obligatoria

**CRG-9 —** Regla dura, aplica en todo flujo que destruye o reemplaza un ítem con sub-slots ocupados (desarme, reemplazo de armadura, muerte con drop): **los sub-slots se eyectan al inventario o al mundo antes de que el contenedor se destruya.** Un generador de escudo o una placa nunca se pierden como efecto colateral de perder el chaleco que los contenía.

**CRG-65 — "No entra" nunca significa "se destruye".** La otra puerta por la que llega el mismo modo de falla que CRG-9 prohíbe, y por eso vive al lado. Cuando un flujo le **entrega** a Cargo un objeto que ya sacó de otra parte —un attachment que ARC9 acaba de desmontar del arma, unas balas que el espejo del pool acaba de restar de la reserva— y `GiveItem` lo rechaza, **el objeto cae al mundo como ítem**; jamás se lo da por entregado y se lo pierde. La ruta única es `Inventory.GiveOrDrop`, que devuelve además **si cayó al piso**, para que el call site pueda decirlo.

La línea, que es lo que hace la norma aplicable (decisión del autor, 2026-07-30, roadmap #53): **rechazar** una acción y avisar es correcto —levantar un arma del suelo sobrecargado sigue contestando *"You can't carry that"* y el arma se queda donde estaba, porque de ahí no se sacó nada—; **consumir** el objeto y avisar es el defecto. Solo la segunda forma pasa por acá. El aviso al jugador no es el remedio: un objeto que ya no existe no deja de no existir porque se haya impreso una línea.

> Los dos sitios que la acuñan la violaban **con un comentario encima afirmando lo contrario** — el puente ARC9 (`ARC9_PlayerGiveAtt` ignoraba el retorno de `GiveItem` y devolvía `true`) y el espejo del pool de munición (`SetAmmo(pool - left)` incondicional, bajo la línea *"The rounds are NOT destroyed"*). De ahí el corolario de verificación: el check que distingue no es "el grid no creció" —eso pasa igual si el objeto se evaporó— sino **el ledger**: el objeto tiene que verse EXISTIENDO en el suelo.

---

## 5. Peso y movimiento

**CRG-11 — Cargo nativo**: curva continua peso → velocidad de movimiento (walkspeed/runspeed). Funciona standalone, sin ningún módulo soft-dep presente — un servidor con solo Cargo montado ya tiene consecuencia real por sobrecarga.

**Coagulant soft-dep**: dueño del recurso de stamina. Si está presente, se suma *encima* de la penalización base: drenaje de stamina por sobrepeso, efectos de fatiga, interacción con vitales. Cargo nunca depende de la stamina de Coagulant para su propia consecuencia — evita degradación deshonesta si Coagulant no está montado.

Capacidad total = base del jugador + bonus de mochila equipada (Back). El footer de peso muestra el desglose (`base + mochila = total`) y colorea según proximidad al límite.

**CRG-66 — Lo que está acoplado a un ítem PESA, y pesa recursivamente.** El peso de una instancia es el de su def **más el de todo lo que lleva montado**, a cualquier profundidad. Sede del cálculo: `Instances.WeightOf`, **una sola recursión** — un tipo nuevo de cosa acoplable se suma ahí, no en una rama propia. Si el módulo que define lo acoplado no está montado, su def no existe y aporta 0: degradación honesta (cita **COR-5**), nunca un peso inventado.

**Alcance VIGENTE hoy: el contenido de los sub-slots** (una placa en el chaleco, unas gafas en el casco), que es lo que pesa desde el Block 1.

> **Enmienda 2026-07-31 (planilla AB, ronda 2) — el árbol de attachments NO pesa todavía, y la norma lo dice en vez de disimularlo.** La primera pasada del #53 lo sumó con el nominal plano de 0,3 kg por att, y **el número no sobrevivió el contacto con una build EFT real**: el MCX 5.56 del autor pesa **2,9 kg** y lleva **doce** attachments — las piezas pesarían más que el arma. No es un problema de calibración sino de modelo: en una build EFT la mayoría de los slots llevan **estructura** (receiver, cañón, guardamanos, tapa, miras de hierro), que *es* el arma y no carga colgada de ella.
>
> Se **difiere** en vez de bajarle el número, porque el arreglo es decidir **qué categorías** pesan —STALKER GAMMA cobra ópticas, silenciadores, lanzagranadas, dispositivos tácticos, foregrips y cargadores ampliados, y **nunca** la estructura— y eso es pasada propia: **roadmap #55**. `Instances.AttsWeight` queda escrita, probada offline y sin llamar desde `WeightOf`: la decisión fue *todavía no*, no *estaba mal*, y es exactamente donde el filtro por categoría se enchufa.
>
> **Caso CERRADO el 2026-07-31 (roadmap #56, entry 65) — la munición cargada en el arma.** Era el «caso declarado y no cubierto» de esta nota: `blob.clip1` es un número pelado que `WeightOf` no miraba, así que cargar un arma hacía **desaparecer peso del ledger** (1,588 kg repartidos en cinco armas del loadout real del autor, medidos por la planilla AC; el «tres kilos del RPG» que esta nota citaba antes era **falso** — ese arma no tiene cargador, ver la corrección en §16.10). Ya pesa, por la misma recursión y como un término aparte del árbol de atts — **CRG-67**, cuya sede es §16.10 porque el problema no era el peso sino la munición: de dónde sale el tipo cuando no hay entidad viva, y a qué ritmo se refresca el número.

> **CRG-12 — Enmienda 2026-07-13 — compat con mods de movimiento (entry 16, roadmap #34).** Un mod
> que re-estampa walk/run **cada tick** desde sus propias convars ("better movement v2":
> su `SetupMove` reescribe `SetWalkSpeed`/`SetRunSpeed`, `sh_bm_main.lua:455-457`) mata las
> bases que la ruta vanilla captura al spawn — la curva deja de morder. La pata de compat
> ([`shared/corpus_cargo_movecompat.lua`](../lua/corpus_cargo/shared/corpus_cargo_movecompat.lua))
> escala el `MaxSpeed` del move data en un hook `Move` propio (corre **después** de
> `SetupMove` en el pipeline de predicción), con el mult que `Movement.Refresh` publica en
> el NW2Float `cargo_speed_mult`; piso absoluto 30 (sobrecargado = lento, nunca inmóvil).
> Es SHARED porque `Move` es predicho: el cliente debe escalar el mismo número o hay
> rubber-banding en multiplayer. No toca al mod ni realimenta su matemática (él relee sus
> convars cada tick). Gates: `cargo_movement_compat` (default 1) y el `sv_bm_enabled` del
> propio mod — sin el mod o apagado, la pata no corre y la ruta vanilla es toda la
> historia: **degradación honesta en ambas direcciones**. Borde cosmético declarado: el
> mod timea sus sonidos de pasos con SU velocidad lerpeada, que nunca ve nuestra escala.

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
- **Filtro por tab**: fila de tabs sobre el grid — **set fijo de 8**, agrupación de display sobre las categorías (§7.1).
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

### 7.1 Tabs de display: set FIJO sobre categorías abiertas (roadmap #23)

**El problema.** El set de **categorías** de ítem es y sigue siendo **abierto**:
`Items.RegisterCategory` auto-registra cualquier categoría que un def mencione, para
que los módulos hermanos (Coagulant, Craving, Cortex) traigan las suyas sin pedir
permiso. La fila de tabs se poblaba **desde ese set**, así que crecía sola: con
"Backpacks" registrada ya hacía **wrap** a una segunda línea.

**La decisión (con el autor, 2026-07-13).** La fila de tabs deja de ser un espejo de
las categorías y pasa a ser una **capa de AGRUPACIÓN de display**, con un set
**fijo y cerrado** de 8 tabs. No es un renombre ni un recorte: las categorías internas
quedan intactas y siguen sirviendo al grammar `"category:a,b"` de slots y sub-slots
(contrato #3) — **CRG-10: el id de un tab jamás es una categoría válida en ese filtro.**

| Tab | Categorías internas que agrupa |
|---|---|
| **All** | (no filtra) |
| **Weapons** | `weapons`, `melee`, `throwables` |
| **Ammo** | `ammo` |
| **Gear** | `helmets`, `armor`, `plates`, `backpacks`, `accessories` |
| **Mods** | `attachments`, `optics` |
| **Meds** | `medical` |
| **Food** | `food` |
| **Misc** | `misc` + **toda categoría no mapeada** (paraguas) |

Reglas de la fila:

- **Se dibuja SIEMPRE entera**, tenga o no ítems: las tabs no se mueven bajo el cursor
  al cambiar el inventario. Una tab sin nada se pinta **atenuada** (sigue filtrando, a
  un grid vacío).
- **CRG-49 — Nunca vuelve a crecer.** Una categoría ajena (`artifacts`, digamos) se auto-registra
  como siempre y su ítem es visible bajo **Misc** y bajo **All**, pero **no acuña tab**.
- Una entrada **sin def** (id desconocido) cae también en Misc — nunca se vuelve
  invisible en todas las tabs menos All.
- Superficie shared: `Items.GetTabs()`, `Items.TabOf(category)`, `Items.MatchesTab(def, tabId)`
  (`corpus_cargo_items.lua`). El grid filtra por **tab**, no por categoría; el orden de
  auto-sort sigue siendo el `order` de la **categoría** (grano fino dentro del tab).

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

**CRG-23 —** Distinción crítica que resuelve parcialmente la bandera de Upgrades: el principio **lectura-only aplica a los stats** (`GetProcessedValue` — nadie escribe valores procesados). Instalar/remover attachments vía la **API propia de ARC9** es el canal de escritura *soportado* — es exactamente lo que hacen el menú de customización de ARC9 y sus entidades de attachment. Los stats cambian como *consecuencia* de que ARC9 procese sus propios attachments, no porque Corpus escriba valores. El contrato se preserva.

**Regla de reconciliación** (el jugador puede seguir usando el menú C de ARC9 directamente):

- El **estado del arma** (qué lleva puesto) es autoritativo en ARC9.
- El **inventario** (qué hay en la mochila) es autoritativo en Cargo.
- Cargo escucha los eventos de attach/detach de ARC9 para reconciliar: si el jugador instala desde el menú C un attachment que estaba en Cargo, Cargo lo descuenta; si desinstala, Cargo lo recibe.
- Decisión de fuente única: el inventario de attachments propio de ARC9 se puentea — Cargo pasa a ser el almacén; ARC9 conserva el estado montado y la matemática de stats. Evita el doble-inventario con drift.

> **Verificado contra el código vivo (2026-07-10):** los nombres exactos de la API de attach/detach y de los hooks de eventos se leyeron de la base de ARC9 + el pack EFT de Darsu (`dev/other/`) y quedaron anotados en el header de `lua/corpus_cargo/shared/corpus_cargo_arc9.lua`; el puente shippeó (§14). El contrato #8 del `CLAUDE.md` congela la regla que lo motivó: este proyecto ya había aprendido (extractor EFT: `Penetration` vs nombres crudos, `armorDamage` ×0.01) que los nombres de ARC9 no se asumen de memoria — se leen del código vivo, siempre contra `dev/other/`.

**La API de ARC9 se usa también para ACCIONAR, no solo para attach/detach** (roadmap #46, entry 52 — re-verificada contra `dev/other/Arc9 Base` el 2026-07-28, anotada en el header de `client/corpus_cargo_lights.lua`): el toggle de modo de un dispositivo (luz/láser/IR) va por `SWEP:ToggleStat(addr)` + `SWEP:PostModify()`, **client-side** — es literalmente lo que hace el radial propio de ARC9 al clickear (`cl_move.lua:153-163`) — y replica solo (`PostModify` en CLIENT llama `SendWeapon`, sh_attach.lua:132). Es el **mismo contrato de CRG-23**: la escritura va por la API del mod, del lado cliente, y el server se entera por el canal del propio mod. Cero lógica de server nueva. El estado del modo pertenece al slot del arma (`slottbl.ToggleNum`) y **desde el roadmap #53 viaja con la instancia** en `blob.atts` (§10.5) — nunca colgado del jugador (§17.8).

### 10.5 `blob.atts` — la configuración pertenece a la INSTANCIA del arma

**El problema, medido y no supuesto** (roadmap #53, 2026-07-30): ARC9 guarda lo que un arma lleva montado en **un solo lugar**, la tabla Lua de la entidad SWEP (`slottbl.Installed`, `sh_attach.lua:19`), y no devuelve nada cuando esa entidad muere (`OnDrop`/`OnRemove`, `sh_init.lua:215-234`). Como casi toda transición de Cargo destruye la entidad —`Unequip`, drop sin el arma en la mano, take-back del suelo, respawn/relog—, todo lo montado se perdía. Lo que *parecía* persistencia era el autoguardado del **cliente** de ARC9, **por clase de arma**, que al re-aplicarse **se cobraba otro ítem del grid**.

**La forma.** `blob.atts` es un árbol anidado de datos planos —solo strings y enteros— con una entrada por slot ocupado:

| Campo | Qué es |
|---|---|
| `cat` | La categoría del slot, **normalizada**: ARC9 la declara como string *o* como tabla de strings (las dos formas conviven en un mismo handguard), así que se ordena y se junta |
| `nth` | Ordinal **entre hermanos de esa misma categoría**, y solo si hay más de uno. Existe porque los hay: el handguard del AS VAL mod4 declara **dos** slots que aceptan `eft_valmod4_side` |
| `att` | El `shortname` del attachment — la clave estable (**CRG-63**) |
| `mode` | El `ToggleNum` del slot, omitido cuando es 1 |
| `sub` | Los hijos, misma forma |

**Ni una posición se persiste, y el motivo es más fuerte que CRG-63 en su forma habitual.** El *address* de ARC9 no es solo un ordinal que un parche del pack puede correr: es el offset de un **aplanado recursivo del build actual** (`BuildSubAttachments` resetea los `SubAttachments` y los rearma solo para lo que está `Installed`), así que **se mueve dentro de la misma partida** mientras el jugador arma el arma. Medido: en el AS VAL del autor el PEQ-2 estaba en el address 11 **únicamente porque** el riel del 10 estaba puesto.

**Ni `PrintName`:** `ARC9:GetPhrase` ya lo localizó, así que cambia con el idioma.

**Nunca una tabla de slot de ARC9.** Llevan `Material()`, `Vector`, `Angle` y referencias cíclicas — es literalmente lo que rompe `gm_save` (§13). El serializador es **nuestro** y jamás copia un slot: lee tres campos y recursa. El propio de ARC9 (`WriteAttachmentTree`) además es `cl_presets.lua`, o sea **client-only**.

**Se cosecha en la PUERTA, no en un timer** (`Inventory.StoreFromEntity`, que es el cargador y el árbol juntos — a los 50 ms la entidad ya no existe). **Se re-aplica por la ruta del propio mod y del lado server** (`Inventory.ApplyAtts`), copiando la secuencia de `ReceiveWeapon` (`sh_net.lua:141-149`): `BuildSubAttachments` → `DoInvalidateCache` → `PruneAttachments` → `SendWeapon` → `PostModify`. **CRG-23 intacto.** Tres cosas que no son obvias:

- **`FillIntegralSlots` NO se llama** (decisión del autor). Consume del almacén, y el almacén somos nosotros: cada equip y cada respawn se comería ítems del grid. Es también la raíz del roadmap **#42**, que sigue siendo entrada propia.
- **El diff de propiedad nunca corre.** Vive *dentro* del `if SERVER` de `ReceiveWeapon` (`sh_net.lua:83-123`), así que llamar `BuildSubAttachments` directo lo saltea. Eso es lo que hace que re-aplicar sea **gratis**: estos atts ya son de esta instancia, no se están comprando de nuevo.
- **El árbol va ANTES del cargador.** Un cargador-attachment cambia el `ClipSize`, y el `PostModify` de server contesta un cambio de `ClipSize` con `Unload` + `SetRequestReload` (`sh_attach.lua:147-159`): aplicado después de `RestoreClip`, vaciaría el cargador que se acaba de restaurar. Es un argumento sobre la **secuencia**, no sobre el instante.

**Nada se pierde por el camino.** Un `shortname` que el pack borró **no puede** volver como ítem (nuestros ids de def derivan de `ARC9.Attachments`), así que se descarta **con log**; uno que existe pero no encuentra slot **vuelve al inventario** — y sus **hijos se juzgan uno por uno**, porque un padre borrado no es motivo para tirar la mira que colgaba de él (cita **CRG-9**). Si el grid no tiene lugar, al piso (cita **CRG-65**). Después de aplicar, el blob se **re-cosecha** de la entidad, así que converge sobre lo que el arma realmente lleva.

**Pesa y se cobra.** El árbol entra en `Instances.WeightOf` por la **misma recursión** que ya pesaba los sub-slots desde el Block 1 —una placa montada, unas gafas en el casco— y en `Trade.PriceOfEntry` sumando el `value` de cada att. El att **no paga la condición del arma**: no tiene condición propia (§10.1), así que una mira de $900 en un rifle hecho pedazos sigue valiendo $900. El **spread** sí lo alcanza, porque es el margen del trader y no desgaste.

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
- **Coagulant**: cantidad de sangre (`id = "blood"`) — **una sola barra**. La vida por zona no viaja al panel: la pinta la silueta de 7 zonas del HUD propio de Coagulant (`Coagulant_Architecture.md` §10, geometría única de silueta), que es información por zona y no cabe en una barra lineal.
- **Caliber (Block 3, pendiente)**: protección de armadura equipada.

**CRG-44 —** Si el módulo dueño de una barra no está montado, la barra simplemente no se registra — degradación honesta, mismo principio que gobierna todo soft-dep del ecosistema.

---

## 12. Persistencia

Todo vía `Corpus.Data` (namespace `cargo`), sin necesidad de SQLite: no hay consultas relacionales ni volumen que lo justifique. Nada de `file.*` para estado propio (cita **COR-18**), y los dos archivos de catálogo declaran su scope (cita **COR-19**, ver abajo).

**CRG-56 — No existen archivos de instancia; existen archivos de DUEÑO.** Un blob de instancia no tiene archivo propio: viaja embebido en el archivo de quien lo posee, bajo el campo `instances = { [uid] = blob }`. El inventario de un jugador es por lo tanto **un** archivo autocontenido — sus entradas de grid y equipo viajan junto a los blobs que referencian, incluidos los sub-slots anidados de forma recursiva. La forma anterior (un archivo `inst_<uid>` por instancia, §12 hasta el 2026-07-25) generaba un archivo en el instante de crear la instancia, sin saber si le pertenecía a un jugador o al mapa: la medición sobre la data real del autor dio **354 huérfanas sobre 370 archivos**, todas de estado de mundo que nunca debió tocar el disco.

**CRG-57 — `Instances._live` es la única fuente de verdad en runtime.** El campo `instances` del archivo es un **render** de `_live` en el momento de guardar, y al cargar se hidrata *hacia* `_live` **por referencia**: `rec.instances[uid]` y `_live[uid]` son la misma tabla. Jamás una copia paralela — si un módulo dueño mutara la copia en vez de la viva, el cambio se perdería en silencio en el próximo guardado. Es del tipo de invariante que un refactor "defensivo" rompe sin ruido, como COR-7.

**CRG-58 — Una instancia nunca se referencia desde fuera del archivo de su dueño.** La referencia cruzada entre archivos es exactamente lo que fabrica huérfanos. Cuando un ítem cambia de dueño el blob **se muda**: se escribe primero el destino y después el origen, de modo que un corte en el medio **duplica** en vez de borrar — duplicar es el modo de falla seguro.

**CRG-59 — El estado del mundo no va a disco salvo dueño persistente declarado (`persistKey`).** Una instancia que nadie declaró persistente muere con el mapa, y eso es lo correcto: GMod reinicia el estado Lua entero al cambiar de nivel, así que la limpieza es gratis. La cláusula de excepción recién tiene sentido desde que el contenedor persistente es archivo de dueño (abajo): antes, el dueño persistente y el efímero guardaban lo mismo — entradas sin blobs—, así que declarar `persistKey` no cambiaba lo que llegaba al disco, solo si llegaba.

**CRG-60 — El savegame guarda el MUNDO, no al jugador.** `gm_save` / `gm_load` conservan el estado de partida de Cargo que vive en entidades —una crate con su loot y sus condiciones, un trader con su stock mermado y su wallet, un ítem tirado en el suelo— y **el inventario del jugador no retrocede al cargar**. No es un descuido: es la contrapartida declarada de que el inventario sea por SteamID64 y **sin noción de mapa** (CRG-43), que cruza de nivel en nivel *y* de partida en partida. Sin la norma escrita, un tester reporta como bug que su mochila no volvió al estado guardado.

**Hasta dónde llega, medido y no supuesto.** El estado plano vuelve del savegame en las entidades **scripteadas** que Cargo declara —crate, trader, el drop `corpus_cargo_item`—, y ésa es la superficie de esta norma. En el **SWEP real** que deja el drop de un arma, no vuelve: ese caso está declarado en §13 y no se cubre acá. Lo que sigue describe la superficie que sí.

**Cómo viaja, y por qué no hay un `PreEntityCopy` que lo escriba.** `duplicator.CopyEntTable` hace `table.Merge(data, ent:GetTable())` quitando solo las funciones, así que **el estado plano de la entidad ES el blob del savegame**. Por eso `Containers.Save` **renderiza `instances` siempre**, persistente o no (escribir a disco sigue gobernado por CRG-59): el marcador que la entidad lleva encima es un dueño autocontenido *en todo momento*, no solo cuando alguien lo copia. Escribirlo desde un gancho de salida sería el mismo parche en el punto de salida que la entry 45 ya rechazó — un blob que solo es correcto adentro de `PreEntityCopy` está mal en cualquier otra ruta que lea `ent:GetTable()` (la herramienta de duplicado, un sistema de saves de terceros). Al volver, `Containers.Attach` acuña las instancias **de nuevo con uid nuevo**: el uid es único por boot y no globalmente, así que reusar el guardado es una colisión esperando ocurrir (misma razón que el re-uid del import). El drop de mundo —la entidad de ítem y el arma tirada, que es el SWEP real— es un **dueño de una sola entrada** y viaja igual, por `Instances.RenderEntry`.

**El invariante es de VALOR, no de momento.** Nada de esto pregunta *cuándo* el duplicator escribió los campos planos: ese orden no está bajo nuestro control ni es observable desde afuera del juego (medido en las seis rondas de la planilla Q). Se pregunta si el dato es **posible en esta sesión** — un id de contenedor que no está vivo, un uid que no está en `_live` — y por eso restaurar es **reemplazar**, nunca acumular: correrlo tarde, dos veces, o después de que algo ya leyó la entidad da el mismo resultado.

**Cuando las dos fuentes discrepan, manda el savegame** (decisión del autor, 2026-07-26). Un contenedor con `persistKey` tiene dos: su propio archivo de dueño y el blob del savegame. `cont_<key>` declara scope `save` — es **estado de partida**, no config de servidor (COR-19) — y el layout de perfiles lo ubica bajo `saves/<perfil>/maps/<mapa>/`; cargar una partida es volver a ese instante, contenido incluido, y el archivo se reconcilia con lo que ganó. El wallet del trader sigue a la **misma** fuente que su stock: un trader con el stock del save y el dinero del archivo sería un estado que ninguna de las dos partidas tuvo.

**Un solo serializador, con el dueño como parámetro.** Los dos archivos de dueño —el record del jugador y el contenedor persistente— renderizan e hidratan por **la misma** rutina, `Instances.RenderOwner` / `Instances.HydrateOwner`. Vive en `corpus_cargo_instances.lua` y no en el inventario: es del dueño de los blobs. `Inventory.CollectInstances` es la primitiva de alcanzabilidad que el render usa y es genérica por construcción —cada lista va guardada por su propio `istable`—, así que un dueño que solo tiene `items` la atraviesa sin ramas especiales. Lo que **no** entra en la rutina común son los remaps legacy: son migraciones de *forma* de cada dueño, no serialización, y el record remapea slots de `equip` que un contenedor no tiene.

- **Inventario del jugador** (`inv_<steamid64>`): slots + stacks + el mapa `instances` de sus blobs. Indexado por SteamID64, **sin noción de mapa**: cruza de nivel en nivel con el jugador.
- **Contenedor persistente** (`cont_<key>`): archivo de dueño de primera clase, con sus blobs adentro — `{ items, instances }`. Es el **segundo** consumidor de CRG-58, que es lo que la saca de intención declarada. Un solo escritor lo toca (`Containers.Save`): el trader, que se apoya en el mismo contenedor, lo llama en vez de escribirlo por su cuenta — mientras hubo dos escritores, el blob sobrevivía o no según quién guardara último.
- **Wallet del trader** (`trader_<key>`): archivo aparte, y a propósito. Un trader es el contenedor **más una capa de precio** (CRG-21); fundir el dinero adentro del `cont_` metería economía dentro del primitivo de storage que mañana reusan el alijo y el cadáver.
- **Estado del mundo sin dueño persistente**: no llega a disco (CRG-59). El stock de un trader de sesión, una crate sin `persistKey` y un ítem en el suelo viven solo en memoria y mueren con el mapa. La contrapartida, que es una decisión de diseño y no un defecto: **un ítem tirado en el suelo se destruye al cambiar de mapa**. Sobrevivir un `gm_save`/`gm_load` (CRG-60) **no** es una excepción a esto: el savegame es del engine y viaja con la entidad, no por `Corpus.Data` — nada de eso toca el disco de Cargo.

**La entidad guarda estado plano; las referencias vivas viven aparte.** `duplicator.CopyEntTable` hace `table.Merge(data, ent:GetTable())` quitando solo las funciones, así que todo lo que cuelgue de la entidad entra a cualquier duplicación y a cualquier savegame. Por eso `ent.CargoContainer` y `ent.CargoTrader` son dato plano, y la Entity y el set de viewers viven en `Containers._live` / `Trade._live`, indexados por el id de sesión. Limpiarlo desde un `PreEntityCopy` sería un parche en el punto de salida —cualquier otra ruta que lea `ent:GetTable()` sigue viendo la basura— y quemaría el gancho que el savegame necesita libre. Corolario para quien cuelgue un trader de su propia entidad: el stock y los viewers se piden por la API (`Trade.StockOf`, `Trade.HasViewer`, `Trade.ClearViewers`, `Containers.EntityOf`), no se leen de un campo.
- **Conocimiento de recetas** (banco de trabajo, ver `Workbench_Arquitectura.md`): mismo mecanismo, un archivo por jugador con el set de IDs desbloqueados.
- **Catálogo de servidor** (`autogen_defs`, `icon_overrides`): NO es estado de partida — es lo que los packs montados resultaron ser, más las decisiones de encuadre del editor de íconos. Los dos declaran `scope = "config"` (cita **COR-19**, sede `../../corpus/docs/CORPUS_Architecture.md` §3). Hoy la declaración no mueve nada —los dos scopes resuelven a la misma carpeta a propósito—; lo que compra es que el día que las rutas se separen, el catálogo no se vaya con la partida borrada.

**Los `inst_<uid>` legacy y su purga.** Un tercero que corrió Cargo antes del CHANGELOG #41 tiene todavía esos archivos en disco: no los escribe nadie más, pero tampoco desaparecen solos. El comando dev `cargo_dev_purge_legacy` los lista (**dry run por default**, porque borra data del jugador y todavía no hay gate de admin — CRG-45) y con el argumento `confirm` los borra. Su filtro es `^inst_` y nada más: `inv_`, `cont_`, `trader_` y los dos archivos de catálogo quedan en pie. Es el primer consumidor real de `Corpus.Data.List`/`Delete`.

Una entrada con `uid` cuyo blob no viene en el archivo se **descarta con log** al cargar: un ítem sin blob no se renderiza a medias (degradación honesta, cita COR-5).

### 12.1 Llevar un personaje a otro servidor (export / import LAN)

**CRG-61 — El import está apagado por default y todo lo que llega del cliente se sanea server-side.** Es el **único** punto del módulo donde CRG-6 —el server posee el inventario— se **invierte**: los otros 21 `net.Receive` reciben *intents*, que se validan contra el estado real y no pueden fabricar nada; éste recibe **estado**. La convar en 0, el gate de admin y la whitelist no son adorno: son lo que hace aceptable la inversión. Si la inversión existiera y la llave no, este archivo sería un agujero.

**Es barato en formato y caro en política.** El record ya es autocontenido desde CRG-56 y el re-acuñado ya existe desde CRG-60: lo único que faltaba era **transporte y permiso**.

**El export** (`cargo_export`, server) escribe el record renderizado por `Instances.RenderOwner` a un archivo por `Corpus.Data` (`export_<steamid64>`, o el nombre que se le pase), con una **cabecera**: número de formato, SteamID64 de origen, provider de dinero y firma de compatibilidad. **El número de formato NO es una ruta de migración** (D2 del plan: sin migraciones) — existe para **rechazar** con un motivo legible en vez de aceptar basura de otra época.

**El import** (`cargo_import`, client) lee ese archivo del disco del propio cliente y lo manda; **todas** las decisiones se toman en el server, en este orden, porque cada capa hace inútil un ataque que la siguiente ya no tiene que considerar:

| # | Capa | Convar | Default |
|---|---|---|---|
| 1 | La puerta | `cargo_import_enabled` | **0** — apagada |
| 2 | Gate de admin | `cargo_import_admin` | 1 |
| 3 | Whitelist de SteamID64 | `cargo_import_whitelist` | **vacía = NADIE**, jamás "vacía = todos" |
| 4 | Rate-limit | `cargo_import_cooldown` | 30 s |
| 5 | Tope, formato, origen, firma y **saneo entrada por entrada** | — | — |

**El receptor se registra SIEMPRE, aun con la convar en 0, y descarta en la primera línea.** No registrarlo sería la forma más fuerte, pero `util.AddNetworkString` corre al boot —una convar cambiada en vivo no tendría efecto sin cambio de mapa— y, decisivo: **un receptor que no existe no tiene dónde imprimir por qué rechazó**. Cada rechazo loguea su **motivo** en la consola del servidor; al jugador le llega una línea corta en inglés (CRG-48), porque una cerradura no le narra sus tripas a quien golpea.

**El saneo** (precedente de forma: CRG-46, el override de íconos). Def desconocida ⇒ la entrada se descarta con log · condición ⇒ se clampea al rango legal · counts ⇒ se recortan al `max_stack` de la def **real**, no al que vino · `ammo_group` fuera del set ⇒ se descarta el campo · sub-slots ⇒ **el filtro de la def manda** y lo que sobra de `maxItems` se recorta · claves numéricas ⇒ `Util.NumberKeys` (cita **COR-8**) · NaN e infinito ⇒ se descartan, que el JSON los expresa y toda comparación río abajo contestaría `false` en silencio. Lo que el **módulo dueño** puso en el blob viaja intacto (cita **CRG-1**: Cargo transporta, no interpreta) una vez probado que es dato plano. **Un uid puede estar reclamado exactamente UNA vez** en todo el record: dos entradas nombrando el mismo blob es la duplicación que este bloque existe para evitar. Un ítem que no entra en el slot en el que llegó **cae al grid** en vez de morir, que es lo que ya hace `ReconcileEquipSlots` al spawn (cita **CRG-9**).

**El peso NO es un gate del import**, igual que no lo es en una compra (cita **CRG-18**): el jugador puede llegar sobrecargado y la curva se lo cobra en velocidad.

**El uid se re-acuña con `Instances.Remint`**, el mismo que estrenó CRG-60 y confirmó la planilla R — no hay un segundo re-acuñado. Dos records de servidores distintos pueden traer uids colisionantes: el uid es único **por boot**, no globalmente.

**El import REEMPLAZA, no fusiona** (decisión del autor, 2026-07-26). "Traigo mi personaje" es literal y es el inverso exacto del export; fusionar es la ruta de la duplicación infinita —importar dos veces duplicaría todo y el peso dejaría de significar algo—. El record del destino se escribe **antes** a `import_backup_<steamid64>`: una sola escritura, destino primero, el mismo orden de **CRG-58** donde duplicar es el modo de falla seguro. El respaldo obedece `cargo_persistence`: con la persistencia en 0 **nada** de Cargo toca el disco (planilla P4) y el respaldo sería la excepción que vuelve falsa esa frase.

**El dinero viaja sólo con el provider nativo en AMBOS lados** (decisión del autor, 2026-07-26). El wallet vive **dentro** del record (`rec.wallet.usd`), así que viaja solo salvo que se lo saque a propósito: `Money` es una interfaz con providers (§6) y exportar un wallet que otro provider posee es **fabricar plata en el destino**. La cabecera estampa el provider de origen y el destino sólo lo acepta si los dos dicen `usd`.

**La firma de compatibilidad AVISA, no gatea, y hay que decir qué puede prometer** — una firma que promete lo que no cumple es peor que no tenerla:

| Mitad | ¿Estable entre dos servidores con los mismos mods? | Qué ve |
|---|---|---|
| `modules` | **Sí** | Qué módulos Corpus registraron. `corpus-stalker` es addon de **contenido** y no registra módulo, así que esta mitad no lo ve |
| `defs` + `defs_hash` | **Sí**, y es la mitad que sí ve a los addons de contenido | Hash de la lista **ordenada** de ids de defs NO autogen: se registran al boot desde archivos shared, así que el conjunto es función de los addons montados y de nada más |
| `autogen` | **No**, y por eso viaja como número pelado | `autogen_defs` **acumula a lo largo de la vida del servidor** (leído de `capture.lua`, no supuesto): dos servidores con los mismos mods hoy pueden tener conjuntos distintos según qué capturó cada uno |

Lo que protege de verdad al destino es el **saneo entrada por entrada**, no la firma. La mitad que sí rechaza es el número de formato.

> **Efecto de borde de la tanda #47, y es la firma funcionando, no un defecto.** Las 61 defs derivadas de las NVG de Neosun son **no autogen** y se registran al boot desde un archivo shared, así que entran de lleno en la mitad `defs` + `defs_hash`: **un servidor con ese mod montado y otro sin él ahora se DETECTAN**. Es exactamente lo que esa mitad promete —ve a los addons de contenido— y por eso avisa en vez de gatear: el saneo sigue descartando entrada por entrada lo que el destino no conoce, y el personaje entra igual sin sus gafas. Lo mismo valdrá para cualquier catálogo derivado que se sume después.

**Tope en vez de chunking, y es una medición, no una estimación.** El plan madre daba por hecho que haría falta trocear el payload. Medido offline: un record pesado pero realista —60 uniques cada uno con un anidado en su sub-slot, más 40 stacks— renderiza a **15.770 bytes** de JSON, y 200 uniques + 100 stacks a **51.310**; comprimido por `Util.WriteBlob` es una fracción de eso, holgado dentro de un mensaje. Así que el chunking sería adorno y lo que hace falta es un **techo que rechace con motivo**: el cable se corta en 64 KiB **antes** de descomprimir un solo byte, y el JSON resultante en 128 KiB, que es lo que ataja una bomba de descompresión. El harness afirma la medición: el día que un blob engorde, el rojo sale offline.

**Fronteras declaradas del bloque, no descuidos:**

- Las **armas equipadas** que llegan en el import quedan **en la mano en el acto** si el jugador está vivo. No por una ruta propia: el import corre `Inventory.RegiveEquipped`, **la misma rutina** que el hook `PlayerLoadout` y su reconcile diferido — un solo re-give con tres llamadores, por el mismo argumento que puso la restauración del savegame dentro de `Containers.Attach` y los dos archivos de dueño detrás de un solo serializador (CRG-58). Un jugador muerto no es una omisión: el hook de spawn está por llamar a esa misma función. **Se llegó acá por la planilla S1**, que midió el defecto contrario: hasta entonces el import dejaba un wheel lleno de armas que no se podían sacar hasta el próximo respawn.
- El gate de admin es **local y provisional** — ver §13.1: **CRG-45** sigue esperando la primitiva de permisos de Corpus.
- El export escribe en el disco del **servidor**. En un listen server —el caso de la LAN del autor— ése es el mismo `garrysmod/data/` que el cliente lee, y por eso el ida y vuelta funciona sin mover un archivo a mano. En un dedicated no: ahí el archivo queda en el host y alguien tiene que acercárselo al jugador.
- Un import trae **TU** personaje: el `origin` de la cabecera tiene que ser el SteamID64 de quien lo manda. Cierra la duplicación entre dos invitados de la misma whitelist sin necesidad de una convar más.
- **Qué scope lleva un archivo de export es decisión de B6, y se deja abierta a propósito.** COR-19 tiene dos: `config` (catálogo de servidor, sobrevive a borrar una partida) y `save` (estado de partida, muere con ella). Un export es honestamente **ninguno de los dos** — es un artefacto de transporte cuyo propósito entero es cruzar perfiles y servidores. Hoy los dos scopes resuelven a la misma carpeta y por eso no se mueve nada; el día que el layout de perfiles los separe, un export bajo `saves/<perfil>/cargo/` moriría con la campaña que venía a sobrevivir. Queda **con el default (`save`) y con la pregunta escrita**, que es lo que "dejar posible sin implementarlo" significa: inventar acá una norma sobre un scope que no encaja sería peor que nombrar la decisión. El **respaldo** (`import_backup_<steamid64>`) no tiene esa duda: es estado de partida del destino y `save` le corresponde.

---

## 13. Fronteras y pendientes declarados

**CRG-47 —** Boundary-debt explícito, mismo espíritu que el flag de Scavenger en Caliber — se declara ahora para no perderlo, se resuelve cuando el bloque dueño cierre:

> La fila *"Compatibilidad con mods externos de NVG/ópticas — sub-slot Head ya generalizado; **falta mapear mods concretos**"* estuvo abierta desde el Block 1 y **se cierra el 2026-07-26** (roadmap #47): el mod concreto quedó mapeado (`../../dev/Cargo_NVG_Neosun_Referencia.md`), el hueco que faltaba resultó ser de Cargo y no del mod —no existía señal de equipamiento— y se cerró con **CRG-62**. Las dos rutas de slot están arriba, en §4.

| Pendiente | Dueño futuro | Nota |
|---|---|---|
| Efectos de armadura de jugador (mitigación real por Body) | Caliber Block 3 | El ítem existe, pesa y se equipa desde ya; el efecto llega cuando Block 3 cierre |
| Escudos de energía de jugador vía sub-slot Body | Caliber Block 3 | Punto de acoplamiento (sub-slot) ya definido en este documento |
| Categoría de materiales de crafteo | Cargo (contrato) + Caliber/Coagulant (contenido) | Reservada, sin schema de recetas — ver `Workbench_Arquitectura.md` |
| Upgrades de armas ARC9/EFT | Workbench | Bandera parcialmente resuelta: la API de attach/detach de ARC9 es un canal de escritura legítimo (ver §10.3) — los upgrades de arma pueden modelarse como attachments nativos ARC9 en vez de escritura de stats. La API ya está verificada y el puente en producción (§10, §14); lo que sigue abierto es el **diseño del árbol** de upgrades |
| Attachments no-ARC9 (TFA u otras bases) | Cargo (integración) | Solo con tabla de compatibilidad manual declarada por arma — sin alcance automático en v1 (§10.4) |
| **Un arma soltada no conserva su instancia a través de un savegame** — **aceptado por el autor**, no pendiente | El engine; decisión cerrada el 2026-07-26 | **Medido, no supuesto** (planilla R, rondas 3-4, `cargo_dev_worldwep` sobre cuatro entidades del mismo save cargado): la tabla Lua vuelve **completa** en las entidades scripteadas de Cargo —la crate con `7 entrada(s), 5 blob(s)`, el drop `corpus_cargo_item` con su entrada y sus 2 blobs— y **no vuelve en absoluto** en el SWEP real que deja el drop de un arma. Lo único de Cargo que aparece encima del arma es `CargoWorldSpawned`, y **no está restaurado: lo re-pone el hook `PlayerSpawnedSWEP`** del world gate cuando el load crea la entidad (efecto colateral afortunado — el gate sigue vigente tras cargar). Consecuencia: al recoger un arma restaurada se acuña un ítem de fábrica, sin condición, sin attachments y sin cargador (degradación honesta, COR-5). **El autor lo acepta como está**: la ruta alternativa existe (`cargo_weapon_world_pickup 0` hace que el drop spawnee `corpus_cargo_item`, que sí conserva su blob) pero esa convar gobierna **también** el world gate de WALK+USE, y el gate más el arma dibujándose a sí misma (roadmap #16/#17) valen más que el cargador. Partir la convar en dos sería la forma de tener ambas cosas, y sería bloque propio; hoy **no se hace**. Instrumento para re-medirlo: `cargo_dev_worldwep` |
| **Con un arma ARC9 con dispositivo desplegada, el haz de la linterna del engine NO se dibuja** — **aceptado**, no pendiente | ARC9 — **no Cargo** | **Medido en juego, no supuesto** (planilla V, ronda 2, con las tres transiciones que lo aíslan): la linterna se enciende desde el chip y el haz se ve; al pasar a un arma ARC9 **con dispositivo** el haz desaparece **con el estado de server en `true` todo el tiempo** (`lua_run print(Entity(1):FlashlightIsOn())`); al volver a un arma sin dispositivo el haz reaparece. O sea que ARC9 suprime el **render**, no el estado — coherente con que su regla sobre la tecla F compartida sea no tener dos linternas a la vez. La línea exacta que lo hace **no quedó ubicada** en `dev/other/Arc9 Base/` y se dice así en vez de citar una que no se verificó (CRG-24 aplicado a nosotros mismos). Consecuencia declarada: en ese caso el chip dice ON y no se ve luz — **el chip no miente**, la linterna está encendida y es el mod el que no la dibuja. No se pelea: ARC9 es COMPAT-RUNTIME. Instrumento para re-medirlo: las dos líneas de consola de arriba |
| **El gate de admin del import es LOCAL y provisional** (`ply:IsAdmin()` + convar `cargo_import_admin`) | Corpus — la primitiva de permisos que **CRG-45** espera | Es el primer y único gate de permisos del módulo, y nació porque §12.1 invierte CRG-6 y no podía esperar (**CRG-61**). Se declara local a propósito: el día que Corpus exponga la primitiva, este gate se reemplaza por ella y la convar que lo apaga desaparece con él. **No** es deuda la convar en 0 por default ni la whitelist —ésas son diseño y se quedan—; lo único provisional es *cómo se pregunta quién es admin*. Mientras tanto la capa se puede apagar (`cargo_import_admin 0`), y apagarla deja a la whitelist como único gate: vacía sigue significando NADIE, así que ningún interruptor solo abre la puerta |
| **Apagar `cargo_nvg_register` con gafas ya en el inventario las deja huérfanas** — **aceptado por el autor**, no pendiente | Cargo; decisión cerrada el 2026-07-27 | **Medido en juego, no supuesto** (planilla U5): con la convar en 0 y cambio de mapa, las entradas que el jugador ya tenía quedan **sin def** —celda sin nombre ni ícono— y **se destruyen al dropearlas**. Es coherente con el resto del módulo (una def que no existe no puede representarse en el mundo, y el saneo del import descarta igual lo que no conoce) y el kill-switch existe para un servidor que **nunca** montó el catálogo, no para apagarlo a mitad de partida. El mismo check dejó la otra mitad, que es la que importa: con la convar en 0 el mod recupera su comportamiento **entero** (E te equipa las gafas y la entidad desaparece) — **COR-5 medido**, no declarado |
| **El HUD anuncia la munición que el arma del engine regala, aunque el jugador nunca la reciba** — **aceptado como costo cosmético**, no pendiente | El engine — **no Cargo**; decisión del autor 2026-08-01 | **Medido en juego, y las dos mitades por separado** (planilla AC, rondas 3 y 4): tomar un RPG del suelo hace que el historial de DGL4 anuncie *"+3 cohetes"* y que `cargo_dev_ammoweight` muestre la reserva **en 0**. O sea que **el invariante está cerrado y sólo miente el aviso**: el clawback por delta de `capture.lua` devuelve el pool a lo que era, pero el evento del engine ya se disparó y llega antes. Verificado contra la fuente del mod (CRG-24): DGL4 alimenta su historial desde `HUDAmmoPickedUp` (`holohud2/elements/resourcehistory.lua:281`). **Taparlo desde un hook hermano sería una carrera** —el orden de `hook.Call` entre hooks distintos no es de inserción, lección de la saga VJ (entries 37-40)— y **apagarlo en la fuente se INTENTÓ y no alcanzó**: escribir `m_iPrimaryAmmoCount` en la entidad antes del `Equip` no impide el evento, así que o el campo no es ése o el regalo no vive en el datamap. El intento **se queda** porque va en `pcall` y es inerte donde no aplica; lo que no se queda es la afirmación de que funciona. **El arreglo real existe y es caro, y por eso no se hace:** no dejar que el engine equipe el arma en absoluto —denegar la recogida y acuñar el ítem directo desde la entidad del suelo—, pero la captura viaja sobre `WeaponEquip` por motivos de compat documentados en el header de `capture.lua` (la lección del L4D IPS), y arriesgar esa superficie por una línea de HUD **que miente pero no roba** no se paga. Instrumentos para re-medirlo: `cargo_dev_ammoweight` (el invariante) y `cargo_dev_worldwep` (los campos de la save table del arma, por nombre **y por valor**) |
| **Un arma ARC9 en el suelo rompe el savegame del engine** | ARC9 / el engine — **no Cargo** | Medido en juego el 2026-07-26 (ronda 1 de la planilla R). El save del engine recorre la tabla Lua de cada entidad; las defs de attachment de ARC9 declaran `ATT.Icon = Material(...)` y el SWEP se cuelga esas tablas encima (verificado contra `dev/other/`, cita CRG-24). Resultado: `Can't write unknown type IMaterial`, `attempt to serialize structure with cyclic reference` y `CSave BLOCK SIZE OVERFLOW (>65k)` → *"This save will not load correctly"*, para **todo el mapa**. No se arregla desde acá: ARC9 es COMPAT-RUNTIME y no se forkea. Lo que sí es decisión de Cargo es el camino que lo hace alcanzable — el drop de un arma deja el **SWEP real** en el suelo (roadmap #16/#17) para que se dibuje con sus attachments; el precio, ahora medido, es éste. Lo que Cargo cuelga de una entidad son **184 bytes por unique** y **145 por drop**, con guard offline que exige dato plano y acíclico |

### 13.1 Comandos dev sin gate de admin

**CRG-45 —** Los comandos dev de Cargo quedan **SIN gate de admin**, con el `TODO` anotado en el código, esperando la primitiva de permisos de Corpus. Alcanza a `cargo_dev_give`, al editor de íconos (`cargo_icon_edit` / `regen_all`) y al spawn del trader de ejemplo (`Cargo_Trade_Arquitectura.md` §10).

Es **deuda declarada, no una norma cumplida**: lo normativo es que el `TODO` esté anotado y espere la primitiva, no que los comandos estén protegidos. Se dice acá para que nadie lea la ausencia de gate como un descuido.

De los **24** `net.Receive` de SERVIDOR del módulo (derivado por grep del árbol, cita FLU-27 — re-derivado el 2026-07-28 al sumar el intent de linterna del roadmap #46, `server/corpus_cargo_lights.lua`, que cae en la categoría protegida: toggle **sin payload**, sin estado que fabricar), **22 no necesitan gate por diseño**: los protege **CRG-6** — el server posee el inventario y el cliente solo manda intents, así que un intent hostil se valida contra el estado real y no puede fabricar nada. Los dos que quedan son de otra naturaleza:

- `NET_ICON_OVERRIDE` — necesita gate y **no lo tiene**: hoy está **abierto a cualquier jugador** y contenido solo por el saneo de entrada de **CRG-46** (def desconocida se ignora, footprint fuera del set permitido se descarta).
- `NET_IMPORT` (§12.1, **CRG-61**) — el único que **invierte** CRG-6, y por eso es el único del módulo que **sí** trae gate de admin. Ese gate es **local y provisional**, y se declara como tal en vez de disimularlo: cuando Corpus exponga la primitiva de permisos, este `ply:IsAdmin()` y la convar `cargo_import_admin` que lo gobierna se reemplazan por ella. La whitelist y la convar apagada por default **no** son deuda: son diseño y se quedan.

> **Sede movida el 2026-07-19** (deuda D-3/D-13). Vivía en `cargo_roadmap.txt` (ítem 12 de su lista de deuda propia), y un roadmap es **intención pura, nivel 6** — no puede ser sede de una norma vigente. Peor: el archivo ni siquiera contenía la etiqueta `CRG-45`, así que era una sede rota que el gate LLM no vio y el checker tampoco, porque la ruta existía. El roadmap ahora **cita** esta sección.

---

## 14. Estado de este documento

Bloque de diseño de Cargo (inventario) cerrado y validado en sesión de diseño (Opus) — ratificado por el autor antes de este volcado a documento (Sonnet). El banco de trabajo (crafteo/reparación/desarme/upgrades) es un bloque de diseño relacionado pero independiente, documentado en `Workbench_Arquitectura.md`.

| Sección | Estado |
|---|---|
| Contrato de ítems, slots/sub-slots, peso, providers, grid, contenedores, tooltip, stat-bars | **Cerrado — este documento** |
| Attachments de armas (UX + puente ARC9) | **Cerrado y en producción — §10.** La API de ARC9 se verificó contra el código vivo (base + pack EFT de Darsu, 2026-07-10) y quedó anotada en el header de `corpus_cargo_arc9.lua`; el contrato #8 del `CLAUDE.md` la congela (nunca de memoria: siempre contra `dev/other/`) |
| UI fullscreen (forma) | **Cerrado — §15**; VGUI es bloque de implementación aparte; depende de Cargo_ItemImages. Paletas runtime + teñido DGL4 **cerrados — §15.5** (entry 14) |
| Sistema de munición (el cinturón ES el pool) | **Cerrado — §16** (Bloque B, roadmap #19). UX (reorder, unload, gate WALK+USE de ítems) **cerrada — §16.8** (Bloque C, roadmap #25 · #26 · #27). Throwables y cajas de mundo **cerrados — §16.9** (entries 13/16). Abierto: cargadores rellenables con toggle, y el binding de ammo-atts de EFT (§16.6) |
| Wheel menu + slot throwable + compat de movimiento | **Cerrado — §17, §4/§5 (enmiendas)** (entries 13/14/16, verificados en juego 2026-07-13). El **grupo de luces** (§17.8, roadmap #46, entries 52-53) está escrito y **pendiente de la planilla V** |
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
| **Trade** | interactuar con trader (NPC o jugador) | stock del trader + strips Buy/Sell + deal bar (neto, Cancel/Confirm) — **implementado, slice 1**; el inventario del otro JUGADOR llega con el slice 3 | `Cargo_Trade_Arquitectura.md` §12.bis |

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

> **Enmienda 2026-07-13 (entry 13 — bloque wheel/throwable).** Mockup congelado:
> `mockups/cargo_equipcolumn_throwable_mock_v1_1.html`.
>
> - **Fila baja apilada (patrón Clear Sky):** conserva 3 columnas; la tercera se divide en
>   vertical — **Throwable (chico, arriba) sobre Melee**. Sidearm y Back conservan su
>   ancho; el throwable lee como slot menor, que es lo que es. La variante de 4 columnas
>   iguales queda **descartada** (vive en el mock solo como comparación visual).
> - **Círculos sandbox:** toggle **"hide" restaurado** (chip al lado; ocultos, la fila
>   colapsa) + alineación configurable `cargo_ui_tools_align` (`left` default / `center`),
>   ambos en el tab de Cargo del menú Q. La selección está factorizada en
>   `CARGO.UI.SelectTool` — la consumen la columna y los chips del wheel (§17.6). Pintan
>   con `Theme.DrawCircle` (primitiva única de círculo, §17.5).
> - **El panel de estado se estira hasta el fondo** de la columna (era alto fijo): va a
>   crecer con las barras de otros módulos. Las barras siguen siendo **registrables**
>   (§11) — nada se hardcodea; cada módulo registra las suyas por soft-dep cuando exista:
>   Coagulant (**Blood** — la vida la pinta su silueta propia, no el panel), Craving
>   (Hunger · Hydration), Caliber Block 3 (armadura propia). **Las dos barras demo de
>   `corpus_cargo_dev.lua` quedan legacy**: HL2 Armor sale cuando Caliber B3 traiga la
>   armadura propia, y **Health no tiene relevo previsto** (Coagulant la descartó — su
>   vida vive en la silueta).

#### Cinturón de munición (solo la FORMA)

Fila de **6 slots cuadrados** (tipo cinturón — la munición no es lo bastante grande
para justificar más espacio). Los ítems de munición del inventario se **mueven acá**
para **alimentar al arma activa**: la munición cargada deja de estar suelta en el grid
y pasa al equipo. En el mock, los stacks bindeados a los grupos A/B de las armas
equipadas viven en el cinturón, no en el grid.

> **Frontera cerrada:** este bloque cerró la **forma** del cinturón (la fila de slots y que
> la munición se mueva ahí). La **semántica** la cerró el Bloque B → **[§16](#16-sistema-de-munición-el-cinturón-es-el-pool)**:
> el cinturón no almacena munición, **ES** la reserva real del jugador. La **interacción** de
> reordenar el cinturón (drag belt→belt, un slot ocupado a otro) la cerró el Bloque C →
> **[§16.8](#168-ux-de-munición-bloque-c)**. Lo único que sigue abierto de #19 es el sistema
> de cargadores rellenables con toggle (fuera del v1).

#### Arrastrar sobre un ítem: qué significa el gesto (1.ª pasada en juego de #47)

Soltar una celda **sobre otro ítem** (no sobre el fondo del grid) tiene significado propio. La regla es **pura y exportada** —`CARGO.UI.ResolveSlotDrop`, `CARGO.UI.FreeSubSlotFor`— porque es de las que se rompen en silencio: un `if` invertido y el gesto deja de significar lo que el jugador espera, sin un solo error en consola.

| Dónde se suelta | Qué pasa |
|---|---|
| Ítem del grid **sobre otro ítem del grid** | Si el destino tiene un **sub-slot libre que acepta** la categoría del origen, lo **monta**. Es el mismo intent que el menú *"Insert into…"* — el arrastre es un atajo, no una segunda ruta |
| Ítem del grid **sobre un slot de equipamiento ocupado** | **1)** Si el ítem puede ocupar el slot → **EQUIPA, e intercambia** (`Equip` devuelve al grid al ocupante anterior). **2)** Si no puede pero el **ocupante** tiene un sub-slot libre que lo acepta → **ACOPLA**. **3)** Si ninguna → se manda el equip igual y **el rechazo lo redacta el servidor** (CRG-6): tragárselo acá cambiaría una negativa legible por un gesto que no hizo nada |

**Equipar se prueba PRIMERO a propósito** (decisión del autor). Cuando las dos lecturas son legales —unas gafas que entran en Head, soltadas sobre un casco que también las aceptaría en su óptica— gana el intercambio.

**Extraer un sub-slot no depende de que el host esté puesto.** La lista de lo montado (`CARGO.UI.MountedEntries`) es la misma para el menú del slot equipado y para el del ítem en el grid: un casco es el mismo objeto en la cabeza que en la mochila, y tenerla solo en el menú del slot hacía que un casco guardado **retuviera su óptica como rehén**. El `index` que viaja al detach es **posicional dentro de su sub-slot**, así que aplanar la lista no lo puede renumerar.

> **Nota de VGUI, y no es opcional:** una celda que además es `Receiver` **tapa** al receiver del canvas (`dragndrop` sube desde el panel bajo el cursor y para en el primero). Por eso `onCellDrop` devuelve un booleano y el grid **cae al `onReceiveDrop`** cuando la celda no es un destino válido — sin ese fall-through, soltar un ítem de un contenedor justo encima de otra celda dejaría de transferir. El comportamiento del canvas no puede depender de **dónde adentro** del canvas soltaste.

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

### 15.5 Paletas runtime y teñido DGL4 (roadmap #29 — entry 14)

*(Contrato de tokens del mock `mockups/cargo_theme_dynamic_mock_v1_1.html`. Todo vive en
`corpus_cargo_theme.lua` — la única fuente de estilo.)*

- **CRG-29 — Mutación en sitio.** Los objetos `Color` de `T.Colors` se crean UNA vez; una paleta
  solo muta sus rgba (`ApplyPalette`), conservando nombre **e identidad de tabla** — todos
  los closures de `Paint` (y tablas de file-scope) que capturaron una referencia se
  re-skinnean al frame siguiente sin tocar un consumidor.
- **Bases.** Default **`spawnmenu`** (grises neutros en la clave del spawnmenu/browser de
  GMod — decisión del autor: "benigno, listo para integrarse"); `cargo_theme olive`
  restaura la paleta GAMMA del mock fullscreen original. Claves nuevas del contrato:
  `accent`/`accentDim`/`scrim` (fin de los colores hardcodeados del scrim).
- **Teñido DGL4** (HOLOHUD2, COMPAT-RUNTIME). Con el mod montado y `cargo_theme_dgl4`
  (default 1), la paleta entera deriva del preset activo: el tint global de
  `GetModifiers().color` cuando está seteado y no es blanco pelado, o — **decisión
  anotada**: los presets no exponen nombre — el color sano de `health_color` (umbral más
  alto) del elemento `health` (Foxtrot Uniform = verde PCV 180,255,100). Re-tint **en
  vivo** vía su hook propio `OnSettingsChanged` y en los flips de convar. Sin mod / API
  rota: base neutra, jamás crash.
- **`Theme.SkinScroll`** re-skinnea los scrollbars Derma stock con la paleta (grid y
  editor de íconos — entry 16, fleco) — el re-tinte DGL4 los alcanza gratis.
- Los FX del mock (glow/scan) quedan anotados como **futuros** — no entran.

---

## 16. Sistema de munición: el cinturón ES el pool

*(Bloque B, roadmap #19. Cierra la semántica que §15.2 dejó como forma vacía.)*

### 16.1 La decisión

**CRG-14 — El cinturón no guarda munición: ES la reserva real del jugador.** Un stack colgado en un
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

Los **11 tipos** de munición del engine que Cargo maneja quedan registrados como ítems en
[`shared/corpus_cargo_ammo.lua`](../lua/corpus_cargo/shared/corpus_cargo_ammo.lua), cada uno con
modelo, peso por unidad, descripción y **`max_stack`**: **9 como munición de cinturón**
(`cargo_ammo_<tipo>`, categoría `ammo`) y **2 con cara lanzable** (`cargo_throw_frag` /
`cargo_throw_slam`, categoría `throwables` — ver la enmienda de §4 y §16.9; los ids
`cargo_ammo_grenade`/`cargo_ammo_slam` quedaron **muertos** y remapean vía
`CARGO.Ammo.LegacyThrowIds`). El tope es lo que convierte a los seis slots del cinturón en una
**decisión** (cuánta munición y de qué calibre te colgás) en vez de decoración. Los `.mdl` se
verificaron parseando los VPK reales, no de memoria.

### 16.3 El espejo (`server/corpus_cargo_ammopool.lua`)

**CRG-15 —** Invariante, para cada tipo que Cargo maneja:

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

> **Fix de conservación (Bloque C, entry 12):** cuando el excedente que vuelve de un cargador
> no cabe en el cinturón y se va al grid **con éxito**, el pool ahora **siempre** baja a la
> suma del cinturón (`ply:SetAmmo(pool - left, hl2)`, sin condicionarlo a la rama de fallo).
> Antes solo bajaba cuando el grid rechazaba el excedente (inventario lleno): con éxito el pool
> quedaba en el valor viejo y el poll siguiente volvía a ver `pool > belt` y **re-acuñaba el
> mismo excedente cada 250 ms** — duplicación latente desde el Bloque B, inalcanzable en la
> práctica hasta que el unload (§16.8) volvió "descargar con el cinturón lleno" una ruta
> ordinaria.

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
2. **CRG-17 — El spawn.** En cada `PlayerLoadout`, `StripAmmo()` y después `Push()`: la reserva se
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

- **CRG-16 — Munición del mundo → el GRID.** Los `item_ammo_*` del mapa se vetan al engine y entran como
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
- **Categorías fijas de tabs** (#23, cerrado aparte en §7.1) y **retícula del grid**
  (#24): frentes ajenos a este bloque.

### 16.8 UX de munición (Bloque C)

*(Bloque C, roadmap #25 · #26 · #27. Cierra la UX que la pasada en juego del Bloque B — entry
11 — dejó anotada en su semilla `dev/HANDOFF_cargo_bloque_c_municion_ux.md`.)*

#### Reordenar el cinturón (#25)

`BeltSet` solo aceptaba refs del **grid**: no existía mover un stack que ya colgaba del
cinturón a otro slot. Nueva
[`CARGO.Inventory.BeltMove(ply, fromN, toN)`](../lua/corpus_cargo/server/corpus_cargo_inventory.lua)
(server, ~línea 752), intent `belt_move` (`Corpus.Net.Register("cargo", "belt_move")`):

- **Destino vacío:** el stack se mueve entero.
- **Mismo id + condición idéntica:** fusiona hasta `max_stack` — el resto **se queda en el slot
  ORIGEN** (nada sale del cinturón en un merge, a diferencia de un `BeltSet` desde el grid).
- **Ocupante distinto:** vuelve al grid (swap; decisión del autor — mismo comportamiento que el
  desplazamiento ya existente de `BeltSet`).

La regla del tope (`max_stack`) se extrajo a un helper compartido,
`BeltMergeInto(occ, moving, maxStack)` (~línea 695), usado tanto por `BeltSet` (grid → cinturón)
como por `BeltMove` (cinturón → cinturón) — vive en un solo lugar. Cualquier movimiento que
desplaza un ocupante llama a `Push` igual que antes: el espejo (§16.3) no se entera de la
diferencia entre un `BeltSet` y un `BeltMove`.

Cliente (`corpus_cargo_ui.lua`): la celda del cinturón (`MakeBeltCell`) ya era
`Droppable("cargo_item")`; su `Receiver` gana la rama "el panel soltado es otra celda del
cinturón" (`panels[1].cargoBeltSlot`) y manda `belt_move` en vez de `belt_set` cuando el origen
es otro slot del cinturón.

#### Descargar el arma (#26)

La mitad difícil ya existía desde el Bloque B (§16.3: el espejo absorbe lo que vuelve de un
cargador, con overflow al grid). Lo que faltaba era el **disparador**:
`CARGO.AmmoPool.UnloadWeapon(ply)` (`server/corpus_cargo_ammopool.lua`) actúa sobre el **arma
activa** (`ply:GetActiveWeapon()`):

- **ARC9, por SU API** (COMPAT-RUNTIME, cero fork): `SWEP:Unload(GetProcessedValue("Ammo"))`
  (`sh_reload.lua:199-205`, verificado contra la base) — hace `GiveAmmo(Clip1)` +
  `SetClip1(0)` + `SetLoadedRounds(0)`.
- **No-ARC9, a mano:** `ply:GiveAmmo(clip, ammoName, true)` + `wep:SetClip1(0)`.
- **`Reconcile` corre en el acto** (sin esperar el poll de 4 Hz) para que las balas aparezcan en
  el cinturón (o el grid, si está lleno) en el mismo instante.
- **`StoreClip`** después: el cargador vacío **persiste en el blob de instancia** (#18) — un
  re-equip desde el grid no debe devolver las balas.
- **Gate de spawn:** denegado con aviso hasta que el `Push` de spawn del jugador corrió — el
  mismo `ready[ply]` que suprime el reconciliador (§16.4); descargar durante la ventana de
  spawn perdería las balas en el `StripAmmo`+`Push` que sigue.

**La trampa de `RestoreAmmo`:** la animación de reload de ARC9 solo se reproduce
(`wep:PlayAnimation("reload")`) si la animation entry de esa arma **NO** declara
`RestoreAmmo` — ese flag re-llena el clip **desde la reserva** en un timer interno de
`PlayAnimation` (`sh_anim.lua:130-133` → `RestoreClip`, `sh_reload.lua:298`), lo que desharía el
unload por detrás. Se consulta la entry por la propia API de ARC9
(`wep:TranslateAnimation`/`wep:GetAnimationEntry`), nunca se asume. **Verificado en juego:** la
animación corrió y el contador **no** se re-llenó — el guard funcionó.

Disparadores en cliente: opción **"Unload magazine"** en el menú contextual del slot equipado
(`OpenSlotMenu`, `corpus_cargo_ui.lua`) — solo se ofrece si esa arma está efectivamente en la
mano (`wep:GetClass() == def.weapon_class`) — y el comando `cargo_unload` (bindeable), ambos
mandan el intent `unload` vía `SendUnload()`.

#### Gate WALK+USE de ítems botados (#27)

El hook `PlayerUse` de `corpus_cargo_capture.lua` (~línea 286) filtraba por `ent:IsWeapon()`; el
`ENT:Use` de `corpus_cargo_item.lua` recogía **incondicionalmente**, así que un ítem de munición
botado esquivaba el gate entero (USE pelado ya aspiraba la munición). El hook ahora cubre también
`ent:GetClass() == "corpus_cargo_item"`:

- **USE pelado:** carry de prop HL2 (`ply:PickupObject(ent)`) — el `return false` del hook
  bloquea que `ENT:Use` corra.
- **WALK+USE:** el hook se aparta (`return` sin valor para el caso ítem) y `ENT:Use` recoge como
  siempre.

Reusa el debounce por jugador (`ply.CargoNextWorldUse`) y la marca "USE de nuevo suelta"
(`ply.CargoCarryEnt`) que el gate de armas de mundo (roadmap #16, entry 7) ya había pagado — sin
duplicar lógica. La entidad `corpus_cargo_item.lua` no cambió (solo su comentario de header); el
convar `cargo_weapon_world_pickup` sigue gateando **solo** la rama de armas, no la de ítems.

**Sin convars nuevas** en este bloque. Net nuevo: `belt_move`, `unload` (ambos vía
`Corpus.Net.Register("cargo", …)`, como todo mensaje del módulo).

### 16.9 Enmiendas del espejo: throwables y cajas de mundo (entries 13/16)

*(El slot `throwable` de §4 y la taxonomía de granadas del roadmap #32 le enseñan la cara
lanzable al espejo de §16.3. Todo en `server/corpus_cargo_ammopool.lua`.)*

- **El stack equipado cuenta como reserva.** `BeltTotals` suma también
  `rec.equip.throwable`: el invariante pasa a ser `pool == cinturón + stack equipado` para
  los tipos con cara lanzable. Al gastar (lanzar), **el slot paga primero** y recién
  después los stacks del cinturón; al vaciarse el slot, se quita el SWEP.
- **`AbsorbType` ramifica por cara.** Para un tipo cuya cara canónica **no** es munición
  (`Grenade`/`slam`): el filtro del cinturón rechaza su categoría, así que la única
  reserva que puede absorber es el **stack equipado**, topeado bajo `max_stack` (esto es
  lo que mueve el `×N` cuando el engine regala una granada). El excedente vuelve al
  caller, cuyo camino de overflow lo manda al **grid** Y baja el pool a la suma de reserva
  — una granada en el grid es almacén, no reserva. Decisión conservadora: **nunca
  auto-equipa** un slot vacío.
- **Cajas `item_ammo_*` por WALK+USE (#32).** Ya no se toman por contacto:
  `PlayerCanPickupItem` pasa a **veto puro** (nunca reparte), y la toma vive en el MISMO
  gate de `PlayerUse` de `capture.lua` que armas e ítems botados (§16.8), leyendo
  `AmmoPool.WorldAmmoSpec(clase)` — USE pelado carga la caja como prop;
  `cargo_ammo_world_pickup 0` restaura el pickup crudo del engine. La captura tampoco
  acuña ya `wpn_weapon_frag`: la entidad del give muere y el espejo contabiliza (con el
  stack equipado, la clase es suya — el take-back del entry 13 intacto).

### 16.10 El peso de la munición cargada (roadmap #56 — entry 65)

*(Cierra el «CASO DECLARADO Y NO CUBIERTO» que la nota de CRG-66 llevaba escrito desde el
2026-07-30. Aterriza acá y no en §5 porque el problema no era el peso sino **la munición**:
de dónde sale el tipo, y a qué ritmo se refresca el número.)*

**CRG-67 — Una bala pesa lo mismo viva donde viva, y se cuenta UNA sola vez.** Colgada del
cinturón, guardada en el grid o cargada en el arma: el costo de carga es el mismo, y ninguna
ruta puede contarla en dos lados a la vez. Es CRG-14 llevado al peso — el cinturón *es* el
pool, y el cargador es el tercer bolsillo que faltaba.

El síntoma que lo abrió: las mismas 30 balas pesaban **0,36 kg en el cinturón y 0 kg adentro
del arma**, así que recargar era un descuento de peso.

> **CORRECCIÓN 2026-08-01 (planilla AC, check AC2 en FALLA) — el ejemplo estrella era falso, y
> queda dicho en vez de reemplazado en silencio.** La semilla, este doc, el roadmap y el CHANGELOG
> abrían con *«un cohete de RPG pesa 3,0 kg, así que cargar el lanzacohetes hace desaparecer tres
> kilos»*. **No es cierto: el RPG de HL2 no tiene cargador.** Dispara de la reserva directo y su
> `Clip1()` contesta **-1** — medido en juego: `clip1=-` en las cuatro corridas del autor, con el
> arma cargada y disparando. Los cohetes siempre estuvieron en el pool, el pool sigue al cinturón
> y el cinturón siempre pesó: **ahí nunca desapareció nada**. El número salió de multiplicar dos
> campos del catálogo (`weight 3.0`, `max_stack 2`) sin abrir el arma — **una inferencia escrita
> como si fuera una medición**, que es justo lo que §7.1 del flujo prohíbe, cometido en la premisa
> de la propia tanda.
>
> **El síntoma real, medido sobre el loadout del autor** (dump del check AC3): cinco armas con el
> cargador puesto escondían **1,588 kg** — AS VAL 31×0,02 = 0,620 · KS-23 4×0,05 = 0,200 · PL-15
> 13×0,012 = 0,156 · UZI 20×0,012 = 0,240 · MCX 31×0,012 = 0,372. Menos espectacular que tres
> kilos, y es el que existe.
>
> **Corolario de forma, y tiene código:** un arma sin cargador contesta `-1`, y un `-1` guardado
> daría peso **negativo** — un arma que alivianaría al jugador. Los dos caminos al campo
> (`StoreClip` y `SyncHeldClip`) lo rechazan, y `ClipWeight` lo rechaza otra vez; las tres guardas
> están medidas por separado, cada una con su reversión.

#### El tipo de un arma que no tiene entidad viva

§16.2 declara que **el tipo real de un arma sale de su ENTIDAD, nunca del def**, y eso sigue
vigente. Lo que faltaba era la respuesta para el caso que esa regla no cubre: un arma guardada
en el grid es un blob y un `id`, y no hay entidad a la que preguntarle. `CARGO.Ammo.TypeOfClass`
la contesta como **default de clase**, y donde hay entidad la entidad sigue ganando.

La resolución trepa `.Base` a mano con `weapons.GetStored` —no `weapons.Get`, que deep-copea el
SWEP entero para leer un string—, en este orden:

1. **`SWEP.Ammo`**, que es como lo declara ARC9. **No** `Primary.Ammo`, que era el candidato
   obvio y **está vacío en la clase**: `SWEP.Primary.Ammo = SWEP.Ammo` se evalúa al cargar la
   base, con `SWEP.Ammo` todavía `""` (`Arc9 Base/…/shared.lua:334-335`), y sólo `Initialize` lo
   corrige **por instancia**. El wheel ya lo había pagado en `AmmoTypeOf`.
2. **`SWEP.Primary.Ammo`** para SWEPs no-ARC9 (VJ, ZBase), donde sí es el valor real.
3. **Tabla de escape para las armas del engine**, que no son SWEPs (`GetStored` devuelve `nil`).
   Es el mismo patrón que `Capture.WeaponSlotKinds` y `Capture.WeaponTrivia` ya necesitaron por
   la misma razón — y ahí cae el caso estrella del bloque, el RPG.

**El censo que lo respalda** (`dev/other/`, 2026-07-31, 243 SWEPs con la herencia resuelta):
**215** clases caen en un tipo que Cargo maneja, **10** en uno que no, 6 en un placeholder
`"none"`, y **las 12 que no resuelven nada son exactamente plantillas base y melee/tools** — o
sea, lo que no tiene cargador. El censo cubre ~2/3 del arsenal real del autor: los packs de EFT
SMG/escopetas/LMG, CS:GO y `arc9_wtt` no están en `dev/other/`.

#### Se calcula, no se guarda

El peso es **derivado** y se calcula en `Instances.WeightOf` (CRG-66: una sola recursión).
Guardarlo crearía el segundo número que CRG-56/57 existen para evitar, y no compraría nada:
`TotalWeight` sobre un record de media partida mide **1,5 µs**. Lo único memoizado es el mapa
`clase → tipo`, y es seguro porque su entrada —las tablas de SWEP registradas— no puede cambiar
dentro de un boot: no es el memo que esconde estado vivo.

El peso por bala sale del **def del ítem de munición**, nunca de una segunda tabla: la bala del
cinturón y la del cargador tienen que ser la misma bala o CRG-67 es indemostrable.

#### La cadencia, y por qué ésta

Hasta acá el ledger sólo se movía cuando se movía el **cinturón**, y el sistema era barato por
eso. Con el cargador pesando, disparar pasa a mover el ledger. **Decisión del autor 2026-07-31,
con los cuatro costos medidos y no estimados:** el refresco **viaja en el poll de 4 Hz que ya
corría** (`AmmoPool.SyncHeldClip`, al tope de `Reconcile`). Sin timer nuevo, sin hook de base de
arma, sin mensaje de red nuevo.

| | costo medido |
|---|---|
| recalcular el peso | **1,5 µs** — gratis |
| un `Touch` (Save + Sync + Movement) | **0,158 ms** de disco + **6.537 B** a disco + **~1,1-1,7 KB** al cable |
| un Touch por bala, a 10 disparos/s | 64 KB/s a disco · 1,58 ms/s · ~11-17 KB/s de red **por jugador** |
| **el poll de 4 Hz (lo elegido)** | **≤4 Touch/s mientras dispara, CERO cuando no** — 26 KB/s · 0,63 ms/s |

Lo que la medición cambió: **lo caro de un `Touch` no es la matemática del peso sino el Save y
el Sync**, así que lo que había que racionar era el Touch y no la aritmética.

**El re-leído va PRIMERO dentro de `Reconcile`, y eso carga peso:** en una recarga el cinturón
está por pagar exactamente lo que el cargador acaba de tomar, y leer el clip en la misma pasada
es lo que hace que las dos mitades caigan en **un solo Touch**. Sin eso, el ledger bajaría un
cargador entero y lo recuperaría después — que es el defecto original con otro disfraz.

**Error máximo declarado:** 250 ms de disparo (≈5 balas de fusil, ~0,06 kg), y **siempre de
más, nunca de menos** — nunca se gana capacidad gratis, que era el reclamo.

#### Fronteras declaradas

- **Un tipo que Cargo no maneja pesa 0.** Son 10 clases medidas: 7 marksman/snipers de ARC9MW
  que comen `SniperPenetratedRound`, el cuchillo arrojadizo de MW y el ssg08 de VJ. Ninguna
  tiene ítem de munición detrás, así que no hay peso que reclamar (COR-5). El mismo hueco ya
  existía antes de este bloque: **el cinturón tampoco las alimenta**.
- **Un attachment puede cambiar el tipo, y el default de clase no lo ve.** §16.6 mide que
  ningún ammo-att de **EFT** setea `ATT.Ammo`, y es cierto — pero **ARC9MW tiene cuatro que sí**
  (`mw19_ammo_types.lua`: dos a `xbowbolt`, que Cargo maneja a 0,15 kg, y dos a un tipo propio).
  El árbol está en `blob.atts` desde el #53, así que es resoluble; queda **fuera del v1** porque
  su sede natural es el #55.
- **El tooltip sigue mostrando `def.weight`**, o sea el peso pelado del def. Un RPG cargado suma
  9 kg al total y muestra 6 en su ficha. No es nuevo —un chaleco con dos placas ya se comportaba
  así— pero este bloque lo vuelve más visible. Queda anotado, sin decidir.
- **Con `cargo_ammo_pool 0`** el poll no corre y el cargador sólo se refresca en las puertas de
  siempre. Es consistente: con el pool apagado, el modelo entero de §16 está apagado.

#### Enganche, y por qué no colisiona con el #55

Los dos enganches viven en `Instances.WeightOf` y son **términos distintos**: el #55 pesa el
cargador **como pieza** (`blob.atts`, `AttsWeight`, todavía sin llamar), éste pesa **las balas
adentro** (`blob.clip1`, `ClipWeight`). El único solape es de calibración y queda dicho por
adelantado: cuando el #55 aterrice, el peso que le dé a un cargador ampliado tiene que ser el
del **cargador vacío**, o las balas se cuentan dos veces.

---

## 17. Wheel menu (menú radial de armas)

*(Roadmap #31 — entry 13, con las enmiendas del hub del entry 16 (#33) y el **tercer
grupo de chips** del roadmap #46 (§17.8, entry 52). Archivo
[`client/corpus_cargo_wheel.lua`](../lua/corpus_cargo/client/corpus_cargo_wheel.lua).
Mockups congelados: `mockups/cargo_wheel_menu_mock_v2_1.html` y
`mockups/cargo_wheel_lights_mock_v1_1.html` (el grupo de luces) — mandan hasta que
exista el código; en divergencia, el código manda.)*

### 17.1 Principio rector — cero lógica de server nueva para el front-end de armas

**CRG-30 (enmendada por el roadmap #46, entry 53) —** El wheel es un **front-end
alternativo de las teclas 1-7**: el commit de un sector manda el **mismo intent
`slotkey`** que `corpus_cargo_hotkeys.lua`, y lo resuelve `corpus_cargo_holster.lua`
como hoy. Lo único que el bloque original sumó al server es que el resolver acepta los
**intents wheel-only** de `CARGO.Slots.WheelSlots` (**8 = throwable** — slots sin tecla
numérica propia); el cliente **jamás intercepta `slot8`** (queda stock GMod), solo el
commit del wheel lo emite. Los chips quick llaman a la ruta de quick use existente
(`CARGO.UI.QuickUse`); los chips de herramientas a `CARGO.UI.SelectTool` (§15.2), gated
por `cargo_ui_tools`. **Cero lógica de server nueva para el front-end de ARMAS.**

**La enmienda, y por qué se pagó:** el texto original decía además "cero mensajes de red
nuevos". El grupo de **luces** (§17.8) suma **un único intent de toggle sin payload**
(`corpus_cargo_torch`, `server/corpus_cargo_lights.lua`) porque `ply:Flashlight(bool)` es
**server-only** — la única de las tres patas del grupo que necesita canal. La alternativa
que respetaba la letra de la norma, `RunConsoleCommand("impulse 100")`, quedó descartada
**con medición** (cita CRG-24): con un arma ARC9 que tenga cualquier dispositivo
toggleable en la mano, `arc9/shared/sh_move.lua:360-369` **secuestra** el impulso y lo
reescribe a `IMPULSE_TOGGLEATTS` — la linterna no se enciende y en cambio cambia el modo
del dispositivo; la misma tecla haría cosas distintas según lo que lleves. Lo que la
norma protegía —no fabricar rutas paralelas de inventario— sigue intacto: el intent no
lleva estado, no persiste nada y no hay validación que un cliente hostil pueda fabricar
(CRG-6 en pie).

**La enmienda estaba INCOMPLETA, y lo destapó la planilla V (2.ª pasada).** La 1.ª pasada
**midió** que *escribir* la linterna necesita canal y **asumió** que *leerla* no —
`ply:FlashlightIsOn()` se usó desde el cliente como si fuera shared. Es server-only en las
**dos direcciones**, y la medición en juego es inequívoca: con el haz visiblemente
pintando una pared y **sin** arma ARC9 en la mano,

```
lua_run    print(Entity(1):FlashlightIsOn())        -> true
lua_run_cl print(LocalPlayer():FlashlightIsOn())    -> false
```

así que el chip nunca podía pintar ON. El remedio es un **espejo**: el server publica el
estado real en `NW2Bool "cargo_torch"` (`CARGO.Lights.PublishTorch`), el mismo vehículo
que ya usa el multiplicador de peso por la misma razón (#34, `server/corpus_cargo_movement.lua`)
— **replicación del engine, no un segundo mensaje de red: la enmienda sigue en UN intent.**
El espejo lee el **engine**, no nuestros toggles, y eso no es un detalle de comodidad:
Cargo **no es el único escritor** por diseño —la tecla del engine jamás se intercepta, y
ARC9 apaga la linterna en su `PostModify` de server (`sh_attach.lua:143-145`) cuando el
arma lleva un att `ToggleOnF`—, así que un espejo alimentado por nuestros propios commits
se desfasaría en cuanto escribiera cualquier otro, que es el pecado de CRG-64 en el otro
tiempo verbal. Ritmo 4 Hz, el mismo del espejo cinturón↔pool (§16.3-16.5), más publicación
inmediata en el receiver para que el commit propio no espere un tick.

**La lección, y es de método:** el error no fue la norma sino *dónde se dejó de medir*.
CRG-24 existe para no asumir la API de un tercero — acá se asumió la del **engine**, que
es el tercero que más fácil se olvida que lo es.

### 17.2 Geometría y render

- Dibujo por **HUDPaint sin VGUI**: cursor libre con `gui.EnableScreenClicker`, que **se
  traga los clicks como input de JUEGO** —nada dispara mientras se apunta el wheel, y ésa
  es exactamente la razón de encenderlo—. Lo que **no** hace es ocultar el **estado** del
  botón: desde #48 el wheel lo lee para ofrecer el click como segunda forma de commit
  (§17.4), y eso se **midió en juego antes de escribirlo** (planilla W). Teclado y
  movimiento quedan con el juego.
- **Una sola función de layout** (`CARGO.Wheel.BuildLayout`) resuelve centro, radios y
  cajas de chips; sectores, hub, chips y el pick beben todos de ahí (el bug del mock v1
  fue exactamente dos sistemas de escala desincronizados). Escala **uniforme** sobre
  `ScrH`: mock viewBox 1200×800, referencia @1080 → hub 120 px, borde exterior 305 px.
- **Los números de referencia @1080 viven en UNA tabla** (`REF`: hub 120, anillo 305,
  margen 46, celda 56, gap entre celdas 8, gap entre grupos 24, celda ancha 150), que
  consumen tanto `BuildLayout` como las funciones puras. Una segunda copia de esos
  números **es el bug del mock v1 otra vez**, y por eso la cuenta del extremo de un grupo
  —`CARGO.Wheel.GroupOuterExtent(push, cellLong)`, en unidades @1080— **lee de ahí** en
  vez de repetir la aritmética.
- **La celda es POR GRUPO, no una constante** (#48). El resolvedor de cajas (`GroupCells`)
  toma `(w, h)` en vez de cerrar sobre un único `chip`, y **qué celda le toca a cada grupo
  es una regla pura y cubierta**: `CARGO.Wheel.GroupCellSize(anchor, w, h)` **clampea `w`
  a `h` cuando el eje es horizontal**. Escrita como clamp, la degradación de la celda
  ancha (§17.8) **no es un caso especial en ninguna parte: ES el clamp**, y las dos
  anatomías coexisten en el mismo build. Quick y tools piden la cuadrada **en el call
  site**, así que la excepción jamás los alcanza.
- **6 sectores anulares de 50° con gaps de 10°**, triangulados como quads convexos
  (~5° por paso) vía `surface.DrawPoly` (un sector anular no es convexo; DrawPoly abanica
  desde su primer vértice). **Nada de texturas horneadas** — todo color lee el theme, así
  el teñido de §15.5 re-tiñe el wheel entero gratis.
- **Contenido del sector agrupado en el radio medio** (enmienda del entry 16 — el mock
  nunca tuvo labels sueltos en el borde): línea de info **encima** del ícono (`×N` del
  stack / `cargador / reserva` del arma / el label del slot cuando ninguna aplica); label
  solo en sectores **vacíos**. Punto de acento del arma en mano **fuera** del anillo
  (`rOut + 12`).

### 17.3 Mapa de sectores (posiciones de reloj)

| Reloj | Slot | Intent `slotkey` |
|---|---|---|
| 12 | Primary | 3 |
| 2 | Sidearm | 2 |
| 4 | Melee | 1 |
| 6 | Hands (holster) | 0 |
| 8 | Throwable | 8 (wheel-only) |
| 10 | Secondary | 4 |

### 17.4 Interacción

- **CRG-31 — Hold** abre, **soltar commitea**. Tecla por convar `cargo_key_wheel` (default `G`,
  polleada en Think — el patrón de binds probado del proyecto) o `+cargo_wheel`/
  `-cargo_wheel` para binds de consola. Si la tecla ya tiene un bind del engine, **aviso
  único** por `Corpus.Log` (regla del autor: jamás pisar un bind en silencio — el engine
  bind no se toca, ambos disparan).
- Soltar en la **deadzone** (hub) o **fuera del anillo** = cancelar. Sector **vacío** =
  **no-op honesto** (el hub lo dijo en el hover). Re-seleccionar el sector del arma **en
  mano** = **enfundar** — la misma semántica del re-press de las teclas (#22); decide el
  server. ESC o muerte cancelan sin commit.
- El **pick re-corre al soltar** (el cursor pudo moverse tras el último frame pintado).
  Dentro del anillo el pick es por **sector más cercano** al ángulo del cursor — los gaps
  de 10° perdonan. El cursor arranca centrado en la deadzone, como el mock. Chips primero:
  un cursor sobre un chip **nunca** activa un sector.
- **El CLICK es una segunda forma de comitear, y es ADITIVA** (roadmap #48, decisión del
  autor 2026-07-29; convar `cargo_wheel_click`, cliente y archivada, default **1** — a
  diferencia de la celda ancha, ésta **suma** un gesto y no cambia ninguno). **CRG-31 no
  se deroga y hay que leerlo así**: soltar la tecla sobre algo sigue comiteando
  exactamente como siempre, que es el gesto ya en el músculo; el click se suma para el
  pausado. Va por la **MISMA ruta** —`CARGO.Wheel.Close(true)` → `Commit`, mismo pick
  re-corrido, mismo `pcall` de CRG-25—: **cero lógica de commit nueva**.
  **Polleo con detección de flanco en el mismo `Think` de la tecla**, no un hook de mouse
  nuevo, y eso significa que **no estrena una sola API del engine**: `input.IsButtonDown`
  es la función que ese hook ya llamaba por frame, sólo que preguntando por `MOUSE_LEFT`
  en vez de un enum `KEY_` — el mismo espacio de `BUTTON_CODE`. Lo único que era
  asunción se **midió en juego antes de escribir una línea** (planilla W, W1): el screen
  clicker se traga el click como input de juego pero **no** impide leer el estado del
  botón por debajo — la misma maquinaria que usa el menú contextual del propio GMod.
  **Un solo commit por apertura, por construcción**: el click cierra el wheel y
  `Close` sale temprano con `state` nil, así que soltar la tecla después no dispara un
  segundo commit. No hace falta bandera; hace falta **probarlo en negativo**, y el
  harness lo prueba. **El flanco del botón se observa SIEMPRE**, abierto o cerrado: si
  sólo se siguiera con el wheel abierto, abrirlo con el botón de disparo ya apretado
  leería como pulsación nueva y comitearía en el acto. **El botón derecho no se toca**:
  una acción alternativa (ciclar el modo de un dispositivo hacia atrás, que ARC9 soporta)
  es bloque propio.
- **El modo que NO cierra** (roadmap #49; convar `cargo_wheel_click_sticky`, cliente y
  archivada, **default 0** — el default del #48 no cambia para nadie). Un click sobre un
  **chip de luz** ejecuta el toggle **en el lugar** y deja el wheel abierto, así que N
  clicks son N ciclos sin reabrir. **Sólo las luces**, y el motivo es el vocabulario que
  §17.6/§17.8 ya fijaron: los sectores *equipan*, los quick *usan*, las luces *togglean*,
  y **togglear es el único verbo repetible** — equipar dos veces es enfundar (#22) y usar
  dos veces gasta dos ítems. Sobre sector, quick o tool el click sigue comiteando y
  cerrando. **Al soltar la tecla: si hubo un click sostenido en esa apertura, sólo
  cierra**; si no hubo ninguno, comitea igual que siempre — o sea **CRG-31 queda literal
  en el camino default** y la excepción sólo existe tras un gesto que el jugador pidió.
  Sin esa regla, terminar de ciclar dispararía un toggle de más. La política vive en
  `CloseOnRelease` y **no dentro de `Close`**, que sigue siendo un "comitea o no, vos
  decidís" tonto porque el camino del click necesita la respuesta contraria; la consumen
  el poll de `Think` y el concommand `-cargo_wheel`, que así no se desincronizan.
- **El botón DERECHO cicla en reversa** (roadmap #50; pedido del autor en la nota de un check
  que PASÓ). Se pollea en el **mismo `Think` y por el mismo camino** que el izquierdo
  —`ClickCommit(back)`—, porque el gesto es idéntico salvo el sentido: un solo código, no una
  copia que derive. Hereda gratis el modo del #49 y la convar `cargo_wheel_click`.
  **Sólo actúa donde hay reversa**: el registro de fuentes gana **`toggleBack(ply, wep)`
  opcional**, y su ausencia es la respuesta honesta y no una carencia — **una linterna no
  tiene reversa**, y tampoco la tiene nada más del wheel: *desequipar no es "equipar hacia
  atrás"* y un quick slot no tiene undo (CRG-32). Sobre cualquier otra cosa el derecho **no
  hace nada y tampoco cierra**. La pata ARC9 es `ToggleStat(addr, -1)` + `PostModify()`,
  **verificada contra `dev/other/`** (CRG-24, `sh_attach.lua:718-735`): `val = val or 1` y el
  wrap está escrito en **las dos direcciones** (`> #ToggleStats → 1`, `< 1 → #ToggleStats`),
  o sea que ARC9 **anticipó** el paso negativo; `ToggleStat` **no** llama a `PostModify`, y un
  dispositivo de un solo modo envuelve sobre sí mismo — no-op honesto, jamás un error.

### 17.5 Hub central = superficie de información universal

Todo lo que recibe hover alimenta el hub — sectores, chips quick, chips de tools y la
deadzone (que muestra lo que hay en mano y ofrece la salida). **CRG-32 — Ningún dato se inventa:**

- **Cargador / reserva** → `CARGO.Wheel.AmmoInfo`, con las rutas **verificadas contra el
  ARC9 vivo** (2.ª pasada, 2026-07-13): el tipo de munición sigue la ruta del propio
  `Ammo1()` de ARC9 (`GetProcessedValue("Ammo")`, `sh_reload.lua:578`), con respaldo en el
  campo plano `SWEP.Ammo` (dato estático de clase, legible aun sin estado procesado en el
  cliente) y recién después `GetPrimaryAmmoType` (**no confiable en ARC9**: el
  `Primary.Ammo` de clase es `""` y solo `Initialize` lo corrige por instancia — queda
  como última pata, para armas del engine). El clip cae al espejo `GetLoadedRounds`
  (NetworkVar broadcast) cuando `Clip1` responde -1. La **reserva se lee del pool del
  engine**, que el espejo de §16 mantiene igual al cinturón — se lee, no se recalcula.
- **Calibre** → los defs autogen nacen/upgradean con `def.ammo.caliber` resuelto del arma
  viva y persistido (#33); la etiqueta es **la del pool de Cargo** — la misma con que
  agrupa el cinturón (§16.2); el calibre EFT real solo existe como token de trivia sin
  API (decisión anotada). Cuando el def no la trae, `CARGO.Wheel.CaliberOf` la deriva en
  runtime del tipo del arma viva.
- **Fire mode** → solo ARC9, COMPAT-RUNTIME: `SWEP:GetFiremodeName()` (verificado,
  `sh_firemodes.lua:158`); si no está, el campo **se oculta** — jamás se adivina.
- **Condición** → blob de instancia; barra segmentada, `< 25%` pinta en danger. **×N** del
  throwable: el count ES la línea de munición.
- **CRG-26 —** El círculo del hub (y el marcador de en-mano) pintan con **`Theme.DrawCircle` /
  `DrawCircleOutlined`** — la **primitiva única de círculo** del theme (polígono
  triangulado, 32/48 segmentos según radio; `draw.RoundedBox` con radio mitad NO es un
  círculo — su radio está cuantizado a los materiales de esquina). La consumen también los
  círculos sandbox de la columna y el botón `$` del header (#21).
- **CRG-64 — Un indicador de un estado ASÍNCRONO de un tercero pinta el TRÁNSITO; jamás
  pinta el estado viejo como si fuera el actual.** Es la hermana de CRG-32 en el eje del
  **tiempo**: aquella prohíbe inventar un dato que no se tiene, ésta prohíbe afirmar uno
  que ya no vale. El caso que la acuña está **medido contra el código vivo del mod**
  (cita CRG-24): `ArcticNVGs_Toggle` (cl_arctic_nvg.lua:13-57) reproduce la anim de
  VManip y espera el `EquipDelay` de la variante (1,325 s en las GPNVG) **antes** de
  invertir `nvg_on` y avisar al server — un chip que pintara la NW mostraría el estado
  viejo más de un segundo. El chip de NVG del wheel (§17.8) pinta el tránsito con la
  duración que **reporta el mod por variante** y **por dirección**, y durante la ventana
  no afirma **ni** el estado viejo **ni** el nuevo. Entry 52; en juego, planilla V
  (checks V2 y V7).
  > **Corrección de la 2.ª pasada (planilla V, ronda 3).** Este párrafo decía *"ninguna
  > variante declara `UnequipDelay`, así que el apagado invierte sin ventana"*. **Es
  > falso**: las **12 variantes `shades*`** (las aviators) declaran `UnequipDelay = 0.25`
  > (`sh_arctic_nvg.lua`, 14 apariciones contando el comentario de cabecera). La 1.ª
  > pasada leyó las GPNVG y **generalizó de una muestra** — la misma familia de error que
  > CRG-24 nombra, en el otro sentido. Lo destapó la nota de un check que **PASÓ**: *"el
  > NVG tiene animación al hacer off también"*. **El código nunca compartió el error**:
  > lee `variant.UnequipDelay` en la pata de apagado, con una rama por dirección
  > justamente para no caer por un `or` encadenado — así que con aviators el chip **ya
  > pintaba** su tránsito de 0,25 s al apagar. Lo que estaba mal era la prosa.
  > Y hay un matiz que la nota también obliga a separar: **la animación de VManip existe
  > en las dos direcciones siempre** (`VManipOut`, 61 variantes) — lo que depende de la
  > variante es si el **estado** espera a que termine. En las de tubo el estado invierte
  > al instante y la animación corre después; ahí el chip diciendo OFF es correcto.

### 17.6 Chips

- **Quick F1-F4**: fila de 4 chips **rectangulares** — verbo distinto = forma distinta
  (se **usan**, no se equipan; mezclar ambos verbos en sectores del mismo anillo es error
  de UX). No participan del pick angular. Candado del traje respetado (mismo hatching de
  la UI fullscreen, recortado con **scissor** — **CRG-28:** HUDPaint no tiene clipping de
  panel);
  vacío = no-op honesto. El commit llama a la ruta de quick use existente.
- **Tools sandbox**: mismo comportamiento que los círculos de la columna
  (`CARGO.UI.SelectTool`), mismo gate `cargo_ui_tools`.
- **Anclajes configurables** (pedido del autor): `cargo_wheel_quick_anchor` (default
  `bottom`) y `cargo_wheel_tools_anchor` (default `right`), valores
  `bottom·top·left·right`, con un **resolver de anclaje único** (`ResolveAnchors`) que
  sirve a ambos grupos. Dos grupos no comparten lado: si colisionan, **quick gana** y
  tools cae al anclaje libre más cercano, con aviso único por `Corpus.Log` — se resuelve
  en el layout, jamás con un error.
- Toda la configuración (habilitación `cargo_wheel`, tecla, anclajes) vive en el **tab de
  Cargo del menú Q**, junto al resto de las opciones del módulo.

### 17.7 Robustez (pagada in-game, 1.ª pasada 2026-07-13)

- **CRG-25 —** GMod **desengancha** un hook de HUDPaint que erra: un hover malo y el wheel muere en
  silencio la sesión entera (la forma exacta de la falla reportada). Pintado y commit
  corren en **pcall** con `Corpus.Log` ruidoso — el error se loguea una vez, con línea, y
  el wheel sigue vivo.
- `gui.MousePos` se lee **antes** de apagar el screen clicker: apagado, no está
  garantizado que siga reportando la posición del cursor libre.
- El primer open de una sesión puede preceder cualquier sync de inventario: se pide un
  snapshot con el intent `open` existente (el mismo que usa la UI).

### 17.8 Tercer grupo de chips: las LUCES (roadmap #46 — entry 52)

*(Mockup congelado: `mockups/cargo_wheel_lights_mock_v1_1.html`, bloques 01-05, con sus
dos capturas hermanas. El bloque **06 está implementado** (celda ancha, roadmap #48 — ver
más abajo); los bloques 07/08 siguen **aprobados y DIFERIDOS** — ver el roadmap. Archivos:
el registro y el render en `client/corpus_cargo_wheel.lua`; las tres fuentes en
`client/corpus_cargo_lights.lua`; el único net en `server/corpus_cargo_lights.lua`.)*

Los sectores del anillo son *equipar*; los chips quick son *usar*; las luces son un
**tercer verbo, *togglear*** — §17.6 ya declara que mezclar verbos en el mismo anillo es
error de UX, y por eso la respuesta es un **grupo propio** con la misma forma rectangular
y el mismo pick no-angular. El motivo del pedido (autor): la G era a la vez el wheel de
Cargo y su linterna; la lista viaja ahora en la tecla del wheel —que ya es hold— y la
tecla de linterna queda **libre y sin tocar** (`impulse 100` no se intercepta jamás:
es el defecto caro de TLS, no su idea). Cubre además lo que ni TLS ni el radial propio de
ARC9 cubren: **un solo dispositivo** (el radial de ARC9 exige ≥2) y fuentes que **no**
están en el arma en mano.

- **El registro de fuentes** — `CARGO.Wheel.RegisterLightSource(id, spec)`, tercer
  precedente vivo del patrón (tras `StatusPanel.RegisterBar` §11 y
  `Capture.RegisterWorldPickup` #47). La lista **se registra, no se hardcodea**: un
  chemlight que mañana sea ítem de Cargo entra como fuente sin tocar el wheel, y el dueño
  de su lógica es el módulo del ítem (CRG-1). `spec`: `label`, `icon`,
  `available(ply, wep)` (¿existe AHORA? — corre **al abrir**, la lista jamás se arma por
  frame), `state(ply, wep)` (qué pintar — corre por frame porque el tránsito anima:
  `on`/`mode`/`emitters`/`transit`), `toggle(ply, wep)` (el commit) y `expand` opcional
  (una fuente, N chips — los dispositivos ARC9, uno por slot toggleable). **Una fuente
  que no está NO se adivina** (CRG-32 aplicado a la columna): sin ARC9 no hay chips de
  dispositivo, sin el mod de NVG no hay chip de NVG, sin dispositivos en el arma la
  columna tiene dos chips y ya.
- **Anclaje y colisión** — convar `cargo_wheel_lights_anchor`, default **`left`**
  (enfrentado a tools, que defaultea a `right`). `ResolveAnchors` **no se tocó** (es
  pura, cubierta, y su regla —dos grupos no comparten lado— sigue siendo la de quick y
  tools). El tercer grupo tiene **su propia regla** (pedido del autor):
  `CARGO.Wheel.LightsPushOut(lights, quick, tools, toolsShown)` — las luces **SÍ pueden
  compartir lado, desplazadas hacia AFUERA**: lado libre → 0; lo ocupa quick, o tools
  visible → 1; los tres → 2 (inalcanzable vía convars — `ResolveAnchors` nunca deja a
  quick y tools juntos — pero la función pura contesta todo su dominio). El offset va en
  el eje del anclaje: cada ocupante cuesta un fondo de grupo (56) más `gapGrupo` = **24
  @1080p** contra los 8 entre celdas (8 adentro vs 24 afuera ya lee como bloques — el
  mock rechazó toda marca de agrupación), todo en unidades de theme escaladas por
  `L.scale`. Orden fijo hacia afuera: **quick → tools → lights**. Aviso único por
  `Corpus.Log` cuando el empuje se activa — jamás un error, jamás en silencio.
- **El chip: tres canales independientes que no se pisan** (mock bloque 02) — celda
  56×56 intacta. **Estado** = relleno (`accentDim` ON / `cell` OFF). **Tránsito** =
  borde `amber` + barra de progreso de 4 px al pie + ícono amber al 55% — es el ÚNICO
  canal que usa amber, así que nunca se confunde con ON (acento) ni con OFF (`textDim`),
  y es **CRG-64** hecho pintura. **Hover** = relleno y borde suben un escalón, y jamás
  toca el canal de color del estado (el tránsito además le gana al hover en el borde).
  **En la celda CUADRADA el modo NO va como texto**: se comprime a **barras de color de
  3 px** en el borde inferior, una por **emisor activo** — léxico del mock: luz visible =
  accent, láser visible = green, iluminador IR = orange, láser IR = red; geometría
  46/22/14 px según 1/2/3 barras. El nombre completo del modo (`Light + Green Laser`)
  vive en el hub (y, desde #48, también en la celda ancha). **Regla del pie** (mock, y
  mata la ambigüedad): al pie **sólo se dibuja lo que está pasando** — el track del
  tránsito existe mientras el tránsito, las barras de modo mientras haya emisores
  encendidos; nada de rieles vacíos. Sin ícono montado, el chip cae a su inicial (título
  20/700) — degradación honesta.
- **Variante de CELDA ANCHA** (roadmap #48, mock bloque 06; convar
  `cargo_wheel_lights_wide`, cliente y archivada, default **0** — la forma de hoy no
  cambia sola para nadie). 150×56 @1080 escaladas por `L.scale`, con **dos condiciones
  duras que son del mock y no se negocian**: **(1) sólo con anclaje `left` o `right`** —
  con `top`/`bottom` el grupo **degrada solo a 56×56 en el MISMO build**, sin aviso y sin
  error, porque una fila de celdas de 150 no entra en el eje horizontal (lo hace el clamp
  de `GroupCellSize`, §17.2, no una rama aparte); **(2) quick y tools siguen cuadrados
  siempre** — la celda ancha es la excepción del **panel de luces**, no un modo nuevo del
  menú. Lo que gana: el **modo se lee sin hoverear**. Pinta los **mismos tres canales**
  (estado / tránsito / hover — es más ROOM, no un lenguaje nuevo) más el **nombre** y la
  **línea secundaria**, que es exactamente la del hub —tránsito > nombre del modo >
  ON/OFF— resuelta en **una sola sede** (`LightSecondary`) y no en dos copias que
  derivarían. **El pie:** el track del tránsito se pinta igual en las dos anatomías; las
  **barras de modo NO se pintan en la ancha**, porque el nombre del modo dice más de lo
  que ellas codifican — **con una excepción declarada**: un dispositivo que expone
  emisores como DATO pero **no declara `PrintName` de su modo** (ARC9 lo permite) sí las
  conserva, porque ahí no hay nombre que las reemplace y el hub las omite por ese mismo
  motivo; sin esa excepción, esos emisores quedarían invisibles en todas partes.
- **El empuje NO lo cambia la celda ancha** (#48): el multiplicador es el fondo del
  **OCUPANTE** —quick o tools, cuadrados por definición—, y lo ancho sólo extiende el
  borde exterior del propio grupo. **La advertencia de desborde del mock está mal y se
  corrige con la cuenta**, no con una opinión: el grupo crece hacia AFUERA desde la misma
  línea de anclaje, así que el extremo queda en `305 + 46 + push·(56+24) + 150` = **501 /
  581 / 661** @1080 para empuje 0 / 1 / 2. El layout **escala por altura**, de modo que a
  1280×720 son **~334 / ~387 / ~441 px reales** contra los 640 de media pantalla:
  **entra** — y quedó **medido en juego a 16:9** (planilla W, W4), no sólo calculado. El
  **4:3 sigue sin medir** y es la frontera declarada. **push 2 es inalcanzable por convars**
  (`ResolveAnchors` nunca deja a quick y tools en el mismo lado). Queda fijado en el
  harness sobre `GroupOuterExtent` para que **nadie re-herede la advertencia sin
  recalcularla** — que es exactamente el error que #46 pagó con el `UnequipDelay` copiado
  de la prosa. **El mock no se edita**: es sede congelada; la corrección vive acá, en el
  CHANGELOG y en el roadmap.
- **Las tres patas, con su procedencia** (todo verificado contra `dev/other/`, CRG-24,
  anotado en el header de `client/corpus_cargo_lights.lua`):
  **(1) Torch** — el commit es el **único intent nuevo** (§17.1, la enmienda de CRG-30):
  net sin payload → `ply:Flashlight(not FlashlightIsOn())` en el server. Lo que **pinta**
  es el **espejo** `NW2Bool "cargo_torch"` que publica ese mismo archivo, **no**
  `ply:FlashlightIsOn()` desde el cliente: es ilegible ahí (§17.1, medido en la planilla V
  — la 1.ª pasada lo asumió shared y por eso el chip nunca encendía). El espejo sigue al
  engine, así que la tecla libre y el `PostModify` de ARC9 quedan cubiertos por
  construcción. **No se pinta tránsito** acá, a diferencia del NVG: el ida y vuelta son
  unos frames de latencia del engine, que este mismo diseño ya declara que no es mentira.
  **Frontera medida y NO peleada** (§13): con un arma ARC9 con dispositivo **desplegada**
  el haz de la linterna del engine **no se dibuja** —vuelve al cambiar a un arma sin
  dispositivo, con el estado de server en `true` todo el tiempo—.
  **CORRECCIÓN (#51): el MECANISMO que este doc afirmaba está mal.** Se decía "supresión de
  render de ARC9", y el código no lo sostiene: grepeada la base entera, ARC9 toca la linterna
  del engine en **un solo lugar** (`sh_attach.lua:143-144` — `PostModify` la **apaga** si el
  arma tiene un att `ToggleOnF`) y **no hay ninguna ruta de supresión de render** para ella
  (todos los `render.SuppressEngineLighting` son de VGUI/FLIR/presets, o sea previews). El
  mecanismo real **no está identificado**; la hipótesis viva es el presupuesto de projected
  textures del engine, que las luces del dispositivo consumen — y **queda anotada como
  hipótesis**. La CONDUCTA sigue medida y es lo que se pinta. Era una **inferencia redactada
  como medición**, el mismo error que el `UnequipDelay`.
  Desde #51 el chip **deja de decir sólo ON**: se pinta **tapado** (tramado de quickslot) y el
  hub dice quién se quedó con la luz. `on` **no** se falsea a `false` —sería la mentira de
  CRG-32— porque *encendida pero invisible* es un **tercer** hecho: **estado y disponibilidad
  son preguntas distintas**. **(2) NVG de Neosun** — aparece si `GetNWInt("nvg", 0) ~= 0` (decisión
  declarada: el chip pregunta por la **NW**, no por el ítem — la NW es lo que
  `arc_vm_nvg` va a accionar y desde #47 **es** la resolución de Cargo replicada;
  preguntar al snapshot re-implementaría `EquippedShortName` en el cliente, una segunda
  ruta). El commit es `RunConsoleCommand("arc_vm_nvg")`, cliente puro; **jamás escribe la
  NW `nvg`** (esa es de #47, escritor único). El toggle es **asíncrono** y el chip pinta
  el **tránsito** (CRG-64) con el delay que reporta la variante del mod, **por dirección**
  — las 12 aviators (`shades*`) declaran `UnequipDelay = 0.25` y las de tubo no, así que
  el apagado tiene ventana en unas y no en otras (corregido en §17.5: la 1.ª pasada
  afirmaba que ninguna la declaraba). El rechazo en
  esta pasada es **MUDO**: durante la ventana el toggle no re-entra (re-entrar encolaría
  un segundo timer dentro del mod). **(3) Dispositivos ARC9** — uno por `slottbl` de
  `GetSubSlotList()` con `.Installed` cuyo att declare `ToggleStats` + `ToggleOnF`. El
  commit es el del radial propio de ARC9 (`cl_move.lua:153-163`): `wep:ToggleStat(addr)`
  + `wep:PostModify()`, **client-side, replica solo** por `SendWeapon` — el mismo
  contrato que CRG-23 (§10.3). Las **barras de modo salen de los EMISORES del merge**:
  `GetFinalAttTable` fusiona `ToggleStats[ToggleNum]` sobre la tabla del att
  (sh_0_stats.lua:86-89), así que `Flashlight`/`Laser`/`FlashlightIR`/`LaserIR` del modo
  activo son **datos**. Si un att no expone emisores en ningún modo, **el string del
  modo NO se parsea**: ese chip va sin barras y el modo queda sólo en el hub. **El
  estado de un dispositivo pertenece al slot del arma** (`slottbl.ToggleNum`, de ARC9) —
  guardarlo en el JUGADOR es el defecto de TLS que no se porta.
  > **Enmienda 2026-07-30 (roadmap #53, decisión del autor).** Esta línea decía que *Cargo
  > no persiste nada de esto*. Desde el #53 **sí lo persiste, y sin contradecir lo de
  > arriba**: el modo viaja en el campo `mode` de un nodo de `blob.atts` (§10.5), o sea
  > **colgado de la instancia del arma**, que es exactamente donde la frase original dice
  > que pertenece. Lo que sigue prohibido —y es lo que la línea siempre quiso decir— es
  > guardarlo en el jugador. Sin esto, un dispositivo en IR volvía en `Off` cada vez que el
  > arma cambiaba de manos, y el pedido del autor era que *toda* la configuración viaje.
- **El hub sirve también a estos chips** (§17.5, CRG-32): dos líneas + hint — principal
  = qué cosa es; secundaria = ON/OFF o el nombre del modo tal cual lo da el mod (o
  `OFF → ON` en tránsito, que no afirma ninguno de los dos — CRG-64); hint = `Release
  to toggle`. Sólo el tránsito agrega la barra segmentada. Ningún chip lleva tooltip
  propio, y un chip hovereado **jamás** activa un sector (§17.4).
- **Regalo verificado, no asumido:** ARC9 ya conoce el mod de NVG — `cl_light.lua:16-24`
  lee `nvg_on` para conmutar los flashlights `FlashlightIR` a infrarrojo. NVG + luz IR
  del arma ya se entienden sin una línea nuestra (se confirma en juego, planilla V). Y la
  interacción inversa, también medida: el `PostModify` de **server** de ARC9 apaga la
  linterna del engine si el arma tiene un att `ToggleOnF`
  (sh_attach.lua:143-145) — togglear un dispositivo con la linterna prendida la apaga,
  es regla del propio mod sobre su tecla F compartida y **no se pelea**.

