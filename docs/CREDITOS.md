# Créditos

Cargo **incluye assets de terceros**. El código es del proyecto; los assets no, y sus autores
conservan sus derechos. Esta página existe porque **la licencia lo exige**, no por cortesía.

> **Si sos el autor de alguno de estos assets y querés que se retiren, se retiran.** Sin discusión y
> sin condiciones. Abrí un issue o escribí, y sale en la siguiente versión.

---

## Modelos de munición — Sketchfab, CC BY 4.0

Los dos son del mismo autor, así que **una sola entrada los cubre**.

- **Autor:** **jsandwich96**
- **Licencia:** **CC Attribution 4.0 International** — <https://creativecommons.org/licenses/by/4.0/>
- **Están modificados.** Decirlo es parte de la obligación de CC BY: se convirtieron a formato
  Source (`.mdl`), se reescalaron, se separaron en piezas y se reconvirtieron sus materiales PBR al
  modelo de iluminación de Source.
- **Rutas:** `models/corpus_cargo/`, `materials/models/corpus_cargo/`

| `.mdl` | Qué es | Fuente | Tris | Tamaño |
|---|---|---|---:|---|
| `ammo_sniper` | caja de cartón abierta, *ELITE HUNTER · 7mm MAG · 20 cartridges*, con 13 cartuchos | [Sniper Ammo Box (Game-ready)](https://sketchfab.com/3d-models/sniper-ammo-box-game-ready-5338de8c47ea4f68aa40dd51602a2b53) | 6.000 | 19 cm |
| `ammo_winchester` | caja de cartón abierta, *PANTHERA · .44 MAG*, con ~15 cartuchos | [Magnum Ammo Box (game-ready)](https://sketchfab.com/3d-models/magnum-ammo-box-game-ready-c85ea88531e84bf7b72b89b9e5cc79db) | 7.960 | 13 cm |

> **CORRECCIÓN (2026-08-06, roadmap #57): el nombre del archivo NO es el de un pool del engine.**
> Esta página decía que sí, y el censo del arsenal vivo lo refutó: **`Winchester` no existe como
> tipo de munición** —no aparece en `garrysmod/bin/win64/server.dll`, donde `AirboatGun`,
> `SniperRound` y `SniperPenetratedRound` sí están—. Es el `PrintName` que **TFA Base** le pone al
> pool `AirboatGun` (`tfa_ammo_winchester`, *"Winchester Ammo"*, 50 balas). El mapeo real es:
>
> | `.mdl` | Pool del engine que ata | Ítem de Cargo |
> |---|---|---|
> | `ammo_sniper` | `SniperPenetratedRound` (10 armas ARC9) **y** `SniperRound` (3 de VJ) | `cargo_ammo_sniperpenetratedround` · `cargo_ammo_sniperround` |
> | `ammo_winchester` | `AirboatGun` | `cargo_ammo_airboatgun`, mostrado como *Winchester Rounds* |
>
> Y el desajuste de calibre queda **a la vista y por decisión**: el arte dice **.44 Magnum** y el
> ítem se etiqueta **`.308`**, que es el texto de la caja de TFA que reparte estas balas. El modelo
> es **suplente** hasta que exista una caja de .308 (pedido del autor, 2026-08-06).
>
> **Ése es el único pendiente del #57**, y es de arte: cuando aparezca la caja de .308 se agrega
> acá con su crédito y se cablea con `Items.SetModel("cargo_ammo_airboatgun", …)` — **sin tocar la
> tabla `AMMO`**, que para eso existe ese punto de extensión (entry 34).

**Los usan tres defs desde el roadmap #57** (`shared/corpus_cargo_ammo.lua`), y los dos ítems de
francotirador **comparten `ammo_sniper.mdl`**: son dos pools distintos del engine y lo que los
separa en la celda es el nombre. Modelos confirmados en juego el 2026-08-05.

## Cómo se reproducen

Los `.mdl` no se editaron a mano. Cada uno tiene su `.qc` en `dev/phastools/compile/src/` con el
comando exacto que lo regenera desde el `.fbx` de origen, y las herramientas (`fbx2smd.py`,
`pbr2source.py`, `png2vtf.py`, `verify_model.py`) viven en `dev/phastools/`. El registro de créditos
del workspace, con el censo completo de los packs, está en `dev/Creditos_Modelos_Terceros.md` —
**fuera de este repo**, y por eso esta página existe: `dev/` no viaja con el addon.

---

## La animación de recoger — [GCAL] Improved Manual Pickup

El gesto que hace el brazo al tomar algo del suelo con **WALK+USE** viene de ahí. Es **código y
ajuste**, no un asset: Cargo **no copia ningún archivo** de esos dos addons.

| Qué | Quién | WSID |
|---|---|---|
| **[GCAL] Improved Manual Pickup** — de él se recicló la **tabla de ajuste** del gesto (`lerp_peak` 0,7 · `lerp_speed_in` 1 · `lerp_speed_out` 0,8 · `lerp_curve` 2,5 · `speed` 1), que es el *"use"* de VManip ralentizado y suavizado hasta que se lee como *levantar algo del piso* en vez de *apretar un botón*. Ese ajuste es la parte del addon que costó gusto y no código | **Sin verificar** — el header del `.gma` trae el placeholder `Author Name` y el `.lua` no acredita a nadie. El pack se presenta como una reescritura de **VManip Manual Pickup** | [`3722869921`](https://steamcommunity.com/sharedfiles/filedetails/?id=3722869921) |
| **GCAL — Garry's Mod Compliant Armature Layer** — la biblioteca que **reproduce** el gesto y de la que sale el modelo `c_vmanipinteract.mdl`. Se consume **por API** (`GCAL:RegisterAnim` / `GCAL:Play`) y el modelo se referencia **por ruta en runtime**: no viaja nada en el `.gma` de Cargo | **Midawek** — no del header del `.gma` (dice el placeholder `Author Name`) sino **del propio código**: `lua/autorun/gcal_init.lua:15` enlaza <https://github.com/Midawek/gcal>. GCAL a su vez acredita a *M4K0*, *Evgeny Akabenko*, *Nak* y *Chen* como contribuyentes | [`3727245204`](https://steamcommunity.com/sharedfiles/filedetails/?id=3727245204) |

**Lo que NO se recicló**, y es casi todo el addon de origen: su sistema de pickup manual entero —el
veto de `AllowPlayerPickup`, su tabla de clases `item_ammo_*`, el malabar con
`m_bPreventWeaponPickup` y su timer de respaldo, el halo verde estilo NMRIH y el modelo del ítem
colgado de la mano—. Cargo ya tenía todos esos trabajos hechos en su portero de `PlayerUse`
(`corpus_cargo_capture.lua`), que es más viejo y más ancho. **Se recicló una sola cosa: la
animación.**

> **Si eres el autor de cualquiera de los dos y quieres que esto se retire, se retira** — misma regla
> que arriba, sin condiciones. El acople es un archivo (`shared/corpus_cargo_pickupanim.lua`) y una
> convar (`cargo_pickup_gesture 0`), así que sale sin tocar nada más.

---

## Otros assets de terceros ya acreditados en su sitio

No se repiten acá; el crédito vive donde se usa, que es donde alguien lo va a leer.

| Qué | Dónde está el crédito |
|---|---|
| **Apex Hands** — el SWEP `Hands` recicla su modelo y sus animaciones (Workshop 2792160770) | header de [`lua/weapons/corpus_cargo_hands.lua`](../lua/weapons/corpus_cargo_hands.lua) |
| **Simple Holster** — la transición de enfundado se recicló de ahí | header de [`lua/corpus_cargo/server/corpus_cargo_holster.lua`](../lua/corpus_cargo/server/corpus_cargo_holster.lua) |
| **Quick Loadouts**, **ARC9**, **NVG de Neosun** | son compat en runtime: Cargo no incluye nada de ellos |
