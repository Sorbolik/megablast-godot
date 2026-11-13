# Guida all'editor delle animazioni di Godot

13 novembre 2026. Si prova sull'apprendista di oggi: la scena `game/apprendista.tscn` del
progetto `C:\Sviluppo\megablast-godot`. Quando arriva l'apprendista nuovo (WB-036) i passi sono
gli stessi.

## 1. Aprire la scena

1. In Godot apri il progetto, poi nel pannello **FileSystem** (in basso a sinistra) fai doppio
   clic su `game/apprendista.tscn`.
2. In alto premi **2D** per la vista 2D. Il diavoletto è piccolo (39 pixel): selezionalo e premi
   **F** per inquadrarlo, poi ingrandisci con la rotella.
3. Nel pannello **Scena** (in alto a sinistra) trovi:
   - `Scheletro`, con dentro le ossa: `corpo` › `forma` › `busto`, `collo` (testa), `braccio_a`
     › `gomito_a` › `mano_a`, `gamba_a` › `ginocchio_a` › `piede_a`, quelle `_d` dietro, `coda_0…4`;
   - i pezzi (`busto`, `testa`, `braccio`, `gamba`, `coda`, `mantello`…): sono maglie piegate
     dalle ossa.

Tasti della vista 2D: **Q** seleziona, **W** sposta, **E** ruota, **S** scala.

## 2. La prima animazione

1. Seleziona la radice `Apprendista`, premi **Ctrl+A**, cerca **AnimationPlayer** e aggiungilo.
   In basso si apre il pannello **Animazione**.
2. Nel pannello premi **Animazione › Nuova** e chiamala, per esempio, `saluto`.
3. In alto a destra del pannello metti la **durata** (per esempio 1 secondo). Il pulsante con
   le due frecce in tondo accanto la fa **ripetere** (ciclo).
4. Fai la prima posa:
   - seleziona l'osso `braccio_a` nella Scena, premi **E** e ruotalo nella vista;
   - nell'**Ispettore** (a destra), alla voce *Transform › Rotation*, premi la **chiave** accanto al
     valore: nasce una traccia con il primo fotogramma chiave.
5. Sposta la testina del tempo (la riga blu in alto nella timeline) a 0,5 s, ruota di nuovo
   l'osso e premi di nuovo la chiave. Fai lo stesso a 1 s, tornando alla posa di partenza.
6. Premi **▶** nel pannello per vederla. Puoi trascinare la testina avanti e indietro per
   controllare ogni istante.

Si anima solo la **rotazione** delle ossa (a parte `corpo`, che si può anche spostare per i salti):
così le ossa restano attaccate.

## 3. Rifinire

- **Onion skin**: nella barra del pannello Animazione c'è il pulsante con i fogli
  sovrapposti; acceso, mostra in trasparenza le pose prima e dopo. Dal suo menu scegli
  quante pose vedere.
- **Morbidezza dei movimenti**: a destra di ogni traccia c'è il menu dell'interpolazione,
  **Cubica** per un moto morbido o **Lineare**; selezionando un fotogramma chiave,
  nell'Ispettore c'è **Easing** per farlo partire o arrivare piano.
- **Curve**: il pulsante con la curva in basso a destra del pannello apre l'editor di Bezier,
  dove tiri le maniglie di ogni chiave come in un programma di grafica.
- **Copiare una posa**: seleziona le chiavi (trascina un rettangolo nella timeline),
  **Ctrl+C**, sposta la testina, **Ctrl+V**. **Ctrl+D** le duplica.
- **Tornare a riposo**: seleziona `Scheletro` e nel menu in alto **Skeleton2D › Reset to Rest
  Pose**. Godot crea anche un'animazione `RESET` con i valori di partenza: lasciala lì.
- **Salva** con **Ctrl+S**.

## 4. Pesi e maglie: come si piega un pezzo

1. Seleziona un pezzo, per esempio `braccio`, e premi **UV** nella barra in alto: si apre
   l'editor del poligono.
2. Scheda **Bones**: premi **Sync Bones** se la lista è vuota, scegli un osso a sinistra e
   dipingi con il pennello quanto quell'osso tira i punti (chiaro = tanto, scuro = niente). I
   cursori regolano raggio e forza; tenendo **Ctrl** togli peso.
3. Schede **Points** e **Polygons**: sposti i punti della griglia o ne aggiungi dove serve più
   piega, per esempio intorno al gomito.
4. Prova subito: ruota `gomito_a` e guarda come si piega il braccio. Se si stira male, ridipingi i
   pesi vicino al gomito.

## 5. Cosa arriva nel gioco

- Nell'editor vedi subito tutto quello che fai.
- Nel gioco (F5) oggi il diavoletto si muove ancora con le clip del gioco vero, che passano
  sopra le ossa: **le tue animazioni non si vedono ancora lì**. I pesi e le maglie invece sì.
- Nella fase 4 collego l'AnimationPlayer al gioco: fermo, corsa, salto e colpito diventano
  animazioni di questo pannello, e quello che fai qui si vede nel gioco e sul telefono.
- Quando hai fatto qualcosa che vuoi tenere, salva e dimmelo: lo prendo dal PC.
- Attenzione: `tools/salva_scena.gd` rifà la scena dai disegni e cancella i ritocchi a mano.
  Non lanciarlo.
