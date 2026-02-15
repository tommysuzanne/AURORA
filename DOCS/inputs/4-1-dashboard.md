# Inputs — 4.1 Dashboard

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "4.1 - Dashboard"
input bool                      InpDash_Enable              = false;                    // Activer le Dashboard
input int                       InpDash_NewsRows            = 5;                        // Nombre de lignes de News à afficher
input int                       InpDash_Scale               = 0;                        // Echelle % (0 = Auto DPI)
input ENUM_BASE_CORNER          InpDash_Corner              = CORNER_LEFT_UPPER;        // Coin d'ancrage du dashboard
```

## See also

- Debugging : `../workflows/debugging.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

