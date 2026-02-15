# Aurora EA (MetaTrader 5 / MQL5)

[![Version](https://img.shields.io/badge/version-3.44-blue.svg)](https://github.com/tommysuzanne)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205-green.svg)](https://www.metatrader5.com)
[![License](https://img.shields.io/badge/license-Proprietary-lightgrey.svg)](#license)

Code version: `3.44` (source-of-truth: `MQL5/Experts/Aurora.mq5`, `AURORA_VERSION`).

Aurora is an event-driven **MetaTrader 5 Expert Advisor (MQL5)** built around:
- **Dual core**: SuperTrend (ZLSMA + Chandelier Exit) or Momentum (Keltner‑KAMA)
- **Dual execution**: Reactive (Market/Limit/Stop) or Predictive (managed pending orders)
- **Guards pipeline**: Sessions, Weekend gap protection, News (MT5 Economic Calendar), spread/market regime filters
- **Async execution**: `OrderSendAsync` + `OnTradeTransaction` retries + persistence
- **Backtest realism**: optional simulation layer (latency / slippage / rejections / spread padding)

Quick links:
- Technical documentation (index): `DOCS/index.md`
- Legacy monolith (stub): `DOCS/Aurora_Documentation.md`
- Entry point: `MQL5/Experts/Aurora.mq5`

---

## English

### Features
- Predictive order management with configurable offset (points or ATR) and update threshold
- Regime/stress filters (Hurst, VWAP deviation, Kurtosis, Trap Candle, Spike Guard, price smoothing)
- Risk controls (equity drawdown kill-switch, max trades/day, max lot limits, spread/slippage guards)
- Break-even (ratio/points/ATR), trailing (standard/points/ATR), optional “exit on close” with virtual stops
- Dashboard (Canvas) + upcoming news feed

### Installation (from source)
Aurora embeds indicators via `#resource` (compiled `.ex5`). If the `.ex5` files do not exist yet, compile indicators first.

1) Copy the `MQL5/` folder into your MetaTrader 5 Data Folder (`File → Open Data Folder`).
2) In MetaEditor, compile indicators in `MQL5/Indicators/Aurora/` (this creates `.ex5` files).
3) Compile the EA: `MQL5/Experts/Aurora.mq5`.
4) In MT5, attach `Aurora` to a chart and enable **Algo Trading**.

### Configuration
All inputs and the “input contract” are documented in `DOCS/index.md` (see `DOCS/inputs/index.md`).

Notes:
- The `.set` presets in `MQL5/Presets/` may target older versions; validate inputs against the current code version (`AURORA_VERSION` in `MQL5/Experts/Aurora.mq5`) before using them live.

### Backtesting
Aurora includes an optional “reality check” simulation for Strategy Tester:
- `InpSim_*` inputs allow you to simulate latency, slippage, rejections, spread padding, and commission.

### Project structure
```
MQL5/
├── Experts/
│   └── Aurora.mq5
├── Include/
│   └── Aurora/
│       ├── aurora_async_manager.mqh
│       ├── aurora_constants.mqh
│       ├── aurora_dashboard.mqh
│       ├── aurora_engine.mqh
│       ├── aurora_error_utils.mqh
│       ├── aurora_guard_pipeline.mqh
│       ├── aurora_logger.mqh
│       ├── aurora_news_core.mqh
│       ├── aurora_newsfilter.mqh
│       ├── aurora_pyramiding.mqh
│       ├── aurora_session_manager.mqh
│       ├── aurora_simulation.mqh
│       ├── aurora_snapshot.mqh
│       ├── aurora_state_manager.mqh
│       ├── aurora_time.mqh
│       ├── aurora_types.mqh
│       ├── aurora_virtual_stops.mqh
│       └── aurora_weekend_guard.mqh
├── Indicators/
│   └── Aurora/
│       ├── ATR_HeikenAshi.mq5
│       ├── AuKeltnerKama.mq5
│       ├── ChandelierExit.mq5
│       ├── Heiken_Ashi.mq5
│       ├── Hurst.mq5
│       ├── Kurtosis.mq5
│       ├── TrapCandle.mq5
│       ├── VWAP.mq5
│       └── ZLSMA.mq5
├── Presets/
│   ├── AURORA V2.21 LOW RISK.set
│   └── AURORA V2.21 MID RISK.set
├── Scripts/
│   └── Aurora_Temporal_EdgeTests.mq5
└── Images/
    ├── Aurora_Icon.bmp
    ├── Aurora_Icon.ico
    └── Aurora_Icon.png
```

---

## Français

### Fonctionnalités
- Gestion **prédictive** des ordres en attente (offset points/ATR + seuil de mise à jour)
- Filtres de régime/stress (Hurst, VWAP, Kurtosis, Trap Candle, Spike Guard, lissage prix)
- Contrôles de risque (kill‑switch drawdown equity, limite trades/jour, limites lots, spread/slippage)
- Break‑Even (ratio/points/ATR), trailing (standard/points/ATR), option “sortie sur clôture” via stops virtuels
- Dashboard Canvas + news à venir via le **calendrier économique MT5**

### Installation (depuis les sources)
Aurora embarque des indicateurs via `#resource` (fichiers `.ex5`). Si les `.ex5` n’existent pas encore, compilez d’abord les indicateurs.

1) Copiez le dossier `MQL5/` dans le répertoire de données MT5 (`Fichier → Ouvrir le dossier de données`).
2) Dans MetaEditor, compilez les indicateurs dans `MQL5/Indicators/Aurora/` (création des `.ex5`).
3) Compilez l’EA : `MQL5/Experts/Aurora.mq5`.
4) Dans MT5, attachez `Aurora` à un graphique et activez **Algo Trading**.

### Configuration
La documentation technique complète (inputs + dépendances + “contrat d’inputs”) est dans `DOCS/index.md` (voir `DOCS/inputs/index.md`).

Notes :
- Les presets `.set` dans `MQL5/Presets/` peuvent cibler des versions plus anciennes ; vérifiez les inputs par rapport à la version du code (`AURORA_VERSION` dans `MQL5/Experts/Aurora.mq5`) avant usage live.

---

## Disclaimer
Trading carries significant risk. This repository is provided for educational/testing purposes; no performance guarantees.

## License
Proprietary. All rights reserved.
