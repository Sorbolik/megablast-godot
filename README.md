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

## Comandi

Serve Godot 4.7 (`godot` nel PATH) e `luajit`.

```bash
godot --headless --path . --import                       # la prima volta
python3 tools/confronta.py ../megablast godot            # deve finire con OK
luajit tools/esporta_mappa.lua ../megablast              # se cambia la mappa
```
