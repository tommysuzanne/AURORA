# Manuel Officiel de Référence - Aurora EA

**Version :** 2.20  
**Dernière mise à jour :** 17 Janvier 2026  
**Format :** Markdown (Convertible PDF)  
**Auteur :** Banks Solutions / Tommy Suzanne

---

## Sommaire

1.  [Philosophie & Architecture](#1-philosophie--architecture)
2.  [Guide d'Installation Standard](#2-guide-dinstallation-standard)
3.  [Anatomie de la Stratégie (Deep Dive)](#3-anatomie-de-la-stratégie-deep-dive)
4.  [Dictionnaire des Paramètres (Inputs)](#4-dictionnaire-des-paramètres-inputs)
    *   [1.1 Indicateurs](#11-indicateurs)
    *   [1.2 Grille](#12-grille)
    *   [1.3 Grille Dynamique](#13-grille-dynamique)
    *   [1.4 Grille Infinie](#14-grille-infinie)
    *   [1.5 Grille Intelligente](#15-grille-intelligente)
    *   [2.1 Gestion du Risque](#21-gestion-du-risque)
    *   [2.2 Gestion du Risque Dynamique](#22-gestion-du-risque-dynamique)
    *   [2.3 Pyramidage](#23-pyramidage)
    *   [2.4 Gestion des Marges](#24-gestion-des-marges)
    *   [3.1 Ouverture & Système](#31-ouverture--système)
    *   [3.2 Gestion des Sessions](#32-gestion-des-sessions)
    *   [3.3 Gestion des Actualités](#33-gestion-des-actualités)
    *   [3.4 Options Supplémentaires](#34-options-supplémentaires)
    *   [3.5 Interface Graphique](#35-interface-graphique)
    *   [3.6 Logs](#36-logs)
5.  [Dashboard Visuel](#5-dashboard-visuel)
6.  [Mécanismes Internes](#6-mécanismes-internes)
7.  [Dépannage & FAQ](#7-dépannage--faq)

---

## 1. Philosophie & Architecture

### Vision
**Aurora EA v2.20** est un automate de trading hybride conçu pour les marchés volatils et tendanciels (Indices comme US30, NAS100). Il répond à une problématique simple : *Comment capturer les grandes tendances tout en survivant aux inévitables retours de marché ?*

La réponse d'Aurora réside dans sa dualité :
1.  **Sniper en Entrée** : Une logique de signal précise (Heiken Ashi + ZLSMA + Chandelier) pour entrer dans le sens du flux.
2.  **Tank en Défense** : Une structure de grille (Grid) sophistiquée, capable de se distordre (Dynamic Grid), de s'alléger (Smart Reduction) et de laisser courir les gains (Infinity Mode).

### Architecture Technique
Contrairement aux EAs classiques "monolithiques", Aurora repose sur une architecture modulaire et asynchrone :
*   **Moteur Événementiel** : Réaction par `OnTick` pour la sécurité critique et `OnTimer` pour la gestion globale.
*   **Pipeline de Gardes** : Filtres stricts avant toute décision (Session, Weekend, News, Spread).
*   **Async Order Manager** : Utilisation de `OrderSendAsync` pour une exécution ultra-rapide ("Fire and Forget") avec gestion automatique des requêtes et erreurs.

---

## 2. Guide d'Installation Standard

### Pré-requis Système
*   **VPS (Virtual Private Server)** : **OBLIGATOIRE** pour une exécution 24/5 sans interruption. Latence < 20ms recommandée.
*   **Terminal** : MetaTrader 5 (Build récent 4000+).
*   **Ressources** : Min 1 vCPU, 2GB RAM.

### Fichiers et Ressources
L'EA est autonome et contient ses propres indicateurs et ressources graphiques.
*   `Aurora.ex5` : Le fichier principal à placer dans `MQL5/Experts/`.
*   **Indicateurs et Images** : Ils sont intégrés dans le fichier `.ex5` via la compilation (`#resource`). Vous n'avez PAS besoin d'installer d'indicateurs tiers manuellement.

### Mise en Route
1.  Ouvrez un graphique **US30** (ou autre indice).
2.  Timeframe recommandé : **M15**.
3.  Glissez `Aurora.ex5` sur le graphique.
4.  Cochez **"Algo Trading"** dans l'onglet Commun et dans la barre d'outils MT5.
5.  Chargez un fichier `.set` (Preset) ou configurez les inputs.
6.  Validez. Le Dashboard "Aurora" devrait apparaître.

---

## 3. Anatomie de la Stratégie (Deep Dive)

### Le Moteur de Signal (Signal Core)
L'entrée est technique, basée sur la **confluence** et validée à la **clôture de la bougie** (No Repainting).
*   **Setup** : `Heiken Ashi` croise `ZLSMA` (Zero Lag SMA).
*   **Filtre** : `Chandelier Exit` confirme la tendance de fond.
*   **Confiance** : Un moteur de "Confidence Score" ajuste dynamiquement le risque selon la qualité du signal (Volatilité, Pente, Efficacité).

### La Défense (Grid & Recovery)
Si le marché va contre nous :
1.  **Grid** : Ajout de positions avec un multiplicateur de volume (`GridVolMult`).
2.  **Smart Reduction** : Utilisation des gains des positions gagnantes pour fermer les positions perdantes les plus anciennes/lourdes ("Grignotage").
3.  **Infinity Mode** : Si le Grid part dans le bon sens, un Trailing Stop agressif sur l'ensemble du panier permet de transformer un rattrapage en gros gain.

---

## 4. Dictionnaire des Paramètres (Inputs)

Cette section recense de manière exhaustive tous les paramètres disponibles dans l'EA.

### 1.1 Indicateurs
Paramètres définissant la sensibilité du signal d'entrée.

*   `CeAtrPeriod` : Période ATR utilisée par l'indicateur Chandelier Exit.
*   `CeAtrMult` : Multiplicateur ATR pour le Chandelier Exit. (Plus élevé = Tendance plus large).
*   `ZlPeriod` : Période de la Zero Lag SMA (Lissage).

### 1.2 Grille
Paramètres fondamentaux de la mécanique de récupération (MartinGale).

*   `Grid` : (`true`/`false`) Activer ou désactiver complètement le système de grille.
*   `GridVolMult` : Multiplicateur de volume exponentiel pour chaque nouvel ordre (ex: 1.5).
*   `GridTrailingStopLevel` : Niveau de trailing stop pour le panier global (en % du profit latent). Mettre 0 pour désactiver.
*   `GridMaxLvl` : Nombre maximum de trades additionnels ("Couches") autorisés dans la grille.

### 1.3 Grille Dynamique
Espacement flexible des ordres basé sur la volatilité.

*   `GridDynamic` : (`true`/`false`) Si activé, la distance entre les ordres varie selon l'ATR. Si désactivé, la distance est fixe/simple.
*   `GridAtrPeriod` : Période de l'ATR utilisé pour calculer l'espacement.
*   `GridAtrMult` : Multiplicateur appliqué à l'ATR pour définir la distance (ex: 1.0 ATR).
*   `GridMaxATR` : Valeur seuil de l'ATR. Si la volatilité dépasse ce niveau, l'ajout de grille est suspendu (Sécurité marché fou).
*   `GridProfitMode` : Méthode de calcul de l'objectif de gain (`CURRENCY` en argent, ou `PIPS` en points).
*   `GridMinProfit` : Montant (ou points) minimal de gain requis pour clôturer le panier de grille.

### 1.4 Grille Infinie
Transforme le Grid en système de suivi de tendance agressif.

*   `Grid_Infinity_Enable` : (`true`/`false`) Activer le mode Infinity.
*   `Grid_Infinity_Trigger` : Pourcentage de l'objectif de profit initial (GridMinProfit) déclenchant le mode Infinity (ex: 90%).
*   `Grid_Infinity_StepMode` : Type de pas pour le trailing (`POINTS` ou `PERCENT`).
*   `Grid_Infinity_TrailingStep` : Valeur du pas de trailing.
*   `Grid_Infinity_AtrPeriod` : Période ATR si le mode est basé sur ATR.
*   `Grid_Infinity_AtrMult` : Multiplicateur ATR si le mode est basé sur ATR.
*   `InpInfinity_TP_Distance` : Distance en points où placer le TP virtuel "infini" (très loin) pour laisser courir le trade.

### 1.5 Grille Intelligente
Réduction active du Drawdown ("Smart Scrubbing").

*   `SmartGrid_Reduction_Enable` : (`true`/`false`) Activer la réduction des pertes par les gains.
*   `SmartGrid_Reduction_StartLvl` : Nombre de niveaux de grille minimum avant de commencer la réduction.
*   `SmartGrid_Reduction_ProfitRatio` : Pourcentage du profit du trade gagnant (dernier entré) utilisé pour fermer les pertes (ex: 90%).
*   `SmartGrid_Reduction_MinVol` : Volume minimum d'un trade pour qu'il soit éligible à la réduction partielle.
*   `SmartGrid_Reduction_WinnerClosePercent` : Pourcentage du trade gagnant à clôturer pour réaliser le profit nécessaire à la réduction (ex: 50%).

### 2.1 Gestion du Risque
Configuration du Money Management pour le premier trade.

*   `RiskMode` : Mode de calcul (`FIXED_LOTS`, `RISK_PERCENT`, `RISK_FIXED_AMOUNT`).
*   `Risk` : Valeur associée au mode (ex: 0.01 pour Lots, 2.0 pour %).
*   `EquityDrawdownLimit` : Pourcentage de drawdown sur l'équité déclenchant la fermeture totale d'urgence (Kill Switch). 0 = Désactivé.
*   `IgnoreSL` : (`true`/`false`) Si true, le SL n'est pas envoyé au broker mais géré virtuellement (furtif).
*   `SLDev` : Distance du Stop Loss en points.
*   `TrailingStop` : (`true`/`false`) Activer le Trailing Stop sur la première position.
*   `TrailMode` : Type de trailing (`STANDARD` points fixes, `ATR` dynamique).
*   `TrailingStopLevel` : Niveau de déclenchement/suivi (% du gain ou points).
*   `TrailAtrPeriod` / `TrailAtrMult` : Paramètres pour le mode ATR.
*   `InpBE_Enable` : (`true`/`false`) Activer la mise à Break-Even (Sécurisation à 0).
*   `InpBE_Mode` : Mode de déclenchement (`RATIO` risque/reward ou `POINTS` fixes).
*   `InpBE_Trigger_Ratio` : Ratio gain/risque pour activer BE (1.0 = à R:1).
*   `InpBE_Trigger_Pts` : Points de gain pour activer BE.
*   `InpBE_Offset_SpreadMult` : Marge ajoutée au BE (Spread * X) pour couvrir les frais.
*   `InpBE_Min_Offset_Pts` : Marge minimale en points ajoutée au BE.
*   `InpBE_OnNewBar` : Appliquer le BE uniquement à la clôture de bougie (moins erratique).

### 2.2 Gestion du Risque Dynamique
Ajustement intelligent de la taille de lot selon la qualité du marché.

*   `DynRisk_Enable` : (`true`/`false`) Activer le risque dynamique.
*   `DynRisk_MinFactor` : Facteur minimal (ex: 0.5 pour réduire le lot de moitié si confiance faible).
*   `DynRisk_MaxFactor` : Facteur maximal (ex: 1.5 pour augmenter le lot de 50% si confiance max).
*   `DynRisk_W_ER` : Poids (%) de l'Efficiency Ratio (Kaufman) dans le calcul.
*   `DynRisk_W_Slope` : Poids (%) de la pente de la ZLSMA.
*   `DynRisk_W_Vol` : Poids (%) de la volatilité.
*   `DynRisk_ER_Period` : Période pour l'Efficiency Ratio.
*   `DynRisk_Slope_Period` : Période pour le calcul de pente.

### 2.3 Pyramidage
Ajout de positions en tendance favorable (Scaling In).

*   `TrendScale_Enable` : (`true`/`false`) Activer le pyramidage.
*   `TrendScale_MaxLayers` : Nombre maximum de positions ajoutées en positif.
*   `TrendScale_StepPts` : Distance en points requise pour ouvrir la couche suivante.
*   `TrendScale_VolMult` : Multiplicateur de volume pour les ajouts (ex: 1.0 = même taille).
*   `TrendScale_MinConf` : Score de confiance minimum (0.0-1.0) requis pour autoriser un ajout.
*   `TrendScale_TrailSync` : (`true`/`false`) Synchroniser les SL de toutes les positions ensemble.
*   `TrendScale_TrailMode` : Mode de calcul du trailing (`POINTS` ou `ATR`).
*   `TrendScale_TrailDist_2` : Distance du trailing quand 2 couches sont ouvertes.
*   `TrendScale_TrailDist_3` : Distance du trailing quand 3+ couches sont ouvertes.
*   `TrendScale_ATR_Period` / `Mult_2` / `Mult_3` : Paramètres ATR correspondants.

### 2.4 Gestion des Marges
Protections critiques pour éviter l'appel de marge.

*   `MarginLimit` : Niveau de marge (%) en dessous duquel l'EA refuse d'ouvrir de NOUVEAUX cycles.
*   `MarginGuard_Enable` : (`true`/`false`) Activer les mécanismes de garde actifs.
*   `MarginGuard_Stretch_Level` : Niveau de marge (%) déclenchant l'écartement des niveaux de grille.
*   `MarginGuard_Stretch_MaxMult` : Facteur d'écartement max (ex: x5 la distance habituelle).
*   `MarginGuard_Delev_Level` : Niveau de marge CRITIQUE (%) déclenchant la fermeture forcée (Deleverage).
*   `MarginGuard_Delev_Worst` : Si `true`, ferme le pire trade ; si `false`, le plus ancien.
*   `MarginGuard_Damping_Enable` : (`true`/`false`) Réduire le volume des prochains ordres si marge faible.
*   `MarginGuard_Damping_Start` : Niveau de marge pour commencer le Damping.
*   `MarginGuard_Damping_MinMult` : Facteur de réduction max (ex: 0.8).
*   `InpMarginGuard_Damping_Floor` : Plancher absolu de marge pour le Damping.

### 3.1 Ouverture & Système
Paramètres système généraux.

*   `InpOpen_Side` : Direction autorisée (`ACHATS`, `VENTES`, `LES_DEUX`).
*   `InpMaxTotalLots` : Volume total cumulé maximum autorisé sur le compte (-1 pour illimité).
*   `SpreadLimit` : Spread maximum en points pour ouvrir un trade.
*   `Slippage` : Tolérance de glissement en points.
*   `SignalMaxGapPts` : Filtre anti-gap. Si le prix est > X points du signal, annuler l'entrée.
*   `TimerInterval` : Fréquence de la boucle de gestion (secondes). 1 est recommandé.

### 3.2 Gestion des Sessions
Contrôle fin des horaires de trading.

*   `InpSess_EnableTime` : (`true`/`false`) Activer le filtre horaire quotidien.
*   `InpSess_StartHour` / `StartMin` : Heure de début d'autorisation.
*   `InpSess_EndHour` / `EndMin` : Heure de fin d'autorisation.
*   `InpSess_CloseMode` : Comportement hors horaires (`OFF`=rien, `FORCE_CLOSE`=fermer tout, `RECOVERY`=gérer l'existant sans nouveau cycle, `SMART_EXIT`, `DELEVERAGE`).
*   `InpSess_DelevTargetPct` : Cible de réduction en mode Deleverage (%).
*   `InpSess_TradeMon` ... `InpSess_TradeSun` : Autorisation jour par jour (Lundi...Dimanche).
*   `InpSess_CloseRestricted` : Appliquer la fermeture (CloseMode) aux jours désactivés.
*   `InpSess_RespectBrokerSessions` : Synchroniser avec les horaires réels du marché (cotation).
*   `InpWeekend_Enable` : (`true`/`false`) Activation du filtre spécial Week-End (Vendredi soir).
*   `InpWeekend_BufferMin` : Minutes avant la clôture marché pour activer la sécurité.
*   `InpWeekend_GapMinHours` : Détection automatique des trous de cotation (week-end).
*   `InpWeekend_BlockNewBeforeMin` : Minutes avant la fermeture où l'on interdit les nouvelles entrées.
*   `InpWeekend_ClosePendings` : Supprimer les ordres en attente (Stop/Limit) avant le week-end.

### 3.3 Gestion des Actualités
Filtre fondamental (News Trading).

*   `InpNews_Enable` : Activer le filtre.
*   `InpNews_Levels` : Niveaux d'impact à surveiller (ex: `HIGH_ONLY`, `HIGH_MEDIUM`).
*   `InpNews_Ccy` : Devises à surveiller (ex: `USD,EUR`). Laisser vide pour auto-détection.
*   `InpNews_BlackoutB` : Minutes de pause AVANT la news.
*   `InpNews_BlackoutA` : Minutes de pause APRÈS la news.
*   `InpNews_MinCoreHighMin` : Durée minimale du noyau de haute volatilité.
*   `InpNews_Action` : Action à entreprendre (`MONITOR_ONLY`, `BLOCK_ENTRY`, `BLOCK_ALL`, `CLOSE_ALL`).
*   `InpNews_RefreshMin` : Fréquence de mise à jour du calendrier (minutes).

### 3.4 Options Supplémentaires
Paramètres divers.

*   `MagicNumber` : Identifiant unique de l'EA pour distinguer ses ordres.
*   `OpenNewPos` : Interrupteur général (Master Switch). Si `false`, aucune nouvelle position (cycle) n'est prise.
*   `Filling` : Mode d'exécution (`DEFAULT`, `FOK`, `IOC`).
*   `CloseOrders` : Si `true`, ferme les positions si le signal s'inverse (ex: Achat -> Signal Vente).
*   `InpClose_ConfirmBars` : Nombre de barres de confirmation pour l'inversion.
*   `InpGrid_SuspendOnInverse` : Si `true`, empêche le Grid d'ajouter des ordres si le signal de fond est inversé.
*   `Reverse` : Si `true`, inverse toute la logique (Acheter sur signal Vente).
*   `MultipleOpenPos` : Autoriser plusieurs "Cycles" (premiers trades) en parallèle.
*   `InpVirtualBalance` : Montant en devise simulé pour les calculs de risque (ex: mettre 10000 sur un compte à 1000).

### 3.5 Interface Graphique
Configuration du Dashboard sur le graphique.

*   `InpDash_Enable` : Afficher le dashboard.
*   `InpDash_NewsRows` : Nombre de lignes d'actualités à afficher.
*   `InpDash_Scale` : Facteur de zoom manuel (%). Mettre 0 pour laisser l'EA détecter (Auto-DPI).
*   `InpDash_Corner` : Coin d'ancrage (`LEFT_UPPER`, `RIGHT_UPPER`, etc.).

### 3.6 Logs
Configuration du niveau de détail dans l'onglet "Experts" (Débogage).

*   `InpLog_General` : Messages d'initialisation et erreurs système.
*   `InpLog_Position` : Suivi des ouvertures/fermetures de positions.
*   `InpLog_Risk` : Calculs de lots, marges et drawdowns.
*   `InpLog_Session` : Événements liés aux horaires/sessions.
*   `InpLog_News` : Détails du filtre de news (événements trouvés, blackout).
*   `InpLog_Strategy` : Raisons détaillées des prises de décision (Signal valide ou refusé).
*   `InpLog_Orders` : Retours techniques du serveur (Retcodes, slippage).
*   `InpLog_Diagnostic` : Données brutes internes (Buffers indicateurs).
*   `InpLog_Dashboard` : Debugging de l'affichage graphique.

---

## 5. Dashboard Visuel

Avec la version 2.20, Aurora arbore un **Dashboard Premium** "Platinum".

### Fonctionnalités
*   **Aperçu Rapide** : Profit Total, Profit Latent, Drawdown (Actuel, Max Jour, Max Historique).
*   **Monitoring** : Levier réel, Spread instantané, Heure Broker.
*   **Module News** : Affiche les prochaines annonces économiques directement sur le graphique.
    *   *Point Rouge* : Impact Fort.
    *   *Point Orange* : Impact Moyen.
    *   *Point Jaune* : Impact Faible.

### Dépannage Graphique
*   **Texte trop petit/grand ?** : Utilisez `InpDash_Scale`. Sur des écrans 4K, essayez `150` ou `200`. Si `0`, l'EA tente de deviner selon le DPI système.

---

## 6. Mécanismes Internes

### Async Order Manager
Aurora n'utilise pas `OrderSend` (bloquant) mais `OrderSendAsync`.
*   **Pourquoi ?** Sur des mouvements de news violents, attendre 200ms la réponse d'un broker est inacceptable. L'EA tire et oublie ("Fire and Forget").
*   **Fiabilisation** : Une classe dédiée surveille les transactions. Si un ordre échoue (ex: `Requote`), il est rejoué automatiquement.

### State Persistence
L'EA sauvegarde l'état de ses objets sur le disque. En cas de redémarrage du VPS ou du terminal, il reprend exactement où il en était.

---

## 7. Dépannage & FAQ

| Symptôme | Cause Possible | Solution |
| :--- | :--- | :--- |
| **Le Dashboard ne s'affiche pas** | `InpDash_Enable` est false. | Cochez `true`. Vérifiez que les objets graphiques sont activés dans MT5. |
| **Erreur "Market Closed"** | Hors session ou Weekend. | Vérifiez `Session Management` et l'heure du broker (Market Watch). |
| **Pas de trade** | Filtres trop stricts. | Vérifiez les logs avec `InpLog_Strategy = true`. |
| **Grille bloquée** | `GridMaxLvl` atteint ou inversion. | Sécurité `InpGrid_SuspendOnInverse` active. |

---
**Disclaimer** : Le trading comporte des risques. Aurora est un outil puissant mais nécessite une surveillance et une configuration adaptée à votre capital.

*Copyright 2026, Tommy Suzanne*
