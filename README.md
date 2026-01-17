# Aurora MQL5 Expert Advisor

[![Version](https://img.shields.io/badge/version-2.20-blue.svg)](https://github.com/tommysuzanne)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205-green.svg)](https://www.metatrader5.com)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)

**Aurora** est un Expert Advisor (EA) sophistiqué pour MetaTrader 5 qui utilise une stratégie technique avancée basée sur les indicateurs Chandelier Exit, ZLSMA et Heikin Ashi. Cette version 2.20 introduit un **Dashboard Professionnel** interactif, une gestion de risque dynamique et une logique de grille intelligente ("Smart Grid") pour maximiser la sécurité et la performance.

## 📊 Vue d'ensemble

Aurora combine une analyse technique multi-indicateurs avec une gestion de position algorithmique avancée :

- **Chandelier Exit** : Détermine la tendance et les niveaux de stop dynamiques
- **ZLSMA (Zero Lag SMA)** : Filtre de tendance ultra-rapide
- **Heikin Ashi** : Lissage de l'action des prix
- **Dashboard Interactif** : Surveillance en temps réel des performances et événements

## ✨ Nouvelles Fonctionnalités v2.20

### 🖥️ Dashboard Pro
- **Interface Graphique Complète** : Visualisation claire sur le graphique.
- **Monitoring Temps Réel** : Profit Total, Profit Actuel, Drawdown (Actuel, Journalier, Historique), Levier, Spread.
- **Persistance des Données** : Le "Profit Total" et le "Max DD (Hist)" sont sauvegardés et restaurés automatiquement, même après un redémarrage du VPS ou de MT5.
- **Intégration News** : Affichage des prochaines annonces économiques directement sur le dashboard.
- **Design Premium** : Thème "Platinum" épuré, support DPI automatique (écrans 4K/Rétina).

### 🧠 Smart Grid & Protection
- **Smart Grid Reduction** : Algorithme actif qui réduit le drawdown en fermant partiellement les positions perdantes grâce aux profits des positions gagnantes.
- **Margin Guard** : Protection anti-appel de marge avec mécanismes de "Stretch" (écartement de la grille) et "Damping" (réduction de volume) en cas de tension critique.
- **Deleverage d'Urgence** : Coupe les positions les plus risquées si la marge atteint un niveau critique.

### 🔺 Pyramidage Avancé
- **Système de Renfort** : Ajout de positions gagnantes pour maximiser les tendances fortes.
- **Trailing Stop ATR** : Stop suiveur adaptatif basé sur la volatilité pour sécuriser les gains du groupe pyra.

## 🚀 Fonctionnalités Principales

### 🎯 Stratégie de Trading
- Signaux basés sur l'alignement HA/ZLSMA avec validation Chandelier Exit
- Système de clôture sur signal inverse configurable
- Support Long/Short/Bi-directionnel

### 📈 Gestion du Risque
- **Risque Dynamique** : Ajustement automatique du lot selon la confiance du signal (Volatilité, Pente ZLSMA, Efficacité Kaufman).
- **Modes de Risque** : % Balance, % Equity, Lot Fixe, Risque Fixe (Argent).
- **Trailing Stop** : Standard ou ATR.
- **Break-Even** : Sécurisation rapide (Ratio ou Points).
- **Hard Limits** : DD Max Equity, DD Max Journalier (type FTMO).

### 📰 Filtre de News
- **Calendrier Intégré** : Téléchargement automatique des news ForexFactory.
- **Filtrage Intelligent** : Blocage des entrées avant/après les news à fort impact.
- **Mode Monitor Only** : Possibilité d'afficher les news sur le dashboard sans impacter le trading.

### 📅 Gestion Temporelle
- **Planificateur Hebdomadaire** : Contrôle jour par jour.
- **Protection Weekend** : Fermeture forcée ou blocage des entrées avant le vendredi soir (Gap protection).

## ⚙️ Configuration Rapide

### Installation
1. Copiez le dossier `MQL5` dans votre répertoire de données MetaTrader 5.
2. Compilez `Experts/Aurora.mq5`.
3. Activez "Autoriser l'importation DLL" si nécessaire (bien que non requis pour le noyau principal). [Optionnel]

### Paramètres Clés (Inputs)
```mq5
// --- Dashboard ---
InpDash_Enable = true       // Activer le Dashboard
InpDash_Scale = 0           // 0 = Auto-détection taille écran

// --- Risque ---
Risk = 1.0                  // Risque par trade (%)
Grid = true                 // Activer la récupération par grille
GridDynamic = true          // Grille adaptative (ATR)

// --- Protection ---
EquityDrawdownLimit = 10.0  // Global Panic Close à 10% DD
SmartGrid_Reduction_Enable = true // Activer la réduction active du DD
```
Voir la documentation pour plus de détails sur les paramètres.

## 🏗️ Structure du Projet

```
MQL5/
├── Experts/
│   └── Aurora.mq5                     # Expert Advisor principal (Point d'entrée, OnInit/OnTick)
│
├── Include/
│   ├── aurora_engine.mqh              # Cœur de la stratégie (Signaux, HA, ZLSMA, Chandelier)
│   ├── aurora_dashboard.mqh           # Moteur graphique et affichage du Dashboard
│   ├── aurora_risk.mqh                # Gestionnaire de risque (Lot size, Equity check)
│   ├── aurora_grid.mqh                # Logique de grille et Smart Grid
│   ├── aurora_pyramiding.mqh          # Module de pyramidage (Trend Scale)
│   ├── aurora_newsfilter.mqh          # Façade de gestion des news
│   ├── aurora_news_core.mqh           # Parser et téléchargeur de calendrier économique
│   ├── aurora_weekend_guard.mqh       # Protection de fin de semaine (Gap protection)
│   ├── aurora_session_manager.mqh     # Gestion des horaires et jours de trading
│   ├── aurora_confidence_engine.mqh   # Moteur de confiance (Calcul dynamique du risque)
│   ├── aurora_guard_pipeline.mqh      # Pipeline de sécurité unifié (Checks avant trade)
│   ├── aurora_async_manager.mqh       # Gestionnaire des ordres asynchrones
│   ├── aurora_async_structs.mqh       # Structures pour l'asynchrone
│   ├── aurora_state_manager.mqh       # Gestion de l'état (Sauvegarde/Restauration)
│   ├── aurora_state_structs.mqh       # Structures de données d'état (Dashboard, etc.)
│   ├── aurora_inputs_structs.mqh      # Structures de regroupement des paramètres (Inputs)
│   ├── aurora_error_utils.mqh         # Utilitaires de gestion d'erreurs et retcodes
│   ├── aurora_logger.mqh              # Système de logging centralisé
│   ├── aurora_time_helper.mqh         # Utilitaires de gestion du temps (GMT, DST)
│   └── aurora_constants.mqh           # Constantes globales et énumérations
│
├── Indicators/
│   ├── ATR_HeikenAshi.mq5         # ATR spécifique lissé avec Heikin Ashi
│   ├── ChandelierExit.mq5         # Indicateur de volatilité et tendance (Stop Loss)
│   ├── ZLSMA.mq5                  # Zero Lag Simple Moving Average (Filtre de tendance)
│   └── Examples/
│       └── Heiken_Ashi.mq5        # Heikin Ashi standard (Utilisé comme ressource)
│
└── Images/
    ├── Aurora_Icon.bmp                # Logo bitmap pour utilisation interne (Resource)
    └── Aurora_Icon.ico                # Icône de l'exécutable
```

## ⚠️ Avertissement

Le trading sur le Forex/CFD comporte un niveau de risque élevé et peut ne pas convenir à tous les investisseurs. Les performances passées (backtests) ne préjugent pas des résultats futurs.
Utilisez toujours un **Stop Loss** et ne risquez jamais plus que ce que vous pouvez vous permettre de perdre.

---

**Développé par [Tommy Suzanne](https://github.com/tommysuzanne)**
*Version 2.20 - Gold Edition*
