# Internal — Weekend guard

## Objectif

Expliquer la protection gap week-end (sessions broker, close soon, block entries).

## Source-of-truth

- `MQL5/Include/Aurora/aurora_weekend_guard.mqh`
- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (section “Weekend guard”)

## Résumé (depuis la doc source)

- Reconstruit les sessions `SymbolInfoSessionTrade` sur plusieurs jours et calcule :
  - `gap_min` entre close et réouverture,
  - `time_to_close_min`.
- Si `gap_min >= InpWeekend_GapMinHours*60` :
  - “close soon” si `time_to_close_min <= InpWeekend_BufferMin`,
  - “block entries” si `time_to_close_min <= InpWeekend_BlockNewBeforeMin`.

