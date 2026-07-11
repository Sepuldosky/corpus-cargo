# Cargo — CHANGELOG

> Historial de parches del repo `corpus-cargo/`. Cada entry nace `[PENDIENTE]` y pasa
> a `[APLICADO YYYY-MM-DD]` **solo tras verificación en juego** (flujo §1 PASO 4-5).
> Nunca se borra ni se renumera un entry.

---

## 1. Block 1 — vertical slice del inventario `[APLICADO 2026-07-10]`

Primer contenido real del repo. Baja a código `Cargo_Architecture.md` §3–§12 completo
(el banco de trabajo de `Workbench_Arquitectura.md` queda explícitamente FUERA — es su
propio bloque futuro):

1. **Registro del módulo** (`corpus_cargo_init.lua`): patrón template de Caliber —
   boot diferido a `Initialize`, sonda de primitivas, manifest explícito, bloque
   CONTRACT, falla ruidoso sin Corpus.
2. **Contrato de ítems** (§3): `Cargo.Items.Register` con clases `stackable`/`unique`,
   schema base (id/name/weight/class/category/icon/display_stats/trivia) + campos
   transportados sin interpretar; blob de instancia con mínimo genérico (condición,
   zonas, sub-slots, grupo de munición A/B).
3. **Sub-slots** (§4): primitivo único `Cargo.Items.DeclareSubSlot` + filtro
   `"category:a,b"` compartido con los slots; sirve óptica-Head, exo/escudo-Body
   (enganche Caliber B3) y placas-Body. Eyección obligatoria antes de destruir.
4. **Slots de equipamiento** (§4): Head/Body/Back, Primary/Secondary/Sidearm, Melee,
   PDA, Detector, quick F1–F4 con disponibilidad gated por el traje (Body). Back como
   modificador de capacidad. Armas de engine se dan/quitan al equipar (weapon_class).
5. **Peso y movimiento** (§5): curva continua pura (1.0 → 0.65 en el límite → piso
   0.15 en 2×) aplicada a walk/run sobre base capturada; tope duro de carga en 2×
   capacidad; lazy-check a `coagulant.OnEncumbrance` (contrato congelado esperado).
6. **Providers** (§6): interfaz dinero get/add/take/format + provider nativo USD
   (persistido en el record); facción/rango solo se renderiza si
   `cortex.GetFactionInfo` existe (lazy + pcall, header la omite si no).
7. **Persistencia** (§12): namespace `cargo` — `inv_<steamid64>`, `inst_<uid>` (un
   archivo por instancia), `cont_<key>`; re-normalización de claves numéricas tras el
   round-trip JSON (quick slots) en ambos realms.
8. **Net**: 17 mensajes vía `Corpus.Net.Register("cargo", …)`, payloads como JSON
   comprimido; el server posee el inventario, el cliente manda intents.
9. **UI** (§7/§9/§10/§11 + mockups): grid uniforme con overlays por esquina
   (stack ↗, condición ↘, efecto/calibre ↙), header de perfil (Steam + facción
   provider + dinero provider), panel de estado con `StatusPanel.RegisterBar`,
   footer de peso con desglose base+mochila y color por proximidad, tooltip de
   inspección (stats ARC9 absolutos o display_stats manuales, zonas, placas,
   sub-slots, capacidad de mochila), menús contextuales + drag&drop (equipar,
   insertar en sub-slot, acoplar, bindear, transferir), sonidos inv_open/close.
10. **Contenedores en mundo** (§8): panel lado a lado con Take all/Move all,
    capacidad por contenedor (finita o infinita), rango de uso, persistencia
    opcional por key; entidades `corpus_cargo_crate` (caja de prueba spawnable) y
    `corpus_cargo_item` (drops, eyección al mundo).
