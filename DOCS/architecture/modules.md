# Modules (MQL5/Include/Aurora)

## Objectif

Donner la carte des modules et où ils s’intègrent dans l’EA.

## Source-of-truth

- `MQL5/Include/Aurora/*`
- `MQL5/Experts/Aurora.mq5` (wiring global + appels `On*`)

## Modules (liste)

- `aurora_engine.mqh` : cœur (helpers marché, exécution, trailing/BE/exit-on-close, logique ordres)
- `aurora_trade_contract.mqh` : contrat d’API d’exécution partagé (découplage des includes)
- `aurora_guard_pipeline.mqh` : pipeline guards (session/weekend/news) pour `OnTick` + `OnTimer`
- `aurora_async_manager.mqh` : gestion `OrderSendAsync`, déduplication, retries, persistence
- `aurora_state_manager.mqh` : persistence du state async (`FILE_COMMON`, binaire)
- `aurora_snapshot.mqh` : snapshot positions en un passage + agrégats
- `aurora_virtual_stops.mqh` : stops virtuels (visuel + niveaux en mémoire)
- `aurora_simulation.mqh` : simulation “reality check” (tester) : latence/slippage/rejections/spread padding
- `aurora_news_core.mqh` + `aurora_newsfilter.mqh` : news filter (MT5 Economic Calendar)
- `aurora_session_manager.mqh` : sessions (2 fenêtres), jours, close mode, sessions broker, deleverage
- `aurora_weekend_guard.mqh` : protection gap week-end basée sur les sessions broker
- `aurora_pyramiding.mqh` : pyramidage (scaling-in) + trailing groupé (points/ATR)
- `aurora_dashboard.mqh` : dashboard Canvas + rendu + interactions
- `aurora_time.mqh` : helpers temps
- `aurora_logger.mqh` : logging par flags/catégories
- `aurora_error_utils.mqh` : descriptions retcodes/erreurs
- `aurora_types.mqh` : enums + structs (inputs/state/simulation/async)
- `aurora_constants.mqh` : constantes globales

## See also

- Internals : `internals/async-order-manager.md`
- Modèle événementiel : `event-model.md`

