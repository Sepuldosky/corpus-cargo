# Cargo — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-08-21 (**tanda doble CERRADA EN JUEGO EL MISMO DÍA: LOS FAVORITOS + LA
MARCA DE SOBRELLENADO** — roadmap **#43** y **#59** en **HECHO**, CHANGELOG **76** y **77** las dos
`[APLICADO 2026-08-21]`, planillas **AI 13/13** y **AJ 7/7** en **una sola ronda cada una**, sin un
rojo y sin una fila sin correr. Van juntas porque **tocan superficies DISJUNTAS** —la #43 son las
puertas del inventario, la #59 vive en **un solo archivo** de cliente que la #43 no toca— así que un
rojo de una no se puede confundir con un rojo de la otra, y cada una tiene su entry, su letra y su
bloque de sabotaje para poder cerrar sola.

**#43 — LOS FAVORITOS, y el entregable es una NORMA: `CRG-76`, sede §7.4.** *Un favorito es un flag
del **jugador** sobre un ítem, y ninguna puerta que saque algo del inventario puede ignorarlo.*
**El valor de la entrada no es que el candado exista: es que NO FALTE NINGUNA PUERTA.** El autor
nombró tres cosas (*«no lo puedes vender ni dropear»*, *«move all»*, *«no puedes mandarlo al loot
box»*); en el árbol eran **cinco sitios** más el clic del cliente — vender (commit + clic), «Move
all», transferencia individual, drop del grid y **drop de EQUIPO**. Una sola casa
(`Inventory.IsFavorite`) y un gate que **cuenta los sitios de llamada por archivo** (lección 89):
sabotear el helper pone todo rojo, pero **devolver UNA puerta a su código de antes dejaría la pasada
verde**, porque las otras cuatro siguen midiendo.
**⭐ LA DECISIÓN MÁS CARA, votada por el autor:** un favorito de algo que **apila** es **por ÍTEM** y
no por celda (`unique` → uid, `stackable` → id). `AddStack` **fusiona sola**, así que un flag por
celda queda **indefinido** en cuanto se levanta otro del piso — sin error y sin aviso — y arreglarlo
obliga a tocar el merge, que es la **#73**. Costo declarado antes del voto: no se pueden tener 3
vendajes favoritos y 2 no. **La munición está excluida** (voto suyo, con su motivo), y por eso
`BeltDrop` (#72) **no puede** ser una sexta puerta.
**LA UI SALIÓ TOGGLE ★ Y NO NOVENA TAB, con el ancho MEDIDO antes de preguntar:** las ocho tabs de
hoy suman **454 px** contra los **424** de la barra a 1280×720 — o sea que **`Misc` ya wrapea hoy**,
y el comentario del código que afirma lo contrario es **falso** en las dos resoluciones más chicas —
y **acortar el label a «Fav» no cambia el resultado en ninguna resolución**: lo que decide es la
**cantidad** de tabs. **La estrella se DIBUJA y no se tipea, y es una medición:** Roboto **no tiene
glifo** para U+2605 (verificado con `fontTools` sobre el `.ttf` de GMod), así que un
`draw.SimpleText` habría pintado el cuadrito de glifo faltante.

**#59 — LA MARCA DE SOBRELLENADO: el diseño ya estaba cerrado (CRG-68, §11.1) y esto es su bajada,
así que NO acuña nada.** El defecto era de **una línea** y estaba medido: el poll clampeaba a 100, y
un valor de 138 **no desbordaba la barra — la dejaba LLENA Y MUDA**. El jugador veía lo mismo con
100 que con 149. **Es peor que un desborde: un desborde se ve.** Entraron `softMax`/`hardMax`/
`overfillColor`, el exceso **tramado ENCIMA** (nunca alargando la barra, que mentiría sobre qué es
«lleno») recortado con `SetScissorRect` (**CRG-28**), y la cifra `+38` junto al label. **Degrada en
las dos direcciones y va MEDIDO, no afirmado.** Dos correcciones a lo que decía §11.1, las dos de
leer el árbol: `overfillColor` defaultea a `T.Colors.orange` porque **`warn` no existe** en la
paleta, y la aritmética **salió del `Paint` a tres funciones puras** — sin eso, lo único que separa
«llena y muda» de «llena y hablando» habría sido lo único que ningún check podía alcanzar.

**Harness 1107 → 1192** (62 FUENTES / 760 server / 370 cliente), selftest 100/107.
**`dev/sabotaje_cargo_43_59.py`: 31/31 en rojo**, con apertura y cierre en verde; re-corridos
`sabotaje_cargo_67/68/69/74_72` (12/12, 16/16, 19/19, 28/28) — y **dos anclas viejas habían quedado
en `x0`** y se actualizaron. **⚠ Un sabotaje salió VERDE la primera vez y el hallazgo fue del GATE:**
exigía la subcadena pelada `render.SetScissorRect`, que **la línea de cierre del par satisface
igual**, así que borrar la apertura no bajaba la cuenta de nada.

**LAS DOS PASADAS EN JUEGO, OK.** La **AI** se acredita **gesto por gesto y no por cobertura** —nueve
de trece con la evidencia en la nota—, y su fila estrella, el **merge**, cerró con la aritmética a la
vista: *«tengo 4 vendas en favorito, una en el suelo; al tomar tengo 5 … y no se puede botar ahora
porque las 5 están en favorito»*. **El falso rojo que se había predicho para el «Move all» no
ocurrió**, y se resolvió leyendo el código en vez de gastar una ronda: el gate vive **antes** del loop
que prende `blocked`, así que el aviso de capacidad que salió al lado del de favoritos era un bloqueo
real sobre ítems **no** favoritos. La **AJ** cerró **por su criterio y no por el que se le parece**:
la nota trajo **los dos números** (*«se ve el rayado en rojo y +38; también el +49»*), que era la
mitad que suele faltar. **CRG-68 deja de ser `INTENCION`** en `ids.yaml` y pasa a tener harness,
código, verificación en negativo y planilla — la métrica de intenciones baja de 72 a **71 de 252**.
**La tanda dejó abiertas DOS.** El **roadmap #76** salió de la **nota de un check que PASÓ** (AI5,
octava vez en el arco): dentro de la ventana de loot el grid del jugador **no ofrece ni marcar
favorito ni botar**, porque abre `Transfer.Menu` —sólo los verbos de transferencia— y no el menú del
grid del inventario. **No es un defecto de la #43**: ese menú nació con menos filas mucho antes, y lo
que la #43 hizo fue volverlo visible. **Su pregunta de alcance ya está contestada, y el autor la
cerró como REGLA de vocabulario y no como caso:** *«"drop" es siempre tirar al piso, al contenedor es
"mover"»*.

El **roadmap #77** es la fila de tabs, y **la resolución del autor la acota en vez de refutarla**:
juega a **1920×1080 nativo** (borderless, *Any/All*, 16:9), donde los 454 px de tabs entran en 644 con
**190 de sobra** — **nunca la vio**. El defecto es real sólo a 720p (por 30 px) y 768p (**por uno**),
o sea de las resoluciones chicas, y el destino es Workshop. **Prioridad baja: el wrap ya existe como
red y la barra crece, así que la segunda fila SE VE** — es prolijidad, no función. **⚠ La medición se
re-auditó y el hallazgo fue del método:** el `454` estaba bien pero **su instrumento no se había
guardado**, y rehacerlo dio **412** por omitir los siete gaps de 6 px — con 412 el defecto **se
refutaba solo**. Queda `dev/medir_fila_de_tabs.py`.)