11. **Puente ARC9** (§10.3, verificado contra `dev/other/` el 2026-07-10): Cargo
    como almacén único vía hooks `ARC9_PlayerGetAtts/GiveAtt/TakeAtt` (con takeover
    de `arc9_free_atts`→0), attach/detach por la API propia de ARC9
    (`SWEP:Attach`/`DetachAllFromSubSlot`, client-side), auto-registro de los
    attachments del pack como ítems (respetando `InvAtt`/`Free`), stats lectura-only
    con las claves reales (`DamageMax`/`Spread`/`RPM`/`ClipSize`).
12. **Dev harness**: `cargo_selftest` (26 checks server / 19 client), kit demo
    `cargo_dev_give`/`cargo_dev_money`, barras demo del panel de estado
    (`cargo_dev_bars`).

**Verificación previa (2026-07-10):** sintaxis 21/21 + harness offline LuaJIT con
stubs de GMod y el framework real de `corpus/` — selftest y 31/7 checks de
integración (server/client) en verde, ambos realms.

**Verificado en juego por el autor (2026-07-10):** carga, kit dev, equipar
(incl. armas a slots para usarlas), peso→velocidad, quick slots, contenedor con
Take/Move all. Observaciones registradas y corregidas en el entry 2: refresco de
la caja en la primera transferencia, celdas cortadas, textos desbordados, ítems
en español, slots PDA/Detector demasiado STALKER, y sin ruta de adquisición de
attachments ARC9 (el puente en sí funcionó: menú C bloqueado = Cargo es el almacén).

---

## 2. Fixes de la primera pasada en juego + captura de armas `[APLICADO 2026-07-11]`

Correcciones y alcance nuevo salidos de la verificación del autor (2026-07-10):

1. **Fix grid (causa raíz de dos síntomas):** `DIconLayout` con `Dock(FILL)`
   dentro de `DScrollPanel` colapsa (canvas se dimensiona a los hijos mientras
   el hijo llena el canvas) — celdas recortadas por abajo y el panel del
   contenedor no repoblaba tras la primera transferencia hasta reabrir. Ahora
   `Dock(TOP)` + `InvalidateLayout(true)` en cada refresh. Trampa nueva anotada
   en CLAUDE.md junto a las heredadas de ADS.
2. **Slots genéricos:** PDA/Detector (mobiliario STALKER) → **Accessory 1/2**
   con categoría única `accessories`; categorías `pda`/`detector` eliminadas de
   los filtros. Remap automático de saves legacy (`equip.pda→accessory1`,
   `equip.detector→accessory2`) al cargar el record.
3. **Idioma del mod = inglés:** todo string de cara al jugador pasado a inglés
   (nombres/trivia de ítems dev, títulos de panel, tabs, menús contextuales,
   notices, tooltip, transferencia, tab Q, helps de convar). Los logs de consola
   (`Corpus.Log`) siguen en español, precedente Caliber.
4. **Captura de armas del engine (pedido del autor):** nuevo
   `corpus_cargo_capture.lua` — `PlayerCanPickupWeapon` intercepta toda arma que
   el engine entregue (loadout base: physgun/toolgun/cámara, mods tipo Quick
   Loadouts, armas de mundo) y la convierte en ítem de inventario (def
   autogenerada con `autogen`, sync de defs al cliente con resolución de tokens
   `#HL2_*`). Dedup por clase (el loadout no duplica por respawn), la entidad
   bloqueada se limpia, y el flujo de equip propio la salta vía flag. Convar
   `cargo_capture_weapons` (default 1). `CARGO.Capture.Ignore` excluye SWEPs de
   manos (semilla para el sub-bloque de manos default — Apex Hands, ver roadmap).
5. **Ruta de adquisición ARC9:** comando `cargo_dev_atts [n] [filtro]` (da n
   attachments puenteados x2). Documentado: las entidades de mundo
   `arc9_att_*` requieren `arc9_atts_generate_entities 1` (default 0 de ARC9).
6. **Overflow de texto:** `Theme.FitText` (elipsis) en celdas de slot, título y
   filas del tooltip; los pills de munición ya no desbordan el ancho.
