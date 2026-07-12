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

## 8. UI fullscreen: 3 columnas / 3 estados, gradas, cinturón y círculos sandbox (§15) `[PENDIENTE]`

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
