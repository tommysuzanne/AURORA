# Enums (référence)

## Objectif

Lister les enums exposées côté inputs et où se trouve la définition.

## Source-of-truth

- `MQL5/Include/Aurora/aurora_types.mqh`

## Liste (doc source)

- `ENUM_STRATEGY_CORE` : `STRAT_CORE_SUPER_TREND`, `STRAT_CORE_MOMENTUM`
- `ENUM_ENTRY_STRATEGY` : `STRATEGY_REACTIVE`, `STRATEGY_PREDICTIVE`
- `ENUM_ENTRY_MODE` : `ENTRY_MODE_MARKET`, `ENTRY_MODE_LIMIT`, `ENTRY_MODE_STOP`
- `ENUM_PREDICTIVE_OFFSET_MODE` : `OFFSET_MODE_POINTS`, `OFFSET_MODE_ATR`
- `ENUM_SIGNAL_SOURCE` : `SIGNAL_SRC_HEIKEN_ASHI`, `SIGNAL_SRC_REAL_PRICE`, `SIGNAL_SRC_ADAPTIVE`
- `ENUM_RISK` : modes equity/balance/margin/volume fixe etc.
- `ENUM_BE_MODE` : `BE_MODE_RATIO`, `BE_MODE_POINTS`, `BE_MODE_ATR`
- `ENUM_TRAIL_MODE` : `TRAIL_STANDARD`, `TRAIL_FIXED_POINTS`, `TRAIL_ATR`
- `ENUM_PYRA_TRAIL_MODE` : `PYRA_TRAIL_POINTS`, `PYRA_TRAIL_ATR`
- `ENUM_SL_MODE` : points fixes, deviation, ATR, deviation ATR
- `ENUM_NEWS_LEVELS` : `NONE`, `HIGH_ONLY`, `HIGH_MEDIUM`, `ALL`
- `ENUM_NEWS_ACTION` : block entries/manage/close/monitor
- `ENUM_SESSION_CLOSE_MODE` : `OFF`, `FORCE_CLOSE`, `RECOVERY`, `SMART_EXIT`, `DELEVERAGE`

TODO(verify): aligner la liste avec la version actuelle du fichier — Comment obtenir: ouvrir `MQL5/Include/Aurora/aurora_types.mqh` et extraire les enums exposées aux inputs.

