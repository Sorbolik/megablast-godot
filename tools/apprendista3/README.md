# L'apprendista di WB-037 per Godot (art/apprendista3)

Dai fogli di Codex al rig, senza mettere niente a occhio (Sergio, 13 nov):

1. `taglia_pezzi.py` ritaglia i fogli scelti: WB-037 `corpo_1`, `teste_1`, `fiamma_1`;
   WB-039 `teste_senza_corna_2`.
2. `corna.py` prende le corna per differenza fra `teste_1` e le teste senza corna:
   il foglio `corna` di WB-039 ha la base troppo corta e lascia un buco.
3. `registra.py` (scala, rotazione e posizione con la minima differenza di colore,
   da grossolana a fine) e `perno.py` (rotazione attorno a una giuntura) mettono ogni
   pezzo sull'apprendista scelto (WB-036 n. 2, R1): risultati in `t.json`. Il foglio
   corpo ha una scala sola (1.64 px di R1 per px), le teste la loro (2.189).
   `giunture.py` trova le estremità senza contorno (collo, spalla, anche, radice della coda).
4. `traccia.py` ricalca in SVG coi colori esatti (`tav37.json`, con `vettoriale.py`
   di MegaBlast) dopo aver calibrato i colori di Codex sulla tavolozza. Il PNG
   esportato è di 12 px per unità, con mipmap.
5. `esporta.py` scrive i PNG dritti e `rig.json` (unità, y in su, 0 ai piedi;
   200 unità dai piedi alla cima del cranio). `montaggio.py` e `sovrapponi.py`
   fanno il confronto con R1.

Gli strati, dal fondo, sono pronti per l'equipaggiamento: braccio e gambe dietro,
mantello, coda, busto, (corazza), fazzoletto (sparisce col mantello), testa,
(elmo), corna, fiamma, braccio davanti. Le clip contano dal valore della clip
`fermo` (`Devil.cv`), perché il disegno è già nella posa di R1.
