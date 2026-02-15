# Modèle événementiel (OnInit / OnTick / OnTimer / OnTradeTransaction)

## Objectif

Décrire les responsabilités de chaque événement et le flux principal.

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (`OnInit`, `OnTick`, `OnTimer`, `OnTradeTransaction`)
- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (section “Modèle événementiel”)

## Schéma fonctionnel (vue d’ensemble)

```mermaid
flowchart TD
  A["OnInit()"] --> B["Input Contract (validation)"]
  B --> C["Init indicateurs (iCustom handles)"]
  C --> D["Configure modules (session/weekend/news/pyra/sim/async)"]
  D --> E["EventSetTimer(TimerInterval)"]
  E --> F["Dashboard init (optionnel)"]

  G["OnTick()"] --> H["Simulation tick (tester only)"]
  H --> I["Snapshot positions (once per tick)"]
  I --> J["Elastic factor / equity check"]
  J --> K["Guards tick (session/weekend/news)"]
  K --> L{"allowManage?"}
  L -->|yes| M["BE / Trailing / Virtual exits"]
  L -->|no| N["Skip management"]
  M --> O["Regime filters => allowEntry gate"]
  O --> P["Pyramiding (if enabled)"]
  P --> Q{"New bar?"}
  Q -->|yes| R["Update buffers/cache + Reactive entries"]
  Q -->|no| S["Skip reactive entry"]
  R --> T["Predictive order mgmt (every tick if enabled & ready)"]
  S --> T

  U["OnTimer()"] --> V["Guards timer (close soon / session close / news refresh)"]
  V --> W["Async manager flush/persist"]
  W --> X["Expire pending orders (soft expiry)"]
  X --> Y["Dashboard state update"]

  Z["OnTradeTransaction()"] --> AA["Async manager (retry/drop)"]
  Z --> AB["Update stats/history/snapshot commissions"]
```

## Rôles (résumé)

- `OnInit` : valide inputs, init indicateurs, configure modules, démarre timer, init dashboard.
- `OnTick` : chemin critique (snapshot, guards, management sorties), décision entrée, reactive (new bar) + predictive (continu).
- `OnTimer` : refresh news, guards time-based, flush/persist async, nettoyage pendings, dashboard update.
- `OnTradeTransaction` : feedback asynchrone, retries, mise à jour stats/snapshot.

## See also

- Contrat d’inputs : `../inputs/input-contract.md`
- Async manager : `internals/async-order-manager.md`

## Last verified
Last verified: 2026-02-15 — Méthode: lecture statique + comparaison avec `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

