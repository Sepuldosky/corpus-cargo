# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-31 (**entries 61-64 `[APLICADO]` — roadmap #53 CERRADO**,
confirmado en juego con la planilla **AB en tres rondas**. **La configuración ARC9 de un arma
pertenece a su instancia y viaja con ella:** sobrevive dropear y levantar, guardar y re-equipar, el
respawn y el cambio de modo de un dispositivo; el cargador vuelve con las balas que tenía;
desacoplar sin lugar en la mochila deja la pieza **en el piso** (**CRG-65**) en vez de destruirla; y
el precio cuenta los attachments. Harness **700 → 771** (71 nuevos, **15 reversiones verificadas en
negativo**); checker limpio. **Commiteado, sin push.**
**Lo primero de la tanda no fue código sino una MEDICIÓN** (AB1): `wep.Attachments` es **por
entidad** —dos AS VAL mod4 vivas con `Installed` distinto en el mismo slot—, así que el invariante
que el autor pidió era alcanzable y el plan B quedó **descartado medido**. La clave de un nodo de
`blob.atts` es **(categoría, ordinal entre hermanos)** y jamás la posición: el *address* de ARC9 es
el offset de un aplanado recursivo del build actual y **se mueve dentro de la misma partida** —su
PEQ-2 estaba en el 11 únicamente porque el riel del 10 estaba puesto—, que es CRG-63 en su forma más
fuerte.
**Las dos decisiones del autor que cambiaron el diseño, y las dos por un caso real:** (1) *"si el
objeto no puede entrar al inventario, debe caer al piso"* → **CRG-65**, y el mismo modo de falla
apareció en un **segundo** sitio que no era ARC9 (el espejo del pool de munición, con un comentario
que decía literal *"The rounds are NOT destroyed"* desde el día que se escribió); (2) el **peso de
los atts se DIFIERE al #55**, porque su MCX de 2,9 kg lleva **doce** attachments y con 0,3 kg planos
las piezas pesarían más que el arma — **cuando un número no sobrevive el contacto con un caso real,
el defecto suele estar en el modelo y no en el número**. `AttsWeight` queda escrita y **sin llamar**:
la decisión fue «todavía no», no «estaba mal», y **CRG-66 quedó enmendada en su sede** diciendo el
alcance vigente en vez de disimularlo.
**LAS TRES REGLAS DE MÉTODO, pagadas las tres en una sesión:** (1) **un check que CRASHEA no es un
check en rojo** — dos reversiones volvieron con 0 y 1 rojo y la lectura obvia («no distingue») era
falsa: la corrida moría indexando un nil y se llevaba puestos los de abajo, así que **contar
`[FAIL]` no alcanza, hay que mirar si la corrida TERMINÓ**; (2) **un check que llama a la función no
prueba que la RUTA la llame** — tres checks invocaban `SyncAttsSoon` directo y sacar las llamadas de
los hooks dejó la corrida **entera en verde** (hubo que exponer `_WireHooks`); (3) **un instrumento
no debe afirmar lo que no puede medir** — `cargo_dev_attstock` gritaba "duplicación" sobre una
**foto**, y una foto no distingue una copia de un repuesto: costó una ronda entera de diagnóstico
equivocado. Y la cuarta, que ya va **ocho** veces en este módulo: de la nota de **AB9, en PASA**,
salieron el roadmap **#54** y el propio **AB13**.
**LA FRONTERA QUE QUEDA DECLARADA, no disimulada:** la **entry 64** (`SyncAttsSoon`) cierra **sin
pasada en juego**. AB8 la medía por el peso y el peso se difirió; AB14 la iba a medir en vivo y quedó
**SIN CORRER**, porque AB13 se respondió **botando** los repuestos y no montándolos. La ruta "montar
desde el menú C" **no se ejerció con números en ninguna de las tres rondas** —AB10 no la cubre, pasa
igual con duplicación puesta— y lo que sostiene la entrada son sus 6 checks de harness con el hook
realmente cableado. Decisión del autor: cerrar con la frontera escrita en vez de retener la entrada.
**Y AB13 cerró por la vía NEGATIVA y no por la resta**: botados los repuestos, `grid=0` **y**
`hook=0` en las siete líneas y el menú dejó de ofrecerlos — el puente contesta lo que el grid tiene y
**no hay un tercer inventario**, que es la forma que tendría la duplicación.)

Antes, **entry 60 `[APLICADO]`, confirmada en juego en dos rondas y commiteada**: el SWEP **Hands**
arrastraba dos restos del port —el header declaraba *"assets removed"* desde la entry 9 y **no era
cierto**—. Los cuatro eventos de sonido horneados en `c_arms_apex.mdl` van **mudos contra
`common/null.wav`** (su foley es el único set que el port no trajo y el modelo no se recompila), y
los tres VTF eran **byte-idénticos** a los del mod original: se borran, y **un solo PNG del logo de
Cargo** sirve las tres superficies vía `DrawWeaponSelection` —el mismo método que llama el HUD
DGL4— más `SWEP.IconOverride`. **El único defecto no estaba en lo reportado sino en una suposición
sobre la caja de un tercero:** DGL4 pasa **140×100** sobre un panel de **144×72** y después
scissorea al PANEL, así que **`tall` no es la altura en la que se puede dibujar**. Las dos reglas:
**un asset renombrado no es un asset reemplazado** (la declaración sobrevivió cincuenta entries
porque nadie la contrastó contra un hash) y el harness **no carga `lua/weapons/`**, así que ahí el
número verde no era evidencia.
Antes, **entries 54-59 `[APLICADO]`, confirmadas en juego — el ARCO
#48-#52 del wheel CERRADO ENTERO**, cinco secciones de planilla (W, X, Y, Z, AA) en **23 checks** y **ni una
ronda perdida por un defecto de código**: la única que costó una vuelta fue la medición de W1, y por el
**instrumento**. Harness **639 → 700** (**61 nuevos, 19 reversiones verificadas en negativo**). **Ni una
norma nueva, ni un mensaje de red, ni una línea de server** en las cinco tandas. **Commiteado y pusheado**
en los dos repos (pedido del autor, 2026-07-30).
**Qué gana el wheel:** la **celda ancha** del grupo de luces (`cargo_wheel_lights_wide`, default 0 — 150×56,
sólo en los laterales, y **degrada sola** a 56×56 arriba y abajo porque la regla se escribió como un
**clamp**, no como un caso especial); el **click** como segunda forma de comitear (`cargo_wheel_click`,
default 1 — **CRG-31 intacta**: soltar comitea igual que siempre, y el click **no estrenó una sola API**
porque `input.IsButtonDown` ya se llamaba por frame ahí); el **modo que no cierra**
(`cargo_wheel_click_sticky`, default 0 — sólo sobre chips de luz, porque *togglear* es el único verbo
repetible del wheel, y si hubo click **soltar sólo cierra**); el **botón derecho en reversa**
(`toggleBack` opcional en el registro; `ToggleStat(addr, -1)`, y **ARC9 anticipó el paso negativo** — el
wrap está escrito en las dos direcciones); y la **linterna tapada** por el dispositivo del arma, que se
pinta con el tramado de quickslot y **rechaza el commit** con un destello, **sin falsear `on`** porque
*estado y disponibilidad son preguntas distintas*.
**LAS TRES REGLAS DE MÉTODO QUE DEJA EL ARCO, y las tres se pagaron:** (1) **la reversión es el único
instrumento que audita al instrumento** — siete checks nacieron sin distinguir y **ninguno lo destapó la
corrida en verde**; (2) **una inferencia no se escribe como una medición** — encontrado dos veces en
nuestros propios docs (el `UnequipDelay` del #46 y la *"supresión de render de ARC9"* de §13, cuyo mecanismo
real **sigue sin identificar**); (3) **un argumento sobre el INSTANTE puede ser falso sobre la SECUENCIA**,
que la trajo el autor corrigiendo la entry 58.
**Y el dato que cierra el arco: la sección AA no abrió un bloque nuevo.** Las siete anteriores terminaron
con una nota que abría el siguiente —X salió de W, Y de X, Z de Y, AA de Z—; ésta no. La cadena se detuvo
sola, y no por dejar de mirar: AA3 recorrió a propósito las cinco tandas y volvió sin nada.
El harness, además, **dejó de sacar su total de un `grep`**: ahora lo imprime él (`ALL GREEN - N checks`),
porque el banner de realm corría carreras con los `print` de Lua y el número saltaba ±1.)

