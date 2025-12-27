# Aurora MQL5 Expert Advisor

[![Version](https://img.shields.io/badge/version-1.73-blue.svg)](https://github.com/tommysuzanne)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205-green.svg)](https://www.metatrader5.com)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)

**Aurora** est un Expert Advisor (EA) sophistiqué pour MetaTrader 5 qui utilise une stratégie technique avancée basée sur les indicateurs Chandelier Exit, ZLSMA et Heikin Ashi. Conçu pour le trading automatique avec une gestion du risque complète et une compatibilité totale avec les règles FTMO.

## 📊 Vue d'ensemble

Aurora combine plusieurs indicateurs techniques pour générer des signaux d'achat et de vente fiables :

- **Chandelier Exit** : Définit dynamiquement les niveaux de stop-loss
- **ZLSMA (Zero Lag SMA)** : Filtre de tendance principal
- **Heikin Ashi** : Lissage des prix pour réduire le bruit du marché

## ✨ Fonctionnalités principales

### 🎯 Stratégie de trading
- Signaux basés sur l'alignement HA/ZLSMA avec protection Chandelier Exit
- Système de clôture sur signal inverse configurable
- Support des positions longues, courtes ou les deux
- Inversion des signaux possible

### 📈 Gestion du risque
- **5 modes de risque** : Pourcentage du solde, volume fixe, % equity, etc.
- **Trailing Stop** automatique configurable
- **Break-Even** automatique avec déclencheur personnalisable
- **Limite de drawdown** sur l'equity
- **Contrôle de spread et marge**

### 🔄 Système de grille avancé
- Grille dynamique basée sur ATR
- Multiplicateur de volume configurable
- Trailing sur les niveaux de grille
- Profit minimum configurable (absolu ou %)
- Suspension intelligente lors d'inversions non confirmées

### 🛡️ Compatibilité FTMO
- **Maximum Daily Loss (MDL)** : Protection automatique
- **Maximum Loss Total** : Sécurité globale
- **Pré-trade checks** : Validation avant chaque ordre
- **Caps opérationnels** : Limites de lots et positions
- **Horloge Prague** : Reset automatique à minuit Prague

### 📅 Gestion temporelle
- **Sessions de trading** : Configuration par jour de la semaine
- **Horaires personnalisés** : Fenêtres de trading précises
- **Fermeture avant weekend** : Évite les gaps de prix
- **Respect des sessions broker**

### 📰 Filtre de news économiques
- **3 niveaux de sévérité** : Faibles, Moyennes, Fortes
- **Fenêtres de blackout** configurables avant/après les news
- **Overlay strict 2/2** pour FTMO (fenêtres réduites)
- **Actions automatiques** : Blocage ou clôture des positions

### 📊 Logging et diagnostics
- **9 catégories de logs** : Général, positions, risque, sessions, news, etc.
- **Export FTMO** : CSV et JSON pour analyse des performances
- **Compteurs détaillés** : MDL hits, suspensions, pré-closes
- **Diagnostic technique** : Buffers et indicateurs

## 🚀 Installation

### Prérequis
- **MetaTrader 5** (build 3260 ou supérieur)
- **Connexion internet** pour les données de news
- **Compte de trading** avec autorisation d'EA

### Étapes d'installation

1. **Téléchargez** tous les fichiers du repository
2. **Copiez les dossiers** dans votre répertoire MQL5 :
   ```
   /MQL5/
   ├── Experts/
   │   └── Aurora.mq5
   ├── Include/
   │   ├── aurora_*.mqh (tous les fichiers)
   │   └── EAUtils.mqh
   └── Indicators/
       ├── ATR_HeikenAshi.mq5
       ├── ChandelierExit.mq5
       ├── ZLSMA.mq5
       └── Examples/
           └── Heiken_Ashi.mq5
   ```
3. **Compilez** l'expert advisor dans MetaTrader 5
4. **Placez Aurora** sur votre graphique préféré
5. **Configurez** les paramètres selon vos besoins

## ⚙️ Configuration

### Paramètres essentiels

#### Indicateurs & Grille
```mq5
CeAtrPeriod = 1          // Période ATR Chandelier
CeAtrMult = 0.75         // Multiplicateur ATR
ZlPeriod = 50            // Période ZLSMA
Grid = true              // Activer la grille
GridVolMult = 1.5        // Multiplicateur volume grille
```

#### Risk Management
```mq5
Risk = 3                 // Risque par trade (%)
RiskMode = RISK_DEFAULT  // Mode de risque
Trail = true             // Trailing stop
TrailingStopLevel = 50   // Niveau trailing (%)
```

#### FTMO (si applicable)
```mq5
InpFTMO_Mode = FTMO_CHALLENGE     // Mode FTMO
InpFTMO_DailyMaxPercent = 4.0     // MDL (%)
InpFTMO_TotalMaxPercent = 9.0     // Max Loss total (%)
```

### Presets recommandés

Des configurations optimisées sont disponibles pour :

- **AUDUSD M15** : Scalping asiatique, London intraday
- **US30 M15** : Configurations safe et kamikaze
- **XAUUSD** : Swing D1/H1, Scalp M1/M5/M15

## 📈 Utilisation

### Backtesting
1. Ouvrez le Strategy Tester dans MetaTrader 5
2. Sélectionnez "Aurora" comme expert
3. Choisissez votre symbole et timeframe
4. Configurez la période de test
5. Lancez le backtest avec visualisation

### Trading live
1. Placez Aurora sur votre graphique
2. Ajustez les paramètres selon votre stratégie
3. Activez l'auto-trading
4. Surveillez les logs pour le diagnostic

### Monitoring
- **Logs en temps réel** dans la console MT5
- **Fichiers CSV FTMO** dans Common Files
- **Alertes automatiques** pour MDL et seuils critiques

## 🔧 Structure du projet

```
MQL5_GEMINI/
├── Experts/
│   └── Aurora.mq5                 # Expert Advisor principal
├── Include/
│   ├── aurora_constants.mqh       # Constantes partagées
│   ├── aurora_inputs_structs.mqh  # Structures de paramètres
│   ├── aurora_logger.mqh          # Système de logging
│   ├── aurora_ftmo_*.mqh          # Modules FTMO
│   ├── aurora_session_manager.mqh # Gestion des sessions
│   ├── aurora_news*.mqh           # Filtre de news
│   └── aurora_*.mqh               # Autres modules
├── Indicators/
│   ├── ATR_HeikenAshi.mq5         # Indicateur ATR modifié
│   ├── ChandelierExit.mq5         # Chandelier Exit
│   ├── ZLSMA.mq5                  # Zero Lag SMA
│   └── Examples/
│       └── Heiken_Ashi.mq5        # Heikin Ashi standard
└── Presets/
    ├── BACKUPS/AURORA/            # Archives de configurations
    └── *.set                      # Presets actifs
```

## 📋 Changelog

### Version 1.73
- Corrections de bugs mineurs
- Amélioration des performances
- Nouveaux presets optimisés

### Version 1.31+
- Grille dynamique basée sur ATR
- Profit minimum configurable pour la grille
- Suspension intelligente de la grille

## ⚠️ Avertissements importants

- **Testez toujours** en démo avant le trading réel
- **Comprenez les risques** : Le trading comporte des risques de perte
- **FTMO** : Respectez strictement les règles des challenges
- **News** : Les filtres ne garantissent pas contre tous les événements
- **Weekend** : La gestion weekend réduit mais n'élimine pas les risques de gap

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créez une branche pour votre fonctionnalité
3. Testez thoroughly vos modifications
4. Soumettez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 📞 Support

Pour le support ou les questions :
- Ouvrez une issue sur GitHub
- Consultez les logs détaillés pour le diagnostic
- Vérifiez la documentation des paramètres

---

**⚡ Puissant • Fiable • FTMO-Ready**

*Développé avec ❤️ pour la communauté MQL5*
