//+------------------------------------------------------------------+
//|                                         aurora_state_structs.mqh |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property strict

#ifndef AURORA_STATE_STRUCTS_MQH
#define AURORA_STATE_STRUCTS_MQH

//+------------------------------------------------------------------+
//| Struct SAuroraState                                              |
//| Centralise l'état en temps réel pour le Dashboard                |
//+------------------------------------------------------------------+
struct SAuroraState
{
   double   account_equity;      // Equité temps réel
   double   account_balance;     // Solde
   double   profit_total;        // Profit total historique
   double   profit_current;      // Profit flottant actuel
   double   dd_max_alltime;      // Drawdown Max absolu
   double   dd_current;          // Drawdown actuel
   double   dd_daily;            // Drawdown journalier
   
   // News Structure
   struct SNewsItem {
       datetime time;
       string   currency;
       int      impact; // 0=None, 1=Low, 2=Med, 3=High
       string   title;
   };
   SNewsItem news[];
   
   // Deprecated/Removed fields (kept if needed for compile but ignored in logic)
   double   confidence_score;    
   double   trend_direction;     
   int      layers_current;      
   int      layers_max;          
};

#endif