Antes, **entries 52-53 `[APLICADO]`, confirmadas en juego con la planilla
V en 10/10 tras CINCO rondas**. **Sin commitear** (GIT-7).
Los **tres defectos que encontró la planilla son el mismo error con distinto disfraz — una API asumida
en vez de medida**: `FlashlightIsOn` supuesta legible en el cliente (no lo es: el server contesta `true`
y el cliente `false` con el haz visible en una pared), `UnequipDelay` supuesta ausente en todas las
variantes (**12 la declaran**, 0,25 s), y `EnableScreenClicker` supuesta idempotente (no lo es: llamarla
por frame re-inicializa el clicker y el cursor parpadea). **La tercera se cometió escribiendo el parche
que documenta las dos primeras.** CRG-24 manda verificar las APIs de terceros contra `dev/other/`, y
**el engine también es un tercero** — el que más fácil se olvida que lo es.
Cuatro de los cinco hallazgos salieron del **campo de notas de checks que PASARON**, no de un rojo.
El PARCHE 9 (**ARC9 le roba el cursor**: `gui.EnableScreenClicker(false)` incondicional en su `Deploy`,
`sh_deploy.lua:125`) ahora **lee el estado antes de escribirlo** y recupera el cursor ante cualquier
tercero. La ronda 3 dejó además una **corrección de doc que el código no compartía**: cuatro sedes
afirmaban que *ninguna variante declara `UnequipDelay`* y **las 12 aviators la declaran** (0,25) — la 1.ª
pasada leyó las GPNVG y **generalizó de una muestra**. La rama por dirección del código ya lo hacía bien;
el stub del harness, en cambio, **había heredado la afirmación falsa del doc**, y por eso no podía
contradecirlo. Las dos cosas salieron de **notas de checks que PASARON**, que ya es la cuarta vez en este
bloque. Antes, la ronda 2 dejó 7 de 9 en PASA y destapó **el defecto de diseño de la tanda**:
`ply:Flashlight` es server-only **en las dos direcciones** y la 1.ª pasada midió la escritura pero **asumió
la lectura**, así que el chip de linterna **nunca pintaba ON**. Medido con el haz visible en una pared:
server `true`, cliente `false`. Remedio: el server publica el estado real en `NW2Bool "cargo_torch"`
(`Lights.PublishTorch`, 4 Hz + inmediato en el receiver) y el chip lo lee — **replicación, no un segundo
mensaje: la enmienda a CRG-30 sigue en UN intent**. El espejo sigue al **engine** y no a nuestros commits,
porque la tecla libre y el `PostModify` de ARC9 también escriben. Lo acompañan dos parches más: `LightState`
**dejó de tragarse el error** —un `state()` que tiraba era idéntico a uno que decía OFF, y esa asimetría con
sus dos hermanas es lo que escondió el defecto una ronda entera— y **la lista se re-arma al cambiar de arma
con el wheel abierto** (V8; se rechazó bloquear las teclas 1-7: el wheel no es dueño del teclado).
**V7 REFUTÓ la premisa de la diferida (h)**: la linterna SÍ enciende durante la animación del NVG.
**Frontera nueva en §13**: con un arma ARC9 con dispositivo desplegada el haz **no se dibuja** —vuelve al
cambiar de arma, con el server en `true` todo el tiempo—. **El mecanismo que esta línea afirmaba
("supresión de render de ARC9") quedó CORREGIDO por el #51: el código no lo sostiene** y la causa real
sigue sin identificar; desde el #51 el chip además se pinta **tapado** y **rechaza el commit**. Harness **639** (eran 630), 9 nuevos y **4 reversiones en negativo**. La ronda 1 se había perdido
entera por un bind doble: la G era wheel **y** `impulse 100`, y como el wheel pollea la tecla, el toggle
daba **neto cero**. — roadmap
**#46, las luces en el wheel**: el **tercer grupo de chips** (verbo *togglear*) acciona la linterna, las
NVG que #47 posee y cada dispositivo toggleable del arma ARC9 en mano. La G deja de ser wheel y linterna a
la vez: la lista viaja en la tecla del wheel y la de linterna queda libre — `impulse 100` **jamás se
intercepta** (el defecto caro de TLS) y quedó **descartado como commit con medición**: ARC9 lo secuestra con
un dispositivo toggleable en mano. `Wheel.RegisterLightSource` (tercer registro vivo del patrón),
`LightsPushOut` (las luces SÍ comparten lado, empujadas hacia afuera, 24 px entre grupos), chip de tres
canales que no se pisan y **barras de emisores** desde el merge de `GetFinalAttTable` — datos, jamás parseo
del string. **CRG-64 acuñada** (*un estado asíncrono de un tercero pinta el TRÁNSITO*: el NVG tarda 1,325 s
en invertir `nvg_on` y el chip no miente) y **CRG-30 ENMENDADA** (deja de decir "cero mensajes de red
nuevos": el grupo suma **un único intent sin payload** para la linterna, que es server-only — CRG-6 en pie).
Dos archivos nuevos (`client/corpus_cargo_lights.lua`, `server/corpus_cargo_lights.lua`), tres íconos
propios versionados en `materials/corpus_cargo/wheel/` con gate `file.Exists`, mock asentado en
`mockups/cargo_wheel_lights_mock_v1_1.html` — sus bloques 06/07/08 (celda ancha, fades/rechazo visible,
baterías) quedaron **aprobados y DIFERIDOS**, anotados en el roadmap. Harness **630** (eran 588), **42
nuevos** y **8 reversiones verificadas en negativo** — una por capa: gate de ausencia, empuje, pick,
receiver del torch, tránsito CRG-64, commit ARC9, no-parseo, y el stub que no guarda.
Antes, **entries 50-51 `[APLICADO]`, confirmadas en juego con la planilla U en 6/6**
— roadmap **#47**,
las **61 gafas de Neosun como ítems de primera clase**: se recogen del mundo, pesan, se guardan, se comercian,
se dropean, sobreviven un relog, y al equiparlas se ven. Es la mitad **POSEER**; la mitad **ACCIONAR** (el
toggle desde el wheel) es el #46 y va después. Dos archivos nuevos, `shared/` + `server/corpus_cargo_nvg.lua`.
**El hueco central NO era del mod: era de Cargo** — no existía ninguna señal de "equipé algo", así que el
primer parche es de `inventory`. **CRG-62 acuñada**: *Cargo difunde que un slot cambió; la semántica vive en
el consumidor*. **Las puertas resultaron CINCO y no cuatro**: re-greppear mostró que `DropEquipped` no pasa
por `Unequip` y que el reconciliador de `WeaponDrop` vacía el slot al soltar el arma en la mano; la de
`DropEquipped` tiene consecuencia visible (dropear el casco con las gafas montadas dejaría al jugador viendo
a través de gafas que ya no tiene). `RegiveEquipped` difunde con **slot nil** = "se re-aplicó todo", que es la
puerta del respawn — **no se escribió un segundo re-give**. **CRG-63 acuñada**: *un ordinal de un tercero no
se persiste jamás* — la NW del mod guarda el ÍNDICE de su tabla, así que un parche que inserte una variante
haría que un ítem guardado amanezca **siendo otras gafas**; el def lleva el `ShortName` y el ordinal se
resuelve al equipar. Los **61 defs se DERIVAN** (CRG-41/42): a mano va **una sola tabla, las seis familias**
— y eso mata solo las dos trampas de nombre del mod (`shades_t` es la TÉRMICA y `shades_teal` la teal; `_hp`
se muestra "Ruby"). Los **íconos ya estaban hechos**: un PNG por variante, referenciado **por ruta** en
runtime — el mod es OFF-LIMITS y no se copió una línea ni un asset. El portero de mundo gana una cuarta forma
**por registro** (`Capture.RegisterWorldPickup`, patrón de `StatusPanel.RegisterBar`), no inline. Ruta C del
autor: **con casco al sub-slot óptica, sin casco a Head directo** — el filtro pasó a
`"category:helmets,optics"` y **CRG-8 quedó intacto**. El commit **escribe la NW y jamás llama a
`ArcticNVGs_SetPlayerGoggles`**, que dropea el par anterior y duplicaría. Harness **574** (eran 504), **70
nuevos**, y las **14 reversiones verificadas en negativo**. **Un check nació sin distinguir y lo destapó la
verificación en negativo, no la corrida verde**: probaba que el registro de recogidas existe, no que el
portero lo consulte. **2.ª pasada, con el reporte del autor en la mano:** el inventario aprendió a **acoplar
arrastrando** —ítem sobre ítem en el grid, e ítem sobre un slot equipado, donde la regla es *equipar (que
intercambia) → acoplar al sub-slot del ocupante → dejar que el server redacte el rechazo*— y a **extraer un
sub-slot con el host EN LA MOCHILA**, que era el hueco real: el server siempre lo permitió y la UI solo
armaba la lista para el slot equipado, así que un casco guardado retenía su óptica como rehén. Las dos reglas
son **funciones puras exportadas** (`ResolveSlotDrop`, `MountedEntries`) porque se rompen en silencio. Y el
**ícono pasó a autogenerarse del world model** (decisión del autor: el arte de spawnmenu del mod se lee mal
al lado de los renders del resto) — costo declarado: seis modelos para 61 variantes, así que **el color no se
ve en la celda y el NOMBRE es lo que distingue**. Harness **588**, **21 reversiones en negativo**.
**La 2.ª pasada no la disparó un check en rojo sino el USO** —la planilla midió lo que se propuso medir y lo
que faltaba apareció al jugar con lo que ya había dado por bueno—, que es la contracara de la lección de
B3/B4/B5. **Frontera declarada y medida por el propio U5** (§13): apagar `cargo_nvg_register` con gafas ya en
el inventario las deja **huérfanas de def** y se destruyen al dropearlas — aceptado; el kill-switch es para un
servidor que nunca montó el catálogo. Y la otra mitad de ese check vale más: con la convar en 0 el mod
recupera su comportamiento **entero**, o sea **COR-5 medido**, no declarado.
Antes, **entries 48-49 `[APLICADO]`, confirmadas en juego con
la planilla S en 5/5** — B5, **export/import LAN**, y con eso el plan de persistencia queda ejecutado salvo B6, que está diferido
a Cortex. Que un amigo traiga su personaje a la LAN, **con la puerta cerrada por default**. Archivo nuevo
`shared/corpus_cargo_lan.lua`. **CRG-61 acuñada**: *el
import está apagado por default y todo lo que llega del cliente se sanea server-side*. Es el **único** de los
`net.Receive` de servidor del módulo (24 desde el #46) que **invierte CRG-6** —recibe estado, no un intent—, y la convar en 0, el
gate de admin y la whitelist (**vacía = NADIE**) son lo que hace aceptable la inversión. Barato en formato y caro
en política: el record ya era autocontenido (CRG-56) y el re-acuñado ya existía (`Instances.Remint`, B4) — **no
se escribió un segundo re-uid**. Decisiones del autor previas al código: el import **REEMPLAZA** el record (con
respaldo a `import_backup_<sid>` antes de tocar nada, destino primero como CRG-58) y el **dinero viaja sólo con
el provider nativo en AMBOS lados**. **Una medición cambió el diseño:** el plan pedía chunking y un record
pesado pero realista mide **15.770 bytes** (60 uniques con anidado + 40 stacks), así que no hay chunking sino un
**tope** — 64 KiB en el cable, cortados antes de descomprimir, y 128 KiB de JSON al abrirlo. La firma de
compatibilidad **avisa y no gatea**, con las tres mitades declaradas por lo que cada una puede prometer. **La
planilla corrigió una declaración de la tanda:** el import deja las armas equipadas **en la mano en el acto**,
corriendo `Inventory.RegiveEquipped` —la MISMA rutina del hook de spawn, extraída y nombrada, no una segunda
ruta—, y la fila de §13 que declaraba la espera del respawn como frontera aceptable desapareció. Harness
**504** (eran 448), **56 nuevos**, y las **28 reversiones verificadas en negativo**. Antes, **entries 46-47
`[APLICADO]`, confirmadas en juego con la planilla R en 5/5** — B4, el savegame de GMod: `gm_save`/`gm_load`
conservan el estado de partida de Cargo que vive en entidades. Una crate vuelve **con su loot y sus
condiciones**, un trader con su **stock mermado y su wallet**, y un ítem tirado en el suelo sobrevive el ciclo.
**CRG-60 acuñada**: *el savegame guarda el MUNDO, no al jugador* — la mochila NO retrocede, contrapartida
declarada de CRG-43. La forma: **no hay `PreEntityCopy`** — el estado plano de la entidad YA viaja, así que
`Containers.Save` **renderiza siempre** y ese marcador ES el blob; al volver, `Containers.Attach` lo re-acuña con
uid nuevo. Como vive en la única puerta del primitivo, **Sidorovich lo hereda sin tocar su repo**. Cuatro rondas
dejaron una frontera **medida y aceptada**: la tabla Lua vuelve completa en las entidades scripteadas de Cargo y
**no vuelve en absoluto** en el SWEP real del drop de un arma (§13; instrumento `cargo_dev_worldwep`).
Antes, **entries 44-45 `[APLICADO]`, confirmadas en juego con la planilla Q en
5/5**: un solo serializador de dueño (`Instances.RenderOwner`/`HydrateOwner`), **`cont_<key>` como archivo de
dueño de primera clase** con un solo escritor —eso sacó a **CRG-58 de INTENCION** y arregló que una crate
persistente perdiera sus uniques al reiniciar—, **CRG-59 acuñada**, el wallet aparte en `trader_<key>` por
CRG-21, y la entidad sin referencias vivas encima (`_live` + API pública `Trade.StockOf`/`HasViewer`/
`ClearViewers`, `Containers.EntityOf`). El saneo rompió el NextBot de Sidorovich y se arregló en la misma tanda
(4.ª raíz). Convar dev `cargo_dev_persist_key`, vacía por default. Antes, **entry 43 `[APLICADO]`, confirmada en juego**: el framework estrenó
`Corpus.Data.List`/`Delete` y el **scope** de COR-19, y Cargo es su primer consumidor real —
`cargo_dev_purge_legacy` lista y purga los `inst_*` legacy de terceros con **dry-run por
default** (sin gate de admin todavía, CRG-45), y los dos archivos de catálogo `autogen_defs` e
`icon_overrides` declaran `scope = "config"`. **No mueve un solo archivo.** Los cinco checks de
la planilla **T** de corpus que tocan este repo están en PASA (T5, T6, T7 dry-run, T8 borrado
2 de 2, T9 inventario intacto); el ✗ que queda abierto, T4, es del framework. Harness 393/393.
Antes, **entries 41-42 `[APLICADO]`, confirmadas en juego —
planilla P, los cinco checks en PASA**). El blob de instancia **dejó de tener
archivo propio**: viaja embebido en el archivo de su dueño (`inv_<steamid64>`) bajo `instances`, y
`Instances._live` es la única verdad de runtime (CRG-56/57/58, §12 reescrita). La medición que lo
originó: **354 huérfanas sobre 370 archivos** en la data real, todas estado de mundo que nunca
debió persistirse — la causa era `Instances.Create` escribiendo sin saber de quién era la
instancia. Cierra de paso **roadmap #13** (murió el `file.Delete` crudo) y la deuda del
**CHANGELOG #10** (`cargo_persistence 0` ahora sí no escribe nada). Plan madre:
[`../../dev/PLAN_cargo_persistencia_gc.md`](../../dev/PLAN_cargo_persistencia_gc.md).
Antes: **entries 36-40 `[APLICADO]`, confirmadas en juego,
commiteadas y pusheadas** — pasada de compat/economía + saga VJ. La 36: MTs-255-12 a slot largo
(su `SWEP.Class` EFT es "Revolver" y la regla sidearm ganaba), **precios por familia**
(`Capture.WeaponValueFor`: `weapon_vj_*` a $200 plano), attachments ARC9 con `value = 100`, y
**Quick Loadouts apagado** ya no corre el strip incondicional en el primer spawn. Las 37-40, la
**saga de armas VJ**, en su forma final: el `PlayerCanPickupWeapon` de VJ corre **embebido en el
world gate** (un solo hook — la lección: el orden de `hook.Call` entre hooks distintos NO es de
inserción), las armas **NPC-only** (`MadeForNPCsOnly`) no son tomables por ninguna ruta / nunca
se acuñan / se purgan al spawn, la toma respeta `vj_npc_wep_ply_pickup 0`, el drop cae al piso
sin re-captura, y el **regalo de munición se neutraliza antes de existir** (copia propia de
`Primary` con `PickUpAmmoAmount = 0` en la instancia — sin fantasma en el history de DGL4).
Antes: **entry 35** (banco de sonidos de UI + persona del trader) y **34** (suministros HL2 +
mochilas genéricas + `Items.SetModel`), ambas `[APLICADO]` y confirmadas.)

