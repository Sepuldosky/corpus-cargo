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

## 5. Sistema de imágenes de ítems (`Cargo_ItemImages`, roadmap #5) `[APLICADO 2026-07-11]`

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
11. **Captura ensamblada para armas ARC9 modulares** *(2.º reporte in-game
    2026-07-11: con el punto 10 el 9A-91 ya resolvía su viewmodel real
    (`c_vsk94.mdl`) pero el ícono mostraba solo una parte del arma — mismo
    síntoma que los mods de íconos de HUD con ARC9 EFT)*. Causa verificada
    contra la base: en las armas MirrorVMWM la culata/handguard/cargador son
    **modelos de attachment** montados sobre el viewmodel (no bodygroups) —
    un `ClientsideModel` pelado siempre va a mostrar el receiver desnudo.
    Reconstruir ese ensamblado desde la def sería reimplementar `SetupModel`
    de ARC9; en cambio, cuando el jugador local **tiene el arma en mano**, se
    toma prestado el build de display de ARC9 (`SetupModel(true,0,true)` →
    `CModel` + `DrawCustomModel`, la receta exacta de su `DoPresetCapture`,
    `cl_presets.lua`) y se fotografía con NUESTRA cámara/luz/alpha: pose por
    `CustomizePos/Ang` (dato por-arma del pack, orienta de perfil), encuadre
    fiteado al AABB combinado de todas las partes, footprint re-cuantizado de
    la silueta completa. Mientras el arma no esté en mano, el viewmodel
    pelado queda como **provisional**: una sonda throttled en `Icons.Get`
    re-captura sola en cuanto se empuña. El footprint medido y el flag
    `assembled` persisten en `data/corpus/cargo/icons/icons_meta.json`
    (clave de caché estable entre sesiones; `Invalidate`/regen los limpian).
    Además el render pelado ahora aplica `DefaultSkin`/`DefaultBodygroups`
    (trepados por `.Base`, como hace `DoBodygroups` de ARC9) — no-op en EFT
    (todo ceros) pero corrige packs que eligen variante por bodygroup.
    Versión de receta → `r3` (los íconos viejos se invalidan solos).
12. **Drops con el modelo real también para armas ARC9** *(3.ª pasada in-game
    2026-07-11: un 9A-91 dropeado mostraba el AK de CSS)*. El drop usa el
    `WorldModel` para la física (los viewmodels no tienen malla de colisión) y
    en las MirrorVMWM ese modelo es el placeholder. Verificado contra el SWEP
    real (`dev/other/Arc9 EFT Assault Rifles/`, alta en el mapa de mods) y
    contra la base: ARC9 mismo dibuja el espejo ENCIMA del placeholder incluso
    en el suelo (`MirrorVMWMHeldOnly` default false). Mismo truco en
    `corpus_cargo_item`: la física conserva el placeholder, el render dibuja
    un `ClientsideModel` del modelo que resuelve el pipeline de íconos
    (`Icons.ModelFor`, vía `cargo_defid` networkeado), centrado sobre el OBB
    físico (los viewmodels se modelan alrededor de la cámara: dibujados crudos
    flotan lejos del prop), vestido con `Icons.ApplyDefaultAppearance` (ahora
    público) y con la sombra del placeholder apagada. Ítems sin divergencia de
    modelo siguen con el `DrawModel` de siempre.
13. **Encuadre por bounds de MALLA** *(5.ª pasada in-game 2026-07-11: los
    íconos EFT ensamblados se generaban, pero chiquitos y todos igual de
    chicos)*. Causa: el CModel base reproduce la secuencia idle del
    viewmodel, y los render/sequence bounds de un viewmodel abarcan el
    barrido completo de la animación alrededor de la cámara (±60+ unidades),
    no el arma (~30) — la cámara fiteaba ese AABB inflado y el arma quedaba
    diminuta, uniformemente en todos los packs. Ahora el hull se mide sobre
    la **malla real** (`util.GetModelMeshes`, una vez por ruta de modelo,
    cacheado; fallback a render bounds si la malla no es legible) — en el
    ensamblado, en el perfil pelado y en el footprint. Receta → `r4` y meta
    versionada (`_v`: al cambiar la semántica de medición la meta vieja se
    descarta sola) — todo el caché regenera lazy sin intervención.
14. **Captura ensamblada solo con el arma DESPLEGADA y asentada** *(6.ª
    pasada in-game 2026-07-11: la primera generación con el arma en mano
    salía completa, pero un regen con otra arma activa dejaba ensamblados
    parciales o vacíos — mismo síntoma intermitente que los íconos de HUD
    autogenerados del propio ARC9, que "se completan" al regenerar después,
    como el AVT-40 del reporte)*. Causa: ARC9 llena su estado de attachments
    durante los primeros instantes del deploy; un arma solo portada
    (enfundada) nunca lo construye, y `LiveArc9Weapon` aceptaba cualquier
    arma portada (`GetWeapon`). Ahora exige `GetActiveWeapon() == wep` y una
    ventana de asentamiento (primer avistamiento activa arma +1 s; la
    captura corre recién en la sonda siguiente con el arma aún afuera).
    Mientras tanto queda el render provisional y la sonda reintenta. Meta →
    `_v = 3`: los ensamblados pre-fix (posiblemente parciales) se descartan
    y re-capturan solos.