Contexto previo: 2026-08-20 (**tanda doble: EL MENÚ TOMA EL TEMA + EL CINTURÓN PUEDE
BOTAR** — roadmap **#74** y **#72**, CHANGELOG **73** y **74**, las dos `[PENDIENTE]`. Van juntas
porque **tocan superficies DISJUNTAS** —la #74 es pintado de cliente, la #72 es semántica de
munición en server— así que un rojo de una no se puede confundir con un rojo de la otra, y cada una
tiene su entry, su letra de planilla y su bloque de sabotaje para poder cerrar sola.
**#74 — EL MENÚ CONTEXTUAL TOMA EL TEMA, y el entregable es una NORMA:** era el **único** pedazo de
UI del módulo que no pasaba por el theme, y salía con el gris de fábrica de Derma encima de una
interfaz que no es gris (*«tambien el menu contextual tiene color derma, deberia tomar el color del
hud de DGL4 que tiene cargo»*). **El teñido de DGL4 sale gratis y eso es literalmente lo pedido:**
`T.Colors` **muta en sitio** (CRG-29) y con DGL4 montado la paleta entera deriva de su acento, así
que un menú que lee `T.Colors` toma el color del HUD **sin una línea de compat** y se re-tiñe en
vivo. Ir a buscar el acento al mod habría sido una **segunda casa**. Son **ocho** los sitios que
abren un menú (6 en `ui.lua`, 1 en `trade.lua`, 1 en `transfer.lua`) y **pintarlos a mano deja el
problema intacto**: el noveno vuelve a salir gris, que es cómo nació la entrada. Va **una puerta
única** —`CARGO.Theme.Menu()`— acuñada como **CRG-75**, sede **§15.7**, al lado de CRG-74.
**LA TRAMPA, y la premisa con la que se entró era FALSA:** un `DMenuOption` **se pinta a sí mismo**,
y `DMenu:AddSubMenu` construye el hijo con un `DermaMenu(true, self)` **pelado** — un menú **aparte**
que el helper nunca vio, así que los **cuatro** submenús quedarían grises y **eso no se ve en la
primera pasada: hay que abrir uno**. El prompt de la tanda decía que *«el hijo se crea al abrirse»*;
**se crea al DECLARARSE**, leído en `vgui/dmenuoption.lua` en disco. La conclusión —pintar la
**descendencia** y no la instancia— sobrevivió, pero **por otro mecanismo**: con la premisa falsa el
helper se habría escrito enganchando el `Open()` del hijo, más caro y apuntado al lugar equivocado.
*Leer la fuente costó diez segundos y cambió el diseño.* El helper envuelve
`AddOption`/`AddSubMenu`/`AddSpacer` y **re-envuelve recursivamente** al hijo. **Votos del autor:**
los **ocho** menús (no sólo los de ítems) y **hover `cellHover` + borde `border`**, lo mismo que una
celda del grid — el acento pleno en una lista de ocho opciones queda chillón. **Único detalle que se
EMPUJA en vez de leerse, y se dice porque parece un olvido de CRG-29:** `DLabel` guarda el
foreground como **snapshot**, así que el color de texto se re-empuja **cada frame** o un re-teñido en
vivo no llegaría nunca a un menú abierto. **NO se tocó el CONTENIDO** de ningún menú: es pintura, y
un rojo de contenido se leería como un rojo de tema.
**#72 — EL CINTURÓN PUEDE BOTAR AL MUNDO:** *«Falta drop desde el belt para expulsarlo del
inventario a la municion»*. Hasta hoy la munición del cinturón sólo podía **volver al grid** y recién
desde ahí botarse, o sea **dos gestos**, y el segundo dependía de que **hubiera lugar de peso en el
grid** — justo lo que no hay cuando quieres tirar algo. `CARGO.Inventory.BeltDrop(ply, slotN, count)`
+ intent `belt_drop`, con la forma de la **rama de stack de `DropEquipped`** (#28) y no una ruta
nueva. **Sin `cid`:** un slot de cinturón se nombra por su **número**, `rec.belt[n]` ya *es* la
entrada. **EL DEFECTO QUE LA ENTRADA EXISTE PARA EVITAR NO SE VE EN PANTALLA: SE VE AL DISPARAR** —
el cinturón **ES** el pool del engine (§16.3, CRG-15), así que un drop que se saltee el
`AmmoPool.Push` deja al jugador **habiendo tirado la caja y teniendo las balas todavía cargadas**;
el ítem cae al piso, el inventario queda impecable, y aparece en la próxima recarga. Es la **cuarta
puerta** que saca algo del cinturón y **la tabla de las cuatro quedó escrita en §16.3** justo porque
la que falte no da error. **No acuña CRG:** es aplicación de CRG-15. **Votos del autor:** el menú
espeja el **vocabulario del grid palabra por palabra** (`Drop` / `Drop all (xN)`, además del
`Return to inventory` que ya estaba) porque dos vocabularios para el mismo verbo es lo que la #69
acaba de cerrar; y **el arrastre NO bota** — el drag del cinturón ya significa devolver/reordenar.
**VERIFICACIÓN:** `glua_check` **48/48**, harness **1038 → 1089 verdes** (51 nuevos: **20** de
conducta en el realm server, **21** en el cliente y **10** en el gate de FUENTES, **tres de ellos POR
CUENTA y por archivo separado** — con el total, mudar un menú de archivo lo tapa; reparto por
entrada: **22 la #74**, **28 la #72** y **1 precondición compartida**), selftest **100 server / 107 client**
sin moverse, y **20 sabotajes en rojo, 20 de 20** (`dev/sabotaje_cargo_74_72.py`), etiquetados por
entrada, con control de apertura y de cierre en verde. Se re-corrieron `sabotaje_cargo_67/68/69`
(**12/12, 16/16, 19/19**) porque la tanda tocó `ui/trade/transfer`: un ancla rota **no revienta**,
imprime `ANCLA x0` y desarma una verificación vieja en silencio.
**LO QUE MÁS ENSEÑÓ ESTA TANDA, y las dos veces habló el instrumento y no la lectura:** (a) el
control de rango de slot, escrito sobre slots **vacíos**, pasaba con el gate puesto **y** con el
gate sacado —un slot fuera de rango siempre está vacío, así que el `entry == nil` contestaba primero
y el guardia **nunca se ejercía**; *un guardia cuya única prueba no puede alcanzarlo es un guardia
que nadie midió*, y se reescribió plantando una entrada en `belt[9]`, el único estado donde el gate
es alcanzable (y es real: el cliente manda el slot en un `UInt(4)`, 0 a 15 sobre un cinturón de 6);
(b) el propio **stub de vgui del harness** cayó en la autovivificación que su comentario de al lado
advertía —`self._options or {}` nunca corre porque el `__index` devuelve una **función**, que es
truthy— y hubo que leerlo con `rawget`, el mismo cuidado que los checks usan para no barrer las
doscientas panels del frame.
**PASADA EN JUEGO ✓ 2026-08-20 — LAS DOS OK, y los dos CHANGELOG quedaron `[APLICADO]`.**
**#74:** *«Si esta bien el menu contextual ya revise todas y funciona como corresponde»* — declarada
como **barrido** y no fila por fila, y se dice: lo que la declaración cubre sin ambigüedad es lo
único que el harness no podía cerrar solo, que **ningún menú quedara afuera de la norma** (ocho
sitios y cuatro submenús). **CRG-75 acreditada en juego.**
**#72:** *«El cinturon tambien bota, bota de 1 y todos del stack que estas botando; Traer al
inventario despues de botar esta bien, recargando la municion despues de botar otro stack esta bien.
No he visto ningun problema»*. **Cuatro filas cerraron POR GESTO y el autor las nombró una por
una** — las dos cantidades distintas (AG3/AG5), el control negativo de `BeltClear` (AG7) y
⭐ **AG4, la que justifica la entrada**: es la **única fila del bloque que no se mira en pantalla**,
porque el defecto deja el inventario impecable y las balas en la reserva. Que haya **recargado
después de botar** y el arma tomara de la reserva correcta es lo que convierte el `AmmoPool.Push` de
una línea escrita en una línea **medida**. Las otras seis se acreditan por **cobertura** (*«no he
visto ningún problema»*) y no por un gesto anotado — *un verde por cobertura y uno por gesto no son
lo mismo*.
**LO QUE ABRIÓ LA PASADA Y YA ESTÁ ESCRITO — la #75, CHANGELOG 75 `[PENDIENTE]`:** el cuadro de
**«how much»** (el `amount…` del trade y del loot) era la **última superficie Derma de fábrica del
módulo**, y sólo se hizo visible cuando los menús dejaron de ser grises — *arreglar lo que se veía
dejó a la vista lo que quedaba debajo*. `CARGO.Theme.Prompt()`, los **dos** sitios lo llaman, y
**NO acuña un CRG nuevo: AMPLIA CRG-75**, porque es la misma regla con otra puerta y dos IDs para
«la UI del módulo pasa por el theme» sería la duplicación que la norma existe para evitar.
**Envuelve `Derma_StringRequest` en vez de re-implementarlo:** la función del engine posee el
*layout*, y reescribirlo para cambiar seis colores sería un diff mucho mayor con un modo de falla
mucho peor. ⭐ **El renglón que no se ve como un color equivocado sino como «no hay texto»:** el
texto de un `DTextEntry` lo dibuja el **SKIN** y no el engine, así que un `Paint` propio que se
olvide de `DrawTextEntryText` deja **una caja donde se puede tipear y no se ve nada** — leído en la
fuente **antes** de escribir, y con sabotaje propio. Harness **1089 → 1107**, y la tanda entera queda
en **28/28 sabotajes en rojo**. **PASADA EN JUEGO ✓ 2026-08-20 — OK** (*«Si los colores del menu contextual y de los StringRequest estan perfectos, nada mas que probar, del tiempo que he jugado, varias horas, no he detectado errores»*): las filas de **color** por declaración directa, y las **dos de conducta** —que el campo muestre lo tipeado y que aceptar transfiera— por **uso extendido**, que para la primera es *mejor* evidencia que un gesto único, porque si faltara el dibujo del texto el número llegaría igual al server y lo único visible sería la caja vacía. CHANGELOG **75 `[APLICADO]`**, y **CRG-75 acreditada en juego en sus DOS puertas**.)

**LAS TRES ENTRADAS DE ESA TANDA ESTÁN CERRADAS EN JUEGO** (#74, #72 y #75). *(Al escribirse, esa línea seguía con «el módulo no tiene deuda de verificación abierta»; hoy la deuda son las dos planillas de arriba, AI y AJ.)*)

Contexto previo: **LA GRAMÁTICA DEL MOUSE** — roadmap **#69**, CRG-74,
sede §15.6. **`M1` selecciona · `M3` deselecciona · `M2` es el menú contextual**, y es una **norma
del módulo entero**, no un feature de una pantalla: son las palabras del autor al cerrar la planilla
AD del #68 — *«Al final como norma es que M1 selecciona, M3 deselecciona y M2 es el boton
contextual»*. Las otras tres frases de esa nota —los cuartos por stack, el `SHIFT+M1`, el
`ALT+SHIFT+M1` y los tres niveles para deseleccionar— son **casos** de la norma. **Por qué existe la
entrada:** dos pantallas del mismo módulo tenían **dos gramáticas para el mismo gesto** —en el trade
un clic cargaba un cuarto desde el #67, en el loot mandaba el stack entero— y **nadie lo decidió**:
se escribieron en tandas distintas y cada una eligió sola. **Los tres niveles**, iguales para los dos
botones que mueven cantidad: pelado **un cuarto del TECHO**, `SHIFT` **la celda que apretaste**,
`ALT+SHIFT` **todo lo de ese ítem de ese lado** (un único es siempre 1; una def sin `max_stack` cae
al agregado y da 1). **El cuarto es del techo y no de la celda** a propósito: tiene que ser el mismo
bocado con una celda llena que con una de siete balas. **`ALT` y nunca `CTRL`, y el motivo es del
JUEGO:** CTRL agacha, así que sostenerlo deja al jugador en cuclillas al cerrarse el menú. **UNA sola
función lo resuelve** —`Grid.ClickAmount`, el **único lugar del módulo que lee una tecla
modificadora**— y las cuatro superficies llegan por dos adaptadores que sólo eligen **sobre qué
lista** se cuenta el agregado; una segunda copia se desincroniza **sin un solo error**. Y **`M1` y
`M3` preguntan a la MISMA función**: seleccionar y deseleccionar no pueden derivar. **La mitad de
`M3` no existía en ninguna pantalla:** hasta hoy «deseleccionar» era un solo gesto sin gradación —el
clic en la fila del basket, que borraba la línea entera—; `Trade.BasketTake` es lo nuevo, y una línea
que llega a cero **se borra** en vez de quedar como un `x0` (el basket es intent). **El botón del
medio llega a la celda por herencia de Derma, leído en la FUENTE del motor y no de memoria**
(`DButton` → `DLabel:OnMouseReleased` → `DoMiddleClick`), y el grid lo cablea **una vez**, en la
celda. ⚠ **El despacho es en `OnMouseReleased`, NO en pressed**: pisar cualquiera de los dos
handlers sin re-emitirlo apaga `M3` sin un solo error. **Las DOS excepciones son votos del autor y
van escritas, no disimuladas:** (1) **`M3` no hace nada en el LOOT** —rechazó la transferencia
inversa por contraintuitiva, *«jamás había visto un sistema así de inventario en juego»*—, así que la
norma se lee **«M3 deselecciona donde hay algo seleccionado»** y el camino de vuelta sigue siendo
`M1` sobre la otra columna; (2) **en la FILA del basket `M1` quita**, porque una fila es una entrada
de **lista** y no una celda — lo que gana son las cantidades, y ahí `ALT+SHIFT` saca **lo mismo** que
`SHIFT` porque una línea **ya es** el agregado de su ref: el mismo número **por construcción**, dicho
para que ningún check afirme distinguir dos cantidades que son una. **Lo que NO cambia:**
`Transfer.Menu` (el «enviar cantidad») queda **exactamente como está** —el autor lo declaró bien y su
clamp es una decisión del cliente, no una falla—, `M2` no cambia de significado, y **el `cid` de
CRG-73 no se toca**: lo que estos gestos mandan es una **cantidad**, no una identidad, así que el
basket y la transferencia de contenedores **siguen agregando** y sus cuatro controles negativos
quedaron verdes **sin ser tocados**. **EL COSTO, dicho antes y no después:** en el loot un `M1`
pelado pasa a mandar un cuarto, o sea que un stack completo son cuatro clics — o un `SHIFT+M1`. Es lo
pedido, pero es la pantalla que más se usa. **Verificación:** harness **985 → 1038 verdes** (39
checks de conducta + 14 de FUENTES, **seis de ellos POR CUENTA**), selftest **100 server / 107
client** sin moverse, `glua_check` 48/48, y **19 sabotajes en rojo, 19 de 19** con control de
apertura y cierre en verde (`dev/sabotaje_cargo_69.py`). **Dos cosas del método que esta tanda
pagó:** (a) los tres niveles sólo discriminan sobre una celda cuyo `count` **no** sea el `max_stack`
—con la celda al tope, «un cuarto del techo» y «lo que dice la celda» dan 30 y 120 pero el
`ALT+SHIFT` de un stack solo da 120 también— así que el bloque mide sobre una x80 con agregado 200,
y las dos listas del loot son **distintas** (caja 200, jugador 120) para que el número delate un
adaptador equivocado; (b) **mudar la gradación de `corpus_cargo_trade.lua` a `corpus_cargo_grid.lua`
dejó el sabotaje 10 de `sabotaje_cargo_67.py` apuntando a NADA**, y ese script **no revienta**:
imprime `ANCLA x0` y sale 1, o sea que desarma una verificación en negativo vieja **en silencio**. Se
re-apuntó y se re-corrió (**12/12**); el del #68 sigue en **16/16**. **PASADA EN JUEGO ✓ 2026-08-20 — planilla AE CERRADA 14/14, 0 fallas, en dos rondas** (la 1.ª quedó
en 4 por cansancio y no por un defecto). **AE2 cerró la única incógnita de la norma:** el botón del
medio **LLEGA** a un `DButton` que además es `Droppable` —control positivo de M1 más `[AE2] M3 LLEGO`
cuatro veces, o sea repetible—, así que lo que era **indicio** sobre la capa de drag-and-drop quedó
**medido en el motor**. Los repartos que trajo el autor miden, de yapa, lo que el bloque no se
propuso: **AE4** caja 120+107, clic pelado sobre la de 107 deja **77** y trae **30** (un cuarto del
TECHO, no de la celda); **AE5** `SHIFT` sobre la de 77 la trae entera y del lado del jugador queda
**107** — los 30 previos y las 77 **se fundieron**, que es `AddStack` bajo el techo; **AE8** manda 30
y queda caja **120·120·17** / inventario **120·90**, que **suman 467**, o sea conservación intacta y
el 17 es el resto de re-empacar 257 bajo un techo de 120, no munición mal partida; **AE7** ALT solo
vuelve al cuarto (control negativo de la tecla suelta); **AE9** los tres niveles andan en las **dos
direcciones y los dos lados del trato**, y M3 los replica; **AE11** la fila del carrito saca 30 con
un clic y todo con `SHIFT`, y `ALT+SHIFT` hace **lo mismo** que `SHIFT` — el comportamiento
**declarado por construcción**, ahora visto en juego. **OBSERVADO Y ACEPTADO:** arrastrar sigue
moviendo el **stack entero** en las dos direcciones (el autor lo llamó *«el símil de SHIFT+M1»*) —
es por diseño (§15.6): el arrastre no es un clic. **QUÉ SE MIDIÓ CON GESTO Y QUÉ POR COBERTURA, y se
dice:** las filas con reparto anotado (AE4/AE5/AE7/AE8/AE9/AE11) corrieron por su gesto; **AE10,
AE12, AE13 y AE14 se acreditan por el uso extendido del trader y por las filas que las cubren**, no
por una corrida aislada — declarado por el autor (*«no llené todas porque hay otras que me lo
confirman»*). *Un verde por cobertura y uno por gesto no son lo mismo.* CHANGELOG **72
`[APLICADO]`**.
Contexto previo: **el ref de un stack nombra LA CELDA que apretaste** —
`cid` estable por entrada, roadmap **#68**, CRG-73, sede §7.3. El autor lo encontró en juego: *«al
meter al belt, ese que tiene 107 se mete otro de 120, incluso bote toda mi municion de pistola del
grid y salieron 6 items de pistola en vez de los 4 que tengo en el grid»*, y precisó el pedido —*«que
en vez de mandar 120 de otro stack, se mande justo ese stack de 107 al belt»*. **NO SE ESTABAN
CREANDO BALAS, y decirlo primero es lo que ahorró la ronda:** la conservación se cumplía y lo que no
se cumplía era **cuál** entrada se movía — `FindEntry` resolvía `{ id, condition }` contra la
**primera** que emparejaba y la celda no viajaba en el ref. **Los dos síntomas del reporte son UN
defecto:** el cinturón se llevaba la primera (120), y `DropEntry` clampeaba al `count` de la primera,
así que botar la de 107 sacaba 107 de una de 120 y dejaba un resto de 13 — vaciar el grid apretando
siempre la celda más chica tomaba **siete clics y dejaba siete ítems** (107, 13, 107, 13, 107, 13,
107). Y el **107 no era el bug**: es una descarga que volvió del pool. Votos del autor, tomados antes
de escribir: **campo estable** y no el `ord` del #67 (el botón **Sort** reescribe todos los `ord` de
una, así que un intent que nombrara un `ord` lo podía re-apuntar un re-orden aterrizando entre el
clic y el paquete — y el `cid` **paga además la mitad del #70**), y **la celda perdida falla y
AVISA** en vez de caer a la primera, porque *ese fallback es el defecto*. **Se descartó el blob por
stack**, que fue la propuesta del autor: un blob guarda **historia** y dos stacks de 9×19 no tienen
ninguna que los distinga — sería pagar con un objeto de persistencia lo que resuelve un campo. Se
acuña en el **mismo funnel** del `ord` (`StampEntries`, los dos funnels del record) y **el contador
vive en el record y se persiste**, porque derivarlo de lo vivo **recicla** el número de una entrada
que se fue, que es el único modo en que un intent viejo puede disparar sobre una celda que nadie
apretó. **El alcance es POR CAMINO:** los cinco que **mueven** una celda la nombran (equip, use,
drop, belt, sub-slot); el basket del trade y la transferencia de contenedores **siguen agregando**,
porque ahí el agregado es lo que mantiene alcanzable al stack gemelo (informe en juego 2026-07-14) —
con **cuatro controles negativos** que lo miden en vez de suponerlo, y los dos del server
verificados en negativo. **Un ref SIN el campo sigue cayendo a la primera** (savegames, import LAN,
`CleanStack`): un ref que no puede nombrar una celda no puede quedar inalcanzable. **Se llama `cid` y
no `sid`** porque `sid` significa SteamID en las 40 apariciones del módulo, cuatro en `GetRecord`.
**El frente que el pedido no nombraba, y salió del censo con denominador:** `QuickTarget` **elegía**
el frasco más gastado y después le pasaba a `UseEntry` un ref que resolvía al **primero** — la
elección se calculaba y se tiraba. Son **dos** los sitios del módulo que arman un ref de stack
(`Grid.RefOf` y ése), no uno. **EL HALLAZGO DE MÉTODO, y es el que más paga:** el sabotaje 14 —*«el
Sort pisa el `cid`»*— salió **VERDE**, y no por el código: en un grid **recién nacido** los `cid`
coinciden con sus posiciones, así que pisarlos con la posición reescribe **los mismos números**. *El
check estaba verde por una coincidencia del sujeto y no por el mecanismo.* Se arregló dándole
**churn** al grid del check y una **precondición** que lo delata. Y dos gates de fuente nuevos no
preguntan si un patrón existe sino **cuántas veces** (5 sitios de `FindCell`, 3 de `FindEntry`):
un gate de existencia deja pasar la reversión de un **sitio de llamada**, que es la lección 89.
Harness **945 → 985 verdes**, selftest **100 server / 107 client** (sin moverse), `glua_check`
48/48, y **16 sabotajes en rojo, 16 de 16**, con control de apertura y cierre en verde
(`dev/sabotaje_cargo_68.py`). El instrumento del #67 siguió a su código —el rename
`StampOrder` → `StampEntries` le dejaba dos anclas apuntando a nada, o sea una verificación en
negativo desarmada en silencio— y se **re-corrió: 12/12**. **PASADA EN JUEGO ✓ 2026-08-19**: los
**dos síntomas del reporte cerrados** —el cinturón se lleva la celda que arrastrás (84 balas) y
**siete stacks de pistola dan SIETE ítems al botar**, que es exactamente lo que el defecto impedía,
porque el viejo dejaba restos y salían más ítems que celdas—, con `cargo_selftest` **100 OK** y
`cargo_selftest_cl` **107 OK**, 0 fallas los dos y **clavados** con lo que el harness offline había
predicho. **Las seis filas que quedaron SIN CORRER se cerraron el mismo día** con la planilla **AD**
(`dev/checks/cargo-celda-r1.html`): **12 PASA · 1 RETIRADO**, con los cinco caminos verdes uno por
uno y la celda perdida contestando las **dos** mitades del voto (no movió nada **y** lo dijo en el
chat). **AD11 se retira por premisa mal escrita y no es un rojo:** pedía *«pedir 200 sobre una celda
de x120»*, y el server sí derrama pero **la UI nunca ofreció ese gesto** — el menú anuncia
`1 - 120` y clampea al cell. El criterio estaba escrito desde la capacidad del **server** y
redactado como un gesto de **interfaz**, así que sólo podía dar rojo. **El mecanismo que esa fila
protegía SÍ quedó verificado por su otra mitad:** `Move all` mueve las 467 de las cuatro celdas con
un solo ref, que es exactamente lo que no pasaría si el campo nuevo se hubiera filtrado al
contenedor. Y el autor verificó de paso algo que **no es de este bloque**:
sacar munición del cinturón **rellena** un stack del grid hasta el techo (100+80 → 120+60), que es
`AddStack` mergeando bajo `max_stack` desde el Block 1 — lo cerró él con el control correcto, botar
ambos y mirar la **conservación**. CHANGELOG **71 `[APLICADO]`**.
Contexto previo: **el ORDEN del grid es del JUGADOR** — `ord` por
entrada, roadmap **#67**, CRG-72, sede §7.2. El autor pidió dos cosas —que los ítems dejen de quedar
desordenados y guarden posición, y que apretar sobre un stack de munición opere sobre **ese** stack y
no sobre las 800 balas de la mochila— y **tenían la misma raíz**: una entrada de stack no tiene
identidad. **Pero para el comercio la identidad resultó INNECESARIA, y ese fue el ahorro del
bloque:** dos stacks del mismo `id` y `condition` son **fungibles**, así que lo que un clic manda no
es *cuál* sino **cuánto**. **La premisa del pedido era falsa** —«tal vez a la munición le falta
información para separar stacks»— y medirlo es lo que lo achicó: `AddStack` parte por `max_stack`
desde el Block 1 y las 800 balas **ya eran siete entradas**; faltaba **no volver a sumarlas al hacer
clic**. Votos: **nivel 1** de posición (orden persistido, **sin arrastrar** — la enmienda «el
footprint es sólo render, sin gestión espacial» **sigue en pie**), `SHIFT+M1` = el stack clicado y
`ALT+SHIFT+M1` = todo (**ALT y no CTRL: CTRL agacha**), y **una celda es un stack en TODAS las listas** (el contenedor y la siembra
de stock del trader no partían: una caja podía decir `x800`). El `ord` lo estampan los **dos
funnels** del record —disco y cable— para que las ~8 rutas que agregan una entrada no tengan que
acordarse, y **no es una identidad**: ningún ref de red lo nombra, así que un `Sort` no puede
re-apuntar un intent en vuelo. **Y de medir el alcance salieron DOS defectos vivos que nadie pidió,
los dos silenciosos:** el comparador terminaba en `(a.uid or "") < (b.uid or "")`, que para dos
stacks compara `""` contra `""` —empate total, y `table.sort` de Lua **no es estable**, así que el
x120 y el x80 se cambiaban de lugar entre syncs sin que nada cambiara—; y **`Take all`/`Move all`
avisaba «no pude mover todo» sobre operaciones que habían funcionado enteras**, porque la lista de
refs traía uno por entrada, el primero se llevaba las siete y los otros seis «no resolvían nada»,
que ese loop lee como *bloqueado*. Harness **910 → 945 verdes**, selftest **100 server / 107
client** (sin moverse: el bloque no toca su superficie), `glua_check` 48/48, y **12 sabotajes en
rojo, 12 de 12**, con control de apertura y cierre en verde (`dev/sabotaje_cargo_67.py`).
**PASADA EN JUEGO ✓ 2026-08-19** — el Sort, el `SHIFT+M1` y el «todo», los tres OK en el trader;
**enmienda de la pasada: el «todo» pasa de CTRL a ALT**, porque CTRL agacha. CHANGELOG **70
`[APLICADO]`**.
**De esa pasada salieron TRES frentes; el #68 y el #69 ya cerraron (arriba) y queda UNO:**
**#70** — el
**nivel 2** del grid: el orden ya no baila, pero el **empaque** sigue dejando huecos (la altura de
una fila es la del tile más alto), y eso sólo se arregla dando a cada ítem una celda. **El #68 ya le
pagó la mitad**: el `cid` es el ref que un intent de arrastre necesita. Enmienda a la mitad *«sin
gestión espacial»* del 2026-07-11 — **la otra mitad, «el costo es peso y no espacio», NO se toca**.
Contexto previo: **un ítem puede tener USOS** — `def.uses = 3`,
roadmap **#66**, CRG-71. **Lo primero que se midió fue que no estaba pendiente:** la barrita que el
autor pedía **ya estaba dibujada** hacía rondas y el precio de un frasco a medio usar **ya se
partía al medio solo**, porque sale de `value × condición × spread`. Faltaba la **unidad** — la
celda decía `67 %` donde un frasco tiene que decir `2/3`. Es **presentación y nada más**: mismo
número guardado, mismo precio, misma persistencia. Cinco votos del autor: **techo** en el redondeo
(compra «0 usos ⟺ condición 0»; con piso, un frasco en 33,3 dice *0 usos* mientras todavía sirve y
el jugador lo tira), el tooltip muestra **los usos Y el %** (el % es de donde sale el precio), `uses`
**implica** `has_condition` (sin él el ítem no dibuja **nada, sin un solo error**), y **a cero el
ítem QUEDA** (qué es un frasco vacío lo decide el módulo dueño, CRG-1). **Y midiendo el alcance
aparecieron DOS defectos vivos y silenciosos** de la tecla rápida, que armaba su ref a mano como
`{ id = itemId }`: un **único** era inalcanzable —y se podía atar igual **arrastrándolo**, porque
el gate de clase estaba sólo en el menú contextual—, así que la tecla contestaba *«You are out of
that consumable»* **para siempre** sobre una mochila con dos frascos; el **Tourniquet de Coagulant**
lleva meses así. Y un **stack con condición** también, ése **sin ni un `Notice`**. Los cierra
`QuickTarget`, que resuelve el id a la instancia **más gastada que todavía sirve** (la regla de
STALKER), y no es cosmético: como Cargo no borra el vacío, sin esa regla el vacío **se come cada
apretada para siempre**. **El hallazgo de instrumento, y es el que más paga:** de los 14 sabotajes
de la verificación en negativo, **dos dejaban la pasada verde entera** — sabotear el *helper* daba
rojo, revertir el **sitio de llamada** (la celda del grid) no. *Se estaba midiendo el helper y no
que alguien lo llamara; un helper impecable que nadie usa es un render viejo con un verde encima.*
Como los overlays son closures `PaintOver` locales, sin nombre y sin superficie que dibujar
offline, el harness ganó un **gate de FUENTES** que lee los archivos y dice qué mide. Harness
**852 → 910 verdes**, selftest **100 server / 107 client**, los 14 sabotajes en rojo. CHANGELOG
**69 `[APLICADO]`**. **PASADA EN JUEGO ✓ 2026-08-19**: planilla `dev/checks/cargo-usos-r1.html` **12 de 12**, `cargo_selftest` **100 OK** y `cargo_selftest_cl` **107 OK**, 0 fallas los dos — y los dos totales **clavados** con los que el harness offline había predicho. **Abrió la #71**, del autor: el chip quick dice `x2` (dos frascos) pero la tecla dispara sobre **uno solo**, así que **el número que muestra no predice lo que va a pasar al apretar** — y es justo el `QuickCount` que esta tanda arregló para contar las dos clases: quedó contando bien la cosa equivocada.
Contexto previo: **el ítem de una CLASE DE ARMA se puede pedir desde
afuera** — `Capture.ItemIdFor(class)`, roadmap **#64**, CRG-70. Es el MISMO agujero que el #63 un
día después: la regla por categoría ya se podía escribir, pero **las armas no estaban EN el
catálogo**. Un arma capturada no tiene código propio —su def es autogen— y la acuñaba sólo la
captura, cuando el engine entregaba el arma; `AttachTrader` resolvía cada línea de stock con
`Items.Get`, no la encontraba, logueaba «stock desconocido» y **salteaba en silencio**, así que el
trader vendía **cero armas con el pack montado entero** — que se lee igual que «el pack no está».
**Lo que acuña lo persiste**: lo que un trader vende, un jugador lo compra, y un arma comprada tiene
que sobrevivir al cambio de mapa. **Y sólo las armas**: censado, todo lo demás (comida, medicina,
munición, NVG, attachments) se registra en el arranque desde `shared`; `autogen = true` aparece una
sola vez en el árbol. **Segundo defecto de instrumento seguido, y otra vez mío:** el tramo de
rechazos era **ciego** — borrando el gate `Ignore` la pasada seguía verde, porque el check sólo
exigía «rechazado con algún motivo» y la clase caía **un gate más abajo** rechazándose igual. *Un
check que no mira CUÁL guarda contestó no juzga ninguna: la firma la de al lado.* Reescrito por
motivo exacto; los **8** gates verificados en negativo. Harness **852 verdes**, selftest **91
server** / 93 client, exit 0. **PASADA EN JUEGO ✓ 2026-08-18**: `cargo_selftest` 91 OK y
`cargo_selftest_cl` 93 OK, 0 fallas los dos — y los dos totales **clavados** con los que el
harness offline había predicho, que es lo único que acredita a ese instrumento. Cerró en la
misma corrida el **#63**; CHANGELOG **67 y 68 `[APLICADO]`**.
Contexto previo: **el catálogo se puede recorrer desde afuera** —
`Items.GetAll()` / `Items.ByCategory(id)`, roadmap **#63**, CRG-69. Lo pidió el trader de comida de
corpus-stalker: su regla votada —*«vende todo lo que declare `category = food`»*, regla y no lista—
no se podía escribir, porque `Items.Get` responde por UNA def y los tres recorridos que existían
leen `_defs` directo desde **adentro** del módulo. La mitad no obvia es el **orden**: salen
ordenadas por id, porque un hash sin ordenar le arma a un trader un catálogo distinto cada arranque
**sin que nadie lo haya sorteado**. **Y salió un defecto del instrumento, más grande que el
parche:** el harness invocaba el selftest con `pcall` y miraba sólo si había **corrido**, tirando su
retorno —que es `fail == 0`—, así que **179 checks (86 server + 93 client) no hacían fallar la
pasada**; los de Craving y Coagulant ya lo hacían bien. Arreglado y verificado en negativo.
Harness **838 verdes** en su momento, exit 0; **pasada en juego ✓ 2026-08-18** (ver arriba). Contexto previo: **dos instrumentos para el realm CLIENTE** —
`cargo_selftest_cl` y `cargo_dev_items_cl`, misma razón que `corpus_selftest_cl`: este módulo es
shared y en listen server **gana el registro del server**, así que su realm cliente era
inverificable en juego. Los estrenó un defecto del framework —la ready barrier no disparaba en
cliente y el grid se quedaba **sin 4.413 defs**, incluidas las médicas y las de comida— cuyo único
síntoma de este lado era el `"No bars registered (absent modules)"` del StatusPanel, que **decía la
verdad**. Sede del diagnóstico: `corpus/docs/CHANGELOG.md` + `dev/VEREDICTO_ready_barrier_cliente.md`.
**CERRADO en juego el mismo día**: `cargo_dev_items_cl` devuelve 51 defs no-bulk en CLIENT —las 4
médicas y las 15 de comida incluidas— y el panel pinta las 5 barras. **Abierto y de otro arco:**
tres quick slots (F1/F2/F3) muestran `x0` en rojo, y con el catálogo completo se ven MÁS que
antes, o sea que no era la def faltante — sin investigar. Contexto previo: **entry 66 `[APLICADO]` — roadmap #57 CERRADO y
confirmado en juego**: los tres pools de munición que el cinturón **no miraba**. No era un problema de peso —
un tipo fuera de `CARGO.Ammo.TYPES` es un tipo que el espejo de §16.3 **no recorre**, o sea que
**esas armas no se alimentaban del cinturón**; el #56 sólo lo hizo visible y lo dejó como frontera.
Tres defs nuevos y el espejo, el peso, el precio, el badge, el unload y el veto de mundo lo heredan
**sin una línea propia**.
**EL CENSO SE REHIZO SOBRE EL ARSENAL VIVO —380 `.gma` suscritos, índice parseado— Y CORRIGIÓ DOS
PREMISAS DEL PROPIO ROADMAP:** (1) **«Winchester» no es un tipo de munición del engine** —no está
en `server.dll`, donde `AirboatGun`/`SniperRound`/`SniperPenetratedRound` sí—: es el `PrintName`
de **TFA Base** para el pool `AirboatGun`, así que *«airboatgun/winchester»* nunca fueron dos pools
sino **uno con dos nombres**, y registrarlos como dos habría acuñado un ítem fantasma; (2) los
francotiradores de ARC9 comen **`SniperPenetratedRound`** y son **diez** clases, no siete (las 7 de
ARC9MW + `awp`/`scout`/`ssg08` de `arc9_go`, que `dev/other/` no tenía), mientras que `SniperRound`
es **otro** pool con tres comedores, todos VJ. Por eso van **los dos** registrados y ninguno
remapeado: dos pools del engine son dos reservas.
**Y un tercer dato que sólo aparece midiendo:** ARC9MW escribe el tipo con **dos grafías** según el
archivo (`SniperPenetratedRound` / `sniperPenetratedRound`). La resolución ya era case-insensitive;
si no lo fuera, **la mitad de las diez seguiría sin cinturón** y se leería como *«a veces anda»*.
**LA VERIFICACIÓN EN NEGATIVO DESTAPÓ UN DEFECTO DEL INSTRUMENTO, Y ERA LA REGLA DEL #53 COMETIDA
AL ESCRIBIR LOS CHECKS QUE LA CITAN:** las seis reversiones enrojecen, pero **cinco lo hacían
crasheando** —los checks indexaban el def pelado, así que quitar una entrada mataba la corrida en
vez de enrojecerla y se llevaba puestos los de abajo—. Corregido con guarda: hoy dan rojo limpio y
la corrida llega al final. **La sexta no se puede reclamar y se dice:** R5 (volver `ItemForType`
case-sensitive) enrojece pero crashea **antes** de llegar al check de las dos grafías, así que ese
check lo sostiene la medición que documenta y no una reversión propia.
**Dos checks viejos se corrigieron, no se borraron:** `#56(a)` y `#56(e)` usaban
`SniperPenetratedRound` como ejemplo de *«tipo que Cargo NO maneja»* y esta tanda vuelve esa
premisa falsa; pasan al pool propio del cuchillo arrojadizo de ARC9MW, que **sigue** sin ítem, y el
francotirador queda como su **contracara**. Harness **817 → 828**.
**Dos fronteras dichas:** **ninguna arma del arsenal vivo come `AirboatGun`** —su única fuente es
la caja de TFA, por eso entra a `WORLD_AMMO`— y los pools por-lanzable de cada pack ARC9 quedan
afuera: son pregunta de throwables (§16.9).
**LA PASADA EN JUEGO CERRÓ, Y CERRÓ POR EL CAMINO QUE SE ESCRIBIÓ:** *«no se rompió nada y están
los modelos; tomar `tfa_ammo` da la munición correspondiente»*, **con la caja entregando un ÍTEM AL
GRID**. Eso último se preguntó antes de escribirlo y no es cosmético: *«la caja da munición»* es
cierto en los **dos** mundos —el ítem al grid (lo nuestro) y el pool crudo que el espejo absorbe al
cinturón (la deuda de `arc9_ammo`, §16.5)—, y **un «funciona» que no distingue qué mecanismo corrió
no cierra un bloque**. Es CRG-16 literal. **Único pendiente, y es de arte:** la caja de **.308** —
el modelo actual dice *.44 Magnum* y es **suplente declarado**; re-vestirlo cuesta un
`Items.SetModel` y ninguna línea de la tabla `AMMO`.)

Antes, 2026-08-01 (**entry 65 `[APLICADO]` — roadmap #56 CERRADO**, el peso de
la munición cargada, confirmado en juego con la **planilla AC en cuatro rondas** y una **frontera
cosmética declarada en §13** por decisión del autor. **Las
mismas 30 balas pesaban 0,36 kg en el cinturón y 0 kg adentro del arma**, o sea que recargar era
un descuento: medido sobre el loadout real, **1,588 kg escondidos en cinco armas**. Ya pesan —
**CRG-67 acuñada** (*una bala pesa lo mismo viva donde viva y ninguna ruta la cuenta dos veces*),
sede §16.10. Harness **771 → 805**, **12 reversiones verificadas en negativo**; checker limpio.
**EL HALLAZGO DE LA RONDA NO FUE EL ROJO SINO LA NOTA DE UN CHECK QUE PASÓ, y es el ÉTER:**
equipar un arma **del engine** regalaba reserva — el volcado del autor la muestra pasando de 6
cohetes a 9 al equipar el RPG, o sea **nueve kilos de capacidad gratis por equipada**. Es más
grande que el agujero que este bloque vino a cerrar y es **anterior** a él; lo prohíbe CRG-17 por
escrito, y **el argumento correcto ya estaba escrito en el mismo comentario que lo dejaba pasar**
(`GiveEquipWeapon` documentaba el éter de los pool-fed y aplicaba el `noAmmo` sólo al throwable).
Sólo mordía a las armas del ENGINE —un ARC9 deja `Primary.Ammo` vacío en la clase—, por eso cinco
packs nunca lo mostraron. **Y el harness no podía verlo: su `Give` ignoraba el segundo argumento**,
así que pasaba en verde con el bug puesto y sin él; el stub ahora modela el regalo y el check va
con su contraprueba.
**Y EL ÚNICO ROJO REFUTÓ LA PREMISA DE LA TANDA, no su código:** *el RPG de HL2 no tiene
cargador* — dispara de la reserva y su `Clip1()` es **-1**, medido con `clip1=-` en las cuatro
corridas. O sea que *«cargar el RPG hace desaparecer tres kilos»*, que abría la semilla y cinco
sedes, **era una inferencia escrita como si fuera una medición** (multiplicar `weight` ×
`max_stack` sin abrir el arma). Se corrige **diciéndolo**, no reemplazándolo callado. Tiene
código además de prosa: un `-1` guardado daría peso **negativo**, y las tres guardas que lo
impiden quedaron medidas por separado.
**La cadencia quedó validada por el único check de sensación**, AC7: *«usé una M249 SAW EFT y se
sintió muy satisfactorio, podía ver el peso bajar, no de golpe, bastante suave la curva»*.
**La tanda no abrió código hasta contestar cuatro preguntas, y la del candidato obvio salió
FALSA:** `Primary.Ammo` **está vacío en la clase** de un arma ARC9 —`SWEP.Primary.Ammo = SWEP.Ammo`
se evalúa al cargar la base, con `SWEP.Ammo` todavía `""`— y sólo `Initialize` lo corrige por
instancia. Lo que sí resuelve es `SWEP.Ammo` trepando `.Base` con `GetStored`, más una tabla de
escape para las armas del engine, que no son SWEPs. **Censo de 243 SWEPs: 215 caen en un tipo
manejado y las 12 que no resuelven nada son exactamente plantillas base y melee** — lo que no
tiene cargador.
**LA MEDICIÓN CAMBIÓ LA PREGUNTA:** recalcular el peso cuesta **1,5 µs** y el `Touch` que
dispararía cuesta **0,158 ms de disco + ~1,7 KB de red**, así que lo caro nunca fue la aritmética
sino el Save y el Sync. Con eso el autor eligió **el poll de 4 Hz que ya corría**: techo de cuatro
Touch por segundo mientras dispara y **cero cuando no**, contra los diez por segundo (64 KB/s a
disco) de un Touch por bala. La medición además **descalificó una de las tres opciones**: pesar el
cargador *por capacidad* no era lo más barato, porque **las armas EFT no declaran `SWEP.ClipSize`**
—cero líneas en los tres packs— y la capacidad vive en el cargador montado.
**LA REGLA DE MÉTODO, y la trajo una reversión que dio CERO:** adelantar el `StoreClip` del unload
—un defecto real de doble conteo que iba a disco— **no pone nada en rojo**, porque el re-leído del
poll ya tapa el mismo hueco. Hacen falta las dos guardas caídas para verlo. O sea: **un check que
sobrevive una reversión no está roto, pero no puede reclamar que prueba el MECANISMO — prueba el
RESULTADO.** Y el propio driver de reversiones falló dos veces por lo mismo del #53: buscaba el
gate en `stdout` cuando sale por `stderr`, y después truncó los fuentes al abrirlos en `"w"` antes
de leerlos.
**Frontera que queda declarada:** §16.6 dice que ningún ammo-att de EFT cambia el pool y es cierto,
pero **ARC9MW tiene cuatro que sí** (`ATT.Ammo`), y los ocho valores de la tabla del engine son lo
único escrito sin poder derivarlo del árbol — el harness prueba que la tabla se consulta, no que
acierte, y el caso estrella (el RPG) cae justo ahí. Eso es lo que mide la AC.)

Antes, **entries 61-64 `[APLICADO]` — roadmap #53 CERRADO**,
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
  `max_stack`, **SHIFT+click = el stack clicado** y **ALT+SHIFT+click = todo**
  (re-votado 2026-08-19, entry 70), click derecho = cantidad exacta.
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
- **La munición cargada PESA** (entry 65, roadmap #56, **sin confirmar en juego**):
  `blob.clip1` × el peso por bala del ítem de munición, sumado en `Instances.WeightOf`
  —la única recursión de CRG-66— como término **aparte** del árbol de atts que el #55
  todavía tiene diferido. El tipo HL2 de un arma **sin entidad viva** sale de su clase
  (`Ammo.TypeOfClass`: `SWEP.Ammo` trepando `.Base` con `GetStored`, después
  `Primary.Ammo`, después la tabla de escape de las armas del engine), y §16.2 queda
  intacta: donde hay entidad, la entidad manda. **CRG-67**: una bala pesa lo mismo
  viva donde viva y ninguna ruta la cuenta dos veces. El refresco viaja en el **poll
  de 4 Hz que ya corría** (`AmmoPool.SyncHeldClip`) — decisión del autor con los cuatro
  costos medidos. Sin convars, sin net, sin timers nuevos.
- **Los tres pools que el cinturón no miraba** (entry 66, roadmap #57,
  **confirmado en juego**): `SniperPenetratedRound` (*Sniper Rounds (AP)*, las **10**
  clases de francotirador ARC9 del arsenal vivo), `SniperRound` (*Sniper Rounds
  (Ball)*, **3** armas VJ) y `AirboatGun` (*Winchester Rounds* — **`Winchester` no
  es un tipo del engine**, es el `PrintName` de TFA para ese pool). Tres entradas
  en la tabla `AMMO` y el espejo, el peso, el precio, el badge, el unload y el veto
  de mundo lo heredan sin una línea propia. Los dos de francotirador **comparten
  `ammo_sniper.mdl`** y los separa el **nombre**. Las dos cajas de TFA
  (`tfa_ammo_winchester` 50, `tfa_ammo_sniper_rounds` 30) entran a `WORLD_AMMO`
  porque la de Winchester es la **única fuente** de `AirboatGun` en el arsenal —
  y se midió que la caja entrega **ítem al grid** (CRG-16) y no reserva cruda.
  **Pendiente de arte:** el `.mdl` de Winchester dice *.44 Magnum* y el ítem se
  etiqueta `.308` — suplente declarado hasta que haya una caja de .308.
- **Harness offline: 828 checks verdes en ambos realms** (con gate final: un
  FAIL tardío ya no imprime ALL GREEN, y **el total lo imprime el propio script** — no se
  grepea de stdout, donde el banner de realm corría carreras con los `print` de Lua);
  `cargo_selftest` 83 client / 76 server (+2 en el bloque de munición).
- **Mapa de archivos completo** → [`../CLAUDE.md`](../CLAUDE.md). Remote
  `origin` **al día** (push 2026-07-13, pedido del autor; incluye `LICENSE`
  MIT y el rename `corpus_stalker` en el kit dev).

## Pendiente de verificar

- **Nada de la tanda del 2026-08-21.** Las planillas **AI** (13 filas) y **AJ** (7) **cerraron el
  mismo día, en una ronda cada una y sin un rojo**; la barra de prueba de la AJ quedó **desmontada**
  (fila AJ7), así que no hay una *AJ Test* fantasma esperando en una ronda futura.
- **Detalle de las rondas 2-4, para referencia. El bloqueante de la ronda 2 quedó RESUELTO** (el
  espejo volvió por su cuenta y el instrumento que lo lee quedó escrito para la próxima vez).
  Entonces: **el ESPEJO DE MUNICIÓN NO ESTABA CORRIENDO**, y los dos rojos son ese único hecho. La captura
  de pantalla lo prueba contra CRG-15: 3 cohetes y 2 virotes en el pool que **no están en ningún
  slot del cinturón ni en el grid**, con dos slots libres — y los cuatro tipos que sí coinciden
  son exactamente los que no tuvieron actividad. Un espejo con un bug no se ve así; **un espejo
  detenido sí.** Con eso, *«el belt dejó de funcionar»*, *«la munición del pickup no va a ningún
  lado»* y *«no puedo hacer unload»* dejan de ser tres defectos.
  **Los dos interruptores fallan DISTINTO y esa diferencia es el diagnóstico:** con
  `cargo_ammo_pool 0` el unload sale **mudo** (y la convar es `FCVAR_ARCHIVE`, o sea que
  sobrevive al reinicio); con el gate de spawn cerrado, **avisa**. Ninguno de los dos lo puede
  tocar el parche del éter — cambiar el segundo argumento de `ply:Give` no escribe una convar ni
  el gate—, y se dice en vez de descartar la sospecha en silencio.
  **La tanda entregó instrumento, no parche:** `AmmoPool.IsReady` expone el gate (hasta ahora
  *«apagado»* y *«corre y falla»* eran indistinguibles desde el juego) y `cargo_dev_ammoweight`
  imprime los dos interruptores más el invariante **ya comparado**. **Falta correrlo.**
  **EL ESPEJO VOLVIÓ** (reporte del autor: *«se arregló el belt con la munición»*), así que el
  bloqueante está levantado y el instrumento queda igual — es el que va a decir cuál de los dos
  interruptores era, si vuelve a pasar.
  **Segunda puerta del éter, PARCHEADA (parche 3):** tomar un arma de HL2 **del mundo** regalaba
  reserva, y el síntoma sobrevivió al espejo restaurado, o sea que era independiente. El parche de
  la ronda 1 había cerrado la ruta del *equip*; ésta es la de la **captura**. Se resuelve **por
  DELTA y no por lectura**: el clawback que ya existía es **sólo de VJ Base** (lee
  `PickUpAmmoAmount`), y un arma del engine no es un SWEP, así que no hay tabla que leer — lo que
  hay es un **antes**, porque toda adquisición pasa por `PlayerCanPickupWeapon` antes del `Equip`.
  Se fotografía ahí y se restaura un tick después, **sólo si el pool subió**. Los throwables quedan
  afuera a propósito: para un frag el regalo del engine **es** el mecanismo (§16.9).
  **Parche 4 — INTENTO de apagar el regalo en la fuente, MEDIDO Y NO ALCANZÓ:** con lo funcional ya cerrado (*«ya no recolecta
  rockets»*), el HUD de DGL4 **seguía anunciando la captura de 3 cohetes** — el mismo síntoma que
  dejaban las armas de VJ, y la línea que lo resolvió allá está en este mismo archivo: *«the event
  itself must never fire»*. Verificado contra la fuente del mod (CRG-24): DGL4 alimenta su
  historial desde `HUDAmmoPickedUp`. **Taparlo desde un hook hermano sería una carrera** —el orden
  entre hooks distintos no es de inserción, lección de la saga VJ—, así que se apaga
  `m_iPrimaryAmmoCount` en la entidad antes del `Equip`, **en `pcall` y sin asumir que el campo
  exista**. **Corrido en juego: el historial de DGL4 SIGUE anunciando los 3 cohetes y el pool queda
  en 0** — o sea que **el invariante está cerrado y la cosmética no**. El parche se queda (es
  inerte donde no aplica), pero la afirmación no: decía que el regalo se apagaba en la fuente y eso
  **no está probado**. En vez de probar un segundo nombre de campo a ojo —tercera vuelta sobre una
  suposición—, `cargo_dev_worldwep` ahora imprime los campos de `ammo`/`clip` de la **save table**
  del arma apuntada: la próxima pasada encuentra el campo real o prueba que el regalo no vive en el
  datamap, y ahí la frontera se declara **con su medición**.
- **AC9 CERRÓ la deuda de verificación de la entry 64**, abierta desde el #53: montar un att
  desde el menú C **descuenta uno del grid** (`pmag_30` de `grid=5 montado=0` a `grid=4
  montado=1`, con el STANAG desalojado en `grid=1`). El puente no duplica, medido en juego.
- **La entry 65 (roadmap #56) sigue `[PENDIENTE]` tras la ronda 1 de la planilla AC (8/9).** El
  único rojo, **AC2, no era del código**: refutó la premisa de la tanda (el RPG no tiene cargador)
  y se resolvió corrigiendo las cinco sedes que la repetían. Los dos parches de la ronda salieron
  de **la nota de un check que PASÓ** (AC1, el éter) y del rojo (AC2, el ejemplo falso).
  **Falta la ronda 2:** re-correr AC2 con su premisa corregida —sobre un arma que sí tenga
  cargador— y **AC1 con el éter tapado**, que es el check que ahora tiene que volver mostrando la
  reserva quieta al equipar un arma de HL2. **AC9 quedó marcado PASA sobre una sola foto** y su
  criterio pedía la resta (correr, montar desde el menú C, correr de nuevo): sin el segundo
  volcado, la evidencia pegada no lo sostiene — es la misma trampa de AB13/AB14.
- **Detalle de la ronda 1, para referencia.** Lo que el harness
  prueba (27 checks nuevos, **8 reversiones verificadas en negativo**): que el tipo se resuelve
  sin entidad viva por sus cinco formas, que el RPG descargado pesa 6 kg y cargado 9, **la
  IGUALDAD de conservación** —30 balas pesan lo mismo en el cinturón que en el cargador, que es
  el reclamo textual del autor— con su desigualdad de apoyo, la degradación honesta en cuatro
  formas, y la cadencia **con su AUSENCIA**: dos pasadas del poll sin mover el cargador cuestan
  cero Touch, que es lo único que separa esta cadencia de un Touch por bala.
  **Lo que NO puede probar, y por eso existe la AC:** (1) que los **ocho valores de la tabla del
  engine** sean los que el engine usa — `weapons.GetStored` da `nil` para las armas de HL2, así
  que offline sólo se prueba que la tabla se consulta, y **el caso estrella del bloque, el RPG,
  cae justo ahí**; (2) el arsenal real, del que `dev/other/` cubre ~2/3; (3) **cómo se siente**
  el peso moviéndose mientras se dispara — y si se siente mal, la primera sospecha va al modelo
  y no al número.
  Planilla: https://claude.ai/code/artifact/5734e521-db27-400d-9693-0fc1e12a85a9
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

1. **Slice 2 del comercio** *(sigue vigente, pero NO es el frente que el autor viene tocando: las últimas seis entradas cerradas son todas de UI de inventario)* — el **plan de persistencia quedó cerrado** con B5: B6 (perfiles reales y GC
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
2. **El frente de UI del inventario, que es donde el autor viene mirando** — y va en este orden
   porque **cada una paga parte de la siguiente**:
   · **#71 (chip con usos)** — *primero, y es barata: lo que falta es un VOTO tuyo, no código.* Hoy
     el chip dice `x2` (dos frascos) pero la tecla dispara sobre **uno solo**, el más gastado, así
     que **el número que se muestra no predice lo que va a pasar al apretar**. Tres formas, y la
     (a) hay que **medirla antes de votarla**: es la única que necesita resolver la instancia del
     lado del cliente, y esa regla hoy vive **sólo en el server** (`QuickTarget`) — si la duplica,
     es más cara de lo que parece. *Medir eso es media hora y decide el voto.*
   · **#58 (el tooltip miente el peso)** — chica, pedido explícito tuyo en la planilla AC. El
     cálculo ya existe y es uno solo (`Instances.WeightOf`), pero es **SERVER**, así que el número
     tiene que **viajar en el snapshot**: recalcularlo en el cliente sería la segunda verdad que
     CRG-56/57 evitan. Decisión tuya: ¿peso **efectivo** en la ficha, o el de la def con el extra
     al lado?
   · **#70 (nivel 2 del grid: posiciones reales)** — **la grande, y el `cid` del #68 ya le pagó la
     mitad**. Es la causa de fondo del *«igual se ve medio desordenado»*: el #67 le sacó al orden
     ser una función del contenido, pero el empaque sigue siendo `DIconLayout` flex-wrap, y la
     altura de una fila es la del tile más alto — un 1×1 al lado de un rifle 2×3 deja **celdas
     muertas que no ocupa nadie**. Eso no se arregla ordenando: se arregla dándole a cada ítem una
     **celda**. ⚠ Enmienda la decisión del 2026-07-11, y **sólo su primera mitad**: va a haber
     gestión espacial, pero el grid sigue siendo infinito hacia abajo y **el techo sigue siendo el
     peso**.
   · **#73 (separar un stack a mano)** — **va DESPUÉS del #70 y no antes**, porque no es un botón:
     separar es lo inverso de `AddStack`, que **mergea solo**, así que una celda separada se vuelve
     a fundir en el próximo funnel. Decidir si el merge deja de ser automático toca el #67 **y** el
     #70. Medir eso primero.
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