---

## Qué existe hoy

- **Todo el arco de entries 1-17 `[APLICADO]` y confirmado en juego.**
  En orden: Block 1 (inventario: contrato de ítems, slots/sub-slots, peso,
  providers, contenedores), captura de armas del engine, imágenes de ítems
  (render a RT + editor), persistencia completa de equipadas, armas de mundo
  por WALK+USE, UI fullscreen 3 columnas/3 estados con gradas, holster +
  orden STALKER + SWEP "Hands", drop nativo + reconciliador universal,
  **munición: el cinturón ES el pool** (§16, espejo 4 Hz agnóstico de base)
  + su UX (reorder, unload, gate de ítems), **wheel menu** (§17) + **slot
  throwable** (§4) + columna apilada, Bloque D de UX (#30 spawnmenu, #28
  drop de slot, #24 retícula, **#29 paletas runtime + teñido DGL4**) y los
  frentes de la 2.ª pasada (#32 taxonomía de granadas + cajas por WALK+USE,
  #33 hub ARC9 completo, #34 compat con mods de movimiento).
- **Tabs de display con set FIJO de 8** (#23, entry 19): `All · Weapons ·
  Ammo · Gear · Mods · Meds · Food · Misc` — agrupación sobre las categorías
  internas, que quedan intactas para el grammar `"category:a,b"`. La fila se
  dibuja siempre entera y lo no mapeado cae en Misc (§7.1).
- **`Inventory.HasItem(ply, id)`** (entry 18): presencia sobre **ambas** clases
  de ítem. `CountItem`/`TakeItem` son de stacks — un `unique` (`{id, uid}`) no
  existe para ellos. Los módulos que solo preguntan "¿lleva uno?" (Coagulant
  con su torniquete) van por acá.
- **Comercio, slice 1** (entry 20, `Cargo_Trade` §2-§5/§8/§10): `def.value` +
  curva de condición + spread; **el trader ES un contenedor** (`Containers.Attach`)
  con capa de precio — el primitivo inventario-en-entidad de §2 no se construyó
  de nuevo; entidad demo `corpus_cargo_trader`; **estado Trade** del frame con
  basket, strips Buy/Sell y neto; **`Confirm` atómico** en server (valida
  existencia, dinero del jugador y wallet del trader, y recién ahí mueve). El
  basket del cliente es intent puro.
  **El peso NO bloquea una transacción** (entry 21): se puede comprar sobrecargado
  — la curva de peso lo cobra en velocidad; el límite sigue vigente para lo que se
  recoge del suelo (techo duro: **2× la capacidad**). Una línea del basket es un
  **agregado sobre todos los stacks** del ítem (entry 22); click = 25% del
  `max_stack`, **SHIFT+click = todo**, click derecho = cantidad exacta.
- **Trivia de armas: la pone el SWEP, no una tabla** (entry 23, roadmap #38).
  La captura lee `SWEP.Description` y el bloque `SWEP.Trivia` de
  `weapons.Get(class)` (ya heredados por la cadena `SWEP.Base`) → `def.trivia`
  + `def.trivia_rows`; el tooltip pinta **"Specs"** bajo los stats, sin exigir
  el arma en la mano. **Cualquier pack ARC9 que se monte después queda cubierto
  solo.** `corpus_cargo_weapon_trivia.lua` es la *excepción* (40 entradas):
  huecos del pack, herencias mentirosas (el M16A1 hereda de `arc9_eft_m4a1`) y
  las armas HL2, que no son SWEPs. **ARC9MW: las 87 clases** con peso y precio
  — los pesos los **declara el propio pack** en su `SWEP.Trivia` (54/87
  transcritos; el resto `real approx`).
- **Cada arma sabe a qué slot va** (entry 24, roadmap #39). Los tres slots de
  arma filtran por `category:weapons`, así que **cualquier** arma entraba en
  cualquiera (un RPG en Sidearm). El def autogen ahora setea `equip_slots`,
  **derivándolo del propio SWEP** (`SWEP.Class` por arma, `SubCategory` por
  pack, ambos resueltos por herencia): pistolas → Sidearm, largas →
  Primary/Secondary, melee → categoría `melee`, sin clasificar → libre.
  `SWEP.Slot` **no** es la señal (inconsistente entre packs). Lo ya equipado en
  un slot ilegal se reconcilia al spawn.
- **El arsenal real del autor, pesado y precificado** (entry 25, roadmap #40).
  Su volcado (`cargo_dev_dump_weapons`) tenía **369 SWEPs y 184 sin peso**:
  packs EFT que no están en `dev/other/` (SMG, escopetas, LMG, melee, gear,
  `makeshift`), el pack entero de **CS:GO** (`arc9_go`) y `arc9_wtt`. El volcado
  alcanzó para catalogarlos **sin tener el pack**. Hoy: **360 armas vivas, las
  360 con peso Y precio, cero huecos** (sin `value` no se comercian, y ese
  hueco era el mismo). El M60E4 pesa **10,5 kg**. El propio `cargo_dev_dump_weapons`
  ya **no grita lobo**: las plantillas de SWEP y las clases de `Capture.Ignore`
  salen `n/a`, no `MISSING`, y trae **columna de precio** + resumen de huecos
  reales.
- **Compat Quick Loadouts** (entry 32, confirmada en juego): takeover de su hook `PlayerLoadout`
  (`corpus_cargo_quickloadout.lua`, ÚLTIMO en el manifest) — los heals de Cargo corren siempre
  antes del strip, los cargadores se banquean a los blobs, el cinturón no se drena, y el loadout
  llega como **entrega de ítems** vía la captura (dedup anónimo, sin éter). Mid-round el arma en
  mano vuelve a la mano. Sin el mod montado el archivo es inerte; kill-switch
  `cargo_quickloadout_compat`. Referencia: `dev/Cargo_QuickLoadouts_Referencia.md`.
- **El holster anima el enfundado** (entry 33, confirmada en juego): reciclaje de Simple Holster —
  cascada `ACT_VM_HOLSTER→…` con **undraw** reverso para armas sin anim dedicada, exclusión de
  bases que ya animan (ARC9 &co.), candados `StartCommand` + `m_flNextAttack` (absoluto, fix del
  original), memoria `m_hLastWeapon` (Q alterna arma↔manos) y rate-limit 0,5 s. Spawn va
  `instant` (#4). Kill-switch `cargo_holster_anim`. Referencia:
  `dev/Cargo_SimpleHolster_Referencia.md`.
- **Hands pega como puños** (entry 26, confirmado en juego): puñetazo **3-4** dmg
  (era 37-47) y se acabó el tirón al volver a `idle` — el port medía la duración
  de la secuencia **equivocada** (`SequenceDuration()` sin argumento, leída
  después de pedir el cambio). LMB = mano izquierda, RMB = derecha. **En 3.ª
  persona no alterna, y no es un defecto:** el hold type `fist` tiene **una sola**
  actividad de ataque (`sh_anim.lua`: `ACT_MP_ATTACK_STAND_PRIMARYFIRE` →
  `index + 5`), no existe gesto de puño izquierdo en el set de anims de jugador —
  el `weapon_fists` de Valve tiene exactamente la misma limitación. Aceptado.
  **Y ya no arrastra nada del mod anterior** (entry 60): los cuatro eventos de sonido horneados en
  el `.mdl` van mudos contra `common/null.wav` —su foley es el único set que el port no trajo— y el
  ícono es **uno propio** (`materials/corpus_cargo/hands_icon.png`, el logo de Cargo) para las tres
  superficies: selección de arma vía `DrawWeaponSelection` (que es también el método que llama el
  HUD DGL4), kill feed y baldosa del spawnmenu vía `SWEP.IconOverride`.
- **Suministros HL2 + mochilas genéricas + `Items.SetModel`** (entry 34, confirmada
  en juego): el framework base trae Health Kit/Vial/Battery como ítems (valores y
  sonidos de pickup del ENGINE — no es medicina, Coagulant intacto) y dos mochilas
  para Back (+12/+24 kg) **sin modelo a propósito**: la cajita de cartón es el
  default honesto de todo def setting-agnostic, y un addon de contenido lo
  re-viste desde afuera con `Items.SetModel(id, model)` (orden-independiente,
  sobrevive re-registro, gana al `model` declarado). `corpus-stalker` lo consume
  para venda/botiquín (wick/spec45as) y las mochilas (hgn backpack-1/2, mapeo
  confirmado en juego). Adquisición dev por ítem: `cargo_dev_items [filtro]` +
  `cargo_dev_give_item <id|texto> [n]`.
- **Sonidos de UI + persona del trader** (entry 35, `[APLICADO]`): banco de GAMMA
  del framework (`corpus/sound/corpus/cargo/`, COR-17) cableado con gate
  `file.Exists` — mochila/estuche al abrir/cerrar por estado, drop, y selección
  por categoría en el clic del grid (sidearm=wpn, largas=wpnbig, por
  `equip_slots`). El trader demo: `Trade.SetDefaultPersona` (perfil cosmético de
  un addon de contenido) + callbacks `OnTradeOpened/Dealt/Closed` + idles de
  plaza rotados + voz por proximidad (saludo/espera 1 min/despedida). Sin
  persona: citizen mudo; sin banco: UI muda, consola limpia.
- **Llevar un personaje a otro servidor** (entry 48, §12.1):
  `cargo_export` escribe el record + cabecera (formato, origen, provider de
  dinero, firma) por `Corpus.Data`; `cargo_import` lo manda desde el cliente y
  **el server decide todo**. Convars: `cargo_import_enabled` (**0**),
  `cargo_import_admin` (1), `cargo_import_whitelist` (**vacía = nadie**),
  `cargo_import_cooldown` (30 s). En un **listen server** el archivo que escribe
  el server es el que lee el cliente, y por eso el ida y vuelta funciona sin
  mover nada a mano; en un dedicated hay que acercárselo al jugador.
- **NVG de Neosun como ítems** (entries 50-51, roadmap #47, **sin confirmar en
  juego**): las 61 variantes son ítems de Cargo **derivados** de la tabla del
  mod, se recogen del mundo por WALK+USE y se equipan por **dos rutas** (el
  sub-slot óptica del casco, o Head directo). El hueco que lo bloqueaba era de
  Cargo: **CRG-62**, la señal genérica de equipamiento por sus **cinco**
  puertas. **CRG-63**: el ordinal del tercero no se persiste — se persiste el
  `ShortName`. Kill-switch `cargo_nvg_register`; inerte sin el mod montado.
  Referencia: `dev/Cargo_NVG_Neosun_Referencia.md`. **Encenderlas es el #46 —
  escrito (entries 52-53), esperando la planilla V.**
- **El inventario acopla y desacopla arrastrando** (entry 50, 2.ª pasada): ítem
  sobre ítem en el grid monta en el sub-slot; ítem sobre un slot equipado
  **equipa (e intercambia) si puede, acopla al sub-slot del ocupante si no**, y
  si ninguna, el rechazo lo redacta el server. **Extraer no depende de que el
  host esté puesto**: la lista de lo montado es la misma para el menú del slot
  y para el del ítem en la mochila — antes un casco guardado retenía su óptica.
  Reglas puras y exportadas (`CARGO.UI.ResolveSlotDrop` / `FreeSubSlotFor` /
  `MountedEntries`); el grid genérico gana `onCellDrop` **con fall-through** al
  canvas, sin el cual el loot dejaría de transferir al soltar sobre una celda.
- **La configuración ARC9 viaja con el arma** (entries 61-64, roadmap #53,
  confirmado en juego): `blob.atts` es un árbol plano y nuestro —nodos de
  `cat`/`nth`/`att`/`mode`/`sub`, sólo strings y enteros, para que ninguna
  tabla de ARC9 se cuele y rompa `gm_save`—, cosechado **en las seis puertas**
  donde la entidad muere (`Inventory.StoreFromEntity`) y re-aplicado por la
  ruta del propio mod. La clave de un nodo es **(categoría, ordinal entre
  hermanos)** y **jamás** la posición: el *address* de ARC9 es el offset de un
  aplanado recursivo del build actual y **se mueve dentro de la misma
  partida** (CRG-63 llevado a su forma más fuerte). El árbol se aplica
  **antes** que el cargador, porque un cambio de `ClipSize` dispara `Unload` +
  `SetRequestReload`. **CRG-65**: lo que no entra al inventario **cae al
  piso**, nunca se destruye — ruta única `Inventory.GiveOrDrop`. **CRG-66**: lo
  acoplado pesa, por la misma recursión que ya pesaba los sub-slots, aunque su
  **alcance vigente son los sub-slots** y el árbol está **diferido al #55**. El
  precio cuenta los atts y el att **cobra pleno** (no tiene condición propia).
  `Inventory.SyncAttsSoon` mantiene el blob al día mientras el arma está en la
  mano, **un tick tarde a propósito**: los hooks disparan *dentro* del diff de
  `ReceiveWeapon`, antes de que el árbol nuevo esté instalado.
- **Harness offline: 771 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN, y **el total lo imprime el propio script** — no se
  grepea de stdout, donde el banner de realm corría carreras con los `print` de Lua);
  `cargo_selftest` 83 client / 76 server.
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Las entries 61-64 (roadmap #53) quedaron confirmadas el 2026-07-31 con la planilla AB en tres
  rondas** — 12 checks en PASA (AB1-AB7, AB9-AB13), **AB8 retirado por decisión** (el peso de los
  atts se difiere al #55: el modelo estaba mal, no el número) y **AB14 SIN CORRER**. Harness **771**
  (eran 700), **15 reversiones verificadas en negativo**; checker limpio, espejo regenerado.
  **Commiteado, sin push.**
  **La única deuda de verificación, y está declarada en la entry 64:** la ruta *"montar un att desde
  el menú C"* **no se ejerció con números en ninguna de las tres rondas**. AB13 respondió su pregunta
  por la **negativa** —botados los repuestos, `grid=0` y `hook=0` en las siete líneas y el menú dejó
  de ofrecerlos, o sea que el puente contesta lo que el grid tiene y no hay un tercer inventario—,
  pero esa misma acción destruyó la precondición de la resta, y con ella AB14. `SyncAttsSoon` se
  sostiene hoy en sus 6 checks de harness con el hook **realmente cableado** (por eso hizo falta
  exponer `_WireHooks`). Si un día el sync se rompe, **ésa es la entrada que nadie miró en juego**.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- **La entry 60 quedó confirmada el 2026-07-30 en dos rondas, sin planilla** (no hay superficie
  nueva que auditar: son dos síntomas reportados y verificables por observación directa). Ronda 1:
  consola limpia y spawnmenu OK, selector de DGL4 recortado. Ronda 2, tras el PARCHE 3: *«se ve bien
  en DGL4, kill icon en el hud de HL2 está perfecto, no hay nada más que tocar»*. **Commiteada y
  pusheada.** Sin cobertura de harness —`lua/weapons/` no lo carga el manifest—, así que lo único
  verificado offline fue la sintaxis y la aritmética de la caja.
- **Las entries 54-59 (roadmap #48 a #52) quedaron confirmadas los 2026-07-29 y 30 con las planillas
  W (10/10), X (4/4), Y (3/3), Z (3/3) y AA (3/3)** — **23 checks, cinco secciones, ninguna ronda perdida
  por un defecto de código**. Harness **700** (eran 639), **61 nuevos** y **19 reversiones verificadas en
  negativo**; checker limpio, espejo regenerado. **Commiteado y pusheado** el 2026-07-30.
  **La sección AA no abrió un bloque nuevo**, y las siete anteriores sí lo habían hecho — la cadena se
  detuvo sola. Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- Detalle viejo, para referencia: Lo que el
  harness prueba: que soltar sobre una linterna **tapada NO manda el intent**, y —la mitad que hace que eso
  distinga algo— que **destapada el MISMO gesto sobre el MISMO chip sí comitea**. Lo que **no** puede probar:
  que el destello se vea y se entienda. Planilla: **sección AA** — el espacio de una letra se agotó en la Z y
  sigue con dos, porque los IDs **no se reciclan** (FLU-07).
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- La entry 58 (roadmap #51) quedó confirmada con la **planilla Z en 3/3** el 2026-07-29, en UNA ronda:
  *«se ve tapado tanto en wide como normal»* y *«el tramado desaparece correctamente, sólo aparece con
  dispositivo»*. Detalle viejo: Lo que el harness
  prueba: que con un dispositivo `ToggleOnF` en mano el chip se declare **tapado**, que el estado **siga
  siendo el real** (no se falsea a OFF), y la **ausencia por partida doble** — sin arma, y con un ARC9 **sin**
  dispositivo. Lo que **no** puede probar: que el tramado se vea bien en las dos anatomías de celda.
  Planilla: **sección Z**. https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- La entry 57 (roadmap #50) quedó confirmada con la **planilla Y en 3/3** el 2026-07-29, en UNA ronda:
  *«está bien»*, *«sí, sólo afecta a ARC9 con dispositivo y a nada más»* y *«no comió nada»*. Detalle viejo: Lo que el
  harness prueba: la reversa sobre el **dispositivo ARC9 real** (un paso atrás desde `Off` da la vuelta al
  último modo, y paga el mismo `PostModify`), la **AUSENCIA** —una fuente sin `toggleBack` no responde y
  **sobre todo no cae hacia adelante**—, que el derecho sobre un sector no comitee ni cierre, y que un
  derecho **sin efecto no se coma el commit de soltar**. Lo que **no** puede probar: cómo se siente ciclar
  en los dos sentidos con el arma en la mano. Planilla: **sección Y** (registrada antes de usarse, FLU-30).
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- La entry 56 (roadmap #49) quedó confirmada con la **planilla X en 4/4** el 2026-07-29, en UNA ronda. Sus
  tres notas confirman las dos decisiones que el autor tomó antes de que se escribiera una línea:
  *«se siente como lo quería, es apretar a gusto el NVG y las linternas»*, *«sí sigue cerrando
  correctamente»* y *«sí funciona intuitivamente»*. **Consultar las dos bifurcaciones se pagó solo.**
  Detalle viejo, para referencia: Lo que el
  harness prueba: que N clicks sobre un chip de luz son N ciclos sin reabrir, que **soltar la tecla
  después sólo cierra**, que sobre un sector el click **sigue comiteando y cerrando** (el alcance), que
  **sin clicks soltar comitea igual que siempre** (CRG-31 literal), y la negativa con la convar en 0. Lo
  que **no** puede probar: si ciclar así **se siente** como el autor lo pidió. Planilla: **sección X**
  (registrada en `familias_excluidas` antes de usarse — FLU-30; no se recicla la W, es otra entrada del
  roadmap). Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- **Las entries 54-55 (roadmap #48) quedaron confirmadas el 2026-07-29 con la planilla W en 10/10**, en dos
  rondas: W1 (**la medición** que desbloqueó el paso 2 — el screen clicker deja leer el estado del botón
  por debajo) · W2 (la celda ancha en los dos laterales, el modo legible sin hoverear) · W3 (**ausencia**:
  la degradación sola a 56×56 con `top`/`bottom`, sin aviso) · W4 (el empuje compartiendo lado, **sin
  salirse de pantalla** — la advertencia del mock refutada en juego, **a 16:9**) · W5 (el tránsito del NVG
  en la anatomía nueva) · W6 y W10 (**las dos negativas**: con cada convar en 0, el wheel de antes) · W7
  (los tres canales del chip intactos) · W8 (el click comitea sobre las tres superficies) · W9 (**las dos
  trampas**: un solo commit por apertura, y abrir con el disparo apretado no dispara nada). Harness **676**
  (eran 639), **37 nuevos** y **9 reversiones verificadas en negativo**; checker limpio, espejo regenerado.
  **Commiteado y pusheado** el 2026-07-30. **La sonda temporal `cargo_probe_mouse.lua` se borra**: ya cumplió.
  **La única ronda que costó una vuelta fue la medición, y por el INSTRUMENTO** — la primera sonda contaba
  los clicks pero no dibujaba nada. Y el hallazgo de la tanda —un check que pasaba con la implementación
  buena **y con la mala**— salió de **revertir el arreglo**, no de la corrida verde.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- **Las entries 52-53 (roadmap #46) quedaron confirmadas el 2026-07-29 con la planilla V en 10/10**, tras
  **cinco rondas**: V1 (la linterna desde el chip, y el chip lo DICE) · V2 (**CRG-64 en juego** por las
  dos rutas de #47) · V3 (los dispositivos ARC9, con UN solo dispositivo) · V4 (el empuje de anclaje) ·
  V5 (**ausencia**, sin chips fantasma) · V6 (**negativa**: la superficie caliente intacta) · V7 (la
  linterna en pleno tránsito del NVG — **refutó la premisa de la diferida (h)**) · V8 (la lista se
  re-arma al cambiar de arma) · V9 (el regalo IR+NVG en el láser) · V10 (**el cursor sobrevive el
  `Deploy` de ARC9**). Harness **639** (eran 588), **51 nuevos** y **4 reversiones en negativo**; checker
  limpio, espejo regenerado. **Pusheado el 2026-07-30** junto con el arco #48-#52.
  **La ronda 1 se perdió entera por el entorno** —la G era wheel *y* `impulse 100`, y como el wheel
  pollea la tecla el toggle daba **neto cero**, indistinguible de "no pasó nada"— y las rondas 2-5
  encontraron **tres defectos y una afirmación falsa del doc**, todos por notas de checks que PASARON.
  Detalle de la 1.ª entrega, para referencia: V1 (la linterna desde el chip, con un arma ARC9 toggleable en mano — el caso donde
  `impulse 100` fallaba — y la tecla de linterna sigue viva) · V2 (el NVG por las DOS rutas de #47, y
  **durante el tránsito el chip no miente**, CRG-64; el apagado invierte sin ventana y eso es del mod) ·
  V3 (un arma con UN dispositivo —lo que el radial de ARC9 no cubre—, el nombre del modo en el hub y las
  barras cambiando con el modo; con DOS, dos chips independientes) · V4 (anclaje compartido → empuje
  hacia afuera con su línea única) · V5 (**ausencia**: sin dispositivos dos chips y ya; sin ARC9 ni NVG,
  un chip y consola limpia; `cargo_ui_tools 0` no rompe el empuje) · V6 (**negativa**: wheel de armas,
  quick, tools, holster e inventario intactos) · **V7-V9, candidatos del USO** (linterna durante el
  tránsito — su NOTA es la medición que la diferida (h) necesita —, cambio de arma con el wheel abierto,
  y el regalo IR+NVG confirmado en juego). Detalle en CHANGELOG entry 53. **Sin commitear** (GIT-7).
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- Antes: las entries 50-51 (roadmap #47) quedaron confirmadas el 2026-07-27 con la **planilla U en 6/6**,
  en dos pasadas: U1 (las gafas del suelo entran al grid y el mod **no** se las equipa por su cuenta) · U2
  (con casco, al sub-slot óptica; sacárselas **encendidas** apaga el efecto solo — es del propio mod y la
  tanda se negó a darlo por hecho) · U3 (sin casco, Head directo; ídem aviators) · U4 (cambio de mapa: siguen
  puestas y son **las mismas**) · U5 (**el kill-switch**, con su mitad de ausencia) · U6 (acoplar y extraer
  **arrastrando**, con la negativa del loot: «pasando al cargo crate sin dramas»). Harness **588** (eran
  504), **84 nuevos** y **21 reversiones verificadas en negativo**; checker limpio, espejo regenerado.
  **Sin commitear** (GIT-7).
  **La 2.ª pasada la disparó el USO, no un check en rojo** — la planilla midió lo que se propuso medir, y lo
  que faltaba (extraer con el host en la mochila, acoplar arrastrando, el ícono) apareció al jugar con lo que
  ya había dado por bueno.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- Antes, las entries 48-49 (B5) quedaron confirmadas el 2026-07-26 con la **planilla S en 5/5**, tras dos
  rondas: S1 (ida y vuelta sin pérdida — condiciones, el NVG en el sub-slot, el cargador, el cinturón, y lo
  agregado en el medio desaparece: REEMPLAZA) · S2 (una def desconocida se descarta con motivo y el resto entra) ·
  S3 y S4 (**los dos de RECHAZO**, cada uno con su línea de motivo en consola) · S5 (negativa: «B5 no ha roto
  nada»). **El hallazgo de la ronda 1 salió otra vez de un check que PASÓ** —el arma equipada que no se podía
  sacar, anotada al costado de un S1 correcto—, y lo arregló el PARCHE 6. De paso quedó una lección de método
  propia: dos rondas se fueron en distinguir «el re-give está roto» de «no hubo respawn», y lo desempató el
  experimento más barato posible, un `kill`. Harness **504**, checker limpio, espejo regenerado. **Sin
  commitear** (GIT-7).
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- Antes, las entries 46-47 (B4) quedaron confirmadas el 2026-07-26 con la **planilla R en 5/5**, tras
  cuatro rondas: R1 (la crate vuelve con su loot y el casco con el NVG en su sub-slot) · R2 (los dos
  traders con stock mermado y wallet — el de Sidorovich **sin tocar `corpus-stalker`**) · R3 (**CRG-60**:
  la mochila no retrocede) · R4 (el drop `corpus_cargo_item` vuelve con su blob) · R5 (Sidorovich
  entero). Harness **448**, checker limpio, espejo regenerado. **Sin commitear** (GIT-7).
  **Dos hallazgos salieron de notas de checks que no eran rojos, y el decisivo de una AUSENCIA** —una
  línea de log que nunca imprimió—, que es lo que motivó el instrumento `cargo_dev_worldwep`.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- Antes, las entries 44-45 (B3) quedaron confirmadas el 2026-07-26 con la **planilla Q en 5/5**,
  tras **seis rondas**: Q1 (la crate persistente conserva su unique, con ícono y footprint) · Q2 (el
  trader efímero re-siembra en un mapa nuevo, verifica D1) · Q3 (`gm_save`/`gm_load` deja crate y
  trader usables, con la cara del NextBot neutra y parpadeando) · Q4 (el slice 1 del comercio
  intacto) · Q5 (Sidorovich muere, deja ragdoll y respawnea). Harness **425 verdes**, checker limpio,
  espejo regenerado. **Commiteado y pusheado** en los tres repos.
  **Las rondas no fueron ruido: tres de los cinco defectos de la tanda los encontró el CAMPO DE
  NOTAS de checks marcados PASA**, no un check en rojo.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
- **Deuda de premisa para B4, anotada:** `gm_load` **no carga desde la consola** en la instalación
  del autor (el menú SAVES sí; descartados sus addons apagándolos todos). El PROMPT de B4 no asume
  `gm_load <nombre>` como ruta de verificación.
- Antes, las entries 41-42 (B1) quedaron confirmadas el 2026-07-25 con la **planilla P**
  —la primera sección de planilla de Cargo— **en PASA los cinco**: P1 arranque limpio · P2
  ningún archivo suelto en el ciclo de vida de un ítem · P3 el relog conserva equipo,
  condición y sub-slots · P4 `cargo_persistence 0` no escribe nada · P5 el mundo es efímero
  y no deja rastro. Harness offline: **373 checks verdes** en ambos realms. **Sin commitear
  todavía** (GIT-7). Antes, la saga VJ (37-40) y la pasada de compat/economía (36) habían
  quedado confirmadas el 2026-07-24, ya commiteadas y pusheadas.

## Frentes abiertos (anotados, NO arreglados)

- **Un arma ARC9 en el suelo rompe `gm_save`** (medido 2026-07-26, ronda 1 de la planilla R).
  El save del engine recorre la tabla Lua de cada entidad y las tablas de attachment de ARC9
  llevan `Material(...)` adentro: `Can't write unknown type IMaterial`, referencia cíclica y
  `CSave BLOCK SIZE OVERFLOW (>65k)` → el save no carga bien, y eso alcanza a **todo el mapa**,
  no solo a Cargo. **No es de esta tanda** —R1 y R2 guardaron y cargaron bien con crates y
  traders llenos de blobs— ni se arregla desde acá (ARC9 es COMPAT-RUNTIME, no se forkea). Lo que
  Cargo cuelga de una entidad son **184 bytes por unique**, medidos. Deuda de frontera declarada
  con su fila en `Cargo_Architecture.md` §13. Regla operativa mientras tanto: no dejar armas ARC9
  tiradas al guardar.

- **Slot del menú HL2 desalineado del slot Cargo** → **roadmap #36** (pedido
  17c: la RPD de EFT es Slot 4 de engine aunque esté equipada como primary).
- **Texturas negras en playermodels ZONA** (SEVA Woodland/Heavy/EXO-Heavy
  cuerpo; Cadpat/Freedom/Monolith chaleco) — lado addon `corpus_stalker`
  (territorio del autor; huelen a `.vmt/.vtf` faltantes en el copy).
- **Footsteps mudos al togglear `sv_bm_enabled`** → **roadmap #35** (lado
  mod: better movement v2; el remedio `sv_bm_slow_footsteps 0` NO funcionó —
  la sospecha del math.huge queda sin confirmar; investigar con el mod vivo).

## Remanentes / deuda conocida

- **Comercio:** faltan los slices **2** (dinero como entidad: botar / línea de
  solo-dinero en el basket) y **3** (jugador-trader con doble confirm, que
  incluye el traspaso P2P) — `Cargo_Trade` §12.bis. Los `value` son números de
  arranque, a calibrar en juego; el trader demo no persiste entre mapas; el
  cliente formatea el dinero con el shape del provider nativo USD.
- **Munición (§16.6/§16.7):** cargadores rellenables con toggle; binding de
  ammo-atts de EFT (`def.ammo.att` reservado en el schema); hueco
  `SWEP.ForceDefaultAmmo` declarado (escalación anotada: ledger de
  conservación); las entidades `arc9_ammo` reparten por su propio `Touch` y
  el espejo las absorbe al cinturón en vez del grid.
- **Íconos:** fuente ARC9 256² a 1080p (deuda aceptada, 2.ª pasada
  2026-07-12); el editor no afecta la cámara de armas ARC9; captura de armas
  de mundo sin bajar al spec de `Cargo_ItemImages_Arquitectura.md`.
- **Remitir el fix de brazos oscuros a Twilight** (ya confirmado, acción del
  autor).
- **El gate de admin del import es local y provisional** (§13): `ply:IsAdmin()`
  + convar `cargo_import_admin`, esperando la primitiva de permisos de
  **CRG-45**. Lo provisional es *cómo se pregunta quién es admin* — la convar
  en 0 por default y la whitelist son diseño y se quedan.
- **Apagar `cargo_nvg_register` con gafas ya en el inventario las deja
  huérfanas de def** y se destruyen al dropearlas (§13, medido en U5 y
  **aceptado**): el kill-switch es para un servidor que **nunca** montó el
  catálogo, no para apagarlo a mitad de partida.
- **El peso de los attachments está DIFERIDO al roadmap #55**, no pendiente de
  calibrar: `Instances.AttsWeight` está escrita, recurre y se prueba offline,
  pero `WeightOf` **no la llama**. El modelo que falta es *qué* attachment es
  carga y cuál **es** el arma — en una build EFT la mayoría de los slots llevan
  estructura. CRG-66 lo dice en la norma en vez de disimularlo. Y **antes** del
  #55 va el peso de la **munición cargada**: `blob.clip1` es un número pelado
  que `WeightOf` no mira, así que hoy cargar un arma **hace desaparecer peso
  del ledger** (aterriza en §16, el cinturón **es** el pool).
- Comandos dev sin gate admin; sin `addon.json`.

## Próximo paso

1. **Slice 2 del comercio** — el **plan de persistencia quedó cerrado** con B5: B6 (perfiles reales y GC
   jerárquico) está **diferido a Cortex**, con el diseño congelado en §6 del
   [`plan madre`](../../dev/PLAN_cargo_persistencia_gc.md), y no se ejecuta hasta que Cortex tenga código y
   `CLAUDE.md` — B1-B5 no le cerraron la puerta. Una decisión que B5 dejó ABIERTA para B6 a propósito: qué
   scope lleva un archivo de export, que no es ni `config` ni `save` (§12.1).
   (Desplazado por decisión del autor el 2026-07-25, D4 del plan
   madre): el dinero como entidad (`Cargo_Trade` §7 — botar efectivo desde el botón $,
   línea de solo-dinero en el basket). Después el slice 3 (jugador-trader con doble
   confirm). Semilla del chat nuevo:
   [`../../dev/HANDOFF_cargo_trade_slice2.md`](../../dev/HANDOFF_cargo_trade_slice2.md).
   La entry 27 se confirma de paso en esa pasada (checklist en el artifact).
2. **#56 — el peso de la munición cargada** (abierto el 2026-07-31, **va antes del #55**): las
   mismas 30 balas pesan 0,36 kg en el cinturón y **0 kg adentro del arma**, y un RPG cargado
   esconde **3 kg**. Semilla de investigación y diseño:
   [`../../dev/PROMPT_cargo_56_peso_municion.txt`](../../dev/PROMPT_cargo_56_peso_municion.txt).
   Lo que bloquea el diseño no es el peso sino **de dónde sale el tipo HL2 de un arma sin entidad
   viva**, y la decisión de **cadencia** que es del autor: hoy el ledger sólo se mueve cuando se
   mueve el cinturón, y el espejo es barato exactamente por eso.
3. **#54 — íconos que distingan dos armas de la misma clase** (abierto por la nota de AB9, un check
   que PASÓ): el ícono se autogenera del world model, así que dos AS VAL con builds distintas se ven
   idénticas en el grid. Y recién ahí el **#55** (qué attachments pesan), cuya pregunta difícil ya
   está anotada: **cómo autodetectar la clasificación** sobre un pack de terceros sin catalogar a
   mano cada att — que es justo el trabajo que CRG-41 existe para evitar.
