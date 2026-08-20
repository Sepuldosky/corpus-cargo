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

## 4. Feed de pickup en pantalla + baja del mod L4D `[APLICADO 2026-07-13]`

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

### Addendum — re-verificación de la tanda de flecos (2026-07-13): FLIP

Re-verificado por el autor contra el código de HOY (el checklist original era
pre-entry 7; la toma de mundo es WALK+USE desde entonces): **(a) WALK+USE
sobre arma de mundo → el feed señala ✓; (b) `cargo_pickup_feed 0` lo apaga ✓;
(c) regresión del gate (nada por contacto ni USE pelado) ✓.** Frente NUEVO
que dejó la pasada (→ roadmap #37, NO bloquea este entry): las armas de
**VJ Base** se toman una sola vez con USE, entran bien al inventario, pero
al dropearlas **vuelven de inmediato al inventario** (re-captura instantánea
del drop) — diagnóstico primero, `archivo:línea`, después arreglo.

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
   `cargo_weapon_world_pickup` sigue gateando solo la rama de armas.
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

## 13. Wheel menu + slot Throwable + enmiendas de la columna (roadmap #31 · #21 fix · §4/§15.2) `[APLICADO 2026-07-13]`

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

## 14. Bloque D: pendientes de UX (roadmap #30 · #28 · #24 · #29) `[APLICADO 2026-07-13]`

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

## 15. Assets ZONA + pesos reales GAMMA para armas capturadas (roadmap #15 parcial) `[APLICADO 2026-07-13]`

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

### Addendum — pasada del autor (2026-07-13): a-c ✓, queda solo (d)

**(a) ✓** con notas de ASSETS (lado addon `corpus_stalker`, territorio del
autor — no bloquean): texturas negras en el cuerpo de "ZONA SEVA Woodland /
Seva Heavy / EXO-Heavy" (botas, casco, guantes y mochila respiradora bien) y
en el chaleco de "ZONA Seva Cadpat / Seva Freedom Heavy / Seva Monolith
Heavy"; el resto bien — huelen a `.vmt/.vtf` faltantes en el copy, revisar
contra el inventario `dev/zona_stalkerrp_contenido.md` cuando se priorice.
**(b) ✓** con stand-ins asumidos y anotados: la placa es una placa de
circuitos (`materials_textolite`, ya declarado stand-in), el NVG es un
kneepad (`dome_mask` era stand-in; candidato a mejor modelo del pack), pda y
detector perfectos. **(c) ✓** — y deja idea del autor → roadmap #38: mover
el "autocaptured" del footer del tooltip a la trivia estilo ARC9, y/o
generar trivias reales para el arsenal EFT del volcado. **(d) sin probar**
(por tiempo, decisión del autor) — el entry queda `[PENDIENTE]` SOLO por la
degradación sin addon; todo lo demás confirmado.

### Addendum 2 — ronda 2 (2026-07-13): FLIP

**(d) ✓** — con `corpus_stalker` desmontado los dev items degradaron sin
errores. Entry completo.

## 16. Frentes de la 2.ª pasada: taxonomía de granadas, hub ARC9 y compat de movimiento (roadmap #32 · #33 · #34) `[APLICADO 2026-07-13]`

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

### Addendum 2 entry 16 — re-chequeo visual (2026-07-13): TODO OK

El autor confirmó los flecos: **letras del wheel, hatching y scroll
perfectos**, y el volcado de `cargo_dev_dump_weapons` generado. Con esto los
cinco puntos + los flecos del entry 16 están completos — los entries
**13/14/16 quedan listos para flipear** en la tanda de cierre (semilla
`dev/HANDOFF_cargo_cierre_entries_13_14_16.md`).

**Excepción, queda ABIERTO (→ roadmap #35):** los footsteps siguen mudos al
togglear `sv_bm_enabled 0`, y el remedio hipotetizado
(`sv_bm_slow_footsteps 0`) NO funcionó — el diagnóstico del addendum
anterior (math.huge en `PlayerStepSoundTime`) queda como sospecha no
confirmada. Es comportamiento del mod de movimiento (nuestra pata de compat
no toca rutas de sonido), pero se anota como frente propio para investigarlo
con el mod vivo en juego, no de memoria.

---

## 17. Resto del #22: muere el historial stock de pickups + veredicto 7.º slot vs DGL4 `[APLICADO 2026-07-13]`

Tanda de flecos (semilla `dev/HANDOFF_cargo_flecos_15_22_4.md`), 2026-07-13.
Las dos mitades que el entry 9 dejó del roadmap #22:

1. **Veto del historial stock de GMod** (`corpus_cargo_pickup.lua`). La
   sospecha del handoff (`CHudHistoryResource`) era incorrecta a medias,
   verificado contra el juego vivo: el historial de pickups NO es un elemento
   del engine — lo dibuja Lua del gamemode base
   (`gamemodes/base/gamemode/cl_hudpickup.lua`: `GM:HUDWeaponPickedUp/
   HUDAmmoPickedUp/HUDItemPickedUp` acumulan en `GM.PickupHistory` y
   `GM:HUDPaint` corre `hook.Run("HUDDrawPickupHistory")` sin gate de
   `HUDShouldDraw` — `cl_init.lua:83`). El veto correcto es un hook
   `HUDDrawPickupHistory` que devuelve `false` (la misma supresión que usa el
   `resourcehistory.lua:920` de DGL4 — coexisten sin orden garantizado y con
   el mismo efecto). Alcance decidido por el autor (preguntado, opción
   recomendada): **todo el historial** — armas + munición + ítems HL2; el
   feed propio queda como única señal de pickup. Convar cliente
   `cargo_hide_pickup_history` (default 1, archive) + checkbox en el tab Q;
   el veto además vacía el backlog de `GM.PickupHistory` para que
   re-habilitar el historial no reproduzca pickups viejos. OJO con DGL4: sus
   paneles "WEAPON ACQUIRED" son su elemento `resourcehistory`, NO el
   historial de GMod — si molestan se apagan en el menú de DGL4
   (COMPAT-RUNTIME, no es territorio nuestro).
2. **7.º slot vs HUD DGL4 — veredicto por lectura del mod vivo: no hay
   conflicto por construcción.** DGL4 escucha las teclas vía
   `UnintrusiveBindPress` (DyaMetR, `modules/bind_press.lua`), que NO usa
   `hook.Add`: reemplaza `GAMEMODE.PlayerBindPress` — y el hook de Cargo
   (`corpus_cargo_hotkeys.lua`, `hook.Add("PlayerBindPress")`) corre ANTES
   que la función del gamemode y la corta al devolver `true`. Es decir: con
   `cargo_weapon_slots 1`, las teclas 1-7 mandan el intent de Cargo y el
   selector de DGL4 nunca ve el bind (diseño deliberado de la librería:
   "giving priority to any other addon"). Además DGL4 solo rastrea 6 slots
   (`HOLOHUD2.WeaponSelectionSlots = 6`, `weaponselection.lua:7`) y su
   handler ignora `slot7` aunque le llegue (`weaponselection.lua:669`); su
   selector sigue operable por rueda del mouse (`invnext`/`invprev`, que
   Cargo no intercepta). Con `cargo_weapon_slots 0` el hook de Cargo se corre
   a un lado y DGL4 recupera las teclas 1-6: exactamente su comportamiento
   stock. Cero código — queda solo la confirmación visual en juego.

**Sin net nuevo; sin migración** (el veto es client puro). Verificación
offline: `luaparser` limpio en lo tocado; harness extendido con el bloque del
veto (devuelve false con la convar puesta, vacía el backlog, se corre a un
lado en 0, degrada sin `GAMEMODE`, no toca el feed propio) — **235 checks
verdes en ambos realms**.

**Checklist en juego (artefacto de la tanda):** (a) recoger un arma/munición/
ítem HL2 → NO aparece el historial stock (esquina derecha) y el feed propio
sí señala; (b) `cargo_hide_pickup_history 0` → el historial stock vuelve;
(c) con DGL4 montado: teclas 1-7 mandan los intents de Cargo (7 = cámara),
sin selector DGL4 abierto ni errores; la rueda del mouse sigue abriendo el
selector DGL4; (d) `cargo_weapon_slots 0` → las teclas vuelven a DGL4/stock.

### Addendum — pasada del autor (2026-07-13): a/c/d ✓, el (b) estaba mal redactado

**(a) ✓ (c) ✓ (d) ✓.** El **(b) ✗** ("con la convar en 0 el stock no vuelve")
NO es bug de Cargo — es el propio DGL4: su `resourcehistory` también veta el
historial stock cuando su elemento está activo (`resourcehistory.lua:920`,
devuelve `false` en el mismo hook), así que con DGL4 montado el stock no
puede volver aunque nuestro veto se corra a un lado (el harness prueba que
en 0 nuestro hook devuelve nil). El check estaba mal redactado para un setup
con DGL4: la ronda 2 lo repite con el elemento resourcehistory de DGL4
apagado (o DGL4 desmontado). El entry queda `[PENDIENTE]` solo por ese
re-check. ADEMÁS, pedido nuevo del autor desde el (c) → roadmap #36: alinear
el slot del MENÚ HL2 del arma con el slot Cargo equipado (ej. la RPD de EFT
declara Slot 4 de engine — equipada como primary debería vivir en el bucket
3 de la rueda del mouse, coherente con la tecla 3).

### Addendum 2 — ronda 2 (2026-07-13): FLIP

**(b) ✓** — con DGL4 desmontado, `cargo_hide_pickup_history 0/1` revive y
mata el historial stock como corresponde. Con DGL4 montado su panel de
"weapon acquired" sigue apareciendo independiente de la convar —
**esperado y fuera de alcance**: es el elemento `resourcehistory` propio de
DGL4 (se desactiva en SU menú de configuración; COMPAT-RUNTIME, nuestra
convar gobierna solo el historial del gamemode base). Entry completo; el
roadmap #22 cierra entero.

## 18. `Inventory.HasItem`: presencia honesta de ítems `unique` (fix G4 de Coagulant) `[APLICADO 2026-07-13]`

**Contexto (reporte del autor — ronda 3 de Coagulant, 2026-07-13):** el
torniquete de Coagulant (clase `unique`) respondía "No tourniquet in
inventory" con el ítem visible en el grid. Causa raíz: `Inventory.CountItem`
cuenta **solo stacks** (`entry.uid == nil`) — correcto para su rol (su
resultado alimenta el drenaje de `TakeItem`, que también es de stacks), pero
no existía superficie pública para preguntar "¿lleva al menos un X?"
cubriendo las dos clases de ítem: los `unique` viven como `{id, uid}` y
CountItem siempre los cuenta 0.

**Cambio (server, `corpus_cargo_inventory.lua`):** nueva
`CARGO.Inventory.HasItem(ply, id) -> bool` — presencia por id sobre
`rec.items`, stacks Y uniques. Lectura pura: **cero cambios de semántica en
CountItem/TakeItem** (sus callers — el guard de TakeItem, QuickUse, el puente
ARC9 — son todos de stacks; hacer que CountItem viera uniques habría vuelto
mentiroso el `return true` de TakeItem sobre un id unique). El bloque
CONTRACT del init documenta la trampa y la superficie nueva. Coagulant es el
primer consumidor (su sesión "Fix G4").

**Verificación offline:** luaparser limpio; el harness de Coagulant cargó por
primera vez el inventario REAL de Cargo (items/weight/instances/inventory
sobre el framework real): GiveItem de un unique → CountItem 0 pero HasItem
true; TakeItem sobre el unique sigue devolviendo false; flujo completo del
torniquete verde (23 checks + selftest de Coagulant 68 OK).

**En juego (2026-07-13, ronda 4 de Coagulant): ✓** — el torniquete `unique` se
pone desde la UI de Cargo y el motor médico lo ve en el inventario (antes del
fix respondía "No tourniquet in inventory" con el ítem en el grid).

---

## 19. Tabs de display: set FIJO de 8, la fila deja de crecer sola (roadmap #23) `[APLICADO 2026-07-14]`

**Contexto (reporte del autor, 2026-07-12):** el set de **categorías** de ítem es
ABIERTO — `Items.RegisterCategory` auto-registra cualquier categoría que un def
mencione — y la fila de tabs se poblaba **desde ese set**. Con 14 categorías + "All"
la fila hacía **wrap**: "Backpacks" caía a una segunda línea. Cada módulo hermano que
registre lo suyo (Coagulant, Craving, Cortex) la habría hecho crecer más.

**Sesión de diseño con el autor (2026-07-13) — el set cerrado:** la fila pasa a ser
una **capa de AGRUPACIÓN de display** sobre las categorías, con un set **fijo de 8**:
`All · Weapons · Ammo · Gear · Mods · Meds · Food · Misc`. No es un renombre ni un
recorte: las **categorías internas quedan intactas** y siguen sirviendo al grammar
`"category:a,b"` de slots y sub-slots (contrato #3). Decisiones del autor: la fila se
dibuja **siempre entera** (tabs vacías atenuadas, posiciones estables) y toda categoría
**no mapeada cae al paraguas Misc** — la fila no vuelve a crecer nunca. Bajado a
`Cargo_Architecture.md` §7.1 (mapeo completo tab ← categorías).

**Cambio (shared, `corpus_cargo_items.lua`):** superficie nueva `Items.GetTabs()`
(set fijo, copias frescas), `Items.TabOf(category)` (categoría → tab, con fallback
a `misc`) y `Items.MatchesTab(def, tabId)` (lo que pregunta el grid por celda; `all`
acepta todo y una entrada **sin def** cae en Misc en vez de volverse invisible en
todas las tabs menos All).

**Cambio (client):** `corpus_cargo_grid.lua` filtra por **tab** en vez de comparar
`def.category` con el filtro; `corpus_cargo_ui.lua::BuildTabs` deja de poblarse desde
`GetCategories()` y dibuja el set fijo entero, atenuando las tabs sin ítems (el wrap
queda solo como red de seguridad para resoluciones diminutas, en vez de recortar la
última tab).

**Verificación offline:** harness `dev/harness_cargo.py` **279 checks verdes** en ambos
realms (eran 235: bloque #23 nuevo — las 14 categorías base caen cada una en un tab del
set fijo, una categoría ajena se auto-registra pero NO acuña tab y su ítem se ve bajo
Misc/All, y el id de tab `gear` **no** matchea `"category:gear"` en el filtro de
sub-slots). `cargo_selftest` **66 client / 59 server** (+10 checks de tabs).
**En juego:** pendiente de confirmación del autor (fila en una línea, tabs vacías
atenuadas, cada ítem en su tab, sub-slots sin romperse).

---

## 20. Comercio slice 1: trader NPC, precio con spread y basket atómico (`Cargo_Trade` §2-§5, §8, §10) `[APLICADO 2026-07-14]`

**Contexto:** primer slice del bloque de comercio (corte de 3 validado con el autor
2026-07-13: NPC → dinero-entidad → jugador-trader). El diseño ya estaba cerrado en
`Cargo_Trade_Arquitectura.md`; esto lo baja a código sin re-discutirlo.

**El primitivo NO es nuevo (decisión de implementación).** §2 del doc pide un
"inventario-en-entidad" genérico. Ya existía y está probado: `Containers.Attach`
(§8 de `Cargo_Architecture.md`) — items colgados de la entidad, capacidad,
persistencia por clave, derrame al removerse. **Un trader es ese contenedor más una
capa de precio**, no un inventario paralelo: construir un segundo habría dejado al
loot de cadáveres (Cortex, §9) eligiendo entre dos primitivos. El net de
transferencia del contenedor **no se cablea** a un trader — nada cruza salvo por
`Confirm`.

**Cambio (shared, `corpus_cargo_trade.lua` nuevo):** matemática pura de precio —
`Trade.UnitPrice(def, condition, mult)` = `value × condición × spread`, con
`ConditionMult` lineal desde `CONDITION_FLOOR` (0.25: una ruina todavía vale algo,
pero un ítem sin valor sería un servicio de basura gratis) y piso de 1 en el redondeo.
Spread default 0.5 / 1.0 (§5). `IsTradeable(def)` = tiene `value` > 0. Shared porque
el cliente pinta los mismos números que el server recomputa.

**Cambio (schema, `corpus_cargo_items.lua`):** campo nuevo **`def.value`** — precio
base. **Sin `value` un ítem no se comercia**: no muestra precio y el server rechaza
moverlo. La ausencia es el default honesto ("no está a la venta", no "gratis").

**Cambio (server, `corpus_cargo_trade.lua` nuevo):** `Trade.AttachTrader(ent, opts)`
(nombre, `buy_mult`/`sell_mult`, wallet finito o `nil` = sin fondo, stock semilla,
`persistKey`), sesión con su propio canal de net, y el **`Confirm` atómico**: resuelve
cada línea del basket contra la fuente viva, la re-precia, y valida **dinero + peso +
existencia** ANTES de mover nada. No hay ruta de rollback porque no hay mutación antes
de la validación. Errores con voz de interfaz ("Not enough money: you're $340 short",
"Too heavy: you're 4.2 kg over the limit", "The trader can't afford that"). Las compras
salen del stock **antes** de que entren las ventas (si no, un basket que vende 30
balas y compra 30 podría recomprar las suyas).

**Cambio (server, `corpus_cargo_weapon_prices.lua` nuevo):** tabla gemela de
`weapon_weights` — clase → `value` para las armas autogeneradas por la captura (ARC9
EFT + HL2). **Sin fallback a propósito:** una clase sin entrada queda sin precio, o
sea no comerciable; las tools del sandbox (physgun, toolgun, cámara) viven en ese
hueco deliberadamente.

**Cambio (client, `corpus_cargo_trade.lua` nuevo + `ui.lua` + `grid.lua`):** el
**estado Trade** del frame fullscreen, que estaba reservado desde §15.1, ya existe:
columna izquierda = stock del trader (con su spread escrito: "Buys at 50% · sells at
100%") + strip **Buy**; columna derecha = inventario propio con el precio que el
trader **pagaría** por cada ítem + strip **Sell**; deal bar con el **neto** ("You pay
$X" / "You get $X") y **Cancel/Confirm**. El basket es **intent puro**: no mueve nada,
marca las celdas con borde ámbar y su cuenta. Un confirm exitoso lo vacía; uno
rechazado lo deja **intacto** (§3) y solo poda lo que se volvió obsoleto.

**Cambio (entidad, `corpus_cargo_trader.lua` nuevo):** trader demo spawnable
(Entities → Corpus), con stock del kit dev y wallet de $50 000 (finito: se lo puede
drenar). Sin IA — el comercio no le debe nada al comportamiento; cuando Cortex traiga
un trader con cerebro, llama al mismo `AttachTrader`.

**Verificación offline:** harness **310 checks verdes** en ambos realms (eran 279:
bloque de comercio nuevo — trader = contenedor, precio con spread y condición, compra,
venta con desgaste que descuenta, ítem sin `value` rechazado, **rollback sin dinero**,
**rollback por peso** (el basket falla entero, nunca a la mitad), trader sin fondos que
rechaza en vez de imprimir dinero, basket mixto con neto correcto, líneas duplicadas
rechazadas y **el server ignorando el precio que manda el cliente**). `cargo_selftest`
**76 client / 69 server** (+10 checks de precio). **En juego:** confirmado por el autor
(2026-07-14, 8/8 ✓). Dos pedidos de la pasada, ambos de diseño y no bugs → **entry 21**:
el click debe llevarse el stack entero, y el peso no debe bloquear una transacción (el
`rollback por peso` verificado acá queda **derogado** por esa enmienda).

---

## 21. Enmiendas de la 1.ª pasada del comercio: click = stack entero, y el peso deja de ser gate `[APLICADO 2026-07-14]`

**Reporte del autor (2026-07-14, pasada del entry 20 — los 8 checks pasaron):** dos
pedidos de diseño sobre el comercio ya funcionando.

**(a) Click izquierdo = el stack ENTERO** (reporte 20c). El click agregaba **1 unidad**
al basket (lo correcto según el código, confirmado con el autor: la celda ámbar marcaba
todo el stack y por eso *parecía* que se llevaba todo). Pero cargar 120 balas de a una
es una tarea, no una decisión: **el click ahora se lleva el stack entero**, como hace
STALKER y como ya hacía el click del loot. La cantidad parcial sigue estando, en el
**click derecho** (`1` / `amount...` / `all`).

**(b) El peso deja de bloquear la transacción** (reporte 20g — enmienda a §3 de
`Cargo_Trade_Arquitectura.md`, que lo listaba como validación). Comprar es un acto
deliberado: negarle el trato al jugador porque saldría sobrecargado convierte al trader
en una niñera. **Ahora puede comprar por encima de su capacidad y salir sobrecargado** —
y la curva de peso (§5 de `Cargo_Architecture.md`) ya se lo cobra en velocidad. El
límite de carga **sigue vigente para lo que se recoge del suelo**: lo que uno paga es su
problema. Dinero, existencia y stock siguen siendo las validaciones atómicas.

**Cambio (client):** `onLeftClick` de ambos grids del estado Trade pasa
`Trade.Available(entry)` (stack completo; un `unique` sigue siendo 1).
**Cambio (server, `Trade.Confirm`):** cae la validación de peso; `GiveEntry` con
`skipCap` deja de ser una optimización y pasa a ser lo que sostiene la regla atómica (sin
él la línea se rechazaría y el trato se ejecutaría a medias).

**No se toca (reporte 19f):** a 800×600 la fila de tabs colapsa en dos filas en vez de
recortar — la red de seguridad del wrap haciendo su trabajo. Decisión del autor: se deja
así.

**Verificación offline:** harness **312 checks verdes** en ambos realms (el check de
"rollback por peso" se dio vuelta: ahora comprar sobrecargado **se permite**, el jugador
queda por encima de la capacidad y `GiveItem` —lo que se recoge del suelo— **sigue**
rechazando por peso). **En juego:** la pasada del autor (2026-07-14) devolvió el peso
✓ pero **corrigió el click**: ver entry 22, que lo reemplaza antes de que este llegara a
`[APLICADO]`.

---

## 22. Basket: la línea es un AGREGADO sobre todos los stacks + click 25% / SHIFT = todo `[APLICADO 2026-07-14]`

**Bug real (reporte del autor 2026-07-14, checks 21a/21b):** al clickear munición "se
pintaban todos los stacks en ámbar pero solo entraba uno", y con un stack ya en el
basket **no se podían agregar los otros stacks de la misma munición**. Causa raíz: el
ref de un stack es `id + condición`, pero **`max_stack` parte 240 balas en DOS entries de
120** — y ambas responden al mismo ref. La línea del basket resolvía contra la *primera*
que encontraba: el stack gemelo era inalcanzable, y el ámbar (que se pinta por ref) los
marcaba a todos.

**Arreglo:** una línea de stack es un **AGREGADO** sobre **todas** las entries que
matchean el ref — que es exactamente el ítem lógico que el jugador ve. El server la
resuelve contra todas (y drena cada una por su parte, respetando `max_stack` al
devolverlas al stock); el cliente calcula el disponible sumando todas. El ámbar sobre
todas las celdas ahora es correcto: **son una sola línea**, no varias.

**Cantidad por click (decisión del autor, 2.ª pasada — reemplaza la regla del entry 21):**
- **Click izquierdo** = **25% del `max_stack`** del ítem (30 balas de 120), repetible.
- **SHIFT + click** = **todo** lo que haya de ese ítem — la convención de las pantallas de
  trade que el autor juega.
- **Click derecho** = cantidad exacta (`1` / `amount…` / `all`), sin cambios.
- Un `unique` siempre es 1.

**No era un bug (check 21d):** recoger munición del suelo con 77,1 kg sobre 54 kg de
capacidad **debía** funcionar. El techo duro de carga es **2× la capacidad**
(`Weight.MAX_FRACTION = 2.0`, regla del Block 1: entre 1× y 2× te movés, dolorosamente;
recién pasado 2× no levantás nada). El checklist decía "sigue rechazando por peso" sin
decir a partir de dónde — el defecto era del texto, no del código.

**Verificación offline:** harness **318 checks verdes** (bloque nuevo: 240 balas viven
como dos stacks; venderlas cruza ambos y cobra por las 240, no por 120; entran al stock
del trader como dos stacks de 120 respetando `max_stack`; y una compra de 240 vacía los
dos stacks del stock). **En juego:** pendiente de confirmación del autor.

---

## 23. Las armas se presentan solas: trivia del SWEP + ARC9MW pesado y precificado `[APLICADO 2026-07-14]`

**Pedido del autor (2026-07-14):** poblar pesos/trivia de las armas ARC9 y que el tooltip
muestre la trivia en vez del "Arma autogenerada" que salía al tomar **cualquier** arma
fuera del kit dev.

**El hallazgo que cambió el plan:** la trivia **no necesitaba una tabla**. Los SWEPs de
ARC9 se describen a sí mismos y `weapons.Get(class)` nos entrega la tabla entera —
incluido lo heredado por la cadena `SWEP.Base`, porque `weapons.Get()` corre
`table.Inherit` (así los akimbos de MW2019 heredan gratis el texto de su pistola base).
Verificado contra el código vivo de ARC9 base + Darsu EFT + ARC9MW (`dev/other/`):

- **`SWEP.Description`** — ya es un **string plano** cuando lo leemos: los packs llaman
  `ARC9:GetPhrase` al cargar el archivo del SWEP, así que la localización ya ocurrió.
- **`SWEP.Trivia`** — `{ [claveEtiqueta] = claveValor }`: fabricante, calibre, acción,
  país, año.

**Cambio (server, `corpus_cargo_capture.lua`):** `RegisterAutogen` resuelve `def.trivia`
(override a mano → `SWEP.Description` → **nada**, nunca más el placeholder) y `def.trivia_rows`
(las specs del bloque `SWEP.Trivia`). Ninguno de los dos se persiste en `autogen_defs`: se
re-derivan del SWEP en cada boot, así que **montar un pack ARC9 nuevo hace que las armas ya
capturadas se describan solas en la siguiente carga de mapa**, sin catalogar una sola clase.

**Dos trampas de ARC9 que hubo que sortear** (ambas anotadas en el header del archivo):

1. **Las etiquetas de EFT no están localizadas.** `eft_trivia_manuf1` no existe en
   `eft_en.lua`, así que `GetPhrase` devuelve `nil` y queda la clave cruda.
2. **El des-numerado de ARC9 es código muerto.** `cl_customize_ui_trivia.lua:127` hace
   `title[#title]` — indexar un **string** con `[]`, que en Lua **siempre** da `nil`. El
   dígito de orden nunca se quita: el propio menú de ARC9 imprime literalmente
   "eft trivia manuf1". Nosotros lo hacemos bien (resolver → quitar el dígito → mapear el
   stem conocido) y además **usamos el dígito para ordenar** las filas, que es para lo que
   estaba puesto. `pairs()` no tiene orden estable: sin esto las filas se barajaban en cada
   carga de mapa.

**Tabla a mano (`corpus_cargo_weapon_trivia.lua`, nueva, server):** la **excepción**, no la
regla — 36 entradas. Existe por dos motivos distintos: (a) **huecos** (SWEPs que piden una
phrase que su pack nunca escribió: las granadas de MW2019, el minigun, 9 clases de EFT), y
(b) **herencias mentirosas** — sin override, el **M16A1** (`Base = arc9_eft_m4a1`) se
presentaría como un M4A1. Un override **siempre gana** sobre la `Description` del SWEP. Las
armas HL2 viven acá enteras: no son SWEPs, `weapons.Get` no tiene nada que leer para ellas.

**Cambio (client, `corpus_cargo_tooltip.lua`):** sección **"Specs"** bajo los stats con las
`trivia_rows`. A diferencia de los stats ARC9, **no exige el arma en la mano**: un fusil
guardado en la grilla igual te dice quién lo fabricó.

**Cambio (server, `weapon_weights` + `weapon_prices`):** las **87 clases de ARC9MW**. Los
pesos **no se inventaron**: el pack declara la masa real de cada arma en su propio bloque
`SWEP.Trivia` (`mw19_weight` → 4.79 kg para el AK-47) y **54 de 87** salieron transcritas de
ahí; las 33 restantes (lanzadores, granadas, melee, akimbos) van con cifras reales, tagueadas
`real approx`. Se **hornean** en vez de parsearse en runtime porque lo que ARC9 guarda es un
string de display ya formateado ("4.79 kg / 10.54 lbs") — raspar kg de prosa localizada en
cada boot es un contrato frágil con un mod que no controlamos. Los precios sí son nuestros:
MW2019 no tiene economía que copiar.

**Adyacente, mismo criterio que ya existía:** los puños de MW2019 (`arc9_cod2019_me_fist`)
entran a `Capture.Ignore` — son el estado desarmado, no equipo, igual que `weapon_fists`; y
el cuchillo/escudo de MW2019 entran a `AUTOGEN_MELEE`, porque un cuchillo que se equipa en
el slot Primary es un bug, no una build.

**Verificación offline:** harness **333 checks verdes** (15 nuevos: la trivia sale del SWEP y
no del placeholder; `BaseClass` no cuela una fila fantasma; la clave cruda `eft_trivia_manuf1`
se limpia a "Manufacturer" y su valor se resuelve; el dígito ordena las 5 filas de EFT; las
claves ya resueltas de MW2019 ordenan alfabéticamente y son estables entre boots; el override
gana sobre la herencia; un arma del engine sin SWEP cae a la tabla a mano; sin descripción en
ningún lado **no hay párrafo**; y el def autogen de una clase MW2019 nace con su peso (4.79) y
su precio reales). **En juego:** pendiente de confirmación del autor.

---

## 24. Cada arma sabe a qué slot va: un RPG deja de entrar en Sidearm (roadmap #39) `[APLICADO 2026-07-14]`

**Reporte del autor (pasada en juego de la entry 23, 2026-07-14):** *"un RPG no puede ir a
Side-arm obviamente"*.

**Causa raíz:** `primary`, `secondary` y `sidearm` **filtran los tres por `category:weapons`**
(`corpus_cargo_slots.lua`), así que **cualquier** arma capturada entraba en **cualquiera** de
los tres. El gancho para estrechar ya existía —`def.equip_slots`, que `Slots.CanEquip` honra
desde el Block 1— y el def autogen simplemente nunca lo seteaba.

**Arreglo — derivado, no catalogado** (la misma lección que ya pagó la trivia): cada SWEP de
ARC9 **declara su propio tipo**. `SWEP.Class` es por arma (`"Handgun"`, `"Hand Grenade"`,
`"Grenade launcher"`, `"Submachine Gun"`) y `SWEP.SubCategory` es por pack (`"LMGs"`,
`"7Pistols"`); `weapons.Get()` resuelve **ambos** por la cadena `SWEP.Base`, que es como
clasifican también los akimbos y las variantes EFT que no declaran ninguno. **Un pack que
nunca vimos —el del M60E4 del autor— se clasifica solo.** El mapeo:

- **pistola / revólver / machine pistol** → `{ sidearm }`
- **fusil / carabina / SMG / escopeta / LMG / sniper / marksman / lanzador** → `{ primary, secondary }`
- **melee** → categoría `melee` (su slot ya filtra por ahí; no necesita `equip_slots`)
- **granada de mano** → clasificada pero **sin restringir** (ver abajo)
- **sin clasificar** → **libre**, como hoy. Degrada; jamás produce un arma que nadie puede equipar.

**`SWEP.Slot` NO es la señal**, por tentador que parezca: medido contra los packs vivos
(2026-07-14) es inconsistente —los LMG están en 2 **y** en 3, las escopetas comparten el 3 con
los snipers, y un tercio de las EFT no declaran Slot—. Es la misma falta de fiabilidad de la
que habla el roadmap #36.

**Trampa que cazó el harness antes de llegar al juego:** la primera versión concatenaba
`Class .. SubCategory` en un solo string a matchear. EFT archiva sus **granadas de mano** bajo
la SubCategory `"Grenades & Grenade launchers"` — que contiene **"launcher"** —, así que una
F-1 se clasificaba como **arma larga**. `SWEP.Class` es la verdad **por arma** y se evalúa
**sola**; `SubCategory` es solo el estante del pack, y es *fallback*, no par. (El orden de las
reglas también es carga: `"Grenade launcher"` contiene `"grenade"`, y el cuchillo **arrojadizo**
de MW2019 es `Class = "Lethal"`, no melee.)

**Granadas ARC9: clasificadas, todavía no accionadas** (decisión del autor, 2026-07-14:
*"dejarlas como están por ahora"*). Una granada de ARC9 sigue siendo un ítem `unique`, y el
slot **Throwable** toma un **stack** de un `stackable` (§4, enmienda del wheel). Restringirla a
un slot en el que no puede entrar la volvería **inequipable**, así que conserva el
comportamiento de hoy —equipable en Primary/Secondary— hasta que la taxonomía de throwables del
roadmap #32 crezca para cubrirlas. El clasificador ya las etiqueta `thrown`: el día que se
accione, es una línea en `KIND_SLOTS`, no un rediseño.

**Remanente reconciliado:** el estrechamiento se aplica al **registrar** el def, o sea gobierna
los equipamientos nuevos. Un RPG que el jugador ya tenía **parkeado en Sidearm** seguiría ahí,
ilegal e invisible a la regla. `ReconcileEquipSlots` (en `PlayerInitialSpawn`, junto al heal de
defs huérfanos) lo saca a la mochila una vez, con aviso. Es también la ruta de reparación
general para el día que un `equip_slots` vuelva a cambiar.

**Verificación offline:** harness **346 checks verdes** (13 nuevos: `CanEquip` rechaza el RPG
en Sidearm y lo sigue aceptando en Primary; la pistola ARC9 y su akimbo —que hereda el
`"Handgun"` del padre— van a Sidearm; fusil/LMG/SMG/sniper son largas; el **lanza**granadas es
larga porque la regla `launcher` corre antes que `grenade`; el cuchillo ARC9 cae en `melee` y
**no** entra en Primary; el cuchillo arrojadizo de MW2019 **no** cae en melee; la granada de
mano queda sin restringir; un arma que ARC9 no clasifica queda libre; la physgun sigue entrando
en su círculo de tool; y un RPG ya equipado en Sidearm se reconcilia al spawn). **En juego:**
pendiente de confirmación del autor.

**Deuda abierta que este entry NO cierra:** los **pesos que caen al nominal de 2,5 kg** en los
packs ARC9 que no están en `dev/other/` (reporte del autor: el **M60E4**). El diagnóstico ya
tiene herramienta: `cargo_dev_dump_weapons` vuelca clase/nombre/tipo/munición/cargador/peso a
`data/corpus/cargo/weapon_dump.txt` y marca cada hueco como `MISSING (2.5 nominal)`. Falta el
volcado del arsenal real del autor para poblar `weapon_weights`/`weapon_prices`.

---

## 25. El arsenal real del autor: 184 pesos y precios que faltaban (roadmap #40) `[APLICADO 2026-07-14]`

**Reporte del autor (2026-07-14):** *"hay algunas armas que tienen el fall-back a 2.5 kg, una
de ellas es el M60E4, indudablemente debería pesar muchísimo más"*.

**No era un bug: era un hueco de datos**, y el fallback hizo exactamente lo que se diseñó. El
M60E4 vive en un pack ARC9 que **no está en `dev/other/`**, así que nunca pudo entrar en
`weapon_weights`. El diagnóstico ya tenía herramienta desde el entry 15: `cargo_dev_dump_weapons`.

**El volcado del autor (`dev/weapon_dump.txt`): 369 SWEPs montados, 184 sin peso.** Los packs
que faltaban:

| Familia | Huecos | Qué es |
|---|---|---|
| `arc9_eft` | 107 | Packs EFT que no tengo: SMGs, escopetas, LMG, **melee** (24), gear, `makeshift`, carabinas |
| `arc9_go` | 71 | Pack de **CS:GO** entero — nunca lo había visto |
| `arc9_cod2019` | 3 | bases + puños |
| `arc9_wtt` | 1 | Scorpion EVO 3 |

**Lo importante: el volcado alcanza para catalogar sin tener el pack.** Trae clase, nombre,
tipo, munición y cargador de cada arma — suficiente para pesarla y precificarla con cifras
reales, igual que se hizo con las EFT contra la DB de GAMMA. **Resultado: 360 armas vivas del
volcado, las 360 con peso y precio, cero huecos.** El M60E4 pesa **10,5 kg**.

**Precios también, no solo pesos** (el autor pidió pesos; el hueco de `value` era el mismo y es
peor): **sin `def.value` un arma no se comercia** (`Cargo_Trade` §4 — ausencia significa "no
está a la venta"). Los 184 huecos de peso eran 184 armas fuera de la economía.

**Las clases BASE no se catalogan, a propósito.** El volcado lista todos los SWEPs registrados,
incluidas las plantillas (`arc9_base`, `arc9_eft_base`, `arc9_go_base`, `*_base_nade`,
`*_melee_base`). No son armas que el jugador pueda recibir; catalogarlas sería ruido con forma
de dato.

**Los duales pesan dos veces su arma base** — el Dual Desert Eagle son 3,80 kg porque son dos
Desert Eagle de 1,90 y las cargás las dos. Anclado con un check.

**Verificación offline:** harness **351 checks verdes** (5 nuevos, todos anclados al volcado
real: el M60E4 pesa 10,5 y es comerciable; PKM/AWP/Negev pesan como pesadas; las pistolas y los
cuchillos de los packs nuevos pesan como tales; un dual pesa exactamente 2× su base; y las
clases BASE **no** están en la tabla). Verificado además contra el volcado: **0 armas vivas sin
peso, 0 sin precio, 0 claves duplicadas**. **En juego:** pendiente de confirmación del autor.

### Frentes que este entry NO cierra (reportados en la misma pasada)

- **Los explosivos de EFT y CS:GO se equipan en Primary, no en Throwable.** El clasificador del
  #39 ya los etiqueta `thrown`, pero siguen siendo ítems `unique` y el slot Throwable pide un
  **stack**. El autor lo confirmó como bloque aparte: *"todo eso amerita hacer un bloque
  especial para mejorarlo, pero eso después"*. → **roadmap #41**.
- **Un lanzagranadas capturado no dispara: perdió su attachment de munición.** Nota del autor en
  el check 4 de la entry 24, dejada explícitamente como anotación, no como bloqueo. Huele al
  puente ARC9 (§10: Cargo es el almacén de attachments y `arc9_free_atts` queda en 0) — el
  arma nace sin su att de munición y no hay de dónde sacarlo. → **roadmap #42**.

### Addendum — pasada del autor (2026-07-14): el dump gritaba lobo

**Reporte:** *"parece estar todo bien en general, aunque he visto uno que otro missing del
dump"*. El volcado nuevo trae **9 `MISSING`**… y los 9 son los que se excluyeron **a
propósito**: 8 **plantillas de SWEP** (`arc9_base`, `arc9_eft_base`, `arc9_go_base`,
`arc9_eft_grenade_base`, `arc9_eft_melee_base`, los `*_base_nade`) y los **puños de MW2019**,
que viven en `Capture.Ignore`. Ninguna es un arma que el juego pueda darle al jugador: no son
huecos, y las tablas están completas.

**Pero el defecto es real y es del instrumento.** `cargo_dev_dump_weapons` es la herramienta
con la que se *diagnostica*; una falsa alarma ahí cuesta una búsqueda de verdad, y el autor la
pagó. Un SWEP que la captura no puede entregar **no es un hueco en la tabla** y no debe
marcarse como tal.

**Arreglo (`corpus_cargo_dev.lua`):** dos exclusiones, ambas honestas —
`Spawnable ~= true` (es una plantilla: nada la spawnea) y `Capture.Ignore` (jamás es un ítem)—.
Siguen **apareciendo** en el volcado (esconderlas sería otra mentira), pero como `n/a (base)` /
`n/a (ignored)`, y **no cuentan** en el conteo de huecos.

**De paso, el hueco gemelo se vuelve visible:** el volcado ahora trae también la **columna de
precio**. Sin `def.value` un arma **no se comercia** (`Cargo_Trade` §4), o sea un arma sin
precio está tan rota como una sin peso — y hasta hoy el dump no lo mostraba. Encabeza con un
resumen: `# N SWEPs, N capturables | sin peso: N | sin precio: N`.

**Verificación offline:** harness **355 checks verdes** (4 nuevos: una plantilla sale `n/a` y no
`MISSING`; una clase de `Capture.Ignore` también; el resumen cuenta **capturables** y huecos
reales, no plantillas; y una clase sin `value` sale marcada como no comerciable). **En juego:**
el propio comando es la verificación — un `cargo_dev_dump_weapons` nuevo debe encabezar con
`sin peso: 0 | sin precio: 0`.

---

## 26. Hands: son puños, no un finisher de Apex — daño, quiebre de animación y mano por botón `[APLICADO 2026-07-14]`

Tres reportes del autor sobre el SWEP **Hands** (2026-07-14), y el hilo que los conecta: el port
heredó del mod original (Workshop 2792160770) **dos lecturas de animación equivocadas**, y una de
ellas mantenía media lógica del arma muerta sin que se notara.

**(a) El daño.** Reporte: *"si al final son puñetazos, menos de 5 dmg debería hacer"*. Hoy un
puñetazo hace `math.random(37, 47)` — casi el 50% de un jugador. La escalera del original
(37-47 base, hasta 115 en el uppercut agachado) es la de una leyenda de Apex partiendo un
escudo. Se **escala ~1/10** manteniendo el peso relativo de los finishers de combo, en una tabla
`DAMAGE` indexada por animación (antes eran literales dispersos en el `if`):

| Animación | Antes | Ahora |
|---|---|---|
| `fists_left` / `fists_right` | 37-47 | **3-4** |
| `fists_uppercut` (combo, LMB) | 55-65 | **5-7** |
| `fists_elbowstrike` (combo, RMB) | 55-65 | **5-7** |
| `fists_uppercut2(_alt)` (agachado) | 65-115 | **7-12** |

Las **fuerzas de knockback no se escalan**: son la tuning de los autores originales
(*"yes we need those specific numbers"*) y solo muerden sobre un objetivo que muere.

**(b) El quiebre de animación al pasar de golpe a idle — y la lógica muerta.** Dos bugs
distintos, ambos por preguntarle al objeto equivocado:

1. **`SetAnim`/`Deploy` medían mal la duración.** Pedían `vm:SequenceDuration()` **sin
   argumento** —"cuánto dura la secuencia que estés reproduciendo ahora mismo"— justo después de
   pedirle al viewmodel que cambiara de secuencia. Si esa lectura cae sobre la secuencia
   **vieja**, el tiempo que `AnimationTime` registra no es el del golpe: `Think` devuelve a
   `idle1` **a destiempo** — o cortando el swing por la mitad, o segundos tarde. Es exactamente
   el quiebre reportado. Ahora ambos piden la duración de **la secuencia que están arrancando**
   (`vm:SequenceDuration(seq)`), con guardas para `seq < 0` (secuencia inexistente: no se pisa el
   estado) y `playbackRate <= 0` (división que producía `inf`/`nan`). `Deploy` de paso deja de
   medir el deploy **antes** de arrancarlo — solo funcionaba porque un `SetWeaponModel` recién
   puesto deja sonando la secuencia 0, que en este modelo **casualmente** es `Deploy`.
2. **`DealDamage` leía el nombre de la animación contra el modelo del ARMA.**
   `self:GetSequenceName(vm:GetSequence())`: un índice de secuencia **del viewmodel** resuelto
   contra la entidad del arma, cuyo `WorldModel` es `""`. Nunca resolvía → **todas las ramas por
   animación eran código muerto**: cada golpe hacía el daño base y **jamás se aplicó una sola
   fuerza direccional**. Ahora lee `GetCurrentAnim()`, el nombre que `SetAnim` ya networkea. Con
   esto el uppercut, el codazo y el uppercut agachado **existen por primera vez** (daño propio +
   knockback), que es lo que el mod siempre quiso decir.

**(c) Mano por botón.** Reporte: *"¿podría golpear alternadamente, que golpear con izquierda sea
realmente la animación de mano izquierda?"*. El modelo `c_arms_apex.mdl` **sí trae las dos
secuencias** (`fists_left` y `fists_right` — verificado sobre el .mdl, no de memoria), y el
código **ya** mapeaba LMB→izquierda y RMB→derecha. Decisión del autor: **botón = mano, fijo**
(sin alternancia automática estilo Fists de GMod). Único cambio: se borra el parámetro
`PrimaryAttack(right)` — el engine **nunca** pasa argumento a `PrimaryAttack`, así que era `nil`
siempre y la rama `if right` era decorado. Si en juego seguía viéndose una sola mano, el
sospechoso es (b1), no la selección de animación.

**De paso (churn de `Think`):** `SetCombo(0)` y `SetHoldType("normal")` se reescribían **cada
tick** una vez pasado el cooldown — un int networkeado y un hold type moviéndose para nada. Ahora
solo se escriben cuando cambian.

**Verificación offline:** sintaxis OK (luaparser). **En juego** (la corre el autor):

1. Equipar Hands. Golpear a un NPC con vida: debe morir en **muchos** golpes, no en dos
   (`developer 1` muestra el daño).
2. LMB → animación de **mano izquierda**; RMB → **mano derecha**.
3. Golpear repetido y soltar: la vuelta a `idle` **no debe dar el tirón** ni cortar el swing.
4. Encadenar 3 golpes seguidos (combo ≥ 2): el 3.º debe ser **uppercut** (LMB) / **codazo**
   (RMB), con su propio daño y su empujón — antes esto no pasaba nunca. Agachado: uppercut.
5. Ojo con el knockback ahora que **vive**: si un NPC moribundo sale volando de más para el tono
   del mod, el número a bajar son los `SetDamageForce` (no el daño).

### Addendum — pasada del autor (2026-07-14): OK, y la 3.ª persona NO es un bug

**Reporte:** *"parece solucionar el salto abrupto entre animaciones de idle y golpear, good. El
daño está bien"* → checks 1-3 verdes, entry **FLIP**. Los finishers de combo y el knockback
recién resucitado quedan a la vista en la próxima pasada (no se buscaron a propósito).

**Pregunta abierta del autor:** *"la animación en tercera persona de golpear yo supongo que
debería funcionar: si golpeo con la izquierda, la animación golpea con la izquierda. ¿O la
animación de golpear de GMod tiene problemas con la alternancia?"*.

**Veredicto: es un techo de GMod, no un defecto del port — y no se toca.** La 3.ª persona no la
elige el SWEP. `SetAnimation(PLAYER_ATTACK1)` termina en `ACT_MP_ATTACK_STAND_PRIMARYFIRE`, que
el `weapon_base` traduce por hold type en
`gamemodes/base/entities/weapons/weapon_base/sh_anim.lua`:

```lua
[ "fist" ] = ACT_HL2MP_IDLE_FIST,
...
self.ActivityTranslate[ ACT_MP_ATTACK_STAND_PRIMARYFIRE ]  = index + 5
self.ActivityTranslate[ ACT_MP_ATTACK_CROUCH_PRIMARYFIRE ] = index + 5
```

**Una sola** actividad de ataque por hold type (`ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST`) — no
distingue ni de pie de agachado, menos aún mano izquierda de derecha. El set de animaciones de
jugador de HL2MP, compartido por **todos** los playermodels, no tiene gesto de puñetazo
izquierdo: no existe la animación que habría que reproducir.

**Lo cierra el propio Valve:** el `weapon_fists` de GMod hace exactamente lo mismo —
`SecondaryAttack()` llama a `PrimaryAttack(true)` (LMB izquierda, RMB derecha, el mismo mapeo que
eligió el autor) y en 3.ª persona reproduce el mismo gesto único para ambas. **La alternancia
nunca existió fuera del viewmodel**, ni en Fists ni en el mod de Apex. (El mod original traía un
`models/player/apex_player_animations.mdl`, pero **ningún Lua suyo lo referencia**: asset muerto,
no era la salida.)

Tenerlo de verdad exigiría animaciones de jugador nuevas (gesto de puño izquierdo + su actividad),
o sea pisar el set de anims compartido por todos los playermodels — invasivo y territorio de
choque con otros addons. **Se acepta el comportamiento de GMod.**

### Addendum 2 — el NPC salió volando `[APLICADO 2026-07-23]`

**Reporte:** *"si un NPC salió volando. Literalmente…"*. Lo advertía el check 5, y era la
consecuencia directa de resucitar las ramas por animación: las fuerzas se dejaron **verbatim**
—son la tuning de los autores originales— pero esa tuning es para golpes de **37-115** de daño,
no de 3. Sobre un ragdoll de ~85 kg: un jab (`GetForward() * 12998`) lo empuja a **~150 u/s**, y
el uppercut agachado (`GetUp() * 25158`) lo lanza **hacia arriba a ~300 u/s**. Eso no es un
empujón: es un despegue.

**Arreglo:** una sola perilla, `FORCE_SCALE = 0.2`, aplicada a **todas** las fuerzas de
personaje (`kb = phys_pushscale * FORCE_SCALE`). Escalar el conjunto en vez de reescribir seis
vectores conserva la **forma relativa** de la tuning original —el uppercut sigue siendo el que
más levanta, el jab el que menos— y deja un único número que mover si hace falta re-calibrar. El
jab pasa a ~30 u/s (un tropezón) y el uppercut agachado a ~60 u/s hacia arriba (un salto, no un
lanzamiento).

El empujón de **props** (`phys:ApplyForceOffset`, más abajo) **no** se toca: usa el `scale` crudo,
siempre estuvo activo y nadie se quejó de un bidón que se mueve al recibir un puñetazo.

**Verificación en juego:** golpear a un NPC hasta matarlo — el cadáver debe **trastabillar**, no
salir despedido. Encadenar 3 golpes (combo) y probar el uppercut agachado: sigue siendo el más
espectacular de los tres, pero dentro del planeta.

**Resultado (pasada 2026-07-23):** X2 ✓ — el cadáver trastabilla, no despega, y los finishers de
combo (uppercut/codazo) quedan a la vista. `FORCE_SCALE = 0.2` confirmado en juego.

---

## 27. Comercio 2.ª pasada: Sidorovich en persona, strips parejos y el fin del dedup de armas `[PENDIENTE]`

**Reporte del autor (2026-07-14, ronda de las entries 21/22 — 4/5 ✓):** el basket agregado
y el click 25% / SHIFT quedaron confirmados (entries 21 y 22 → `[APLICADO]`). Lo que dejó
la pasada:

**(a) Los dos strips del basket ahora miden lo mismo.** El panel **BUY** del trader
(96 px) era más bajo que el bloque **SELL** del jugador (134 px, que además carga el neto
y Cancel/Confirm), y la fila se veía desalineada de lado a lado. Ambos leen ahora de un
único `Trade.STRIP_TALL` — un número compartido, no dos afinados a mano que se separan.

**(b) El trader demo es Sidorovich.** `models/rashkinsk/sidor.mdl` (pack `stalker rp
content #2`, material `act_stalker_trader_1`) es un rig **ValveBiped con los includes de
animación del ciudadano HL2** (`male_shared`/`gestures`/`postures`, leídos del propio
`.mdl`), así que la idle del NPC le corre tal cual. Copiado a **`corpus-stalker`** con
**rutas verbatim** (assets gitignoreados, manifiesto en su `docs/ASSETS.md`). Cargo NO
hard-depende de él: **detección, nunca asunción** — sin el addon montado, el trader cae al
ciudadano de HL2.

**(c) El dedup de armas se levanta para las tomas DELIBERADAS** (reporte 22e: "no puedo
tomar dos M60E4… comprar sí, lo que es raro"). Cada arma capturada es su **propia
instancia** (uid, condición y cargador propios), y el comercio ya las vendía como tales;
la regla "un ítem por clase" contradecía eso. **Pero no se puede levantar entera:** lo que
el dedup protege de verdad es el **give ANÓNIMO del engine** — el loadout del gamemode
re-entrega sus clases en cada respawn, y capturarlas a ciegas mintería una pistola nueva
cada vez que morís. Así que la regla queda **acotada a eso**: give anónimo de una clase ya
poseída → se descarta; give **deliberado** (WALK+USE, click del spawnmenu, instancia
dropeada que vuelve) → **captura**. Podés cargar N armas iguales. Cierra la parte de
"segunda arma de mundo de una clase ya poseída" del roadmap #15.

**Verificación offline:** harness **355 checks verdes** (el check del dedup se dio vuelta:
un give deliberado de una clase ya poseída ahora captura la segunda, y el anónimo sigue
descartándose — que es lo que impide el stockeo por respawn). **En juego:** pendiente.

---

## PARCHES DE sesión Pasada de veracidad de docs — 2026-07-14

Auditoría de veracidad del ecosistema: cada afirmación de los docs contrastada contra el
código real. Cargo era el repo con más deriva, y de una sola clase: **los docs de diseño
siguieron describiendo lo diseñado mientras la implementación divergía en juego** y nadie
volvió a la fuente. El caso grave es el **lock del basket** —el doc lo daba por hecho y en
código no existe—; el resto son números y rutas que la bajada cambió (íconos ARC9, `CELL_PX`,
el gate de transparencia) y la falsedad heredada de «Cargo es hoja». Sin superficie de
runtime: los siete parches son doc, salvo un comentario de `icons.lua` que quedó mintiendo
junto a su doc.

- PARCHE 1 — docs(docs): declara que **el lock del basket NO existe** (`Cargo_Trade` §3 pasos 2 y 4, §6 y deuda del slice 1). El basket es *intent puro del cliente* —el server no guarda estado de basket— y el ítem pendiente sigue siendo usable y equipable (botarlo no es directo: en estado Trade el click derecho del grid propio abre `Trade.AmountMenu`, no `OpenItemMenu`); lo que sostiene la transacción es la **re-resolución** (`PruneBasket` en cliente + re-resolver/recortar/abortar en `Confirm`), no un candado. Aceptable contra un NPC, **obligatorio en el slice 3** (jugador-trader). **[APLICADO 2026-07-14]**
- PARCHE 2 — docs(docs): corrige la fila del slice 1 en `Cargo_Trade` §12.bis, que se contradecía con su propio §3: el click carga **25% del `max_stack`** (entry 22), no el stack entero (regla del entry 21, ya derogada). De la #21 sobrevive solo la mitad vigente: el peso deja de ser gate. **[APLICADO 2026-07-14]**
- PARCHE 3 — docs(docs): documenta la **ruta ARC9 de íconos** en `Cargo_ItemImages` (§2, §3, §4, §7). Para las armas `MirrorVMWM` no hay render de modelo: la fuente es el **select-icon que captura ARC9**, re-encuadrado en 2D por bbox de silueta (re-fotografiar la ensambladura corría carrera con el posicionamiento de partes, que se asienta por frames — recetas r3-r5 abandonadas). Se anota la divergencia `Icons.ModelFor` ≠ `Items.ResolveModel`, que el encuadre no aplica en esa ruta, y que la clave de caché pliega `RECIPE_VERSION` + el mtime de la fuente. **[APLICADO 2026-07-14]**
- PARCHE 4 — docs(docs): actualiza resolución y formato (`Cargo_ItemImages` §6): **256 px por celda** (`CELL_PX`, nació en 64) y **RT de 2048×2048** (`RT_SIZE`), con la salvedad de que la ruta ARC9 escribe a las mismas dimensiones pero su detalle real lo capa la fuente de 256² — subir `CELL_PX` ahí no compra calidad. **[APLICADO 2026-07-14]**
- PARCHE 5 — docs(docs): cierra el **gate de transparencia** (`Cargo_ItemImages` §9, §11, §12): lo ganó el **Plan A** (alpha real, verificado en juego el 2026-07-11); el Plan B queda cableado como fallback por la convar `cargo_icon_bake_bg` (0 = A, default). Incluye el comentario de `corpus_cargo_icons.lua`, que seguía diciendo que el autor decidía después del gate. **[APLICADO 2026-07-14]**
- PARCHE 6 — docs(docs): precisa `Cargo_Architecture` §16.2 — los **11 tipos** de munición del engine no se registran todos como `cargo_ammo_<tipo>`: son **9 de cinturón** (categoría `ammo`) y **2 con cara lanzable** (`cargo_throw_frag`/`cargo_throw_slam`, categoría `throwables`), con los ids viejos muertos y remapeados por `Ammo.LegacyThrowIds`. **[APLICADO 2026-07-14]**
- PARCHE 7 — docs(docs): **Cargo no es hoja** (`CLAUDE.md`, sección «Qué es»). Consume Coagulant (`OnEncumbrance`, en producción) y Cortex (`GetFactionInfo`, mock-first), ambos con lazy-check + `pcall` — la propia línea se contradecía con el contrato #9 del mismo archivo. **[APLICADO 2026-07-14]**

### Ronda 3 — la capa profunda: roadmap, estado y CLAUDE.md

La segunda ronda dejó los docs de arquitectura limpios, pero la mentira había calado más
abajo: los **docs vivos** (los que se leen PRIMERO al retomar el módulo) seguían describiendo
un repo sin commits, un sistema de íconos por construir y un slice 1 sin verificar. El caso
grave es el mismo del PARCHE 2 —el peso como gate— reapareciendo en `cargo_estado.md`, que se
**autocontradecía dos líneas más abajo**. Sin superficie de runtime: los cuatro parches son doc.

- PARCHE 8 — docs(docs): el `Confirm` del comercio **no valida peso** (`cargo_estado.md`, slice 1). Valida **existencia + dinero del jugador + wallet del trader** (`corpus_cargo_trade.lua`: «WEIGHT IS NOT A GATE HERE»; la compra va con `skipCap`). El párrafo se contradecía con su propia línea siguiente, que ya declaraba el peso derogado (entry 21). Misma mentira que el PARCHE 2 ya había corregido en `CLAUDE.md` y `Cargo_Trade` §3. **[APLICADO 2026-07-14]**
- PARCHE 9 — docs(docs): el repo **tiene 88 commits y está al día con `origin/main`** (`CLAUDE.md`, sección Git). Decía «remote `origin` cableado localmente, sin commits todavía» — falso desde el primer commit (2026-07-11). **[APLICADO 2026-07-14]**
- PARCHE 10 — docs(docs): el **sistema de imágenes de ítems está HECHO** (`cargo_roadmap.txt` #5), no es «el próximo paso de implementación»: `corpus_cargo_icons.lua` + `corpus_cargo_iconeditor.lua`, CHANGELOG #5 `[APLICADO 2026-07-11]`. El **gate de transparencia ya lo ganó el Plan A** (verificado en juego el 2026-07-11), así que deja de figurar como alcance pendiente — el Plan B queda como fallback por `cargo_icon_bake_bg`. Arrastra el «PREREQUISITO DURO: #5» de la entrada #3, que afirmaba en presente un bloqueo ya levantado. **[APLICADO 2026-07-14]**
- PARCHE 11 — docs(docs): el slice 1 del comercio **ya pasó por la pasada en juego** (`cargo_roadmap.txt` #3): la #20 está `[APLICADO]` y la pasada produjo las entries **#21 y #22**, ambas confirmadas. Decía «CHANGELOG #20, PENDIENTE de la pasada en juego». Lo que sigue `[PENDIENTE]` es la **#27** (2.ª pasada), y así queda anotado. **[APLICADO 2026-07-14]**

### Ronda 4 — el README, que nadie había auditado nunca

Las tres rondas anteriores limpiaron `docs/` y el `CLAUDE.md`. El **`README.md`** —el único doc
que ve quien entra al repo desde GitHub— nunca había entrado en el alcance, y seguía congelado en
la era semilla: anunciaba el comercio como «en diseño / sin implementar» con el slice 1 shippeado
y confirmado en juego (#20/#21/#22), y el estado Trade de la UI como «reservado» con sus dos
paneles construidos. Detrás quedaba una cola de marcadores rancios en el roadmap, una cardinalidad
vieja del workspace y una lista de alcances de commit que el propio `git log` desmentía. Sin
superficie de runtime: los siete parches son doc, salvo el comentario de `corpus_cargo_ui.lua`
que originó la mentira del «Trade reservado» y seguía repitiéndola junto a su doc.

- PARCHE 12 — docs(docs): el **comercio no está «en diseño»** (`README.md`): su **slice 1 está en producción** (`Cargo_Trade` §2-§5/§8/§10 — código en los tres realms + `corpus_cargo_trader.lua`; CHANGELOG #20 `[APLICADO]` + enmiendas #21/#22). Se separa del **Workbench**, que sí es futuro y no tiene una sola línea de Lua. El README suma la bala del comercio (trader = contenedor + capa de precio, `value × condición × spread`, basket de intent puro, `Confirm` atómico) y el pendiente pasa a ser lo que de verdad falta: los **slices 2 y 3**. Alcanza al índice de documentación, que listaba `Cargo_Trade_Arquitectura.md` como «subsistema futuro» junto al Workbench. **[APLICADO 2026-07-14]**
- PARCHE 13 — docs(docs): el **estado Trade de la UI está construido**, no «reservado» (`README.md`, `CLAUDE.md` — mapa de archivos): `corpus_cargo_ui.lua` arma la columna izquierda del trader (`Trade.BuildStockColumn`) y la deal bar (`Trade.BuildDealBar`); los paneles los pone `client/corpus_cargo_trade.lua`. Incluye el **comentario de `corpus_cargo_ui.lua`** que originó la mentira y seguía diciendo «trade (reserved for the Cargo_Trade block)» — solo el comentario, ni una línea ejecutable. **[APLICADO 2026-07-14]**
- PARCHE 14 — docs(docs): **racimo de marcadores rancios** en `cargo_roadmap.txt`. La regla del CHANGELOG (L3-4) es que una entry pasa a `[APLICADO]` **solo tras verificarse en juego**, así que «CHANGELOG #N + `[PENDIENTE]` verif.» es falso en cuanto la #N está `[APLICADO]`. Corregidos los frentes **#15, #16, #17, #19, #22-tabs (#23), #38, #39 y #40** contra sus entries: **#7, #10, #11, #19, #23, #24 y #25**, todas `[APLICADO]`. Lo único que sigue legítimamente sin verificar —la **#27** y los addenda que `cargo_estado.md` lista (dump de la #25, fuerzas de la #26)— queda anotado como tal, no borrado. **[APLICADO 2026-07-14]**
- PARCHE 15 — docs(docs): el workspace tiene **ocho carpetas = siete repos git + `dev/`** (`CLAUDE.md`), no «seis raíces». Verificado contra `corpus.code-workspace`. Faltaba **`corpus-stalker/`**, que no es un módulo sino el **addon de contenido** de la Zona — y del que Cargo ya consume assets por detección (el modelo de Sidorovich del trader demo, entry 27; sin el addon montado cae al ciudadano de HL2). La cuenta de **módulos** hermanos (cuatro) era correcta y se conserva. **[APLICADO 2026-07-14]**
- PARCHE 16 — docs(docs): la **API de ARC9 ya se verificó y el puente shippeó** (`Cargo_Architecture` §14, tabla «Estado de este documento»). Decía «cerrado en diseño — API exacta de ARC9 pendiente de verificación contra código»: se verificó contra el código vivo (base + pack EFT de Darsu) el **2026-07-10**, quedó anotada en el header de `corpus_cargo_arc9.lua` y el **contrato #8** del `CLAUDE.md` la declara pagada. **[APLICADO 2026-07-14]**
- PARCHE 17 — docs(docs): los **alcances de commit** del `CLAUDE.md` contradecían al doc canónico que la propia línea enlaza (`cargo_convenciones_commits.txt` §3): faltaban **`ammo`** e **`icons`** —los dos en uso en el historial (7 commits `icons`, 2 `ammo`)— más `capture`, `trade` y el reservado `workbench`; y **`chore` es un TIPO (§2), no un alcance**. La línea ahora lista los seis tipos y los catorce alcances, y declara que el doc manda. **[APLICADO 2026-07-14]**
- PARCHE 18 — docs(docs): `cargo_convenciones_commits.txt` §3 se presenta como el **set cerrado** de alcances del repo y el propio `git log` lo desmentía: faltaban **`trade`** (4 commits, subsistema shippeado con doc de arquitectura propio) y **`capture`** (2 commits, y es el dueño de la captura de armas del engine + sus tres tablas de datos). Ambos definidos con sus archivos. **[APLICADO 2026-07-14]**

### Ronda 5 — las dos regresiones que la propia pasada introdujo, y la cola

Última ronda. Dos de estos parches no arreglan deriva vieja sino **daño que esta misma pasada
hizo**: el PARCHE 13 reescribió el comentario de `corpus_cargo_ui.lua` y dejó FALSA la frase de al
lado, y el PARCHE 16 mató la mentira de la «API de ARC9 pendiente» en el §14 de
`Cargo_Architecture` **pero no en las otras cuatro sedes**, dejando al doc contradiciéndose consigo
mismo y con su propio subsistema. La cola es un convar que nunca existió y el racimo de marcadores
rancios que el PARCHE 14 no alcanzó. Sin superficie de runtime: los cuatro parches son doc, salvo
el comentario de `corpus_cargo_ui.lua` — ni una línea ejecutable.

- PARCHE 19 — docs(ui): **REGRESIÓN del PARCHE 13.** El comentario de `BuildFrame` (`corpus_cargo_ui.lua`) cerraba con «Center and right are identical in every state», y es falso: la columna **`right` NO es idéntica** — en `trade` recibe la deal bar (`Trade.BuildDealBar(right)`) y su grid gana `priceOf`/`basketOf`, y en `loot` el footer reserva 112 px para el botón «Move all». Se contradecía con su propia frase dos líneas antes, que ya decía que la deal bar va «under the own grid» (que ES `right`). Idéntica en los tres estados es **solo la columna central**. Comentario, ni una línea ejecutable. **[APLICADO 2026-07-14]**
- PARCHE 20 — docs(docs): **REGRESIÓN del PARCHE 16.** La verificación de la API de ARC9 (2026-07-10, base + pack EFT de Darsu, anotada en el header de `corpus_cargo_arc9.lua`, congelada por el contrato #8) seguía anunciada como **tarea futura en cuatro sedes** que el PARCHE 16 no tocó: `Cargo_Architecture` **§10.3** (que la mandaba «al prompt de CC») y **§13** (fila «Upgrades de armas ARC9/EFT»), y `Workbench_Arquitectura` **§6** y **§10** (fila Upgrades). Las cuatro corregidas: la API está verificada y el puente en producción; lo que sigue abierto es el **diseño del árbol de upgrades**, y nada más. **[APLICADO 2026-07-14]**
- PARCHE 21 — docs(docs): **convar fantasma.** `Cargo_Architecture` §16.8 gateaba la rama de armas de mundo con un `cargo_world_guns` que **no existe en el árbol**: el convar real es **`cargo_weapon_world_pickup`** (`corpus_cargo_capture.lua`; `cvWorldGuns` es solo el nombre de la variable Lua que lo sostiene, de ahí la confusión). El roadmap ya lo citaba bien. Se corrige también en la **entry 12** de este mismo CHANGELOG, donde el nombre ya era falso al escribirse — corrección de identificador, sin borrar ni renumerar nada. **[APLICADO 2026-07-14]**
- PARCHE 22 — docs(docs): **el racimo de marcadores rancios que quedó vivo** en `cargo_roadmap.txt`. Los frentes **#25** (reordenar el cinturón) y **#26** (unload) figuraban como **«SIN DISEÑAR»** estando cerrados, implementados y confirmados en juego —`Inventory.BeltMove` + `BeltMergeInto` y `AmmoPool.UnloadWeapon`, CHANGELOG #12 `[APLICADO 2026-07-12]`— cuatro líneas debajo de un encabezado que ya decía «ESTADO: CERRADO». El **#27** describía en presente un bug que el mismo #12 arregló (el `PlayerUse` de `capture.lua` ya cubre `corpus_cargo_item`). El **#18** figuraba «SIN diseñar» en la L165 y «hoy no persiste» en su cuerpo, con `Inventory.StoreClip` en producción desde la entry #10 y el propio roadmap desmintiéndose 30 líneas más abajo. Y la sección **«AHORA (cierre del Block 1)»** pedía re-verificar la entry #2 —`[APLICADO 2026-07-11]`— contra un checklist de `cargo_estado.md` que ya no existe. Los cinco corregidos contra sus entries. De paso, el encabezado **«HALLAZGOS IN-GAME 2026-07-12 … — SIN DISEÑAR»** declaraba ese estado **por el grupo entero** cuando sus cuatro ítems (**#28 a #31**) están CERRADOS: pasa a «ESTADO POR ÍTEM», y el marcador de cada ítem manda. (Los #32-#42 son de la pasada del **2026-07-13**, sección aparte — no de este grupo.) **[APLICADO 2026-07-14]**

---

## PARCHES DE sesión Etiquetado de IDs normativos (deuda D-7) — 2026-07-19

Tanda multi-repo del ecosistema, guiada por `dev/PROMPT_d7_etiquetado_ids.txt` (§8 del flujo).
Solo prosa: **ninguna norma cambió**. Cada sede que el registro
(`../corpus/docs/ids.yaml`) declara ahora lleva su ID visible, para que un lector que
aterriza en el doc vea de qué norma se trata sin abrir el registro, y para que el gate de
coherencia (§7.8) pueda contrastar el título del yaml contra la prosa de su sede.

- PARCHE 1 — **38 de 48 IDs de la familia `CRG` etiquetados en su sede.**
  Los 10 restantes NO se etiquetaron a propósito: sus sedes viven en archivos `.lua`,
  en el CHANGELOG, en el estado o en el roadmap. Etiquetar ahí volvería **definitorio** un
  comentario, que es lo que **FLU-26** prohíbe, o tocaría un doc que no se reescribe
  (**FLU-14**). Son deuda **D-3** del registro y se cierran moviendo la sede a un doc —
  decisión de diseño, no mecánica. **[APLICADO 2026-07-19]**

- PARCHE 2 — **La deuda D-1 pagada en el repo dueño.** `Cargo_Architecture.md` §3 gana un
  bloque que **cita** `COR-12` (la def y su `onUse` van en shared) con su causa —la UI
  client-side exige `isfunction(def.onUse)`— y `COR-13` (el retorno gobierna el consumo).
  Cargo es el dueño de `Items.Register` y hasta hoy no lo decía en ningún doc: las seis
  copias vivían en los repos consumidores. Es el único lugar de la tanda donde se agregó
  prosa nueva en vez de solo anteponer un ID. **[APLICADO 2026-07-19]**

- PARCHE 3 — **Contratos que eran copias, ahora CITAN:** `COR-11`, `COR-1`/`COR-10`,
  `COR-2`, `COR-3`/`COR-8`, `COR-4`, `COR-5`, `COR-6`. **[APLICADO 2026-07-19]**

Sigue abierto, y es la mitad fea de D-1: el comentario de `shared/corpus_cargo_items.lua`
anota `onUse ... (SERVER)`, que **induce el bug** al leerse solo. Es `.lua`: va en la
pasada de D-3.

Verificación: `corpus/.claude/check-ids/corpus_check_ids.ps1` en verde (una etiqueta mal
tipeada habría salido como `HUERFANO_DOC`). Sin superficie de runtime: nada que cargar en
un mapa, y **ningún check de planilla nace de esta tanda** (FLU-37).

---

## PARCHES DE sesión Anti-drift: cierre de votos — 2026-07-19

Tanda multi-repo guiada por `dev/PROMPT_cierre_antidrift.txt`: el autor votó las deudas
abiertas del registro y acá se aplica lo que toca a este repo.

- PARCHE 1 — **D-9 cerrada: la notación del footprint vive en su doc dueño.** **`CRG-38`**
  (el «2x3» del autor es `{w=3, h=2}` — alto×ancho, el reverso del código) se enuncia en
  `Cargo_ItemImages_Arquitectura.md` §5, la sede que `CRG-36` declara, aclarando que los
  pares del propio doc (y el set permitido) van en notación de código **ancho×alto**. La
  trampa del toolgun queda desactivada; la entry del §8 (3.ª pasada, 2026-07-12) de este
  CHANGELOG queda como historia (FLU-14). **[APLICADO 2026-07-19]**
- PARCHE 2 — **La mitad fea de D-1, saldada.** El comentario de
  `shared/corpus_cargo_items.lua` ya no anota `onUse ... (SERVER)` a secas: dice que la def
  y su `onUse` se registran en **AMBOS realms** y que la closure solo CORRE en server,
  citando `COR-12`. Ya no induce el bug al leerse solo. **[APLICADO 2026-07-19]**
- PARCHE 3 — **Curaduría D-10 (votada por el autor):** el contrato 7 del `CLAUDE.md`
  enuncia la mitad real de **`CRG-6`** que solo el registro afirmaba (toda mutación termina
  en Save + Sync + refresh de movimiento); el contrato 8 generaliza **`CRG-24`** a API de
  terceros y del engine (no solo ARC9); la fila fija de tabs es ahora **`CRG-49`**
  (`Cargo_Architecture.md` §7.1, partida de `CRG-10`); **`CRG-48`** se reescribe a las tres
  capas de idioma que su sede enuncia; y **`CRG-19`** se reformula en positivo (voto del
  autor: sigue **VIGENTE** — es la norma que sostiene el `skipCap` del `Confirm`; el
  titular «DEROGADO» de `Cargo_Trade_Arquitectura.md` §3 pasa a enunciarla como regla
  activa, conservando la historia de la enmienda del 2026-07-14). **[APLICADO 2026-07-19]**

Verificación: `corpus/.claude/check-ids/corpus_check_ids.ps1` en verde sobre 197 IDs. Sin
superficie de runtime (solo el comentario de items.lua, ni una línea ejecutable), y
**ningún check de planilla nace de esta tanda** (FLU-37).

---

## PARCHES DE sesión Anti-drift: reparación del COMPLETO — 2026-07-19

Aplica los hallazgos del acta `corpus/docs/auditorias/2026-07-19_coherencia_docs.md` que
tocan este repo — el más auditado de la corrida (10 de 26).

- PARCHE 1 — **2.1 / 2.7 / 2.11:** el encabezado de `Cargo_Architecture.md` separa por
  fin **SALIENTES** (Cortex y Coagulant — las únicas dos consultas reales) de
  **ENTRANTES** (Coagulant, Craving y Caliber registran CONTRA Cargo — CRG-44/CRV-13):
  la flecha Cargo↔Craving estaba invertida y Caliber jamás fue arista saliente. La fila
  de barras de §11 y la enmienda §15 dejan de prometer una barra «Health» que Coagulant
  descartó: registra **una sola** (Blood); la vida la pinta su silueta. **[APLICADO 2026-07-19]**
- PARCHE 2 — **2.2 (ALTA):** §3 deja de decir que un stackeable persiste «solo un
  `count`»: la entry es `{id, count, condition?}` y el stack **se parte por condición** —
  mezclar desgastes sería una reparación gratis (el anti-lavado de `AddStack`, que
  además factura el comercio por `id + condición`). **[APLICADO 2026-07-19]**
- PARCHE 3 — **2.3 (ALTA):** la fila de capture del CLAUDE.md deja de decir «nunca
  vetando `PlayerCanPickupWeapon`»: la ruta de **give** no se veta; el **world gate** sí
  veta armas en reposo en el mundo (roadmap #16, CHANGELOG #7). `CRG-40` alineado en el
  registro. **[APLICADO 2026-07-19]**
- PARCHE 4 — **2.5 (ALTA):** el harness deja de declararse descartable en el CLAUDE.md:
  es **permanente** en `dev/harness_cargo.py` (355 checks acumulados), referente citable
  de ~20 evidencias `tipo: harness` del registro — tirarlo borraría evidencia. **[APLICADO 2026-07-19]**
- PARCHE 5 — **2.8 / 2.13 / 2.18:** §1 anota la enmienda de gradas (el «grid uniforme /
  cada ítem una celda» murió el 2026-07-11; el footprint es **solo render**) — también en
  el «Qué es» del CLAUDE.md; §4 corrige «clase "placa"» (el registro hace `error()` con
  cualquier `class` fuera de stackable/unique — el eje es `category:plates`, CRG-8); y la
  fila del SWEP Hands describe el fix **vivo** de brazos oscuros
  (`render.SuppressEngineLighting` + caja de luz propia; `SetLightingOriginEntity` falló
  y se revirtió — CHANGELOG #9). **[APLICADO 2026-07-19]**
- PARCHE 6 — **2.14 / 2.21 / 2.22 / 2.23 (roadmap):** el #30 gana el cross-ref a la
  enmienda #27 (el aviso «You already have one.» es historia), los cruces 8/9 se parten
  en cerrado / en-código-sin-verificar / pendiente real (solo el drenaje de stamina), el
  #21 ubica los círculos junto al cinturón (orden §15.2, APLICADO en CHANGELOG #8) y el
  #17 deja de diferir al «Bloque B» la persistencia de blob que el #18 cerró en la misma
  entry (#10). **[APLICADO 2026-07-19]**
- PARCHE 7 — **2.25 — VOTO DEL AUTOR: el GC del cadáver looteado es de CARGO.** La
  frontera del §9 de `Cargo_Trade` queda adjudicada: la loot table (el QUÉ dropea) es de
  Cortex/Caliber; el **cadáver looteable es un contenedor de Cargo** (CRG-21) y su GC —
  el CUÁNDO se limpia — es de **Cargo**, agnóstico al diseño de Cortex (que queda como
  capa de IA sobre la base de NPC). Coincide con la fila del §11, que ya lo decía: la
  contradicción interna del doc muere. **[APLICADO 2026-07-19]**

Deuda de verificación que el acta detectó al pasar (decide el autor): la entry **#27
sigue `[PENDIENTE]`** con su código en el árbol y `cargo_estado.md` dándolo por estado
de HOY — o falta la pasada en juego, o falta el flip.

Verificación: checker en verde + suite 12/12. Sin superficie de runtime: todos los
parches son doc.

---

## PARCHES DE sesión D-13: pre-2.º COMPLETO — 2026-07-19

Parte de la tanda multi-repo guiada por `dev/PROMPT_d12_d13_segundo_completo.txt`, que cerró
las deudas **D-12** y **D-13**. Este repo es el que más recibe: tenía **tres** de los 10 docs
ciegos y **dos** sedes fuera de un doc de diseño. Solo prosa: ninguna norma cambió de contenido.

- PARCHE 1 — **`Workbench_Arquitectura.md` deja de ser invisible: nacen `CRG-50`..`CRG-54`.**
  Eran 128 líneas de diseño de un subsistema entero (craft/reparación/desarme) con **cero**
  IDs — no estaba sano, estaba **ciego**, y produjo cero hallazgos en el COMPLETO por eso. Se
  acuñó lo que la prosa YA enunciaba: tabla explícita de desarme (`CRG-50`), herencia de
  condición (`CRG-51`), herramienta = tasa y no acceso (`CRG-52`), asimetría de toolkit
  (`CRG-53`) y tope de reparación por calidad de parte (`CRG-54`). Toda la familia es
  `INTENCION` por construcción: el bloque no está implementado y no hay un solo call site.
  Eso es honesto, no deuda. **[APLICADO 2026-07-19]**
- PARCHE 2 — **Tres reglas de ese mismo doc NO se acuñaron: se CITAN**, porque ya son normas
  de otra sede y acuñarlas habría fabricado IDs bicéfalos al nacer. La eyección antes de
  destruir es **CRG-9**, el patrón de módulo dueño es **CRG-1**, el canal ARC9 de
  lectura-only es **CRG-23**. La persistencia del banco cita **CRG-43**/**COR-3**.
  **[APLICADO 2026-07-19]**
- PARCHE 3 — **`CRG-55` acuñado: la tabla de alcances de `cargo_convenciones_commits.txt` §3.**
  Tercer doc ciego de este repo. La §3 es por-repo (cita GIT-6); el `CLAUDE.md` la resume y el
  doc manda. Los 15 alcances se derivaron del propio doc — `workbench` está RESERVADO hasta
  que abra su bloque, y existe en la tabla para que ese día nadie invente un alcance nuevo.
  **[APLICADO 2026-07-19]**
- PARCHE 4 — **La sede ROTA de `CRG-45` se muda a `Cargo_Architecture.md` §13.1** (nuevo).
  Estaba rota **por partida doble**: `cargo_roadmap.txt` no contenía la cadena `CRG-45` en
  ninguna parte, y un roadmap es intención pura (nivel 6) que no puede alojar una norma
  vigente. El checker no la cazó porque **la ruta existía** — su validación de sede es
  presencial sobre el archivo, no sobre la etiqueta. La sección nueva enuncia la norma con su
  matiz completo: es DEUDA DECLARADA (el `TODO` anotado esperando la primitiva de permisos),
  el único `net.Receive` que hoy espera gate es `NET_ICON_OVERRIDE` —contenido por
  **CRG-46**— y los otros 14 no lo necesitan porque los protege **CRG-6**. El roadmap ahora
  cita §13.1. **[APLICADO 2026-07-19]**
- PARCHE 5 — **La sede de `CRG-42` se muda de `cargo_estado.md` a `Cargo_Architecture.md` §4**
  (subsección nueva: cómo se deriva el slot de un arma capturada). Vivía en un doc **volátil
  de nivel 2 que se reescribe entero en cada refresh**: la norma estaba a un refresh de
  desaparecer sin que nadie lo notara. La prosa nueva explica el POR QUÉ, que el estado no
  tenía espacio para decir: `SWEP.Slot` es inconsistente entre packs, así que la señal es
  `SWEP.Class` + `SubCategory` resueltas por herencia — el mismo principio que **CRG-41**
  aplica a la trivia. **[APLICADO 2026-07-19]**
- PARCHE 6 — **`cargo_roadmap.txt` (531 líneas, el doc ciego más grande del ecosistema) pasa a
  citante**, sin acuñar: por voto del autor un roadmap es intención pura. NOTA DE LECTURA que
  lo declara nivel 6 y NO-AUDITABLE POR DISEÑO, con el caso de `CRG-45` anotado como la
  demostración de por qué. **[APLICADO 2026-07-19]**

Verificación: checker en verde sobre 207 IDs + suite 12/12. Sin superficie de runtime: **ni
una línea de Lua cambió**, y ningún check de planilla nace de esta tanda (FLU-37).

---

## PARCHES DE sesión Reparación del gate de coherencia (acta 2026-07-22) — 2026-07-22

Tanda de reparación documental propuesta por el gate de coherencia en su corrida COMPLETO del
2026-07-22 (`../../corpus/docs/auditorias/2026-07-22_coherencia_docs.md`; el gate propone, el
autor dispone). Acá lo que toca a este repo. Solo prosa; **ninguna norma cambió de contenido**.

- PARCHE 1 — **Hallazgo 2.3 del acta (pase de valor):** `docs/cargo_roadmap.txt` decía
  «espejado como cross-ref en `caliber_roadmap.txt §2[5]`»; no existe `[5]` en ese doc — el
  cross-ref vive en `[4]`. Corregido a `§2[4]`. **[APLICADO 2026-07-22]**
- PARCHE 2 — **Hallazgo 2.4 del acta:** la tabla `CARGO.Capture.WeaponTrivia` tiene **40**
  entradas (9 arc9_eft + 19 arc9_cod2019 + 12 weapon_ HL2, contadas en el árbol), no 36. Se
  corrige la cifra en `docs/cargo_roadmap.txt` (#38) **y** en `docs/cargo_estado.md` (misma
  cifra stale). **[APLICADO 2026-07-22]**
- PARCHE 3 — **Hallazgo 2.7 del acta:** el árbol tiene **22** `net.Receive` en
  `lua/corpus_cargo/server/` (ammopool 1 + containers 3 + holster 1 + icons 1 + inventory 14 +
  trade 2), no 15. Se corrige la cifra en su **sede**, `docs/Cargo_Architecture.md` §13.1 (22
  net.Receive, otros 21), y el eco en `docs/cargo_roadmap.txt` (#12: «los otros 21»). CRG-45 /
  CRG-46 / CRG-6 sin cambio de contenido. **[APLICADO 2026-07-22]**

Verificación: sin superficie de runtime — **ni una línea de Lua cambió**. Cifras recontadas
contra el árbol (árbitro de nivel 1, §7.1). No commiteado ni pusheado (GIT-7).

---

## 28. Toma del piso de una 2.ª arma de una clase ya EQUIPADA (fix W3 de la entry #27) `[APLICADO 2026-07-23]`

Reporte del autor (pasada 2026-07-23 de la entry #27, check W3): comprar dos armas iguales
✓, pero tomar del PISO una 2.ª de una clase **ya equipada** se rechazaba con «You can't take
that right now». Causa raíz: la captura viaja en `WeaponEquip`, que solo dispara si
`ply:PickupWeapon` tuvo éxito — y el engine sostiene **una entidad SWEP por clase**, así que
rechaza la segunda de una clase equipada; encima `Capture.Decide` devuelve `"keep"` para toda
clase equipada (`server/corpus_cargo_capture.lua` §525-548). El «N armas iguales» del #27
funcionaba con la 1.ª en el GRID (`equippedCount == 0`), no con una equipada.

El invariante «una clase equipada nunca se toca» se **mantiene para el give ANÓNIMO** del
engine (el loadout del respawn, que es lo que el dedup protege). Lo que se abre es solo la
TOMA DELIBERADA del piso: cada arma es su propia instancia (roadmap #15/#30).

- PARCHE 1 — fix(capture): en la rama WALK+USE del hook `PlayerUse`, si la clase ya está
  equipada (`EquippedClassCount(ply, class) > 0`), se captura el arma de mundo **directo al
  grid** en vez de pasar por `ply:PickupWeapon`: `EnsureDef` + `Inventory.GiveItem` +
  `StoreClip` (conserva el cargador del arma del piso, #18) + `NotifyPickup` + `ent:Remove`.
  Guardas: `cargo_capture_weapons` activo, no `Capture.Ignore`, no cara throwable
  (`ThrowableFace == nil`, para no resucitar la 2.ª cara de un frag/SLAM — #32). Queda una
  equipada + N en el grid, cada una su instancia; el give anónimo sigue en `"keep"`.
  **[APLICADO 2026-07-23]** (pasada 2026-07-23, W3 ✓: 3 armas probadas, las 3 entran al grid
  con su propio cargador)

Verificación offline: el archivo carga sin romper sintaxis y los 355 checks del harness
siguen verdes (regresión). El camino nuevo es interacción con el engine (`PickupWeapon` /
entidades de arma), que el harness no simula: se confirma EN JUEGO (§1 PASO 4). No commiteado
ni pusheado (GIT-7).

---

## 29. `Inventory.TakeUnique`: consumir un ítem `unique` (soporte del cap de torniquete de Coagulant) `[APLICADO 2026-07-23]`

Gemela de `HasItem` (#18) por el otro lado: `TakeItem`/`CountItem` drenan y cuentan **solo
stacks** (`entry.uid == nil`), así que un consumidor que necesita CONSUMIR de verdad un
`unique` no tenía cómo. Nace del cap del torniquete de Coagulant (pasada 2026-07-23, nota del
check V3): un torniquete `unique` se ponía en varias extremidades porque `HasItem` seguía
dando true (nunca salía del inventario). El torniquete pasa a **ocuparse** (sale al ponerlo,
vuelve al quitarlo), y para eso Cargo debe poder sacar una instancia unique concreta.

- PARCHE 1 — feat(inventory): `Inventory.TakeUnique(ply, id)` — saca UNA instancia unique de
  `id` del grid (`entry.uid ~= nil`), borra su blob (`Instances.Delete`) y hace `Touch`.
  Devuelve true si sacó una. No toca stacks (para eso está `TakeItem`). Lectura/mutación pura
  sobre `rec.items`, misma forma que `HasItem`. **[APLICADO 2026-07-23]** (ejercitado por el cap
  del torniquete: TQ ✓ en la pasada 2026-07-23 — ver el CHANGELOG de Coagulant)

Verificación offline: harness_cargo carga el archivo y sus 355 checks siguen verdes; el uso
real (occupy/return del torniquete) se prueba con Coagulant montado, en juego. No commiteado
ni pusheado (GIT-7).

---

## 30. Strips del comercio parejos de verdad: BUY crece por el footer de peso (fix W1 de la #27) `[APLICADO 2026-07-23]`

Reporte del autor (pasada 2026-07-23, ronda 2, check W1): la fila de abajo del estado Trade se ve
despareja — la barra **BUY** (trader) queda más corta que el bloque **SELL** (jugador). La 1.ª
pasada lo reportó al revés (SELL más bajo); la ronda 2 lo corrigió con el ojo del autor: BUY es más
corto **porque el lado del jugador lleva abajo el footer de PESO** (`corpus_cargo_ui.lua`, la barra
de capacidad `%.1f kg`) que el trader no tiene. Ambos strips ya leían el mismo `STRIP_TALL = 134`
(entry #27a) — el número compartido estaba bien; faltaba que la columna del trader emparejara la
altura del footer que solo existe del lado del jugador.

- PARCHE 1 — fix(trade): la barra BUY de `BuildStockColumn` pasa a
  `SetTall(STRIP_TALL + 8 + WEIGHT_FOOTER_TALL)` — crece por el footer de peso (34) + su gap (8),
  así el bloque inferior del trader iguala `Sell (134) + peso (34)` del jugador y la fila lee como
  una sola. Nace la constante compartida `CARGO.Trade.WEIGHT_FOOTER_TALL = 34`, que `ui.lua` lee
  para el footer y `BuildStockColumn` para el crecimiento — un solo número, no dos que derivan.
  **[APLICADO 2026-07-23]** (pasada en juego del autor: la fila BUY/SELL queda pareja de lado a lado)

Verificación offline: el harness carga los archivos client sin romper (355 verdes). Es layout VGUI
puro (alturas de dock), que el harness no pinta: se confirma EN JUEGO. No commiteado ni pusheado
(GIT-7).

---

## 31. 11 armas makeshift más del arsenal del autor, pesadas y precificadas (cierra el addendum de la #25) `[APLICADO 2026-07-23]`

Reporte del autor (pasada 2026-07-23, ronda 2, check X1): un `cargo_dev_dump_weapons` nuevo
encabezó **`# 380 SWEPs, 371 capturables | sin peso: 11 | sin precio: 11`** — NO es regresión del
fix de la #25 (el dump ya no grita lobo: las plantillas salen `n/a`, hay columna de precio), sino
**arsenal nuevo**: 11 clases del pack `arc9_eft_makeshift` que no están en `dev/other/` y que la
#25 no alcanzó a catalogar. Mismo remedio que la #25: se catalogan desde el propio volcado (clase /
nombre / tipo / munición) con cifras reales de arranque, sin tener el pack.

- PARCHE 1 — feat(capture): las 11 clases entran a `weapon_weights.lua` **y** `weapon_prices.lua`
  (bloque «makeshift: altas 2026-07-23»): M919 (pistola 9x19), ASh-20 (lanzagranadas), NEWD M53
  (FAL), MXLR .357, CG NL 12/70 (escopeta), TPPK (SMG), AD-44 (RPD/AK), Sako TRG 50 (sniper),
  SKS-9x39, TSVD, VALAK Mod.4. Peso `real approx` y precio de arranque por tipo (a calibrar en
  juego, como el resto del arsenal). Sin `value` no se comercia y sin peso cae al nominal 2.5 — los
  dos huecos eran el mismo. **[APLICADO 2026-07-23]** (pasada en juego del autor: un dump nuevo
  encabeza `sin peso: 0 | sin precio: 0`)

Verificación offline: sintaxis de las dos tablas (el harness las carga; 355 verdes). El conteo 0/0
se confirma con el dump en juego. No commiteado ni pusheado (GIT-7).

---

## 32. Compat con Quick Loadouts: el loadout es una entrega de ítems, nunca destruye nada `[APLICADO 2026-07-23]`

Pedido del autor (2026-07-23; mapa del mod + diagnóstico + wants en
`dev/Cargo_QuickLoadouts_Referencia.md` — alcance acordado: solo funcionalidad, SIN UI). El bug
reportado: con `quickloadout_enable_client 0` las armas equipadas persistidas desaparecen. Causa
verificada contra el código vivo (`dev/other/quick loadouts/.../sv_loadout.lua`, CRG-24): el hook
`PlayerLoadout` del mod (la global `QuickLoadout()`, sv:59) hace `StripWeapons()` +
`RemoveAllAmmo()` INCONDICIONALES (sv:63-64) — también con tabla vacía, que es lo que deja el
"cliente desactivado" (sv:29) —, y con loadout activo devuelve `true` (sv:100-102), cortando la
cadena: que los hooks de restauración de Cargo corrieran era lotería de orden de inserción. Además
el net receive re-corre la cadena ENTERA en cualquier momento de la partida (sv:42). El wipe del
pool además le leía como consumo al espejo §16, que drenaba el cinturón (pérdida real de ítems).

- PARCHE 1 — feat(capture): nace `server/corpus_cargo_quickloadout.lua` — **takeover del hook**:
  se remueve `"QuickLoadoutLoadout"` y se re-registra la MISMA función envuelta, ÚLTIMA en el
  orden del manifest. Con eso la cadena es determinista: todos los hooks `PlayerLoadout` de Cargo
  (re-give del inventario + reconcile a 0.1 s, gate `ready` del ammopool + rebuild a 0.5 s, manos
  a 0.25 s) ya corrieron Y agendaron sus heals antes del strip — el espejo queda suprimido en la
  ventana, el reconcile re-da toda clase equipada stripeada, y el wrapper **banquea los cargadores
  vivos** en los blobs (`StoreClip`) antes de llamar al original. Mid-round, además, recuerda el
  arma en mano y la re-selecciona a 0.35 s (el loadout es una ENTREGA, no un swap; en spawn mandan
  las manos del roadmap #4). El original corre intacto vía `pcall` y su `return true` hacia
  `GM:PlayerLoadout` se preserva. Detección honesta (COR-5): sin el mod montado el archivo es
  inerte; kill-switch `cargo_quickloadout_compat` (con captura apagada también es pass-through).
  Los gives del mod NO se tocan: caen en la captura `WeaponEquip` existente como cualquier give
  anónimo (clase nueva → ítem al grid; clase ya poseída → dedup; equipada → keep), y la munición
  regalada muere en el rebuild del spawn (§16: sin éter). Edge aceptado y anotado: una clase del
  loadout que además está equipada cae en "keep" y el `SetClip1(max)` del mod le llena ese cargador.
- PARCHE 2 — fix(inventory): el re-give de `"corpus_cargo_inv_loadout"` ahora **salta las clases
  que ya están en mano** (guard `HasWeapon`): en las pasadas mid-round re-daba sobre el arma viva y
  `RestoreClip` le pisaba el cargador actual con el clip viejo del blob (recarga gratis). En spawn
  real el jugador no tiene nada y todo se da igual que antes. **[APLICADO 2026-07-23]** (pasada en
  juego del autor: checklist a-b-c de abajo verificado)

Verificación offline: harness 355 verdes en ambos realms (el stub de player ganó `SetSaveValue` /
`GetViewModel`, extensión explícita como pide su header). En juego, checklist: (a) con
`quickloadout_enable_client 0`, spawn y pasada mid-round → cero pérdida (equipadas, cargadores,
cinturón); (b) con loadout activo → las armas del loadout aparecen como ítems en el grid una sola
vez, las equipadas siguen, sin munición del éter; (c) apply mid-round → el arma en mano vuelve a
la mano. No commiteado ni pusheado (GIT-7).

---

## 33. El holster anima el enfundado: reciclaje de Simple Holster en las manos `[APLICADO 2026-07-23]`

Pedido del autor (2026-07-23; mapa + wants en `dev/Cargo_SimpleHolster_Referencia.md`): reciclar
la capa funcional de Simple Holster (Chen, 2546335680) en el holster propio (#22/#4). El SWEP de
manos ya estaba (Hands, entry 9); esto porta la TRANSICIÓN. Verificado contra el código vivo
(`dev/other/simple holster/.../sh_holsterweapon.lua`, CRG-24).

- PARCHE 1 — feat(inventory): `server/corpus_cargo_holster.lua` recicla, del mod: (1) la **cascada
  de animación** `ACT_VM_HOLSTER → seq "holster" → ACT_VM_DRAW → seq "draw" →
  ACT_SLAM_DETONATOR_THROW_DRAW` con el truco **"undraw"** (solo hay draw → se reproduce AL REVÉS
  a 2x, media duración) — cubre cualquier arma sin anim de holster dedicada; (2) la **lista de
  exclusión de bases** que ya animan su propio enfundado (ArcCW/ARC9/TacRP/TFA/CW2/FAS2/UT99 +
  SS/HLAZ condicionales por sus cvars) — para esas se cambia al acto y la base hace su transición
  (ARC9 es la que importa acá); (3) los **candados de transición**: flag `CargoHolstering` +
  scrub de `IN_ATTACK|IN_ATTACK2|IN_RELOAD` en `StartCommand` (la máscara 10241 del mod, sh:370)
  + `m_flNextAttack`; (4) la **memoria `m_hLastWeapon`**: Q (lastinv) alterna arma ↔ manos, en
  ambos modos de holster (Hands o nada); (5) el **rate-limit 0.5 s** por jugador (sh:235). El
  switch real ocurre server-side al terminar la anim (nuestro holster es intent-driven, contrato
  #7), con guard de identidad (si el jugador cambió de arma a mitad de la anim, no se le arranca
  la nueva). Kill-switch `cargo_holster_anim`; el deploy de spawn va `instant` (roadmap #4: manos
  YA). Desvíos deliberados del original, anotados en el header: `m_flNextAttack` va en tiempo
  ABSOLUTO (el mod pasa la duración pelada, sh:309 — ese candado nunca mordía); el auto-holster
  en escaleras NO se porta (opcional en los wants, fuera del alcance acordado). `SlotKey` ignora
  intents durante la transición. **[APLICADO 2026-07-23]** (pasada en juego del autor: checklist
  de abajo verificado — undraw en HL2, ARC9 con su propia anim, Q alterna, candados)

Verificación offline: harness 355 verdes. En juego: enfundar un arma HL2 (anim reversa), una ARC9
(su propia anim, sin doble), Q vuelve al arma, no se puede disparar/recargar mientras enfunda,
re-apretar el número enfunda con anim. No commiteado ni pusheado (GIT-7).

---

## 34. La cajita como default honesto: suministros HL2, mochilas genéricas y el punto de sustitución de modelos `[APLICADO 2026-07-23]`

Pedido del autor (2026-07-23): (a) los ítems sin modelo —el set médico de Coagulant, y todo def
setting-agnostic— deben caer **a propósito** a la cajita de cartón del drop
(`models/props_junk/cardboard_box004a.mdl`, el fallback que la cadena de resolución ya tenía),
dejando una vía para que **cualquiera** sustituya esos modelos por los que quiera; (b) el
framework base suma como ítems default las entidades estándar de salud y escudo de HL2; (c) y
**ambas mochilas** genéricas. Es cross-repo (FLU-04, Cargo primero): `corpus-stalker` consume el
punto de sustitución para re-vestir venda/botiquín/mochilas con modelos de la Zona, y Coagulant
solo anota la decisión (sus defs ya no declaraban modelo — ahora es contrato de diseño, no
accidente).

- PARCHE 1 — feat(items): **`Items.SetModel(id, model)`** — el punto de sustitución de modelos
  (`shared/corpus_cargo_items.lua`). El override se guarda en `_modelOverrides` y se aplica en el
  acto si el def ya existe, o al registrar(se) — **orden-independiente entre addons** (COR-5:
  nadie asume que el otro ya cargó) y **sobrevive al re-registro** (autogen defs y lua refresh
  re-registran su tabla; sin la re-aplicación en `Register` resucitaban el modelo original). Gana
  sobre el `model` declarado, así que sirve para re-vestir cualquier ítem. Un path no montado es
  inofensivo: `ModelUsable` ya gatea drop e íconos y ambos caen al default exacto de siempre. El
  precache del modelo declarado se extrajo a un helper (`PrecacheDeclared`) que ahora también
  cubre al override. Va al bloque CONTRATO del init.
- PARCHE 2 — feat(items): nace **`shared/corpus_cargo_supplies.lua`** (manifest: después de
  `ammo`) — el set default del framework base, como el de munición (§16): **Health Kit** (+25 HP,
  `models/items/healthkit.mdl`), **Health Vial** (+10, `healthvial.mdl`), **Suit Battery** (+15
  de armadura HL2 cap 100, `battery.mdl`, categoría `misc`, `effect_icon` battery) — `onUse` con
  los valores y sonidos de pickup del ENGINE (`HealthKit.Touch` & co.; al tope no consume, como
  la entidad de HL2 que rechaza el touch). NO es medicina: heridas/sangre son de Coagulant y
  estos ítems no las tocan (CRG-1 intacta — Cargo es dueño de estas defs, su semántica
  engine-genérica vive acá). Más **dos mochilas genéricas** para el slot Back: `Backpack`
  (1.8 kg, +12 kg, $1500) y `Large Backpack` (3.2 kg, +24 kg, $3200), `unique` con condición,
  **sin modelo a propósito** (HL2 no tiene prop de mochila): caen a la cajita hasta que un addon
  de contenido las re-viste vía SetModel. Números de arranque, a calibrar en juego.
- PARCHE 3 — chore(dev): el kit `cargo_dev_give` entrega el set nuevo (healthkit/vial/battery ×2,
  ambas mochilas) y el selftest suma **7 checks**: suministros registrados con `onUse` en ambos
  realms (COR-12), mochilas equipables en Back con su bonus, mochilas sin modelo propio (caen a
  la caja), y SetModel antes / después / sobre re-registro. `cargo_selftest` pasa a **76 server /
  83 client**.
- PARCHE 4 — chore(dev): **adquisición dev por ítem** (pedido del autor 2026-07-23, al preguntar
  cómo probar ítems sueltos: los defs no son entidades y no se spawnean del spawnmenu — el kit
  entero era la única vía). `cargo_dev_items [filtro]` lista los defs registrados en la sesión,
  agrupados por categoría (armas capturadas `wpn_*` y attachments ARC9 son BULK: cientos de
  autogen que ahogarían el listado — solo aparecen con filtro explícito; para el arsenal ya está
  `cargo_dev_dump_weapons`). `cargo_dev_give_item <id|texto> [cantidad]` da N unidades de UN def:
  id exacto primero, si no substring sobre id+nombre (1 match da, varios los imprime, 0 avisa);
  stackables van en un solo GiveItem, uniques una instancia por unidad con **tope 10 por llamada**
  (cada unique es un blob en disco — un typo en la cantidad no debe acuñar cientos). Sirve
  también para los ítems de Coagulant/Craving montados (cualquier def registrado).

Lado contenido (mismo pedido, repos hermanos): `corpus-stalker` estrena
`lua/autorun/corpus_stalker_itemmodels.lua` (re-viste `corpus_coagulant_bandage` → wick_bandage,
`corpus_coagulant_medkit` → medkit_low, y las dos mochilas → backpack-1/2 de hgn, mapeo
provisorio) + los assets de spec45as/wick copiados con rutas verbatim; Coagulant anota en su §7 y
en el comentario de sus defs que la ausencia de modelo es decisión, no deuda. Tourniquet y Blood
Bag quedan en la cajita (sin modelo coherente identificado por el autor).

Verificación offline: harness **355 verdes en ambos realms** (el manifest carga el archivo nuevo
solo). En juego (pasada del autor): (a) `cargo_dev_give` → healthkit/vial/battery curan/cargan
con su sonido y NO se consumen al tope; (b) las mochilas equipan en Back y suman capacidad;
(c) SIN corpus_stalker las mochilas y los ítems de Coagulant dropean como la cajita con su
etiqueta; (d) CON corpus_stalker montado, venda/botiquín/mochilas dropean y renderizan ícono con
el modelo de la Zona (log `[Corpus:stalker] modelos de ítem sustituidos: 4/4`), y el autor
verifica cuál mochila es cuál. **Confirmado en juego por el autor el 2026-07-23** (checklist
a-d ✓; el mapeo chica→backpack-1 / grande→backpack-2 quedó confirmado, deja de ser provisorio).
Commiteado y pusheado con autorización del autor.

---

## 35. El banco de sonidos entra al juego: UI de inventario + persona del trader `[APLICADO 2026-07-24]`

Pedido del autor (2026-07-24): los sonidos generales de STALKER GAMMA viven ahora en el
framework (`corpus/sound/corpus/`, ordenados por módulo; COR-17 — assets fuera de git) y cada
módulo consume los suyos. Cargo cablea su UI al banco y el trader demo gana una **capa de
persona genérica** para que el addon de contenido le cuelgue a Sidorovich sin que Cargo lo
nombre (mismo espíritu que `Items.SetModel`, entry 34).

- PARCHE 1 — feat(ui): nace `client/corpus_cargo_sounds.lua` (en el manifest tras el theme):
  cues nombrados — `backpack_open/close` para el inventario personal (estado solo),
  `inv_open/close` para loot/trade, `inv_drop` en los dos Send*Drop — más **selección por
  categoría en el clic del grid** (mapa del autor en `sound/corpus/cargo/items/about.txt`:
  sidearm = `wpn`, primary/secondary = `wpnbig` — derivado de `equip_slots` —, y
  ammo/pills/knife/cloth/parts/generic por categoría, variante al azar). TODA ruta pasa por un
  gate `file.Exists` cacheado: sin el banco montado la UI queda MUDA, sin errores de consola
  (detección, nunca asunción). Reemplaza los `backpack/inv_*.wav` que apuntaban a un addon
  externo que el ecosistema no trae.
- PARCHE 2 — feat(trade): **capa persona** — `Trade.SetDefaultPersona/GetDefaultPersona`
  (shared: perfil cosmético `{name, model, idles, radius, wait_interval, sounds}` que registra
  un addon de contenido; rutas PRE-filtradas por el registrador) + callbacks genéricos de evento
  en el server: `OnTradeOpened` al abrir sesión, `OnTradeDealt` al cerrar trato, `OnTradeClosed`
  al cerrar pantalla — el contrato es el nombre del método; cualquier entity trader puede
  definirlos (Cortex incluido, mañana). El bloque CONTRACT del init y el CLAUDE.md reflejan.
- PARCHE 3 — feat(trade): la entity demo implementa la persona: modelo por persona (la cadena
  sidor.mdl → citizen queda como fallback), **idles de plaza del citizen HL2 rotados**
  (plazaidle1-4 / lineidle01-03, filtrados por `LookupSequence` — un modelo sin el set cae a
  `idle_subtle`, nada rompe) y **voz por proximidad** server-side (`CHAN_VOICE`: una línea pisa
  a la anterior; gap ambiental 2,5 s): saludo al entrar al radio (primera vez por sesión =
  línea propia), línea de espera cada `wait_interval` parado sin comerciar (nunca con la
  pantalla abierta; el reloj rearma al cerrarla), despedida al salir (histéresis del 15% para
  no farmear el borde) y las líneas de trade forzadas en sus eventos. Sin persona: citizen mudo
  en idles, como siempre. El nombre del trader sale de la persona — `"Trader (demo)"` sin ella
  (deja de decir "Sidorovich (demo)" hardcodeado: menos Zona en Cargo, no más).

Verificación offline: los 9 archivos tocados compilan (lupa; el harness no cubre client-UI ni
entities). EN JUEGO (checklist del autor):
(a) tecla I abre/cierra con foley de mochila; crate y trader abren/cierran con inv_open/close;
(b) el clic en ítems del grid suena por categoría (pistola ≠ rifle ≠ munición ≠ venda ≠ ropa);
(c) Drop del menú contextual (grid y slots) suena inv_drop;
(d) CON corpus-stalker: el trader saluda al acercarse (línea distinta la primera vez), rezonga
    ~1 min parado sin comerciar, se despide al alejarse, habla al abrir el trading y al cerrar
    un trato, y rota idles de plaza;
(e) SIN corpus-stalker: trader citizen y mudo, idles ok; sin el banco de corpus la UI queda
    muda y la consola limpia.
**Confirmado en juego por el autor el 2026-07-24** (a-e ✓; nota del autor: con corpus-stalker
montado el vodka suena con el banco de Corpus y NO con el sonido original de la Zona — que es
exactamente lo buscado, todo el audio de consumo tira del banco general). Commiteado y pusheado
con autorización del autor.

## 36. Pasada de compat y economía: MTs-255 a slot largo, armas VJ vendibles y sin re-captura, attachments con precio, Quick Loadouts apagado ya no stripea `[APLICADO 2026-07-24]`

Cuatro pedidos del autor (2026-07-24), tres de ellos diagnosticados contra el código vivo de
los mods en `dev/other/` (CRG-24):

- PARCHE 1 — fix(capture): **la MTs-255-12 va a Primary/Secondary, no a Sidearm**. Su
  `SWEP.Class` es la frase EFT "Revolver" (`eft_class_weapon_revol` — es una escopeta de
  acción revólver), y la regla sidearm del clasificador matchea "revolver" ANTES de que la
  SubCategory ("6Shotguns") se consulte. Alta en `Capture.WeaponSlotKinds` (el escape hatch
  existe exactamente para esto): `arc9_eft_mts255 = "long"`. El def autogen se re-registra al
  boot y `ReconcileEquipSlots` saca del Sidearm una ya equipada.
- PARCHE 2 — feat(trade): **precios por FAMILIA** (`Capture.WeaponValuePrefixes` +
  `Capture.WeaponValueFor`, en `weapon_prices.lua`): la entrada exacta del catálogo sigue
  ganando; sin ella, un prefijo precia la familia entera. Primera familia: `weapon_vj_*`
  (VJ Base + todo pack SNPC que siga la convención) a **$200 plano** — armas de NPC que el
  jugador lootea pero rara vez conserva. La captura y el dump dev resuelven por la misma
  función (un arma preciada por familia ya no lista MISSING).
- PARCHE 3 — fix(capture): **el drop de un arma VJ ya no vuelve solo al inventario**
  (roadmap #37, ahora DIAGNOSTICADO): el hook `PlayerCanPickupWeapon` de VJ Base
  (`vj_base/hooks.lua:354`) autoriza CUALQUIER pickup de un arma VJ con menos de 0,15 s de
  vida (ventana `InitTime`, pensada para sus propios gives de NPC) — y en `hook.Call` el
  primer retorno no-nil gana: el world gate nunca llegaba a vetar, la entidad recién dropeada
  a los pies del jugador se aspiraba por contacto al instante, y cada ciclo regalaba munición
  (el `SWEP:Equip` de VJ da `ClipSize*2`, `weapon_vj_base/shared.lua:411`).
  `SpawnWorldWeapon` ahora RETRO-fecha `InitTime` en armas VJ: nacida "en reposo", el propio
  hook de VJ niega el pickup por contacto y el WALK+USE deliberado sigue entrando por su rama
  `KeyPressed(IN_USE)`.
- PARCHE 4 — feat(arc9): **attachments ARC9 con `value = 100`** plano en el registro del
  puente: los mods llenan el grid y necesitaban ruta de venta; número de arranque a calibrar
  en juego, misma regla que las tablas de armas (Cargo_Trade §11).
- PARCHE 5 — fix(capture): **Quick Loadouts con el toggle del cliente apagado ya no stripea
  el equipo persistido en el primer spawn**. El net "disabled" deja `ply.quickloadout = {}`
  (sv:29), que pasa el guard de `QuickLoadout()` (solo chequea nil, sv:62) y ejecuta el
  `StripWeapons + RemoveAllAmmo` incondicional (sv:63-64) SIN dar nada a cambio — y el
  cliente auto-manda ese loadout vacío ~1 s después de `InitPostEntity`
  (`cl_loadoutmenu.lua:1830`), aterrizando el strip sobre las armas recién restauradas. El
  wrapper ahora salta el mod entero con loadout vacío/ausente: nada que entregar = el strip
  no corre (mismo retorno nil, cadena del engine intacta).

Verificación offline: harness ALL GREEN en ambos realms (355 checks). EN JUEGO (checklist):
(a) capturar/equipar la MTs-255-12 → entra en Primary y Secondary, no en Sidearm (una ya
    equipada en Sidearm se va al grid al spawn con notice);
(b) arma VJ (`weapon_vj_*`): se vende al trader por ~$200 × condición × spread; dropearla
    desde el inventario la deja EN EL PISO (sin re-captura ni munición gratis); WALK+USE la
    retoma;
(c) attachments ARC9 listan precio en el trade y se venden a ~$100 base;
(d) con Quick Loadouts montado y su toggle de cliente APAGADO: primer spawn conserva las
    armas equipadas persistidas (y el cinturón no se drena); con el toggle ENCENDIDO el
    loadout sigue entregándose como ítems (entry 32 intacta).
**Confirmado en juego por el autor el 2026-07-24** ("funciona todo bien"), con UN hueco de
seguimiento: las armas VJ del mundo aún se capturaban SIN walk+use y con munición regalada —
diagnóstico y cierre en la entry 37.

## 37. Armas VJ, cierre: el hook de VJ ya no salta el world gate y la munición de pickup se devuelve `[APLICADO 2026-07-24]`

> **NOTA (reemplazo parcial):** el PARCHE 1/2 (re-asiento del hook detrás del gate) lo
> reemplazó la **entry 39** (embebido en el gate — el re-asiento perdía la lotería de orden);
> el PARCHE 3 (clawback del regalo) lo dejó de red la **entry 40** (el regalo se neutraliza
> antes de existir). El retro-fechado de `InitTime` en `SpawnWorldWeapon` y el deny de cadáver
> por `OwnerIsNPC` sobreviven. Se conserva por el registro histórico (no se borra ni renumera).

Reporte del autor (2026-07-24, tras confirmar la entry 36): las armas VJ del mundo seguían
capturándose SIN walk+use, regalando munición en cada captura. Dos causas, ambas contra el
código vivo (CRG-24):

1. **Orden de la cadena**: el `PlayerCanPickupWeapon` de VJ (vj_base/hooks.lua:354) se registra
   en autorun — ANTES del world gate, que Cargo registra en Initialize — y para un arma VJ
   SIEMPRE retorna no-nil: USE a secas mirándola (su rama `KeyPressed(IN_USE)`), el userinfo
   opt-in `vj_wep_autopickup`, o su ventana `InitTime` de 0,15 s. Primer retorno no-nil gana:
   el gate nunca llegaba a vetar (el retro-fechado del PARCHE 3 de la #36 solo cubría NUESTROS
   drops — el resto de las entidades VJ del mundo quedaba en manos del hook de VJ).
2. **El regalo de munición**: el `SWEP:Equip` de VJ (weapon_vj_base/shared.lua:409-415) da
   `ClipSize*2` de reserva (`PickUpAmmoAmount = "Default"` de fábrica) en CADA adquisición del
   jugador — pickups del mundo, gives de loadout Y nuestros propios equips desde el grid
   (`ply:Give` también pasa por `Equip`): equipar↔desequipar un arma VJ farmeaba munición sin
   siquiera dropearla.

- PARCHE 1 — fix(capture): **takeover de ORDEN, no de comportamiento** (mismo movimiento que la
  compat de Quick Loadouts): el hook de VJ se saca de la cadena y se re-registra LA MISMA
  función detrás del gate (`corpus_cargo_vj_pickup_defer`). El gate manda en los casos de
  mundo (arma en reposo → deny, nuestros drops → deny, WALK+USE → grant determinista — de paso
  muere la flakiness del `KeyPressed` de VJ en la retoma); todo lo que el gate abstiene (gives
  frescos, o el gate entero apagado por `cargo_weapon_world_pickup 0`) sigue cayendo en la
  lógica intacta de VJ. Sin el mod: no-op (COR-5).
- PARCHE 2 — fix(capture): **el drop de cadáver de NPC es arma de mundo desde el frame uno**:
  `OwnerIsNPC` queda estampado en la entidad suelta (solo se actualiza con dueño válido,
  `SWEP:OwnerChanged` shared.lua:1011) — el gate lo niega ANTES de la abstención por entidad
  fresca, cerrando el hoover por contacto parado sobre el cadáver (la ventana de 0,15 s de
  VJ). WALK+USE la toma igual (el grant gana primero; deliberadamente incluso con
  `vj_npc_wep_ply_pickup 0` — bajo Cargo la toma deliberada rige las armas de mundo).
- PARCHE 3 — fix(capture): **clawback del regalo**: en el `WeaponEquip`, para armas VJ no-melee
  se re-calcula el monto exacto del regalo (`"Default"` → ClipSize*2; número → ese número) y se
  lo remueve un tick después (a prueba del orden Equip↔WeaponEquip; si un tick del espejo 4 Hz
  se cuela en el medio, la baja del pool se lee como consumo y el cinturón re-drena — consistente
  igual). Programado ANTES del fast-path de `CargoEquipGive` a propósito: nuestros gives también
  reciben el regalo. Sin éter, misma regla que los takeovers de ammo de ARC9 y QL.

Verificación offline: harness ALL GREEN en ambos realms. EN JUEGO (checklist):
(a) arma VJ en reposo en el mundo: tocarla o apretar E a secas NO la captura (E a secas la
    carga como prop HL2); WALK+USE la captura;
(b) matar un NPC VJ parado encima: su arma NO entra sola al inventario; WALK+USE la toma;
(c) equipar↔desequipar un arma VJ del grid repetidas veces NO acumula munición en el cinturón;
    capturarla del mundo tampoco;
(d) con `vj_wep_autopickup 1` puesto por el cliente: el hoover sigue muerto mientras
    `cargo_weapon_world_pickup 1` (Cargo manda en el mundo);
(e) dar un arma VJ por spawnmenu/loadout sigue entrando al inventario como siempre.
**Parcialmente confirmado en juego el 2026-07-24** ("ahora se pueden botar las armas VJ" ✓);
el mismo reporte destapó el frente de las armas NPC-only → entry 38.

## 38. Armas VJ NPC-only: nunca son ítems, la toma respeta el convar del mod y las ya acuñadas se purgan `[APLICADO 2026-07-24]`

> **NOTA (afinado por la #39):** el deny de NPC-only en la toma WALK+USE de esta entry se
> subió al world gate en la **entry 39** (rechazo por cualquier ruta, no solo WALK+USE). Los
> PARCHES 2 (nunca acuñar) y 3 (purga al spawn) siguen vigentes tal cual.

Reporte del autor (2026-07-24, tras probar la 37): las armas VJ marcadas **`MadeForNPCsOnly`**
("CAG Terrorist Assault Rifle removed! It's made for NPCs only!") entraban al inventario y
seguían regalando munición — botar y re-tomar farmeaba, con spam de chat incluido — y eso con
**"Players Can Pickup Dropped Weapons: OFF"** (`vj_npc_wep_ply_pickup 0`), que la entry 37
pisaba a propósito (decisión revertida: el convar del mod manda).

Diagnóstico contra el código vivo: el `SWEP:Equip` de VJ regala la munición de pickup
(shared.lua:409-415) **ANTES** de auto-borrar el arma NPC-only (:417-420) — y como el borrado
aborta el equip, `WeaponEquip` no llega a disparar: el clawback de la entry 37 (que viaja ahí)
nunca ve ese regalo. La única palanca real es que el pickup NO ocurra.

- PARCHE 1 — fix(capture): la toma WALK+USE **rechaza antes de cualquier pickup**: (a) armas
  `MadeForNPCsOnly` — "That weapon is made for NPCs only." — sin pickup no hay regalo, ni spam,
  ni ítem; (b) armas con `OwnerIsNPC` cuando `vj_npc_wep_ply_pickup = 0` — "Picking up NPC
  weapons is disabled." — la toma deliberada de Cargo ya no pisa la config del mod.
- PARCHE 2 — fix(capture): `WeaponEquip` **nunca acuña** ítem para una clase NPC-only (el
  clawback igual corre para las rutas donde el regalo sí llegó a WeaponEquip); el def autogen
  de una clase NPC-only capturada antes del bloqueo **muere en el boot** (mismo patrón que las
  caras throwable muertas) y `HealOrphanDefs` no lo resucita.
- PARCHE 3 — fix(capture): **purga al spawn** (`PurgeNpcOnlyItems`, junto al heal): todo ítem
  `wpn_*` cuya clase resuelva `MadeForNPCsOnly` se remueve del grid y del equip con notice
  ("N NPC-only weapon(s) removed...") — equiparlos era un loop (la entity se borra, el
  reconcile de 0,1 s re-da, VJ re-borra con spam) y botarlos era la semilla del farmeo. Sin
  sub-slots (los defs autogen de arma no declaran), CRG-9 no aplica.

Verificación offline: harness ALL GREEN en ambos realms. EN JUEGO (checklist):
(a) arma NPC-only en el suelo: WALK+USE la rechaza con notice, sin mensaje de VJ, sin
    munición, sin ítem;
(b) con "Players Can Pickup Dropped Weapons: OFF": el arma normal de un NPC VJ muerto no se
    puede tomar (notice); con ON se lootea como siempre;
(c) al primer spawn, las armas NPC-only que ya estaban en el inventario desaparecen con
    notice, y el cinturón no gana munición por ninguna vía VJ;
(d) las armas VJ normales (weapon_vj_ak47 etc.) siguen: capturables por WALK+USE, vendibles
    a ~$200, drop al piso sin re-captura.
**Verificación en juego 2026-07-24 (4.º reporte): PARCIAL** — el respeto del convar OFF ✓,
pero con el convar ON las NPC-only seguían llegando al Equip de VJ (doble mensaje + flash de
ammo en el HUD de DGL4) y el USE a secas seguía tomando armas VJ normales: el re-asiento de la
entry 37 perdió la lotería de orden de hooks → entry 39.

## 39. VJ, forma final: la lógica de su hook corre EMBEBIDA en el world gate (un solo hook, orden determinista) `[APLICADO 2026-07-24]`

4.º reporte del autor (2026-07-24): con `vj_npc_wep_ply_pickup` ON, (a) tomar un arma NPC-only
mostraba AMBOS mensajes ("[Cargo] That weapon is made for NPCs only." + "MP5 removed! It's
made for NPCs only!") y el HUD de DGL4 flasheaba munición obtenida (el regalo existía un tick
y el clawback lo devolvía — neto cero real, pero el pickup ocurría); (b) las armas VJ normales
se tomaban con USE a secas, cuando debería ser WALK+USE.

Causa raíz: **el orden de `hook.Call` entre hooks DISTINTOS no es orden de inserción** — el
supuesto sobre el que se apoyaba el re-asiento de la entry 37. El hook re-registrado
(`corpus_cargo_vj_pickup_defer`) seguía respondiendo ANTES que `corpus_cargo_world_gate`, y su
rama `KeyPressed(IN_USE)` autorizaba el pickup con el gate mudo. El único orden determinista
es DENTRO de un hook.

- PARCHE 1 — fix(capture): la función de VJ se captura y su registro se remueve (re-asegurado
  idempotente en cada corrida del gate, por si un lua refresh lo re-agrega), y su lógica corre
  **embebida en el world gate** exactamente donde el gate se abstiene: la ventana de give
  (<0,5 s — la regla InitTime de VJ sigue mandando en SUS armas) y el gate apagado por convar
  (`cargo_weapon_world_pickup 0` = comportamiento stock de VJ, desde adentro). El hook
  `corpus_cargo_vj_pickup_defer` de la entry 37 desaparece.
- PARCHE 2 — fix(capture): el deny de **NPC-only sube al gate** (antes vivía solo en la toma
  WALK+USE): un arma `MadeForNPCsOnly` no es tomable por NINGUNA ruta a NINGUNA edad — sin
  pickup no hay regalo de Equip, ni doble mensaje, ni flash fantasma en el HUD. La notice de
  Cargo en WALK+USE se mantiene como único feedback.
- El deny de cadáver (`OwnerIsNPC`) queda verificado contra el drop real: la muerte dropea LA
  MISMA entidad que el NPC sostenía (`DeathWeaponDrop`, npc_vj_human_base/init.lua:4491), así
  que el estampado sobrevive.

Verificación offline: harness ALL GREEN en ambos realms. EN JUEGO (checklist):
(a) arma VJ normal en reposo: USE a secas NO la toma (la carga como prop); WALK+USE sí;
(b) arma NPC-only con el convar ON: ni contacto, ni USE, ni WALK+USE la toman — solo la
    notice de Cargo, sin mensaje de VJ y sin flash de ammo en DGL4;
(c) convar OFF: sigue rechazando armas de NPC con notice (ya confirmado en el 4.º reporte);
(d) gives (spawnmenu, loadout, equipar del grid) siguen entrando normal;
(e) `cargo_weapon_world_pickup 0`: comportamiento stock de VJ (USE toma, autopickup opcional).
**Confirmado en juego por el autor el 2026-07-24** ("funciona bien en todo") con UN residuo
cosmético: el history de DGL4 logueaba "+60 SMG1" en la toma legítima de un arma VJ equipable
— el regalo existía un tick antes del clawback y el popup del engine ya había disparado →
entry 40.

## 40. VJ, el regalo de munición se neutraliza ANTES de existir (adiós al fantasma en el history de DGL4) `[APLICADO 2026-07-24]`

5.º reporte del autor (2026-07-24): todo bien salvo que el HUD de DGL4 aún mostraba en su
history "+60 SMG1" al tomar un arma VJ equipable. Es el costo estructural del enfoque
"regalar → devolver" de la entry 37: el `GiveAmmo(ClipSize*2)` del `SWEP:Equip` de VJ dispara
el **popup de pickup del engine** (sin el arg `hidePopup`), DGL4 loguea el evento, y el
clawback solo netea el número un tick después — el evento ya quedó registrado.

- PARCHE ÚNICO — fix(capture): el regalo se **neutraliza antes de existir**. Todo pickup de
  jugador (touch, USE, y también `ply:Give` — la ruta de loadouts y de nuestros equips) pasa
  por `PlayerCanPickupWeapon` ANTES de que corra el `Equip`, así que el world gate es el choke
  point: para un arma VJ bajo captura activa se le asigna a ESA instancia una **copia propia
  de `Primary`** con `PickUpAmmoAmount = 0` (escribir a través de `wep.Primary` mutaría la
  tabla compartida de la clase — fork por mutación, jamás). El `Equip` de VJ entonces regala 0
  (sin popup, el engine no anuncia dádivas vacías) y el clawback de la entry 37, que lee el
  mismo campo, se vuelve no-op solo — queda como red para rutas exóticas. Con
  `cargo_capture_weapons 0`: regalo stock intacto (Cargo no administra esa economía).

Verificación offline: harness ALL GREEN en ambos realms. EN JUEGO (checklist):
(a) tomar un arma VJ equipable con WALK+USE: NADA en el history de ammo de DGL4, cinturón sin
    cambios (el arma llega con su cargador, como cualquier captura);
(b) equipar↔desequipar un arma VJ del grid: tampoco loguea ni acumula;
(c) con `cargo_capture_weapons 0`: la toma vuelve a regalar munición con popup (stock VJ).
**Confirmado en juego por el autor el 2026-07-24** ("funciona todo bien"). Commiteado y
pusheado con autorización del autor (junto con las entries 36-39 de la misma pasada VJ).

---

## 41. El blob de instancia vive dentro del archivo de su dueño (adiós a `inst_<uid>` y a las huérfanas) `[APLICADO 2026-07-25]`

Medición sobre `data/corpus/cargo/` del autor (2026-07-25, antes de borrarla): **370** archivos
`inst_*.json`, **16** referenciados por el inventario, **0** referencias rotas — **354 huérfanas,
el 95,7%**. El histograma las delata (25 `cargo_dev_pistol`, 25 `cargo_dev_smg`, 20
`cargo_dev_backpack` ≈ 25 sesiones de trader demo): son estado de MUNDO — stock de trader, drops
al suelo, derrames de contenedor— que muere con el mapa y deja el archivo atrás.

**La causa raíz no es la falta de un barredor.** Es que `Instances.Create` escribía el archivo en
el instante de crear la instancia, sin saber ni preguntar si le pertenecía a un jugador o al mapa.
Las 354 no son archivos que se quedaron sin dueño: son archivos que **nunca debieron escribirse**.
Por eso el remedio no es un mark & sweep (necesitaría raíces en disco, se rompería con
`cargo_persistence 0` barriendo el mundo, y dejaría el savegame futuro apuntando a archivos que el
propio GC podría borrar): el remedio es **dejar de escribir**.

- PARCHE 1 — feat(inventory): **el blob no tiene archivo propio; viaja embebido en el archivo de
  su dueño** (CRG-56), bajo `instances = { [uid] = blob }`. `Instances.Create` ya no escribe nada,
  `Get` pierde el fallback a disco (`_live` es la única verdad de runtime, CRG-57), `Save`
  **se elimina** y `Delete` deja de tocar el filesystem — con eso **cierra roadmap #13**: el
  `file.Delete` crudo era la violación declarada de COR-3, y desaparece sin necesitar la primitiva
  `Corpus.Data.Delete` (que sigue siendo deseable y pasa a B2).
- PARCHE 2 — feat(inventory): **walker, render, hidratación, descarte y poda.**
  `Inventory.CollectInstances(rec)` es la primitiva única de alcanzabilidad (grid + equipo +
  sub-slots **recursivos**, con guardia de ciclos; el cinturón se camina igual por si un día deja
  de ser stacks). `SaveRecord` **reconstruye `instances` desde cero** en cada guardado tomando los
  blobs de `_live` **por referencia**: un uid que dejó de estar referenciado (se dropeó, se vendió)
  desaparece del archivo solo, sin borrado explícito y sin barredor — por eso la clase "huérfana"
  ya no puede existir. `GetRecord` hidrata **hacia** `_live` sin copiar: `rec.instances[uid]` y
  `_live[uid]` son **la misma tabla**, que es lo que hace imposible la divergencia que CRG-57
  prohíbe (mismo espíritu que el invariante by-ref COR-7). El `PlayerDisconnected` **poda** los
  uids del dueño: hasta hoy `_live` solo crecía.
- PARCHE 3 — feat(inventory): **degradación honesta** (cita COR-5). Una entrada con `uid` cuyo
  blob no vino en el archivo se **descarta con log** al cargar, en grid y en equipo: un ítem sin
  blob no se renderiza a medias. Mismo trato en el loader de contenedores con `persistKey` —
  un `cont_<key>` guarda entradas, no blobs (ser archivo de dueño es B3), así que sus uids no
  sobreviven un reinicio y se descartan en vez de quedar como fantasmas de peso cero.

**Los cuatro call sites de `Instances.Save`** (el PROMPT de la tanda contaba uno): `StoreClip` y
los dos de sub-slot pierden la línea —los de sub-slot ya terminaban en `Touch`, que es quien
escribe el record—; `SetAmmoGroup`, que era el único que sincronizaba **sin** guardar, pasa a
`Touch` (decisión del autor, 2026-07-25). Con eso todo flujo cumple el "every mutation ends in
Save + Sync + movement refresh" del header del archivo.

**Comportamiento aceptado y declarado** (no es un pendiente): de los 8 call sites de `StoreClip`,
todos terminan en `Touch` salvo el espejo del ammopool y el drop al mundo. En el primero el blob es
del jugador y la escritura llega con el próximo `Touch` —a más tardar en el disconnect o el
ShutDown—; en el segundo el blob es del mundo y no va a disco por diseño. La única pérdida posible
es una mutación de cargador seguida de un crash duro sin ningún `Touch` en el medio; hoy ese mismo
crash ya se lleva el record entero.

**Deuda del CHANGELOG #10 cerrada de paso:** con `cargo_persistence 0` los blobs se escribían
igual (el gate solo cubría el record). Ahora 0 significa que **no se escribe nada**.

Verificación offline: harness **ALL GREEN en ambos realms, 373 checks** (eran 355). Los 18 nuevos
en `TESTS_SERVER`: `Create` no deja rastro en disco · round-trip de un record con un unique en el
grid, uno equipado y un tercero **anidado** en sub-slot, con su condición · identidad **por
referencia** `rec.instances[uid] == Instances._live[uid]` (no igualdad de contenido: es lo que
prueba CRG-57) · mutar el blob vivo se ve en el render · entrada con uid sin blob descartada y
resto del record intacto · dropear el unique y su uid sale del archivo solo · poda de `_live` en
el disconnect. EN JUEGO: planilla **P1-P5** (sección P, la primera de Cargo).
**Confirmado en juego por el autor el 2026-07-25: los cinco checks en PASA.** `cargo_selftest`
76 OK / 0 fallas en realm server; P5 reportado con la frase que cierra el caso — "no hay restos
del ítem que boté".

---

## 42. §12 reescrita: normas del blob-en-su-dueño (CRG-56/57/58) y barrido de la forma vieja `[APLICADO 2026-07-25]`

La entrada 41 cambió la forma en disco; esta le pone las normas y barre los ecos. Hasta hoy §12
eran tres viñetas sin un solo ID: un subsistema entero de persistencia descrito en prosa, que es
exactamente lo que FLU-30 y §7.2 del flujo persiguen — una norma sin ID es una norma que va a
derivar.

- PARCHE 1 — docs(docs): **§12 de `Cargo_Architecture.md` reescrita entera**, acuñando **CRG-56**
  (no existen archivos de instancia, existen archivos de DUEÑO), **CRG-57** (`_live` es la única
  verdad de runtime; el campo `instances` es un render **por referencia**) y **CRG-58** (una
  instancia nunca se referencia desde fuera del archivo de su dueño; el cambio de dueño **muda** el
  blob, destino primero y origen después, porque duplicar es el modo de falla seguro). Las tres
  entran en `corpus/docs/ids.yaml` en el mismo parche (FLU-30), con la letra **P** registrada en
  `familias_excluidas` **antes** de que la planilla la use.
- PARCHE 2 — docs(docs): **CRG-43 enmendada** — `inst_<uid>` sale de la lista de claves del
  namespace, en el CLAUDE.md de Cargo y en la `nota` de su entrada del registro, citando CRG-56
  como el motivo. No se le tocó sede, fuerza ni evidencia.
- PARCHE 3 — docs(docs): **barrido de ratificación** (§7.3, barriendo **por el valor**): el mapa de
  archivos del CLAUDE.md, el header de `corpus_cargo_instances.lua`, el comentario del convar
  `cargo_persistence`, el de `WipeOnDeath`, el estado, y en el roadmap **#13 cerrado** (el
  `file.Delete` ya no existe; la primitiva `Corpus.Data.Delete` sigue siendo deseable y pasa a B2)
  y **#15 recortado** a "loot on death" — el GC de huérfanas deja de ser un pendiente porque la
  clase no existe. En `Cargo_Trade_Arquitectura.md`, el pendiente que queda es **cuándo** se limpia
  un cadáver looteado (adjudicado a Cargo en `Cortex_ContratosEntrantes.md` §3.2), no el GC de
  blobs.

**Lo que esta tanda NO acuña, a propósito:** la norma de que el estado del mundo no va a disco
salvo dueño persistente declarado. B1 ya lo hace de hecho, pero su cláusula de excepción solo tiene
sentido cuando el contenedor persistente sea archivo de dueño — eso es B3, y su ID está
presupuestado ahí en el plan madre. En §12 el punto va redactado como **prosa descriptiva**, sin
SIEMPRE/NUNCA, para no fabricar una norma sin ID (§7.2).

Verificación: checker de IDs (`corpus/.claude/check-ids/corpus_check_ids.ps1`) en verde — las tres
normas nuevas están citadas Y registradas, y la letra P está en `familias_excluidas`. El framework
**no** se toca en código, así que el inciso de FLU-16 (`corpus_estado`, §9 de la arquitectura,
espejo) no se dispara por B1; sí lo hará B2.

---

## 43. Primer consumidor de `Corpus.Data.List`/`Delete`: purga de los `inst_*` legacy, y el catálogo declara su scope `[APLICADO 2026-07-25]`

La entry 41 dejó de **escribir** un archivo por instancia (CRG-56), pero no borró los que ya
estaban: un tercero que venía usando Cargo tiene todavía sus `inst_*` en disco, y no
desaparecen solos. Esta entry es la otra mitad — y le da a las primitivas nuevas del
framework su call site inmediato, en vez de que nazcan `INTENCION`.

- PARCHE 1 — feat(dev): **`cargo_dev_purge_legacy`**, en el kit dev de
  `corpus_cargo_dev.lua` (dentro del bloque `if SERVER then` que ya aloja al resto — server-side
  por construcción). Sin argumento hace **DRY RUN**: cuenta las claves `inst_*` y lista las
  primeras 10 por nombre, sin borrar nada. Con `confirm` borra y reporta el conteo. El dry-run
  es el default **porque el comando borra data del jugador y hoy no tiene gate de admin**
  (CRG-45 sigue esperando la primitiva de permisos de Corpus; no se inventa uno acá). El filtro
  es `^inst_` y **nada más**: `inv_`, `cont_`, `trader_`, `autogen_defs` e `icon_overrides`
  quedan en pie. No hay purga automática al bootear — el barrido silencioso de data ajena es
  exactamente lo que el diseño rechaza: la purga es un comando, con confirmación.
- PARCHE 2 — refactor(capture) + refactor(icons): **los dos archivos de catálogo declaran
  `scope = "config"`** (cita **COR-19**, sede `../../corpus/docs/CORPUS_Architecture.md` §3):
  `autogen_defs` (5 sitios en `corpus_cargo_capture.lua`: 1 Load, 4 Save) e `icon_overrides`
  (2 en el `corpus_cargo_icons.lua` de server). Son config de SERVIDOR —lo que los packs
  montados resultaron ser, más las decisiones de encuadre del editor— y sobreviven a borrar una
  partida. El resto de Cargo (`inv_`, `cont_`, `trader_`) **no se toca**: ya es estado de
  partida y el default lo cubre. Hoy la declaración **no mueve un solo archivo** —los dos
  scopes resuelven a la misma carpeta a propósito—; lo que compra es que el día que las rutas
  se separen, el catálogo no se vaya con la partida borrada.
- PARCHE 3 — docs(docs): **§12 de `Cargo_Architecture.md`** suma el catálogo de servidor como
  categoría propia y el párrafo de la purga legacy; **CRG-43** en el `CLAUDE.md` cita COR-18 y
  COR-19 y marca cuál de sus claves declara scope (sin tocarle sede, fuerza ni evidencia);
  y el **roadmap #13** cierra su coleta — decía que la primitiva "sigue siendo deseable y pasa
  a B2", y ahora existe.

**Lo que esta entry NO hace:** migrar el resto del ecosistema al scope (no es de Cargo
decidirlo), mover un archivo a un layout de perfiles, ni convertir el contenedor persistente
en archivo de dueño de primera clase. Y **no** toca los dos sidecars JSON del caché de íconos
del cliente: quedan como deuda declarada de COR-18 con su motivo (viven en la subcarpeta
`icons/` junto a los PNG que indexan, y la primitiva no direcciona subcarpetas).

Verificación offline: harness **ALL GREEN en ambos realms, 389 checks** (eran 373). Los 16
nuevos en `TESTS_SERVER`: `List` devuelve keys sin `.json` y ordenadas · `List` de un namespace
inexistente devuelve `{}` y nunca `nil` · `Delete` true la primera vez y false la segunda ·
`Load` post-`Delete` nil · `Delete` y `List` rechazan separadores (path traversal) · los dos
scopes resuelven igual · un scope desconocido tira `error()` · el **dry run no borra nada** ·
`confirm` borra **solo** los `inst_*` y deja en pie `inv_`/`cont_`/`trader_` y el catálogo.
EN JUEGO: la purga corrida primero en **dry-run sobre data real** — es lo mínimo irrenunciable
antes de dar la tanda por cerrada. Va en la planilla **T**, que es de **corpus** y no de Cargo:
la tanda es cruzada y su peso está en el framework, así que el autor abrió la primera planilla
del framework en vez de gastar una letra de Cargo (Q/R/S siguen presupuestadas acá).
Checks que tocan a este repo: **T5** (nada de lo viejo cambió), **T6** (el catálogo
`scope=config` sobrevive el reinicio), **T7**/**T8** (la purga en dry run y con `confirm`) y
**T9** (el inventario sobrevive a la purga).
Planilla: https://claude.ai/code/artifact/fc204b66-e751-42a2-af8a-0c02429934bd

**Confirmado en juego por el autor el 2026-07-25.** Los cinco checks que tocan a este repo
pasaron: T5 y T6 limpios ("no he visto nada fuera de lo común"), T8 con "2 de 2 claves `inst_*`
legacy borradas" sobre dos archivos traídos de la papelera a propósito, T9 con el inventario
intacto tras el relog, y T7 —el dry-run— cerrado en la ronda 2. La 1.ª corrida de T7 había
devuelto el atajo `no quedan claves inst_* legacy` porque los archivos todavía no estaban;
quedó anotado acá porque el orden de esa preparación es lo que hace que el check pruebe algo.
El único ✗ de la planilla, T4, es del framework y no de Cargo.

---

## 44. Un solo serializador de dueño: `cont_<key>` gana sus blobs (y el contenedor persistente deja de perder sus uniques) `[APLICADO 2026-07-26]`

B1 dejó **una** rutina de serialización escrita, pero inline dentro del inventario, y **un** archivo
de dueño. Esta entry extrae la rutina y le da el segundo dueño, que es lo que saca a **CRG-58** de
`INTENCION`: hasta hoy la norma "una instancia nunca se referencia desde fuera del archivo de su
dueño" tenía un solo archivo donde ser cierta, y una norma con un solo call site no está probada.

De paso arregla un bug real que la unificación vuelve trivial: **una crate con `persistKey` perdía
sus uniques en cada reinicio.** Guardaba entradas y no blobs, así que el loader se encontraba con
uids sin nada detrás y los descartaba con log. El comentario del propio código lo declaraba —
"a persisted container is NOT an owner file yet ... (that is B3)".

- PARCHE 1 — refactor(inventory): **la rutina única, con el dueño como parámetro.** El render que
  vivía inline en `SaveRecord` y la hidratación que vivía inline en `GetRecord` salen a
  `Instances.RenderOwner(owner)` e `Instances.HydrateOwner(owner)`, en
  `corpus_cargo_instances.lua` y no en el de inventario: son del dueño de los blobs, y el punto de
  la tanda es que el inventario deje de ser su sede. `HydrateOwner` **devuelve el set de uids que
  llegaron**, porque el descarte por degradación honesta se queda en cada llamador — cada dueño
  tiene listas distintas que barrer (el record tiene `equip`, el contenedor no).
  `Inventory.CollectInstances` **no se duplicó ni se parametrizó**: ya era genérico —recorre
  `items`/`equip`/`belt` con un `istable` por cada uno—, así que un contenedor pasa por él sin
  tocarle una línea. Solo cambió el nombre del parámetro, de `rec` a `owner`. Media rutina ya
  estaba escrita.
- PARCHE 2 — feat(containers): **`cont_<key>` es archivo de dueño de primera clase.** `Attach`
  hidrata antes de barrer, `Containers.Save` renderiza antes de escribir, y el archivo pasa a
  llevar `{ items, instances }`. **Se cae el bloque de descarte que existía solo porque el
  contenedor no era dueño**: el descarte por degradación honesta se queda, pero ahora significa lo
  que significa en el inventario — "el archivo vino incompleto", no "los blobs nunca vinieron".
- PARCHE 3 — feat(containers) + refactor(trade): **UN SOLO ESCRITOR de `cont_<key>`.** Hasta hoy
  `SaveContainer` (containers) y `SaveTrader` (trade) escribían **los dos** el mismo archivo, y en
  cuanto uno aprendiera a serializar `instances` y el otro no, el blob se perdía según quién
  guardó último. `SaveContainer` pasa a ser público (`Containers.Save`) y es el único que toca
  `cont_`; `SaveTrader` lo llama y persiste **solo su wallet**.
- PARCHE 4 — feat(dev): **`cargo_dev_persist_key`**, convar de servidor, vacía por default.
  Ninguna entidad del módulo declaraba un `persistKey`, así que la ruta del dueño persistente
  —lo que esta entry construye— **no tenía forma de ejercerse en juego**. Con la convar puesta, la
  crate y el trader demo la adoptan, cada uno con su sufijo (`<key>_crate`, `<key>_trader`) para
  no compartir archivo. Vacía, todo sigue siendo de sesión exactamente como antes. Sin gate de
  admin, como el resto del kit dev (CRG-45). Limitación declarada: **dos crates comparten la clave**
  — de a una por vez.

**Decisión del autor tomada en la ejecución (§4.0 del PROMPT): el wallet del trader NO se muda
adentro de `cont_<key>`.** Se queda en `trader_<key>`, por **CRG-21**: un trader es el contenedor
**más una capa de precio**, y fundir el dinero en el primitivo de storage metería economía dentro
de lo que mañana reusan el alijo y el cadáver de Cortex. Lo que sí era innegociable en cualquiera
de las dos formas es el escritor único, y eso es el PARCHE 3.

**CRG-59 acuñada** — "El estado del mundo no va a disco salvo dueño persistente declarado
(`persistKey`)". Sede: `Cargo_Architecture.md` §12. La entry 42 se abstuvo de acuñarla a propósito
para no fabricar una norma sin call site: recién ahora el dueño persistente declarado guarda algo
**distinto** de lo que guarda el efímero, y la cláusula de excepción tiene sentido.

**Lo que NO se unificó, y hay que decirlo:** los remaps de `LegacyThrowIds` y de slots viejos. Son
migraciones de **forma** del record, no serialización, y el contenedor tiene su propia versión
recortada. Meterlos en la rutina común haría que un `cont_` empiece a correr remaps de `equip`, que
no tiene.

Verificación offline: harness **ALL GREEN en ambos realms, 418 checks** (eran 393). **Los 393 de
B2 siguieron verdes sin tocar uno solo durante el PARCHE 1** — era el criterio: un refactor puro que
obligue a cambiar un check cambió comportamiento. Los 25 nuevos en `TESTS_SERVER`, sección B3: la
rutina corre sobre un dueño que solo tiene `items` y embebe por referencia · `HydrateOwner` devuelve
el set que llegó · `cont_<key>` lleva `instances` en disco · **el unique sobrevive un reinicio
completo del runtime con su condición** (el bug, medido offline) · un contenedor sin `persistKey` no
escribe un solo archivo (CRG-59) · la entrada cuyo blob no vino se descarta y el stack de al lado
queda · el guardado **por el trader** también escribe `instances` · el wallet está en `trader_<key>`
y **no** dentro del contenedor · la convar dev da claves distintas a crate y trader.
EN JUEGO: planilla **Q** (ver entry 45, que comparte la pasada).

---

## 45. La entidad sin referencias vivas encima (saneo del duplicator) `[APLICADO 2026-07-26]`

`duplicator.CopyEntTable` hace `table.Merge(data, ent:GetTable())` quitando **solo las funciones**.
Y la entidad llevaba encima una Entity y un set con Players de clave, **dos veces**:

    ent.CargoContainer = { id, ent = <Entity>, name, capacity, persistKey, items,
                           viewers = { [Player] = true } }
    ent.CargoTrader    = { cont = <la tabla de arriba>, ent = <Entity>, name, buyMult,
                           sellMult, money, persistKey, viewers = { [Player] = true } }

Todo eso entraba a cualquier duplicación y a cualquier savegame. Es **saneo, no feature**, y va
acá y no en el bloque del savegame porque ese bloque depende de que esté hecho: no se puede
escribir un blob controlado en `PreEntityCopy` mientras el merge crudo arrastra basura por detrás.

- PARCHE 1 — refactor(containers): **la entidad guarda estado plano y nada más.** Las referencias
  vivas se mudan a `Containers._live[id] = { ent, viewers }`, indexadas por el id de sesión que ya
  existía. Los cinco call sites de `containers.lua` (`ViewedContainer`, `SyncViewers`, `OpenFor`,
  el `CallOnRemove`, el hook de `PlayerDisconnected`) pasan por ahí. `_live` significa lo mismo que
  en `Instances._live`: la mitad que solo existe en runtime y nunca llega a disco.
- PARCHE 2 — refactor(trade): **lo mismo para el trader**, que además soltó la **tabla del
  contenedor embebida** — arrastraba el stock entero y su propia mitad viva. Guarda el `contId` y
  lo resuelve por `_byId`.
- PARCHE 3 — feat(trade): **la API pública que reemplaza los campos que se fueron**:
  `Trade.StockOf(trader)` (la lista del contenedor, por referencia), `Trade.HasViewer(trader, ply)`
  y `Trade.ClearViewers(trader)`, más `Containers.EntityOf(cont)` para el camino de vuelta. Sin
  ellas, un consumidor de afuera tendría que leer `Containers._byId`, que es tabla privada: la
  dependencia no desaparecía, se disfrazaba.
- PARCHE 4 — refactor(trade): **el trader demo también estaba sucio, y el PROMPT no lo enumeraba.**
  `ENT.CargoVoice` era un set `{ [Player] = { waitNext } }` viviendo directo sobre la entidad —
  exactamente la misma clase de basura que `viewers`. Pasa a indexarse por SteamID64, que es dato
  plano (`CargoGreeted` ya lo hacía). La poda cambia de "borrar los Player inválidos" a "borrar a
  los que se desconectaron", para que morir cerca del trader no vuelva a disparar el saludo.

**Alternativa rechazada, y conviene dejar dicho por qué:** limpiar en un `PreEntityCopy` que borre
los campos sucios. Es un parche en el punto de salida —cualquier otra ruta que lea `ent:GetTable()`
sigue viendo la Entity y los Players— y además es exactamente el gancho que el bloque del savegame
necesita libre para escribir SU blob. Se arregla la forma, no el síntoma.

**Decisión del autor (§5.2 del PROMPT): mudanza completa ahora**, contenedor y trader juntos, no
solo el trader. CRG-21 dice que son el MISMO primitivo, y sanear la mitad deja la puerta abierta por
donde el duplicator ya entra. El costo es que toca superficie ya verificada en juego (el slice 1 del
comercio), y por eso la planilla Q lleva un check de verificación negativa.

**Rompió un repo hermano, y se arregló en la misma tanda (2.ª decisión del autor, §7.5 disparado).**
`corpus-stalker` no estaba entre las raíces declaradas del PROMPT, pero su NextBot de Sidorovich
—confirmado en juego y pusheado— leía `trader.cont.items` en `OnKilled` para borrar el stock y
`trader.viewers` en dos lugares: con la forma nueva eso es un `index a nil value` que se lleva
puestos el ragdoll y el respawn. Pasa a la API del PARCHE 3, y de paso su `SidorVoz` —el mismo
set indexado por Player— se sanea igual. Ver el CHANGELOG de ese repo.

Verificación offline: incluida en los 418 del harness. Los checks de forma: `ent.CargoContainer` sin
`ent` ni `viewers` · `ent.CargoTrader` sin `ent`, sin `viewers` y sin `cont` · las referencias vivas
están en `_live` indexadas por el id de sesión · el camino de vuelta `cont -> entidad` existe · la
API pública devuelve la lista del contenedor **por referencia**.

**EN JUEGO — planilla `Q`** (sección nueva de la planilla de CARGO; la de B1 es la P, y la T es de
corpus, otra planilla). Comparte pasada con la entry 44:

- **Q1** · crate con `persistKey` sobrevive un reinicio **con su unique y su condición intactos** —
  es el bug que la tanda arregla, y hoy FALLA. **Preparación primero:** `cargo_dev_persist_key q1`
  ANTES de spawnear la crate. Si al terminar **no existe `data/corpus/cargo/cont_q1_crate.json`**,
  la preparación no se hizo y el check NO corrió — no se marca PASA.
- **Q2** · trader sin `persistKey` re-siembra stock en un mapa nuevo (verifica D1). Preparación:
  `cargo_dev_persist_key ""` (vacía, que es el default).
- **Q3** · `gm_save` con una crate spawneada no corrompe el save — canario del bloque siguiente,
  medido acá: si la entidad quedó sucia, se ve en este check.
- **Q4** · el slice 1 del comercio sigue igual (comprar, vender, basket) — **verificación negativa**
  del saneo, que toca su superficie. Con Sidorovich montado, corre sobre él: es el trader que el
  autor usa de verdad.
- **Q5** · Sidorovich muere, deja ragdoll y respawnea — es el arreglo del repo hermano, y va como
  check propio y no dentro de Q4: bundlear "el comercio sigue igual" con "matarlo" haría que un
  solo PASA cubra dos cosas que fallan por motivos distintos, que es exactamente lo que la lección
  de la sección T persigue. Señal de que el fix no está cargado: `attempt to index a nil value`
  dentro de `OnKilled`.

La letra **Q** se registra en `familias_excluidas` en el mismo parche, ANTES de usarse (FLU-30), y
no se recicla (FLU-07). Planilla (sección nueva de la de Cargo, la misma URL que la P):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

### Ronda 1 de la planilla Q (2026-07-26): Q2/Q4/Q5 PASA, Q1 y Q3 destapan dos defectos

Los dos salieron del **campo de notas**, no del estado: Q1 vino marcado PASA y su nota describía
el fallo. Es la tercera vez que pasa (la sección T lo pagó dos veces) — un ✓ se adjudica abriendo
la evidencia, y acá la evidencia era el JSON pegado y la frase «no mostraban los iconos».

- PARCHE 5 — fix(items) + fix(containers) + fix(trade): **el snapshot del contenedor y el del
  trader no llevaban los defs autogen.** Reporte de Q1: la crate persistente devolvió sus dos
  armas —los blobs viajaron bien, el JSON lo prueba— pero se dibujaban como **celda 1×1 muda**,
  mientras la munición dev al lado se veía perfecta. Causa: los defs de armas capturadas se
  acuñan **server-side** (`capture.lua` es de server) y el cliente los aprende del snapshot que
  se los trae. `BuildSnapshot` del inventario lo hacía inline —su propio comentario lo declara—;
  el contenedor y el trader, no. Con la def en nil, `grid.lua` PaintCell corta antes de dibujar y
  `Icons.GetFootprint` cae a `{w=1,h=1}`: los dos síntomas, una sola causa. Se extrae a rutina
  única —`Items.PackDefs(snap, entries)` del lado server, `Items.AbsorbDefs(snap)` del lado
  cliente— y la usan los **tres** snapshots. La munición dev se veía porque es def **shared**,
  registrada en ambos realms; por eso el defecto era invisible mientras el stock de los traders
  demo fuera del kit dev.
  **Por qué aparece recién ahora:** hasta esta tanda una crate persistente no podía devolver un
  unique —se descartaba— así que ese cuadro no tenía cómo dibujarse. El defecto es viejo; lo
  alcanzable es nuevo.
- PARCHE 6 — fix(containers) + fix(trade): **el marcador de attach sobrevive al savegame y
  bloqueaba el re-attach.** Reporte de Q3, con `gm_load` corrido **desde el menú** (por consola
  no carga, ver abajo): la crate y el trader volvieron **inservibles**, sin responder al USE.
  `ent.CargoContainer` es dato plano, y dato plano colgado de una entidad es exactamente lo que
  un savegame restaura. El marcador vuelve nombrando un id de sesión que murió con el mapa:
  `Attach` retornaba temprano por él, devolviendo un contenedor que no está en ningún registro, y
  `OpenFor` no encontraba su mitad viva. Ahora la pregunta «¿ya está attacheado?» **la contesta
  `_live`, no el campo** — y exige además que la entidad coincida, porque un id muerto puede
  COLISIONAR con uno que esta sesión ya acuñó (sin eso, la crate abriría el contenido de otra).
  Marcador que no valida: se descarta y se attachea de cero. Las entradas que traía **no se
  heredan**: sus instancias murieron con el mapa, y heredarlas fabricaría justo los fantasmas sin
  blob que la degradación honesta descarta. Restaurar contenido de verdad es del bloque del
  savegame.
  Es **regresión de esta tanda**: antes del saneo el marcador volvía con una Entity muerta y el
  panel abría igual (roto de otra forma, pero abría). Q3 existía como canario y funcionó —
  destapó lo contrario de lo que buscaba: la entidad quedó limpia, y lo que estorba es el
  marcador que el duplicator devuelve.

**Los checks nuevos se verificaron en negativo**, revirtiendo cada arreglo y confirmando que el
check se pone rojo: sin ellos, un check que nunca falló no prueba nada (lección de la sección T).
Harness **425** (eran 418).

### Ronda 2 (2026-07-26): Q1 cierra, Q3 destapa el gemelo del PARCHE 6 en la entidad de al lado

Q1 volvió **PASA limpio** — «funcionó correctamente el render, no hay problemas en ningún arma o
ítem». El PARCHE 5 quedó confirmado en juego. Q3 quedó a medias, y otra vez lo dijo la nota:
la **crate** ya abre (el PARCHE 6 hizo su trabajo) y vuelve vacía, que es lo declarado —restaurar
contenido es del bloque del savegame—, pero **el trader no respondía al USE**, además de «hablar
infinitamente» y quedar con la cara deformada.

No es de Cargo, pero **es exactamente el mismo defecto** y merece quedar anotado acá porque el
PARCHE 6 solo cubrió la mitad del problema: `ent.CargoContainer` era dato plano que el savegame
devolvía, y los **sellos de tiempo** de la entidad de Sidorovich también lo son. `CurTime()` arranca
de cero al cargar el mapa, así que un plazo heredado queda en el futuro para siempre: su candado
anti doble-USE nunca vencía. Arreglado del lado de `corpus-stalker` (su CHANGELOG, PARCHE 4 de la
tanda del 2026-07-26), reiniciando el estado de sesión entero en `Initialize` — el único punto que
corre tanto en un spawn nuevo como en una entidad que devuelve un savegame.

**La regla que sale de las dos mitades, y que el bloque del savegame hereda:** dato plano encima de
una entidad es lo que un savegame trae de vuelta. Un id de sesión, un plazo de `CurTime()` y una
marca de estado de partida son todos sospechosos, no continuidad. Lo que el bloque siguiente
escriba en `PreEntityCopy` tiene que nacer sabiendo esto.

### Ronda 3 (2026-07-26): el arreglo del vecino estaba en el lugar equivocado, y eso enseñó DÓNDE va

Q3 volvió por tercera vez con los tres síntomas del trader **intactos**, con foto. El arreglo del
lado de `corpus-stalker` reiniciaba el estado en `Initialize`, y **ese fallo es la evidencia**: si
el reinicio hubiese quedado en pie, poner el candado de USE en cero habría destrabado el USE. No lo
destrabó, así que **el duplicator escribe los campos planos DESPUÉS del constructor** y pisa
cualquier reinicio hecho al nacer.

El contraste dentro de la misma ronda es la lección, y por eso queda escrita acá y no solo en el
repo vecino: **la crate sí se arregló a la primera.** La diferencia no era el defecto —era el mismo—
sino dónde vivía el remedio. El PARCHE 6 **valida al leer** (`_live` manda, el campo no) y por eso
es indiferente al orden; el del vecino **reiniciaba al nacer** y dependía de un orden que nadie
controla. Reescrito con un **sello de sesión** verificado en cada lectura, que es la misma forma.

- PARCHE 7 — fix(trade): **el trader demo de Cargo tenía el defecto latente y se sanea igual.**
  No dio la cara porque no tiene flexes ni candado de USE —sus síntomas serían quedarse mudo y con
  el idle congelado—, pero su `Initialize` reiniciaba la contabilidad de voz exactamente igual de
  tarde. Mismo sello, verificado en `CargoSpeak`, `CargoVoiceThink` y `Think`. Se arregla acá y no
  cuando alguien lo reporte, porque la causa ya está probada en la entidad de al lado.

**Lo que esto le deja al bloque del savegame, y vale más que los dos parches:** el estado que una
entidad necesita entre partidas no se puede dejar colgado en campos planos esperando que alguien lo
reinicie a tiempo. O se valida al leer, o se escribe y se lee por el gancho del duplicator. La
cadena `PreEntityCopy` → `PostEntityPaste` nace con esta restricción medida en juego, no supuesta.

### Ronda 4 (2026-07-26): el USE vuelve, y la cara resulta ser una división entre negativos

El sello de sesión devolvió **el USE y el comercio** — «ahora se le puede hablar y tradear». Quedó la
cara, y esta vez el reporte trajo una foto de dos Sidorovich lado a lado, el cargado deforme y el
recién spawneado perfecto: la comparación aisló el defecto sin ambigüedad.

Se arregló del lado de `corpus-stalker` (su CHANGELOG, PARCHE 6) y **no era el sello, era una
fórmula**: el parpadeo interpola un triángulo que da por sentado que su `t` es positivo, y con un
sello de tiempo heredado `t` sale negativo, entra igual en la rama y el peso del flex se va a
**-5500**. Los vértices salen disparados por el lado negativo del morph. Dos remedios: clamp del
peso —para que ningún `t` imposible pueda deformar— y cerar todos los flexes al reiniciar sesión,
porque un morph que quedó movido no lo endereza nadie: el código solo reescribe los índices que
conoce.

**El patrón que dejan las cuatro rondas, y que conviene tener a mano en el bloque siguiente:**
un valor heredado de otra sesión no rompe donde se guarda, rompe **donde se usa en una cuenta**. El
id de sesión rompió una búsqueda en un registro; el plazo de `CurTime()` rompió una comparación; el
mismo plazo rompió una interpolación y la volvió negativa. Los tres se veían distinto y eran lo
mismo. Al escribir `PostEntityPaste`, la pregunta no es «¿qué campos restauro?» sino **«¿qué cuentas
hacen estos campos, y aguantan un valor de otra partida?»**.

### Ronda 5 (2026-07-26): el clamp tapaba, y la lección final sobre en qué apoyarse

«Arreglaron los flexes deformes, **pero no parpadea**, la boca nace hablando pero al decir algo se
arregla». Ese cuadro es un diagnóstico entero: el plazo heredado **seguía ahí**, y el clamp de la
ronda anterior no lo había arreglado —lo había **silenciado**. Con el plazo de otra partida, la
interpolación del parpadeo da siempre negativo: sin clamp eso era -5500 (cara estirada), con clamp
es 0 **para siempre**, o sea sin parpadeo. Un síntoma visible convertido en uno callado, que es la
peor clase de arreglo.

Cerrado del lado de `corpus-stalker` (su CHANGELOG, PARCHE 7) con un **segundo candado por VALOR**:
cada plazo se compara contra la cota exacta de la línea que lo escribe, y ninguno puede superarla
dentro de una sesión porque el tiempo solo avanza. No le pregunta nada al duplicator.

**La lección que este bloque le pasa al del savegame, y es la más cara de las cinco rondas:** hubo
tres intentos apoyados en *cuándo* corre el código —reiniciar en el constructor, sellar la sesión,
acotar el resultado— y los tres fallaron o taparon, porque el orden en que el duplicator escribe no
está bajo nuestro control y no se puede observar desde afuera del juego. El que funcionó se apoya en
*qué valores son posibles*, que no depende de nadie. **Cuando el orden no es observable, el
invariante tiene que ser de valor, no de momento.** El contenedor ya lo hacía sin que nadie lo
dijera —`Containers.Attach` pregunta si el id está vivo, no cuándo llegó— y por eso fue el único que
salió bien a la primera.

### Cierre

**Confirmado en juego por el autor el 2026-07-26: planilla `Q` en 5/5, tras seis rondas.**
Q1 (la crate persistente conserva su unique, con su ícono y su footprint), Q2 (el trader efímero
re-siembra en un mapa nuevo — verifica D1), Q3 (`gm_save`/`gm_load` deja crate y trader usables, con
la cara del NextBot neutra y parpadeando), Q4 (el slice 1 del comercio intacto) y Q5 (Sidorovich
muere, deja ragdoll y respawnea). Harness offline **425 verdes** en ambos realms, checker de IDs
limpio, espejo regenerado.

**Las cinco rondas no fueron ruido: tres de los cinco defectos de esta tanda no los encontró ningún
check, los encontró el CAMPO DE NOTAS de checks marcados PASA.** El estado decía verde y la nota
decía qué estaba roto. Vale como método, no como anécdota — la planilla se lee entera, empezando por
las notas.
Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

**Hallazgo que cambia las premisas del bloque siguiente, anotado y NO resuelto acá:** `gm_load`
**no funciona desde la consola** en la instalación del autor —el menú SAVES sí—, y el autor
descartó que fueran sus addons apagándolos todos. El bloque del savegame es el que estrena esa
cadena: su PROMPT no puede escribirse asumiendo que `gm_load <nombre>` es una ruta de
verificación. Va por el menú, y eso hay que decirlo en su planilla.

---

## 46. El savegame de GMod: el estado plano de la entidad ES el blob, y vuelve con uid nuevo `[APLICADO 2026-07-26]`

`gm_save` copia la entidad con `duplicator.CopyEnts`, que mergea `ent:GetTable()` entero; `gm_load`
se la devuelve con esos campos puestos. La entry 45 dejó ese estado plano **limpio** y la 44 lo dejó
**serializable por la rutina del dueño**. Esta entry junta las dos mitades: hasta hoy la crate volvía
del save **usable y vacía** (el PARCHE 6 de la 45 arregló lo primero y declaró lo segundo como trabajo
de este bloque); al terminar vuelve usable y **con su loot**.

- PARCHE 1 — feat(inventory): **`Instances.Remint(entries, blobs)`**, el re-acuñado. Un blob que llega
  de otra sesión se **crea de nuevo con uid NUEVO** y las entradas se reescriben. El uid es único por
  boot y no globalmente (misma razón que el re-uid del import de B5): reusar el guardado es una
  colisión esperando ocurrir. Es **recursivo** —un chaleco trae sus placas en `subslots` y esas
  entradas también nombran uids— y aplica la degradación honesta de los dos archivos de dueño (cita
  COR-5): la entrada cuyo blob no viajó, o cuya def este boot no conoce (un pack desmontado), se
  descarta con log en vez de volver como fantasma sin peso. Al lado, `Instances.RenderEntry(entry)`
  para el dueño de UNA sola entrada, que es lo que es un drop de mundo.
- PARCHE 2 — feat(containers): **`Containers.Save` renderiza SIEMPRE**, persistente o no. Es la línea
  que hace que el marcador plano de la entidad sea un dueño autocontenido *en todo momento*, que es
  exactamente lo que el savegame se lleva. Escribir a disco sigue gobernado por **CRG-59** (el `return`
  por `persistKey` quedó donde estaba, un renglón más abajo). Y **`Attach` adopta lo que el marcador
  muerto traía**: lo re-acuña y **reemplaza** la lista de items.
- PARCHE 3 — feat(trade): **la capa de precio también vuelve.** El stock ya vuelve por el contenedor
  (CRG-21: un trader es ese contenedor más precio), así que lo único que le queda a esta capa es el
  **wallet**, que viaja en el marcador plano y le gana al `opts` y al archivo. Y el stock recién
  sembrado se **renderiza al sembrarse**: sin eso, guardar la partida antes de la primera compra se
  llevaba entradas sin blob, que al cargar son justo los fantasmas que la degradación honesta descarta.
- PARCHE 4 — feat(containers): **el drop de mundo, por las dos rutas que existen.** La entidad de ítem
  (`corpus_cargo_item.lua`) lleva su blob al lado de la entrada y lo re-acuña al leer; y el **arma
  tirada**, que no es esa entidad sino el SWEP real con `CargoInstanceUid`, hace lo mismo en
  `capture.lua`. Sin la segunda, un arma soltada, guardada y recargada se recogía como ítem de fábrica
  —sin condición, sin attachments y sin el cargador guardado—, que es el drop que el autor usa de
  verdad. El PROMPT solo enumeraba la primera.

**DECISIÓN DE DISEÑO, y es la que se aparta del PROMPT: no hay `PreEntityCopy`.** El PROMPT pedía
escribir un blob propio en ese gancho. El árbol ofrece algo mejor y la entry 45 lo dejó servido: el
estado plano YA viaja y YA está limpio, así que alcanza con que esté **completo**. El argumento es el
mismo que la 45 usó para rechazar limpiar la basura ahí, leído al derecho — un blob que solo es
correcto adentro del gancho de copia está mal en cualquier otra ruta que lea `ent:GetTable()` (la
herramienta de duplicado, un sistema de saves de terceros). Y compra algo que la forma del PROMPT no
podía: **la restauración vive en `Containers.Attach`, la única puerta del primitivo**, así que toda
entidad que se vuelve contenedor la hereda —la crate demo, el trader demo, el **Sidorovich de
`corpus-stalker`** y mañana el cadáver de Cortex— sin una línea propia y **sin cuarta raíz**. El único
`PostEntityPaste` del bloque es el del drop de mundo, y ni siquiera él depende de correr: la toma
ejecuta la misma rutina.

**El invariante es de VALOR, no de momento** — la lección cara de las seis rondas de la planilla Q, y
acá se respeta en cada línea. Nada pregunta cuándo el duplicator escribió los campos: se pregunta si
el dato es **posible en esta sesión** (un id de contenedor que no está vivo, un uid que no está en
`_live`). Por eso restaurar **reemplaza** y nunca acumula: correrlo tarde, dos veces, o después de que
algo ya leyó la entidad da el mismo resultado, y hay un check offline que lo prueba.

**Lo que la cadena del engine puede y no puede afirmarse (cita CRG-24).** `gm_save` → `gmsave.SaveMap`
→ `duplicator.CopyEnts` → `engine.WriteSave`, y al cargar `duplicator.Paste` → `PostEntityPaste`, se
verificó contra la wiki y `Facepunch/garrysmod`, **no contra una copia local** — no hay fuente de
garrysmod en `dev/other/`. Lo que sí está **medido en juego** es la única premisa de la que este
diseño depende: los campos planos de la entidad vuelven del savegame (es lo que rompió el USE en la
ronda 1 de Q) y vuelven **después** del constructor (rondas 3 a 5). El orden de `PreEntityCopy`
respecto del merge no hace falta afirmarlo, porque nada acá lo usa.

Verificación offline: harness **443** (eran 425), 18 checks nuevos, **los 425 anteriores intactos
salvo uno** — el de la 45 que afirmaba que el wallet del marcador muerto se ignora. Ese comportamiento
lo **invierte esta entry a propósito** (CRG-60), así que el check se partió: la mitad que probaba lo
que ese bloque probaba de verdad —que el contenedor vivo no se secuestra— se queda donde estaba, y la
del wallet se reescribió en la sección B4. **Los 18 se verificaron EN NEGATIVO**, revirtiendo cada
arreglo y confirmando el rojo. Hallazgo de paso: **al harness le faltaba `table.Merge`**, así que
`Instances.Create(id, seed)` nunca se había ejercido con seed offline desde B1; el stub se agregó con
la semántica de GMod.

**Lo que el harness NO cubre, y hay que decirlo:** todo lo de `lua/entities/` — el drop de mundo lo
carga el sistema de scripted_ents del engine, no el manifest. De ese archivo se apoya en tests la
mitad de módulo que llama (`RenderEntry` / `Remint`); el resto va a la pasada del autor.

EN JUEGO: planilla **R** (ver entry 47, que comparte la pasada).

---

## 47. CRG-60 acuñada: el savegame guarda el MUNDO, no al jugador `[APLICADO 2026-07-26]`

La mitad contraintuitiva del bloque, y la que sin norma escrita se reporta como bug.

**CRG-60 acuñada** — "El savegame guarda el **MUNDO**, no al jugador: el inventario del jugador no
retrocede al cargar una partida". Sede: `Cargo_Architecture.md` §12. Es la **contrapartida declarada**
de que el inventario sea por SteamID64 y sin noción de mapa (**CRG-43**): cruza de nivel en nivel *y*
de partida en partida. No hay línea de código que lo implemente y ése es el punto — el record no es
una entidad, así que no viaja por la cadena del duplicator salvo que alguien lo meta a propósito;
lo que la norma hace es que nadie lo meta y que el tester sepa qué esperar.

§12 se reescribe con las cuatro cosas que este bloque decidió: cómo viaja el blob (el estado plano de
la entidad **es** el blob) y por qué no hay un gancho que lo escriba; el re-acuñado con uid nuevo; el
invariante de valor; y la resolución de la discrepancia entre el savegame y el archivo de dueño.

**Decisión del autor, tomada ANTES de escribir código (§5.2 del PROMPT): cuando un contenedor con
`persistKey` tiene dos fuentes, MANDA EL SAVEGAME.** El argumento que decidió no fue el de coherencia
narrativa sino que el árbol ya había clasificado esos archivos: `cont_<key>` y `trader_<key>` declaran
scope `save` —estado de partida, muere al borrar una partida (**COR-19**)— y el layout objetivo de
perfiles los pone bajo `saves/<perfil>/maps/<mapa>/`. La opción contraria los trataba como config de
servidor, que es la OTRA categoría de COR-19, y habría que sacarlos de `saves/`. El archivo se
**reconcilia** con lo que ganó, para que la próxima transferencia no escriba un estado mezclado.

La letra **R** se registra en `familias_excluidas` en el mismo parche, ANTES de usarse (FLU-30), y no
se recicla (FLU-07).

**EN JUEGO — planilla `R`** (sección nueva de la planilla de CARGO; la de B1 es la P, la de B3 la Q, y
la T es de corpus, otra planilla). **Todos los checks que carguen una partida lo hacen POR EL MENÚ**
(hallazgo medido en la ronda 6 de Q: `gm_load` no carga desde la consola en la instalación del autor;
`gm_save <nombre>` por consola sí funciona):

- **R1** · una crate con loot sobrevive `save`/`load` **con sus condiciones intactas**. Preparación:
  meterle un ÚNICO capturado (no del kit dev) y **anotar su condición ANTES de guardar**. Señal de que
  el check no corrió: si al cargar la crate no existe, el save no la incluyó.
- **R2** · un trader con stock mermado y wallet gastado sobrevive el ciclo: se le compra algo, se
  guarda, se carga, y **ni el stock ni el dinero vuelven al estado inicial**.
- **R3** · el inventario del jugador **NO** retrocede al cargar (confirma CRG-60). Es el check
  contraintuitivo: lo esperado es que la mochila siga como estaba ANTES de cargar, no como en el save.
- **R4** · un ítem tirado en el suelo sobrevive el ciclo con su blob. Vale **un arma soltada**, que es
  la ruta que el PARCHE 4 agregó: al recogerla tiene que seguir siendo la suya, con su condición.
- **R5** · verificación negativa: **Sidorovich sigue entero** — abre trade, muere, deja ragdoll y
  respawnea, y su cara sigue neutra y parpadeando tras cargar. Es el consumidor externo, y este bloque
  vuelve a tocar su superficie (aunque esta vez sin tocar su repo).

Planilla (sección nueva de la de Cargo, la misma URL que la P y la Q):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

### Ronda 1 de la planilla R (2026-07-26): R1/R2/R5 PASA, y R3/R4 destapan que el save del engine se rompe con un arma ARC9 en el suelo

**Lo que quedó confirmado en juego.** R1: la crate volvió con su loot **y el casco con el NVG puesto
en su sub-slot** — el re-acuñado recursivo, que era lo más frágil del bloque, funciona. R2: los dos
traders conservaron stock mermado y wallet (Sidorovich 48.900, el demo 40.560, iguales antes y
después del ciclo). R5: Sidorovich entero.

**R2 vale doble, y conviene dejarlo escrito:** el wallet de **Sidorovich** volvió bien sin que esta
tanda tocara una línea de `corpus-stalker`. Es la confirmación en juego de la decisión de diseño de
la entry 46 — poner la restauración en `Containers.Attach`, la única puerta del primitivo, en vez de
en un gancho por entidad.

**R3 y R4 no se pudieron correr: el savegame del engine se rompió.** Tres errores distintos, del
reporte del autor:

    attempt to serialize structure with cyclic reference   (gmsave → util.TableToJSON, ABORTA el save)
    Can't write unknown type IMaterial                     (saverestore, ~20 veces, DESCARTA la clave)
    CSave BLOCK SIZE OVERFLOW! (79031 … 190757 > 65k)      "This save will not load correctly!"

**No es de esta tanda, y la evidencia es del propio reporte.** R1 y R2 guardaron y cargaron **bien**,
con una crate llena de blobs y dos traders con stock: si lo que Cargo cuelga de la entidad fuera la
causa, R1 habría fallado primero y no habría PASA que mostrar. Los tres errores aparecen recién en
**R4, que es el primer check de la historia del proyecto que pide soltar un arma al suelo antes de
guardar**. Un arma ARC9 en el suelo es una entidad de un tercero cuya tabla el save del engine
recorre entera.

**Verificado contra `dev/other/` y no de memoria (CRG-24):** las defs de attachment de ARC9 declaran
`ATT.Icon = Material(...)`, y el SWEP se cuelga esas tablas encima (`self.Attachments`). La traza del
reporte tiene exactamente esa forma — tres `WriteTable` anidados antes de que `GetType` encuentre el
`IMaterial`: tabla de la entidad → `Attachments` → la att → su icono.

**Cuánto pesa lo NUESTRO, medido y no argumentado.** El marcador de una crate con 10 uniques —cada
uno con un anidado en su sub-slot— más un stack pasa de **482 a 2.325 bytes**: **184 bytes por
unique**, y un drop de mundo son **145**. Para llegar solo a los 190 KB del desborde harían falta del
orden de **mil** uniques colgados de entidades. El elefante es la tabla del SWEP, no el blob.

**Consecuencia operativa, y hay que decirla porque cambia lo que se puede esperar de un save:** con un
arma ARC9 tirada en el suelo, `gm_save` **no escribe un save cargable** — y eso alcanza a TODO el
mapa, no solo a Cargo. No hay arreglo del lado de Cargo: ARC9 es COMPAT-RUNTIME y no se forkea, y la
tabla que desborda es suya. Queda como **deuda de frontera declarada** en `Cargo_Architecture.md`
§13, con su fila propia. Lo que sí es de Cargo es el camino que la hace alcanzable: nuestro drop de
armas deja el **SWEP real** en el suelo (roadmap #16/#17, para que un arma ARC9 se dibuje ella misma
con sus attachments), y ése es el precio de esa decisión, ahora medido.

- PARCHE 5 — test(dev): **guard de serializabilidad para lo nuestro.** El defecto era ajeno, pero la
  clase de defecto nos aplica: `saverestore.WritableKeysInTable` descarta con error en consola
  cualquier valor que no sepa escribir, y `util.TableToJSON` aborta ante un ciclo. Dos checks nuevos
  recorren lo que Cargo cuelga de la entidad —el marcador del contenedor y las dos mitades del
  trader— y exigen **dato plano y acíclico**: claves string/number, valores string/number/boolean o
  tabla, nada más. Si algún día un módulo dueño mete un Material o una Entity dentro de un blob
  (CRG-1 le deja escribir ahí), el rojo sale offline y no en el reporte del autor. Verificado en
  negativo: con una función metida en el blob, el check falla **nombrando la clave culpable**.

Harness **445** (eran 443). **Entries 46 y 47 siguen `[PENDIENTE]`**: dos checks sin correr no cierran
una sección. Ronda 2 en la misma planilla — R3 y R4 se re-corren **sin un arma ARC9 en el suelo al
guardar**, y R4 usa la **pistola del kit dev** (`weapon_pistol`, SWEP de HL2 con tabla chica) para la
mitad de arma soltada: prueba la misma ruta de código de Cargo sin pasar por la tabla que desborda.

### Ronda 2 (2026-07-26): R3 cierra CRG-60, y R4 destapa que el arma soltada volvía con el cargador LLENO

**R3 PASA y con eso CRG-60 queda confirmada en juego**: «la mochila no retrocedió después de darme
todas las armas de HL2 posterior a guardar». El check contraintuitivo se comportó como la norma dice.
La regla operativa de la ronda funcionó: sin armas ARC9 en el suelo, el `gm_save` del engine escribió
saves cargables y los dos checks pudieron correrse.

**R4 FALLA, y el reporte trae el número exacto:** los dos drops volvieron y se pudieron tomar, pero
«la munición gastada no se reflejó — la pistola tenía 0 balas y volvió a 18, el SMG tenía 15 y ahora
tiene 45». 18 y 45 son los `DefaultClip` de `weapon_pistol` y `weapon_smg1`.

**El diagnóstico, y por qué el síntoma era ambiguo.** Un arma que devuelve un savegame **no la
spawneó Cargo**: la re-creó el engine, así que el `ApplyClipToEntity` de `SpawnWorldWeapon` nunca
corrió sobre ella y su `Clip1` es el DefaultClip del SWEP — un valor de ninguna partida. Al tomarla,
la **cosecha de cargador** del roadmap #18 (`StoreClip`, que existe para que re-equipar desde el grid
no regale un cargador lleno) escribía ese DefaultClip **encima** del cargador que sí había viajado en
el blob. Lo ambiguo es que un ítem acuñado de fábrica —o sea, el blob perdido— daba **exactamente los
mismos 18 y 45**, así que el reporte por sí solo no distinguía «el blob no llegó» de «el blob llegó y
se lo pisaron».

**Lo desempató un check offline, y de paso probó lo que la ronda 1 no pudo:** el ciclo completo del
arma soltada ahora corre en el harness —equipar, soltar, morir el runtime, pegar los campos planos en
una entidad que reporta 30, tomarla— y con el arreglo revertido **reproduce el defecto con el blob
PRESENTE**: el arma vuelve como su instancia, con uid nuevo, y el cargador en 30 en vez de 3. O sea
**el blob sí viaja pegado a un SWEP de mundo**, que era la mitad de B4 que solo se podía afirmar por
analogía con la crate.

- PARCHE 6 — fix(capture): **no se cosecha el cargador de una entidad que acaba de revivir de un
  savegame.** Es la misma regla que gobierna el bloque entero, aplicada al cargador: un valor que
  solo tiene sentido en la sesión que lo produjo no es continuidad. Cuando el blob se re-acuña, el
  blob es la autoridad y la entidad restaurada no; en el camino normal —el arma que Cargo spawneó en
  esta sesión— la cosecha sigue igual, porque ahí la entidad lleva el cargador que el blob le puso.
  Se suma un `Corpus.Log` en la restauración del arma de mundo, que nombra el ítem y el cargador
  recuperado: si el próximo reporte vuelve a discrepar, la consola dice de qué mitad se trata.

Harness **448** (eran 445). Los tres nuevos verificados en negativo. **Entries 46 y 47 siguen
`[PENDIENTE]`**: R4 vuelve a la ronda 3.

### Ronda 3 (2026-07-26): R4 vuelve a fallar, y la línea de log que NO apareció es el hallazgo

R4 se corrió **dos veces** —soltando con la tecla de drop y dropeando desde el inventario— y las dos
volvieron con el cargador lleno. **La línea `Capture: arma de mundo restaurada de un savegame` no
apareció nunca.**

**Esa ausencia es el dato, y corrige lo que la ronda 2 dio por probado.** El log vive adentro de la
rama de revive, que solo necesita dos cosas en la entidad: `CargoInstanceUid` y `CargoInstances`. Si
no imprime, esos campos **no volvieron del savegame** — así que el PARCHE 6 arregló un clobber real
pero no el defecto que R4 mide. En la ronda 2 se afirmó que «el blob sí viaja pegado a un SWEP de
mundo»; el check offline probaba la **ruta de código** con los campos presentes, no que el engine los
devuelva. No los devuelve.

**El contraste está medido dentro de esta misma sección, y es lo que le da forma al hallazgo:**

| Entidad | Qué es | ¿Vuelve su tabla Lua? |
|---|---|---|
| `corpus_cargo_crate` | scripted entity (`base_gmodentity`) | **Sí** — R1 volvió con su loot y sus blobs; antes Q3 medía lo mismo con el marcador |
| `corpus_cargo_trader` | scripted entity | **Sí** — R2, stock mermado y wallet |
| un arma soltada | el SWEP real (`weapon_pistol`, `weapon_smg1`) | **No** — R4, dos veces, dos rutas de drop |

O sea: **el savegame del engine no trata igual la tabla Lua de una entidad scripteada que la de un
arma.** Todo B4 se apoya en que el estado plano vuelve, y vuelve — para las entidades que Cargo
declara. Para un SWEP, no. No se afirma acá el mecanismo exacto del engine (no hay fuente local de
garrysmod — cita CRG-24); se afirma lo medido, que es la tabla de arriba.

**Lo que esto NO invalida:** las entidades de Cargo (crate, trader, y el drop `corpus_cargo_item`,
que es de la misma base que la crate) son la superficie que el bloque construyó, y están confirmadas
salvo la última. **Lo que sí:** un arma soltada **no conserva su instancia a través de un savegame** —
vuelve como ítem de fábrica, sin condición, sin attachments y sin cargador. Degradación honesta, pero
hasta hoy no declarada.

**La ruta que sí sobrevive ya existe, y es un trade-off del autor, no un arreglo.** La convar
`cargo_weapon_world_pickup` (default 1) gobierna **dos cosas a la vez**: que un arma soltada spawnee
el **SWEP real** en el suelo, y el world gate de WALK+USE. En **0**, el drop de un arma spawnea
`corpus_cargo_item` —entidad scripteada de Cargo, que sí conserva su blob— pero se pierde el gate:
vuelve el pickup por contacto del engine, y el arma en el suelo se ve con el modelo del ítem en vez
de dibujarse ella misma con sus attachments (que es justo por lo que el SWEP real está ahí, roadmap
#16/#17). **Decisión del autor, no de la tanda.** Si algún día se quiere lo mejor de las dos, la
forma es partir la convar en dos —ruta de drop y gate de pickup son decisiones distintas—, y eso es
un bloque propio, no un parche de acá.

- PARCHE 7 — feat(dev): **`cargo_dev_worldwep`**, el instrumento que faltaba. Una ausencia no deja
  rastro que loguear: no hay marcador que preguntar, y por eso dos rondas no pudieron distinguir «el
  blob no viajó» de «viajó y algo lo pisó». El comando mira la entidad que el jugador tiene en la
  mira e imprime **qué campos de Cargo lleva de verdad** — uid, blobs, contenedor, entrada. Apuntarlo
  a una crate y después a un arma soltada **en el mismo save** es el experimento entero. Sin gate de
  admin, como el resto del kit (CRG-45).

**El PARCHE 6 se queda.** No arregla R4, pero el clobber que corrige es real y sigue vigente en toda
ruta donde el blob sí vuelva —un paste del duplicator en la misma sesión, o el día que la ruta del
arma cambie— y no toca el camino normal, donde la entidad lleva el cargador que el blob le puso.

Harness **448**, sin checks nuevos: lo que esta ronda descubrió es **del engine**, y un check offline
que lo "probara" estaría probando nuestro stub, no el juego. Lo honesto es el instrumento en juego.
**Entries 46 y 47 siguen `[PENDIENTE]`.** Ronda 4: R4 se corre sobre la ruta que el §6 del PROMPT
nombraba y que ninguna ronda llegó a probar —el **drop no-arma**, `corpus_cargo_item`— más una
pasada de `cargo_dev_worldwep` sobre una crate y sobre un arma en el mismo save, para dejar la
frontera evidenciada y no inferida.

### Cierre — planilla `R` en 5/5, cuatro rondas (2026-07-26)

**Confirmado en juego por el autor.** R1 (la crate vuelve con su loot y el casco con el NVG en su
sub-slot) · R2 (los dos traders con stock mermado y wallet: Sidorovich 48.900 y el demo 40.560, y el
de Sidorovich **sin que la tanda tocara `corpus-stalker`**) · R3 (**CRG-60**: la mochila no
retrocede) · R4 (el drop `corpus_cargo_item` vuelve con su blob: «el test con el casco sí funciona,
no hay problemas») · R5 (Sidorovich entero).

**La pasada de `cargo_dev_worldwep` cerró la frontera con evidencia, y afinó el mecanismo.** Cuatro
entidades leídas en el MISMO save cargado:

    weapon_smg1 #272        uid=nil   instances=nil          CargoWorldSpawned=true
    weapon_smg1 #271        uid=nil   instances=nil          CargoWorldSpawned=true
    corpus_cargo_item #251  entry=cargo_dev_helmet uid=i1785101775_2   instances=2 blob(s)
    corpus_cargo_crate #250 CargoContainer = 7 entrada(s), 5 blob(s)   → "estado restaurado (7 entradas)"

Las dos entidades scripteadas volvieron **completas**, blobs incluidos, y el arma volvió **pelada**.
Y el detalle que corrige la lectura de la ronda 3: en el arma **sobrevive un campo**,
`CargoWorldSpawned = true`. No es que un boolean se salve y un string no — **ese campo no se
restauró, lo re-puso Cargo**: el hook `PlayerSpawnedSWEP` del world gate re-etiqueta el arma cuando
el load la crea. O sea la tabla Lua del arma **no vuelve en absoluto**, y lo único de Cargo que hay
encima es lo que Cargo escribió recién. Efecto colateral afortunado, y conviene saberlo: por ese
mismo hook, **el world gate sigue funcionando tras cargar** — el arma restaurada tampoco se recoge
por contacto.

**DECISIÓN DEL AUTOR (ratificada acá, cierra la fila de §13):** el cargador de un arma soltada que se
restablece al cargar **se acepta como está**. Textual: «con las armas la munición se restablece —eso
ya me da lo mismo, dejémoslo así como OK, lo importante es que los ítems funcionan». No se parte la
convar `cargo_weapon_world_pickup` y no se toca la ruta del SWEP real: el world gate y el arma
dibujándose a sí misma valen más que el cargador. La deuda queda **declarada y aceptada**, no
pendiente.

**Lo que las cuatro rondas dejaron como método, y no es anécdota:** dos de los cuatro hallazgos
salieron de **notas de checks que no eran rojos** (los wallets de R2, que confirmaron lo mejor de la
tanda; los errores de guardado en la nota de R5, que resultaron ser una frontera del engine), y el
hallazgo decisivo salió de **una ausencia**: la línea de log que nunca imprimió. Un log que no sale
es un dato, pero solo si algo lo estaba esperando — de ahí el instrumento (`cargo_dev_worldwep`),
porque una ausencia no deja rastro que loguear. Y la ronda 3 obligó a corregir una afirmación propia:
un check offline verde prueba la **ruta de código**, nunca que el engine devuelva lo que la ruta
necesita.

Harness **448** verdes en ambos realms, checker de IDs limpio, espejo regenerado. **Sin commitear**
(GIT-7). Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 48. Export / import LAN: el único punto donde CRG-6 se invierte, y bajo llave `[APLICADO 2026-07-26]`

B5 del plan de persistencia (`dev/PLAN_cargo_persistencia_gc.md` §4). Que un amigo del autor pueda
traer su personaje a la LAN, **con la puerta cerrada por default**.

Es barato en formato y caro en política: el record ya es autocontenido desde la entry 41 (CRG-56) y
el re-acuñado ya existe desde la 46 (`Instances.Remint`). Lo único que faltaba era **transporte y
permiso**. Archivo nuevo: `shared/corpus_cargo_lan.lua` — shared porque el import tiene dos mitades,
y el cliente no posee ninguna decisión: lee su propio archivo y lo manda.

**Y hay que decir en voz alta lo que el bloque hace:** de los **23** `net.Receive` de servidor del
módulo (contados por grep, FLU-27), 21 no necesitan gate porque los protege **CRG-6** —el server
posee el inventario, el cliente manda *intents*, y un intent hostil se valida contra el estado real
y no fabrica nada—. Éste recibe **estado**. Es la única inversión de CRG-6 del módulo, y la convar
apagada, el gate de admin y la whitelist son lo que la hace aceptable.

- PARCHE 1 — feat(inventory): **`cargo_export`** (server). El record renderizado por
  `Instances.RenderOwner` —la rutina de B3, autocontenida y con los sub-slots anidados adentro— a un
  archivo por `Corpus.Data` (COR-18), con **cabecera**: número de formato, SteamID64 de origen,
  provider de dinero y firma de compatibilidad. El payload es una `table.Copy`, y ése es el único
  lugar donde copiar es lo correcto: es dato muerto camino a un archivo, así que recortarlo no puede
  tocar el record vivo (CRG-57 gobierna la ruta de RUNTIME, no ésta). El **número de formato NO es
  una ruta de migración** (D2 del plan): existe para RECHAZAR con un motivo legible.
- PARCHE 2 — feat(inventory): **la cerradura**, y va ANTES del transporte, porque cada capa hace
  inútil un ataque que la siguiente ya no tiene que considerar. `cargo_import_enabled` en **0** ·
  gate de admin · whitelist de SteamID64 donde **vacía significa NADIE** · rate-limit por jugador ·
  y recién ahí el tope, el formato, el origen, la firma y el saneo.
  **DECISIÓN, y se declara: el receptor se registra SIEMPRE y descarta en la primera línea.** No
  registrarlo sería más fuerte, pero `util.AddNetworkString` corre al boot y una convar cambiada en
  vivo no tendría efecto sin cambio de mapa. Lo decisivo es otra cosa: **un receptor que no existe no
  tiene dónde imprimir por qué rechazó**, y el corolario que dejó B4 es que cada rechazo se loguea
  con su MOTIVO. El motivo entero va a la consola del servidor; al jugador le llega una línea corta
  en inglés (CRG-48) — una cerradura no le narra sus tripas a quien golpea.
- PARCHE 3 — feat(inventory): **el saneo, entrada por entrada** (cita COR-5 y CRG-46, cuyo saneo del
  override de íconos es el precedente de forma). Def desconocida ⇒ se descarta la entrada · condición
  ⇒ clampeada · counts ⇒ recortados al `max_stack` de la def **real**, no al que vino · `ammo_group`
  fuera del set ⇒ el campo se descarta · sub-slots ⇒ **el filtro de la def manda** y lo que pasa de
  `maxItems` se recorta · claves numéricas ⇒ `Util.NumberKeys` (COR-8) · **NaN e infinito ⇒ se
  descartan**, que el JSON los expresa y toda comparación río abajo contestaría `false` en silencio.
  Lo que el módulo dueño puso en el blob **viaja intacto** (CRG-1: Cargo transporta, no interpreta)
  una vez probado que es dato plano.
  Dos reglas que no estaban en el PROMPT y que el árbol pidió: **un uid puede estar reclamado
  exactamente UNA vez** en todo el record —dos entradas nombrando el mismo blob es la duplicación que
  este bloque existe para evitar, y `Remint` llamado dos veces sobre el mismo uid lo acuñaría dos
  veces—; y un ítem que **no entra en el slot en el que llegó cae al grid** en vez de morir, que es
  exactamente lo que ya hace `ReconcileEquipSlots` al spawn (CRG-9: nada se pierde como efecto
  colateral de una regla que incumplió).
  **El peso NO es un gate del import**, igual que no lo es en una compra (CRG-18): el jugador puede
  llegar sobrecargado y la curva se lo cobra en velocidad. Decidido y escrito.
- PARCHE 4 — feat(inventory): **el import REEMPLAZA, y se re-acuña con `Instances.Remint`.**
  Decisión del autor previa al código (§5.4 del PROMPT): "traigo mi personaje" es literal y es el
  inverso exacto del export; fusionar es la ruta de la duplicación infinita. El record del destino se
  escribe **antes** a `import_backup_<steamid64>` —una sola escritura, destino primero, el mismo
  orden de **CRG-58** donde duplicar es el modo de falla seguro—, y el respaldo **obedece
  `cargo_persistence`**: con la persistencia en 0 nada de Cargo toca el disco (planilla P4) y el
  respaldo sería la excepción que vuelve falsa esa frase.
  El re-uid es el de B4 y **no se escribió un segundo**: `Remint` acuña uid nuevo, es recursivo por
  sub-slots y aplica la degradación honesta de COR-5. Escribir otro sería fabricar la clase de
  duplicación que B3 mató con el escritor único.
  El desarme de lo que sale copia la forma de `WipeOnDeath` —stripear las clases de arma equipadas y
  sacar los blobs viejos de `_live`—, porque un record reemplazado es un record que dejó de tener
  dueño. Y cierra con `AmmoPool.Push`: **el cinturón ES el pool** (§16), así que sin asignar la
  reserva desde el cinturón nuevo, el reconciliador de 4 Hz leería el pool viejo como verdad y
  arrastraría la munición del record anterior al cinturón recién importado.
- PARCHE 5 — feat(money): **el dinero viaja sólo con el provider NATIVO en AMBOS lados.** Decisión
  del autor (§4.2). El wallet vive *dentro* del record (`rec.wallet.usd`), así que viaja solo salvo
  que se lo saque a propósito; `Money` es una interfaz con providers (§6) y exportar un wallet que
  otro provider posee es fabricar plata en el destino. La cabecera estampa el provider de origen y el
  destino sólo lo acepta si los dos dicen `usd`.

**MEDICIÓN QUE CAMBIÓ EL DISEÑO: no hay chunking, hay TOPE.** El plan madre daba por hecho que habría
que trocear el payload ("~64 KB por mensaje"). Medido offline con el harness, que ya construye
records realistas: 60 uniques —cada uno con un anidado en su sub-slot— más 40 stacks son **15.770
bytes** de JSON, y 200 uniques + 100 stacks **51.310**; comprimido por `Util.WriteBlob` es una
fracción de eso. O sea el chunking era **adorno** y lo que hacía falta era un **techo que rechace con
motivo**: 64 KiB en el cable, cortados **antes** de descomprimir un solo byte, y 128 KiB de JSON al
abrirlo, que es lo que ataja una bomba de descompresión. El harness afirma la medición, así que el
día que un blob engorde el rojo sale offline y no en la partida de alguien.

**LA FIRMA AVISA, NO GATEA, Y SE DICE QUÉ PUEDE PROMETER** (§3.d del PROMPT: una firma que promete lo
que no puede cumplir es peor que no tenerla). Se parte en tres mitades con honestidad distinta: la
lista de **módulos** registrados es estable (pero no ve a `corpus-stalker`, que es addon de contenido
y no registra módulo); el **hash de las defs NO autogen** es estable *y* sí ve a los addons de
contenido, porque esas defs se registran al boot desde archivos shared y el conjunto es función de lo
montado; y el **contador de autogen** viaja pelado porque **NO** es estable — `autogen_defs` acumula
a lo largo de la vida del servidor (leído de `capture.lua`, no supuesto), así que dos servidores con
los mismos mods hoy pueden tener conjuntos distintos según qué capturó cada uno. Lo que protege de
verdad al destino es el saneo entrada por entrada; la mitad que sí rechaza es el número de formato.

**UNA REGLA QUE NO ESTABA EN EL PROMPT: el import trae TU personaje.** El `origin` de la cabecera
tiene que ser el SteamID64 de quien lo manda. Cierra la duplicación entre dos invitados de la misma
whitelist sin necesidad de una convar más, y ningún flujo legítimo se rompe: el personaje del amigo
se acuñó bajo su propio SteamID64 en su propio listen server.

- PARCHE 6 — fix(inventory): **una sola rutina de re-give, con tres llamadores.** Lo destapó la
  planilla **S1 EN JUEGO**, y es el defecto que la pasada del autor encontró: el import dejaba al
  jugador parado con un wheel lleno de armas que **no podía sacar hasta el próximo respawn**.
  El bucle que convierte `rec.equip` en armas en la mano vivía **adentro** del hook `PlayerLoadout`;
  ahora es `Inventory.RegiveEquipped(ply)`, pública, y la corren el hook, su reconcile diferido de
  0,1 s y el import (si el jugador está vivo — al muerto se la va a correr el hook igual).
  **No es un segundo camino: es el mismo camino con nombre**, que es el argumento de la entry 46 al
  poner la restauración del savegame dentro de `Containers.Attach`, y el de CRG-58 al poner los dos
  archivos de dueño detrás de un solo serializador. La entry 48 había declarado la espera del respawn
  como frontera aceptable en §13; **la planilla mostró que no lo era, y la fila de §13 desaparece**
  en vez de quedar como excusa escrita.
  El guard que se conserva —no re-dar una clase que el jugador ya tiene— es el que impide que el clip
  viejo del blob pise el cargador vivo, y ahora tiene check propio.

**FRONTERA DECLARADA** (§13, con su fila): el gate de admin es **local y provisional** — CRG-45
sigue esperando la primitiva de permisos de Corpus, y lo provisional es *cómo se pregunta quién es
admin*, no la convar ni la whitelist.

Verificación offline: harness **504** (eran 448), **56 checks nuevos**. Los 448 anteriores intactos.
**Las 28 reversiones se verificaron EN NEGATIVO**, una por una, y las 28 ponen en rojo el check que
nombra la regla — incluida la del PARCHE 6, cuya reversión **reproduce exactamente** el síntoma que el
autor reportó en juego.

**El stub del jugador del harness tenía una constante que hacía indemostrable el re-give**, y salió a
la luz al escribir el check del PARCHE 6: `HasWeapon` contestaba `false` para siempre y `Give` era un
no-op, así que "el arma quedó puesta" era indistinguible de "no pasó nada". Ahora `Give`/`Strip`
llevan el set de armas y un contador de gives — el contador es lo que hace observable el guard.
`GetWeapon` sigue devolviendo `NULL` a propósito: la entidad del SWEP no existe offline y la ruta del
cargador tiene que seguir degradando por `IsValid` como lo hace en juego.

**Tres de esos checks nacieron VACUOS y hay que decirlo, porque es el método y no la anécdota.** El
primero marcaba verde un rate-limit que la consola mostraba `import ACEPTADO`: el check comparaba el
CONTEO de entradas, y un archivo que trae lo mismo que ya hay da el mismo conteo entrado o
rechazado. Lo destapó leer la línea de log al lado del verde — la misma lección que B4 sacó de una
ausencia. Se arreglaron comparando el **uid**, que un import aceptado re-acuña siempre. Los otros dos
eran de la misma familia (la firma que no coincide, y el pack faltante). Y la verificación en
negativo destapó una cuarta: reventar la convar dejaba el check de S3 **verde**, porque el gate de
admin lo tapaba — defensa en profundidad funcionando, pero un check que no aísla su capa no prueba
que esa capa exista. Ahora cada capa se prueba con las otras tres ABIERTAS. La quinta fue un hueco
liso: no había ningún check de que el wallet se rechace **en el import** con un provider ajeno; el
que había probaba el export.

**LO QUE EL HARNESS NO PUEDE PROBAR, Y HAY QUE DECIRLO** (§0.bis 2 del PROMPT, la lección cara de la
ronda 3 de la planilla R): un check offline verde prueba que la **ruta de código** hace lo correcto
CON esta entrada. Jamás que ésta sea la entrada que llega. Acá el entorno es la RED y un cliente que
es hostil por definición, así que lo que **no** está cubierto offline es:

- que `util.Compress`/`util.Decompress` del engine se comporten como el stub, que es identidad. Los
  dos topes se ejercen con largos declarados a mano; la relación real entre bytes comprimidos y JSON
  la pone el engine.
- que el tope de un mensaje de net del engine sea el que se supone. No hay fuente de garrysmod en
  `dev/other/` (cita **CRG-24**), así que el número del plan no se verificó contra código local: lo
  que sí está medido es cuánto pesa un record, y por eso el techo propio del módulo es el que manda.
- que `ply:IsAdmin()` responda lo que el servidor real cree. El stub contesta `false` a propósito.
- que un cliente **modificado** mande exactamente lo que el cliente de Cargo manda. Ésa es la premisa
  entera del bloque, y por eso el saneo se escribe para la entrada que no se probó.

EN JUEGO: planilla **S** (ver entry 49, que comparte la pasada).

---

## 49. CRG-61 acuñada: la puerta cerrada por default `[APLICADO 2026-07-26]`

**CRG-61 acuñada** — "El import está apagado por default y todo lo que llega del cliente se sanea
server-side". Sede: `Cargo_Architecture.md` §12.1, sección nueva. Fuerza: INVARIANTE.

La norma existe porque es el **único** punto del módulo donde **CRG-6** se invierte, y porque sin
escribirla la próxima pasada leería la convar en 0 como un default conservador que se puede subir de
un plumazo. No lo es: es la condición de que la inversión sea aceptable, junto con la whitelist
—donde **vacía significa NADIE, jamás "vacía = todos"**— y el gate de admin.

§12 gana la subsección **12.1** con qué viaja, qué se rechaza y por qué la puerta está cerrada,
incluida la tabla de las cinco capas y la tabla de las tres mitades de la firma con lo que cada una
puede prometer. §13 gana **dos filas** de deuda de frontera: el gate de admin local a la espera de
CRG-45, y el arma equipada que vuelve a la mano en el próximo respawn. §13.1 se re-deriva del árbol:
eran 22 `net.Receive` de servidor y ahora son **23** — 21 protegidos por CRG-6, uno
(`NET_ICON_OVERRIDE`) que necesita gate y no lo tiene, y uno (`NET_IMPORT`) que invierte CRG-6 y es
el único del módulo que sí trae gate.

La letra **S** se registra en `familias_excluidas` en el mismo parche, ANTES de usarse (FLU-30), y no
se recicla (FLU-07). Con ella el plan de persistencia agota su presupuesto de planilla: P=B1, Q=B3,
R=B4, S=B5.

**EN JUEGO — planilla `S`** (cuarta sección de la planilla de CARGO; la T es de corpus y es otra
planilla, no reciclar). **Al menos DOS de los cinco son de RECHAZO a propósito: una planilla donde
todo pasa no prueba que la cerradura exista** — acá son tres.

**LA PLANILLA S SE CORRE SOLO, y no es un atajo: es la única forma que el check tiene.** La regla
"un import trae TU personaje" (el `origin` de la cabecera contra el SteamID64 de quien manda) hace que
el archivo de otro jugador se RECHACE. El flujo real —el amigo exporta en su máquina e importa en la
del autor— usa la MISMA SteamID64 las dos veces, así que probarlo solo ejerce idéntica ruta de código.
Todo pasa en el **listen server**, donde el `garrysmod/data/` que escribe el server es el que lee el
cliente. El reparto de realms tiene precedente en el repo y no se afirma de memoria: `cargo_export` es
server-only como `cargo_dev_give`, y `cargo_import` es client-only como `cargo_icon_edit`.

- **S1** · **ida y vuelta local sin pérdida, y de paso REEMPLAZA.** Preparación: `cargo_dev_give`,
  ponerse el **casco con el NVG en su sub-slot** (`cargo_dev_helmet` declara `optic`, y
  `cargo_dev_nvg` es `category:optics`) y **disparar el SMG hasta un cargador que NO sea el lleno**,
  después desequiparlo para que la cosecha lo baje al blob. `cargo_export`. Ahora **cambiar el
  inventario EN VIVO** —dropear cosas, `cargo_dev_give` otra vez— y recién ahí `cargo_import`.
  Vuelve el estado exportado: el casco **con el NVG adentro** —un ítem acuñado de cero vuelve
  vacío, igual que en R1— y el SMG **con el cargador que se le dejó**, no con su `DefaultClip`. Y lo
  que se agregó en el medio **tiene que haber desaparecido**: eso es lo que prueba que REEMPLAZA y no
  fusiona. **Ojo con la trampa de la condición: si todo está en 100, "volvió con su condición" no
  prueba nada** — 100 es también lo que da un ítem recién acuñado. Por eso la señal numérica es el
  cargador, que no tiene un valor por default que coincida. **Y ojo con lo declarado:** el arma
  equipada vuelve a la mano en el **próximo respawn**, no en el acto.
  No hace falta borrar `inv_<steamid64>.json` ni reiniciar: cambiar el inventario en vivo prueba
  más que borrarlo, y el respaldo queda en `import_backup_<steamid64>.json` por si algo sale mal.
- **S2** · **import con defs que este servidor no conoce.** Dos rutas, y prueban cosas distintas:
  editar a mano el `id` de una entrada del `export_*.json` por uno inventado ejerce el saneo —que es
  lo que S2 mide, porque para `Items.Get` una def desmontada y una inventada son lo mismo— y no pide
  reiniciar; desmontar de verdad un pack ARC9 prueba además que el desmontaje no rompe otra cosa,
  pero exige reinicio. Con cualquiera de las dos: descarta **esas** entradas con **log de motivo** en
  la consola del servidor y **no rompe el resto**.
- **S3** · **RECHAZO — import con la convar en 0.** Con `cargo_import_enabled 0`, `cargo_import` se
  rechaza **y la consola del servidor dice por qué** (§0.bis 4). Es el check que prueba que el
  default es real.
- **S4** · **RECHAZO — SteamID64 fuera de la whitelist.** Con la convar en 1 y
  `cargo_import_whitelist` vacía, se rechaza con motivo. Repetir con la lista puesta pero con OTRA
  id: se rechaza igual.
- **S5** · **verificación negativa: el inventario normal, el comercio y el savegame siguen intactos.**
  Equipar/dropear/recoger, una compra a Sidorovich, y un `gm_save`/`gm_load` con una crate con loot.
  Este bloque toca el record, que es la superficie más caliente del módulo, así que lo que hay que
  mirar es que nada de lo confirmado en P, Q y R se haya movido.

Planilla (sección nueva de la de Cargo, la misma URL que la P, la Q y la R):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

### Cierre — planilla `S` en 5/5, dos rondas (2026-07-26)

**Confirmado en juego por el autor.** S1 (ida y vuelta sin pérdida: condiciones, el NVG en el
sub-slot del casco, el cargador y el cinturón, y lo agregado en el medio desaparece — REEMPLAZA) ·
S2 (una def que este servidor no conoce descarta esa entrada con motivo y el resto entra) · S3
(RECHAZO con la convar en 0) · S4 (RECHAZO fuera de la whitelist) · S5 (inventario, comercio,
crate y morir-con-el-arma-en-la-mano intactos: «B5 no ha roto nada»).

**Las tres capas de la cerradura dejaron su línea en consola**, que es lo que vuelve citable la
evidencia:

    import RECHAZADO — SEPULDOSKY (…): el import está apagado en este servidor (cargo_import_enabled 0)
    import RECHAZADO — SEPULDOSKY (…): el SteamID64 no está en cargo_import_whitelist
    import saneo    — SEPULDOSKY (…): blob 'i1785110922_1': def desconocida 'wpn_arc9_eft_m19a1', descartado
    import saneo    — SEPULDOSKY (…): grid 'wpn_arc9_eft_m16a1': uid 'i1785110922_1' sin blob en el archivo, descartada

**EL HALLAZGO DE LA RONDA 1 SALIÓ DE UN CHECK QUE PASÓ, y es el tercer bloque seguido.** S1 marcó
el ida y vuelta correcto en todo lo que medía; el defecto —el arma equipada que no se podía sacar—
estaba en el campo de notas al costado. Lo arregla el PARCHE 6, y la fila de §13 que declaraba esa
espera como frontera aceptable **desaparece**: la planilla mostró que no lo era.

**Y dejó una lección de método propia, que es sobre CÓMO SE MIDE.** Dos rondas se fueron en
distinguir «el re-give está roto» de «no hubo respawn», y el error fue de esta sesión, no del autor:
se afirmó que la declaración de §13 era falsa **antes** de tener el dato que lo probara. Lo desempató
el experimento más barato de todos —un `kill`— que separaba las dos lecturas de una: si el arma vuelve
en el segundo respawn, el mecanismo está sano. **Un instrumento chico y decisivo antes que una
hipótesis elaborada**, que es la misma conclusión a la que B4 llegó con `cargo_dev_worldwep`.

De paso, dos correcciones a los comandos de diagnóstico que valen para la próxima pasada: la consola
de GMod **trunca** una línea larga de `lua_run` sin decir que la truncó (el error sale como sintaxis),
y pegar varias sentencias separadas por saltos las concatena. Los comandos de medición se mandan
**cortos y de a uno**.

Harness **504** verdes en ambos realms (eran 448), checker de IDs limpio, espejo regenerado.

---

## 50. Las NVG de Neosun como ítems de primera clase (y la señal de equipamiento que faltaba) `[APLICADO 2026-07-27]`

Roadmap **#47**, pedido del autor. Que las 61 gafas de *[VManip] Neosun's Cooler Nightvision* se
recojan del mundo, pesen, se guarden, se comercien, se dropeen, sobrevivan un relog — y al
equiparlas, **se vean**. Es la mitad **POSEER** de un frente de dos: la mitad **ACCIONAR**
—encenderlas desde el wheel— es el roadmap #46 y va después, con su propio PROMPT.

Mapa del mod y acople: [`../../dev/Cargo_NVG_Neosun_Referencia.md`](../../dev/Cargo_NVG_Neosun_Referencia.md).
El mod es **COMPAT-RUNTIME y OFF-LIMITS para modificar**: no se copia una línea de su código ni uno
de sus assets, y la integración vive **entera** en Cargo, hablándole por su superficie pública.

**EL HUECO CENTRAL NO ERA DEL MOD: ERA DE CARGO.** Hasta hoy no existía ninguna señal de "equipé
algo". `Equip`/`Unequip` solo daban y quitaban `weapon_class`, la única difusión era
`Corpus_Cargo_BodyChanged` —exclusiva del slot body— y los sub-slots **no difundían nada**. Sin esa
señal no hay dónde colgar una integración de equipamiento, y por eso el primer parche es de
`inventory` y no de compat.

- PARCHE 1 — feat(inventory): **la señal genérica** (**CRG-62**).
  `Corpus_Cargo_EquipChanged(ply, slotId, defId|nil, blob|nil)` y
  `Corpus_Cargo_SubSlotChanged(ply, hostUid, subId)`, disparadas **después** de que el record quedó
  consistente — un oyente que lea `rec.equip` a mitad de camino ve un estado que no existió.
  `Corpus_Cargo_BodyChanged` **se queda exactamente como está** y se sigue disparando: su firma es
  contrato vivo del lector de disfraz del roadmap #10, y la señal nueva se dispara **ADEMÁS**.
  **LAS PUERTAS SON CINCO, NO CUATRO, y esto salió de re-greppear en vez de creerle al diseño.** El
  doc contaba `Equip`/`Unequip`/`SubSlotAttach`/`SubSlotDetach`; el árbol mostró que
  **`DropEquipped` no pasa por `Unequip`** —manipula `rec.equip` y difunde por su cuenta, que es lo
  que el `BodyChanged` existente ya hacía en sus **dos** salidas— y que el reconciliador de
  `WeaponDrop` de `capture.lua` es donde se vacía el slot al soltar el arma **en la mano**. Las dos
  se suman. Una puerta que no difunde es un agujero que se descubre en juego seis meses después, y
  la de `DropEquipped` tiene consecuencia visible: dropear el casco con las gafas montadas dejaría
  al jugador **viendo a través de unas gafas que ya no tiene**.
  Y `RegiveEquipped` difunde con **`slotId` nil** = *"se re-aplicó todo"*. Es la puerta del
  respawn, y existe para que el oyente no tenga que enganchar `PlayerLoadout` y apostar al orden de
  hooks — el bug que Quick Loadouts ya le costó a este repo. **No se escribió un segundo re-give:**
  es la rutina única que B5 extrajo y nombró.
  **Descartado, con su razón escrita:** `def.onEquip`/`def.onUnequip` en el contrato de ítem. Es más
  potente, pero mete una closure por def en un contrato que hoy tiene exactamente una (`onUse`) y
  obliga a que 61 defs derivados carguen la misma función.
- PARCHE 2 — feat(items): **los 61 defs se DERIVAN** (`shared/corpus_cargo_nvg.lua`, ambos realms
  por COR-12: el grid del cliente renderiza desde defs). Se itera la tabla global `ArcticNVGs` y se
  registra un def por variante. **61 defs a mano es exactamente el trabajo que CRG-41 y CRG-42
  existen para evitar** — y este mod tiene **dos trampas de nombre** que un mapeo a mano se
  equivoca sí o sí: en las cinco familias de NVG `_t` es **teal**, pero en las aviators `shades_t`
  es la **TÉRMICA** y la teal es `shades_teal`; y `_hp` (hotpink) se muestra **"Ruby"**. Derivado,
  ninguna de las dos se puede tipear mal: el nombre sale del `PrintName` de la entidad y la
  etiqueta de display, de los flags `ThermalVision`/`FullColor`/`NoBrightenWorld`, **nunca del
  sufijo**.
  **A mano se cataloga UNA sola tabla: las SEIS familias** (peso, valor, footprint). Seis modelos
  reales para 61 variantes — el color es post-proceso, no un modelo distinto — así que seis filas es
  el tamaño honesto de la parte escrita a mano. Los números son de arranque, a calibrar en juego.
  **Los íconos ya estaban hechos**: el mod trae un PNG recortado por variante en
  `materials/entities/arctic_nvg_*.png`, con el nombre exactamente derivable de la clase (67
  archivos, las 61 con el suyo — contado, no supuesto). `def.icon` gana en el pipeline. Es la
  diferencia entre 61 celdas idénticas y 61 legibles **sin copiar un solo archivo**: se referencia
  una ruta montada en runtime, que es la definición misma de COMPAT-RUNTIME.
  Convar `cargo_nvg_register` (default 1) para el servidor que no quiera 61 entradas en el catálogo
  del trader. Sin el mod montado la tabla no existe, no se registra nada y el archivo es **inerte**
  (COR-5), con una línea de log que lo dice — el corolario de B4: un componente que calla no deja
  evidencia de que estaba apagado.
- PARCHE 3 — feat(capture): **`Capture.RegisterWorldPickup(class, spec)`**. Hoy E sobre unas gafas
  llega al `ENT:Use` del mod y el inventario **nunca se entera**: el portero sale en
  `if not ent:IsWeapon() then return end`. El portero gana una cuarta forma, pero **por registro y
  no inline** — mismo patrón que `StatusPanel.RegisterBar`: la cuarta rama inline funcionaba, la
  quinta ya sería un olor, y el doc hermano (#46) propone un registro gemelo para las fuentes de
  luz. Semántica idéntica a las otras tres: **WALK+USE toma, USE solo carga**, mismo debounce, y si
  no entra por peso **se queda en el suelo** con el `Notice` de siempre (la regla viva de las cajas
  de munición, copiada tal cual). `return false` en los dos caminos: eso es lo que bloquea al engine
  de alcanzar el `ENT:Use` del mod, y la técnica ya estaba probada (roadmap #27).
  **El drop es gratis y no se tocó:** un `unique` de Cargo cae como `corpus_cargo_item` con su blob
  al lado. Spawnear la entidad del mod sería un objeto con dos dueños.
- PARCHE 4 — feat(items): **las DOS rutas de slot** (decisión del autor, ruta C). Con casco, las
  gafas montan en su **sub-slot óptica** — ya existía, cero código nuevo. Sin casco, ocupan **Head
  directo**, y eso cuesta **una cadena**: el filtro del slot pasó a `"category:helmets,optics"` y
  `MatchesFilter` ya parseaba listas separadas por coma. **Ni un primitivo nuevo: CRG-8 intacto.**
  La regla que el jugador percibe es *"o el casco con las gafas montadas, o las gafas solas"*. El
  costo real, asumido y declarado: el compat escucha **dos** señales, y cada ruta se prueba con la
  otra fuera de juego.
- PARCHE 5 — feat(capture): **el commit escribe la NW, y JAMÁS llama a
  `ArcticNVGs_SetPlayerGoggles`** (`server/corpus_cargo_nvg.lua`). Esa función **dropea al mundo el
  par anterior**: correcto para un mod donde el jugador tiene un par, **DUPLICADOR** para un
  llamador que ya es dueño del ítem — el jugador terminaría con las gafas en el inventario y una
  copia en el suelo. Escribir la NW es idempotente: sin entidades, sin sonido, sin efectos
  colaterales. Y **se valida el nombre corto ANTES**, porque el mod no lo hace y un nombre
  inexistente baja a `SetNWInt("nvg", nil)`, que es un error de argumento.
  La resolución es **genérica y determinista**: se recorre `Slots.List` en su orden declarado y, por
  cada host, sus sub-slots en el orden que declara el def. Nada dice "head" — unas gafas son
  cualquier def equipado que lleve `nvg_shortname`. Eso hace que la ruta C sea **un solo camino de
  código** en vez de dos casos especiales, y que dos pares equipados a la vez den siempre la misma
  respuesta (`pairs` sobre `rec.equip` no tiene orden).
- PARCHE 6 — feat(capture): **el convar del mod va a 0 y se dice.** `sh_arctic_nvg_losegoggles`
  viene en 1 y en `PlayerSpawn` hace `SetNWInt("nvg", 0)` sin dropear nada; Cargo tiene su propia
  regla (`cargo_lose_on_death`) y su reconcile. El orden de hooks *favorece* al reconcile, pero
  **depender del orden es exactamente el bug de Quick Loadouts**: se apaga el convar y no se
  discute. Nunca en silencio — una línea de `Corpus.Log` si se lo encuentra en 1.

**CRG-63, y es la regla cara de la tanda: el ORDINAL nunca se persiste.** `ply:GetNWInt("nvg")` no
guarda un nombre: guarda el **índice** de la tabla del mod. Si Neosun publica un parche que inserta
una variante en el medio, todos los índices posteriores se corren y **un ítem guardado amanece
siendo otras gafas**. El def lleva el `ShortName` y el ordinal se resuelve en el momento de
equipar, contra la tabla viva. Detalle que lo agrava y está verificado contra el código del mod
(CRG-24): el propio mod construye su índice inverso con `pairs` sobre un array. Norma en la entry
51.

**LO QUE EL HARNESS NO PUEDE PROBAR, Y HAY QUE DECIRLO** (§0.bis 1 del PROMPT). Acá el entorno es un
**mod ajeno que el harness no tiene**: `ArcticNVGs`, `ArcticNVGs_ShortNameToID` y las 61 entidades
son un **stub escrito por nosotros**. Todo lo que los checks afirman es *"la derivación hace lo
correcto CON esta tabla"*, jamás *"ésta es la tabla que el mod expone"*. Lo segundo lo prueba la
planilla **U** y nada más. Lo que sí está anclado al mod real: los `PrintName` del stub se leyeron
de sus archivos de entidad, los seis modelos y sus conteos (12+11+12+11+2+13 = 61) se contaron sobre
su tabla, y los 67 PNG se contaron en su carpeta. Fuera de cobertura offline por construcción:
que el `PrintName` llegue a tiempo en el cliente real (`scripted_ents.GetStored` se consulta
defensivamente y degrada al `ShortName`), que el efecto del mod se **apague solo** al quitar las
gafas —su `HUDPaintBackground` compara el ordinal contra el anterior y lo hace, pero eso se
**verifica en juego, no se da por hecho**—, y que la ruta de la entidad de mundo real llegue al
portero.

Verificación offline: harness **574** (eran 504), **70 checks nuevos**. Los 504 anteriores intactos.
**Las 14 reversiones se verificaron EN NEGATIVO**, una por una, y las 14 ponen en rojo el check que
nombra la regla.

**El stub del jugador NO tenía `SetNWInt`/`GetNWInt`, y se agregaron GUARDANDO ESTADO DE VERDAD.**
Es la lección del PARCHE 6 de B5 aplicada **antes** de volver a pagarla: allá `HasWeapon` estaba
clavado en `false` y eso volvió indemostrable el re-give durante bloques enteros. Un stub que no
guarda haría indistinguible *"la NW se escribió"* de *"no pasó nada"*. La reversión que lo prueba
está en la lista: vaciar el `SetNWInt` del stub pone **siete** checks en rojo.

**UN CHECK NACIÓ SIN DISTINGUIR, y lo destapó la verificación en negativo — no la corrida verde.**
Había checks de que el registro de recogidas existe y resuelve la clase correcta, pero **ninguno de
que el portero de `PlayerUse` lo consulte**, que es justamente el `return false` que impide al
engine alcanzar el `ENT:Use` del mod: cegar el portero dejaba los checks en verde. Ahora se corre
el **hook real**, como el bloque de las cajas de munición (#32), y de paso se le pusieron
`IsWeapon`/`GetOwner` a la entidad falsa **a propósito**: sin ellos, el portero ciego se caía con un
error de método faltante en vez de contestar, y un check que se salva por un crash no aísla su capa.

### 2.ª pasada — lo que el autor pidió tras la primera vuelta en juego (2026-07-26)

Reporte del autor **sin la planilla a la vista**: recoger las gafas del suelo al inventario funciona,
ponérselas en la cabeza y sacárselas **mientras están encendidas** también, lo mismo metiéndolas
dentro del casco dev, y lo mismo con las aviators; cambiar de mapa conserva las gafas puestas. O
sea: **U1, U2 y U3 se comportaron**, y el apagado automático del efecto —que es del propio mod y
esta tanda se negó a dar por hecho— ocurrió. Lo que faltaba, y son cuatro cosas:

- PARCHE 7 — feat(ui): **extraer un sub-slot con el host EN LA MOCHILA.** La lista de lo montado se
  armaba solo dentro del menú del slot equipado, así que **un casco guardado retenía su óptica como
  rehén** — y una armadura guardada, sus placas. El servidor **siempre** lo permitió
  (`FindOwnedInstance` acepta grid o equipo): el hueco era de la UI y de nadie más. Ahora la lista
  es una función pura y exportada, `CARGO.UI.MountedEntries`, y **los dos menús la comparten**: un
  casco es el mismo objeto en la cabeza que en la mochila. El `index` que viaja al detach es
  **posicional dentro de su sub-slot**, así que aplanar la lista no lo puede renumerar — con dos
  placas en el mismo sub-slot, sacar la segunda tiene que sacar la segunda.
- PARCHE 8 — feat(ui): **arrastrar un ítem SOBRE otro ítem lo monta.** El grid genérico gana
  `onCellDrop`, y con él cada celda es destino además del canvas. Es el mismo intent que el menú
  *"Insert into…"* ya mandaba: **el arrastre es un atajo, no una segunda ruta**.
  **La trampa de VGUI, pagada de entrada y no descubierta en juego:** una celda que además es
  `Receiver` **tapa** al receiver del canvas — `dragndrop` sube desde el panel bajo el cursor y para
  en el primero que encuentre. Sin un fall-through explícito, soltar un ítem de un contenedor justo
  encima de otra celda **dejaría de transferir**. Por eso `onCellDrop` devuelve un booleano y el
  grid cae al `onReceiveDrop` de siempre: el comportamiento del canvas no puede depender de **dónde
  adentro** del canvas soltaste.
- PARCHE 9 — feat(ui): **intercambiar o acoplar, y en ese orden.** Soltar sobre un slot de
  equipamiento ocupado tenía una sola lectura (equipar). Ahora son tres, y la regla vive en
  `CARGO.UI.ResolveSlotDrop`, pura: **(1)** el ítem puede ocupar el slot → equipa, y eso ya
  **intercambia** porque `Equip` devuelve al ocupante anterior al grid; **(2)** no puede, pero el
  **ocupante** tiene un sub-slot libre que lo acepta → **acopla** — es la única forma de que una
  placa, o una óptica que ningún slot admite sola, llegue a su host arrastrando; **(3)** ninguna de
  las dos → se manda el equip igual y **el rechazo lo redacta el servidor** (CRG-6), porque
  tragárselo acá cambiaría una negativa legible por un gesto que no hizo nada.
  **Equipar se prueba primero a propósito** (decisión del autor): cuando las dos lecturas son
  legales —gafas que entran en Head, soltadas sobre un casco que también las aceptaría en su
  óptica— gana el intercambio.
- PARCHE 10 — feat(items): **el ícono se AUTOGENERA del world model.** La primera pasada usaba el
  PNG que el mod trae por variante; en juego **su arte de spawnmenu se lee mal al lado de los
  renders generados del resto del catálogo** (decisión del autor). Se quita `def.icon` y el pipeline
  renderiza `def.model` como para todo lo demás, así que el catálogo entero parece **un** catálogo.
  **Costo declarado:** seis modelos para sesenta y una variantes significa que el color **no se ve
  en la celda** — el NOMBRE es lo que distingue una Green de una Ruby. El encuadre por def sigue
  siendo ajustable con `cargo_icon_edit`, que escribe un `icon_override` y sobrevive al re-registro.

La regla de arrastre y la lista de montados son **puras y exportadas** justamente porque son de las
que se rompen en silencio: un `if` invertido y el gesto deja de significar lo que el jugador espera,
sin un solo error en consola. Harness **588** (eran 574), **14 checks más**, y **7 reversiones más
verificadas en negativo** — 21 en total en la tanda.

**Lo que sigue sin cobertura offline, y hay que decirlo:** el cableado de `dragndrop` en sí (que la
celda reciba, que el fall-through se dispare) es VGUI y no existe en el harness. Lo probado offline
es la **decisión** —qué significa el gesto—, no que el gesto llegue. Eso es planilla.

EN JUEGO: planilla **U** (ver entry 51, que comparte la pasada).

---

## 51. CRG-62 y CRG-63 acuñadas: la señal genérica y el ordinal que no se persiste `[APLICADO 2026-07-27]`

**CRG-62** — *"Cargo difunde que un slot de equipamiento cambió; la semántica de ese cambio vive en
el consumidor, nunca en el inventario."* Sede: `Cargo_Architecture.md` §4, sección nueva. Fuerza:
INVARIANTE. Es **CRG-1** aplicado al equipamiento: el inventario no sabe qué *significa* que alguien
se ponga unas gafas, igual que no sabe qué significa `onUse`. La norma existe porque sin ella la
próxima integración de equipamiento volvería a no tener dónde colgarse — o peor, la colgarían
adentro de `Equip`.

**CRG-63** — *"Un identificador de un tercero que sea POSICIONAL (un ordinal de su tabla) no se
persiste jamás: se persiste su clave estable y el ordinal se resuelve en el momento de usarlo."*
Sede: `Cargo_Architecture.md` **§3**, y la elección se declara: el PROMPT ofrecía §3 o §13, y **§13
es la tabla de fronteras y deuda declarada** — una norma vigente no vive en una lista de
pendientes, que es el mismo argumento que sacó a CRG-45 de un roadmap. Esto es una regla sobre qué
campo lleva un def, así que su lugar es el contrato de ítems. Mismo espíritu que **CRG-42**.

§4 gana además el párrafo de **las dos rutas de una óptica** (con casco al sub-slot, sin casco a
Head directo) con su costo declarado: el consumidor escucha dos señales. §13 **pierde la fila**
*"compat con mods externos de NVG/ópticas — falta mapear mods concretos"*, abierta desde el Block 1
y ahora mapeada y resuelta; queda la nota de cierre en su lugar. Y **§12.1 gana una nota**: 61 defs
**no autogen** cambian el `defs_hash` de la firma de compatibilidad de B5, así que dos servidores
que difieran en este mod **ahora se detectan**. Eso es la firma funcionando —esa mitad promete
justamente ver a los addons de contenido— y por eso avisa en vez de gatear.

La letra **U** se registra en `familias_excluidas` en el mismo parche, ANTES de usarse (FLU-30), y
no se recicla (FLU-07). Es la primera sección de planilla de Cargo que **no** es del plan de
persistencia: P=B1, Q=B3, R=B4, S=B5 lo agotaron. La **T es de corpus y es otra planilla**, no se
recicla.

**EN JUEGO — planilla `U`** (quinta sección de la planilla de CARGO). Nació con cinco checks y la
2.ª pasada le sumó el **U6**; los números no se reciclan (FLU-07). **Al menos uno es de RECHAZO o de
AUSENCIA a propósito**: que sin el mod montado el archivo sea inerte y la consola quede limpia es
tan verificable como lo demás, y es la mitad que nadie prueba nunca.

- **U1** · **las gafas del mundo se recogen al inventario.** Spawnear unas gafas del menú Q
  (categoría *"Neosun's Cooler Nightvision"*) y hacerles **WALK+USE**: entran al grid con su peso y
  con un **ícono generado del world model** —igual que el resto del catálogo, no el PNG del mod
  (2.ª pasada)—. **Y el mod NO se las equipa por su cuenta**, que es lo que hace hoy: al recogerlas
  **no se ve nada todavía**. Poseer y llevar puesto son dos verbos distintos. De paso, **USE
  pelado** debe **cargarlas como prop**, no recogerlas.
- **U2** · **con casco: montan en el sub-slot óptica y SE VEN.** `cargo_dev_give`, equipar
  `cargo_dev_helmet` en Head y montar las gafas en su sub-slot `optic`: la NW quedó escrita y la
  visión nocturna es utilizable. Al **desmontarlas**, el efecto **se cae solo** — eso lo hace el
  `HUDPaintBackground` del propio mod sin una línea nuestra, y **hay que verificarlo, no darlo por
  hecho**: si estaban **encendidas** al desmontarlas, tienen que apagarse al siguiente frame.
- **U3** · **sin casco: ocupan Head directo y se ven igual.** Es la **otra ruta** y **se prueba
  SOLA**: con el casco **fuera del inventario**, equipar las gafas directamente en Head. Si el
  casco estuviera puesto, un camino roto pasaría desapercibido tapado por el otro.
- **U4** · **relog: siguen puestas y son LAS MISMAS.** Desconectar y volver con las gafas
  equipadas: vuelven puestas y son **la misma variante**, no otra. Es el check de **CRG-63** — lo
  que sobrevive es el nombre, no el ordinal. **Ojo con la trampa de la medición: hay que usar una
  variante distinguible a ojo** (una de color raro, o una térmica), porque "hay unas gafas puestas"
  no distingue "las mismas" de "otras".
- **U5** · **AUSENCIA + verificación negativa.** Dos mitades.
  **(a) El kill-switch, y cómo se corre** (la convar se lee **UNA vez, al boot**, así que cambiarla
  en vivo no hace nada — hace falta cambio de mapa):

      cargo_nvg_register 0          <- en la consola del servidor
      map gm_construct              <- o el mapa que sea: la convar se relee acá

  Al arrancar, la consola tiene que decir en **una** línea
  `[Corpus:cargo] neosun nvg: cargo_nvg_register en 0 — el catálogo queda del mod`, **sin un solo
  error**. Y entonces: `cargo_dev_items nvg` **no lista nada**, las 61 entradas no están en el
  catálogo del trader, y **E sobre unas gafas del suelo vuelve a hacer lo del mod** —te las equipa
  sola y la entidad desaparece— porque Cargo dejó de reclamarlas. Eso es lo que prueba que el
  archivo es **inerte y lo declara** (COR-5), no que esté apagado por accidente. Después,
  `cargo_nvg_register 1` y otro cambio de mapa para volver.
  **(b)** Con todo prendido, el inventario normal, el comercio, el savegame y el import de B5
  **siguen intactos** — esta tanda toca `Equip`/`Unequip` y el portero de mundo, que son dos de las
  superficies más calientes del módulo.
- **U6** · **acoplar y desacoplar arrastrando, y con el host en la mochila** (2.ª pasada, lo que el
  autor pidió tras la primera vuelta). Cuatro gestos, y cada uno prueba una rama distinta:
  **(a)** con el casco **en la mochila** y las gafas también, **arrastrar las gafas sobre el casco**
  las monta en su óptica; **(b)** click derecho sobre ese casco **en la mochila** ofrece
  **"Extract …"** y las devuelve al grid — eso es lo que faltaba, y vale igual para las **placas**
  dentro de la armadura guardada; **(c)** con el **casco equipado** en Head, arrastrarle las gafas
  desde el grid las **INTERCAMBIA** (el casco baja al grid, las gafas quedan en Head), porque las
  gafas también entran en Head; **(d)** con la **armadura equipada**, arrastrarle una **placa**
  desde el grid la **ACOPLA** a su sub-slot en vez de no hacer nada, porque una placa no puede
  ocupar Body. **Y la negativa que va con esto:** abrir una crate o un trader y **arrastrar un ítem
  del contenedor soltándolo justo encima de otra celda** del inventario tiene que **transferir
  igual** — si la celda de destino se comiera el drop, este parche habría roto el loot.

Planilla (sección nueva de la de Cargo, la misma URL que P, Q, R y S):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

### Cierre — planilla `U` en 6/6, dos pasadas (2026-07-27)

**Confirmado en juego por el autor.** U1 (las gafas del suelo entran al grid y el mod **no** se las
equipa por su cuenta) · U2 (con casco, montan en el sub-slot óptica y se ven; sacárselas
**encendidas** apaga el efecto solo, que es del propio mod y esta tanda se negó a dar por hecho) ·
U3 (sin casco, Head directo, y lo mismo con las aviators) · U4 (cambio de mapa: siguen puestas y son
las mismas) · U5 (el kill-switch) · U6 (acoplar y extraer arrastrando, más la negativa del loot:
*"pasando al cargo crate sin dramas con drag and drop a los cascos en la misma ventana"*).

**La tanda salió en dos pasadas y la segunda no la disparó un check en rojo, sino el USO.** La
primera vuelta confirmó lo que la planilla medía; lo que faltaba —extraer un sub-slot con el host en
la mochila, acoplar arrastrando, y el ícono— apareció al **usar** el inventario, no al verificarlo.
Es la contracara de la lección de B3/B4/B5 (*el hallazgo sale del campo de notas de un check que
PASÓ*): acá salió de que el autor jugara con lo que la planilla ya había dado por bueno. **Una
planilla mide lo que se propuso medir; el uso mide lo que falta.**

**FRONTERA DECLARADA, y la midió el propio U5** (§13, con su fila): apagar `cargo_nvg_register` con
gafas **ya en el inventario** deja esas entradas **huérfanas de def** —celda sin nombre ni ícono— y
**se destruyen al dropearlas**. El autor lo verificó y lo acepta como está: *"cambió los ítems por
una data vacía que se esfumó al hacer drop como corresponde"*. Es coherente con el resto del módulo
—una def que no existe no puede representarse en el mundo, y el saneo del import descarta igual lo
que no conoce— y el kill-switch existe para un servidor que **nunca** montó el catálogo, no para
apagarlo a mitad de partida.

**El otro dato que dejó U5, y vale más que el check:** con la convar en 0 el mod vuelve a funcionar
**exactamente como el original** —E sobre unas gafas te las equipa y la entidad desaparece—. Eso es
COR-5 medido, no declarado: el archivo no está *apagado*, está **inerte**, y se nota porque el
tercero recupera su comportamiento entero.
**Sin commitear** (GIT-7). Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 52. Las luces en el wheel: el tercer grupo de chips (roadmap #46) `[APLICADO 2026-07-29]`

Roadmap **#46**, pedido del autor, la otra mitad del frente de #47: aquella tanda **POSEE** las
gafas, ésta las **ACCIONA** — junto con la linterna del jugador y cada dispositivo toggleable
(luz/láser/IR) del arma ARC9 en mano. El motivo, en palabras del autor: **la G era a la vez el
wheel de Cargo y su linterna**, y ese roce es exactamente lo que esta integración mata: la lista
viaja en la tecla del wheel —que ya es hold— y la tecla de linterna queda **libre y sin tocar**.
Cubre además lo que ni TLS ni el radial propio de ARC9 cubren: **un solo dispositivo** (el radial
exige ≥2) y fuentes que no están en el arma en mano.

Diseño: [`../../dev/Cargo_TLS_Referencia.md`](../../dev/Cargo_TLS_Referencia.md) (TLS es referencia
de IDEA — escrito contra TFA, ni una línea ni un asset se portan; su premisa sobre el NVG es
anterior a #47 y se corrigió acá). Forma: **`mockups/cargo_wheel_lights_mock_v1_1.html`** (bloques
01-05; el 06/07/08 aprobados y **DIFERIDOS** — ver roadmap) con sus dos capturas hermanas. PROMPT:
`dev/PROMPT_cargo_tls_luces.txt`.

- PARCHE 1 — feat(ui): **el registro de fuentes** (`CARGO.Wheel.RegisterLightSource(id, spec)`,
  §17.8). **Tercer precedente vivo del patrón** tras `StatusPanel.RegisterBar` (§11) y
  `Capture.RegisterWorldPickup` (#47) — no se inventó nada. La lista **se registra, no se
  hardcodea**: un chemlight que mañana sea ítem de Cargo entra sin tocar el wheel, y el dueño de su
  lógica es su módulo (CRG-1). `available` corre **al abrir** (lo único que TLS hace bien de
  entrada: su lista se arma en el hold, no por frame); `state` corre por frame porque el tránsito
  anima; `expand` opcional convierte una fuente en N chips (los dispositivos, uno por slot).
  **Una fuente que no está NO se adivina** (CRG-32 aplicado a la columna).
- PARCHE 2 — feat(ui): **el tercer grupo de chips** — un grupo, NO un anillo nuevo (§17.6: los
  sectores *equipan*, los quick *usan*, las luces *togglean* — tercer verbo, grupo propio, misma
  forma rectangular y pick no-angular). Convar `cargo_wheel_lights_anchor`, default **`left`**.
  `ResolveAnchors` **no se tocó** y `GroupCells` se reusa **tal cual** — el empuje se aplica sobre
  las celdas ya resueltas. La regla nueva es `CARGO.Wheel.LightsPushOut` (pura, cubierta por el
  harness): las luces **SÍ comparten lado, desplazadas hacia AFUERA** — 0 lado libre / 1 quick o
  tools visible / 2 los tres (inalcanzable vía convars: `ResolveAnchors` nunca deja a quick y tools
  juntos; la función igual contesta todo su dominio, que es lo que el mock dibuja en su bloque 04).
  `gapGrupo` = **24 @1080p** contra los 8 entre celdas, unidad de theme escalada por `L.scale` —
  jamás un literal suelto. Orden fijo hacia afuera **quick → tools → lights**, sin marca de
  agrupación (una cuarta forma en una superficie de tres — el mock la rechazó). Aviso único por
  `Corpus.Log` al activarse el empuje.
  **El chip: tres canales que no se pisan** (mock bloque 02, §0.ter c): estado = relleno
  (`accentDim`/`cell`), tránsito = borde `amber` + barra de 4 px + ícono al 55% (único canal que
  usa amber), hover = sube relleno y borde un escalón y jamás toca el color de estado. **El modo
  NO va como texto en el chip**: barras de 3 px al pie, una por **emisor activo** (léxico: luz =
  accent, láser = green, iluminador IR = orange, láser IR = red; 46/22/14 px según N), y el nombre
  completo vive en el hub. **Regla del pie**: sólo se dibuja lo que está pasando — nada de rieles
  vacíos. Recorte heredado, colores del theme (el teñido DGL4 re-tiñe gratis), pintado y commit en
  `pcall` (CRG-25).
- PARCHE 3 — feat(ui): **las tres fuentes** (`client/corpus_cargo_lights.lua`, header con las
  firmas verificadas contra `dev/other/` — CRG-24, nada de memoria):
  **(1) Torch** — pinta `ply:FlashlightIsOn()`; commit por el único net nuevo (PARCHE 4).
  **(2) NVG** — aparece si `GetNWInt("nvg", 0) ~= 0`. **Decisión declarada** (la primera página
  del PROMPT la exigía): el chip pregunta por la **NW y no por el ítem equipado** — la NW es lo
  que `arc_vm_nvg` va a accionar (el mod gatea en ella), y desde #47 **es** la resolución de Cargo
  replicada; preguntar al snapshot re-implementaría `EquippedShortName` en el cliente, una segunda
  ruta para la misma verdad. Commit `RunConsoleCommand("arc_vm_nvg")`, cliente puro; **jamás se
  escribe la NW `nvg`** (es de #47, escritor único). **El toggle es asíncrono y el chip pinta el
  TRÁNSITO** (CRG-64, entry 53): el delay se lee de la variante viva —`EquipDelay` al encender;
  ninguna variante declara `UnequipDelay`, así que el apagado invierte sin ventana— y durante la
  ventana el chip no afirma ni el estado viejo ni el nuevo. El rechazo es **MUDO** en esta tanda
  (bloque 07 del mock, diferido): re-togglear durante la ventana no ejecuta nada — re-entrar en
  `ArcticNVGs_Toggle` encolaría un segundo timer dentro del mod.
  **(3) Dispositivos ARC9** — uno por slot con `.Installed` cuyo att declare `ToggleStats` +
  `ToggleOnF`. Commit = el del radial propio (`cl_move.lua:153-163`): `wep:ToggleStat(addr)` +
  `wep:PostModify()`, client-side, replica solo (`SendWeapon`) — el mismo contrato de **CRG-23**,
  cero lógica de server. **La bifurcación de §0.ter (a) se resolvió a favor de las barras**:
  `GetFinalAttTable` **fusiona** `ToggleStats[ToggleNum]` sobre la tabla del att
  (sh_0_stats.lua:86-89), así que los emisores del modo activo (`Flashlight`/`Laser` + flags IR)
  son **datos** — las barras jamás se fabrican parseando el string del modo, y un att que no
  exponga emisores va sin barras con el modo sólo en el hub. El nombre del dispositivo se lee de
  la tabla SIN fusionar (`ARC9.GetAttTable`): el merge pisa `PrintName` con el del modo. **El
  estado pertenece al slot del arma** (`slottbl.ToggleNum`) — Cargo no persiste nada; guardarlo en
  el jugador es el defecto de TLS que no se porta.
- PARCHE 4 — feat(ui): **el único net del grupo** (`server/corpus_cargo_lights.lua`, archivo solo
  a propósito: la excepción de la **enmienda a CRG-30** se audita de un vistazo).
  `Corpus.Net.Register("cargo", "torch")`, **sin payload**, y en el server
  `ply:Flashlight(not ply:FlashlightIsOn())`. Decisión del autor, opción (b) del diseño: la (a),
  `impulse 100`, quedó descartada **con medición** — ARC9 lo secuestra
  (`sh_move.lua:360-369`) cuando hay un dispositivo toggleable en la mano y la misma tecla haría
  cosas distintas según lo que lleves. Sin estado, sin persistencia, sin validación que fabricar:
  **CRG-6 sigue en pie**. Y `impulse 100` **no se intercepta jamás** — el hallazgo caro de TLS
  (§6 del diseño): su `return true` incondicional en `PlayerBindPress` mata la linterna del engine
  para toda la sesión y rompe el toggle de attachments de ARC9.
- PARCHE 5 — feat(icons): **los TRES íconos propios** (lo cambió el mock, §0.ter b: ninguno sale
  de `atttbl.Icon` — todos los dispositivos comparten un único símbolo genérico; costo aceptado y
  declarado: dos dispositivos apagados en la misma columna se ven idénticos y los distingue el
  orden y el hub). **Decisión de sede, dicha**: viven en **`materials/corpus_cargo/wheel/`**
  (`flashlight.png`/`nvg.png`/`device.png`, los PNG de 64 exportados del mock — a 1080p la celda
  pide ~48 y el de 64 sobra) y **se versionan**: son arte propio del proyecto (COR-17 sólo excluye
  assets de terceros; no suben al banco del framework porque los consume un solo módulo — COR-10).
  El gate `file.Exists` va igual: sin el PNG montado el chip cae a su inicial, degradación honesta
  (COR-5), nunca un error. **Los 5 PNG de TLS no se copian** — licencia silenciosa, y no hacen
  falta.

### 2.ª pasada (planilla V, ronda 2) — la enmienda estaba incompleta

La ronda 1 quedó **contaminada** por un bind doble (la G del autor era wheel **y** `impulse 100`,
y el wheel pollea la tecla en vez de pasar por binds: cada apretón togleaba la linterna por su
cuenta y soltar sobre el chip la invertía otra vez — **neto cero**, indistinguible de "no pasó
nada"). Limpio el bind, la ronda 2 destapó dos cosas.

- PARCHE 6 — fix(ui): **el chip del torch nunca pintaba ON, y el motivo es de diseño.**
  `ply:Flashlight` es server-only en las **DOS** direcciones; la 1.ª pasada **midió** la
  escritura y **asumió** la lectura, usando `ply:FlashlightIsOn()` desde el cliente. Medición
  en juego, con el haz visiblemente pintando una pared y **sin** ARC9 en la mano:
  `lua_run print(Entity(1):FlashlightIsOn())` → **true**, `lua_run_cl
  print(LocalPlayer():FlashlightIsOn())` → **false** (el método **existe** en el cliente — lo
  primero que se descartó —, simplemente no vale ahí). Remedio: el server publica el estado
  real en **`NW2Bool "cargo_torch"`** (`CARGO.Lights.PublishTorch`), el mismo vehículo que ya
  usa el multiplicador de peso de #34 — **replicación del engine, no un segundo mensaje: la
  enmienda a CRG-30 sigue en UN intent**. El espejo lee el **engine y no nuestros toggles**,
  porque Cargo no es el único escritor por diseño (la tecla libre, y el `PostModify` de ARC9
  que apaga la linterna con un att `ToggleOnF` en mano); alimentarlo con nuestros commits se
  desfasaría en cuanto escribiera otro, que es **CRG-64 en el otro tiempo verbal**. 4 Hz, el
  ritmo del espejo cinturón↔pool de §16, más publicación inmediata en el receiver para que el
  commit propio no espere un tick. **La lección es de método**: CRG-24 existe para no asumir la
  API de un tercero, y acá se asumió la del **engine** — el tercero que más fácil se olvida que
  lo es.
- PARCHE 7 — fix(ui): **`LightState` dejó de tragarse el error.** Su `pcall` devolvía `{}` sin
  loguear, así que un `state()` que **tiraba** era pixel por pixel idéntico a uno que decía OFF
  — y sus dos hermanas de al lado (`available`, `expand`) ya logueaban. Esa asimetría es lo que
  dejó al defecto del PARCHE 6 sobrevivir una ronda entera de planilla. Log único por error
  distinto, para que un fallo por frame no inunde la consola. Es la misma lección de la G y la
  del stub que no guardaba estado, esta vez **adentro del código**: un instrumento que no
  distingue "roto" de "no pasó nada" no es un instrumento.
- PARCHE 8 — feat(ui): **la lista de luces se re-arma al cambiar de arma con el wheel abierto**
  (V8). La lista se arma al abrir y el teclado sigue vivo a propósito, así que un chip de
  dispositivo de un arma que ya no llevás no puede decir la verdad de nada. Se re-arma cuando
  —y **solo** cuando— cambia el arma en mano: sigue sin ser por frame, que era la parte de la
  regla que importaba. **La otra salida que propuso el autor, bloquear las teclas 1-7 mientras
  el wheel está abierto, se rechazó a propósito**: el wheel no es dueño del teclado, y pisar un
  bind en silencio es justo lo que este grupo existe para evitar. El tránsito del NVG
  **sobrevive** el re-armado (vive en un upvalue del archivo de fuentes, no en el chip), así que
  CRG-64 sigue pintando a través de un cambio de arma a mitad de ventana.

### 3.ª pasada (planilla V, ronda 3) — la sección cierra 9/9, y dos notas de checks que PASARON

- PARCHE 9 — fix(ui): **ARC9 le robaba el cursor al wheel.** Cambiar de arma con 1-7 con el
  wheel abierto y caer en un arma ARC9 dejaba el cursor muerto: no se podía seleccionar nada.
  Con un arma HL2 no pasaba, y **ese contraste es lo que señaló la causa** — el `Deploy` de
  ARC9 llama `gui.EnableScreenClicker(false)` **incondicionalmente** (`sh_deploy.lua:125`). El
  screen clicker es **estado global** y no somos su único consumidor. `Open` sigue siendo el que
  lo prende y `Close` el que lo apaga; esto solo lo sostiene mientras ya decidimos que tenía que
  estarlo. **El defecto era anterior al PARCHE 8**, pero el parche 8 bendijo el gesto y lo volvió
  alcanzable.
  **Su primera forma estuvo MAL y la planilla lo agarró (V10, ronda 4).** Re-afirmaba el clicker
  en **cada frame pintado**, justificado en que *"la llamada es idempotente"* — una **asunción
  sobre una API del engine que nunca se verificó**, y falsa: el cursor volvía pero **parpadeaba**
  y no podía clickear nada. Llamarlo por frame **re-inicializa** el clicker en vez de dejarlo
  quieto. La forma correcta **lee el estado antes de escribirlo** —
  `if not vgui.CursorVisible() then gui.EnableScreenClicker(true) end` —, que además recupera el
  cursor ante **cualquier** tercero que lo apague y en cualquier momento, que era el objetivo de
  la versión por frame. `vgui.CursorVisible` es la misma sonda que `Open` ya usaba unas líneas
  más abajo. **Es la tercera vez en esta tanda que el defecto es una API asumida en vez de
  medida** (CRG-24 vale también para el engine), y la única de las tres cometida *escribiendo el
  parche que documenta las otras dos.**
- **CORRECCIÓN de doc — `UnequipDelay` sí existe, y el código nunca compartió el error.** El
  texto afirmaba en cuatro sedes que *"ninguna variante declara `UnequipDelay`, así que el
  apagado invierte sin ventana"*. **Es falso**: las **12 variantes `shades*`** (las aviators)
  declaran `UnequipDelay = 0.25`; las de tubo no. La 1.ª pasada leyó las GPNVG y **generalizó de
  una muestra** — la misma familia de error que CRG-24 nombra, y la hermana del error del PARCHE
  6, pero al revés: allá la prosa tenía razón y el código asumió, acá **el código tenía razón y
  la prosa afirmó de más**. La rama por dirección de `client/corpus_cargo_lights.lua` existía
  justamente para no caer por un `or` encadenado, así que con aviators el chip **ya pintaba** su
  tránsito de 0,25 s al apagar. Corregidas §17.5, §17.8, el header del archivo y el stub del
  harness — que **había heredado la afirmación falsa del doc**, y por eso el harness no podía
  contradecirlo: no existía en el stub un apagado con ventana que medir.

Lo destapó la nota de un check en **PASA** (V7: *"el NVG tiene animación al hacer off también"*),
que es la cuarta vez en este bloque que el hallazgo sale del campo de notas y no de un rojo.

Harness **639** (eran 636), **3 checks nuevos** (el apagado con ventana de las aviators, su
etiqueta `ON → OFF`, y la precondición que los separa) y **1 reversión en negativo**: quitar la
rama por dirección pone en rojo **3** checks a la vez.

**Frontera nueva, medida y NO peleada** (§13): con un arma ARC9 con dispositivo **desplegada**,
el haz de la linterna del engine **no se dibuja** — y vuelve al cambiar a un arma sin
dispositivo, con el estado de server en `true` todo el tiempo. Es supresión de **render**, no de
estado. La línea de ARC9 que lo hace **no quedó ubicada** y se dice así en vez de citar una sin
verificar. Consecuencia declarada: en ese caso el chip dice ON y no se ve luz, y **el chip no
miente** — la linterna está encendida.

Verificación offline tras la 2.ª pasada: harness **636** (eran 630), **6 checks nuevos** (2 del
chip contra el espejo —uno de ellos **en negativo**, que el engine encendido NO alcance para
pintar ON— y 4 del espejo server, incluido el que fija que sigue al engine y no a nuestros
commits). **3 reversiones verificadas en negativo**, 5 rojos distintos: el chip leyendo el
engine otra vez (2), el receiver sin publicar en el acto (2) y el espejo leyendo un cache
propio en vez del engine (3). El stub de jugador ganó `SetNW2Bool`/`GetNW2Bool` **con estado de
verdad**, por la misma razón de siempre. Fuera de cobertura, y se dice: el PARCHE 7 vive en la
ruta de pintado (`HUDPaint`, ya declarada fuera de alcance arriba) — se verifica en juego.

**Interacción de terceros medida y NO peleada** (va a la planilla): el `PostModify` de **server**
de ARC9 apaga la linterna del engine cuando el arma en mano tiene un att `ToggleOnF`
(`sh_attach.lua:143-145`, lo dispara `ReceiveWeapon` al replicar) — togglear un dispositivo con la
linterna prendida la apaga. Es la regla del propio mod sobre su tecla F compartida. Y el regalo
verificado en código (falta verlo en juego): `cl_light.lua:16-24` lee `nvg_on` para conmutar los
flashlights `FlashlightIR` a infrarrojo — NVG + luz IR del arma ya se entienden solos.

Verificación offline: harness **630** (eran 588), **42 checks nuevos** (39 client + 3 server: el
torch se prueba con su capa AISLADA — el receiver contra el estado real del stub, sin wheel en el
medio, §0.bis 2). **Las 8 reversiones se verificaron EN NEGATIVO**, una por capa, y cada una pone
en rojo el check que nombra la regla: el gate de `available` cegado (3 rojos, cae "nada se
adivina"), el empuje anulado (5), el pick ciego a las luces (2), el receiver del torch vaciado (1),
el tránsito sin rastrear (los 5 de CRG-64), el commit sin `ToggleStat` (3 — "el modo CAMBIÓ de
verdad" depende de la mutación real del stub), los emisores afirmados sin datos (1, el del
no-parseo), y **el stub de linterna sin guardar estado** (1 — un stub que no invierte vuelve
indemostrable lo que mide, §0.bis 3).

**LO QUE EL HARNESS NO PUEDE PROBAR, Y HAY QUE DECIRLO** (§0.bis 6). El entorno son DOS mods
ajenos: todo ARC9 y todo el NVG corren contra **stubs escritos por nosotros** — los checks afirman
*"la lógica hace lo correcto CON estas tablas"*, jamás *"éstas son las tablas de los mods"*. Los
stubs guardan estado de verdad (§0.bis 3): el SWEP falso **cambia de `ToggleNum` con el wrap real**
y el stub de linterna invierte de verdad — sin eso, "el dispositivo cambió" sería indistinguible de
"no pasó nada". Fuera de cobertura offline por construcción: que `arc_vm_nvg` exista y anime (VManip
no está en `dev/other/` — el mod lo hard-depende en `cl:24` sin comprobarlo; en la instalación del
autor está montado y el toggle funciona, confirmado en la planilla U2, pero acá no se afirma nada de
su comportamiento), que el secuestro de `impulse 100` ocurra (es un hecho del engine y del mod, no
de una función pura — está medido, no harnesseado), la replicación real de `SendWeapon`, y el
render HUDPaint en sí. Todo eso es planilla **V** y nada más.

EN JUEGO: planilla **V** (ver entry 53, que comparte la pasada).

---

## 53. CRG-64 acuñada y CRG-30 enmendada: el tránsito honesto y el intent que costó una norma `[APLICADO 2026-07-29]`

**CRG-64** — *"Un indicador de un estado ASÍNCRONO de un tercero pinta el TRÁNSITO; jamás pinta el
estado viejo como si fuera el actual."* Sede: `Cargo_Architecture.md` **§17.5**, junto a CRG-32, de
la que es **la hermana en el eje del TIEMPO**: aquella prohíbe inventar un dato que no se tiene,
ésta prohíbe afirmar uno que ya no vale. Fuerza: INVARIANTE. El caso que la acuña está **medido
contra el código vivo del mod** (CRG-24): `ArcticNVGs_Toggle` espera 1,325 s (el `EquipDelay` de la
variante; 1,41 en las aviators) antes de invertir `nvg_on` — un chip que pintara la NW mentiría más
de un segundo. La duración jamás se hornea (regla del propio mock): se lee de la tabla viva, por
variante y por dirección.

**ENMIENDA a CRG-30** — el ID se conserva, no es una norma nueva. Decía: *"cero lógica de server
nueva, cero mensajes de red nuevos, y jamás intercepta slot8"*. Queda: cero lógica de server nueva
**para el front-end de ARMAS**; el grupo de LUCES suma **un único intent de toggle sin payload**,
que no lleva estado ni validación. Lo que la norma protegía —no fabricar rutas paralelas de
inventario— sigue intacto (CRG-6 en pie). Sede enmendada en §17.1 **con la medición del secuestro
del impulso como fundamento**, y el `titulo` de `ids.yaml` corregido **en el mismo parche** —
dejar ahí una frase que el código contradice es exactamente lo que el flujo §7.1 llama un yaml
desactualizado.

§17 ganó la subsección **§17.8** (el tercer grupo entero: registro, anclaje y empuje, los tres
canales del chip, las tres patas con su procedencia). **§13.1 se re-derivó del árbol** (FLU-27):
eran 23 `net.Receive` de servidor y son **24** — el nuevo es un intent sin payload y cae en la
categoría que CRG-6 ya protege (21 → 22). Y **§10.3 ganó la fila de los toggles**: la API de ARC9
se usa también para **ACCIONAR**, no solo para attach/detach — mismo contrato CRG-23, client-side,
replica solo.

La letra **V** se registró en `familias_excluidas` en el MISMO parche, ANTES de usarse (FLU-30), y
no se recicla (FLU-07). Es la sexta sección de planilla de Cargo y la primera del frente
ACCIONAR: P=B1, Q=B3, R=B4, S=B5, U=#47.

**EN JUEGO — planilla `V`** (sección nueva de la planilla de CARGO, la misma URL que P-U). **Al
menos uno es de RECHAZO o de AUSENCIA a propósito** — V5 lo es: que sin ARC9 y sin el NVG la
columna quede con un solo chip y la consola limpia es tan verificable como lo demás.

- **V1** · **la linterna del jugador** se enciende y se apaga desde el chip, **con un arma ARC9
  con dispositivo toggleable en la mano** — que es justo el caso donde `impulse 100` fallaba. Y la
  tecla de linterna del jugador **sigue funcionando por su cuenta**: no se interceptó nada.
  *Nota esperable, medida en código y no peleada:* togglear un **dispositivo** con la linterna
  prendida la apaga — es el `PostModify` de server de ARC9 (su regla sobre la tecla F), no un bug
  nuestro.
- **V2** · **el NVG**: el chip lo enciende y lo apaga, y **durante el segundo y pico del tránsito
  el chip NO miente** (CRG-64) — borde amber, barra llenándose, hub en `OFF → ON`, y ni el relleno
  ON ni el OFF afirmados. Con las gafas puestas por las **DOS rutas de #47** (sub-slot del casco y
  Head directo), porque el chip no debería notar la diferencia. El apagado, en cambio, invierte
  **sin ventana** (ninguna variante declara `UnequipDelay`) — que se vea instantáneo no es un bug.
- **V3** · **los dispositivos ARC9**: un arma con **UN solo dispositivo** —el caso que el radial
  propio de ARC9 no cubre— cambia de modo desde el chip, y el nombre del modo que muestra **el
  hub** es el que ARC9 dice (§0.ter a: el nombre va al hub, no al chip). Las **barras de modo al
  pie** cambian con el modo (los emisores están expuestos y las barras existen); si algún att de
  otro pack no expusiera emisores, ese chip tiene que estar **SIN barras** y no con barras
  inventadas. Repetir con un arma de **DOS** y confirmar que son dos chips independientes.
- **V4** · **el anclaje y el empuje**: con `cargo_wheel_lights_anchor` en el mismo lado que quick
  o que tools, la columna se **desplaza hacia afuera** (24 px de separación entre grupos, orden
  quick → tools → lights) y no se pisa nada, con su línea única en consola.
- **V5** · **AUSENCIA/RECHAZO**: sin arma en la mano (o con una sin dispositivos) la columna tiene
  **dos chips y ya** — no aparecen chips fantasma (CRG-32). Y `cargo_ui_tools 0` no rompe el
  empuje. La mitad fuerte: **sin ARC9 y sin el NVG montados**, la columna queda con **un solo
  chip** (la linterna) y la consola limpia.
- **V6** · **negativa**: el wheel de armas, los chips quick, los de herramienta, el holster y el
  inventario siguen intactos. Esta tanda toca el layout del wheel, que es superficie caliente
  (y los fades/bloqueo del mock — bloque 07 — quedaron DIFERIDOS justamente para no tocar el
  dibujador raíz: esta pasada tiene que dejarlo intacto).

**Y tres CANDIDATOS DEL USO (V7-V9), sumados al entregar la planilla** — la lección de #47 aplicada
ANTES de pagarla otra vez: la planilla mide lo que se propuso medir, el uso mide lo que falta. Los
números no se reciclan (FLU-07):

- **V7** · **la linterna DURANTE el tránsito del NVG.** Encender el NVG y, en plena animación,
  soltar sobre el chip de la linterna: nada revienta, el wheel cierra normal, consola limpia — el
  rechazo de esta tanda es MUDO a propósito. **La NOTA vale más que el estado**: decir si la
  linterna encendió durante la animación o el mod la bloqueó — la diferida (h) del mock **asume**
  que la bloquea y eso nunca se midió (CRG-24). Esta nota ES esa medición.
- **V8** · **cambiar de arma con el wheel abierto** y soltar sobre un chip de dispositivo del arma
  ANTERIOR. La lista se arma al abrir: el toggle aplica al arma que el wheel MOSTRÓ (aunque ya no
  esté en la mano) o no hace nada — las dos lecturas son honestas. Lo que no puede pasar: un error
  en consola, o togglear un dispositivo de la nueva arma que nunca se mostró.
- **V9** · **el regalo verificado en código, confirmado en juego**: con las NVG encendidas, el
  iluminador/láser **IR** del arma se ve; a ojo desnudo, no — es ARC9 leyendo la señal del mod por
  su cuenta (`checknvg`), sin una línea nuestra.

**RESULTADO, dos rondas.** Ronda 1: **V2, V4 y V6 en PASA** —V2 pone **CRG-64 en juego** por las
dos rutas de #47, así que la norma que acuñó esta tanda ya tiene su evidencia—; V1 y V7
**contaminados** por la G doble-bindeada, V3/V8/V9 sin correr por falta de attachments, V5 sin
correr. Ronda 2, con el bind limpio y attachments en mano: **V3, V5, V8 y V9 en PASA**, y **V1 y
V7 en ✗ destapando el defecto del PARCHE 6** (entry 52). Lo que la ronda 2 dejó, y vale más que
los estados:

- **V7 REFUTÓ la premisa de la diferida (h)** del mock. Asumía que el mod de NVG bloquea la
  linterna durante su animación; el grep del mod ya mostraba que **no la toca en ninguna línea**,
  y la medición lo confirmó: **la linterna encendió en pleno tránsito**. La diferida (h) queda
  sin ese supuesto cuando se ejecute.
- **V9 pasó a medias y el resto es de ARC9**: el láser IR se ve con las NVG encendidas (el
  regalo, confirmado en juego), la **luz** IR no. Mecanismo probable, leído en el mod y **no
  peleado**: `cl_laser.lua` re-evalúa `checknvg` en cada dibujo, pero `cl_light.lua` solo
  re-crea las luces `if anydrawn and nvgon != checknvg(self)` (:186-187) — la recuperación queda
  condicionada a que ya se esté dibujando algo, que es lo que está suprimido. Predicción
  falsable si alguien lo retoma: ciclar el dispositivo con el NVG ya encendido debería
  destrabarlo.
- **V5 (c)** —desmontar ARC9 y el NVG— quedó **N/A** por decisión del autor; (a) y (b) alcanzan
  para el check.

Ronda 3, con los parches de la 2.ª pasada: **los nueve en PASA**. V1 confirma el espejo por sus
tres caras —el chip enciende, apaga y **sigue en ON al reabrir**; con dispositivo ARC9 se
mantiene; sin dispositivo el haz vuelve— y V8 confirma que la lista se re-arma. **Las dos notas
volvieron a valer más que los estados**: la de V7 corrigió una afirmación falsa de cuatro sedes
del doc (`UnequipDelay`), y la de V8 destapó que **ARC9 le roba el cursor al wheel** en el gesto
que el PARCHE 8 acababa de bendecir. Las dos están arriba, en la 3.ª pasada de la entry 52.
Ronda 4, un solo check: **V10 en ✗** — el PARCHE 9 en su primera forma dejaba el cursor vivo pero
**parpadeando**, y la nota lo describió con precisión suficiente para diagnosticarlo sin volver a
juego (*"vivo pero parpadeando"* es un síntoma distinto de *"muerto"*, y esa distinción es la que
señaló al parche en vez de al mod). Ronda 5, con el guard: **V10 en PASA**.

**La sección V cierra 10/10 el 2026-07-29, en cinco rondas.** Los tres defectos que encontró son
**el mismo error con distinto disfraz — una API asumida en vez de medida**: `FlashlightIsOn`
supuesta legible en el cliente (no lo es), `UnequipDelay` supuesta ausente en todas las variantes
(12 la declaran), `EnableScreenClicker` supuesta idempotente (no lo es). **Y la tercera se cometió
escribiendo el parche que documenta las dos primeras.** Queda dicho así a propósito: CRG-24 manda
verificar las APIs de terceros contra `dev/other/`, y **el engine también es un tercero** — el que
más fácil se olvida que lo es.

Planilla (sección nueva de la de Cargo, la misma URL que P, Q, R, S y U):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 54. La celda ancha del grupo de luces (roadmap #48, paso 1) `[APLICADO 2026-07-29]`

Roadmap **#48 (A)**, pedido del autor al cerrar el #46: *"faltaban cosas del wheelmenu, por
ejemplo el botón alternativo"*. **No es diseño nuevo**: es la diferida **(g)** del #46, aprobada
el 2026-07-27, con el **bloque 06** del mock congelado
(`mockups/cargo_wheel_lights_mock_v1_1.html`) como sede — no se re-diseñó nada. PROMPT:
`dev/PROMPT_cargo_wheel_celda_ancha_y_click.txt`. Un solo archivo de código
(`client/corpus_cargo_wheel.lua`) y sus docs: **ni una norma nueva, ni un mensaje de red, ni una
línea de server**.

- PARCHE 1 — feat(ui): **la celda deja de ser una constante y pasa a ser POR GRUPO**, que es el
  único cambio estructural de la tanda y el que el propio mock declara en su bloque de cierre
  (*"el resolvedor deja de tener una sola constante de celda"*). `GroupCells` cerraba sobre `chip`;
  ahora toma `(w, h)`, y **la regla de qué celda le toca a cada grupo sale como función pura** —
  `CARGO.Wheel.GroupCellSize(anchor, w, h)`, que **clampea `w` a `h` cuando el eje es
  horizontal**. Sale pura por el precedente de `ResolveAnchors` y `LightsPushOut`, y por el motivo
  de siempre: **lo que se rompe en silencio se prueba offline**.
  Escribirla como **clamp** tiene una consecuencia de diseño que vale más que la línea: la
  degradación de la celda ancha **no es un caso especial en ninguna parte del código — ES el
  clamp**. El pintor tampoco necesita bandera: pregunta `c.w > c.h` y la celda le contesta su
  propia anatomía.
- PARCHE 2 — feat(ui): **la celda ancha**, convar `cargo_wheel_lights_wide` (cliente, archivada,
  default **0** — la forma de hoy **no cambia sola para nadie**). 150×56 @1080 escaladas por
  `L.scale`, **jamás un literal suelto**. Las **dos condiciones duras son del mock y no se
  negociaron**: **(1) sólo con anclaje `left` o `right`** —con `top`/`bottom` el grupo **degrada
  solo a 56×56 en el MISMO build**, sin aviso y sin error: las dos anatomías coexisten, no es un
  modo que se elige una vez—; **(2) quick y tools siguen cuadrados siempre**, y lo dicen **en el
  call site**: la celda ancha es la excepción del **panel de luces**, no un modo nuevo del menú.
  Lo que gana es lo que el mock prometió: **el modo se lee sin hoverear**. La celda ancha pinta
  los **mismos tres canales** del #46 —estado / tránsito / hover— **más** el nombre y la línea
  secundaria: es más ROOM, no un lenguaje nuevo.
- PARCHE 3 — refactor(ui): **una sola sede para la línea secundaria** (`LightSecondary`:
  tránsito > nombre del modo > ON/OFF) y **una sola para la fracción del tránsito**
  (`TransitFrac`). El hub ya las pintaba desde el #46 y la celda ancha las pinta **sin hover**;
  dejarlas duplicadas era garantizar que derivaran el día que aparezca un quinto estado. Mismo
  comportamiento, verificado por el harness que ya cubría el hub.
- PARCHE 4 — refactor(ui): **los números de referencia @1080 pasan a UNA tabla** (`REF`: hub 120,
  anillo 305, margen 46, celda 56, gap 8, gap de grupo 24, ancha 150), que consumen tanto
  `BuildLayout` como las puras. No es prolijidad: **una segunda copia de 305/46/56/24 es el bug
  del mock v1 otra vez** —dos sistemas de escala desincronizados—, y la cuenta del extremo tenía
  que leer los números **del layout real**, no los suyos. Un check que se afirma sobre números que
  él mismo se pasó es el hermano del stub que hereda la afirmación de la prosa (#46).

**LA ADVERTENCIA DEL MOCK SOBRE EL DESBORDE ESTÁ MAL, Y SE CORRIGE CON LA CUENTA.** El bloque 06
avisa que con empuje la columna *"se sale de pantalla en 1280×720"*. No se sale. El grupo crece
hacia **AFUERA desde la misma línea de anclaje**, así que el extremo queda en
`305 (anillo) + 46 (margen) + push·(56+24) + 150 (celda)` = **501 / 581 / 661** @1080 para empuje
0 / 1 / 2. El layout **escala por ALTURA**, de modo que a 1280×720 son **~334 / ~387 / ~441 px
reales** contra los **640** de media pantalla: **entra**. El caso apretado no es 16:9 sino 4:3, y
**el push 2 que dispara el peor número es inalcanzable por convars** (`ResolveAnchors` nunca deja a
quick y tools en el mismo lado; la pura contesta igual todo su dominio). Queda fijado en el harness
sobre `CARGO.Wheel.GroupOuterExtent` **para que nadie re-herede la advertencia sin recalcularla** —
que es exactamente el error que el #46 pagó con el `UnequipDelay` copiado de la prosa. **El mock no
se edita**: es sede congelada y lo que dibujó se implementó; la corrección vive **acá, en el
roadmap y en §17.8**.

**El empuje no lo cambia la celda ancha**, y se verificó en vez de asumirse: el multiplicador es el
fondo del **OCUPANTE** —quick o tools, cuadrados por definición—, y lo ancho sólo extiende el borde
exterior del propio grupo. `LightsPushOut` y `ResolveAnchors` **no se tocaron** (ni firma ni
dominio), y `PickAt` **tampoco hizo falta tocarla**: ya leía `c.w`/`c.h` por celda. Eso se
**confirmó con un check**, no de vista — incluido uno que pickea a **148 px** del origen de la
celda, que con un 56 horneado sería imposible.

**Una decisión declarada donde el mock no dibujó el caso.** El bloque 06 reemplaza las barras de
modo por el **nombre** del modo, que dice más de lo que ellas codifican, y por eso la celda ancha
no las pinta. Pero existe un dispositivo que expone emisores **como dato** y **no declara
`PrintName`** de su modo (ARC9 lo permite: `HasEmitterData` / `ModeNameOf` en
`client/corpus_cargo_lights.lua`) — ahí no hay nombre que reemplace nada, y el hub las omite por el
**mismo** motivo, así que quitarlas dejaría esos emisores **invisibles en todas partes**. La celda
ancha conserva las barras **exactamente cuando no hay nombre de modo que mostrar**. Se dice acá en
vez de resolverse en silencio.

Harness offline: **669** (eran 639), **30 checks nuevos** y **5 reversiones verificadas en
negativo**, una por capa — el clamp del eje, la celda por grupo, la cuenta del extremo, el pick
sobre celda no cuadrada, y la fuga de la excepción a quick/tools. Lo que **no** se puede probar
offline y hay que decirlo: **el render en `HUDPaint`** — eso es planilla.

### Cierre — planilla `W` en 6/6 sobre el paso 1, una sola ronda (2026-07-29)

**W2** (la celda ancha en los dos laterales, con el modo legible sin hoverear) · **W3** (**la
degradación**: con la convar en 1 y anclaje `top`/`bottom` el grupo vuelve a 56×56 **solo**, sin
aviso — el check de AUSENCIA de la sección) · **W4** (compartiendo lado: el empuje correcto y **sin
salirse de pantalla**, que es la advertencia del mock confirmada como falsa **en juego** y no sólo
en la aritmética) · **W5** (el tránsito del NVG dentro de la anatomía nueva — CRG-64 sobrevive el
cambio de celda) · **W6** (**negativa**: con la convar en 0 el wheel es exactamente el de la
sección V) · **W7** (la superficie del #46 intacta: los tres canales del chip siguen pintando).

**Sin defectos y en una sola ronda**, que es lo primero que pasa en este módulo desde la planilla
P — y la explicación honesta no es que la tanda estuviera mejor escrita, sino que **era chica y
tenía UNA incógnita, y esa incógnita se sacó de la tanda en vez de resolverse a mitad de camino**.
Las cinco reversiones en negativo cubrieron cada capa antes de llegar al juego, así que la planilla
no tuvo que hacer de primer filtro.

**Lo que la planilla NO trajo, y queda dicho:** los seis pasaron **sin nota**. La regla que el #46
dejó probada por repetición —cuatro de sus cinco hallazgos salieron del campo de notas de un check
en PASA— no se ejercitó acá. En particular **W4 pedía la resolución de pantalla** y no vino: la
cuenta del desborde está verificada para 16:9 y el caso apretado declarado es 4:3, así que ese dato
sigue siendo el único hueco de la corrección al mock.

**W1 NO cierra esta entry y no le pertenece**: es la medición del **paso 2** (el click), y quedó en
N/A por un defecto del instrumento, no del wheel — el fragmento abreviado que se copió a mano
**contaba los clicks pero no dibujaba nada**, o sea era invisible, y `cargo_probe_reset` ni existía
en esa copia. Es la misma familia de error que esta planilla viene midiendo desde el #46: **un
instrumento que no puede distinguir "roto" de "no pasó nada" no es un instrumento** — sólo que esta
vez el que no distinguía era el instrumento mismo. Sonda completa reescrita en su lugar.

Planilla (sección nueva de la de Cargo, la misma URL que P, Q, R, S, U y V):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 55. El click en el wheel: una segunda forma de comitear, aditiva (roadmap #48, paso 2) `[APLICADO 2026-07-29]`

Roadmap **#48 (B)**, la otra mitad del pedido del autor: *"también, como extra, que se pueda
clickear en el wheelmenu"*. **CRG-31 no se deroga** — soltar la tecla sobre algo sigue comiteando
exactamente como siempre, que es el gesto ya en el músculo; el click se **suma** para el pausado.
Decisión del autor, 2026-07-29. PROMPT: `dev/PROMPT_cargo_wheel_celda_ancha_y_click.txt` §5.

**LO PRIMERO, PORQUE ES LO QUE HIZO QUE ESTA ENTRY EXISTA: la incógnita se midió antes de escribir
una línea.** `gui.EnableScreenClicker` se traga los clicks **a propósito** —nada dispara mientras
apuntás el wheel, y ésa es la razón de encenderlo—, y que el **estado** del botón siguiera siendo
legible por debajo era **plausible y no estaba verificado**. El PROMPT lo puso como condición de
arranque y no como algo que se descubre a mitad de la implementación. Se midió en juego (planilla
**W**, check **W1**) y salió que **sí**: el screen clicker usa la misma maquinaria que el menú
contextual del propio GMod, así que el cursor se mueve y el botón se lee. **Si hubiera salido que
no, esta entry no existiría** — el plan B se decidía con el autor, porque no hay `dev/other/`
contra el cual verificar un hook de mouse.

**La medición costó una ronda, y no por el motor sino por el instrumento.** La primera sonda que
llegó a juego era el **fragmento abreviado** de la explicación copiado a mano: contaba los clicks
pero **no dibujaba nada**, o sea era invisible, y su comando de reset ni existía en esa copia. Es
la misma familia que este bloque viene nombrando desde el #46 —**un instrumento que no puede
distinguir "roto" de "no pasó nada" no es un instrumento**— sólo que esta vez **el que no
distinguía era el instrumento**. La sonda definitiva mide **con baseline**: cuenta los clicks CON
y SIN el wheel abierto en columnas separadas, porque sin esa segunda mitad un cero sería
indistinguible de un lector que no sirve.

- PARCHE 1 — feat(ui): **el click comitea por la ruta que ya existía.** Convar
  `cargo_wheel_click` (cliente, archivada, default **1** — a diferencia de la celda ancha, ésta
  **suma** un gesto y no cambia ninguno, así que la convar está para apagarla si molesta, no para
  optar por entrar). El commit es `CARGO.Wheel.Close(true)` → `Commit`: **mismo pick re-corrido al
  instante, mismo `pcall` de CRG-25, cero lógica de commit nueva**, ni un mensaje de red, ni una
  línea de server.
  **Polleo con detección de flanco en el MISMO `Think` de la tecla**, no un hook de mouse nuevo —
  y eso tiene una consecuencia que vale nombrar: **no estrena una sola API del engine**.
  `input.IsButtonDown` es la función que ese hook **ya llamaba por frame** para la tecla del
  wheel; sólo se le pregunta por `MOUSE_LEFT` en vez de un enum `KEY_`, que viven en el mismo
  espacio de `BUTTON_CODE`. Era exactamente lo que el PROMPT pedía: **precedente dentro del propio
  archivo en vez de API nueva**.
- PARCHE 2 — la trampa obvia, y **no hizo falta código para cerrarla**: si el click comitea, el
  wheel cierra, y `Close` sale temprano con `state` nil, así que **soltar la tecla después no
  dispara un segundo commit**. Un solo commit por apertura **por construcción**. Lo que sí hizo
  falta fue **probarlo en negativo**: la reversión que comitea sin cerrar —que es la
  implementación plausible y equivocada— hace caer ese check y sólo ése.

**EL FLANCO SE OBSERVA SIEMPRE, ABIERTO O CERRADO**, y es la única decisión no obvia del parche.
Si el estado del botón sólo se actualizara mientras el wheel está abierto, **abrirlo con el botón
de disparo ya apretado leería como pulsación nueva y comitearía en el acto** — el wheel
parpadearía y se cerraría solo. Observar es gratis; actuar está gateado. Se sigue por frame para
que el gesto heredado no exista.

**UN CHECK QUE NO MEDÍA LO QUE DECÍA, ENCONTRADO POR LA VERIFICACIÓN EN NEGATIVO Y NO POR LA
CORRIDA VERDE.** El check de ese flanco heredado pasaba con la implementación buena **y también
con la mala**: el bloque del click corre **antes** que el de la tecla, así que en el frame de
apertura `state` todavía es nil y cualquier versión pasa — el defecto vive un frame más tarde. El
check ahora corre **un `Think` de más** y recién ahí distingue. Es la tercera vez en este bloque
que un check nace sin distinguir (la primera fue el registro de recogidas del #47, la segunda el
stub que no guardaba estado del #46), y las tres las destapó **revertir el arreglo**, nunca la
corrida en verde. **Un check que no se ve caer no prueba nada** deja de ser una consigna y pasa a
ser el procedimiento que encuentra los defectos de los checks.

**El botón derecho no se toca en esta tanda** (alcance negativo del PROMPT): una acción alternativa
—ciclar el modo de un dispositivo hacia atrás, que ARC9 soporta vía `ToggleStat(addr, -1)`— es
bloque propio.

Harness offline: **676** (eran 669), **7 checks nuevos** y **4 reversiones verificadas en
negativo** — el click que no comitea, el commit sin cerrar (la trampa), la convar ignorada y el
flanco sólo-mientras-abierto. Lo que **no** se puede probar offline: que el click se sienta bien
en la mano, y que el screen clicker siga dejando leer el botón en cada caso real — eso es planilla.

### Cierre — planilla `W` en 10/10, y el #48 entero entregado (2026-07-29)

**W8** (el click comitea sobre las tres superficies — sector, quick y chip de luz) · **W9** (las
dos trampas: **un solo commit por apertura**, y abrir el wheel con el disparo ya apretado no
dispara nada) · **W10** (**negativa**: con `cargo_wheel_click 0` clickear no hace nada y soltar la
tecla comitea igual que siempre — **CRG-31 no depende de esta convar**).

**Dos rondas para toda la sección, y ninguna se perdió en el motor.** La única que costó una vuelta
fue la medición, y por el **instrumento**. Con las diez en PASA quedan cerradas las dos entries del
#48 y **la tanda entera**.

**El hueco que el paso 1 había dejado abierto, cerrado por el autor:** la resolución es **16:9**, o
sea que la cuenta del desborde de la entry 54 —501/581/661 @1080, ~334/~387/~441 px reales contra
640 de media pantalla— está **verificada en el caso real de este servidor**, no sólo en la
aritmética. El **4:3 sigue declarado como el caso apretado y sin medir**, y así queda anotado: es
una frontera conocida, no un olvido.

**Lo que la sección deja como método, y es lo único que vale reescribir:** el hallazgo de esta
entry —un check que pasaba con la implementación buena **y con la mala**— no salió de la corrida
verde sino de **revertir el arreglo**. Es la tercera vez en este bloque. La conclusión operativa ya
no es «verificá en negativo para probar que el check sirve», es más fuerte: **la reversión es el
único instrumento que audita al instrumento.**

Planilla (sección W, la misma URL que P, Q, R, S, U y V):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 56. El click que no cierra: ciclar sin reabrir el wheel (roadmap #49) `[APLICADO 2026-07-29]`

Roadmap **#49**, pedido del autor al cerrar el #48: *"me gustaría una opción para que el clic no
cierre el wheelmenu, sino para que uno apriete sin cerrar, así puedo ciclar el attachment de arc9 en
una sola pasada sin mover tanto el mouse"*. **No estaba en el alcance del #48** —aquella tanda
declaró que el click comitea y CIERRA, y eso se confirmó en W8—, así que es bloque propio con convar
propia, **apagada por default**.

**LAS DOS DECISIONES SON DEL AUTOR, y las dos se consultaron antes de escribir una línea**, porque
la segunda toca CRG-31 y ese no es un llamado que se hace solo:

- **ALCANCE: sólo los chips de luz.** El motivo lo da el vocabulario que el propio wheel ya tenía
  (§17.6/§17.8): los sectores **equipan**, los quick **usan**, las luces **togglean** — y de los
  tres verbos, **togglear es el único repetible**. Ciclar un dispositivo ARC9 es literalmente
  apretar N veces; equipar dos veces la misma arma significa **enfundar** (el re-press de #22) y
  usar dos veces un quick **gasta dos ítems**, que era el riesgo real del modo. El click sobre
  sector, quick o tool sigue comiteando y cerrando **exactamente como el #48**.
- **AL SOLTAR: sólo cierra, y sólo si ya hubo un click.** Es la pregunta cara. Si CRG-31 se
  respetara al pie de la letra dentro del modo, ciclar tres veces y soltar sobre el mismo chip
  dispararía un **cuarto toggle que nadie pidió**. La regla que quedó: **si hubo un click sostenido
  en esa apertura, soltar únicamente cierra; si no hubo ninguno, soltar comitea igual que siempre**.
  Así **CRG-31 queda literal en el camino default** y la excepción sólo existe después de un gesto
  que el jugador pidió explícitamente. La alternativa —mover el cursor a la deadzone antes de
  soltar, que es la regla de cancelación que ya existe— se descartó porque pedía justo el movimiento
  de mouse que el pedido quería evitar.

- PARCHE 1 — feat(ui): convar `cargo_wheel_click_sticky` (cliente, archivada, **default 0**). Un
  click sobre un **chip de luz** ejecuta el toggle **en el lugar** y deja el wheel abierto, así que
  N clicks son N ciclos sin reabrir. Mismo `Commit`, misma disciplina de `pcall` (CRG-25), y el
  **rechazo mudo no cambia**: una luz en tránsito no re-entra y el menú se queda arriba. El pick se
  **re-corre en el click**, por el mismo motivo por el que `Close` lo hace — el cursor pudo moverse
  desde el último frame pintado—, así que los dos gestos honran dónde está el cursor **por una sola
  regla**.
- PARCHE 2 — refactor(ui): la política del soltar vive en un `CloseOnRelease` propio, **no dentro de
  `Close`**. `Close` se queda siendo un "comitea o no, vos decidís" tonto —el camino del click
  necesita la respuesta contraria— y la decisión de gesto queda donde se toma el gesto. Lo consumen
  el poll de `Think` **y** el concommand `-cargo_wheel`, que así no se desincronizan.

**UN CHECK QUE NO DISTINGUÍA, OTRA VEZ, Y OTRA VEZ LO DESTAPÓ LA REVERSIÓN.** El check del alcance
—«sobre un sector el click comitea y cierra»— **pasaba también con una versión donde el sticky se
derramaba a todos los objetivos**: contaba commits, y el conteo es idéntico; lo que cambia es si el
menú quedó abierto, que el conteo no ve. Se arregló haciendo lo único que lo distingue: **un segundo
click**, que sobre un wheel cerrado no comitea nada. Es la **cuarta vez en este arco** que un check
nace sin distinguir, y van **dos seguidas** encontradas por revertir el arreglo en vez de por la
corrida verde.

**Y EL HARNESS DEJÓ DE MENTIR SU PROPIO TOTAL.** Perseguir un desajuste de ±1 en el conteo destapó
que el número que **todos los docs citan** salía de **grepear `[ok]` en stdout**, y ahí corren dos
escritores a la vez —los `print` de Lua y los banners de realm de Python—: el banner llegaba a
**tragarse una línea entera**, así que el total saltaba entre corridas. Ahora cada pasada lleva su
contador (`CHECKS_OK`) y el script **imprime su propio total**, que es el que se cita. El número no
cambió de valor —**683**, y `639 + 44` cuadra exacto—, cambió de **procedencia**: dejó de depender de
quién ganó una carrera de stdout. Es la misma lección que esta saga viene pagando en cada tanda,
aplicada por una vez **al instrumento que mide a los instrumentos**.

Harness offline: **683** (eran 676), **7 checks nuevos** y **3 reversiones verificadas en negativo**
— el sticky derramado a todos los objetivos, el soltar que comitea igual (el cuarto toggle), y la
convar ignorada.

### Cierre — planilla `X` en 4/4, una sola ronda (2026-07-29)

**X1** (ciclar un dispositivo ARC9 en una sola pasada, sin reabrir) · **X2** (el alcance: sobre un
sector el click sigue comiteando y cerrando) · **X3** (tras clickear, soltar sólo cierra; sin
clicks, comitea como siempre) · **X4** (**negativa**: con la convar en 0, el #48 intacto).

Las tres notas del autor confirman las dos decisiones que él mismo había tomado antes de que se
escribiera una línea: *«se siente como lo quería, es apretar a gusto el NVG y las linternas»*,
*«sí sigue cerrando correctamente»* y —sobre el soltar, que era la decisión cara— *«sí funciona
intuitivamente»*. **Consultar las dos bifurcaciones antes de escribir se pagó solo**: ninguna de
las dos volvió como defecto.

**Y la nota de X1 trajo el bloque siguiente, que es la quinta vez en este arco que un hallazgo sale
del campo de notas de un check que PASÓ**: *«sobre los ARC9 lo único que pediría sería que con el
clic secundario del ratón se pudiera ciclar en reversa»*. Va como roadmap **#50**, con la API ya
verificada contra `dev/other/` (CRG-24) en vez de asumida — ver ahí.

Planilla (sección X, la misma URL que P, Q, R, S, U, V y W):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 57. El botón derecho cicla en reversa (roadmap #50) `[APLICADO 2026-07-29]`

Pedido del autor **en la nota de un check que PASÓ** (X1): *"sobre los ARC9 lo único que pediría
sería que con el clic secundario del ratón se pudiera ciclar en reversa (No sé si ARC9 lo permite,
tendrías que investigar)"*. Es la **quinta vez en este arco** que el hallazgo sale del campo de
notas y no de un rojo.

**LA INVESTIGACIÓN QUE PIDIÓ, CONTRA EL CÓDIGO VIVO Y NO DE MEMORIA** (CRG-24, `dev/other/`).
`SWEP:ToggleStat(addr, val)` — `sh_attach.lua:718-735`, 18 líneas: `val = val or 1`, suma el paso a
`ToggleNum`, y **el wrap está escrito en LAS DOS direcciones** (`> #ToggleStats → 1` y
`< 1 → #ToggleStats`). O sea que **ARC9 anticipó el paso negativo**, no es algo de lo que nos
estemos zafando. Dos consecuencias que salieron de leerla y no de suponerla: **no llama a
`PostModify`** —el commit tiene que seguir pagándolo, igual que el de ida— y un dispositivo de **un
solo modo** envuelve sobre sí mismo en ambos sentidos, o sea un no-op honesto y jamás un error.
Y una tercera que contesta la pregunta obvia antes de que la haga el juego: es la **ÚNICA**
definición de `ToggleStat` en todo `dev/other/` —grepeada sobre los 20 y pico de mods que hay ahí—,
o sea que **ningún pack de armas la pisa** (ni ARC9MW ni los de EFT) y la reversa no depende de qué
pack tengas montado. Es exactamente la clase de cosa que el #46 pagó por asumir con `UnequipDelay`:
*generalizar de una muestra*. Acá la muestra son todos.

- PARCHE 1 — feat(ui): el registro de fuentes de luz gana **`toggleBack(ply, wep)` OPCIONAL**. Su
  ausencia es la respuesta honesta y no una carencia: **una linterna no tiene reversa**, y tampoco
  la tiene nada más del wheel — *desequipar no es "equipar hacia atrás"* y un quick slot no tiene
  undo. Sólo el chip de dispositivo ARC9 lo declara.
- PARCHE 2 — feat(ui): el botón derecho se pollea **en el mismo `Think` y por el mismo camino** que
  el izquierdo (`ClickCommit(back)`), porque el gesto es idéntico salvo el sentido: **un solo
  código, no una segunda copia que pueda derivar**. Hereda gratis el modo del #49 (con
  `cargo_wheel_click_sticky` cicla sin cerrar; sin él, comitea y cierra) y la misma convar
  `cargo_wheel_click` lo apaga. `CARGO.Wheel.Close` gana un segundo parámetro opcional,
  retrocompatible.

**TRES DEFECTOS DE CHECK, LOS TRES DESTAPADOS POR LA REVERSIÓN Y NINGUNO POR LA CORRIDA VERDE.** Es
lo que esta entry deja como material:

1. **El `and/or` que cae hacia adelante.** `back and chip.toggleBack or chip.toggle` convierte *"esta
   fuente no puede ir para atrás"* en *"fue para el lado equivocado"*. Escribirlo largo parecía
   redundante —el llamador ya rechaza el derecho sobre un chip sin reversa— **y no lo era**: el pick
   corre **dos veces** (una para decidir, otra adentro de `Close`) y el cursor puede moverse entre
   ambas, así que el chip que llega no es necesariamente el que pasó el guard. La primera versión
   del check no ejercitaba esa divergencia y **pasaba con las dos formas**; ahora el harness mueve
   el cursor entre pick y pick a propósito.
2. **El guard de ausencia medía menos de lo que decía.** Quitarlo no hacía caer nada, porque un
   derecho sobre un chip sin reversa "no hace nada" igual. Pero **sí hace algo invisible**: entra al
   camino sticky y marca que hubo click, con lo cual **soltar la tecla deja de comitear** (#49). Un
   botón sin efecto se comía el gesto de siempre. El check nuevo suelta la tecla después del no-op.
3. Y el de siempre: **un check que sólo cuenta commits no ve si el menú quedó abierto**.

Harness offline: **694** (eran 683), **11 checks nuevos** —incluidos tres sobre el dispositivo ARC9
**real** del bloque del #46, no sobre una fuente sintética— y **4 reversiones verificadas en
negativo**: el paso `-1`, el `and/or`, el guard de ausencia y la fuente sin reversa.

### Cierre — planilla `Y` en 3/3, una sola ronda (2026-07-29)

**Y1** (*«está bien»*: el derecho retrocede y el izquierdo avanza) · **Y2** (**ausencia**: *«sí,
sólo afecta a ARC9 con dispositivo y a nada más»*) · **Y3** (el gesto de siempre intacto tras un
derecho sin efecto: *«clic derecho sobre la linterna y luego arma no comió nada»*).

**Y la nota de Y3 volvió a traer el bloque siguiente** — sexta vez en el arco que un hallazgo sale
del campo de notas de un check que PASÓ: con un arma ARC9 con dispositivo en la mano, el chip de
linterna dice ON y **el jugador puede creer que la linterna del engine está disponible cuando en
realidad la del arma se la queda**. Va como roadmap **#51**.

Planilla (sección Y, la misma URL que P, Q, R, S, U, V, W y X):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 58. La linterna tapada por el dispositivo del arma (roadmap #51) `[APLICADO 2026-07-29]`

Pedido del autor **en la nota de Y3, un check que PASÓ** — sexta vez en el arco: *"al tener el arma
de ARC9 con dispositivo se bloquee visualmente la linterna con tachas, mejor que rojo se puede
copiar las tachas que tienen los otros bloques del wheelmenu así como el quickslot, pues un jugador
puede pensar que la linterna del engine está disponible, cuando en realidad la de ARC9 la captura"*.

**EL DIAGNÓSTICO CORRIGE UNA AFIRMACIÓN DE NUESTRO PROPIO DOC.** §13 y la entry 53 declaraban que el
haz no se dibuja porque es *"supresión de render de ARC9"*. **El código no dice eso.** Grepeada la
base entera, ARC9 toca la linterna del ENGINE en **un solo lugar** —`sh_attach.lua:143-144`, que en
`PostModify` la **apaga** si el arma tiene un att `ToggleOnF`— y **no existe ninguna ruta de
supresión de render** para ella: todos los `render.SuppressEngineLighting` de la base están en VGUI,
FLIR y presets, o sea en previews, nunca en el render del mundo. Su `cl_light.lua` administra
**sus propias** projected textures y nada más.
Así que el mecanismo real **no está identificado**, y la hipótesis que queda —el presupuesto de
projected textures del engine, que las luces del dispositivo consumen— **se declara como hipótesis y
no se escribe como hecho**. Es exactamente el error del `UnequipDelay` del #46 otra vez: **una
inferencia redactada como medición**. Lo que sí está medido es la conducta, y es lo que se pinta.

- PARCHE 1 — feat(ui): el `state()` de una fuente de luz puede devolver **`blocked = "<motivo>"`**.
  El chip se pinta con el **tramado a 45° de los quickslots bloqueados**, en `border` y **no en
  rojo** (decisión del autor: el rojo lee como error y esto no lo es; el jugador ya sabe que ese
  tramado significa *"ahora no"*). Va **sobre** el relleno y el ícono y **debajo** de las barras del
  pie, recortado con `render.SetScissorRect` — **CRG-28**, que estas mismas rayas ya pagaron
  sangrando fuera de un quickslot. Funciona en **las dos anatomías** porque sigue `c.w`/`c.h`.
  En el hub cambia el **hint**, no el estado: dice quién se quedó con la luz.
- PARCHE 2 — feat(ui): la fuente `torch` declara `blocked` cuando el arma en mano lleva un att
  `ToggleOnF`. **El predicado es el de ARC9, no uno nuestro**: es literalmente lo que pregunta
  `sh_attach.lua:143`, leído de la misma lista de slots que los chips de dispositivo ya recorren —
  **ni una API nueva** (CRG-24 re-verificado antes de escribir).

**`on` NO se falsea a `false`, y ésa es la decisión de diseño de la entry.** La linterna **está**
encendida; decir OFF sería la mentira que **CRG-32** prohíbe, y además volvería a esconder el estado
real cuando el jugador cambie de arma. *"Encendida pero no la vas a ver"* es un **tercer** hecho, no
una variante de OFF — y por eso vive en su propio campo. **Estado y disponibilidad son preguntas
distintas**, y confundirlas es lo que hacía que el chip fuera cierto e inútil a la vez.
**El toggle sigue funcionando**: la acción no está rechazada —la linterna enciende igual y se verá
al guardar el arma—, así que bloquear el commit sería inventar un rechazo que el mod no impone.

Harness offline: **698** (eran 694), **4 checks nuevos** y **2 reversiones verificadas en negativo**
—falsear OFF, y tapar con cualquier attachment en vez de con `ToggleOnF`—, con la **ausencia por
partida doble**: sin arma en mano, y con un ARC9 **sin** dispositivo.

### Cierre — planilla `Z` en 3/3, una sola ronda (2026-07-29)

**Z1** (*«se ve tapado tanto en wide como normal, todo bien»*) · **Z2** (**la ausencia**: *«el
tramado desaparece correctamente, sólo aparece con dispositivo»*) · **Z3** (la superficie de las
cuatro tandas anteriores intacta).

**Y la nota de Z3 corrigió una decisión de diseño de ESTA misma entry** — séptima vez en el arco que
el hallazgo sale del campo de notas de un check que PASÓ. Acá se había declarado que *"bloquear el
commit sería inventar un rechazo que el mod no impone"*, y **el argumento del autor es mejor**: el
mod **sí** lo impone, en diferido — su `PostModify` apaga la linterna del engine en cuanto ciclás el
dispositivo. O sea que encenderla ahí no es una acción válida que estuviéramos estorbando: es una
acción **que el mod deshace solo**. Va como roadmap **#52**.

---

## 59. El commit sobre una fuente tapada se rechaza, y lo dice (roadmap #52) `[APLICADO 2026-07-30]`

Pedido del autor **en la nota de Z3**, séptima vez en el arco que el hallazgo sale de un check que
PASÓ: *"lo importante es sólo bloquear el clic a la linterna del engine mientras estás con el arma
ARC9 con dispositivo, pues al cambiar de luz del dispositivo el mod ya apaga la linterna del engine
[...] tal vez un destello rojo al hacer clic sea suficiente"*.

**CORRIGE LA DECISIÓN DE DISEÑO DE LA ENTRY 58, Y HAY QUE DECIR POR QUÉ.** Aquella declaró que el
toggle seguía funcionando porque *"bloquear el commit sería inventar un rechazo que el mod no
impone"*. **Es falso, y el autor tenía el dato**: el mod **sí** lo impone, sólo que en diferido —
`sh_attach.lua:143-144`, ya verificado en la 58, apaga la linterna del engine **en cuanto se cicla
el dispositivo**. Encenderla bajo ese arma no es una acción válida que estuviéramos estorbando: es
una que **muere en el siguiente click**. Dejarla pasar era comitear algo con fecha de vencimiento.
El razonamiento viejo miraba el instante; el del autor mira la secuencia.

- PARCHE 1 — feat(ui): una fuente que se declara `blocked` **rechaza el commit**, en las dos
  direcciones (izquierdo y derecho) y por las dos rutas (click y soltar). **Una sola regla,
  `BlockedChip`, con dos consumidores**: `Commit` la usa para rechazar y `ClickCommit` lee la misma
  respuesta para decidir que **un rechazo NO cierra el menú** — cerrar es cómo el wheel acusa recibo
  de un commit, y no hubo ninguno; cerrar ahí sería una segunda mentira encima de la que este
  bloque existe para sacar.
- PARCHE 2 — feat(ui): **el destello**. UN pulso rojo sobre la celda entera que se desvanece en
  250 ms, pintado **al final**, sobre el tramado y sobre las barras. **No** es el bloque 07 del mock
  (dos parpadeos + fade del menú + cue sonoro), que sigue diferido porque arrastra el dibujador
  raíz. Los dos canales dicen cosas distintas y se leen juntos: **el tramado es "esto no está
  disponible", el destello es "y acabo de rechazar lo que apretaste"**.

**El destello se resuelve en el pintor y NO se guarda en el chip**, y eso no es capricho: la lista
de chips **se re-arma al cambiar de arma** (§17.8, V8), así que cualquier cosa colgada de la tabla
del chip se evaporaría a mitad de la ventana — el mismo motivo por el que el tránsito del NVG vive
en un upvalue del archivo de luces y no en el chip.

**Frontera declarada, y se dice en vez de esconderse:** al **soltar la tecla** sobre una tapada el
rechazo ocurre igual, pero el wheel se cierra —no hay alternativa, la tecla está arriba— así que
**el destello no llega a verse**. El tramado ya avisó; el destello es para el gesto que puede
quedarse mirando, que es el click.

Harness offline: **700** (eran 698), **2 checks nuevos** y **1 reversión verificada en negativo**.
El segundo check es el que hace que el primero distinga: **destapada, el MISMO gesto sobre el MISMO
chip sí comitea**. Sin esa mitad, "no mandó el intent" sería indistinguible de un chip que no
funciona.

### Cierre — planilla `AA` en 3/3, y con ella el ARCO ENTERO (2026-07-30)

**AA1** (el rechazo con destello, y el wheel queda abierto) · **AA2** (**la contraprueba**: guardado el
arma, el MISMO clic sobre el MISMO chip enciende y cierra) · **AA3** (**negativa**: *«no hay drama en
nada, funciona como corresponde»*).

**Y lo que más dice esta sección es lo que NO trajo.** Las siete anteriores terminaron con una nota
que abría el bloque siguiente —X salió de W, Y de X, Z de Y, AA de Z—; **ésta no abrió ninguno**. La
cadena se detuvo sola, que es la señal de que la superficie convergió y no de que dejamos de mirar:
AA3 recorrió a propósito todo lo de las cinco tandas y volvió sin nada.

**EL ARCO, EN UN PÁRRAFO.** Roadmap **#48 a #52**, entries **54-59**, dos días, **23 checks de
planilla en cinco secciones y ni una sola ronda perdida por un defecto de código** — la única que
costó una vuelta fue la medición de W1, y por el **instrumento**. Harness **639 → 700**: **61 checks
nuevos y 19 reversiones verificadas en negativo**. Ni una norma nueva, ni un mensaje de red, ni una
línea de server en las cinco tandas.

**Las tres reglas de método que deja, y las tres se pagaron:**
1. **La reversión es el único instrumento que audita al instrumento.** Siete checks nacieron sin
   distinguir en el arco y **ninguno lo destapó la corrida en verde**: los destapó revertir el
   arreglo y mirar si el rojo aparecía.
2. **Una inferencia no se escribe como una medición.** Encontrado dos veces en nuestros propios
   docs — el `UnequipDelay` del #46 y la "supresión de render de ARC9" de §13.
3. **Un argumento sobre el INSTANTE puede ser falso sobre la SECUENCIA** (la trajo el autor,
   corrigiendo la entry 58): una acción puede ser legal ahora y morir en el gesto siguiente.

Planilla (sección AA, la misma URL que P, Q, R, S, U, V, W, X, Y y Z):
https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9

---

## 60. Hands: el sonido que no existe y el ícono del mod anterior `[APLICADO 2026-07-30]`

Reporte del autor (2026-07-30), dos síntomas con **una sola causa**: el port de la entry 9 se quedó
a medias con los assets del reciclaje. El header del SWEP declara desde entonces *"assets removed on
request of the original authors"*, y **eso era falso en dos lugares** — uno que suena y uno que se ve.

**LAS DOS CAUSAS, MEDIDAS Y NO SUPUESTAS.**

- **El sonido.** `c_arms_apex.mdl` dispara **cuatro eventos de animación POR NOMBRE DE SOUNDSCRIPT**,
  horneados en el modelo: `Apex_Cloth`, `Apex_Cloth_Jump`, `Apex_Gear_Sprint` y `Apex_Gear_Jump`.
  Salieron **del propio .mdl** (volcado de strings del binario), no de la prosa de nadie. El original
  los declaraba en un archivo aparte, `lua/autorun/apexsfx.lua`, sobre `sound/player/gear/*` — y ese
  set de foley de ropa/equipo es **el único** que el port no trajo: los 41 wavs de melee sí están en
  `sound/weapons/`, el de movimiento no. El modelo, en cambio, vino entero y **sigue disparando los
  eventos igual**. De ahí las dos líneas por cada sprint y cada salto en la consola del autor.
- **El ícono.** Los **tres VTF** (`vgui/corpus_cargo_hands`, `_killicon` y `vgui/entities/…`) son
  **byte-idénticos** a los del mod original — verificado por hash contra `dev/other/`. El port los
  **renombró en vez de reemplazarlos**, así que el HUD mostraba las manos de Apex bajo nuestro nombre
  de archivo.

- PARCHE 1 — fix(ui): los cuatro nombres se registran con `sound.Add` contra **`common/null.wav`**,
  el sample mudo del engine (**verificado presente** en `hl2_sound_misc_dir.vpk`, que GMod monta).
  **Mudos y no re-vozados a propósito:** volver a sonarlos pide foley de ropa y equipo que este repo
  no tiene y que el acuerdo de reciclaje sacó. El `.mdl` **no se recompila** —sigue la regla del
  port— así que los eventos van a disparar siempre: el único lugar donde la queja puede morir es la
  tabla de soundscripts, y es la que este parche llena.
- PARCHE 2 — fix(ui): **un PNG para las tres superficies.**
  `materials/corpus_cargo/hands_icon.png` (512², renderizado de `assets/cargo_logo_dark.svg`) sirve
  la selección de arma, el killicon y la baldosa del spawnmenu. Los **seis** archivos VMT/VTF se
  borran, con lo que la línea del header deja de ser una promesa y pasa a ser un hecho.

**TRES APIS VERIFICADAS CONTRA LA FUENTE INSTALADA, NINGUNA DE MEMORIA** (CRG-24 y la lección de la
entry 53: *el engine también es un tercero*):

1. `killicon.Add` construye su material con `Material(name)`
   (`lua/includes/modules/killicon.lua:33`), o sea que **acepta un PNG**. El color se **multiplica**
   contra la textura, por eso pasa blanco y no el naranja de antes: el logo trae su propio color.
2. La baldosa del spawnmenu sale de `SWEP.IconOverride`, y sin él de `entities/<clase>.png`
   (`gamemodes/sandbox/…/contenttypes/weapons.lua:6`). **Nunca miró `vgui/entities/`**: ese tercer
   VTF ya estaba muerto antes de este parche, y sin `IconOverride` la baldosa nunca fue la nuestra.
3. `SWEP.WepSelectIcon` es un **texture ID** de `surface`, no un material: un PNG no entra ahí. Por
   eso el ícono se pinta tomando `SWEP:DrawWeaponSelection`, que es exactamente lo que hace
   `weapon_base` (`gamemodes/base/entities/weapons/weapon_base/cl_init.lua:34-58`: recuadro **2:1**
   con inset fijo de 10 px, más `PrintWeaponInfo`). El logo es **cuadrado**, así que se ajusta al
   lado corto y se centra — y el inset se escribe como **fracción**, no como los 10 px del base, que
   es la clase de constante que se va a negativo cuando la caja no es la que uno tenía en la cabeza.

**Y el ícono llega al HUD que el autor realmente usa sin un caso especial:** DGL4 no pinta el ícono
por su cuenta, su componente `weaponicon` **llama a este mismo método** para toda clase de la que no
tenga arte propia (`dev/other/DGL4 …/components/weaponicon.lua:99` y `:155`). Un solo override cubre
el HUD default de GMod **y** el suyo.

**Lo que el harness no prueba, y se dice:** `lua/weapons/` no lo carga el manifest, así que estos dos
parches **no tienen cobertura offline** más allá de la sintaxis (verificada con el mismo LuaJIT 2.1
que usa el harness). Los **700** checks siguen verdes porque este cambio no toca nada de lo que
miden — el número no es evidencia acá. Lo que hay que ver en juego es exactamente lo reportado:
correr y saltar con las manos puestas **sin una línea en consola**, y el ícono de Cargo en la
selección de arma, en el kill feed y en la baldosa del spawnmenu.

### 1.ª pasada en juego (2026-07-30) — dos de tres, y el tercero midió una caja que miente

El autor confirmó **las dos mitades del reporte**: *«ya no hay gritos en el developer console»* y el
ícono en el spawnmenu, bien. Lo que salió mal es el mismo ícono en el **selector de armas de DGL4**:
*«se ve medio cortado»*, con la captura al lado.

**Y no era el ícono: era haberle creído a la caja.** La cadena, leída entera y con números (CRG-24 —
el mismo pecado que la entry 53, y acá el tercero no es el engine sino el HUD):

- `selectionpanel:SetSize(144, 72)`, y `AnimatedPanel:PaintFrame` **scissorea a ese rect**
  (`animatedpanel.lua:189`).
- Adentro, el ícono vive en `selection_icon_pos = (72, 36)` con `selection_icon_size = 140`, y
  `weaponicon:PerformLayout` arma la caja como `140 × (140 · 100/140)` = **140 × 100**, centrada
  sobre ese punto → `_y = -14`.
- O sea: **la caja que llega mide 100 de alto y sólo se ven los 72 del medio.** 14 px afuera arriba
  y 14 abajo.

El cuadrado de la 1.ª versión era `math.min(140, 100) · 0.8 = 80` centrado → **4 px comidos arriba y
4 abajo**, que es exactamente el corte plano de la captura.

- PARCHE 3 — fix(ui): el lado del cuadrado sale de **`(wide - 20) / 2`** —la altura que
  `weapon_base` pinta él mismo— clampeada por `tall · 0.8` para el caso de una caja más alta que
  ancha. En DGL4 da **60**: arranca en `y = 20` y termina en `y = 80` contra una ventana visible de
  14 a 86, o sea **6 px de aire por lado** en vez de 4 comidos. Y no es un número elegido para DGL4:
  es el número alrededor del cual está maquetado **todo ícono stock**, así que entra donde entra el
  base.

**LA LECCIÓN, Y ES LA QUE HAY QUE ANOTAR: `tall` no es la altura en la que se puede dibujar.** Un
tercero puede pasarte una caja **más grande que su propio recorte**, y la única forma de saberlo era
seguir el `SetScissorRect` hasta el panel que lo pone. Es la familia de CRG-28 (*`HUDPaint` no tiene
clipping de panel*) vista desde el otro lado: acá el clipping **sí** existe y **la caja no lo
declara**. `wide` en cambio era honesto —140 contra un panel de 144—, y por eso el remedio se apoya
en él y no en el que mintió.

**Frontera declarada:** `selection_size` y `selection_icon_size` son **ajustes del usuario** en DGL4.
Con los defaults el margen es de 6 px por lado; si alguien achica el panel y agranda el ícono, vuelve
a recortar — y ahí el recorte es de su layout, no nuestro. No se lee la config de DGL4 para
compensar: sería atarse a un tercero por un caso hipotético (COR-5).

### Cierre — 2.ª pasada: las tres superficies del ícono, confirmadas (2026-07-30)

*«Si ahora se ve bien en DGL4, kill icon en el hud de HL2 está perfecto. No hay nada más que
tocar.»* Con eso quedan medidas en juego **las tres superficies** —el selector de DGL4, el kill feed
del HUD de HL2 y la baldosa del spawnmenu— más la consola limpia que ya había confirmado la 1.ª
pasada. **Dos rondas y un solo defecto**, y el defecto no estaba en lo que el reporte pedía: estaba
en una **suposición sobre la caja de un tercero**.

**Sin planilla, y se dice por qué:** esto es un parche de dos síntomas reportados, verificables por
observación directa y sin superficie nueva que auditar — una sección de planilla mide una tanda de
diseño, no un ícono que se ve o no se ve. Harness **700**, intacto: este bloque no toca nada de lo
que mide, y el número **no es evidencia de nada de lo que se probó acá**.

**Lo que deja escrito para el próximo port:** *un asset renombrado no es un asset reemplazado.* El
header de este SWEP declaraba «assets removed on request of the original authors» desde la entry 9 y
los tres VTF seguían ahí, byte por byte, bajo nuestros nombres de archivo — la declaración sobrevivió
cincuenta entries porque **nadie la contrastó contra un hash**. Lo mismo del lado del sonido: el port
copió el modelo y dejó afuera el archivo que registraba sus eventos, y el síntoma tardó en aparecer
porque **es ruido de consola y no un error**.

---

## 61. CRG-65: "no entra" nunca significa "se destruye" (roadmap #53, B2) `[APLICADO 2026-07-31]`

La **segunda fuga** del #53, que es independiente del resto del bloque y **cierra sola**: desacoplar
un attachment con la mochila llena lo destruía. El hook `ARC9_PlayerGiveAtt` llamaba a `GiveItem`,
**ignoraba su valor de retorno** y devolvía `true` igual — y `GiveItem` rechaza por peso. ARC9 daba
el att por entregado, Cargo no lo tenía, y nadie lo tenía.

**La tanda encontró un SEGUNDO sitio con la misma forma, y no está en ARC9.** El espejo del pool de
munición (`corpus_cargo_ammopool.lua`) baja la reserva con un `SetAmmo(pool - left)` **incondicional**
y después intenta darle las balas al grid: con el grid lleno, las balas salían de la reserva y no
llegaban a ninguna parte. Los **dos** sitios llevaban encima un comentario afirmando que nada se
perdía — el del pool lo decía literal (*"The rounds are NOT destroyed"*) desde el día que se escribió.

**Decisión del autor (2026-07-30):** *"si no por peso u otra acción, el objeto no puede entrar al
inventario, este objeto debe caer al piso"*. Y la línea que hace la norma aplicable, que salió de
mirar los diez call sites de `GiveItem`: **rechazar** una acción y avisar está bien —levantar un arma
del suelo sobrecargado sigue contestando *"You can't carry that"* y el arma se queda donde estaba,
porque de ahí no se sacó nada—; **consumir** el objeto y avisar es el defecto. Solo la segunda forma
se toca. El aviso no es el remedio: un objeto que ya no existe no deja de no existir porque se haya
impreso una línea.

- PARCHE 1 — feat(inventory): **`Inventory.GiveOrDrop(ply, id, countOrSeed)`**, ruta única, devuelve
  `ok, cayóAlPiso(, uid)`. Y `SpawnDropped`, **extraída de `DropEntry`** en vez de escrita de nuevo:
  el SWEP real cuando es un arma y el gate de mundo lo permite (roadmap #16/#17), el
  `corpus_cargo_item` en todo lo demás, que renderiza su propio blob al spawnear. `DropEntry` pasa a
  usarla, así que **no hay una segunda ruta de spawn que pueda derivar de ésta**.
- PARCHE 2 — fix(arc9): el hook lee el retorno. Si cayó al piso lo **dice** (`Notice`), y sigue
  devolviendo `true` — que es correcto en los dos casos, porque el objeto existe: acá o a tus pies.
  Si la def ni siquiera es nuestra, ahora **no** se suprime el almacén interno de ARC9.
- PARCHE 3 — fix(ammo): el sobrante del espejo va por la misma ruta, y **el comentario que mentía se
  reescribe** en vez de borrarse — dice qué hacía mal y desde cuándo.
- PARCHE 4 — feat(dev): **`cargo_dev_attshare`**, el instrumento de **AB1** (ver entrada siguiente).
- PARCHE 5 — docs: **CRG-65 acuñada**, sede `Cargo_Architecture.md` §4, al lado de CRG-9 — es el
  mismo modo de falla por la otra puerta. Entrada en `ids.yaml` en el mismo parche (FLU-36), más la
  sección **AB** en `familias_excluidas`, registrada **antes** de usarse (FLU-30).

**Harness 700 → 714** (14 nuevos), **dos reversiones verificadas en negativo** — y la segunda dejó el
corolario de verificación de la norma. Revertido el sitio del pool, se pone en rojo **un solo** check:
el del **ledger** (*"LAS TRES ESTÁN EN EL SUELO"*). Los otros dos —"la reserva baja igual", "el grid
sigue lleno"— **pasan con el bug puesto**. O sea: *el check que distingue no es que el grid no crezca
—eso pasa igual si el objeto se evaporó— sino ver el objeto EXISTIENDO en el suelo.* Sin ese check el
bloque entero habría salido verde midiendo nada.

**Lo que el harness NO puede probar, y por eso hay planilla:** el sitio del puente ARC9 no se puede
ejercer offline —sus hooks se cablean dentro del `OnReady` y ahí `ARC9` es `nil`—, así que lo cubierto
offline son el primitivo y el sitio del pool. Que la linterna caiga a tus pies al desacoplarla con la
mochila llena se mide en juego.

---

## 62. AB1: el instrumento de la precondición del #53 `[APLICADO 2026-07-31]`

**Lo primero de la tanda no es código de producción, es una medición** — y su receta estaba mal.

`wep.Attachments` decide la forma del bloque entero: ARC9 nunca copia esa tabla al inicializar (solo
`DefaultAttachments = table.Copy(...)`, `sh_init.lua:43`) y escribe el estado montado **a través** de
ella (`slottbl.Installed`, `sh_attach.lua:19`, alcanzado por `AttachmentAddresses`, que
`BuildAttachmentAddresses` llena **desde `self.Attachments`**, `sh_subatts.lua:8-19`). Si el engine
entrega la misma tabla a cada entidad, dos armas de una clase comparten configuración y *"la config
pertenece a ESTA instancia"* es inalcanzable tal como se pidió. **El engine también es un tercero:**
no se lee, se mide.

**La corrección:** la receta original decía *"con dos armas de la misma clase en el inventario"*, y eso
no se puede correr — **un jugador sostiene UN SWEP por clase**, cosa que la captura ya pagó en juego
(`capture.lua:906-912`, *"You can't take that right now"*). La segunda M4 en el inventario es un
**ítem del grid**, y un ítem no tiene `Attachments` que comparar. Las dos entidades tienen que
coexistir en el **mapa**: una en la mano y otra en el suelo.

- PARCHE 1 — feat(dev): `cargo_dev_attshare [clase]`. Barre las entidades **vivas** de esa clase
  (default: el arma en la mano), imprime por cada una la identidad de `Attachments`,
  `DefaultAttachments` y `AttachmentAddresses`, más el `Installed`/`ToggleNum` de cada slot ocupado.
  **Dos lecturas a propósito:** la identidad de tabla explica el *mecanismo*, pero el veredicto es el
  **set instalado** —la identidad puede dar `false` y el estado compartirse igual por una referencia
  más adentro—. Y **la ausencia se reporta como ausencia**: una sola entidad, o dos peladas
  coincidiendo en nada, sale **NO CONCLUYENTE**, nunca como resultado.

Sin cobertura de harness: es un concommand dev y el harness no los carga. Lo único verificado offline
es la sintaxis.


---

## 63. `blob.atts`: la configuración ARC9 pertenece a la instancia del arma (roadmap #53, B1/B3/B4) `[APLICADO 2026-07-31]`

El cuerpo del #53. **AB1 lo desbloqueó primero, y con un resultado, no con una suposición:**
`wep.Attachments` es **por entidad** — dos AS VAL mod4 vivas a la vez, con `Installed` distinto en el
mismo slot y las tres tablas en direcciones distintas. El invariante que el autor pidió —*la
configuración pertenece a ESTA instancia*— es alcanzable, y el plan B queda descartado **medido**.

**B1 — el árbol, plano y nuestro.** `blob.atts`, nodos de `cat`/`nth`/`att`/`mode`/`sub`, solo strings
y enteros. La clave es **(categoría, ordinal entre hermanos de esa categoría)** y jamás la posición,
y el motivo resultó **más fuerte que CRG-63 en su forma habitual**: el *address* de ARC9 no es solo un
ordinal que un parche del pack puede correr, es el offset de un **aplanado recursivo del build
actual**, así que **se mueve dentro de la misma partida**. Medido en el arma del autor: su PEQ-2
estaba en el address 11 **únicamente porque** el riel del 10 estaba puesto. `nth` existe porque el
handguard del mod4 declara **dos** slots que aceptan `eft_valmod4_side` — el shortname solo no es
clave. Y `PrintName` no es candidato: `ARC9:GetPhrase` ya lo localizó.

**B3 — cosechar en la puerta.** `Inventory.StoreFromEntity` (cargador **y** árbol) reemplaza al
`StoreClip` en las seis puertas donde la entidad muere. `StoreClip` **no se renombra**: lo cita un
acta de auditoría **inmutable** y §10 de la arquitectura, y renombrarlo dejaría esas citas
describiendo algo que ya no existe. Las puertas resultaron **seis y no cinco** — el handoff no listaba
la toma del suelo de una clase duplicada (`capture.lua`) ni el banqueo de Quick Loadouts.

**B4 — re-aplicar por la ruta del propio mod.** `Inventory.ApplyAtts`, con la secuencia de
`ReceiveWeapon` server (`sh_net.lua:141-149`). **Tres cosas que no son obvias y las tres se
verificaron leyendo la fuente:** `FillIntegralSlots` **no** se llama (consume del grid en cada equip —
decisión del autor, y raíz del #42); **`DoInvalidateCache` sí** se llama, y el handoff lo omitía —
sin él el arma sirve stats de antes del cambio; y **el diff de propiedad nunca corre**, porque vive
*dentro* del `if SERVER` de `ReceiveWeapon`, que es lo que hace que re-aplicar sea **gratis**.

**El orden contra el cargador dejó de ser hipotético.** El volcado del arma del autor tiene el
cargador (`eft_val_mag_30s`) y el cartucho (`eft_ammo_9x39_sp5`) **como attachments**, así que el
`Unload` + `SetRequestReload` que dispara un cambio de `ClipSize` es alcanzable con su arma real. El
árbol va **antes** de `RestoreClip` en las dos rutas (equip y drop).

**Decisiones 1 y 4 del autor, implementadas.** Lo acoplado **pesa** (**CRG-66 acuñada**) por la
**misma recursión** que ya pesaba los sub-slots desde el Block 1 — no es un mecanismo nuevo, el att
era invisible por una sola razón: no estaba en el blob. Y el precio **cuenta los atts**, cobrando
**pleno**: un att no tiene condición propia (§10.1), así que una mira de $900 en un rifle destrozado
sigue valiendo $900; el spread sí lo alcanza, porque es margen y no desgaste.

**Nada se pierde por el camino.** Un shortname que el pack borró no puede volver como ítem y se
descarta **con log**; uno que existe pero no encuentra slot **vuelve al inventario**, y sus **hijos se
juzgan uno por uno** — un padre borrado no es motivo para tirar la mira que colgaba de él (CRG-9).
Sin lugar en el grid, al piso (CRG-65). Después de aplicar, el blob se **re-cosecha** de la entidad.

**Harness 714 → 761** (47 nuevos), **once reversiones verificadas en negativo**.

**LA LECCIÓN DE MÉTODO DE LA TANDA, y se pagó dos veces en la misma sesión: un check que CRASHEA no
es un check en rojo.** Dos reversiones —la de la densidad del array y la de la puerta de `Unequip`—
volvieron con **0 y 1 rojo**, y las dos veces la lectura ingenua («el check no distingue») era falsa:
la corrida **moría indexando un nil** y se llevaba puestos todos los checks de abajo. La forma es
siempre la misma: **un check que lee A TRAVÉS de lo que el check anterior acaba de probar que existe**
explota justamente en el escenario que la reversión fabrica. Con navegación nil-safe pasaron a **3 y
8 rojos**. Corolario para el instrumento, no para el código: contar `[FAIL]` no alcanza — hay que
mirar también si la corrida **terminó**.

**Lo que el harness prueba** (761): el round-trip completo del árbol, el negativo que protege
`gm_save` por **partida doble** (lista blanca de claves *y* tipo plano con guarda de profundidad,
porque el `Vector` del harness es una tabla plana y ahí no probaría nada), CRG-63 con un slot
insertado por el pack, los dos rieles hermanos, la rama perdida juzgada por nodo, la densidad, el
orden árbol→cargador, la presencia de `DoInvalidateCache`, la **ausencia** de `FillIntegralSlots`, el
ledger a dos vueltas por la puerta, el peso recursivo, el precio pleno y la negativa de COR-5.
**Lo que no puede probar:** que la linterna siga puesta al recoger el arma del suelo, que el cargador
extendido no vacíe el cargador restaurado, y que 17 atts quepan en el tope de 64 KiB del export LAN.
Eso es la **planilla AB**.

**B5 — docs.** §10.5 nueva (la forma, las tres trampas de secuencia y las dos rutas de pérdida);
**§17.8 enmendada** — decía que Cargo *no* persiste el modo del dispositivo y ahora sí lo persiste,
**sin contradecir su propio espíritu**: el modo viaja colgado de la **instancia**, que es donde esa
misma frase decía que pertenece, y lo que sigue prohibido es guardarlo en el **jugador**; §5 con
CRG-66; y los dos comentarios de `capture.lua` que **nombraban un campo que no existía** — ahora
existe.

### Confirmado en juego (planilla AB, tres rondas, 2026-07-30 y 31)

Diez checks en PASA en la ronda 1 (AB1-AB7, AB9-AB12) y **AB13 cerrado en la ronda 3**: la
configuración viaja, el cargador vuelve con las balas que tenía, el respawn devuelve el arma
vestida, el precio cuenta los atts, y el export con 17 atts pesa 9 KB contra un tope de 64 KiB.

**AB13 cerró por la vía NEGATIVA y no por la resta que la planilla pedía, y eso se dice acá porque
la evidencia no es la misma.** El reporte que lo abrió —el menú C ofreciendo el cargador de otra
UZI guardada— resultó ser **repuestos del propio jugador**: botados los repuestos, el volcado dio
`grid=0` **y** `hook=0` en las siete líneas y el menú dejó de ofrecerlos. Eso prueba que el puente
contesta exactamente lo que el grid tiene y que **no hay un tercer inventario en el medio**, que es
la forma que tendría la duplicación. `ARC9_PlayerTakeAtt` queda descartado como causa de lo
reportado. Lo que **no** prueba —y por eso es una vía distinta— es que montar **descuente** uno del
grid: la resta nunca llegó a correrse, porque botar los repuestos es a la vez lo que produjo la
respuesta y lo que destruyó su precondición. Ver la frontera en la entrada siguiente.


---

## 64. El blob sigue al arma mientras está en tus manos (planilla AB, check AB8) `[APLICADO 2026-07-31]`

**El único rojo de la sección AB**, y es un defecto de diseño mío, no una medición mal hecha.

Las puertas son donde el árbol se **rescata** — la entidad está por morir ahí. Pero montar una mira
desde el menú C de ARC9 **no cruza ninguna puerta**, así que `blob.atts` se quedaba en lo que dijera
la última vez que el arma se guardó. La persistencia estaba bien y **todo lo derivado del blob
estaba viejo**: CRG-66 dice que la instancia pesa lo que lleva, y el peso solo se ponía al día
después de guardar el arma. El precio, igual.

Descartadas dos hipótesis más cómodas antes de tocar nada: los 17 atts del AS VAL **sí** tienen def
(ninguno es `Free`, todos declaran `PrintName`), o sea ~5 kg, nada que la precisión del footer pueda
esconder.

- PARCHE 1 — feat(inventory): **`Inventory.SyncAttsSoon(ply)`**, más `EquippedUidForClass` (una
  entidad dada por `GiveEquipWeapon` no lleva uid encima; el vínculo es la clase, igual que en
  `StripEquipWeapon`). Corre **un tick tarde y a propósito**, que es lo contrario de la regla de la
  puerta y por el motivo contrario: los hooks de inventario disparan **dentro** del diff de
  `ReceiveWeapon`, **antes** de que `BuildSubAttachments` instale el árbol nuevo, así que cosechar
  en el acto grabaría el árbol que el jugador acaba de reemplazar. Acá la entidad no se va a ningún
  lado — nada caduca en un tick; en una puerta nunca es así. Un sync por tick, no uno por att, y si
  el árbol no cambió no hay `Touch` ni refresco de movimiento.
- PARCHE 2 — fix(arc9): los hooks `ARC9_PlayerGiveAtt`/`TakeAtt` lo llaman.

**Harness 764 → 770** (6 nuevos), **dos reversiones**.

**Y LA LECCIÓN, que es la TERCERA vez en la tanda que la reversión audita al instrumento y no al
código.** Los tres primeros checks de AB8 llamaban a `SyncAttsSoon` **directo**: probaban que la
función anda y **no** que el hook la llame. Sacar las dos llamadas de los hooks dejó la corrida
entera **en verde**. Fue necesario exponer `CARGO.ARC9._WireHooks` (interno, mismo precedente que
`Corpus._SelfTest`) para poder disparar el hook de verdad — `WireHooks` corre dentro del `OnReady`
y ahí `ARC9` es `nil` offline, así que sin eso un test **sólo puede llamar a la función**. Con el
cableado ejercido, la misma reversión da 2 rojos.

Es exactamente la forma que el arco #48-#52 nombró —*un check puede nacer sin distinguir*— y las
tres veces de esta tanda tuvieron la misma raíz: **el check no ejercía la ruta que el usuario
recorre**, sino una función que esa ruta llama.

### FRONTERA DECLARADA: esta entrada cierra sin pasada en juego, y no es un descuido

**Los dos checks que la iban a medir se cayeron por motivos distintos, y ninguno fue un defecto.**

**AB8 (rondas 1 y 2) — retirado por decisión, no arreglado.** Medía el peso, que era la consecuencia
visible del sync. Falló las dos veces y la segunda **el autor diagnosticó la causa mejor que el
check**: su MCX 5.56 pesa 2,9 kg y lleva **doce** attachments, así que con el nominal plano de 0,3 kg
las piezas pesarían más que el arma. No es calibración sino **modelo** — en una build EFT la mayoría
de los slots llevan estructura (receiver, cañón, guardamanos, tapa, miras de hierro), y la estructura
**es** el arma. El peso de los atts se difiere al **roadmap #55**; `Instances.AttsWeight` queda
escrita, recurriendo, probada offline y **sin llamar**. Y la regla que dejó, del autor: **cuando un
número no sobrevive el contacto con un caso real, el defecto suele estar en el modelo y no en el
número** — bajarle el nominal habría escondido que la mitad de un build EFT no es carga.

**AB14 (ronda 3) — SIN CORRER**, que es un estado legítimo y no un fallo. Se escribió para recuperar
lo que el diferimiento de AB8 dejó huérfano: que `montado` **suba** en la misma corrida, con el arma
todavía en la mano y sin cruzar ninguna puerta. Su precondición era montar algo, y la ronda 3 no
montó nada — la respuesta de AB13 salió de **botar** los repuestos, no de montarlos. El volcado que
volvió es una foto con `montado=1` fijo: no dice nada sobre el movimiento, que es lo único que este
check mide.

**O sea: la ruta "montar desde el menú C" no se ejerció con números en ninguna de las tres rondas**,
y `AB10` no la cubre —"tres ciclos no consumen repuestos" pasa igual con duplicación puesta—. Lo que
sostiene esta entrada hoy son sus **6 checks de harness con el hook realmente cableado** (por eso
hizo falta exponer `_WireHooks`) más sus dos reversiones. Decisión del autor, 2026-07-31: cerrar con
la frontera escrita en vez de retener la entrada. **Se declara acá en vez de disimularse** — si algún
día el sync se rompe, esta es la entrada que nadie miró en juego.

---

## 65. El peso de la munición cargada (roadmap #56) `[APLICADO 2026-08-01]`

**Las mismas 30 balas pesaban 0,36 kg en el cinturón y 0 kg adentro del arma**, así que
recargar era un descuento de peso. Medido sobre el loadout real del autor (planilla AC, dump de
AC3): cinco armas con el cargador puesto escondían **1,588 kg** — AS VAL 0,620 · KS-23 0,200 ·
PL-15 0,156 · UZI 0,240 · MCX 0,372. No era un olvido — estaba declarado por escrito
desde el 2026-07-30 en la nota de CRG-66 («CASO DECLARADO Y NO CUBIERTO»). Esta entrada lo
cierra. Sede del diseño: **§16.10**, y la norma nueva es **CRG-67**.

### La tanda empezó SIN escribir código, y fue lo que la salvó

Las cuatro preguntas de la semilla tenían respuestas incompatibles entre sí y **la del candidato
obvio resultó falsa**. Escribir primero habría costado el parche entero:

**`Primary.Ammo` NO sirve para resolver el tipo de un arma ARC9.** Está **vacío en la clase**:
`SWEP.Primary.Ammo = SWEP.Ammo` se evalúa al cargar la base, con `SWEP.Ammo` todavía `""`
(`Arc9 Base/…/shared.lua:334-335`), y sólo `Initialize` lo corrige **por instancia**. El wheel ya
lo había pagado en `AmmoTypeOf` y estaba anotado; la semilla proponía justo ese camino.

La respuesta que sí funciona es `SWEP.Ammo` trepando `.Base` con `weapons.GetStored` —no
`weapons.Get`, que deep-copea el SWEP entero para leer un string— más una tabla de escape para
las armas del **engine**, que no son SWEPs. **Censo sobre `dev/other/`, 243 SWEPs con la herencia
resuelta: 215 caen en un tipo que Cargo maneja, 10 en uno que no, y las 12 que no resuelven nada
son exactamente plantillas base y melee/tools** — o sea, lo que no tiene cargador. La respuesta
es limpia porque lo que no resuelve es lo que no tenía nada que resolver.

### La medición que decidió la cadencia, y lo que cambió

El comentario del espejo era el eje del problema: *«firing does not touch the reserve, it drains
the magazine»*. Con el cargador pesando, disparar empieza a mover el ledger, y cada `Touch` es
Save + Sync + Movement. **Se midió antes de preguntar, en vez de estimar:**

| | medido |
|---|---|
| recalcular el peso (`TotalWeight`, record de media partida) | **1,5 µs** |
| snapshot del `Sync` | 10.246 B crudos, **1,1-1,7 KB** comprimidos |
| lo que escribe `SaveRecord` | **6.537 B**, **0,158 ms** de disco real (200 corridas) |
| un Touch por bala a 10 disparos/s | 64 KB/s a disco · 1,58 ms/s · ~11-17 KB/s de red |

**Lo caro de un `Touch` no es la matemática del peso sino el Save y el Sync** — 1,5 µs contra
0,158 ms —, así que lo que había que racionar era el Touch y no la aritmética. Eso convirtió las
tres opciones de la semilla en cuatro, y la medición **descalificó una de las tres**: la (iii)
(«el cargador pesa por su capacidad») no era la más barata sobre el arsenal del autor, porque
**las armas EFT no declaran `SWEP.ClipSize`** —cero líneas en los tres packs de `dev/other/`—: la
capacidad vive en el cargador montado (`ATT.ClipSize`, 134 attachments la setean), o sea que
pesar por capacidad necesitaba caminar el árbol de atts, que es la maquinaria del #55 que este
bloque existía para no tocar.

**Decisión del autor: el poll de 4 Hz que ya corría.** `AmmoPool.SyncHeldClip` al tope de
`Reconcile`. Sin timer nuevo, sin hook de base de arma, sin mensaje de red nuevo: **techo de
cuatro Touch por segundo mientras se dispara, y cero cuando no**. Error máximo declarado: 250 ms
de disparo, y **siempre de más, nunca de menos** — nunca se gana capacidad gratis, que era el
reclamo.

**El re-leído va PRIMERO dentro de `Reconcile` y eso carga peso:** en una recarga el cinturón
está por pagar exactamente lo que el cargador acaba de tomar, y leer el clip en la misma pasada
es lo que hace que las dos mitades caigan en **un solo Touch**. Sin eso el ledger bajaría un
cargador entero y lo recuperaría después, que es el defecto original con otro disfraz.

### Lo que encontró recorrer las rutas de doble conteo

`AmmoPool.UnloadWeapon` llamaba a `Reconcile` —que hace un `Touch` adentro, y ese Touch calcula
el peso— **y recién después** a `StoreClip`. Con el cargador pesando, las mismas balas quedaban
contadas en el cinturón donde acababan de aterrizar **y** en un cargador que ya estaba vacío. Y
no era un parpadeo: **nada vuelve a Touchear después de esa línea**, así que el número inflado
era el que se escribía a disco y el que veía el cliente. El `StoreClip` se adelanta.

Las otras seis rutas se recorrieron una por una y ninguna cuenta doble: `StripEquipWeapon`, el
drop al mundo, el reconciliador de `WeaponDrop`, el banqueo de Quick Loadouts, el
`StripAmmo`+`Push` del spawn y el import LAN.

### La regla de método de la tanda, y la trajo una reversión

**Adelantar el `StoreClip` no pone NADA en rojo.** Medido: la reversión R5 dio **cero** rojos,
porque `SyncHeldClip` encabeza `Reconcile` y lee el mismo cero antes. La propiedad —*una bala se
cuenta una sola vez en el Touch que va a disco*— está sostenida por **dos guardas independientes**,
y hacen falta las dos caídas (R8 = R4+R5) para ponerla en rojo.

De ahí sale la regla: **un check que sobrevive una reversión no está roto, pero no puede reclamar
que prueba el mecanismo — prueba el resultado.** El check quedó reescrito diciendo eso, y el
`StoreClip` adelantado se queda con su motivo dicho: es redundante bajo *esta* cadencia y es el
único que sobrevive si la cadencia cambia.

De paso, **el propio driver de reversiones falló dos veces y las dos son la misma lección del
#53**: buscaba el gate final en `stdout` cuando el gate escribe por `stderr`, así que reportó
«murió antes de terminar» sobre siete corridas que habían terminado bien; y después truncó los
archivos fuente al abrir en `"w"` antes de leerlos. **Contar `[FAIL]` no alcanza, y mirar si la
corrida terminó tampoco alcanza si el detector que lo mira está mal.**

### Fronteras declaradas, no disimuladas

- **§16.6 es verdad para EFT y NO se generaliza:** ningún ammo-att de EFT setea `ATT.Ammo`, pero
  **ARC9MW tiene cuatro que sí** (`mw19_ammo_types.lua` — dos a `xbowbolt`, que Cargo maneja a
  0,15 kg/unidad, y dos a un tipo propio). El default de clase no los ve. El árbol está en
  `blob.atts` desde el #53, así que es resoluble; queda fuera del v1 porque su sede es el #55.
- **10 clases medidas comen un tipo que Cargo no maneja** y su cargador pesa 0: 7 marksman de
  ARC9MW en `SniperPenetratedRound`, el cuchillo arrojadizo de MW y el ssg08 de VJ. El hueco ya
  existía: **el cinturón tampoco las alimenta**.
- **El censo cubre ~2/3 del arsenal real** — EFT SMG/escopetas/LMG, CS:GO y `arc9_wtt` no están
  en `dev/other/`.
- **El tooltip sigue mostrando `def.weight`**, o sea el peso pelado: un RPG cargado suma 9 kg al
  total y muestra 6 en su ficha. No es nuevo (un chaleco con placas ya se comportaba así), pero
  este bloque lo vuelve más visible. Anotado sin decidir.
- **Los ocho valores de la tabla del engine son lo único escrito sin poder derivarlo del árbol.**
  `weapons.GetStored` devuelve `nil` para las armas de HL2, así que el harness prueba que la
  tabla **se consulta**, no que sus valores sean los correctos — y el caso estrella del bloque,
  el RPG, cae justo ahí. **CRG-24 vale también para el engine** (lección del #46): se miden uno
  por uno en juego. Es lo que mide la planilla **AC**.

### Archivos

- `shared/corpus_cargo_ammo.lua`: `Ammo.TypeOfClass` (memo por clase, seguro porque su entrada no
  cambia dentro de un boot), `Ammo.WeightPerRound`, `Ammo.EngineWeaponTypes`,
  `Ammo.ForgetClassTypes`.
- `server/corpus_cargo_instances.lua`: `Instances.ClipWeight`, sumada dentro de `WeightOf`.
- `server/corpus_cargo_ammopool.lua`: `AmmoPool.SyncHeldClip` al tope de `Reconcile`, el
  `StoreClip` del unload adelantado, y el comentario de cadencia enmendado con su techo.
- **Harness 771 → 798** (27 nuevos), con **8 reversiones verificadas en negativo** (una de ellas
  con resultado CERO, que es la que dejó la regla de método). El stub `weapons.GetStored` dejó de
  devolver `nil` fijo: ahora sirve tablas **sin heredar**, que es lo que devuelve en GMod, para
  que la trepada por `.Base` quede realmente ejercida.
- Sin convars nuevas, sin mensajes de red nuevos, sin timers nuevos.

### Planilla AC, ronda 1 (2026-08-01) — 8 PASA · 1 FALLA, y el rojo no fue el hallazgo

**El bloque quedó confirmado en lo suyo:** AC3 y AC4 midieron el ciclo entero sobre el arsenal
real —el AS VAL bajó de `clip1=31 · 0,620 kg` a `clip1=0 · 0,000` gastando el cargador, y el
total bajó exactamente 0,62—, AC5 midió el unload con el total **idéntico a los dos lados**
(69,71 → 69,71), AC6 vio la frontera comportarse como frontera, y AC8 volvió limpia.

**AC7, que era el único check de sensación, es el que valida la decisión de cadencia:** *«usé una
M249 SAW EFT y se sintió muy satisfactorio; mientras disparaba y miraba el inventario podía ver
el peso bajar, no de golpe, bastante suave la curva. Está perfecto en ese sentido.»* Los cuatro
refrescos por segundo se leen como una curva y no como escalones.

#### PARCHE 1 — el éter, y salió de la NOTA de un check que PASÓ

AC1 pasó con las tres armas en `[coincide]`, y al costado: *«BUG ENCONTRADO, armas del HL2 al
capturar o pasar al equipo te regalan munición, RPG da 3 cohetes y crossbow da 4»*. Está en su
propio volcado: la reserva de `RPG_Round` pasa de **x6 a x9** entre el dump con el RPG en el grid
y el dump con el RPG equipado, y la de `XBowBolt` de x8 a x11.

**Tres cohetes son NUEVE KILOS de capacidad de carga regalados por equipada** — un agujero más
grande que el que este bloque vino a cerrar, y **anterior a él**. Es el éter que §16.4 declara
como clase de defecto con las palabras del propio autor (*«la munición no puede aparecer del
éter»*) y que CRG-17 prohíbe por escrito: *la reserva se reconstruye del cinturón y de nada más*.

La causa es de alcance, no de lógica, y **el argumento correcto ya estaba escrito en el mismo
comentario que lo dejaba pasar**: `GiveEquipWeapon` documentaba que *«pool-fed SWEPs like
weapon_frag put that free clip straight into the ammo POOL, and the §16 mirror would launder it
onto the belt — ether»*… y aplicaba el `noAmmo` **sólo al slot throwable**. Toda arma del engine
es pool-fed igual. Ahora la entrega es incondicional (`ply:Give(class, true)`) y el parámetro
desaparece: no había un caso que quisiera el regalo.

**Por qué cinco packs de armas nunca lo mostraron:** sólo mordía a las armas del ENGINE. Un arma
ARC9 declara `SWEP.Ammo` y deja `Primary.Ammo` vacío en la clase, así que el engine no tenía qué
regalar, y el regalo propio de ARC9 ya estaba neutralizado en la fuente por el takeover de
`arc9_mult_defaultammo`. El arsenal del autor es ARC9 casi entero.

**Y el harness no podía verlo, que es la mitad más incómoda:** su `FakePlayer.Give` **ignoraba el
segundo argumento**, así que pasaba en verde con el éter puesto y sin él. El stub ahora modela el
regalo del engine (`ENGINE_GIVE_AMMO`, vacío por default: se declara el mecanismo, no se catalogan
los números de HL2), y el check nuevo va con su **contraprueba explícita** — que el stub SÍ regala
cuando nadie se lo impide, porque sin esa mitad el check no distinguiría nada. Misma clase de
agujero que el `lua/weapons/` sin cargar de la entry 60.

#### PARCHE 2 — el ejemplo estrella del bloque era FALSO (AC2, el único rojo)

AC2 falló, y no por el código: *«RPG no tiene cargador, mientras tenga munición en el belt sale
como si estuviera cargado»*. **El RPG de HL2 no tiene cargador**: dispara de la reserva directo y
su `Clip1()` contesta `-1` — `clip1=-` en las cuatro corridas del autor, con el arma cargada.

O sea que **la premisa con la que se abrió el bloque nunca fue cierta**. «Un cohete pesa 3,0 kg,
así que cargar el RPG hace desaparecer tres kilos» salió de multiplicar `weight` × `max_stack` del
catálogo **sin abrir el arma**: una inferencia escrita como si fuera una medición, que es lo que
§7.1 del flujo prohíbe, cometida en la premisa de la tanda y copiada a cinco sedes. Los cohetes
siempre estuvieron en el pool, el pool sigue al cinturón y el cinturón siempre pesó.

Se corrige **diciéndolo** en las cinco sedes en vez de reemplazarlo callado, y el síntoma real
pasa a ser el que está medido sobre el loadout del autor: **1,588 kg escondidos en cinco armas**.

**Tiene código, además de prosa:** un `-1` guardado daría peso **negativo** — un arma que
alivianaría al jugador. Los dos caminos al campo (`StoreClip`, `SyncHeldClip`) lo rechazan y
`ClipWeight` lo rechaza otra vez; las **tres guardas quedan medidas por separado**, cada una con
su reversión, porque son tres caminos distintos al mismo número.

#### Lo que la ronda dejó anotado y no se ejecuta acá

- **El tooltip** (nota de AC3, textual): *«el tooltip debería reflejar el peso que tiene el arma
  por efectos de la munición en el cargador»*. Es el **roadmap #58**, que esta misma tanda había
  abierto — ahora con pedido explícito del autor en vez de anotación nuestra.
- **Los tipos de munición que Cargo no maneja** (nota de AC6): *«hay que dar a Cargo los ítems de
  sniper y airboatgun/winchester ammo, hay varias armas de distintas bases que se alimentan con
  esas balas. Amerita buscar un modelo para esas balas»*. Es el **roadmap #57**, y la nota le
  fija la forma —**registrarlos como ítems**, no remapearlos— y le agrega dos tipos que el censo
  de `dev/other/` no había visto, `AirboatGun` y `Winchester`.

Harness **798 → 805** (7 nuevos: 4 del éter con su contraprueba, 3 del arma sin cargador), con
**4 reversiones nuevas verificadas en negativo** — 12 en total para el bloque.

### Planilla AC, ronda 2 (2026-08-01) — 1 PASA · 2 FALLA, y los dos rojos son UN solo hecho

**AC9 CIERRA la deuda de la entry 64**, que llevaba abierta desde el #53 y era la única ruta
del bloque que nadie había ejercido con números: montar un att desde el menú C **descuenta uno
del grid**. La resta, en el MCX 5.56 cambiando el STANAG 30 por un PMAG:
`eft_mag_ar15_pmag_30` pasa de `grid=5 montado=0` a `grid=4 montado=1`, y el STANAG desalojado
aparece con `grid=1`. **El puente no duplica**, y ahora está medido en juego y no sólo en el
harness.

**Los dos rojos, en cambio, no son dos defectos: son el mismo espejo detenido.**

#### El diagnóstico, hecho sobre la foto y no sobre una impresión

La captura de pantalla que acompaña el reporte prueba lo que ningún volcado decía: el pool tiene
**3 cohetes de RPG y 2 virotes** que **no están en ningún slot del cinturón ni en el grid**, con
dos slots de cinturón **libres**. Contrastado tipo por tipo contra CRG-15
(`pool == suma de los stacks del cinturón`):

| tipo | pool | cinturón | |
|---|---|---|---|
| Pistol / SMG1 / AR2 / Grenade | 120 / 120 / 60 / 3 | 120 / 120 / 60 / 3 | coinciden |
| **Buckshot** | **27** | **40** | debería DRENAR |
| **XBowBolt** | **2** | **0** | debería ABSORBER |
| **RPG_Round** | **3** | **0** | debería ABSORBER |

**Los cuatro que coinciden son exactamente los que no tuvieron actividad** — coinciden porque el
`Push` del spawn los igualó y nada los movió desde entonces. Los tres desincronizados son los que
sí se movieron. Eso no es un espejo con un bug: es **un espejo que no está corriendo**.

Y con eso los tres síntomas del autor colapsan en uno: *«el belt dejó de funcionar, no hay baja de
balas»* (no drena), *«te da una reserva que no va ni al inventario ni al belt»* (no absorbe) y *«no
puedo hacer unload»* (`UnloadWeapon` comparte los mismos interruptores). **No hay que buscar tres
causas.**

#### Los dos interruptores, y fallan distinto — que es el diagnóstico

`Reconcile` y `UnloadWeapon` comparten exactamente dos condiciones de salida, y **la diferencia
entre ellas es observable sin ningún comando**:

- **`cargo_ammo_pool 0`** → `UnloadWeapon` sale en su primera línea, **sin decir nada**. Es
  `FCVAR_ARCHIVE`, o sea que si alguna vez quedó en 0 **sobrevive al reinicio**.
- **el gate de spawn (`ready[ply]`)** → `UnloadWeapon` **avisa** *«You can't do that right now»*.

Que el autor reporte *«no puedo hacer unload»* **sin mencionar un aviso** apunta al primero, pero
eso es una inferencia y no se escribe como una medición: `cargo_dev_ammoweight` ahora imprime los
dos, más el invariante **comparado** en vez de dejar sumar el cinturón a ojo.

**Ninguno de los dos interruptores lo puede tocar el parche 1 de la ronda 1**: cambiar el segundo
argumento de `ply:Give` no escribe una convar ni el gate del spawn. Queda dicho porque la sospecha
por secuencia era legítima —en la ronda 1 el unload funcionaba— y descartarla en silencio sería
exactamente lo que este proyecto no hace.

#### Lo que el parche 1 SÍ hizo, y está medido

Su mitad se confirmó: *«al traerlo del inventario a equipamiento, no me da reserva de ammo, lo
mismo el RPG»*. **La ruta que se parcheó quedó cerrada.**

Y el mismo check destapó **la segunda puerta del éter, que es otra**: *«al tomar por primera vez
como ítem de HL2 tanto el RPG como el Crossbow, te da una reserva»*, confirmado con el
experimento limpio — cohetes en 0, botar el RPG, tomarlo, **tres cohetes regalados**. Esa puerta
es la **captura**, no el equip: el engine entrega el arma y su reserva *antes* de que
`WeaponEquip` mint el ítem y strippee el arma, así que la munición queda en el pool.

**Ya existe un clawback para exactamente esto y es de VJ Base solamente**
(`capture.lua`, `WeaponEquip`): lee `PickUpAmmoAmount` del SWEP y descuenta el regalo exacto un
tick después. Para un arma del **engine** no hay tabla que leer —`weapons.Get` devuelve `nil`—,
así que el clawback por lectura no sirve y hay que hacerlo **por delta**: el propio comentario del
world gate dice que *toda* adquisición pasa por `PlayerCanPickupWeapon` **antes** del `Equip`, o
sea que ahí está el único "antes" legible. **No se escribe todavía**: el espejo está detenido, y
un tercer parche sobre un subsistema que ahora mismo no se puede verificar en juego es una apuesta.

#### PARCHE 3 — el éter por la puerta de la CAPTURA (reportado dos veces)

Con el espejo de vuelta en marcha (*«se arregló el belt con la munición»*) el síntoma sobrevivió
y se pudo aislar: **tomar el RPG del suelo sigue regalando cohetes**. Es la puerta que el parche 1
no cubría — aquél cerró `ply:Give` (el equip desde el inventario, confirmado en juego); ésta es el
arma que viene **del mundo**, donde el engine la entrega con su reserva por default *antes* de que
`WeaponEquip` acuñe el ítem y la strippee.

**Se resuelve por DELTA y no por lectura, y ésa es la diferencia con el clawback que ya existía.**
El de VJ Base lee `PickUpAmmoAmount` del SWEP y descuenta el número exacto; un arma del **engine**
no es un SWEP —`weapons.Get` devuelve `nil`— así que no hay tabla que leer. Lo que sí hay es un
**antes**: el propio comentario del world gate declara que *toda* adquisición (touch, WALK+USE y
`ply:Give`) pasa por `PlayerCanPickupWeapon` **antes** del `Equip`. Se fotografía ahí y se restaura
un tick después, sólo si el pool **subió**. Funciona con cualquier base, incluida una que no
conozcamos — es "detección, nunca asunción" aplicado al regalo.

**Los throwables quedan afuera a propósito y no es un descuido:** para un frag el regalo del engine
**es** el mecanismo (§16.9 — es lo que mueve el `×N` del stack equipado cuando el engine concede una
granada). Clawbackearlo rompería la recogida de granadas del mundo.

**Y las reversiones auditaron los checks antes que al código:** de las cuatro, **dos volvieron con
CERO rojos** y las dos eran culpa de los checks, no del parche. El del piso medía *«sin regalo el
pool no cambia»* —con el antes y el después iguales, que un clawback sin guarda pasa igual—, y el
de los throwables **pasaba por un `nil` ajeno**: el stub de `GetAmmoName` no contestaba para el
tipo del frag, así que la granada quedaba sin fotografiar por una razón que no era la excepción que
el check decía medir. Reescritos, las cuatro reversiones ponen en rojo **un check cada una**.

#### PARCHE 4 — INTENTO de apagar el regalo en la fuente, y NO alcanzó

Con el parche 3 puesto el autor confirmó lo funcional —*«ya no recolecta rockets»*, y
`cargo_dev_ammoweight` lo respalda— y reportó lo que quedaba: **el HUD de DGL4 seguía anunciando
la captura de 3 cohetes**. Textual: *«es lo mismo que pasaba con las armas de VJ que regalaban
munición»*, y tiene razón — es el mismo síntoma, y la línea que lo resolvió allá estaba veinte
líneas más arriba en este mismo archivo: **«the event itself must never fire»**. El clawback deja
el pool correcto, pero llega tarde para el evento.

**Verificado contra la fuente del mod y no supuesto (CRG-24, 2026-08-01):** DGL4 alimenta su
historial desde `HUDAmmoPickedUp` (`holohud2/elements/resourcehistory.lua:281`).

**Y eso descarta el camino fácil.** Devolver `true` desde un `HUDAmmoPickedUp` propio sólo gana si
corre **antes** que el suyo, y **el orden de `hook.Call` entre hooks distintos no es de
inserción** — la saga VJ ya pagó esa lección (entries 37-40). Una carrera no es un arreglo.

Así que se apaga en la entidad, antes del `Equip`, en el mismo choke point donde se toma la foto:
`m_iPrimaryAmmoCount` es el campo del datamap que un arma del engine entrega al equiparse, y es el
mismo que el `bNoAmmo` de `ply:Give` pone en cero. **No se asume que exista:** va en `pcall`, y su
fracaso no rompe nada porque el clawback por delta sigue garantizando lo funcional. Si el campo no
está, **se pierde la cosmética y nunca el invariante** — y eso es lo que la planilla mide, porque
el engine es un tercero y esto no se verifica offline. Los throwables siguen exceptuados por el
mismo motivo que en el parche 3.

> **MEDIDO EN JUEGO Y NO ALCANZÓ (ronda 4, 2026-08-01).** *«Todavía no desaparece el history de 3
> cohetes de DGL4; en `cargo_dev_ammoweight` no se muestran que existan 3 cohetes.»* O sea: **el
> invariante está cerrado y la cosmética no**. Escribir `m_iPrimaryAmmoCount` no impide el evento —
> o el campo no es ése, o `SetSaveValue` no lo alcanza, o el regalo no vive en el datamap.
>
> El parche **se queda**: es inerte donde no aplica (va en `pcall`) y el clawback por delta, que es
> lo que sostiene el invariante, no depende de él. Lo que **no** se queda es la afirmación: este
> bloque decía que el regalo se apagaba en la fuente y **eso no está probado**, así que el título
> pasa a *intento*. Una afirmación no sobrevive a la medición que la contradice.
>
> **Y no se prueba un segundo nombre de campo a ojo**, que sería la tercera vuelta sobre una
> suposición: `cargo_dev_worldwep` ahora imprime los campos de `ammo`/`clip` de la **save table**
> del arma que estés mirando, más si esa entidad pasó por el world gate. Con eso la próxima pasada
> o encuentra el campo real, o prueba que el regalo no vive en el datamap — y entonces la frontera
> queda declarada **con su medición** en vez de por cansancio.

**Y otra vez la reversión auditó el instrumento antes que al código.** Sacarle el `pcall` al parche
**no ponía nada en rojo: mataba la corrida** —cero `[FAIL]` y la pasada sin terminar, que es
exactamente la regla 1 del #53—, porque **ninguna** de las armas de mentira del bloque tenía el
campo del datamap y la primera reventaba. El stub ahora modela la realidad —las armas del engine
**sí** lo tienen— y deja **una sola** sin él, que es la que prueba la degradación. Con eso las tres
reversiones enrojecen **un check cada una** y la corrida llega al final.

#### Qué se hizo en esta tanda

Instrumento, no parche. `AmmoPool.IsReady` expone el gate —hasta ahora *«el espejo está apagado»*
y *«el espejo corre y falla»* eran **indistinguibles desde el juego**, que es la lección de la
sección AB en su forma más cara— y `cargo_dev_ammoweight` imprime los dos interruptores y el
invariante ya comparado, con el veredicto por tipo.

**Cuatro checks nuevos de harness para el modo de falla que nadie había fichado** (809 desde 805),
con su AUSENCIA: con el gate cerrado el espejo **no** corrige un desincronizado, y con el gate
abierto el **mismo** desincronizado se corrige. Sin esa segunda mitad, el primero pasaría también
con un espejo que no hace nada.

### Cierre — cuatro rondas, y el bloque cierra por lo que MIDIÓ y no por lo que se propuso

**Decisión del autor, 2026-08-01:** *«sí, por ahora será costo cosmético, se arregló el resto pero
se muestran los cohetes en el HUD»*. La frontera queda **declarada en §13 con su medición**, que es
la diferencia entre cerrar y abandonar: se sabe qué miente (el aviso), qué no (el ledger), por qué
no se tapó (una carrera no es un arreglo) y qué costaría taparlo (no dejar que el engine equipe el
arma, arriesgando la superficie de compat que el header de `capture.lua` protege).

**Lo que el bloque entrega, todo medido en juego:** las balas del cargador pesan y se cuentan una
sola vez; el tipo de munición se resuelve sin entidad viva; la cadencia es la del poll que ya
corría y **se siente como una curva y no como escalones** (AC7); y **dos puertas del éter que no
eran de este bloque quedaron cerradas de paso** — equipar un arma del engine y tomarla del suelo,
las dos regalaban reserva, la segunda desde el Bloque B.

**Y el bloque cierra con más reglas de método que de código.** Ninguno de los cuatro parches salió
de donde el bloque miraba: el primero de una **nota en un check que pasó**, el segundo de un **rojo
que refutó la premisa** en vez del código, el tercero de un reporte que sobrevivió al bloqueante, y
el cuarto de **medir en vez de adivinar un segundo nombre de campo**. Tres veces la reversión
auditó **el instrumento antes que al código** — dos checks que no distinguían y un `pcall` cuya
ausencia mataba la corrida en vez de enrojecerla —, y una afirmación de este mismo CHANGELOG hubo
que **corregirla porque la medición la volvió falsa**.

Harness **771 → 817** (46 nuevos), **19 reversiones verificadas en negativo**. Checker limpio,
espejo regenerado.

---

## 66. Los tres pools que el cinturón no miraba (roadmap #57) `[APLICADO 2026-08-07]`

Pedido del autor, 2026-08-06: *«ya están los modelos para la munición de winchester y sniper
rounds, es hora que los agreguemos a cargo (…) porque antes algunas armas de ARC9 no tenían cómo
meter munición al belt sin un item que capturara esa info»*. Es el **roadmap #57**, y su modelo
—lo único que ese punto dejaba abierto— se cerró el 2026-08-05.

**Qué estaba roto, y no era el peso.** Un tipo que no está en `CARGO.Ammo.TYPES` es un tipo que el
espejo de §16.3 **no recorre**: esas armas **no se alimentaban del cinturón**, punto. El #56 sólo
lo hizo visible (su cargador pesaba 0) y lo dejó declarado como frontera. Tres entradas nuevas en
la tabla `AMMO` de `shared/corpus_cargo_ammo.lua` y el espejo, el peso, el precio, el badge del
cinturón, el unload y el veto de mundo los heredan **sin una línea propia**: es el mismo trabajo
que la tabla ya hacía para los nueve de HL2.

### El censo se rehízo sobre el arsenal VIVO, y corrigió dos premisas del propio roadmap

El punto avisaba que `dev/other/` cubre ~2/3 y pedía re-censar. Se re-censó **sobre los 380 `.gma`
suscritos** (índice de cada uno parseado y sus `.lua` leídos — no un barrido de los 63 GB), más los
binarios del engine. **Las dos correcciones son del punto, no del código:**

1. **«Winchester» NO ES UN TIPO DE MUNICIÓN DEL ENGINE.** No aparece en
   `garrysmod/bin/win64/server.dll` — `AirboatGun`, `SniperRound` y `SniperPenetratedRound` sí. Es
   el `PrintName` que **TFA Base** le pone al pool `AirboatGun`: `tfa_small_entities.lua` registra
   `tfa_ammo_winchester` como *"Winchester Ammo"* con `AmmoType = "AirboatGun"` y 50 balas. O sea
   que *«airboatgun/winchester ammo»* nunca fueron **dos** pools: son **uno** visto por sus dos
   nombres. Registrarlos como dos habría acuñado un ítem fantasma que ninguna arma alimenta.
2. **Los francotiradores de ARC9 comen `SniperPenetratedRound`, no `SniperRound`** — y son **diez**
   clases, no siete: las 7 de ARC9MW más el `awp`, el `scout` y el `ssg08` de `arc9_go`, que
   `dev/other/` no tenía. `SniperRound` es **otro** pool con **tres** comedores, todos VJ
   (`weapon_vj_ssg08` y el `m40a1` y el `csniper` de Half-Life Resurgence). Por eso van los **dos**
   registrados y ninguno remapeado al otro: son dos pools del engine y el espejo es por pool.

**Y un tercer dato que sólo aparece midiendo:** ARC9MW escribe el tipo con **dos grafías** según el
archivo (`SniperPenetratedRound` en kar98k/spr208/ax50/hdr, `sniperPenetratedRound` en
m14/rytec/svd). `ItemForType` ya era case-insensitive; si no lo fuera, **la mitad de las diez
seguiría sin cinturón** y el defecto se leería como *"a veces anda"*.

### Lo que se escribió

- **Tres defs nuevos** (ids derivados del pool, como los nueve de HL2):
  `cargo_ammo_sniperpenetratedround` → *Sniper Rounds (AP)*, `7mm MAG`, 0,035 kg, tope 20, $55;
  `cargo_ammo_sniperround` → *Sniper Rounds (Ball)*, `7.62x51`, 0,03 kg, tope 20, $45;
  `cargo_ammo_airboatgun` → *Winchester Rounds*, `.308`, 0,025 kg, tope 50, $28.
- **Los dos francotiradores comparten `ammo_sniper.mdl`**, así que **el nombre es lo que los
  separa** en la celda (la lección de las 61 variantes de NVG). AP/Ball es la distinción **del
  propio engine**: el *penetrated* es el que atraviesa.
- **El ítem se llama Winchester y su clave es `AirboatGun`.** El nombre es el que el jugador ya lee
  en juego; la clave es el pool. Decisión del autor con el desajuste a la vista: el `caliber` es
  **`.308`** (el texto que TFA imprime en su caja) y **no** el *.44 Magnum* que dice el arte del
  modelo shipeado, que queda de suplente hasta que haya una caja de .308. Re-vestirlo cuesta un
  `Items.SetModel` y ninguna línea de este archivo.
- **Las dos cajas de TFA entran a `WORLD_AMMO`** (`tfa_ammo_winchester` 50, `tfa_ammo_sniper_rounds`
  30, cuentas leídas del `.gma`, no de HL2). Sin esto el ítem de Winchester **no tiene de dónde
  salir**: ninguna arma del arsenal come `AirboatGun` y esa caja es su única fuente. Lo que cierra
  la fuga no es el veto de `PlayerCanPickupItem` —TFA reparte por su propio `ENT:Use`, que ese hook
  nunca ve— sino el **`return false` del gate de WALK+USE**, que impide que el engine llegue a
  `ENT:Use`: la técnica del roadmap #27, ya probada. Inerte sin TFA montado y bajo el kill-switch
  `cargo_ammo_world_pickup` que ya existía.

### Lo que la verificación en negativo destapó, y era del instrumento

Las **seis reversiones enrojecen**, pero **cinco lo hacían crasheando**: los checks nuevos
indexaban el def pelado, así que quitar una entrada mataba la corrida en vez de enrojecerla y se
llevaba puestos todos los checks de abajo. Es **la regla del #53 —"un check que CRASHEA no es un
check en rojo"— cometida de nuevo al escribir los checks que la citan**. Corregido con guarda: hoy
las cinco dan rojo limpio y la corrida llega al final.

**La sexta no se puede reclamar y se dice:** R5 (volver `ItemForType` case-sensitive) enrojece la
corrida pero **crashea antes de llegar** al check de las dos grafías, así que ese check queda
sostenido por la medición que documenta, no por una reversión propia.

**Dos checks viejos había que corregirlos, no borrarlos:** `#56(a)` y `#56(e)` usaban
`SniperPenetratedRound` como ejemplo de *"tipo que Cargo NO maneja"*, y esta tanda vuelve esa
premisa falsa. Pasan a usar el pool propio que ARC9MW acuña para su cuchillo arrojadizo
(`arc9_cod2019_knife`, vía `game.AddAmmoType`), que **sigue** sin ítem — y el francotirador queda
como su **contracara**, midiendo que ahora sí pesa sus balas.

**Qué queda afuera, dicho:** los pools propios que cada pack ARC9 acuña por lanzable
(`arc9_cod2019_knife`, `arc9_cod2019_c4`, los `arc9_go_nade_*`) son una pregunta de **throwables**
(§16.9) y no de cinturón. Y **ninguna arma del arsenal vivo come `AirboatGun`**: el ítem existe,
pesa, se guarda y se comercia, pero hoy sólo se llena desde la caja de TFA.

Harness **817 → 828** (11 nuevos), **5 reversiones verificadas en negativo** + 1 declarada sin
poder reclamarse. `cargo_selftest` pasa de 11 a 14 tipos, con los tres ids fijados.

### Pasada en juego (2026-08-07) — cierra, y cierra por el camino que se escribió

Reporte del autor: *«testeado ingame, no se rompió nada y están los modelos. Tomar `tfa_ammo` da la
munición correspondiente»*, y **la caja entrega un ÍTEM AL GRID**. Con eso el bloque cierra:

- **Los tres pools se alimentan** y los modelos se ven — que era el pedido literal.
- **`WORLD_AMMO` es lo que corrió, y no el espejo.** La distinción no es cosmética y por eso se
  preguntó antes de escribirla: *«la caja da munición»* es cierto en los **dos** mundos posibles —el
  ítem al grid (lo que escribimos) y el pool crudo que el espejo de 4 Hz absorbe al cinturón (la
  deuda declarada de `arc9_ammo`, §16.5)—, y sólo uno de los dos prueba que la línea nueva hizo
  algo. Es **CRG-16 literal**: el grid es el almacén, el cinturón es el pool, y el jugador decide
  cuánto cuelga. **Un «funciona» que no distingue qué mecanismo corrió no cierra un bloque.**
- **Nada se rompió**, que es la mitad que ninguna corrida offline podía dar: el harness prueba que
  los tres tipos resuelven, no que agregarlos al recorrido del espejo deje quieto lo que ya andaba.

**Lo único que queda abierto, y es de arte, no de código:** la caja de **.308**. El
`ammo_winchester.mdl` que ships hoy dice *.44 Magnum* en su arte y el ítem se etiqueta `.308`
(el texto de la caja de TFA, decisión del autor con el desajuste a la vista). Es **suplente
declarado**: re-vestirlo cuesta un `Items.SetModel` y **ninguna línea** de
`shared/corpus_cargo_ammo.lua`, porque para eso existe ese punto de extensión (entry 34).

---

## PARCHES DE sesión Instrumentos del realm CLIENTE — 2026-08-08

Cola del diagnóstico cuya sede es el CHANGELOG de `corpus/` (sesión *La ready barrier no
disparaba en el realm CLIENTE*) y cuyo veredicto vive en
[`dev/VEREDICTO_ready_barrier_cliente.md`](../../dev/VEREDICTO_ready_barrier_cliente.md). El
defecto era del framework; **lo que es de Cargo es que no había con qué verlo**.

El mensaje que el autor reportó como *«dice que no reconoce módulos cargados»* es de este repo:
`"No bars registered (absent modules)"`, `client/corpus_cargo_statuspanel.lua:66`. No estaba en
el `console.log` **porque es VGUI, no `Corpus.Log`** — un string que se ve en pantalla y no está
en el log es un string dibujado. **Y decía la verdad:** las 3 barras se registran dentro de
`Corpus.OnReady`, y esa barrera no disparaba en el realm cliente. La degradación honesta del
§11 funcionó exactamente como se diseñó; lo que faltaba era el instrumento para creerle.

- PARCHE 1 — `shared/corpus_cargo_dev.lua`: **`cargo_selftest_cl`**, alias CLIENT-only, misma
  razón que `corpus_selftest_cl` (2026-07-25, planilla T4): este archivo es shared, así que
  `cargo_selftest` queda registrado en los dos realms y **en listen server gana el del SERVER**;
  `lua_run_cl` está gateado por `sv_allowcslua` en 0. Sin nombre propio, el realm CLIENT de este
  módulo era **inverificable en juego**. **[APLICADO 2026-08-08]**
- PARCHE 2 — `shared/corpus_cargo_dev.lua`: **`cargo_dev_items_cl`**, el check directo del
  defecto: lista las defs que el CLIENTE tiene, que son **las que el grid realmente renderiza**
  (Cargo no sincroniza defs de módulo por red — **COR-12**), y por eso «qué defs existen» es una
  pregunta **distinta por realm**. Cuando esto se escribió, la respuesta del cliente eran 4.413
  defs menos que la del server, y nada en juego podía decirlo. **[APLICADO 2026-08-08]**
- PARCHE 3 — `shared/corpus_cargo_dev.lua`: `IsBulk`, `FindDefs` y el cuerpo del listado salen
  del bloque `if SERVER then` a scope de archivo, y los **dos** comandos llaman a la misma
  `ListDefs`. **Una rutina, dos nombres** — dos copias del listado es cómo los realms terminan
  divergiendo en lo que reportan. La cabecera del listado ahora **imprime el realm**: una
  medición que no dice de dónde se tomó es cómo un check verde reporta dos veces el mismo lado.
  **[APLICADO 2026-08-08]**

Harness `harness_cargo.py`: **828 verdes**, sin cambio de conteo — los tres parches son
instrumentos y superficie de consola, no lógica pura. La verificación de que sirven es en juego:
`cargo_dev_items_cl` tiene que devolver el mismo catálogo no-bulk que `cargo_dev_items`.

### Pasada en juego (2026-08-08) — los dos instrumentos CIERRAN, y el listado fue el que probó el fix

`cargo_dev_items_cl` devolvió **51 ítems no-bulk en el realm CLIENT** (+4.467 bulk), con las 4
defs de Coagulant en `[medical]` y las 15 de Craving en `[food]` — el catálogo del que el grid
renderiza, que hasta el día anterior **no se podía preguntar en juego**. El autor confirma el
inventario: *«se ve bien como antes, tengo todo lo que debería tener»*, y el StatusPanel pinta
las 5 barras en vez del `"No bars registered (absent modules)"`.

Los tres parches quedan **verificados en juego**. Nota de método: el instrumento que se agregó
*porque faltaba para diagnosticar* terminó siendo el que **acreditó el arreglo** — un listado que
dice su realm es lo que separa «el catálogo existe» de «el catálogo existe en el otro lado».

**Queda una observación abierta, y no es de este arco.** En la pasada se ven **tres** quick slots
(F1, F2, F3) con `x0` en rojo, donde antes del fix se veía uno solo — o sea que **no era un
efecto de la def faltante**: con el catálogo completo el síntoma se hizo más visible, no menos.
Un `count == 0` en una referencia de quick slot es su propio defecto y **no se investigó**.

---

## 67. Enumerar el catálogo desde afuera del módulo (roadmap #63) `[APLICADO 2026-08-18]`

Superficie nueva, chica, y **pedida por un consumidor que no podía escribir su regla sin ella**.

**De dónde sale.** De sentarse a escribir el trader de comida de `corpus-stalker` y descubrir que
la regla que el autor ya había votado —*«vende TODO lo que declare `category = "food"`»*, que es
una **regla y no una lista**, para que una comida registrada mañana por cualquier addon entre
sola— **no se puede escribir**. `Items.Get(id)` responde por *una* def; recorrerlas no tenía
puerta pública. Censado con `rg --no-ignore` sobre el workspace entero: los únicos tres recorridos
son `dev.lua`, `lan.lua` e `iconeditor.lua`, y los tres leen `CARGO.Items._defs` directo **porque
viven adentro del módulo**. Ningún consumidor de afuera la tocaba.

Voto del autor al presentarle el hallazgo, textual: *«si no hay API mejor construirla
correctamente»*. El trader queda esperándola y su prompt, pendiente.

- PARCHE 1 — `shared/corpus_cargo_items.lua`: **`Cargo.Items.GetAll()`** y
  **`Cargo.Items.ByCategory(id)`**. Lista **fresca** (del caller, mutable), defs **por
  referencia** — mismo invariante que `Items.Get`, el módulo dueño las sigue escribiendo. **No
  abre ninguna vía para mutar el registro**: no hay desregistro público y esto no lo inventa.
  Es el mismo movimiento con el que este repo ya sacó `Trade.StockOf`/`HasViewer`/`ClearViewers`
  cuando la entidad de Sidorovich empezó a leer `trader.cont` y `trader.viewers`: alcanzar la
  tabla privada desde afuera **no evita el acoplamiento, lo muda**. **[APLICADO 2026-08-18]**
- PARCHE 2 — el mismo archivo: **el orden**. Las dos salen ordenadas por id, y eso es **la mitad
  del contrato**, no prolijidad. `_defs` es un hash y el orden de `pairs` no se repite entre
  sesiones: un trader que siembre stock recorriéndolo arma un catálogo **distinto en cada
  arranque sin que nadie lo haya sorteado**, y un defecto que dependa del orden **no se reproduce
  dos veces** — se lee como mala suerte, que es la peor forma que puede tomar. Acuñado como
  **CRG-69**, sede `Cargo_Architecture.md` §3. **[APLICADO 2026-08-18]**

Lo que **no** hace, para que no se lea de más: no oculta el catálogo **bulk** (attachments de
ARC9, armas capturadas `wpn_*`, las 61 NVG). Esconderlas es decisión de **display** y vive en el
listado de `dev.lua`, que ya tiene su `IsBulk`; un accesor que descartara entradas **mentiría
sobre qué hay registrado**, y el que siembra stock decide por sí mismo.

### El hallazgo de instrumento, que es más grande que el parche

Verificando en negativo —mutando `GetAll` a propósito, borrándole el `table.sort`— salió esto:

**`harness_cargo.py` invocaba el selftest con `pcall` y miraba SÓLO si había corrido**, tirando el
valor de retorno. Y `CARGO._SelfTest()` **sí** devuelve `fail == 0`. O sea que con el selftest en
**rojo** el harness imprimía `ALL GREEN` y salía **0**: sus **86 checks de server y 93 de client
no hacían fallar nada** — escribían una línea en stdout y la pasada seguía verde. Es la familia
más cara de control defectuoso: el que **da verde sin medir**, y encima acredita.

- PARCHE 3 — `dev/harness_cargo.py`: el selftest se exige **PASADO**, no corrido, en los **dos**
  realms (`check(okSelf and resSelf == true, ...)`). Con el mutante puesto, la pasada ahora sale
  **exit 1**. Los harness de **Craving y Coagulant ya lo hacían bien** (`check(X._SelfTest() ==
  true, ...)`) — el de Cargo era el único, así que es un desvío y no un patrón. **[APLICADO 2026-08-18]**

**Y la misma verificación en negativo destapó un defecto en un check que yo acababa de escribir.**
El primer check de orden del harness comparaba **dos** elementos (`arte[1].id == "t_enum_aa"`).
Con el `table.sort` borrado, **el selftest se puso rojo y ese check siguió verde**: con dos
elementos, un `pairs` sin ordenar acierta la mitad de las veces, y encima su comentario afirmaba
lo contrario. Lo que juzga es recorrer el catálogo **entero** — miles de ids ascendentes por azar
del hash no pasa. Reescrito así, y verificado aislando el gate temprano para poder verlo ponerse
rojo. *Un caso suelto no juzga un orden* (PLANTILLA_CHECKS §4), y esta vez el que se lo saltó fue
el que escribía el check.

Harness `harness_cargo.py`: **828 → 838 verdes** (7 checks de la superficie nueva + 1 de orden
reescrito + 2 de los gates del selftest), selftest **86 OK server / 93 OK client**, exit 0. Los
dos gates nuevos verificados en negativo: con `GetAll` mutado, exit 1.

**PASADA EN JUEGO ✓ (2026-08-18).** `cargo_selftest` → **91 OK, 0 fallas** (realm server) y
`cargo_selftest_cl` → **93 OK, 0 fallas** (realm client). Los dos números son **exactamente** los
que había predicho el harness offline, que es la única forma que tiene ese instrumento de
acreditarse: no alcanza con que sea verde, tiene que coincidir con el motor. Cubre también al
entry 68, que corrió en la misma pasada.

## 68. El ítem de una clase de arma (roadmap #64) `[APLICADO 2026-08-18]`

**El mismo agujero que el 67, un día después y en otra superficie** — y esta vez el consumidor
llegó con el anterior ya resuelto.

**De dónde sale.** De retomar el trader de `corpus-stalker` con `Items.ByCategory` en el árbol y
chocar con que la regla ya se podía escribir para comida y medicina, pero **las armas no estaban
EN el catálogo**. Un arma capturada no tiene código propio: su def es **autogen** y hasta hoy la
acuñaba **sólo la captura**, cuando el engine entregaba el arma. `EnsureDef` es una función
**local** de `server/corpus_cargo_capture.lua` — no había puerta pública, y desde afuera una local
ni siquiera se puede alcanzar.

**El síntoma, que es el que importa.** `Trade.AttachTrader` resuelve cada línea de `opts.stock`
con `Items.Get`, no encontraba la def, logueaba *«stock desconocido»* y **salteaba en silencio**.
O sea que el trader en un server **fresco** vendía **cero** armas con el pack ARC9 EFT montado
entero, y eso se lee exactamente igual que *«el pack no está montado»*: un falso negativo que
además **acredita al pack**.

Voto del autor al presentarle el hallazgo, textual: *«Si es bloqueante paremos acá, guarda el
prompt original, y solucionemos la bloqueante de cargo»*.

**Y preguntó si pasaba lo mismo con el resto de los ítems — no, y está medido.** `rg --no-ignore`
sobre **todos** los `Items.Register` del workspace: comida (Craving), medicina (Coagulant),
munición y suministros (Cargo), las 61 NVG y los attachments de ARC9 se registran **en el
arranque** desde archivos `shared` y existen mientras su addon esté montado. Las armas capturadas
`wpn_*` son la **única** familia acuñada en runtime — `autogen = true` aparece **una sola vez** en
todo el árbol de Cargo. El agujero era de una familia, no del catálogo.

- PARCHE 1 — `server/corpus_cargo_capture.lua`: **`CARGO.Capture.ItemIdFor(class)`** (SERVER).
  Devuelve el id de ítem que representa esa clase, acuñando su def autogen si no existe; si la
  clase ya tiene **cara canónica** (frag/SLAM, roadmap #32) devuelve **ésa** — acuñarle una
  `wpn_*` resucitaría la segunda cara que ese frente existe para matar. Cuatro motivos de rechazo
  **distinguibles**, y eso es contrato y no decoración (una respuesta vacía sin causa es lo que el
  entry 67 dedicó un párrafo a advertir): `"invalid class"`, `"ignored class"`, `"unknown weapon
  class"` y `"NPC-only weapon"`. **Sólo armas scripteadas**: las del engine no son SWEPs
  (`GetStored` da `nil`), se rechazan, y no pierden nada — siguen capturándose por la vía del
  pickup, que tiene entidad viva y nunca necesitó esta puerta. Acuñado como **CRG-70**, sede
  `Cargo_Architecture.md` §3. **[APLICADO 2026-08-18]**
- PARCHE 2 — el mismo archivo: **lo que acuña, lo persiste**, y es la mitad que no era obvia.
  `autogen_defs` existe (CHANGELOG #6) para que un arma **capturada** sobreviva al cambio de mapa;
  un arma **comprada** necesita exactamente lo mismo, o el jugador se queda con un blob cuyo id no
  resuelve. Efecto lateral **declarado y no escondido**: el catálogo pasa a ser *«lo que los
  jugadores tuvieron en la mano Y lo que los traders sortearon»*. Nada se acuña dos veces.
  **[APLICADO 2026-08-18]**
- PARCHE 3 — el mismo archivo: **dos datos que antes salían de la entidad viva y ahora salen de la
  clase**, porque sin entidad habría que inventarlos. El **PrintName** trepando `.Base` con
  `GetStored` —que **no** hereda: sólo `weapons.Get` corre `TableInherit`, y deep-copea el árbol de
  attachments entero para leer un string— y el **calibre** vía `Ammo.TypeOfClass`. Sin la trepada,
  una clase que no declara `PrintName` propio produce un ítem **llamado como su clase** y **nada
  falla**: la misma falla sin síntoma que ya midió el censo de `dev/other/` (9 de 99 SWEPs
  spawneables heredan el campo). El camino con entidad viva no cambia: sigue ganando el
  `GetPrintName` real. **[APLICADO 2026-08-18]**

### El hallazgo de instrumento, y esta vez fue contra un check mío

Verificando en negativo —borrando cada gate uno por uno y exigiendo rojo— salió que **el tramo de
rechazos era CIEGO**. Con el gate `Ignore` borrado la pasada seguía **verde**: el check sólo exigía
*«rechazado con algún motivo»*, y sin `Ignore` la clase caía **un gate más abajo** —el de
existencia— y se rechazaba igual, con otro motivo que el check no miraba.

**Un check que no mira CUÁL gate contestó no juzga ninguno en particular: lo aprueba el de al
lado.** Es la misma familia del check de orden del entry 67 (comparaba dos elementos y un `pairs`
sin ordenar acertaba la mitad de las veces), y volvió a salir por la misma vía. Reescrito
comparando el **motivo exacto**, y la clase de `Ignore` sembrada en el padrón de SWEPs para que el
gate de abajo **no pueda** cubrirla. Los **8** gates verificados en negativo después del arreglo:
los 8 en rojo.

Harness `harness_cargo.py`: **838 → 852 verdes** (14 checks del bloque CRG-70), selftest **91 OK
server** (eran 86) / 93 OK client, exit 0.

**PASADA EN JUEGO ✓ (2026-08-18)**, la misma corrida que cerró el entry 67: `cargo_selftest`
**91 OK, 0 fallas** (server) y `cargo_selftest_cl` **93 OK, 0 fallas** (client) — los 5 checks
nuevos de esta superficie entre ellos, y los dos totales clavados con los que el harness offline
había anticipado.

---

## 69. Los usos de un ítem, y la tecla que un único no podía tener (roadmap #66) `[APLICADO 2026-08-19]`

**Pedido del autor (2026-08-18):** *«tener un solo item pero con x usos más que varios items en un
stack (…) el mismo tooltip debería decir cuántos usos le queda, eso parece que le queda pendiente
a Cargo, no lo había pensado.»*

### Lo primero que se midió fue que NO estaba pendiente

La barrita que el pedido describe **ya estaba dibujada** hacía rondas (`grid.lua`, pegada al borde
inferior de la celda), el tooltip ya tenía su fila de condición, `has_condition` ya estaba en el
contrato, y **el precio de un frasco a medio usar ya se partía al medio sin una línea escrita**,
porque sale de `value × condición × spread`. Lo único que faltaba era la **unidad**: la celda decía
`67 %` donde un frasco de pastillas tiene que decir `2/3`.

De paso se corrigió una premisa del prompt que pedía la tanda: decía que la condición se dibuja en
**dos** lugares. Son **tres** para el texto (celda del grid, título del tooltip, fila de un
sub-slot montado) y **cinco** para la barra (más la celda de equipamiento y el sector del wheel).

### Lo que se escribió

- PARCHE 1 — `shared/corpus_cargo_items.lua`: el campo **`def.uses`** (entero ≥ 1, **sólo
  `unique`**) y las **dos funciones puras** de conversión, `Items.UsesLeft(def, condition)` y su
  inversa `Items.ConditionForUses(def, n)`. Van en **shared** y no en el theme a propósito: la
  aritmética es la misma en los dos realms, el harness la mide en los dos, y el módulo dueño la
  necesita del lado del server para **gastar** un uso sin restar a mano. Acuñado como **CRG-71**,
  sede `Cargo_Architecture.md` §3. **[APLICADO 2026-08-19]**
- PARCHE 2 — el mismo archivo, **los dos portones del `Register`**, y los dos existen porque la
  falla que frenan es **silenciosa**. `uses` sobre un **stackable** es `error()`: un stack lleva
  UNA condición para sus N unidades (CRG-7), así que gastarle «un uso» se la gastaría a todas de
  una, y no hay forma de eso que no sea un bug. Y declarar `uses` **prende `has_condition`**: sin
  él `Instances.Create` no siembra `blob.condition`, `ConditionOf` contesta `nil` y el ítem **no
  dibuja nada, sin un solo error** — exigir los dos campos no compra nada y deja ese no-op al
  alcance de la mano. **[APLICADO 2026-08-19]**
- PARCHE 3 — `client/corpus_cargo_theme.lua`: `ConditionShort` y `ConditionLong`, **el único lugar
  que decide si una condición se lee en % o en usos**. Las tres superficies de texto pasan por acá;
  que cada una lo decidiera por su cuenta es exactamente cómo la celda y el tooltip terminan
  diciendo unidades distintas del mismo frasco. El tooltip muestra **los dos** (`2/3 uses · 67 %`)
  porque el % es de donde sale el precio: esconderlo hace que una reventa a la mitad se lea como un
  error de precio. **[APLICADO 2026-08-19]**
- PARCHE 4 — `client/corpus_cargo_grid.lua` y `client/corpus_cargo_tooltip.lua`: las tres
  superficies llaman a esos dos helpers. En el título del tooltip, además, **el reserve del ancho
  del nombre dejó de ser un `150` mágico y se mide**: estaba calibrado contra `Condition 100%` y la
  forma nueva es más larga. Un número mágico que sólo entra para la etiqueta con la que se calibró
  es un defecto esperando a la próxima etiqueta. **[APLICADO 2026-08-19]**
- PARCHE 5 — `server/corpus_cargo_inventory.lua`: **`QuickTarget`**, que resuelve el id bindeado a
  una **instancia** en cada apretada. La regla, votada: **el más gastado que todavía sirve** (la
  condición más baja entre las mayores que 0, desempate por uid). Es la regla de STALKER —terminás
  el frasco abierto antes de abrir otro— y no es cosmética: como Cargo **no borra** el ítem a cero,
  sin ella un frasco vacío se sienta adelante y **se come cada apretada para siempre**. Con todos
  gastados le pasa igual el primero al `onUse` del dueño, que es el que contesta. **[APLICADO 2026-08-19]**
- PARCHE 6 — `client/corpus_cargo_ui.lua`: se cae el gate `class == "stackable"` del submenú *Quick
  bind*, y `UI.QuickCount` pasa a contar **las dos clases**. **[APLICADO 2026-08-19]**
- PARCHE 7 — `shared/corpus_cargo_dev.lua`: **`cargo_dev_pills`**, la implementación de referencia
  del lado del módulo dueño, y **dos** en el kit — con un solo frasco toda regla de selección da la
  misma respuesta y el check no discrimina. Las tres cosas que un consumidor hace mal por defecto
  están en sus diez líneas: gasta con `ConditionForUses` (nunca restando 100/uses, que deriva),
  devuelve **`false` siempre** (un `true` borraría el frasco con la primera pastilla en vez de
  gastarle uno de tres) y a 0/3 **lo deja**. **[APLICADO 2026-08-19]**

### Dos defectos vivos y silenciosos que el parche 5 cerró

La ruta vieja de la tecla armaba su ref a mano como `{ id = itemId }`, forma que `FindEntry` sólo
empareja contra entradas con `uid == nil`:

- **Un `unique` era inalcanzable** — y se podía atar igual **arrastrándolo**, porque el gate de
  clase estaba sólo en el menú contextual y el receiver del drag no tenía ninguno. La tecla
  contestaba *«You are out of that consumable»* **para siempre** sobre una mochila con dos frascos
  adentro. El **Tourniquet de Coagulant** (`unique` + `onUse` + *«Not consumed»*) lleva meses en ese
  estado exacto.
- **Un stack CON condición también**, y ése ni siquiera avisaba: `CountItem` lo contaba (el guard
  pasaba) y después `FindEntry` fallaba por el `condition ~= nil`, así que `UseEntry` devolvía
  `false` **sin un solo `Notice`**. Un stack con condición es estado **legal** y lo declara
  `shared/corpus_cargo_lan.lua` (una placa gastada que vuelve de un sub-slot, CRG-7).

Los dos son la misma forma: **una ref construida a mano que sólo empareja una de las tres formas de
entry que existen.**

### La pregunta abierta que el prompt dejó, contestada

*¿Cuando el módulo dueño muta `blob.condition` desde su `onUse`, el cliente se entera solo?* **Sí**:
`UseEntry` llama `Touch` **después** del `onUse`, y el `Sync` que eso dispara lee el blob **vivo**
de `Instances._live`. Fuera del `onUse` (un timer, daño) el dueño tiene que llamar
`Inventory.Touch` él. Escrito en el header de `cargo_dev_pills`, que es donde lo va a leer el que
lo necesite.

### El hallazgo de instrumento, y es el que más paga de la tanda

Verificando en negativo —14 sabotajes, uno por gate, exigiendo rojo— **dos dejaban la pasada verde
entera**: revertir la **celda del grid** y el **título del tooltip** a imprimir el `%` a mano.
Sabotear el *helper* daba rojo; sabotear el *sitio de llamada*, no.

**Se estaba midiendo el helper y no que alguien lo llamara. Un helper impecable que nadie usa es un
render viejo con un verde encima.** No se puede cerrar desde Lua: los overlays son closures
`Paint`/`PaintOver` **locales**, sin nombre por el que agarrarlos y sin superficie que dibujar
offline. Lo único que ve la diferencia es el **texto fuente**, así que el harness ganó un **gate de
FUENTES** que lee los archivos del cliente y es honesto sobre qué mide: no comprueba que la celda
dibuje bien, comprueba que **nadie fuera del theme vuelva a decidir por su cuenta cómo se escribe
una condición**. Corre antes de los realms (es el más barato) y **sus checks cuentan en el total**:
un gate que no suma es un gate que nadie mira.

Un check además **nació en rojo**: estaba escrito con la intuición del **piso** —la opción que el
autor descartó— y afirmaba que 33,4 % lee `1/3`. Con techo lee `2/3`. Quedó en el harness con esa
nota al lado, porque un check que se equivocó una vez y se corrigió es la prueba de que discrimina.

### Medición

Harness `harness_cargo.py`: **852 → 910 verdes** (37 en server, 15 en cliente, 6 del gate de
fuentes). Selftest: **91 → 100** server y **93 → 107** cliente, los dos en 0 fallas. `glua_check.py`:
48/48 parsean. **Los 14 sabotajes en rojo, uno por uno.**

### Pasada en juego ✓ (2026-08-19) — **12 de 12**, y los dos totales clavados

Planilla `dev/checks/cargo-usos-r1.html`: **Pasa 12 · Falla 0 · Sin correr 0**. `cargo_selftest`
**100 OK, 0 fallas** y `cargo_selftest_cl` **107 OK, 0 fallas** — los dos números **exactamente**
los que el harness offline había anticipado, que es lo único que acredita a ese instrumento.

Lo que la corrida dejó registrado y vale la pena citar, porque son los criterios que discriminaban:

- **El descuento se vio en el mismo botón**, con su antes y su después: `You take a pill. 2/3
  left.` → `1/3` → `0/3` → **`The bottle is empty.`** dos veces. El frasco **no desapareció** al
  llegar a 0 y el que contestó fue el `onUse` del módulo dueño, no Cargo.
- **El control negativo aguantó**: un ítem sin `uses` *«sigue diciendo condición de 100»*. La
  conversión no se filtró a quien no la pidió.
- **La regla de selección se vio hacer lo suyo dos veces**: con un frasco abierto y otro intacto,
  F1 terminó el abierto (`2/3` → `1/3` → `0/3`) y recién con ese vacío saltó al lleno (`2/3
  left`). Es la línea de log que separa «eligió bien» de «eligió cualquiera».
- **Y con la mochila vacía** volvió el aviso de siempre: `You are out of that consumable.`

### Lo que la pasada abrió, y es del autor

Nota del check 07, textual: *«el wheelmenu y el quickmenu deberían mostrar del ítem la cantidad de
usos más que la cantidad del ítem»*. Tiene razón y es **la misma pregunta de esta entrada sobre
una cuarta superficie**: el chip dice `x2` —dos frascos— pero la tecla dispara sobre **uno solo**,
el más gastado, así que **el número que se muestra no predice lo que va a pasar al apretar**. Es
justamente el `QuickCount` que el parche 6 arregló para que contara las dos clases: quedó contando
bien la cosa equivocada. **No se implementó acá** — el autor mismo dejó la forma abierta
(*«o no sé, tal vez»*) y hay al menos tres, que es lo que la vuelve una entrada de roadmap y no un
parche: **roadmap #71**.

---

## 70. El orden del grid es del jugador, y una celda es un stack (roadmap #67) `[APLICADO 2026-08-19]`

**Pedido del autor (2026-08-19):** *«quedan desordenados los items (…) que el inventario guarden
posición los items entre el grid (aunque el grid sea infinito ya que el limitante del jugador es el
peso)»* y *«de la munición de pistola (120 balas el stack), el límite para apretar sobre ese item
del inventario sea 120 y que no vendas las 800 balas de inmediato»*.

### Los dos pedidos tenían la misma raíz, y no era la que parecía

Parecían dos frentes. El diagnóstico los juntó: **una entrada de stack no tiene identidad** — los
únicos llevan `uid` y los stacks se nombran por `{ id, condition }`. Sobre eso no se puede colgar
una posición (no hay a quién) ni acotar el SHIFT al stack clicado (no hay cómo nombrar *ése*).

**Pero para la mitad del comercio la identidad resultó innecesaria, y ahí está el ahorro del
bloque:** dos stacks del mismo `id` y la misma `condition` son **fungibles**. 120 balas de 9×19 son
120 balas de 9×19 en cualquier celda. Lo que un clic tiene que mandar nunca fue *cuál* stack, sino
**cuánto** — y eso lo arregla el cliente, en una función. La identidad sólo hacía falta para la
posición, y ahí se llama `ord` y **no viaja en ningún ref**.

### Lo que estaba mal, medido

1. **La posición era una función del contenido.** El cliente re-derivaba el orden entero en cada
   `Refresh()` (`grid.lua`), así que nada podía quedarse donde se lo puso y cada pickup reflowaba
   el grid bajo el cursor.
2. **Un desempate que no desempataba.** El comparador terminaba en
   `(a.uid or "") < (b.uid or "")`; para dos *stacks* eso compara `""` contra `""`. `table.sort` de
   Lua es quicksort y **no es estable**, así que el x120 y el x80 de la misma munición se
   intercambiaban entre syncs sin que nada hubiera cambiado. Es la mitad del *«se ve desordenado»*
   que no era el layout.
3. **SHIFT+click vendía la reserva entera.** `ClickAmount` devolvía `Available`, el **agregado**
   sobre las siete entradas que respaldan 800 balas. El agregado es correcto y se queda —nació de
   un informe en juego del 2026-07-14, porque sin él el stack gemelo quedaba inalcanzable—, pero
   como **cantidad de un clic** convierte un cargador en toda la mochila.
4. **El contenedor no partía por `max_stack`.** `AddContStack` mergeaba sin techo y la siembra de
   stock del trader tampoco partía, así que una caja podía mostrar una sola celda diciendo `x800`:
   la regla *«una celda es un stack»* que el jugador aprende en su propio grid dejaba de valer al
   abrir una caja.
5. **Un falso «no pude mover todo», VIVO desde antes de este bloque.** `Take all`/`Move all` arma
   una lista de refs, uno por entrada. Con 800 balas partidas en siete, el **primer** ref se lleva
   las siete y los otros **seis no resuelven nada** — y «no resolvió» es lo que ese loop lee como
   *bloqueado*. El aviso *«Couldn't move everything»* salía sobre una operación que había
   funcionado entera. Estaba vivo del lado `put` (el grid del jugador siempre partió) y el punto 4
   se lo habría traído también a `take`.

### Lo que se escribió

- PARCHE 1 — `shared/corpus_cargo_items.lua`: **`Items.MaxStack(def)`** y
  **`Items.AutoSortLess(a, b)`**, las dos en shared. El techo estaba re-tipeado en cuatro archivos
  como `def.max_stack or math.huge` y por eso el contenedor pudo quedarse sin él; el criterio de
  orden estaba re-tipeado en el cliente. `MaxStack` además **pisa en 1** un techo declarado bajo 1:
  los dos loops que parten stacks hacen `count - put` y con `put = 0` no terminan nunca. Acuñado
  como **CRG-72**, sede `Cargo_Architecture.md` §7.2. **[PENDIENTE]**
- PARCHE 2 — `server/corpus_cargo_inventory.lua`: el campo **`ord`**, estampado por los **dos
  funnels** (`SaveRecord` y `BuildSnapshot`) para que las ~8 rutas que agregan una entrada no
  tengan que acordarse. Dos regímenes decididos por el **estado del propio record** y no por un
  flag persistido: nadie tiene `ord` ⇒ se siembra entero con el criterio (la primera carga se ve
  igual que siempre); ya hay ⇒ los recién llegados van **al final**. Más
  **`Inventory.SortGrid`** + el intent `cargo_sort`, rate-limitado a 0,25 s porque es el único
  receptor **sin payload que validar**. **[PENDIENTE]**
- PARCHE 3 — `client/corpus_cargo_grid.lua`: el comparador respeta `ord` cuando la lista lo trae y
  cae a `Items.AutoSortLess` cuando no (contenedor y stock del trader — una caja no es del jugador
  para acomodarla). Se borra la copia local del criterio. **[PENDIENTE]**
- PARCHE 4 — `client/corpus_cargo_ui.lua`: el botón **Sort**, alineado a la derecha de la fila de
  tabs. Ahora que hay un orden del jugador, volver al automático tiene que ser algo que él
  **aprieta** y nunca algo que un refresh haga por atrás. **[PENDIENTE]**
- PARCHE 5 — `client/corpus_cargo_trade.lua`: **tres** cantidades por clic, voto del autor.
  `M1` = un cuarto del techo (30 de 120, sin cambios); **`SHIFT+M1` = el stack clicado**
  (`entry.count`, o sea 120 en una celda llena y **80** en la del resto — la cantidad sale de la
  celda, no del techo de la def); `CTRL+SHIFT+M1` = todo, el comportamiento viejo entero.
  **[PENDIENTE]**
- PARCHE 6 — `server/corpus_cargo_containers.lua` + `server/corpus_cargo_trade.lua`: el contenedor
  y la siembra de stock parten por `max_stack`. Y como partir crea el problema de *«el clic pidió
  120 y esta entrada tiene 80»*, la transferencia pasa a **derramar** sobre las entradas que
  respaldan el ref (`StackTotal` + `DrainStack`) — que es lo que ya hacía el basket del trade.
  **[PENDIENTE]**
- PARCHE 7 — el mismo `containers.lua`: **la lista de refs de `Take all`/`Move all` se dedupea por
  `RefKey`**. Cierra el punto 5. **[PENDIENTE]**

### Lo que NO se hizo, y por qué

El autor votó **nivel 1** de posicionamiento: orden persistido, sin arrastrar. **No** hay `slot` de
celda, ni colisión de footprints, ni drag-to-place. La enmienda del 2026-07-11 (*«el footprint es
sólo render, sin gestión espacial»*) **sigue en pie**; §7.2 sólo le saca al orden el ser una función
del contenido.

### El hallazgo de método

**Lo más caro del bloque no fue el código: fue medir el alcance.** El pedido nombraba dos frentes
grandes y uno de los dos (SHIFT sobre un stack) se cerró con **una función de cinco líneas en el
cliente**, porque la premisa *«a la munición le falta información para separar stacks»* era falsa —
`AddStack` parte por `max_stack` desde el Block 1 y las 800 balas **ya eran siete entradas**. Lo que
faltaba no era partir: era **no volver a sumarlas al hacer clic**. Y de medir ese alcance salieron
**dos defectos vivos que nadie había pedido** (el punto 2 y el punto 5), los dos silenciosos.

### Medición

Harness `harness_cargo.py`: **910 → 945 verdes** (25 en server, 8 en cliente, 6 del gate de
fuentes, que además aprendió a leer archivos de `server/`). Selftest: **100** server y **107**
cliente, los dos en 0 fallas y sin moverse — el bloque no toca su superficie. `glua_check.py`:
48/48 parsean. **Verificación en negativo: 12 sabotajes, 12 en rojo**, con control de apertura y de
cierre en verde (`dev/sabotaje_cargo_67.py`).

### Pasada en juego (2026-08-19) — PASÓ, con una enmienda de tecla

El autor verificó las tres cosas: el botón **Sort**, el `SHIFT+M1` sobre un stack y el «todo».
**Enmienda votada en la misma pasada:** el «todo» pasa de `CTRL+SHIFT+M1` a **`ALT+SHIFT+M1`**,
porque **CTRL está bindeado a agacharse** — sostenerlo para comprar munición deja al jugador en
cuclillas apenas se cierra el menú. Un modificador de menú no puede ser una tecla de movimiento.
Aplicada, con sus dos checks del harness re-escritos (y las constantes `KEY_LALT`/`KEY_RALT` reales
en el prelude, que es lo que permite que el check distinga SHIFT de ALT+SHIFT en vez de estar verde
por no poder fallar).

De la misma pasada salieron **tres frentes nuevos**, todos anotados en el roadmap y ninguno tocado
acá: **#68** (el ref de un stack nombra la primera entrada y no la celda que apretaste — el «meto
el 107 y entra un 120»), **#69** (la gramática del clic en contenedores, que quedó inconsistente
con la del trade justo por este bloque) y **#70** (el nivel 2 del grid: el empaque sigue dejando
huecos porque la altura de una fila es la del tile más alto).

## 71. El ref de un stack nombra la celda que apretaste (roadmap #68) `[APLICADO 2026-08-19]`

**Pedido del autor (en juego, 2026-08-19):** *«al meter al belt, ese que tiene 107 se mete otro de
120, incluso bote toda mi municion de pistola del grid y salieron 6 items de pistola en vez de los
4 que tengo en el grid, esa es la inconsistencia que quiero arreglar»*. Y al confirmarle que el
stack de 107 no era un bug, precisó el pedido: *«Si se que no es bug lo del 107, pero eso es lo que
quiero, que en vez de mandar 120 de otro stack, se mande justo ese stack de 107 al belt»*.

O sea: **la celda que apretás tiene que ser la celda que se mueve.** No era «arreglar la munición».
La munición estaba bien.

### No se estaban creando balas, y decirlo primero es lo que ahorró la ronda

La conservación se cumplía. Lo que no se cumplía era **cuál** entrada se movía. `FindEntry`
resolvía un ref de stack —`{ id, condition }`— contra la **primera entrada que emparejaba**; el
cliente armaba ese ref desde la celda que se apretó, pero **la celda no viajaba en el ref**.

Perseguir un duplicador habría costado la ronda entera. Y el 107 tampoco era el defecto: `AbsorbType`
del pool devuelve al cinturón lo que sale de un cargador hasta el techo y derrama el resto al grid,
que mergea bajo `max_stack`. **Un 107 es una descarga que volvió**, no munición mal partida.

### Los dos síntomas del reporte son UN defecto

1. **El cinturón.** `BeltSet` movía la primera entrada de 9×19, que tenía 120. El slot mostraba 120.
2. **El piso.** `DropEntry` clampeaba `count` al `entry.count` de la **primera**, así que botar la
   celda de 107 sacaba 107 de una de 120 y dejaba **un resto de 13** — un ítem más en el piso que
   celdas en el grid, con el total intacto. Vaciar el grid apretando siempre la celda más chica (que
   es lo que hace cualquiera mirando un 107 entre tres 120) tomaba **siete clics y dejaba siete
   ítems**: 107, 13, 107, 13, 107, 13, 107. De ahí el *«salieron 6 en vez de 4»*.

Y eran **cinco** los caminos que compartían ese `FindEntry` y decían «la primera»: `Equip`,
`UseEntry`, `DropEntry`, `BeltSet` y `SubSlotAttach`.

### Lo que se escribió

- PARCHE 1 — `server/corpus_cargo_inventory.lua`: el campo **`cid`**, una identidad estable por
  entrada. Se acuña **una vez** en el mismo funnel del `ord` —`StampEntries`, que llama a `StampOrd`
  y a `StampCid`, invocado por `SaveRecord` (disco) y `BuildSnapshot` (cable)— y **no se reasigna
  nunca**. El contador vive **en el record** y se persiste: derivarlo de «el mayor `cid` vivo más
  uno» reciclaría el número de una entrada que acaba de irse, y un número reciclado es exactamente
  lo que dejaría a un intent viejo disparar sobre una celda que el jugador nunca apretó. Sólo cuenta
  hacia arriba. Acuñado como **CRG-73**, sede `Cargo_Architecture.md` §7.3. **[PENDIENTE]**
- PARCHE 2 — el mismo archivo: **`FindEntry` honra el `cid`** cuando el ref lo trae, resolviendo a
  esa celda y **a ninguna otra**, y sigue matcheando `id`+`condition` de paso. Un ref **sin** `cid`
  cae a la primera igual que siempre. **[PENDIENTE]**
- PARCHE 3 — el mismo archivo: **`FindCell`**, por donde resuelven los cinco caminos que mueven una
  celda. Una celda que ya no está no cae a la primera —*ese fallback es el defecto*— y tampoco falla
  muda: avisa *«That stack is no longer in that cell.»*, una sola vez, y cada camino conserva su
  propia frase para el fallo ordinario. **[PENDIENTE]**
- PARCHE 4 — el mismo archivo: **`EntrySnapshot`** lleva el `cid` al cable (también en los únicos,
  para que el #70 no tenga que inventar una segunda regla), y **`QuickTarget`** lo devuelve. Ese
  segundo importa más de lo que parece: **elige** una entrada entre varias —la regla de la #66, el
  frasco más gastado— y sin el `cid` la elección se calculaba y se tiraba. **[PENDIENTE]**
- PARCHE 5 — `client/corpus_cargo_grid.lua`: **`Grid.RefOf`** pone el `cid` en el ref. Es el único
  sitio del cliente que arma un ref de stack —los 16 intents pasan por ahí—, así que sin este
  renglón todo lo anterior es inalcanzable. **[PENDIENTE]**

### Las tres decisiones, con lo que se descartó

- **`cid` estable y no el `ord` del #67** (voto del autor). El `ord` era la opción barata: ya existe,
  ya se persiste, ya viaja. Pero el botón **Sort** reescribe todos los `ord` de una, así que un
  intent que nombrara un `ord` lo podía re-apuntar un re-orden aterrizando entre el clic y el
  paquete — el bug volvería justo después del gesto que el #67 le acaba de dar al jugador. El `cid`
  se paga una vez y **paga también la mitad del #70**, donde un intent de arrastre tiene que decir
  *«mové ESTA celda al slot 12»*. Por eso el #68 iba antes que el #70.
- **La celda perdida falla y avisa** (voto del autor), en vez de caer a la primera. Cae un clic en
  una carrera rara; lo que se compra es que **si algo se mueve, es la celda que apretaste**.
- **NO un blob por stack**, que fue la propuesta del autor (*«¿cada stack de 120 podría ser un blob
  propio?»*). Se puede, y es la herramienta cara y equivocada: un blob existe para guardar
  **historia** (condición, attachments, `clip1`) y dos stacks de 9×19 no tienen ninguna que los
  distinga. Costaría un blob persistido por stack de munición en el record de cada jugador,
  rotación de `uid` en cada merge y cada split, y rompería el espejo cinturón↔pool, construido sobre
  «N balas del tipo T» y no sobre «este montón». Sería pagar con un **objeto de persistencia** lo
  que resuelve un **campo**.

### El alcance es POR CAMINO, y esa mitad es la que hay que defender

Pasan a nombrar la celda: `Equip`, `UseEntry`, `DropEntry`, `BeltSet`, `SubSlotAttach`.

**Conservan la semántica de cantidad, a propósito:** el basket del trade (`MatchesRef`,
`Trade.RefKey`) y la transferencia de contenedores (`StackTotal`, `DrainStack`). Ahí el agregado es
lo que mantiene **alcanzable** al stack gemelo — informe en juego del 2026-07-14 —, así que
«arreglarlos» rompería aquello. Los tres resolvedores ignoran el campo nuevo **sin una línea de
cambio**, y el bloque lleva **cuatro controles negativos** que lo miden en vez de suponerlo: pedir
200 sobre una celda de 120 sigue cruzando las dos celdas, y dos celdas con `cid` distinto siguen
cayendo en la misma línea del basket. Los dos controles se verificaron **en negativo** (sabotajes 15
y 16): sabotear `StackTotal` y `RefKey` para que mirasen el `cid` los pone en rojo, o sea que no
están verdes por no ejercitarse.

### El censo que decidió el tamaño del parche

Antes de escribir se contó, con denominador, **quién arma un ref de stack** en todo el módulo: 45
líneas con `condition =`, 19 tablas literales candidatas, y de ésas exactamente **dos** alimentan a
`FindEntry` — `Grid.RefOf` y `QuickTarget`. Las otras 17 son snapshots, payloads al mundo, slots de
equipo y del cinturón, o entradas que `CleanStack` reconstruye. Ese censo es lo que evitó tocarlas:
la lección 89 dice que medir el helper no mide que alguien lo llame, y acá el helper del cliente
tenía **un** hermano oculto, no ninguno.

Y ese hermano —`QuickTarget`— es un frente que el pedido no nombraba: elegía el frasco más gastado
y le entregaba a `UseEntry` un ref que resolvía al primero.

### El hallazgo de método: un verde que no podía fallar

El sabotaje 14 —*«el botón Sort pisa el `cid`»*— salió **VERDE** en la primera corrida de la
verificación en negativo. La causa no era el código: en un grid **recién nacido** los `cid`
coinciden con sus posiciones (1..N), así que pisarlos con la posición reescribe **los mismos
números** y el check no tenía cómo fallar. Estaba verde por una coincidencia del sujeto, no por el
mecanismo.

El arreglo fue darle **churn** al grid del check —un grid real lo tiene, así que la forma sin churn
era la excepción— y dejarle una **precondición** que lo delate: *«los `cid` de este grid NO coinciden
con sus posiciones»*. Sin esa fila, el mismo agujero puede volver la próxima vez que alguien toque el
bloque.

En la misma tanda hubo un segundo defecto de instrumento, más chico: el gate de fuentes imprimía 18
checks y su total decía **4**, porque el `for` del control por cuenta usaba `n` como variable y `n`
era el contador del `check`.

### Los controles POR CUENTA (lección 89)

Dos gates de fuente nuevos no preguntan si un patrón **existe** sino **cuántas veces**: `FindCell`
tiene que aparecer en **5** sitios de llamada y `FindEntry(rec, ref)` en **3** (el propio `FindCell`
más las dos re-resoluciones internas de `Equip`). Un gate de existencia deja pasar la reversión de un
**sitio de llamada** — devolver uno de los cinco caminos a `FindEntry` pelado deja verde a los otros
cuatro. El sabotaje 12 lo prueba: revierte sólo `BeltSet` y la pasada se pone roja.

### Medición

Harness `harness_cargo.py`: **945 → 985 verdes** (25 en server, 8 en cliente, 6 del gate de fuentes
— dos de ellos por cuenta —, más la fila de precondición del Sort). Selftest: **100** server y
**107** cliente, los dos en 0 fallas y sin moverse. `glua_check.py`: 48/48 parsean. **Verificación en
negativo: 16 sabotajes, 16 en rojo**, con control de apertura y de cierre en verde
(`dev/sabotaje_cargo_68.py`).

Y el instrumento del #67 siguió a su código: el rename `StampOrder` → `StampEntries` dejaba dos
anclas de `dev/sabotaje_cargo_67.py` apuntando a nada, o sea una verificación en negativo desarmada
en silencio. Actualizadas y **re-corridas: 12/12 en rojo**.

### Pasada en juego (2026-08-19) — PASÓ

**Los dos síntomas del reporte, cerrados**, y el segundo es el que discrimina de verdad:

1. **El cinturón** — *«Traspasar municion al belt que sea menor al stack funciona (Pase 84 balas
   directo al belt sin dramas)»*. La celda que se arrastra es la que viaja.
2. **El piso** — *«Parece que si cada stack contiene la municion que le corresponde al botar, tenia
   7 stacks de ammo de pistol y salieron las 7»*. **Éste es el que no se puede cumplir por
   casualidad:** con el código viejo, vaciar un grid de siete celdas dejaba **más ítems que celdas**
   (los restos de 13 que quedaban al recortar contra la primera entrada). Siete celdas ⇒ siete
   ítems es exactamente lo que el defecto impedía.

**Selftests en juego, clavados con lo que el harness offline había predicho:** `cargo_selftest`
**100 OK / 0 fallas** y `cargo_selftest_cl` **107 OK / 0 fallas**.

**Un comportamiento que el autor verificó y NO es de este bloque:** sacar munición del cinturón
**rellena** un stack del grid hasta el techo — *«Tienes 100 en un stack del inventario y 80 en el
belt → traspasar al inventario → ahora tienes un stack de 120 y otro de 60»*. Es `AddStack`
mergeando bajo `max_stack`, y es correcto desde el Block 1: una celda es un stack, así que lo que
vuelve llena la que hay antes de abrir otra. El autor lo cerró él mismo con el control que
correspondía —*«tire ambas y salen con los valores correctos»*—, que es medir la **conservación** en
vez de discutir la forma.

**La deuda que dejó, cerrada el mismo día.** Las filas 3 a 8 quedaron SIN CORRER en esta primera
pasada y se declararon así en vez de acreditarse (precedente AB14 del #53). Las cerró una planilla de
13 filas — sección **AD**, `dev/checks/cargo-celda-r1.html`.

### Planilla AD (2026-08-19) — 12 PASA · 1 RETIRADO

Los cinco caminos, uno por uno y todos verdes: el cinturón con la celda rara, el piso con las cuatro
celdas, el **Sort seguido del arrastre** (que es la fila que separa el `cid` del `ord`), el equip
desde la celda de `x2`, el uso desde la segunda celda de medkits y el montaje en sub-slot desde la
de `x1`. La **celda perdida** contestó las dos mitades del voto: no movió nada **y** el chat dijo
`[Cargo] That stack is no longer in that cell.`. Y los controles negativos del trader, de la tecla
rápida y del relleno del cinturón quedaron intactos.

**AD11 se RETIRA por premisa mal escrita, y no es un rojo pendiente.** La fila pedía *«pedir 200
sobre una celda de x120 y que cruce a la de al lado»*. El server hace exactamente eso —`StackTotal`
y `DrainStack` derraman sobre todas las entradas que respaldan el ref—, pero **la UI nunca ofreció
ese gesto**: `Transfer.Menu` anuncia `1 - 120` y clampea con `math.min(n, entry.count)`, o sea al
**cell** clicado. El criterio estaba escrito desde la capacidad del **server** y redactado como un
gesto de **interfaz**, así que sólo podía dar rojo. Confundir eso con un defecto dejaría deuda
fantasma en el registro (misma distinción que AB8 y AC2).

**Y el mecanismo que esa fila existía para proteger SÍ quedó verificado, por su otra mitad:**
*«Move all y take all funciona bien»*. `Move all` manda **un** ref deduplicado por las cuatro celdas
de 9 mm y mueve las 467. Si el campo nuevo se hubiera filtrado al contenedor, ese mismo gesto habría
movido **120** y se habría quedado con tres celdas adentro. El control negativo del alcance está
medido; lo que estaba mal escrito era el gesto con que se lo pedía.

**Lo que la fila destapó de verdad es un pedido, no un defecto**, y el autor lo dijo así: el
contenedor no tiene la **gradación** del clic que el trade sí tiene. Va al roadmap **#69**, que
salió de esta pasada con la gramática ya votada.

---

## 72. La gramática del mouse: M1 selecciona, M3 deselecciona, M2 es el menú (roadmap #69) `[APLICADO 2026-08-20]`

**Pedido del autor (en juego, 2026-08-19, al llenar la planilla AD del #68).** Cuatro frases, y la
última es la entrada:

> *«Hay que mejorar el como funcionan los contenedores (…) el enviar tiene que ir de cuartos por
> stack y completo el stack con SHIFT+M1, todos del mismo tipo con ALT+SHIFT+M1»*
> *«Otra cosa del trader, hay que permitir deseleccionar de a cuartos con M3, deseleccionar un stack
> completo con SHIFT+M3 y deseleccionar todos del mismo tipo con ALT+SHIFT+M3»*
> **«Al final como norma es que M1 selecciona, M3 deselecciona y M2 es el boton contextual»**

Las tres primeras son **casos**. La última es la norma, y por eso la entrada del roadmap dejó de
llamarse *«los contenedores: el clic debería transferir»* y pasó a nombrar el módulo entero.

### Por qué esto es una norma y no un feature

Dos pantallas del mismo módulo tenían **dos gramáticas para el mismo gesto**: en el trade un clic
cargaba un cuarto del techo desde el #67, en el loot mandaba el stack entero de la celda. **Nadie lo
decidió.** Se escribieron en tandas distintas y cada una eligió sola.

Sin un ID que diga qué significa cada botón, la próxima pantalla vuelve a inventar la suya — que es
exactamente cómo nació esta entrada. Por eso el entregable no es «los contenedores ahora graduan»:
es **CRG-74**, con sede en §15.6, la sede de la UI.

### Los tres niveles, y la única casa que los resuelve

Los dos botones que mueven una cantidad leen **los mismos tres**:

| Gesto | Cuánto |
|---|---|
| pelado | un **cuarto del TECHO** (`def.max_stack`), repetible — un cargador |
| `SHIFT` | **la CELDA que se apretó**: lo que esa celda dice (#67) |
| `ALT`+`SHIFT` | **todo lo de ese ítem de ese lado** — el agregado |

Un `unique` es siempre 1. Una def **sin `max_stack`** no tiene techo del que sacar un cuarto y cae al
agregado, que para un arma o un botiquín da 1 — la respuesta honesta para algo que no apila.

**El cuarto es del TECHO y no de la celda**, y no es un detalle de implementación: tiene que ser el
mismo bocado con una celda llena que con una de siete balas, o vaciar un stack casi vacío costaría
los mismos cuatro clics que vaciar uno lleno.

**`ALT` y nunca `CTRL`, y el motivo es del JUEGO y no de la UI** (voto del autor): CTRL está bindeado
a agacharse, así que sostenerlo para comprar munición deja al jugador en cuclillas apenas se cierra
el menú. Un modificador de menú no puede ser una tecla de movimiento.

**Una sola función lo resuelve** — `CARGO.Grid.ClickAmount(entry, aggregate)`, que es **el único
lugar del módulo que lee una tecla modificadora**. Las cuatro superficies llegan por **dos
adaptadores** que sólo eligen *sobre qué lista* se cuenta el agregado:

- `Trade.ClickAmount(side, entry)` — el stock del trader o el grid del jugador;
- `Transfer.ClickAmount(dir, entry)` — el contenedor o el grid del jugador.

Escribir la gradación dos veces la desincroniza **sin un solo error**. Es el mismo argumento que
llevó el texto de condición a `Theme.ConditionShort` (#66) y el criterio de orden a
`Items.AutoSortLess` (#67). Y **M1 y M3 preguntan a la MISMA función**: seleccionar y deseleccionar
no pueden derivar si el número sale del mismo lugar.

### La mitad de M3, que no existía en ninguna pantalla

Esto **no es «agregarle niveles a algo que existía»**. Hasta esta entrada, «deseleccionar» era un
solo gesto sin gradación: hacer clic en la fila del basket, que borraba la línea entera. En el loot
no había «deshacer» de ningún tipo.

`Trade.BasketTake(side, key, count)` es la mitad nueva. Una línea que llega a cero **se borra** en
vez de quedar como un `x0` en la tira: el basket es intent puro (`Cargo_Trade` §3) y un intent vacío
no es un intent.

**El botón llega a la celda por herencia de Derma, y se leyó en la FUENTE del motor y no de memoria:**
un `DButton` deriva de `DLabel` (`dbutton.lua:179`) y `DLabel:OnMouseReleased` despacha
`MOUSE_MIDDLE` a `DoMiddleClick` (`dlabel.lua:257`). El grid no pisa `OnMousePressed` ni
`OnMouseReleased` en sus celdas, y `Droppable` no toca los handlers (sólo llena `m_DragSlot`). Se
cablea **una vez, en la celda del grid** y no en las tres superficies: lo que cambia entre ellas es
qué le cuelgan, no cómo les llega.

> ⚠ **El despacho es en `OnMouseReleased`, NO en pressed.** Si algún día hace falta pisar uno de esos
> dos handlers en una celda, hay que **re-emitir el despacho** o M3 deja de disparar **sin un solo
> error**.

### Las dos excepciones, y las dos son votos del autor

Van **escritas**, no disimuladas:

1. **M3 no hace nada en el LOOT.** La otra lectura era la **transferencia inversa** —M3 manda de
   vuelta, con los mismos tres niveles— y era la recomendación del diseño. El autor la rechazó:
   *«es contraintuitivo, jamás había visto un sistema así de inventario en juego donde tomes por
   transferencia inversa»*. La norma se lee entonces como **«M3 deselecciona donde hay algo
   seleccionado»**, y en el loot la transferencia es inmediata: no hay carrito, así que
   «deseleccionar» no tiene referente. El camino de vuelta ya existe y es **M1 sobre la otra
   columna**, que es donde todo inventario lo pone.
2. **En la FILA del basket, M1 quita.** Es el único lugar del módulo donde M1 no agrega. El diseño
   recomendaba dejarla como «sacar todo» y decir por qué; el autor eligió **darle las cantidades**:
   *«es más consistente de verdad, apretar shift+m1 se va a aprender fácilmente para todo, así el
   jugador no memoriza mil formas distintas de interactuar con funcionalidades similares»*. Se
   conserva el botón porque una fila es una entrada de **LISTA** y no una celda: existe sólo porque
   algo ya está seleccionado. Y ahí `ALT+SHIFT` saca **lo mismo** que `SHIFT` —la línea— porque **una
   línea de basket YA ES el agregado de su ref** (una por `RefKey`): no es un nivel que la fila no
   distingue, es el mismo número **por construcción**, y se declara así para que ningún check afirme
   distinguir dos cantidades que son una sola.

### Qué NO cambia

- **`Transfer.Menu`** (el «enviar cantidad» del click derecho) queda **exactamente como está**: el
  autor lo declaró bien (*«el enviar cantidad esta bien segun stack y como funciona actualmente»*).
  Su clamp `math.min(n, entry.count)` es una **decisión del cliente**, coherente con «una celda es un
  stack» (#67) — no una falla. Es lo que hizo dar rojo a la fila **AD11** del #68, que se retiró por
  premisa mal escrita.
- **M2 no cambia de significado** en ninguna pantalla.
- **El `cid` de CRG-73 no se toca.** Lo que una celda manda por estos gestos es una **CANTIDAD**, no
  una identidad: los dos caminos que preguntan cuánto —el basket y la transferencia de
  contenedores— siguen **agregando**, y sus cuatro controles negativos quedaron verdes **sin haber
  sido tocados**. Dos stacks del mismo `id` y `condition` son fungibles.
- **El estado suelto** del grid propio sigue con `OpenItemMenu` en M2 y sin transferencia: no hay a
  dónde mandar nada, y tampoco nada que deseleccionar.

### El costo, dicho antes de la pasada y no después

En el loot un M1 pelado **pasa a mandar un cuarto**, así que mover un stack completo son cuatro
clics — o un `SHIFT+M1`. Es lo que el autor pidió explícitamente, así que no es una objeción, pero
es la pantalla que más se usa y el cambio se siente ahí.

### Archivos

- `client/corpus_cargo_grid.lua` — **`Grid.ClickAmount`** (la casa única) y **`Grid.Aggregate`** (el
  conteo, mudado desde el trade porque ahora lo pide también el loot), más el cableado de
  `cell.DoMiddleClick` y el `opts.onMiddleClick` del contrato del grid.
- `client/corpus_cargo_trade.lua` — `Trade.ClickAmount` pasa a ser un **adaptador**;
  `Trade.BasketTake` (la mitad de M3); el `onMiddleClick` del stock; la fila de la tira gradada, con
  `LineAsEntry` para que lea **la línea** y no la última celda que la alimentó; y dos marcas
  (`cargoBasketSide`/`cargoBasketKey`) que le dan a la fila un asidero, igual que `cargoEntry` en una
  celda.
- `client/corpus_cargo_transfer.lua` — **`Transfer.ClickAmount`**, el adaptador del loot.
- `client/corpus_cargo_ui.lua` — las **dos** superficies del loot piden su cantidad al adaptador; el
  grid propio gana `onMiddleClick` **sólo en estado `trade`**.

### Verificación

- `glua_check` **48/48**.
- Harness **985 → 1038 verdes** (`dev/harness_cargo.py`): **39** checks de conducta en CLIENT y
  **14** en el gate de FUENTES, **seis de ellos POR CUENTA**. Selftest **100 server / 107 client**,
  sin moverse: el bloque no toca su superficie.
- **19 sabotajes en rojo, 19 de 19** (`dev/sabotaje_cargo_69.py`), con control de apertura y de
  cierre en verde.

**Cómo se mide una casa única, que es lo que esta tanda tuvo que inventar:** que `Grid.ClickAmount`
exista no dice nada. Lo que hace que la gradación sea **una** es que **ningún otro archivo lea una
tecla**, así que el gate cuenta los **cuatro** únicos usos de `input.IsKeyDown(KEY_…)` del módulo
entero y **prohíbe el patrón** en los otros tres archivos de cliente. Un segundo lector no revienta
ni se ve: devuelve otro número y se desincroniza en silencio.

**Y los sitios de llamada se CUENTAN, no se comprueban** (lección 89): sabotear la gradación pone la
pasada entera en rojo, pero **devolver UNA de las cuatro superficies a su cantidad de antes la deja
verde**, porque las otras tres siguen midiendo bien. Dos de los 19 sabotajes son exactamente eso y no
tocan la gradación en absoluto. Además, el bloque aprieta **las celdas de verdad**: abre un
contenedor por su receiver real, busca los paneles que el grid creó y llama sus `DoClick` /
`DoMiddleClick` interceptando `Transfer.Send`.

**Dos cuidados de instrumento que la tanda pagó:**

1. **Los tres niveles sólo discriminan sobre una celda cuyo `count` NO sea el `max_stack`** — con la
   celda al tope, «un cuarto del techo» y «lo que dice la celda» dan 30 y 120, pero el `ALT+SHIFT` de
   un stack solo da 120 también y la fila deja de distinguir dos niveles (**lección 94**, que costó
   una vuelta en el #68). El bloque mide sobre una **x80 con agregado 200**. Y las **dos listas del
   loot son distintas a propósito** (caja 200, jugador 120): con las dos iguales, un adaptador que se
   equivocara de lista devolvería un número creíble y ningún check lo vería.
2. **Mudar la gradación de `corpus_cargo_trade.lua` a `corpus_cargo_grid.lua` dejó el sabotaje 10 de
   `dev/sabotaje_cargo_67.py` apuntando a NADA**, y ese script **no revienta**: imprime `ANCLA x0` y
   sale 1, o sea que **desarma una verificación en negativo vieja en silencio**. Se re-apuntó al
   archivo nuevo y se **re-corrió**: **12/12**. El del #68 se re-corrió también y sigue en **16/16**.

### Lo que el harness NO puede decir, y por eso hay planilla

Que `cell.DoMiddleClick` esté cableado y haga lo correcto está probado offline. Que **el motor lo
despache** hasta ahí, no: la cadena se leyó en la fuente de GMod, pero que la capa de drag-and-drop
no se coma el press antes del release es **indicio y no prueba**.

Por eso la **primera fila de la planilla AE** es una **medición y no un veredicto**: que el botón del
medio **llegue**. **Si esa fila no pasa, todas las de M3 quedan SIN CORRER y NO en rojo** — un
cableado que no dispara se ve exactamente igual que una regla mal escrita, y marcarlas rojas
acreditaría un defecto de reglas que nadie midió.

**Pasada en juego:** planilla **AE** (`dev/checks/cargo-mouse-r1.html`), **cerrada 14/14 el 2026-08-20** en dos rondas.

### Addendum — 1.ª pasada en juego (2026-08-20): PARCIAL, 4 PASA · 0 FALLA · 10 SIN CORRER

La corrida se cortó por cansancio del autor (6 de la mañana), no por un defecto. **Cero rojos**, y
las cuatro que corrieron son justamente las que decidían si el resto tenía sentido:

- **AE1** — selftests **100 server / 107 client**, 0 fallas, **clavados** con lo que el harness
  offline predijo. El juego corre el código medido.
- **AE2 — LA MEDICIÓN, y es la que cierra la única incógnita de la tanda.** El botón del medio
  **LLEGA** a un `DButton` que además es `Droppable`: la consola imprimió el control positivo de M1
  **y** `[AE2] M3 LLEGO` — **cuatro veces** en la sesión, o sea que dispara de forma repetible y no
  fue un golpe de suerte. Con esto queda **probado en el motor** lo que sólo era indicio: la capa de
  drag-and-drop **no se come el press del medio** antes del release. Las filas 09-12 dejan de
  depender de una incógnita y pasan a ser cobertura pendiente, no riesgo abierto.
- **AE3** — el sujeto quedó bien formado (cuatro celdas de 9 mm con una de count distinto del techo),
  que es la precondición sin la cual las filas de niveles no discriminarían (lección 94).
- **AE4 — la gradación LLEGÓ AL JUEGO.** Un clic pelado sobre la celda del contenedor trajo **30**:
  un cuarto del **techo** (120) y no de la celda (que habría dado 26) ni el stack entero. Es el nivel
  que no existía en el loot, y es el que más se va a usar.

**Lo que esto acredita y lo que no.** Acredita el mecanismo nuevo y su cableado en las dos mitades
—M1 gradúa, M3 llega—. **No** acredita los otros dos niveles ni ninguna de las excepciones votadas:
las diez filas restantes se declaran **SIN CORRER** y **no** se dan por buenas por parentesco con las
que pasaron. La entry sigue `[PENDIENTE]` por eso.

**Lo que falta, en orden de valor:** AE5/AE6 (los otros dos niveles de M1 en el loot) y AE7 (el
control negativo de la tecla suelta) cierran la mitad de M1; AE9/AE10/AE11 la de M3 y la excepción de
la fila; AE12/AE13/AE14 son los controles negativos de alcance. Las marcas de esta corrida quedan en
el `localStorage` de la planilla, así que se retoma donde quedó.

**Un defecto de INSTRUMENTO que la pasada destapó, y no es de este bloque:** la fila AE2 creaba un
popup que toma el mouse y su desmontaje estaba en la prosa de al lado, así que dejó al autor sin
poder seguir la planilla. Se corrigió llevando el `B:Remove()` a la **última línea del comando** (el
campo que se copia) y quedó como **regla 7** de `dev/PLANTILLA_CHECKS.md`. Al corregirlo se rompió el
string del campo y la planilla abrió con **0 0 0 y ninguna tarjeta** mientras
`dev/auditar_planilla.py` la declaraba **SANA**: sus chequeos leen el archivo como texto y ninguno
veía un error de sintaxis de JavaScript. Se le agregó la puerta que faltaba —`node --check` sobre el
`<script>`, y **SIN CORRER** en vez de OK si no hay node—, verificada en las dos direcciones y
barrida sobre las **101** planillas de `dev/checks/`: las 101 parsean, **cero falsos positivos**.

---


### Addendum 2 — 2.ª pasada en juego (2026-08-20): **CERRADA, 14 PASA · 0 FALLA · 0 SIN CORRER**

Las diez que faltaban corrieron y pasaron. **Ningún rojo en toda la sección**, y ningún check
retirado.

**Los números que el autor reportó, y por qué valen más que un «anda bien»:** varias filas trajeron
el reparto exacto de las celdas, así que además del gesto quedó medida la **conservación** y el
**merge bajo `max_stack`** — que no era lo que el bloque se propuso medir y es lo que lo respalda.

- **AE4** — caja con 120 y 107; clic pelado sobre la de 107 → le quedan **77** a la caja y llegan
  **30**. Un cuarto del **techo**, no de la celda.
- **AE5** — caja con 120 y 77; `SHIFT` sobre la de 77 → llegan las **77** y del lado del jugador
  queda **107**. O sea que los 30 anteriores y las 77 **se fundieron en una sola celda**: es
  `AddStack` mergeando bajo el techo, correcto y no un stack perdido.
- **AE7** — ALT solo manda y trae de **30** (vuelve al cuarto de techo) y SHIFT manda el stack. El
  control negativo de la tecla suelta discrimina.
- **AE8** — M1 manda 30: la caja queda **120 · 120 · 17** y el inventario **120 · 90**. Suman
  **467**, que es el total original: la conservación se sostiene, y el 17 no es munición mal partida
  sino el resto de re-empacar 257 bajo un techo de 120.
- **AE9** — los tres niveles andan **en las dos direcciones y en los dos lados del trato** (comprar y
  vender), y M3 los replica para quitar.
- **AE11** — la fila del carrito: un clic saca **30**, `SHIFT` saca todo. Y `ALT+SHIFT` **hace lo
  mismo que `SHIFT`**, que es exactamente el comportamiento declarado: una línea de basket **ya es**
  el agregado de su ref, así que los dos niveles son el mismo número **por construcción**. Quedó
  observado en juego, no sólo escrito.

**OBSERVADO Y ACEPTADO, para que nadie lo lea como bug después:** arrastrar sigue moviendo el
**stack entero**, en las dos direcciones — la caja recibe dos celdas de 120 y 107, y traerlas de
vuelta devuelve dos celdas de 120 y 107. El autor lo notó y lo describió como *«el símil de
SHIFT+M1»*. **Es por diseño** (§15.6): el arrastre **no es un clic**, la gramática es de los
botones, y un drag ya dice *qué* y *adónde* con el gesto. No es una gradación que se escapó.

**QUÉ SE MIDIÓ CON UN GESTO AISLADO Y QUÉ POR CONFIRMACIÓN CRUZADA, dicho porque la distinción es
la que hace citable a la planilla.** El autor lo declaró él mismo: *«no llené todas porque hay otras
que me lo confirman, y he comprado tanto al trader verificando que sí está funcional sin dramas»*.
Las filas con reparto anotado (AE4, AE5, AE7, AE8, AE9, AE11) se corrieron por su gesto y traen su
número. **AE10, AE12, AE13 y AE14 se acreditan por el uso extendido del trader y por las filas que
las cubren**, no por una corrida aislada: AE10 (la línea que se borra a cero) queda cubierta por el
`ALT+SHIFT`+M3 de AE9 y por el AE11 de la fila; AE13 por los `Move all` / `Take all` que el autor
ejercitó; AE14 por haber usado el menú contextual durante toda la pasada. **Es una acreditación
válida y se dice cuál es**, en vez de dejar entender que las catorce salieron de catorce gestos
medidos — *un verde por cobertura y un verde por gesto no son lo mismo, y confundirlos es lo que
deja deuda fantasma en el registro*.

**Con esto la norma queda acreditada en juego en sus tres mitades:** M1 gradúa en el loot y en el
trade, M3 deselecciona con los mismos tres niveles, y las **dos excepciones votadas** se comportan
como se declararon (la rueda muda en el loot, y la fila del carrito quitando con M1). Los controles
negativos del #68 siguen verdes: el contenedor y el carrito **siguen agregando**.

CHANGELOG **72 `[APLICADO 2026-08-20]`**. Planilla **AE** cerrada 14/14.
