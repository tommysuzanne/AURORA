# Guards & filtres de régime

## Source (doc legacy)

`DOCS/legacy/Aurora_Documentation.md` (section “Guards & filtres de régime”).

## Résumé (haut niveau)

Aurora applique des “gates” avant d’autoriser :
- l’entrée (`allowEntry`),
- la gestion (BE/trailing/exits) (`allowManage`),
- la purge d’ordres en attente (`guardPurgePending`).

Principales familles :
- sessions / jours / close mode,
- week-end gap,
- news (MT5 Economic Calendar),
- filtres de régime/stress (Hurst/VWAP/Kurtosis/Trap/Spike/Smooth).

## Inputs

Voir `../inputs/1-4-filtres-entree.md`, `../inputs/3-1-sessions.md`, `../inputs/3-2-news.md`.