15. **Cámara del ensamblado = encuadre de preset de ARC9 + bounds robustos**
    *(7.ª pasada in-game 2026-07-11: una generó perfecta (AEK-971), otras
    salieron transparentes; el AF-53 "lejos del origen" y en 1x2; y la
    primera generación al equipar lagueaba ~1 s. Propuesta del autor: "¿no
    es posible generar la imagen tomando en cuenta el menú de ARC9?")*.
    Tres causas, tres fixes:
    - **La cámara ya no se mide: se usa la de ARC9.** Para modelos EFT
      pesados `util.GetModelMeshes` falla y el fallback (render bounds
      inflados) desencuadraba TODO — cámara lejos del arma, crop donde el
      arma no está (PNG transparente), footprint 1x2. Ahora el ensamblado
      replica la foto de preset de ARC9: el arma ya está poseada por
      `CustomizePos/Ang` (dato por-arma) y la cámara es
      `CustomizeSnapshotFOV` en origen con viewport 16:9 — cero medición
      que pueda salir mal; se captura el cuadrado central como ARC9 y se
      recorta al aspect del footprint. El override de cámara del editor
      sigue ganando.
    - **Cadena de bounds con hull estático:** malla → `GetModelBounds`
      (hull autorado, nunca falla ni se infla por secuencia) → render
      bounds. Los bounds quedan SOLO para el footprint.
    - **El lag de ~1 s era el mesh-walk del viewmodel EFT:** ahora el
      resultado se persiste en `data/corpus/cargo/icons/mesh_bounds.json`
      (una vez por modelo PARA SIEMPRE) y en el ensamblado solo se
      mesh-walkea el viewmodel base (los attachments usan su hull estático
      gratis). Receta → `r5`, meta → `_v = 4` (regenera todo solo).
16. **La captura 3D ensamblada MUERE: la fuente es el PNG del propio ARC9,
    regenerado desde su menú** *(8.ª pasada in-game 2026-07-11: el AVT-40
    seguía generando sin barril ni culata y con piezas lejos, mientras el
    menú de customize de ARC9 y el ícono de HUD se veían perfectos.
    Diagnóstico del autor: "la generación de los attachments no es tan
    rápida y la generación del png por Cargo es mucho más rápida". Idea del
    autor implementada: plan C del handoff)*. La carrera era estructural:
    `DrawCustomModel` posiciona las partes a lo largo de VARIOS frames
    (huesos se asientan por frame, no por draw call) y ninguna ventana de
    asentamiento la cerraba del todo. Pivot completo:
    - **Fuente = `data/arc9_presets/<base>_icon.arc9.png`** (el select icon
      que ARC9 mismo captura, 256×256 RGBA con alpha real; fallback
      `<base>/default.arc9.png`, la misma cadena que su HUD). Cargo lo
      **re-encuadra en 2D**: bbox de la silueta por alpha
      (`CapturePixels`/`ReadPixel`, fallback por luminancia), crop al
      aspect del footprint, PNG propio. Cero estado 3D que pueda correr:
      sirve desde disco al boot, sin el arma en mano, y `regen_all` ya no
      necesita empuñar nada. `AssembledPose`/`AssembledBounds`/
      `DrawAssembled`/`RenderAssembledToFile`/`LiveArc9Weapon` borrados.
    - **Regeneración deliberada = el menú de ARC9** (timer pedido por el
      autor): watcher en `Think` — con el menú de customize abierto ≥1 s
      (arma garantizada armada, asentada y en pantalla), dispara
      `wep:DoIconCapture(true)` (la receta propia de ARC9, que desde ahí
      sale siempre completa). Se rearma si ARC9 marca el ícono sucio
      (`InvalidateSelectIcon`, cambio de attachments). Convar
      `cargo_icon_arc9_menu_capture` (default 1). El **mtime de la fuente
      entra en la cache key**: cada recaptura renombra el PNG de Cargo
      (esquiva el caché by-path de `Material()`) y barre el archivo viejo;
      mientras el re-crop está en cola la celda muestra el ícono anterior,
      nunca la letra. El footprint se estima de la proyección del snapshot
      (FOV/`CustomizePos` por `.Base`) y la meta lo persiste como antes.
      El override de cámara del editor queda SIN efecto en armas ARC9 (la
      foto de ARC9 ES el encuadre); el de tamaño sigue ganando.
    - **Resolución del resto de los íconos** *(mismo reporte: "se generan
      con una resolución inferior muy fea")*: `CELL_PX` 64 → **128 px por
      celda** y RT de trabajo 512 → 1024 (el nombre del RT ahora lleva el
      tamaño: `GetRenderTarget` cachea por nombre toda la sesión del
      engine). Receta → `r6`, meta → `_v = 5` — todo regenera lazy solo.

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

**Verificación previa del punto 11 (2026-07-11):** harness re-corrido con los
checks nuevos (footprint persistido en `icons_meta.json` con precedencia
override > meta, `Invalidate` limpiando la entrada, `ModelFor` por cadena
`.Base`, clave de caché estable): selftest 26/29 + checks en verde, ambos
realms. La captura ensamblada en sí es render puro — solo verificable in-game.

**Pendiente para `[APLICADO]` (última verificación del autor):** con el arma
ARC9 **en la mano** (equipada/deployada), abrir el inventario o regenerar
(`cargo_icon_regen_all`) y confirmar que el ícono del 9A-91 muestra el arma
completa (culata/handguard/mira incluidos); recargar mapa y confirmar que el
ícono ensamblado persiste sin re-empuñar; grid/slots/tooltip y preview del
editor consistentes. **Nota 3.ª pasada (2026-07-11):** el autor confirmó que
el ícono se genera y se ve en inventario/editor (captura ensamblada
funcionando). El drop del punto 12 quedó **superado por el entry 7** en armas:
los drops de armas ahora spawnean el SWEP real (el override visual del punto
12 queda para ítems no-arma y drops legacy). **Nota 5.ª pasada:** íconos
generando pero diminutos → punto 13. **Nota 6.ª pasada:** encuadre confirmado
más cerca; ensamblados parciales/vacíos intermitentes tras regen → punto 14
(solo captura con el arma desplegada + asentada). **Nota 7.ª pasada:** AEK-971
perfecta; transparentes/desencuadres residuales (AF-53) + lag de primera
generación → punto 15 (encuadre de ARC9 + hull estático + caché de malla en
disco). **Nota 8.ª pasada:** el AVT-40 seguía parcial y con piezas lejos →
punto 16 (la captura 3D propia muere; fuente = PNG del propio ARC9 +
recaptura desde su menú + re-crop 2D). **Verificación previa del punto 16
(2026-07-11):** sintaxis + harness offline reconstruido (LuaJIT + stubs):
clave re-keyeada por stamp de fuente nueva (con fallback `default.arc9.png`),
`ModelFor` por `.Base`, precedencia de footprint, cuantización, watcher
registrado y tolerante sin arma — 13/13 verde.

**Confirmado in-game por el autor (2026-07-11, 9.ª pasada — cierre del entry):**
el ícono ARC9 ahora sale COMPLETO ("funciona correctamente"); el re-crop 2D
del select icon del propio ARC9 y la recaptura desde el menú resolvieron el
parcial/desencuadre residual del AVT-40. Deuda anotada por el autor: la
resolución "no es la más linda" — la fuente de ARC9 es 256×256 y el arma
ocupa una banda horizontal, así que el re-crop upscalea; mejora futura
posible (capturar la fuente a mayor resolución, o RT propio sobre el menú).
Entry cerrado; el resto del sistema de imágenes (puntos 1-15) ya estaba
confirmado en las pasadas previas.

---

## 6. Fix: armas equipadas sobreviven al respawn/reinicio (persistencia completa) `[APLICADO 2026-07-11]`

Salido de la verificación in-game (2026-07-11): un arma equipada en un slot
(toolgun, physgun, 9A-91) quedaba **inerte** tras recargar mapa/reconectar —
el slot la mostraba, pero el jugador no tenía el arma (no se podía
seleccionar). Había que mandarla al inventario y re-equiparla.

**Primer patch (insuficiente):** remover solo la entidad específica que el
engine acaba de dar (`wep:Remove()`) en vez de `StripWeapon(class)` — que
quitaba **todas** las armas de la clase, incluida la re-dada por
`PlayerLoadout`. Correcto (se conserva absorbido abajo), pero el diagnóstico
de fondo era doble:

1. **Las defs autogen no se persistían.** Nacen en runtime (`EnsureDef`,
   cuando el engine entrega el arma) y se re-creaban solo al capturar. Tras
   un reinicio, un arma equipada **que no está en el loadout** (el 9A-91)
   deserializa a un blob cuyo id ya no resuelve → `PlayerLoadout` se saltea
   su re-give y el slot muestra un arma que el jugador no tiene.
2. **Colisión captura ↔ arma equipada de clase de loadout, con timing
   frágil.** El re-give de physgun/toolgun se protegía SOLO con el flag
   `CargoEquipGive`, seteado/limpiado sincrónico alrededor de `ply:Give` —
   pero en el spawn `WeaponEquip` puede disparar **diferido** y perder la
   ventana del flag: la captura veía el arma re-dada como duplicado y la
   removía.

**Fix de 3 partes** (`corpus_cargo_capture.lua` + `corpus_cargo_inventory.lua`):

1. **Registro persistido de defs autogen:** `data/corpus/cargo/
   autogen_defs.json` (id → {name, weapon_class}), guardado en cada
   `EnsureDef` nuevo y **re-registrado en el boot del server** — las defs
   existen siempre tras reinicio (los `name` de armas de engine son tokens
   `#HL2_*` crudos; el cliente ya los resolvía al llegar el snapshot).
2. **La captura CONSERVA las clases equipadas:** decisión pura
   `CARGO.Capture.Decide(equippedCount, hasItem)` → `keep`/`remove`/
   `capture`. Si la clase del arma está equipada en un slot, la entidad **ES**
   el arma equipada (el engine permite una por clase): la captura no la toca,
   venga del loadout, de nuestro reconcile o de un mod de pickup. Esto
   **elimina la dependencia del flag/timing** como mecanismo de corrección
   (el flag queda solo como fast-path); el `wep:Remove()` del primer patch
   queda absorbido en las ramas `remove`/`capture`.
3. **Reconcile diferido en `PlayerLoadout`:** `timer.Simple(0.1)` que, tras
   asentarse el loadout y los timers de captura, re-da las armas equipadas
   que el jugador **todavía no tiene** (`not ply:HasWeapon`) — típicamente
   las que no están en el loadout (9A-91). Como la captura ahora conserva
   las clases equipadas (parte 2), estos re-gives sobreviven sin flag.
4. **Heal de blobs huérfanos** *(3.ª pasada in-game 2026-07-11: "bloques"
   sin nombre ni ícono en el grid — ítems capturados en sesiones ANTERIORES
   al registro persistido, cuyas defs murieron con su sesión)*. El id del
   blob codifica la clase (`wpn_<clase>`): al cargar el record
   (`PlayerInitialSpawn`) se resucita una def mínima para todo blob `wpn_*`
   sin def (nombre placeholder = la clase) y se persiste en el registro;
   en la siguiente captura real de esa clase, `EnsureDef` reemplaza el
   placeholder por el print name verdadero (la def es by-ref: el snapshot
   siguiente lo lleva). Los "bloques" vuelven a ser armas con nombre,
   equipables y re-dables.

**Verificación previa (2026-07-11):** sintaxis 4/4 tocados + harness offline
(framework real + módulo real, ambos realms): selftest 26/29 en verde, y
checks nuevos — def autogen re-registrada en boot desde `autogen_defs.json`
sembrado, matriz completa de `Decide`, flujo de captura real vía
`hook.Run("WeaponEquip")` + timers (arma suelta capturada y removida, def
persistida, instancia en el grid), clase equipada intocada (`keep`), reconcile
diferido re-dando la clase equipada faltante, y el heal completo (def
resucitada desde el blob + persistida + upgrade del nombre placeholder en la
captura siguiente + dedup del arma re-capturada).

**Confirmación parcial del autor (3.ª pasada, 2026-07-11):** el toolgun
equipado sobrevivió al respawn y era usable — las partes 1-3 funcionan para
clases de loadout.

**Confirmado por el autor (2026-07-11, cierre del entry):** persistencia de
equipadas verificada — el heal de blobs huérfanos, el reconcile diferido y la
supervivencia al reinicio/reconexión completa funcionan. Entry cerrado.

---

## 7. Armas de mundo: sin auto-pickup, WALK+USE toma, USE agarra; drops = SWEP real `[APLICADO 2026-07-11]`

Baja a código el **roadmap #16** (pedido del autor, 3.ª pasada 2026-07-11:
"que al tomar las armas se deba hacer walk + use; use sirve para tomar el
arma y lanzarla o moverla como los props de HL2") y la **mitad del #17** (el
arma botada conserva su instancia de Cargo). Resuelve además la paridad
visual del drop: un arma ARC9 dropeada se veía como viewmodel pelado (o
nada), mientras la misma arma spawneada por toolgun se ve completa — porque
esa la dibuja ARC9. Todo en `corpus_cargo_capture.lua` +
`corpus_cargo_inventory.lua` (DropEntry), convar maestro
`cargo_weapon_world_pickup` (default 1; en 0 vuelve TODO al comportamiento
anterior):

1. **Drops de armas = la entidad SWEP real.** `DropEntry` de un ítem con
   `weapon_class` spawnea el arma misma (`CARGO.Capture.SpawnWorldWeapon`)
   tagueada con el **uid de la instancia**: ARC9 la renderiza ensamblada en
   el suelo (verificado: `MirrorVMWMHeldOnly` default false ⇒ dibuja el
   espejo también sin dueño), la física es la del SWEP, y el blob
   (attachments/condición) queda intacto en `inst_<uid>`. Ítems no-arma
   siguen dropeando `corpus_cargo_item`.
2. **Gate de mundo (`PlayerCanPickupWeapon`).** Nadie aspira armas por
   contacto: se niega el pickup de armas **reposando** en el mundo (entidad
   con edad > 0.5 s, o spawneada por nuestro drop). Los flujos de give
   (loadout del gamemode, nuestro equip/reconcile) crean la entidad y la
   entregan en el acto (edad ~0) y **pasan intactos** — la lección de compat
   L4D del header se conserva: jamás se deniega un give ni queda una entidad
   flotando (el arma ya estaba en el suelo a propósito).
3. **USE = agarrar (carry HL2), WALK+USE = tomar.** Hook `PlayerUse`
   (mirarla + E, con debounce): USE solo llama `PickupObject` (moverla,
   lanzarla — el pedido "como los props ligeros de HL2"); WALK+USE marca un
   grant de un solo uso en la entidad y llama `PickupWeapon` → el flujo
   normal de captura la convierte en ítem. **USE de nuevo SUELTA** (5.ª
   pasada: el engine libera el objeto en el mismo press ANTES de que corra
   el hook, y lo re-agarrábamos al instante — el press que agarra marca la
   entidad y un press sobre la entidad marcada solo suelta, con
   `DropObject` de respaldo si seguía sostenida). Tras un lanzamiento con
   physgun/click, el primer E sobre esa arma consume la marca vieja (press
   "en vacío") y el segundo re-agarra — costo conocido de la v1.
4. **El take-back restaura LA MISMA instancia (roadmap #17 parcial).** La
   captura lee `CargoInstanceUid` de la entidad al momento del equip: si el
   arma es un drop de Cargo, `GiveEntry` devuelve el blob original (no un
   ítem nuevo, sin pasar por el dedup — una instancia concreta nunca es
   "duplicado"). Si el give no cabe (peso), un take **deliberado** vuelve al
   suelo (`SpawnWorldWeapon` de nuevo, con su uid) en vez de perderse — la
   regla vieja "se remueve igual" queda solo para el handout anónimo del
   engine.

**Verificación previa (2026-07-11):** sintaxis 4/4 + harness (ambos realms,
selftest 26/29): gate completo (mundo denegado / give fresco pasa / grant
autoriza / equip-give intocado / drop propio denegado aun fresco), PlayerUse
(carry con USE, debounce, grant+pickup con WALK+USE), drop ruteado al SWEP
real con uid y entry fuera del grid, y take-back restaurando el uid idéntico.

**Confirmado por el autor (5.ª pasada, 2026-07-11):** "funciona todo bien" —
sin auto-pickup, WALK+USE toma (el autor usa F como +use), USE agarra, el
drop se ve como el arma real. Único faltante reportado: soltar el arma
agarrada re-apretando USE → implementado arriba (punto 3, marca de carry).

**Confirmado por el autor (2026-07-11, cierre del entry):** armas de mundo
verificadas completas — gate sin auto-pickup, WALK+USE toma, USE agarra/
suelta (marca de carry), drops con el SWEP real y take-back con la misma
instancia. Entry cerrado.

---

## 8. UI fullscreen: 3 columnas / 3 estados, gradas, cinturón y círculos sandbox (§15) `[APLICADO 2026-07-12]`

Baja a código el **bloque UI fullscreen** (`Cargo_Architecture.md` §15,
roadmap #3 del módulo): cambia la **forma**, no la funcionalidad — todo lo
de Block 1 (slots, sub-slots, quick, peso, providers, stat-bars, tabs,
footer, contenedores, menús contextuales, ARC9) se conserva reordenado al
layout STALKER/GAMMA del mock congelado
(`docs/mockups/cargo_fullscreen_ui_mock_v1.html` + los 3 PNG). Decisiones
del autor en la sesión: el **tooltip sigue flotante** en todos los estados
(manda la tabla de §15.1 — la columna izquierda en Solo queda ausente, mundo
visible detrás; la tarjeta dockeada del mock NO se implementa), el botón $
queda como gancho con aviso, el cinturón acepta **solo** `category "ammo"`,
y **ESC cierra el inventario** (no apila el menú del juego encima).

1. **Grid a gradas** (`corpus_cargo_grid.lua`): cada ítem pinta `w×h`
   celdas según `CARGO.Icons.GetFootprint` (§7 enmendado; unidad 42 px @1080,
   escalada). El modelo de datos NO cambia (sin gestión espacial ni
   rotación; el costo de cargar sigue siendo peso). `DIconLayout` en flow
   con wrap — la trampa `Dock(TOP)` + `InvalidateLayout(true)` se conserva.
   Overlays nuevos: badge de grupo A/B (armas, arriba-izq) y barra de
   condición al borde inferior; retícula sutil de fondo.
2. **Frame fullscreen, una implementación / tres estados**
   (`corpus_cargo_ui.lua`): scrim traslúcido sobre el mundo, tres columnas
   del mock (580/420/660 @1080, escaladas y clampeadas a 4:3). Columna
   izquierda **contextual**: ausente en Solo, contenedor en Loot, reservada
   para Trade (`Cargo_Trade`). Centro (orden §15.2 exacto): Accessory1 ·
   Head · Accessory2 / Secondary · Body · Primary (verticales, icono de
   arma rotado 90°, badge A/B + calibre, barra segmentada de condición) /
   Sidearm · Back · Melee / quick F1–F4 (candado intacto) / círculos
   sandbox / cinturón / panel de estado al fondo. Derecha: header de perfil
   (avatar, facción provider, dinero + botón $) → tabs → grid → footer de
   peso. Paleta oliva del mock ahora en `corpus_cargo_theme.lua` (única
   fuente de estilo — re-skinnea tooltip/feed/transfer coherente).
3. **Estado Loot absorbe el panel de transferencia**
   (`corpus_cargo_transfer.lua`): el frame lado-a-lado desaparece; usar un
   contenedor abre el frame único en Loot (columna izquierda = contenedor +
   Take all; Move all en el footer propio). El archivo queda como dueño del
   wire (`container_open/sync/close`, `transfer`, `takeall`) y de los
   intents; la UI vive entera en `corpus_cargo_ui.lua`. Drag en ambos
   sentidos y click-para-transferir se conservan 1:1.
4. **Cinturón de munición — solo la FORMA (#19 queda para su bloque)**:
   `rec.belt[1..6]` en el server (`corpus_cargo_inventory.lua`), net
   `belt_set`/`belt_clear` namespaced. Solo stacks `category "ammo"`; el
   stack se mueve ENTERO (deja el grid); merge solo con condición idéntica
   (regla anti-lavado); ocupante distinto vuelve al grid (swap, nunca se
   pierde); el peso lo sigue contando `TotalWeight`; persiste en el record
   (claves numéricas re-normalizadas como quick). Badge A/B **derivado**
   client-side (calibre vs arma equipada) — display only, nada alimenta
   del cinturón todavía.
5. **Círculos de herramienta sandbox (#21)**: physgun/toolgun/camera como
   atajos circulares — en mano → `input.SelectWeapon`; como ítem capturado
   en el grid → equip al primer slot que acepte (vacío primero). Toggle
   hide/show (`cargo_ui_tools`, archive). No son slots de almacenamiento.
6. **Botón de dinero (§15.3) — el gancho**: circular junto al valor del
   header. Delegará en `CARGO.Trade.MoneyButton(estado)` cuando el bloque
   de comercio exista; hoy responde honesto en chat. La entidad-dinero y el
   basket viven en `Cargo_Trade_Arquitectura.md` §7.

**Verificación previa (2026-07-12):** sintaxis 6/6 (luaparser) + harness
offline (lupa/LuaJIT, ambos realms): selftest 26/29 OK; reglas del cinturón
completas en server (gate ammo, stack entero, merge, swap sin pérdida,
fuera de rango, peso, persistencia con claves numéricas, snapshot); en
client, snapshot inyectado por el receiver real de sync (NumberKeys de
quick y belt), frame Loot y Solo construidos (51/42 paneles), barrido de
TODOS los Paint/PaintOver/Think limpio en ambos estados, 18 DoClick limpios
y cierre del Loot notificando `container_close`. **Pendiente: pasada en
juego del autor** (checklist §15 + regresión Block 1).

**Ajustes de la 1.ª pasada en juego (2026-07-12, feedback del autor —
confirmados en esa pasada: cinturón, botón $, peso y traspaso
crate↔inventario):**

1. **Retícula alineada:** la dibuja el propio `DIconLayout` (mismo origen
   que las celdas y scrollea con el contenido), no el scroll de fondo.
2. **Footprints calibrados** (la calibración empírica que
   `Cargo_ItemImages` §5 dejaba pendiente): **piso por categoría**
   `ICON_CATEGORY_MINS` (weapons ≥3×2) aplicado en la cuantización y como
   clamp aspect-aware sobre metas persistidas (`ClampFootprintMin`: un meta
   3×1 de rifle ARC9 cae en 6×2, uno 2×1 de pistola en 4×2); **sizes
   explícitos** en el kit dev (casco 3×3, chaleco 3×4, mochila 3×3, placa
   2×3, SMG 4×2, pistola 3×2, melee 3×1…) y **tabla de clases engine** en
   la captura (physgun 4×2, toolgun 3×2, cámara 2×1, AR2/escopeta 5×2,
   RPG 6×2…). El set permitido suma 4×2 y 3×4; techo de armor 4×4.
3. **Círculos sandbox = slots dedicados REALES** (`tool_physgun` /
   `tool_toolgun` / `tool_camera` en `Slots.List`, campo `classes` en
   `CanEquip`: aceptan exactamente su clase — un rifle jamás cae ahí y la
   herramienta no compite por Primary/Secondary). Click coloca la
   herramienta desde el grid en su slot (el server entrega el SWEP; vivir
   en `rec.equip` compra gratis el keep-equipped de la captura y el re-give
   del reconcile de spawn) o la selecciona si ya está puesta; drag en ambos
   sentidos; **hover muestra el tooltip real del ítem** (pedido del autor);
   fila centrada y **sin toggle hide** (ocultarlas será del futuro
   sub-bloque admin).
4. **Tabs con wrap** en filas (la fila única recortaba "Backpacks").
5. **Strings sobrantes fuera:** "feeds active weapon" (el cinturón se
   explica solo) y "registrable stat-bars".
6. **Transferencia por cantidad:** "Take/Move amount..." con prompt
   (`Derma_StringRequest`) además de 1/stack entero.

**Verificación previa de los ajustes (2026-07-12):** sintaxis 9/9 + harness
ambos realms: selftest sube a 29/36 OK (casos nuevos: piso en cuantización,
clamps 3×1→6×2 y 2×1→4×2, piso no toca otras categorías, tool slot acepta
su clase / rechaza otra / physgun sigue equipable en slots de arma), equip
server-side a `tool_physgun` con rechazo de clase equivocada y unequip
devolviendo al grid, frames Loot/Solo construidos y barrido de paints/clicks
limpio. **Pendiente: 2.ª pasada en juego.**

**Ajustes de la 2.ª pasada en juego (2026-07-12, feedback del autor):**

1. **Header sin subtítulo de provider** (`corpus_cargo_ui.lua`): se quitó la
   línea "native USD / provider" bajo el valor de dinero (ruido visual); el
   valor queda centrado. `snap.moneyLabel` se conserva para el bloque de
   comercio.
2. **Toolgun a 2×3** (antes 3×2): `AUTOGEN_SIZES.gmod_tool` en
   `corpus_cargo_capture.lua` — silueta vertical. `def.size` explícito ⇒ NO
   pasa por el piso `ICON_CATEGORY_MINS` (Cargo_ItemImages §5), así que el
   2 de ancho se respeta; re-key automático del ícono (footprint en la clave).
3. **Sin bloque de celda detrás de los ítems** (`corpus_cargo_grid.lua`):
   `PaintCell` ya no pinta el relleno oscuro por ítem — los ítems flotan
   sobre la retícula tenue (más STALKER, menos ruido, pedido del autor); el
   highlight de celda + borde queda **solo en hover**.
4. **Los slots de herramienta no auto-stockean el tool del loadout**
   (`corpus_cargo_capture.lua`): el loadout de sandbox reparte
   physgun/toolgun/camera en cada spawn y la captura los metía al inventario
   aunque el jugador no los quisiera. Nuevo convar
   `cargo_capture_sandbox_tools` (`FCVAR_ARCHIVE`, default **0**): con 0, el
   handout **anónimo** del loadout de esas tres clases se **descarta** en vez
   de capturarse — el círculo/slot es para una herramienta que YA tenés. Una
   toma **deliberada** (WALK+USE de un tool de mundo) o una instancia
   dropeada de Cargo (`blob`) siguen capturando; un tool ya en inventario
   (dedup) o equipado (`keep`) no se toca. En 1 vuelve al auto-stock anterior.
   Los saves existentes conservan sus tools (el guard solo salta capturas
   nuevas); un personaje realmente fresco arranca sin ellos.
5. **Resolución de íconos de render (no-ARC9) 128→256 px/celda**
   (`corpus_cargo_icons.lua`): `CELL_PX` 128→256, RT de trabajo 1024→2048,
   `RECIPE_VERSION` r6→r7 (regenera solo). Íconos de modelo (armas HL2,
   toolgun, medkits…) más nítidos, sobre todo en el zoom del tooltip. Los
   íconos **ARC9 se dejan en su fuente 256²** (decisión del autor): la fuente
   la hornea ARC9 según `ScrH() > 1100` (256² ≤1100px, 512² arriba) en un RT
   de file-scope que Cargo no puede redimensionar sin forkear ARC9 —
   COMPAT-RUNTIME. A ≥1440p ARC9 ya entrega 512 y el re-crop lo aprovecha
   solo; la deuda de nitidez de entry 5 sigue anotada, sin regresión (un
   `CELL_PX` mayor solo agranda el mismo re-crop, no lo degrada).

**Verificación previa de la 2.ª pasada (2026-07-12):** sintaxis 4/4
(luaparser) en los archivos tocados (`ui`/`capture`/`grid`/`icons`); harness
completo NO recorrido en esta sesión. Lógica del guard de captura razonada
por casos (loadout descartado / dedup / keep / walk+use / drop de Cargo /
convar en 1).

**Confirmado in-game por el autor (3.ª pasada, 2026-07-12, cierre del entry):**
"todo good" — header sin subtítulo, grid sin bloque oscuro, physgun/toolgun/
camera del loadout ya NO entran solos al inventario, e íconos de render
no-ARC9 más nítidos, los cuatro OK. **Único ajuste: el toolgun salió
invertido.** La notación del autor es **alto×ancho** (reverso del `{w,h}` del
código): su "2x3" = 2 alto × 3 ancho = `{w=3, h=2}`, pero se había aplicado
`{w=2, h=3}` (2 ancho × 3 alto). Corregido a `gmod_tool = { 3, 2 }` (3 ancho ×
2 alto) — footprint de código sobre el mismo mecanismo `def.size` ya
confirmado en el resto de las clases; el def autogen re-registra el size en el
boot del server y el ícono re-keya solo. Entry cerrado.

---

## 9. Orden de armas estilo STALKER + holster + manos default (roadmap #22 parcial + #4) `[APLICADO 2026-07-12]`

Baja a código el pedido del autor (2026-07-12): teclas 1-7 mapeadas a los
slots de equipamiento, re-apretar la tecla del arma en mano la **enfunda**, y
el estado desenfundado es elegible — manos vacías totales (sin arma) o el
SWEP de manos reciclado de Apex Hands, renombrado **"Hands"**. El resto del
#22 (matar las notificaciones de obtención de armas de GMod + verificar
compat del 7.º slot con el HUD D/GL4) queda para otra tanda.

1. **SWEP `corpus_cargo_hands` ("Hands")** (`lua/weapons/corpus_cargo_hands.lua`):
   reciclado de "Apex Legends: Holster/Melee SWEP" (Workshop 2792160770,
   Twilight Sparkle & Buu342; créditos completos en el header + política de
   retirar assets si lo piden — aprobado por el autor 2026-07-11, mapa §2).
   Puñetazos con ambos botones (combos/uppercut/daño y "los números
   específicos" de knockback intactos), R inspecciona, anims de
   caminar/sprint/agacharse/saltar con convars renombradas `cargo_hands_*`,
   hitmarker con material relocado. Sonidos re-namespaced `corpus_hands.*`
   (cero colisión si el mod original sigue montado) y el `sound.Add` de
   swing que declaraba `sound` dos veces (el left hook moría) ahora mergea
   ambos sets. Operadores C-style reescritos a Lua estándar (estilo del
   repo + harness offline). Assets copiados: viewmodel `c_arms_apex` (mismo
   path — un .mdl no se renombra sin recompilar), 41 wavs usados, íconos
   vgui/killicon/spawnmenu renombrados con VMTs propios.
2. **FIX de brazos oscuros** (repro refinado del autor 2026-07-11: el
   viewmodel se oscurece mirando al horizonte, recupera mirando arriba/abajo
   o flotando → el `$illumposition` horneado del modelo porteado rota con
   los eye angles y cae BAJO el piso, muestreando lightmap negro).
   - **1.er intento (falló in-game 2026-07-12):** anclar el lighting origin
     del viewmodel al jugador (`vm:SetLightingOriginEntity(owner)`, la
     técnica de ARC9 en `sh_deploy.lua:88`). El engine siguió iluminando el
     viewmodel desde el illumposition malo — no bastó, revertido.
   - **2.º intento (CONFIRMADO in-game 2026-07-12):** tomar el control
     del lighting del viewmodel a mano en vez de anclarlo. `PreDrawViewModel`/
     `PreDrawPlayerHands` hacen `render.SuppressEngineLighting(true)` + una
     caja de luz propia (`render.ResetModelLighting` ambiente + `SetModelLighting`
     `BOX_TOP` como key cenital), restaurada en los `Post`. La caja **no es
     fullbright plano**: muestrea la luz del mundo en `ply:EyePos()`
     (`render.GetLightColor` — un punto que sigue la cabeza y nunca cae bajo
     el piso con el ángulo de vista) con un **piso** por canal (0.16) para que
     los brazos nunca queden negros, más un realce cenital para conservar
     volumen. Así reaccionan al ambiente (sótano oscuro vs. exterior) pero
     ignoran el glitch del horizonte. **El autor confirmó que funciona,
     aplicando el archivo en vivo sin reiniciar.** Queda pendiente **remitir
     el fix a Twilight** (acción del autor, TODO del roadmap #4).
3. **Orden de armas 1-7** (`CARGO.Slots.Hotkeys`, data SHARED en
   `corpus_cargo_slots.lua`): 1=melee, 2=sidearm, 3=primary, 4=secondary,
   5=physgun, 6=toolgun, 7=camera. El cliente
   (`corpus_cargo_hotkeys.lua`) intercepta `slot1`-`slot7` en
   `PlayerBindPress` (la barra de buckets de GMod no abre para esas teclas;
   8/9/0 quedan stock) y manda SOLO el intent (`slotkey`, contrato #7);
   convar `cargo_weapon_slots` (default 1, toggleable como pide el roadmap).
4. **Holster server-side** (`corpus_cargo_holster.lua`): resuelve el intent
   contra `rec.equip` — slot vacío no hace nada; el arma del slot se
   selecciona; **re-apretar la tecla del arma activa enfunda**. Estilo de
   holster por jugador vía userinfo `cargo_holster_hands` (default 1 =
   Hands; 0 = `SetActiveWeapon(NULL)` + viewmodel oculto, técnica Simple
   Holster — referencia COMPAT del mapa §2, no se copió código). Comando
   `cargo_holster` para bindear el enfunde directo. `PlayerSwitchWeapon`
   levanta el hide del viewmodel en cualquier cambio a arma real.
5. **Manos default al spawn (roadmap #4):** con la captura activa
   (`cargo_capture_weapons` 1), tras asentarse el loadout + captura +
   reconcile (timer 0.25 > 0.1 del reconcile), el jugador spawnea
   **enfundado** en su estado elegido (Hands o nada) en vez del viewmodel
   vacío del engine. `corpus_cargo_hands` y `apexswep` (por si el original
   sigue montado) entran en `CARGO.Capture.Ignore` — las manos SON el
   estado desarmado, nunca un ítem.
6. **Crowbar/stunstick capturados caen en categoría `melee`** (autogen en
   `corpus_cargo_capture.lua`): sin esto la tecla 1 no tenía qué
   seleccionar — un crowbar capturado era `weapons` y no entraba al slot
   Melee. Los saves viejos sanan solos (la def se re-registra en el boot).
7. **Utilities → Corpus → Cargo:** checkbox de las teclas STALKER y
   checkbox "Holster to Hands" (la elección del holster que pidió el
   autor), con help del comando `cargo_holster`.

**Verificación previa (2026-07-12):** sintaxis 8/8 (luaparser) + harness
offline (lupa/LuaJIT, stubs GMod): file-scope de los 5 archivos
nuevos/tocados limpio (incl. el SWEP con su global inyectado), mapa de
hotkeys exacto al pedido (1-7 sobre slots reales), `Capture.Ignore` con
ambas clases de manos, matriz de `Decide` intacta y `SlotKey` robusto
(slot vacío / holster directo / fuera de rango). Selftest suma 2 checks
(mapa de hotkeys + melee dev equipable en su slot).

**Confirmado in-game por el autor (2026-07-12, cierre del entry):** el
mecanismo funciona ("está bien" en la 1.ª pasada), y el **fix de brazos
oscuros** quedó resuelto en el 2.º intento (control manual del lighting del
viewmodel, punto 2) — el autor lo confirmó aplicando el archivo **en vivo,
sin reiniciar**. El 1.er intento (`SetLightingOriginEntity`) había fallado y
se revirtió. Entry cerrado.

**Acción pendiente del autor (no bloquea el cierre):** remitir el fix de
brazos oscuros a Twilight Sparkle (mod original Workshop 2792160770). Del
roadmap #22 queda, para otra tanda, matar las notificaciones de obtención de
armas de GMod y verificar el 7.º slot contra el HUD D/GL4.

---

## 10. Bloque A: drop de armas + muerte + modelos dev (roadmap #17 · #18 · #15 parcial) `[APLICADO 2026-07-12]`

Segunda tanda del autor (2026-07-12), partida en dos bloques (metodología §2,
corte por cambio de modo temático). **Bloque A** = tres features concretas; el
sistema de munición (roadmap #19) va como Bloque B aparte. Ninguna suma
archivos nuevos (no toca el manifest).

1. **Compat "Drop Weapon" + drop nativo (roadmap #17, la mitad que faltaba)**
   (`corpus_cargo_capture.lua`): un **reconciliador universal** en el hook
   `PlayerDroppedWeapon` cubre CUALQUIER ruta de drop — el mod "Drop Weapon"
   (Workshop 946373028, cuyo `+drop` llama `ply:DropWeapon`), el comando
   nativo de Cargo o cualquier otro addon. Antes el arma botada por el mod
   salía de la mano pero **quedaba fantasma en `rec.equip`**; ahora el
   reconciliador **vacía el slot** (sin devolverla al grid — se va al mundo) y
   **taguea la entidad** con `CargoInstanceUid` + `CargoWorldSpawned`, de modo
   que el world gate no la aspira por contacto y el take-back (WALK+USE) la
   recupera como LA MISMA instancia (blob/attachments; el cargador `Clip1`
   viaja en la propia entidad). Decisión del autor: **el mod gana** — su
   comportamiento queda intacto, Cargo solo reconcilia. Comando nativo
   `cargo_drop` (bota el arma en mano al frente vía `ply:DropWeapon`, gateado
   por `cargo_native_drop` default 1) para el caso sin el mod. Tecla bindeable
   sin consola: convar cliente `cargo_key_drop` + poller de flanco en `Think`
   (`corpus_cargo_hotkeys.lua`, mismo patrón que la tecla de inventario) +
   **DBinder en el tab Q** (`corpus_cargo_options.lua`).
2. **Muerte pierde todo + toggle de persistencia (roadmap #15 parcial)**
   (`corpus_cargo_inventory.lua`): dos convars independientes.
   `cargo_lose_on_death` (`FCVAR_ARCHIVE`, default **0**): en `PlayerDeath`,
   `WipeOnDeath` borra grid + equipo + quick + cinturón y pone el dinero en 0
   **por el provider activo** (respeta DarkRP etc., §6), destruyendo las
   instancias alcanzables (host + sub-slots uid'd) para no dejar blobs
   huérfanos. Corre en `PlayerDeath` para que el `PlayerLoadout` reconcile
   encuentre `equip` vacío y no re-dé nada. `cargo_persistence`
   (`FCVAR_ARCHIVE`, default **1**): en 0, `GetRecord`/`SaveRecord` no leen ni
   escriben a disco (sesión en memoria; el equipo sobrevive al respawn DENTRO
   de la sesión vía `_records`, solo se pierde entre reinicios/reconexiones).
   Nota de deuda: los blobs de instancia (`inst_<uid>`) todavía escriben a
   disco con persistencia off — quedan huérfanos, GC futuro (roadmap #15).
3. **Modelos dev + sonido de curación** (`corpus_cargo_dev.lua`, pedido del
   autor): `cargo_dev_food` → `models/props_junk/garbage_takeoutcarton001a.mdl`;
   `cargo_dev_medkit` (el consumible de quick slots) →
   `models/items/healthkit.mdl` + `EmitSound("items/medshot4.wav")` en su
   `onUse`. El campo `model` alimenta `ResolveModel` (drops + render de ícono);
   el ícono re-keya solo (el modelo entra en `IconCacheKey`), sin regen manual.

**Verificación previa (2026-07-12):** sintaxis 5/5 (luaparser) + harness
offline (lupa/LuaJIT 2.1, framework real de `corpus/` + módulo real, ambos
realms): selftest 31/38 sin regresión, y **15 checks nuevos del Bloque A** —
persistencia (reload con on, fresh con off, SaveRecord no-op con off), wipe de
muerte (grid/equipo/quick/cinturón vacíos, dinero en 0 por provider, instancia
equipada purgada sin huérfano), reconciliador de drop (slot vaciado, entidad
tagueada con uid + world-spawned, instancia conservada para take-back, arma
no-Cargo intacta) — todo verde.

**1.ª pasada en juego (2026-07-12, feedback del autor):** `cargo_lose_on_death`
y `cargo_persistence` **funcionan** (el dinero se explica abajo); el modelo del
**medkit** aplicó, el de **comida NO**; y botar un arma **ARC9 EFT** escupió 5
errores de Lua. Fixes de la pasada:

4. **Persistencia del cargador (roadmap #18 — la causa real del reporte)**
   (`corpus_cargo_inventory.lua` + `corpus_cargo_capture.lua`). El autor:
   *"pasó de perder 3 balas a tenerlas todas cuando lo traje de vuelta al
   inventario"*. Causa: un arma que sale del jugador se **destruye como
   entidad** (strip al desequipar, `Remove` en el take-back) y vuelve por
   `ply:Give`, que reparte el `DefaultClip` del SWEP — cargador lleno gratis.
   Ahora el conteo de balas cargadas **viaja en el blob de instancia**
   (`blob.clip1`; Cargo transporta el número, la base del arma le da
   significado — contrato §3): `Inventory.StoreClip` lo guarda al desequipar,
   al botar (reconciliador) y en el take-back (antes del `Remove`);
   `Inventory.RestoreClip` lo restaura tras cada `ply:Give` (equip, loadout,
   reconcile) y `ApplyClipToEntity` en el arma de mundo dropeada desde el grid.
   Se aplica **ahora y un tick después** (la base del arma llena el clip en su
   propio `Initialize`/`Deploy`, después de que `ply:Give` retorna) y espeja
   `LoadedRounds` cuando el SWEP lo expone (ARC9 mantiene el cargador real en
   el `Clip1` nativo y lo replica ahí — verificado contra la base). El roadmap
   ya declaraba el #18 **prerequisito del #17**, así que cierra acá.
5. **Los 5 errores de ARC9 EFT NO eran nuestros** — y el drop nativo ahora los
   esquiva. Causa verificada contra el código vivo (`Arc9 EFT pistols/lua/
   weapons/arc9_eft_cr200ds.lua:403-406`): el revólver recarga **bala por
   bala** y arma un `timer.Simple(2)` **por cada una**; ese timer valida
   `IsValid(swep)` pero **nunca al dueño**, y hace
   `swep:GetOwner():GetAmmoCount(swep.Ammo)` → al botar el arma a media
   recarga los timers quedan huérfanos, `GetAmmoCount` devuelve nil y revienta
   `math.Clamp` (uno por bala pendiente = los 5 errores). Es bug de ARC9 y
   pasa igual con el mod "Drop Weapon" solo. ARC9 es **COMPAT-RUNTIME (nunca
   se forkea)**, así que `cargo_drop` simplemente **se niega a botar mientras
   el arma recarga** (`wep:GetReloading()`, NetworkVar real de la base) con un
   aviso. Un mod externo que llame `ply:DropWeapon` crudo puede seguir
   pegándole — no está en nuestras manos.
6. **El modelo de comida no aplicaba: `util.IsValidModel` NO alcanza como
   gate.** El path era correcto (`models/props_junk/garbage_takeoutcarton001a.mdl`
   existe — verificado parseando `hl2_misc_dir.vpk`), pero esa función
   devuelve **false** para modelos que están en el contenido montado y **nunca
   fueron precacheados en el mapa** — y el gate del pipeline de íconos
   retornaba **en silencio** (sin log), así que el ítem se quedaba con la letra
   y el drop con la caja de cartón. El medkit funcionaba porque HL2 precachea
   `models/items/healthkit.mdl` vía `item_healthkit`. Fix en dos capas:
   `CARGO.Items.ModelUsable(model)` (SHARED) = `util.IsValidModel` **o**
   `file.Exists(model, "GAME")`, usado ahora por el render de íconos, el
   footprint, el editor y la entidad de drop; y `Items.Register` **precachea**
   el `def.model` declarado en el server (también lo networkea al cliente).
   Arregla la clase entera del problema, no solo este ítem.
7. **El dinero NO persiste — se re-siembra** (aclaración, sin cambio de
   código). Con `cargo_persistence 0` el record nace fresco, así que la wallet
   se re-inicializa a **`cargo_money_start`** (default **$1000**) en cada
   sesión: no conserva el balance viejo, lo **regala de nuevo** al valor de
   arranque — indistinguible de "persistente" si tu balance ya era 1000.
   Verificado en el harness (con persistencia ON un balance de 6000 sobrevive;
   con OFF vuelve a 1000, no a 6000). Para arrancar sin plata: `cargo_money_start 0`.

**Verificación de los fixes (2026-07-12):** sintaxis 9/9 (luaparser) + harness
offline ambos realms: selftest 31/38 sin regresión y **24 checks** —
persistencia, dinero bajo el toggle (ON conserva 6000 / OFF vuelve a 1000),
wipe de muerte, reconciliador de drop, **round-trip del cargador** (StoreClip
al blob, RestoreClip pisando el DefaultClip 30→27, arma de mundo con su
cargador, y sin cargador guardado el DefaultClip queda intacto) y `ModelUsable`.

**2.ª pasada en juego (2026-07-12, feedback del autor):** comida **OK**,
persistencia **OK**, **sin errores de ARC9** (el guard de recarga funcionó).
Único frente abierto: el **cargador seguía volviendo lleno** (AK-19: disparar
15 de 30, mandarla al inventario y re-equiparla → 30 otra vez). Fix:

8. **ARC9 regala un cargador lleno: hay que RECLAMAR su bandera, no correrle
   una carrera** (`corpus_cargo_inventory.lua`). El punto 4 guardaba y
   restauraba `Clip1` bien — pero ARC9 lo pisaba después. Causa verificada
   contra la base viva (`sh_attach.lua:147-155`), dentro de `PostModify`
   (server, con dueño válido):

   ```lua
   timer.Simple(0, function()          -- corre tras acoplar cada attachment
       if (cambió ammo/clipsize) and self.AlreadyGaveAmmo then ...
       elseif !self.AlreadyGaveAmmo then
           self:SetClip1(self:GetProcessedValue("ClipSize"))  -- CARGADOR LLENO
           self.AlreadyGaveAmmo = true
       end
   end)
   ```

   `Initialize` siembra `AlreadyGaveAmmo = false` (`sh_init.lua:44`) y
   `PostModify` recién se asienta cuando lo hacen los attachments — **a un
   round-trip de red DESPUÉS de `ply:Give`**, o sea después de cualquier timer
   que nosotros pudiéramos encolar. Por eso ningún `timer.Simple(0)` alcanzaba.
   Solución: `ApplyClip` **reclama la bandera** (`wep.AlreadyGaveAmmo = true`)
   antes de fijar el `Clip1`; con ella en true ARC9 no toma ninguna de las dos
   ramas y nuestro cargador queda. Un arma **sin** cargador guardado nunca
   llega ahí (`RestoreClip` corta antes), así que un arma nueva sigue
   recibiendo su cargador lleno de ARC9, tal como corresponde. Aplica igual al
   arma dropeada como entidad (`ApplyClipToEntity`), que si no se rellenaba
   sola al recogerla.
9. **Mod "Drop Weapon": el autor lo da de baja** (lo saca de su suscripción de
   Workshop). La compat **se conserva tal cual** — el reconciliador de
   `PlayerDroppedWeapon` es agnóstico de la fuente y sigue cubriendo cualquier
   mod de drop futuro; el drop nativo (`cargo_drop`) pasa a ser la ruta única
   en su setup. Sin cambio de código.

**Verificación del fix (2026-07-12):** sintaxis OK + harness ambos realms:
selftest 31/38 sin regresión, 25 checks — incl. `AlreadyGaveAmmo` reclamada
sobre un SWEP que simula el estado post-`Initialize` de ARC9.

**Confirmado in-game por el autor (3.ª pasada, 2026-07-12 — cierre del entry):**
el drop de armas funciona completo, **incluso con el mod "Drop Weapon" todavía
montado** (el reconciliador universal cumple: el arma deja de quedar fantasma en
el equipo y vuelve como su misma instancia), y el cargador ya no se rellena solo.
Comida, persistencia y ausencia de errores de ARC9 ya venían confirmados de la
2.ª pasada. **Entry cerrado.**

**Dos frentes NUEVOS que abrió esta pasada — anotados, NO arreglados acá**
(decisión del autor: "eso no solucionar, anotar"):

- **ARC9 regala munición de reserva al tomar un arma** — *"la munición no puede
  aparecer del éter"*. Es `SWEP:InitialDefaultClip()` (`sh_deploy.lua:130-146`),
  que ARC9 dispara desde un `timer.Simple(0.4)` en su `Initialize`
  (`sh_init.lua:80-86`) y hace `ply:GiveAmmo(ClipSize * arc9_mult_defaultammo)`.
  **Es exactamente lo que contamina el "cinturón = pool real" del Bloque B**, así
  que se resuelve ahí → **roadmap #19** (ya documentado en la semilla
  `dev/HANDOFF_cargo_bloque_b_municion.md` §3.5, con las opciones a evaluar).
- **La retícula del grid se pierde con el inventario vacío / se corta con pocos
  ítems** → **roadmap #24** (nuevo). Causa probable: desde el entry 8 la dibuja el
  propio `DIconLayout` (para que comparta origen con las celdas y scrollee con el
  contenido), así que su alto = alto del contenido: sin ítems no hay nada que
  pintar, y con pocos se corta en el último.

---

## 11. Bloque B: sistema de munición — el cinturón ES el pool (roadmap #19) `[APLICADO 2026-07-12]`

Tercera tanda del autor (2026-07-12), arrancada en chat nuevo desde la semilla
`dev/HANDOFF_cargo_bloque_b_municion.md`. Cierra la **semántica** del cinturón que
el entry 8 (§15.2) había dejado como forma vacía. Diseño → **§16 nueva** de
`Cargo_Architecture.md`. Suma **dos archivos** (tocan el manifest).

**Modelo (decidido con el autor antes de codear):** el cinturón **no guarda**
munición, **ES** la reserva real del jugador (`ply:SetAmmo`/`GetAmmoCount`); el
grid es solo almacén. Las armas del mismo tipo HL2 **comparten** reserva (como HL2
y como STALKER); lo distinto por arma es el **cargador** (`Clip1`), que ya persiste
en el blob (#18, entry 10). **No** hay reserva por-arma con swap.

1. **Ítems de munición HL2 + mapa de calibres** (nuevo
   `shared/corpus_cargo_ammo.lua`): los **11 tipos base del engine** registrados como
   ítems (`cargo_ammo_<tipo>`), cada uno con **modelo**, peso por unidad, descripción
   y **`max_stack`** (el tope es lo que hace que los 6 slots del cinturón sean una
   decisión y no decoración). El schema de `def.ammo` gana **`hl2`** — el tipo de
   engine, que es **la clave del pool**; `caliber` queda como etiqueta de display
   (es sobre lo que agrupa el badge A/B). En el def de un **arma**, `def.ammo` lleva
   *solo* la etiqueta: el tipo real sale de la entidad. **Los 11 `.mdl` se verificaron
   parseando los VPK reales** (`hl2_misc_dir.vpk` → 2 201 `.mdl`, `garrysmod_dir.vpk`),
   no de memoria.
2. **El espejo cinturón ↔ pool** (nuevo `server/corpus_cargo_ammopool.lua`).
   Invariante: `GetAmmoCount(tipo) == suma de los stacks del cinturón de ese tipo`.
   `Push()` (cinturón → pool) usa **`SetAmmo`, nunca `GiveAmmo`**: asigna, así que
   empujar dos veces no infla nada. `Reconcile()` (pool → cinturón) es un **poll a
   4 Hz**: el pool es la **verdad del consumo** (recargar lo drena, descargar el
   cargador lo devuelve, granadas/cohetes lo gastan directo) y el cinturón lo sigue,
   así que el `x<n>` de la celda **es** el conteo real — la UI no necesitó cambios.
   **Poll y no hooks a propósito:** el pool lo muta la base de arma que el jugador
   tenga en la mano (ARC9, HL2, TFA…); pollear es **agnóstico de base** y cuesta 11
   lecturas de entero por jugador por tick. **El pool funciona sin un solo hook de
   ARC9.** Drenaje **por orden de slot** (1→6). La munición que vuelve de un cargador
   y no entra en el cinturón **no se destruye**: se va al grid.
3. **Muerto el éter** (el bloqueante que el entry 10 dejó anotado; reporte del autor:
   *"la munición no puede aparecer del éter"*). `SWEP:InitialDefaultClip`
   (`Arc9 Base/.../sh_deploy.lua:130-146`) hace `GiveAmmo(ClipSize * arc9_mult_defaultammo)`
   en **cada entrega de arma**, vía un `timer.Simple(0.4)` de su `Initialize`. Tres capas:
   (a) **la fuente** — Cargo fuerza `arc9_mult_defaultammo` a **0** (su default es **2**)
   al ready, mismo takeover que el puente de attachments ya hace con `arc9_free_atts`;
   (b) **el spawn** — en cada `PlayerLoadout`, `StripAmmo()` y después `Push()`: la
   reserva se reconstruye **del cinturón y de nada más**, diferido más allá de la
   ventana de 0.4 s de ARC9; (c) **el gate** — el reconciliador queda **suprimido**
   hasta que el `Push` de spawn del jugador corrió, así que nada de lo que una base de
   arma regale en la ventana de spawn puede lavarse al cinturón por el espejo.
   ⚠️ **Hueco declarado, no tapado:** `SWEP.ForceDefaultAmmo` **saltea la convar**
   (`sh_deploy.lua:140`) — dato que la semilla NO traía. Hoy la neutralización es
   **completa** para los 5 packs instalados (grep: ningún arma la usa con valor ≠ 0;
   solo las granadas EFT, que la ponen en 0), pero un pack futuro reabriría el hueco.
   **Escalación anotada:** ledger de conservación (pool + cargadores debe balancear).
4. **Munición del mundo → el GRID** (decisión del autor): los `item_ammo_*` del mapa se
   vetan al engine y entran como **ítem** al inventario, nunca como reserva a espaldas
   del jugador. Convar `cargo_ammo_world_pickup`. *Deuda:* las entidades propias de ARC9
   (`arc9_ammo`/`arc9_ammo_big`) reparten por su propio `Touch`, no por
   `PlayerCanPickupItem`, así que el espejo las absorbe al **cinturón** en vez del grid
   (no es éter — las balas están contadas — pero saltea el grid). Son props de sandbox:
   deuda, no parche a ciegas.
5. **Muerte + persistencia**: `WipeOnDeath` vacía **también el pool real** (el cinturón
   *era* la reserva: borrarlo sin borrar el pool dejaba al cadáver respawneando armado).
   El pool nativo no persiste, el cinturón sí → se re-siembra en cada spawn.
6. **`max_stack` respetado en el cinturón**: `BeltSet` topea el slot y **el excedente se
   queda en el grid** (antes fusionaba sin tope). El kit dev reparte munición real;
   `cargo_dev_ammo_9mm` ahora declara `hl2 = "Pistol"` — comparte pool con
   `cargo_ammo_pistol` **a propósito**: es el caso de prueba del punto 4 del autor (dos
   ítems de "calibres" distintos comiendo un solo tipo HL2).

**Convars nuevas:** `cargo_ammo_pool` (1), `cargo_ammo_arc9_takeover` (1),
`cargo_ammo_world_pickup` (1).

**Fuera de este bloque (confirmado con el autor):** cargadores rellenables con toggle;
el **binding de ammo-atts de EFT** (§16.6 — el stack activo del cinturón decidiría qué
attachment de bala va montado, dando balística realmente distinta sobre el mismo pool
HL2; el campo `def.ammo.att` queda reservado en el schema). Ambos, bloque siguiente.

**Verificación previa (2026-07-12):** sintaxis 6/6 (luaparser) + harness offline
(lupa/LuaJIT 2.1, framework real de `corpus/` + módulo real, ambos realms): **80 checks,
0 fallas**, de los cuales **22 nuevos del pool de munición** — el grid no es reserva, el
cinturón sí; case-insensitive (ARC9 escribe `"pistol"`, HL2 `"Pistol"`); recargar drena y
descargar devuelve; dos ítems distintos suman **una** reserva compartida; drenaje por orden
de slot; `max_stack` topea y el excedente no se pierde; el respawn reconstruye la reserva
**solo** del cinturón (el éter muere); la muerte vacía cinturón **y** pool; la caja del mapa
entra al grid y **no** al pool; y el takeover de `arc9_mult_defaultammo` a 0 al ready.
Selftest **40** (server) / **47** (client), era 31/38 — sin regresión. El harness ganó un
flush de timers (`RunTimers`/`ClearTimers`) para poder ejercitar la ruta de spawn.

**Falta:** verificación en juego (la corre el autor).

**1.ª pasada en juego (2026-07-12, feedback del autor): el núcleo del bloque
FUNCIONA.** Confirmado: la munición funciona, **ARC9 ya no entrega munición del
"éter"**, la muerte limpia todo, y el pool anda bien con ARC9 **no-EFT**. Un solo
bug del bloque, arreglado acá:

7. **Modelos de AR2 cruzados** (`corpus_cargo_ammo.lua`, reporte del autor:
   *"Dark energy rounds y Orb tienen los modelos cambiados"*). Los dos props de
   AR2 son fáciles de cruzar y se cruzaron: el **cartridge** es el cargador del
   rifle y la **ammo01** es la bola del alt-fire. Ahora `AR2` →
   `combine_rifle_cartridge01.mdl` y `AR2AltFire` → `combine_rifle_ammo01.mdl`,
   que es como los aparea HL2 en sus propios `item_ammo_ar2` /
   `item_ammo_ar2_altfire`.

**Frentes que abrió la pasada — NO son de este entry, van al bloque siguiente**
(semilla: `dev/HANDOFF_cargo_bloque_c_municion_ux.md`):

- **Reordenar el cinturón**: no se puede mover un stack que YA está en el
  cinturón de un slot a otro (30 de SMG en el slot 3 no van al 6). `BeltSet` solo
  acepta refs del **grid** — mover belt→belt no existe. → roadmap **#25**.
- **Descargar el arma** (quitarle la munición al cargador, con animación de
  reload): la munición va al cinturón, y si está lleno, al inventario. → roadmap
  **#26**.
- **Los ítems botados se recogen con USE pelado, no con WALK+USE**: el gate del
  #16 vive en el hook `PlayerUse` de `corpus_cargo_capture.lua` y **solo cubre
  armas** (`ent:IsWeapon()`); el `ENT:Use` de `corpus_cargo_item.lua:49` recoge
  incondicionalmente, así que la entidad de ítem esquiva el gate entero. →
  roadmap **#27**.
- **Coherencia de calibres con EFT** (que un rifle ARC9 no coma "dark energy"):
  el autor lo da por **aceptable por ahora** — los parches de coherencia exigirían
  depender de TODOS los mods EFT (las balas están dispersas entre ellos). Enlaza
  con el binding de ammo-atts (§16.6), que sigue pendiente y era esperado.

---

## 12. Bloque C: UX de munición (roadmap #25 · #26 · #27) `[APLICADO 2026-07-12]`

Cuarta tanda del autor (2026-07-12), arrancada en chat nuevo desde la semilla
`dev/HANDOFF_cargo_bloque_c_municion_ux.md`. El núcleo del Bloque B (entry 11)
quedó confirmado; este bloque completa la UX que la pasada dejó anotada. Plan
aprobado por el autor antes de codear: en el reorder el ocupante desplazado
**vuelve al grid**; el unload se dispara **por menú contextual y por comando**.

1. **Reordenar el cinturón (#25)** — belt→belt no existía como operación
   (`BeltSet` solo acepta refs del grid). Nueva `Inventory.BeltMove(ply, from, to)`
   + intent `belt_move`: destino vacío mueve; mismo id+condición **fusiona hasta
   `max_stack` y el resto se queda en el slot ORIGEN** (nada sale del cinturón en
   un merge); ocupante distinto **vuelve al grid** (decisión del autor, mismo
   comportamiento que el desplazamiento de `BeltSet`). El paso "merge con tope"
   se extrajo de `BeltSet` a un helper compartido (`BeltMergeInto`) — la regla
   vive en un solo lugar. Cliente: la celda del cinturón ya era
   `Droppable("cargo_item")`; su receiver gana la rama "el panel soltado es otra
   celda del cinturón" (`cargoBeltSlot`).
2. **Descargar el arma (#26)** — la mitad difícil ya existía (§16.3: el espejo
   absorbe lo que vuelve de un cargador; cinturón → excedente al grid). Nuevo
   disparador `AmmoPool.UnloadWeapon(ply)` sobre el **arma activa**, intent
   `unload`: **ARC9 por SU API** (`SWEP:Unload(GetProcessedValue("Ammo"))`,
   sh_reload.lua:199-205 verificado — COMPAT-RUNTIME, cero fork); no-ARC9 a mano
   (`GiveAmmo(Clip1, game.GetAmmoName(...))` + `SetClip1(0)`). `Reconcile`
   inmediato (sin esperar el poll de 250 ms) y `StoreClip` después: el cargador
   vacío **persiste en el blob** (#18). **Gate de spawn**: denegado hasta que el
   `Push` de spawn corrió (las balas morirían en el `StripAmmo`+`Push`).
   **Animación**: ARC9 reproduce su anim de reload **solo si la entry no declara
   `RestoreAmmo`** — ese flag re-llena el clip DESDE LA RESERVA en un timer
   interno de `PlayAnimation` (sh_anim.lua:130-133 → `RestoreClip`) y desharía
   el unload; se consulta por su propia API. Tercera persona: gesto de reload.
   No-ARC9: `SendWeaponAnim(ACT_VM_RELOAD)` + gesto. Disparadores cliente:
   opción **"Unload magazine"** en el menú contextual del slot equipado (solo si
   esa arma está en la mano) + comando **`cargo_unload`** (bindeable).
3. **Gate WALK+USE para ítems botados (#27)** — el `PlayerUse` de `capture.lua`
   filtraba `ent:IsWeapon()` y el `ENT:Use` de `corpus_cargo_item` recogía
   incondicionalmente (USE pelado aspiraba la munición dropeada). El hook ahora
   cubre también `corpus_cargo_item`: USE pelado = carry de prop HL2 (el
   `return false` bloquea el `ENT:Use`); WALK+USE = el hook se corre a un lado y
   `ENT:Use` recoge como siempre. Se reusa el debounce (`CargoNextWorldUse`) y
   la marca "USE de nuevo suelta" (`CargoCarryEnt`) que las armas ya pagaron.
   La entidad no cambió (solo su comentario de header); el convar
   `cargo_world_guns` sigue gateando solo la rama de armas.
4. **Fix de duplicación latente en `Reconcile`** (encontrado al testear el #26):
   cuando el excedente de un unload iba al grid **con éxito**, el pool no se
   bajaba (`SetAmmo` solo corría en la rama de fallo) — el poll siguiente volvía
   a ver `pool > belt` y **re-acuñaba el mismo excedente cada 250 ms**. Era
   inalcanzable en la práctica en el Bloque B (sin unload, con el éter muerto);
   el #26 lo volvía ruta ordinaria. Ahora el pool baja a la suma del cinturón
   siempre que el excedente sale hacia el grid.

**Sin convars nuevas.** Net nuevo: `belt_move`, `unload` (vía
`Corpus.Net.Register`, como todo).

**Verificación previa (2026-07-12):** sintaxis 5/5 (luaparser) + harness offline
extendido (`dev/harness_cargo.py`): **110 checks, 0 fallas** (eran 80; +30 del
bloque — reorder con merge/tope/swap-al-grid e inputs degenerados, intent de red,
unload no-ARC9 y ARC9 con blob + cinturón lleno → grid, anti-dup del poll, gate
de spawn, y el use-gate de ítems con debounce/carry/suelta). Selftest 40 (server)
/ 47 (client) — sin regresión.

**Pasada en juego (2026-07-12, autor): TODO CONFIRMADO — CERRADO.** Cinturón:
fusión, belt→grid y reorden OK; el autor intentó además el **exploit** de
recargar y rotar la munición rápido buscando reserva "gratis" y **no funcionó**
(el espejo aguantó). Unload con ARC9 OK: **la animación corrió y el contador NO
se re-llenó después** (el guard de `RestoreAmmo` hizo su trabajo). Munición
botada: WALK+USE toma, USE pelado carga. Sin bugs del bloque.

**Frentes que abrió la pasada — NO son de este entry** (van al roadmap
**#28-#31**): falta **drop de armas equipadas** desde su slot; el **color de la
UI** debe ser neutro estilo spawnmenu e integrarse con el preset del HUD DGL4
del autor (PCV de Opposing Force / Foxtrot uniform; mod nuevo en `dev/other/`:
"[dgl4] official presets pack"); los **íconos de armas del spawnmenu no llegan
al inventario** al clickearlos (sin toolgun no hay forma de obtener
physgun/toolgun/camera); falta un **wheel menu** (diseño pendiente en Claude
Desktop).

## 13. Wheel menu + slot Throwable + enmiendas de la columna (roadmap #31 · #21 fix · §4/§15.2) `[PENDIENTE]`

Quinta tanda, bajada de la sesión de diseño en Claude Desktop (2026-07-13,
ratificada por el autor; prompt semilla `dev/PROMPT_CC_Cargo_wheel_y_equipcolumn.md`).
Mockups congelados en `docs/mockups/`: `cargo_wheel_menu_mock_v2_1.html` y
`cargo_equipcolumn_throwable_mock_v1_1.html` (+ PNGs de referencia). Ejecutada
en **modo auto**: el autor no verificó en juego todavía — checklist consolidado
en `cargo_estado.md` §"Pendiente de verificar". Cuatro frentes, un commit cada uno:

1. **Primitiva de círculo** (`3e3f367`) — los círculos sandbox se veían con
   bordes duros in-game (#21): el polígono de 24 segmentos + `surface.DrawCircle`
   no alcanzan a tamaño de slot (y `draw.RoundedBox` con radio mitad tampoco es
   círculo: su radio está cuantizado a los materiales de esquina — trampa
   anotada). `Theme.DrawCircle` (polígono triangulado, 32/48 segmentos según
   radio) + `Theme.DrawCircleOutlined`, elegido sobre un material con alpha
   porque no necesita asset y tinta directo de la paleta (#29 gratis).
   Consumidores migrados: círculos sandbox, botón `$`, hub del wheel.
2. **Slot `throwable`** (`fd17ee3`) — enmienda §4: primer slot de **stack** del
   equipo (`rec.equip.throwable` = entry `{id, count, condition?}`, no uid;
   todos los consumidores de `rec.equip` ramifican con `istable()`). Categoría
   `throwables`, give/take del `weapon_class`, badge `×N`, sin barra de
   condición, sin remap legacy. **El `×N` es reserva real**: el stack equipado
   entra al espejo de §16 (suma en `BeltTotals`) y **se drena primero** al
   lanzar; vaciarse vacía el slot y stripea el SWEP. El give del equip va con
   `noAmmo` (el default clip de `weapon_frag` caería al pool → éter lavado al
   cinturón) y el equip/unequip hace `AmmoPool.Push`. El capture aprende a ver
   el stack equipado (`EquippedClassCount`/`HasWeaponItem` vía `EquippedDefOf`)
   — sin eso el give del equip se recapturaba y duplicaba. Ítem dev
   `cargo_dev_frag` (weapon_frag, hl2 `Grenade`, max_stack 4) en el kit.
   *Borde conocido:* `cargo_drop` con la granada en mano bota el SWEP sin tocar
   el slot — coherente con el modelo (los "rounds" viven en el slot; el
   take-back re-equipa por `keep`), y el drop desde slot es #28 (fuera de tanda).
3. **Enmiendas de la columna** (`938951a`) — §15.2: fila baja **apilada (Clear
   Sky)**: 3 columnas, la tercera se divide en Throwable (chico, arriba) sobre
   Melee; Sidearm/Back conservan su ancho (la variante de 4 columnas queda
   descartada, vive solo en el mock). Círculos sandbox: **toggle "hide"
   restaurado** (chip; oculto, la fila colapsa) + alineación `cargo_ui_tools_align`
   (left default / center), ambas en el tab Q; selección factorizada en
   `CARGO.UI.SelectTool`. **El panel de estado se estira hasta el fondo** de la
   columna (era alto fijo); las barras siguen siendo registrables (§11) — nada
   se hardcodea; **HL2 Armor queda declarado legacy** (sale cuando Caliber
   Block 3 traiga la armadura propia; hoy se conserva como demo bar).
4. **Wheel menu** (`8602625`) — roadmap #31, archivo nuevo
   `client/corpus_cargo_wheel.lua`. **Cero lógica de server nueva**: commit de
   sector = intent `slotkey` existente (el resolver del holster solo suma el
   intent **8** wheel-only del throwable — `CARGO.Slots.WheelSlots`; el cliente
   jamás intercepta `slot8`), chips quick = ruta de quick use existente, chips
   de herramientas = `CARGO.UI.SelectTool`, gated por `cargo_ui_tools`. Dibujo
   por HUDPaint sin VGUI (cursor libre con `gui.EnableScreenClicker`; los
   clicks no disparan), sectores anulares por `surface.DrawPoly` en quads
   convexos, colores 100% del theme. Geometría y mapa reloj del mock v2 (una
   sola función de layout). Hub = superficie de información universal (fire
   mode por `SWEP:GetFiremodeName()` de ARC9 — verificado contra
   `sh_firemodes.lua:158`, se oculta si no está; reserva = pool del engine que
   el espejo §16 mantiene igual al cinturón). Hold/release con
   `cargo_key_wheel` (default G, **con aviso** si la tecla ya tiene bind) o
   `+cargo_wheel`; anclajes de chips configurables con resolver único y
   fallback logueado. Todo configurable desde el tab de Cargo del menú Q.

**Verificación offline:** `luaparser` limpio en todo lo tocado; harness
`dev/harness_cargo.py` extendido con **+18 checks** del throwable (equip,
espejo, drain slot-primero, unequip, rechazo de uniques, peso) y **+17** del
wheel (anclajes/colisión, layout, pick por sector/chip/deadzone/fuera, commit
del intent, no-op honesto, HUDPaint limpio) — **verde en ambos realms**; +5
checks puros en `cargo_selftest` (52 client / 45 server). Lo NO testeable
offline (que los círculos SE VEAN circulares, el layout apilado, el teñido del
hover, el hub legible) queda declarado al checklist en juego.

## 14. Bloque D: pendientes de UX (roadmap #30 · #28 · #24 · #29) `[PENDIENTE]`

Sexta tanda, arrancada de la semilla `dev/HANDOFF_cargo_bloque_d_ux_pendientes.md`
(causas ya diagnosticadas a nivel `archivo:línea` — no se re-investigaron) y
ejecutada en **modo auto** en la misma sesión que el entry 13. Orden del
handoff (#30 → #28 → #24 → #29), un commit por frente; checklist consolidado
en `cargo_estado.md`.

1. **Spawnmenu → inventario (#30)** (`7d3febc`) — el click del ícono corre
   `gm_giveswep`, cuyo `ply:Give` es **anónimo**: el filtro de tools del entry
   8 lo descartaba (indistinguible del loadout de spawn) y sin toolgun no había
   forma de obtener physgun/toolgun/camera. La señal que faltaba:
   **`PlayerGiveSWEP`** (sandbox `commands.lua:940`) corre justo antes del give
   y solo en esa ruta — el hook marca al jugador (clase + `CurTime`, sin
   devolver nada: un return secuestraría el allow/deny de sandbox) y la captura
   consume la marca como `deliberate` (semántica del WALK+USE), ventana 1 s.
   El dedup no cambia pero avisa ("You already have one.") en vez de comerse
   el click en silencio.
2. **Drop desde el slot (#28)** (`06d711c`) — opción "Drop" en el menú del
   slot equipado (incl. círculos de herramienta y throwable) → intent
   `equip_drop` → `Inventory.DropEquipped`, todo con maquinaria existente:
   arma en mano va por `ply:DropWeapon` (el reconciliador universal contabiliza
   UNA vez; guard ARC9 de recarga compartido — `Capture.DropBlockedByReload`);
   arma no-en-mano stripea y `SpawnWorldWeapon` con su instancia + `StoreClip`;
   gear no-arma cae como `corpus_cargo_item` con el blob entero (placas y
   sub-slots viajan DENTRO — nada se pierde); el stack throwable cae como ítem
   y su reserva sale del pool. Body dropeado dispara `Corpus_Cargo_BodyChanged`.
3. **Retícula del grid (#24)** (`4c0a8a2`) — la pintaba el propio `DIconLayout`
   (alto = contenido: vacío no había retícula, con pocos ítems se cortaba).
   Ahora la pinta el fondo del viewport (`scroll.Paint`) desplazada por el
   **offset del canvas** (`(GetPos()+GAP) % (U+GAP)`): cubre el área visible
   siempre y la fase queda clavada a las celdas — la alineación del entry 8
   no regresa. Offline solo se barre que no explote; **lo visual es del
   checklist**.
4. **Paletas runtime + DGL4 (#29)** (`81f2f5c`) — contrato de tokens del mock
   `cargo_theme_dynamic_mock_v1_1.html`. Las paletas mutan los `Color` de
   `T.Colors` **en sitio** (misma identidad) — todos los closures se
   re-skinnean gratis. Base default **spawnmenu** (grises neutros del mock del
   autor; la oliva GAMMA queda como `cargo_theme olive`); claves nuevas
   `accent`/`accentDim`/`scrim` (fin de los colores hardcodeados del scrim).
   Con DGL4 montado y `cargo_theme_dgl4` (default 1) la paleta deriva del
   preset activo: tint global de `GetModifiers().color` o — **decisión
   anotada**, los presets no exponen nombre — el color sano de `health_color`
   (umbral más alto) del elemento `health` (Foxtrot Uniform = verde PCV
   180,255,100, leído de `preset4.lua`). Re-tint en vivo por el hook propio
   `OnSettingsChanged` de HOLOHUD2. Sin mod / API rota: base neutra, jamás
   crash. FX del mock (glow/scan) quedan anotados como futuros, no entran.

**Verificación offline:** harness extendido **+29 checks** (7 del #30 con el
flujo `PlayerGiveSWEP`→`WeaponEquip` completo, 14 del #28 con las cuatro
formas del drop, 8 del #29 con HOLOHUD2 stubbeado) — **verde en ambos
realms**. El stub de `Vector` ganó aritmética (posiciones de drop). Lo visual
del #24/#29 (retícula, colores reales del teñido) es de la pasada en juego.

### Addendum entries 13/14 — 1.ª pasada in-game (2026-07-13, 42 OK / 5 fallas)

El autor corrió el checklist completo. **Confirmado en juego:** círculos,
throwable entero (equip/lanzar/drenaje/persistencia), geometría y commit
básico del wheel, columna apilada, #30 completo, #28 completo (las 4 formas),
#24 y #29 completos. **Fallas → fix `dfeafcc`:**

1. **Granadas por contacto** (reporte aparte): la ventana de give del world
   gate dejaba pasar el touch de SWEPs recién spawneados por el click medio
   del spawnmenu; con la clase ya en poder, el bump del engine absorbe la
   munición y el espejo la deposita en el cinturón (no en el ×N — "el
   contador no se actualiza"). Fix: `PlayerSpawnedSWEP` taguea
   `CargoWorldSpawned` desde el primer frame + mismo tag para la cáscara del
   throwable botada con `cargo_drop`.
2. **Hub/chips del wheel muertos** (4 fallas con una sola forma: abrir/equipar
   OK, hub sin actualizar, chips sin responder): GMod desengancha un HUDPaint
   que erroró — un hover malo y el wheel muere en silencio la sesión entera.
   Pintado y commit ahora en pcall con `Corpus.Log` ruidoso (la ronda 2
   reporta la línea exacta si persiste) + `gui.MousePos` leído antes de
   apagar el screen clicker.
3. **Peso/velocidad (regresión reportada)**: no se reproduce offline (curva,
   TotalWeight con slot de stack y movement verdes en el harness) — a la
   ronda 2 con el log del wheel activo; sospecha: colateral de los errores
   de sesión del punto 2.

### Addendum 2 — 2.ª pasada in-game (2026-07-13, 46 OK / fallas reales: 3)

El fix `dfeafcc` **funcionó**: holster desde el sector activo, hub actualizando
en los tres tipos de hover y quick use desde el chip F1 pasaron en la ronda 2
(las marcas 19-22/52 del reporte son estado persistido de la ronda 1 — sus
gemelos de la ronda 2 pasaron). Granadas ya no se toman por contacto en la
ruta arreglada. Quedan **3 frentes abiertos**, diagnóstico y semilla en
`dev/HANDOFF_cargo_pendientes_pasada2.md` (roadmap **#32 #33 #34**):

1. **#32 Taxonomía de granadas + gate de cajas de munición.** El frag de HL2
   aparece como ítem de MUNICIÓN (cara canónica `cargo_ammo_grenade` del
   Bloque B) al morir/spawnearlo — el autor lo quiere LANZABLE (throwable);
   la granada del SMG1 sí es munición. Además las cajas `item_ammo_*`
   spawneadas con click medio se toman por contacto (diseño del Bloque B,
   hoy indeseado): extender el patrón WALK+USE también ahí.
2. **#33 Hub ARC9 incompleto.** Muestra "Auto · Group A" — faltan calibre
   (los defs autogen no llevan `def.ammo`) y cargador/reserva (`AmmoInfo`
   devolvió nil con SWEP válido — FiremodeOf sí funcionó).
3. **#34 Velocidad vs mod de movimiento.** El autor identificó la causa: su
   mod de movimiento ("better movement v2") sobreescribe walk/run y pisa la
   curva de Cargo. El footer sí muestra bien. COMPAT-RUNTIME: leer el mod
   vivo antes de elegir palanca.

Los entries 13 y 14 siguen `[PENDIENTE]` hasta que estos tres cierren y el
autor confirme la pasada limpia.

## 15. Assets ZONA + pesos reales GAMMA para armas capturadas (roadmap #15 parcial) `[PENDIENTE]`

Sesión paralela a los frentes #32-34 (2026-07-13), pedida por el autor: darle
cuerpo STALKER a los ítems dev y peso real a las armas EFT. Dos piezas, una
fuera del repo y otra adentro:

1. **Addon opcional `corpus_zona_assets`** (vive en `dev/corpus_zona_assets/`,
   FUERA de todo repo git — assets de GSC, no publicables; junction en
   `garrysmod/addons/` como los seis repos). Contenido: los 122 props de ítem
   de "zona stalker props" (Workshop 315505698) + los 27 playermodels y brazos
   first-person de "zona stalkerrp content" (300746843), rutas verbatim (los
   `.mdl` referencian materiales por ruta compilada), y
   `lua/autorun/corpus_zona_playermodels.lua` — registro adaptado del lua de
   Cluelesshobo (prefijo "ZONA" en el selector, fix del path de Seva Cadpat y
   del typo "Heayv"). Créditos y política de retiro en su README.md; inventario
   fuente en `dev/zona_stalkerrp_contenido.md`.
2. **Modelos ZONA en el kit dev** (`corpus_cargo_dev.lua`): helper `ZonaModel`
   (existencia vía `file.Exists` + fallback honesto — sin el addon montado los
   defs quedan como estaban; contrato #9, detección nunca asunción). Asignados:
   helmet→`hardhat`, nvg→`dome_mask` (stand-in), vest→`cs_light` (el gemelo
   Clear Sky del "CS-3a"), backpack→`hgn/srp/backpack-1`,
   plate→`materials_textolite` (stand-in), medkit→`medical/medkit1`,
   food→`food/tuna`, ammo 9mm→`ammo/9x19`, pda→`handhelds/pda`,
   detector→`scanner_anomaly`.
3. **Pesos reales para autogen (`corpus_cargo_weapon_weights.lua`, nuevo,
   server)**: tabla `CARGO.Capture.WeaponWeights` clase→kg con las ~100 armas
   de los packs ARC9 EFT, poblada desde la **base de datos de STALKER GAMMA
   0.9.5** (stalker-gamma-db.com, campo `st_prop_weight` de los JSON
   `/data/gamma-0.9.5/<categoría>.json`, bajados 2026-07-13). Las clases que
   GAMMA no tiene (MCX, Spear, AXMC, granadas M-series…) llevan valor EFT/real
   aproximado, comentado `EFT approx`. Cuidado pagado: `arc9_eft_vss` mapea a
   `wpn_vintorez` (el `wpn_vssk` de GAMMA es el VKS Vykhlop). También pesos
   verosímiles para el arsenal HL2/sandbox (physgun 4.0, toolgun 2.0…).
   `RegisterAutogen` consulta la tabla y cae a 2.5 kg nominal si la clase no
   está; el manifest la carga justo antes de `capture.lua`, así el
   re-registro de defs autogen persistidos re-pesa TODO lo ya capturado en el
   próximo load. Sin migración: el peso vive en el def, no en los blobs.

**Sin convars ni net nuevos.** Verificación previa: sintaxis 5/5 (luaparser);
paths de modelo verificados contra el addon (13/13 existen).

**Checklist en juego:** (a) menú C → playermodels "ZONA *" con brazos propios;
(b) `cargo_dev_give` → helmet/vest/backpack/plate/medkit/food/ammo/pda/detector
con ícono STALKER renderizado (no letra); (c) spawnear un arma EFT (p. ej.
AK-74M) → tooltip pesa 3.4 kg y el footer de peso lo refleja; (d) desmontar el
addon ZONA → los dev items vuelven a su modelo anterior/letra sin errores.

## 16. Frentes de la 2.ª pasada: taxonomía de granadas, hub ARC9 y compat de movimiento (roadmap #32 · #33 · #34) `[PENDIENTE]`

Séptima tanda, arrancada de la semilla `dev/HANDOFF_cargo_pendientes_pasada2.md`
(los tres frentes que dejó la 2.ª pasada in-game de los entries 13/14) y
ejecutada en modo auto. Un commit por frente; los entries **13 y 14 siguen
`[PENDIENTE]`** hasta que el autor confirme estos tres en juego.

1. **Taxonomía de granadas + gate de cajas de munición (#32)** (`4d5d43b`) —
   la cara canónica de los tipos HL2 `Grenade`/`slam` deja de ser munición de
   cinturón: `cargo_throw_frag` / `cargo_throw_slam` (categoría `throwables`,
   slot de stack §4) viven en `corpus_cargo_ammo.lua` junto al resto de los
   tipos manejados — el SLAM va con el frag por dirección del handoff (misma
   forma del conflicto); la granada del SMG1 sigue siendo munición. El espejo
   §16 aprende la cara: `AbsorbType` tope el stack EQUIPADO bajo max_stack (el
   ×N se mueve cuando el engine regala una granada — el reporte de la ronda 1)
   y el excedente cae al grid clampeando el pool (el grid es almacén, no
   reserva; decisión conservadora: nunca auto-equipa el slot vacío). La
   captura ya no acuña `wpn_weapon_frag`: la entidad del give muere y el
   espejo contabiliza; con el stack equipado la clase es suya (keep — el
   take-back del entry 13 intacto). Ids muertos (`cargo_ammo_grenade/slam`,
   `cargo_dev_frag`, `wpn_weapon_frag/slam` → `CARGO.Ammo.LegacyThrowIds`)
   remapean al cargar records y contenedores; el stack legacy del cinturón
   baja al grid. `cargo_dev_frag` sale del kit dev (entra el real). ADEMÁS:
   las cajas `item_ammo_*` ya no se toman por contacto — `PlayerCanPickupItem`
   pasa a veto puro y la toma es WALK+USE en el MISMO gate de `PlayerUse` de
   `capture.lua` (USE pelado carga como prop; `cargo_ammo_world_pickup 0`
   restaura el pickup crudo del engine), leyendo `AmmoPool.WorldAmmoSpec`.
2. **Hub ARC9 del wheel (#33)** (`f458a08`) — diagnóstico contra el ARC9 vivo:
   `GetPrimaryAmmoType` no es confiable en ARC9 (el `Primary.Ammo` de clase es
   `""` — `shared.lua:334` — y solo `Initialize` lo corrige por instancia) y
   un `Clip1` de -1 delata local weapon data sin networkear. `AmmoInfo` sigue
   ahora la ruta del propio `Ammo1()` de ARC9 (`GetProcessedValue("Ammo")`,
   `sh_reload.lua:578`) con respaldo en el campo plano `SWEP.Ammo` (dato
   estático de clase: `"smg1"/"ar2"/"357"` en los packs EFT) y recién después
   `GetPrimaryAmmoType`; el clip cae al espejo `GetLoadedRounds` (NetworkVar
   broadcast, `shared.lua:1592`) cuando `Clip1` responde -1. El calibre: los
   defs autogen nacen/upgradean con `def.ammo.caliber` resuelto del arma viva
   y persistido en el registro; la etiqueta es LA DEL POOL de Cargo (la misma
   con que agrupa el cinturón — el calibre EFT real solo existe como token de
   trivia sin API, decisión anotada), y el hub la deriva en runtime cuando el
   def no la trae (`CARGO.Wheel.CaliberOf`). El tooltip gana la fila de ammo
   en capturadas gratis.
3. **Velocidad vs mod de movimiento (#34)** (`9b48dc2`) — leído contra el mod
   vivo: el `SetupMove` de better movement v2 reescribe `SetWalkSpeed/
   SetRunSpeed` CADA tick desde sus convars (`sh_bm_main.lua:455-457`) — las
   bases capturadas mueren al tick siguiente. Palanca elegida (la menos
   invasiva del handoff): hook `Move` propio y SHARED
   (`corpus_cargo_movecompat.lua`, nuevo en el manifest) que corre DESPUÉS de
   `SetupMove` y escala el `MaxSpeed` del move data con el mult de la curva,
   publicado por `Movement.Refresh` en un NW2Float; piso absoluto 30. No toca
   al mod ni realimenta su matemática; sin el mod o con `sv_bm_enabled 0` la
   pata no corre (vanilla intacto); `cargo_movement_compat 0` la apaga. Borde
   cosmético declarado: los pasos del mod se timean con SU velocidad lerpeada.

**Verificación offline:** `luaparser` limpio en todo lo tocado; harness
`dev/harness_cargo.py` extendido por frente (taxonomía/absorción/captura/remap
del #32, stub ARC9 frío y sano + calibre en captura del #33, decisión pura +
escala/piso/toggles del #34) — **220 checks verdes en ambos realms**; selftest
actualizado a la cara canónica (`cargo_throw_frag`, mapa clase→throwable).
Checklist en juego (corto, solo #32-34 + regresión) en `cargo_estado.md`.

### Addendum entry 16 — pasada del autor (2026-07-13): 1-5 OK + flecos

El autor corrió el checklist corto: **los cinco puntos pasaron** (#32
granadas y cajas, #33 hub, #34 velocidad, regresión). Flecos de la misma
pasada, arreglados en el acto:

1. **Letras del wheel** (`46afd09`) — los labels chicos en el borde de cada
   sector no estaban en el mock congelado: el contenido va agrupado en el
   radio medio (info encima del ícono: ×N / cargador-reserva / label según
   aplique; label solo en vacíos; punto de en-mano fuera del anillo).
2. **Hatching de quickslots bloqueados** (`46afd09`) — sangraba fuera del
   chip: HUDPaint no tiene clipping de panel — scissor rect.
3. **Scroll del inventario en Derma stock** (`46afd09`) — `Theme.SkinScroll`
   sobre el grid y el editor de íconos; el re-tinte DGL4 lo alcanza gratis.
4. **`cargo_dev_dump_weapons`** (`40639b3`) — pedido del autor: volcado del
   arsenal ARC9 (clase/nombre/tipo/ammo/clip/peso actual) a consola +
   `data/corpus/cargo/weapon_dump.txt` para cruzar con la GAMMA DB (entry 15).
5. **Footsteps mudos con `sv_bm_enabled 0`** — diagnóstico contra el mod
   vivo, LADO MOD (no se toca): con `sv_bm_slow_footsteps 1` el mod suprime
   los pasos del engine devolviendo `math.huge` en `PlayerStepSoundTime` y
   los toca él mismo desde un Tick; al apagar `sv_bm_enabled` su Tick muere
   Y el engine quedó agendado al infinito → silencio hasta respawn/cambio de
   mapa. Remedio: `sv_bm_slow_footsteps 0` antes de apagar, o respawnear.
   Nuestra pata de compat no toca rutas de sonido.

Harness tras los flecos: **229 checks verdes en ambos realms** + gate final
nuevo (un FAIL tardío ya no puede imprimir ALL GREEN). Queda el re-chequeo
visual de 1-3 en juego; con eso los entries 13/14/16 flipean juntos.
