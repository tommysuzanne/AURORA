# Internal — Async order manager

## Objectif

Documenter le rôle du manager asynchrone (`OrderSendAsync`) et ses invariants observables (sans formules propriétaires).

## Source-of-truth

- `MQL5/Include/Aurora/aurora_async_manager.mqh`
- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (section “Async Order Manager”)

## Principes (résumé)

- Envoi via `OrderSendAsync` (non-bloquant), traitement dans `OnTradeTransaction`.
- Déduplication : évite d’empiler des requêtes identiques “in flight”.
- Retry policy : retries limités, abandon sur erreurs fatales.
- Persistence live : persistance des requêtes “en vol” via `FILE_COMMON` (via `aurora_state_manager.mqh`).

## Schéma

```mermaid
sequenceDiagram
  participant EA as "Aurora EA"
  participant AM as "AsyncManager"
  participant TS as "Trade Server"
  participant TM as "OnTradeTransaction"

  EA->>AM: SendAsync(request)
  AM->>TS: OrderSendAsync
  TS-->>TM: TradeTransaction (result + request_id)
  TM->>AM: OnTradeTransaction(trans, request, result)
  alt retcode OK
    AM-->>AM: Remove from pending
  else retcode retryable
    AM-->>AM: Rebuild request, retry++ (new request_id)
    AM->>TS: OrderSendAsync (resend)
  else fatal / IOC strict invalid price
    AM-->>AM: Drop request (log)
  end
```

## See also

- Modèle événementiel : `../event-model.md`

