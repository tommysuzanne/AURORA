# DOCS — Aurora (source-of-truth)

Cette arborescence `DOCS/` est la **documentation “système d’enregistrement”** du repo.

- Règle : `DOCS/` contient la vérité maintenable (docs atomiques + index + liens croisés).
- Règle : `.codex/AGENTS.md` est une **carte** (table des matières), pas une encyclopédie.
- Règle : **ne pas deviner**. Si une info manque : `TODO(verify): ... — Comment obtenir: ...`.

> Legacy : l’ancien monolithe est conservé dans `DOCS/legacy/Aurora_Documentation.md`.

## Start here (agent)

- Installer / compiler : [`getting-started/install-compile.md`](getting-started/install-compile.md)
- Lancer en live (opérationnel) : [`getting-started/run-live.md`](getting-started/run-live.md)
- Backtest / simulation : [`workflows/backtesting.md`](workflows/backtesting.md)
- Debug / logs / diagnostic : [`workflows/debugging.md`](workflows/debugging.md)
- Contrat d’inputs (refus d’init) : [`inputs/input-contract.md`](inputs/input-contract.md)

## Où trouver quoi

- Architecture & modules : [`architecture/index.md`](architecture/index.md)
- Stratégies & exécution (reactive/predictive) : [`strategies/index.md`](strategies/index.md)
- Inputs (liste + defaults + descriptions) : [`inputs/index.md`](inputs/index.md)
- Dépannage / FAQ : [`troubleshooting/index.md`](troubleshooting/index.md)
- Références (enums, glossaire) : [`reference/index.md`](reference/index.md)

## Où est la vérité (source-of-truth)

- Inputs + validation (input contract) : `MQL5/Experts/Aurora.mq5`
- Types / enums : `MQL5/Include/Aurora/aurora_types.mqh`
- Modules (runtime) : `MQL5/Include/Aurora/*`
- Indicateurs internes : `MQL5/Indicators/Aurora/*`

## Contribuer à la doc (mécanique)

1. Lire `style-guide.md`.
2. Appliquer le DoD : `maintenance/doc-dod.md`.
3. En cas de doute : créer un `TODO(verify)` et expliquer “comment obtenir l’info”.

## Maintenance

- DoD doc : `maintenance/doc-dod.md`
- Doc gardening : `maintenance/doc-gardening.md`
