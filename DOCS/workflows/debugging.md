# Logs & diagnostic (debugging)

## Objectif

Diagnostiquer les problèmes fréquents (init refusée, news, dashboard, compilation `#resource`).

## Sources

- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (sections “Logs & diagnostic”, FAQ)
- Code : `MQL5/Include/Aurora/aurora_logger.mqh`, `MQL5/Experts/Aurora.mq5`

## Catégories de logs

Le logging est contrôlé via les inputs `InpLog_*` (voir `../inputs/4-2-logs.md`).

Recommandations (doc source) :
- Live : activer `General`, `Risk`, `Session`, `News` uniquement si besoin.
- Debug : activer `Diagnostic` + `Orders` temporairement.
- Tester : activer `Simulation` pour analyser la couche “reality check”.

## Symptômes → où regarder

- “EA refuse de s’initialiser” : onglet Experts, logs `[INPUT-CONTRACT]`.
- “Erreur `#resource ... .ex5`” : compiler d’abord les indicateurs `MQL5/Indicators/Aurora/*`.
- “Le filtre news ne bloque rien” : vérifier `InpNews_Enable`, `InpNews_Levels`, `InpNews_Ccy`, `InpNews_Action`.
- “Le dashboard n’apparaît pas” : vérifier `InpDash_Enable=true`, compatibilité Canvas, `InpDash_Scale`.

## See also

- Input contract : `../inputs/input-contract.md`
- FAQ : `../troubleshooting/faq.md`