7. Detalle: el badge de grupo de munición A/B ya no aparece en melee (solo
   ítems con `ammo` o categoría `weapons`).

**Verificación previa (2026-07-10):** sintaxis 22/22 + harness offline ampliado
(captura con dedup y bypass de flag, remap legacy, slots de accesorio, defs en
snapshot): selftest 26/19 + integración 40/9 (server/client) en verde.

**Verificado en juego por el autor (2026-07-11):** caja refresca en vivo y UI
correcta (2 OK), inglés completo (3 OK), attachments con `cargo_dev_atts` y
reconciliación ARC9 (4 OK). Observaciones → entry 3: la tecla I poco fiable, y
la captura por `PlayerCanPickupWeapon` chocó con "Left 4 Dead | Item Pickup
System" (physgun/toolgun/cámara flotando e inagarrables); los drops de armas
salían como caja genérica. El deseo de UI fullscreen estilo STALKER y el
sistema de imágenes de ítems quedaron como pendientes de diseño en el roadmap.

---

## 3. Bind fiable + captura post-equip (compat mods de pickup) + drops con modelo `[APLICADO 2026-07-11]`

Salido de la segunda pasada en juego (2026-07-11):

1. **Bind del inventario:** `PlayerButtonDown` no dispara client-side en
   singleplayer (quirk del engine) — reemplazado por polling de
   `input.IsButtonDown` en `Think` (detector de flanco + guardas de chat/menú).
   Rebind sin consola: **DBinder** en el tab Q (Utilities → Corpus → Cargo)
   que escribe `cargo_key_inventory`; alternativa `bind <tecla> cargo_inventory`.
2. **Captura rediseñada: post-equip vía `WeaponEquip`, ya no se veta
   `PlayerCanPickupWeapon`.** Diagnóstico contra el código vivo del mod
   "Left 4 Dead | Item Pickup System" (3744343101, informe 2026-07-11): ese
   mod nunca usa `Give` — pre-autoriza el touch-pickup del engine devolviendo
   `true` desde su propio hook, y en `hook.Call` el primer retorno no-nil
   gana; nuestro `false` incondicional cortaba su único camino y un `Give`
   denegado deja el arma como entidad suelta (las herramientas flotantes).
   Ahora se captura un tick DESPUÉS del equip exitoso (convertir + strip):
   el engine ya consumió la entidad, cualquier mod de pickup ve su flujo
   completo, y el resultado es inmune al orden de hooks. Dedup y flag de
   equip propios se conservan.
3. **Drops con el modelo real del arma:** `corpus_cargo_item` resuelve
   def.model → `WorldModel` del SWEP scripted → mapa de modelos de armas de
   engine (pistol/357/smg/ar2/shotgun/physgun/toolgun/cámara/…) → caja solo
   como último recurso.

**Verificación previa (2026-07-11):** sintaxis 22/22 + harness (captura
post-equip: convertir/strip, dedup en re-give, bypass del flag): selftest
26/19 + integración 41/9 en verde.

**Verificado en juego por el autor (2026-07-11):** funciona; los ítems se
autoregistran correctamente (bind, captura, drops OK). Única excepción: ítems
spawneados con el toolgun no se podían tomar → atribuido al mod "L4D Item
Pickup System" (bloquea `AllowPlayerPickup` de todo lo que es arma). El autor
decidió **desinstalar ese mod** (removido también de `dev/other/`), lo que
elimina el conflicto; re-verificar sin él en el entry 4.

---

## 4. Feed de pickup en pantalla + baja del mod L4D `[PENDIENTE]`

Salido de la segunda pasada (2026-07-11):

