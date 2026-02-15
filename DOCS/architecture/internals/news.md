# Internal — News filter (MT5 Economic Calendar)

## Objectif

Documenter le filtre news (cache, refresh, fallback) et où le diagnostiquer.

## Source-of-truth

- `MQL5/Include/Aurora/aurora_news_core.mqh`
- `MQL5/Include/Aurora/aurora_newsfilter.mqh`
- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (section “News core” + FAQ)

## Points techniques (résumé)

- Cache d’événements rafraîchi via `OnTimer` selon `InpNews_RefreshMin`.
- Fenêtres blackout avant/après + noyau minimal renforcé pour news fortes.
- Fallback neutre si API indisponible, avec throttling des probes.

## Debug (symptômes)

- “Le filtre news ne bloque rien” : vérifier `InpNews_Enable`, `InpNews_Levels`, `InpNews_Ccy`, `InpNews_Action`.