4. Remitir el fix de brazos oscuros a Twilight (acción del autor).
5. **#41 — explosivos ARC9 como stack throwable** (bloque propio, pedido del
   autor): hoy las granadas de EFT/CS:GO/MW2019 se equipan en Primary. El
   clasificador ya las etiqueta `thrown`; falta el destino (son `unique` y el
   slot Throwable pide un **stack**). Enlaza con el #32.
6. Cuando se prioricen: **#42** (el lanzagranadas capturado no dispara — perdió
   su attachment de munición; sospecha: el puente ARC9 §10), **#36** (slot HL2
   alineado), **#35** (footsteps), **#44** (overlay de máscara
   de gas para cascos cerrados — los sonidos ya están en el banco, SIN DISEÑAR).
   (El **#37** —saga VJ completa— quedó resuelto y confirmado en las entries 37-40.)

---

*Rumbo / qué sigue → [`cargo_roadmap.txt`](cargo_roadmap.txt). Diseño →
[`Cargo_Architecture.md`](Cargo_Architecture.md), [`Cargo_ItemImages_Arquitectura.md`](Cargo_ItemImages_Arquitectura.md),
[`Cargo_Trade_Arquitectura.md`](Cargo_Trade_Arquitectura.md) y [`Workbench_Arquitectura.md`](Workbench_Arquitectura.md).
Metodología → [`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*