1. **Feed de pickup (`corpus_cargo_pickup.lua`, CLIENT):** señala en pantalla
   el ítem que entra al inventario por una recogida real — captura de arma
   (loadout, mundo) y recoger un drop `corpus_cargo_item` con E. Reemplaza el
   highlight "mira el ítem" que daban los mods de pickup externos, ahora que
   la captura de Corpus es automática e instantánea. Server manda el **id**
   (no el nombre) tras el give, después del Sync que ya trae la def autogen —
   el cliente resuelve el nombre (y tokens `#HL2_*`) de su propia def. Convar
   cliente `cargo_pickup_feed` (default 1) lo desactiva; checkbox en el tab Q.
   No se dispara en transferencias de contenedor (el panel ya las muestra) ni
   en el kit dev.
2. **Baja del mod "L4D Item Pickup System"** (Workshop 3744343101): removido
   de `dev/other/` a pedido del autor por el conflicto de pickup. La lección
   de compat que dejó (capturar en `WeaponEquip`, nunca vetar
   `PlayerCanPickupWeapon`) **se conserva** en el header de
   `corpus_cargo_capture.lua` — el diseño post-equip sirve para cualquier mod
   de pickup futuro, no solo ese. La funcionalidad de captura de Corpus queda
   intacta.

**Verificación previa (2026-07-11):** sintaxis 23/23 + harness (la captura ya
ejercita `NotifyPickup` de camino): selftest 26/19 + integración 41/9 en verde,
ambos realms.

**Pendiente para `[APLICADO]`:** en juego SIN el mod L4D — spawn desarmado con
el feed listando el loadout capturado; recoger un arma de mundo (toolgun,
spawnmenu) por contacto ahora que nada bloquea `AllowPlayerPickup`; recoger un
drop con E y ver la línea del feed; `cargo_pickup_feed 0` lo apaga.

---

## 5. Sistema de imágenes de ítems (`Cargo_ItemImages`, roadmap #5) `[PENDIENTE]`

Baja a código `Cargo_ItemImages_Arquitectura.md` completo (client-side puro,
cero net salvo el snapshot de defs que ya existía). Prerequisito del bloque de
UI fullscreen (§15) — acá el grid sigue uniforme, las gradas son el bloque #3:

1. **Pipeline de íconos (`corpus_cargo_icons.lua`, CLIENT):** jerarquía de
   fuente estricta `def.icon` → render desde modelo → letra (§2; la letra pasa
   a ser placeholder de cola y señal de error). Render: `ClientsideModel` →
   RT reutilizable 512 (uno solo) → cámara resuelta → `render.Model` +
   `SetModelLighting` (receta del ícono de dupes del sandbox, la única que
   probó dibujar dentro de `PostRender`: los trucos de `DrawModel` de contexto
   de panel capturaban el fondo sin el modelo — 1.ª pasada del gate,
   2026-07-11) → captura PNG →
   `file.Write("data/corpus/cargo/icons/<defid>_<hash>.png")` →
   `Material("data/…", "smooth")`. Al aspect del footprint, 64 px/celda (§6).
   Generación lazy en `PostRender` con presupuesto por frame (convar
   `cargo_icon_budget`, default 2); sesiones siguientes cargan del disco sin
   re-render. Nombre de archivo = clave de invalidación:
   `hash(model + cam_efectiva + footprint)` (§7) — cambiar cualquier entrada
   re-renderiza solo ese ícono.
2. **Gate de transparencia (§9), decidido por convar:** Plan A (alpha real:
   RT transparente + `SetWriteDepthToDestAlpha` durante el pase — la silueta
   escribe el canal alpha — + captura `alpha=true`) vs Plan B (fondo del color
   de celda horneado). Switch: `cargo_icon_bake_bg` (0 = A default, 1 = B); al
   cambiarlo se regenera toda la caché sola. **Gate resuelto en juego
   (2026-07-11): Plan A funciona** — PNG transparentes limpios con la receta
   final; Plan B queda como fallback operativo del switch.
