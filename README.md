# MegaBlast in Godot (spike)

Prova di due settimane per capire se Godot ci dà più potere sulla grafica del
personaggio (scheletro, mesh che si deformano, mantello e fiamma con la fisica,
espressioni) rispetto a Defold. Non è il gioco: c'è solo l'essenziale.
Proposta e criteri di decisione: https://claude.ai/artifact/3kFrd7aHXHkX6yFsSTcWGB

## Cosa c'è

- `sim/`: la fisica del movimento di MegaBlast riscritta in GDScript con gli stessi
  numeri e lo stesso passo fisso (camminata con gradini, salto libero con controllo
  in aria, salto corto, coyote time, buffer del salto, danno da caduta, esplosione
  del Lanciarune con cratere e spinta, rinculo del Tonante).
- `data/cortile.bin`: la maschera del Cortile presa dalla simulazione vera.
- `tools/confronta.py`: fa girare lo stesso scenario nella simulazione vera (LuaJIT,
  dal repository MegaBlast) e qui, e controlla che le traiettorie siano identiche
  **bit per bit** a ogni tick. È la garanzia che le differenze che vediamo
  dipendono solo dal motore.

- `game/devil.gd`: l'APPRENDISTA rifatto con gli strumenti di Godot dagli stessi
  disegni (`tools/prepara_pezzi.py`): Skeleton2D e ossa, ogni pezzo una mesh piegata
  dalle ossa, le stesse clip di MegaBlast (`data/clip.json`, `game/pose.gd`) e le
  stesse molle. In più (si spengono col tasto EXTRA per il confronto): mantello di
  stoffa simulata, fiamma che segue il moto con braci e alone, palpebre e sguardo
  (`game/eye.gdshader`), busto che respira, gomiti e ginocchia.
- `game/main.gd`: il Cortile giocabile, camera, comandi, foto e misure.

## Sul telefono

Ogni push su `main` costruisce l'APK (Actions > APK, si scarica dagli artefatti).
Comandi: frecce, SALTA, BOOM (esplosione ai piedi), TONANTE (rinculo), EXTRA (accende
e spegne le novità di Godot), MISURA (8 diavoletti per 30 secondi: il risultato
resta in alto a sinistra).

## Comandi

Serve Godot 4.7 (`godot` nel PATH) e `luajit`.

```bash
godot --headless --path . --import                       # la prima volta
python3 tools/confronta.py ../megablast godot            # deve finire con OK
luajit tools/esporta_mappa.lua ../megablast              # se cambia la mappa
luajit tools/esporta_clip.lua ../megablast               # se cambiano le clip
python3 tools/prepara_pezzi.py ../megablast              # se cambiano i disegni
godot --path . -- --foto foto.png --zoom 6 --tieni RJ    # una foto (R L J: tasti tenuti)
godot --path . -- --misura 8 --secondi 60                # misura con 8 diavoletti
```

## Ritoccare l'Apprendista nell'editor di Godot

L'Apprendista è la scena `game/apprendista.tscn`: ossa, maglie, pesi, occhi, fiamma e
mantello. Il gioco la carica così com'è, quindi quello che cambi lì lo vedi premendo F5.

1. Nel pannello FileSystem fai doppio clic su `game/apprendista.tscn`. Nella vista 2D
   ingrandisci sul diavoletto (è piccolo: 39 pixel).
2. **Muovere le ossa.** Nella scena apri `Scheletro` e seleziona un osso (per esempio
   `braccio_a`): ruotalo con il tasto E o trascinalo. Per tornare alla posa di riposo:
   menu `Skeleton2D` > `Reset to Rest Pose`; per fissare quella nuova: `Make Rest Pose`.
3. **Dipingere i pesi.** Seleziona un pezzo (per esempio `braccio`), nella barra in alto
   premi `UV`, poi la scheda `Bones`: scegli un osso a sinistra e dipingi con il
   pennello quanto quell'osso tira i punti (bianco = tutto, nero = niente). È qui che si
   decide come si piegano gomito, ginocchio, pancia e coda.
4. **Cambiare la maglia.** Nella stessa finestra UV, scheda `Points` e `Polygons`: sposti
   i punti della griglia o ne aggiungi dove serve più piega.
5. **Mantello.** Seleziona la radice `Apprendista`: nel gruppo Mantello ci sono peso, aria,
   rigidità, lunghezza, larghezza e attacco. Valgono anche mentre il gioco gira (scheda
   Remoto).

Attenzione: `godot --headless --path . -s tools/salva_scena.gd` rifà la scena dai disegni
e cancella i ritocchi fatti a mano. Si usa solo quando cambiano i pezzi.
