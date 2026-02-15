# Installation & compilation (depuis le repo)

## Objectif

Compiler les indicateurs requis puis compiler l’EA `Aurora`.

## Sources

- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (sections “Installation & compilation”, “Dépannage”)
- Code : `MQL5/Experts/Aurora.mq5` (références `#resource` vers des `.ex5`)

## Prérequis

- MetaTrader 5 + MetaEditor.
- TODO(verify): version minimale MT5 “build” requise — Comment obtenir: ouvrir MT5 → *Help/About* puis tenter une compilation dans MetaEditor.

## Point critique : indicateurs embarqués en `.ex5`

Aurora référence des indicateurs via `#resource` en **`.ex5`** (pas en `.mq5`).
Conséquence : si les `.ex5` n’existent pas, la compilation de l’EA échoue.

## Procédure standard

1. Copier le dossier `MQL5/` dans le dossier de données MT5 (`File → Open Data Folder`).
2. Dans MetaEditor, compiler les indicateurs dans `MQL5/Indicators/Aurora/` (cela génère les `.ex5`).
3. Compiler l’EA : `MQL5/Experts/Aurora.mq5`.
4. Dans MT5, attacher `Aurora` à un graphique et activer **Algo Trading**.

## Presets `.set`

Le dossier `MQL5/Presets/` contient des presets historiques : ils peuvent cibler des versions antérieures.

## Dépannage rapide

- Erreur `#resource ... .ex5` : compiler d’abord les indicateurs `MQL5/Indicators/Aurora/*`, puis recompiler `MQL5/Experts/Aurora.mq5`.

## See also

- Ressources embarquées : `../architecture/resources.md`
- FAQ : `../troubleshooting/faq.md`

## Last verified
Last verified: 2026-02-15 — Méthode: lecture statique + comparaison avec `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