3. **Cadena de modelo compartida:** la resolución de los drops (entry #3) se
   extrajo de la entidad a `CARGO.Items.ResolveModel` (SHARED) — def.model →
   `WorldModel` del SWEP → mapa de armas de engine; la entidad y los íconos
   consumen la misma función (cero duplicación).
4. **Encuadre de 3 niveles (§4):** override de data (JSON) → `def.icon_cam` →
   auto con `PositionSpawnIcon` (firma verificada contra el engine:
   entidad + pos + noAngles → view table). `ResolveCam(def, ent)`.
5. **Footprint (§5):** `def.size` explícito o auto por OBB proyectado en la
   cámara efectiva, **cuantizado al set cerrado** (1×1…6×2, 11 formas) con
   techo por categoría (ammo≤2×1, medical≤2×2, weapons≤6×2, resto ≤3×3);
   set y techos SHARED en `Items` (el server valida overrides contra ellos).
   `Cargo.Icons.GetFootprint(defid)` expuesto en el CONTRACT — el layout en
   gradas NO se implementa acá (bloque #3).
6. **Consumidores (§10):** grid (aspect-fit en la celda cuadrada, interim),
   slots de equipamiento, quick slots y zoom del tooltip pintan vía
   `Cargo.Icons.Get`; helper único `Theme.DrawIconFit`. Refresh en caliente
   gratis: los `Paint` re-piden el material cada frame.
7. **Sync de overrides (§10):** registro server-side
   (`server/corpus_cargo_icons.lua`) persistido en
   `Corpus.Data("cargo", "icon_overrides")`, re-adjuntado a las defs al
   registrarse (las autogen se rearman cada sesión) y viajando en el snapshot
   de defs existente (ahora incluye defs con override además de autogen); el
   cliente mergea en sitio e invalida esa def. Los PNG nunca se sincronizan.
   Net nuevo: `corpus_cargo_icon_override` (editor→server, validado).
8. **Editor dev (§8, `corpus_cargo_iconeditor.lua`):** `cargo_icon_edit
   <defid>` (autocompletado solo de defs con modelo resoluble) — preview vivo
   (DModelPanel) sobre **fondo del color de celda con guía de footprint**
   (caja al aspect + cruz de centrado; pedido del autor en el gate), controles
   orbit/zoom/pan por mouse + **sliders finos de pitch/yaw/distancia/FOV**
   sincronizados en dos vías, botones "Auto frame (Cargo)" / "Engine
   isometric", footprint manual del set permitido, **Save** (persiste
   override, invalida hash, re-renderiza), **Print Lua** (imprime
   `icon_cam`/`size` para canonizar al def) y **Clear**.
   `cargo_icon_regen_all` invalida y borra la caché entera (re-render lazy
   respetando presupuesto). Ambos con el TODO estándar de gate de admin
   (roadmap #12). **Browser en el tab Q** (Utilities → Corpus → Cargo,
   pedido del autor): buscador + lista de defs editables (con modelo
   resoluble) que abre el editor al click y se refresca sola cuando se
   capturan armas nuevas — sin tipear defids en consola.
9. **Encuadre auto de perfil para `weapons`/`melee`** *(pedido del autor en el
   gate: los íconos de la referencia STALKER son perfiles paralelos, no el
   isométrico del engine)*: cámara lateral (+Y, yaw 270) fiteada al OBB del
   modelo; el resto de categorías mantiene `PositionSpawnIcon`. La clave de
   caché ahora incluye una **versión de receta** (`r2`): cambiar la receta o
   el auto en código invalida los íconos viejos por sí solo, sin
   `cargo_icon_regen_all` manual.
10. **Modelo correcto para armas ARC9** *(reporte in-game 2026-07-11: los
    íconos ARC9 salían con un modelo CSS con culata de madera)*. Causa raíz
    verificada contra la base ARC9 (`dev/other/`): las armas con
    `MirrorVMWM = true` ponen su `WorldModel` como **placeholder de colisión
    CSS/HL2** (comentario textual en `shared.lua`) y dibujan el viewmodel
    encima (`DrawWorldModel`, `cl_wm.lua`) — el `WorldModel` es la imagen
    equivocada. Resolver icon-específico `Icons.ModelFor(def)`: para armas
    ARC9 con MirrorVMWM usa `WorldModelMirror or ViewModel`; el resto y los
    **drops** siguen con `Items.ResolveModel` (necesitan un prop con
    colisión). Escape hatch `def.icon_model` para casos borde. Como cambia el
    modelo de entrada, la clave de caché de esas armas cambia sola → re-render
    automático, sin regen manual.

**Verificación previa (2026-07-11):** sintaxis 13/13 tocados + harness offline
(LuaJIT + framework real de `corpus/`, stubs de `file`/`render`/`weapons`):
selftest 26/29 (server/client; el client suma 10 checks nuevos de íconos) +
checks puros del harness (cuantización con techos, estabilidad y divergencia
de `IconCacheKey`, `ResolveIconSource`, precedencia de footprint, `Get` con
IMaterial/letra/cola, `ModelFor` con stub de SWEP ARC9) + snapshot de defs
llevando `icon_override` — todo verde, ambos realms.

**Confirmado in-game por el autor (2026-07-11):** gate de transparencia →
**Plan A OK** (PNG transparentes); íconos reemplazando letras en
grid/slots/tooltip; armas capturadas (`wpn_*`) resolviendo modelo; editor
funcionando (cam+footprint guardado, persistido entre sesiones y aplicado en
vivo); `cargo_icon_regen_all` sin hitch; auto de perfil correcto; browser del
tab Q. Feedback aplicado en caliente: receta de render a `render.Model` (la
two-pass de contexto de panel no dibujaba en `PostRender`), autocompletado
filtrado, sliders finos + fondo/guía, auto de perfil, y el modelo ARC9
(puntos 1, 8, 9 y 10).

**Pendiente para `[APLICADO]` (última verificación del autor):** que los
íconos de armas ARC9 muestren ahora el arma real (viewmodel) en vez del modelo
CSS placeholder, en grid/slots/tooltip y en el preview del editor.

---

## 6. Fix: arma equipada de clase de loadout sobrevive al respawn `[PENDIENTE]`

Salido de la verificación in-game (2026-07-11): un toolgun equipado en Primary
quedaba **inerte** tras recargar mapa/reconectar — el slot lo mostraba, pero el
jugador no tenía el arma (no se podía seleccionar).

Causa raíz en `corpus_cargo_capture.lua`: al respawnear, el loadout de sandbox
re-da su propio `gmod_tool`/`weapon_physgun`/`gmod_camera`. La captura lo detecta
como duplicado (ya es ítem de inventario) y hacía `StripWeapon(class)` — que
quita **todas** las armas de esa clase por nombre, incluida la que el hook
`PlayerLoadout` re-dio para el slot equipado. El re-give funcionaba; el strip
por clase lo mataba un tick después.

Fix: remover **solo la entidad específica** que el engine acaba de dar
(`wep:Remove()`), nunca `StripWeapon(class)`. El equip-give lleva el flag
`CargoEquipGive` y nunca agenda el timer de captura, así que el `wep` del timer
es siempre el duplicado del loadout/pickup — se remueve solo, y el arma equipada
(otra entidad de la misma clase) queda en la mano. Si `wep` ya es inválido no se
hace nada (el duplicado ya no está; jamás se toca la equipada).

**Verificación previa (2026-07-11):** sintaxis + harness en verde (la lógica de
render/ModelFor no regresó; el fix es de comportamiento de spawn/loadout, se
verifica in-game).

**Pendiente para `[APLICADO]` (verificación del autor):** equipar un toolgun (u
otra arma de clase de loadout: physgun, cámara) en un slot, recargar mapa/
reconectar, y confirmar que sigue equipada y **seleccionable/funcional**; que el
spawn desarmado y la captura del loadout normal no se rompieron.
