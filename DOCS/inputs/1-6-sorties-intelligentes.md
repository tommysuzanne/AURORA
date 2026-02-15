# Inputs — 1.6 Sorties intelligentes

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "1.6 - Sorties Intelligentes"
input bool                      InpElastic_Enable           = false;                    // Activer Modèle Élastique (Hybrid VR + Noise)
input bool                      InpElastic_Apply_SL         = true;                     // Appliquer au Stop Loss Initial
input bool                      InpElastic_Apply_Trail      = true;                     // Appliquer au Trailing Stop (Distance & Step)
input bool                      InpElastic_Apply_BE         = false;                    // Appliquer au Break-Even (Trigger)
input int                       InpElastic_ATR_Short        = 5;                        // Période ATR Court (Choc)
input int                       InpElastic_ATR_Long         = 100;                      // Période ATR Long (Mémoire)
input double                    InpElastic_Max_Scale        = 2.0;                      // Facteur d'expansion Maximum
```

## See also

- Sorties (concepts) : `../strategies/exits.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

