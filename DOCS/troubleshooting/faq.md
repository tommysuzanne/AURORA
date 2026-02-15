# Dépannage / FAQ

## L’EA ne compile pas : erreur sur `#resource ... .ex5`

Cause : les indicateurs `.ex5` n’existent pas.  
Solution : compiler d’abord les indicateurs dans `MQL5/Indicators/Aurora/`, puis recompiler `MQL5/Experts/Aurora.mq5`.

## Le filtre news ne bloque rien

Vérifier :
- `InpNews_Enable=true`
- `InpNews_Levels` (pas `NONE`)
- devises `InpNews_Ccy` (ou vide pour auto)
- `InpNews_Action` (si `MONITOR_ONLY`, aucune action de blocage)

Note : le filtre news utilise le calendrier économique MT5. Si l’API est indisponible, le comportement est “fallback neutre”.

## Le dashboard n’apparaît pas

Vérifier :
- `InpDash_Enable=true`
- “Algo Trading” activé
- compatibilité Canvas (MT5 récent)
- `InpDash_Scale` (0 = auto)

## L’EA refuse de s’initialiser

Cause : violation du “input contract”.  
Solution : consulter l’onglet **Experts** (logs `[INPUT-CONTRACT]`) et corriger les inputs.

## See also

- Installation / compilation : `../getting-started/install-compile.md`
- Input contract : `../inputs/input-contract.md`

