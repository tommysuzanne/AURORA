//+------------------------------------------------------------------+
//|                                            aurora_pyramiding.mqh |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#include <aurora_inputs_structs.mqh>
#include <aurora_logger.mqh>
#include <aurora_confidence_engine.mqh>
#include <aurora_async_manager.mqh> // Need access to send orders

// Forward declaration of GerEA to avoid circular dep if possible, 
// strictly we just need order sending capabilities, but assuming we use global or pass-in
// For now, we will assume we can use the global g_asyncManager or pass a reference.

//+------------------------------------------------------------------+
//| Class CAuroraPyramiding                                          |
//| Gestionnaire de Scaling-In "Trend Sniper"                        |
//+------------------------------------------------------------------+
class CAuroraPyramiding
{
private:
   bool     m_enable;
   int      m_max_layers;
   int      m_current_layers; // Exposed for dashboard
   double   m_step_pts;
   double   m_vol_mult;
   double   m_min_conf;
   bool     m_trail_sync;
   int      m_trail_dist_2;      // Configurable distance
   int      m_trail_dist_3;      // Configurable distance
   
   // ATR Settings (v1.6)
   ENUM_PYRA_TRAIL_MODE m_trail_mode;
   int      m_atr_period;
   double   m_atr_mult_2;
   double   m_atr_mult_3;
   int      m_atr_handle;
   
   // State tracking (simple timestamp anti-spam)
   datetime m_last_scale_time;

public:
   CAuroraPyramiding();
   ~CAuroraPyramiding();
   
   void Configure(const STrendScaleInputs &params);
   
   // Main processing method called from OnTick
   void Process(ulong magic, string symbol, double confidence_score, double current_spread);
   int GetCurrentLayers() const { return m_current_layers; }

private:
   struct SGroupState {
      int count;           // Total positions in chain
      ulong lead_ticket;   // Ticket of the "Lead" (Initial) trade
      double lead_profit_pts; 
      double lead_open_price;
      double lead_sl;
      double lead_vol;
      ENUM_POSITION_TYPE type; 
      double last_layer_open_price; 
      
      // New fields for Group BE Calc
      double total_vol;
      double weighted_price_sum;
   };

   void ScanGroup(ulong magic, string symbol, SGroupState &state);
   bool ExecuteScaling(ulong magic, string symbol, const SGroupState &state, double confidence_score, double spread);
   void SyncTrailing(ulong magic, string symbol, const SGroupState &state);
   double NormalizeVolume(string symbol, double vol);
   void UpdateGroupStopLoss(ulong magic, string symbol, double new_sl);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAuroraPyramiding::CAuroraPyramiding()
   : m_enable(false),
     m_max_layers(3),
     m_current_layers(0),
     m_step_pts(500),
     m_vol_mult(1.0),
     m_min_conf(0.8),
     m_trail_sync(true),
     m_trail_dist_2(300),
     m_trail_dist_3(150),
     m_trail_mode(PYRA_TRAIL_POINTS),
     m_atr_period(14),
     m_atr_mult_2(2.0),
     m_atr_mult_3(1.0),
     m_atr_handle(INVALID_HANDLE),
     m_last_scale_time(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAuroraPyramiding::~CAuroraPyramiding()
{
   if(m_atr_handle != INVALID_HANDLE) {
      IndicatorRelease(m_atr_handle);
      m_atr_handle = INVALID_HANDLE;
   }
}

// ... (Constructor/Destructor/Configure unchanged)

//+------------------------------------------------------------------+
//| Configure                                                        |
//+------------------------------------------------------------------+
void CAuroraPyramiding::Configure(const STrendScaleInputs &params)
{
   m_enable     = params.enable;
   m_max_layers = params.max_layers;
   m_step_pts   = params.scaling_step_pts;
   m_vol_mult   = params.volume_mult;
   m_min_conf   = params.min_confidence;
   m_trail_sync = params.trailing_sync;
   m_trail_dist_2 = params.trail_dist_2layers;
   m_trail_dist_3 = params.trail_dist_3layers;
   
   // ATR Config (v1.6)
   m_trail_mode = params.trail_mode;
   m_atr_period = params.atr_period;
   m_atr_mult_2 = params.atr_mult_2layers;
   m_atr_mult_3 = params.atr_mult_3layers;
   
   // Initialiser l'indicateur si nécessaire
   if(m_trail_mode == PYRA_TRAIL_ATR) {
      if(m_atr_handle == INVALID_HANDLE) {
         m_atr_handle = iATR(NULL, PERIOD_CURRENT, m_atr_period);
         if(m_atr_handle == INVALID_HANDLE) {
            CAuroraLogger::ErrorGeneral("[PYRAMIDING] Impossible de créer le handle ATR !");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ScanGroup                                                        |
//| Analyse les positions existantes pour ce magic                   |
//+------------------------------------------------------------------+
void CAuroraPyramiding::ScanGroup(ulong magic, string symbol, SGroupState &state)
{
   state.count = 0;
   m_current_layers = 0;
   state.lead_ticket = 0;
   state.lead_profit_pts = -DBL_MAX;
   state.type = POSITION_TYPE_BUY; // Default
   state.last_layer_open_price = 0;
   state.total_vol = 0;
   state.weighted_price_sum = 0;
   
   int total = PositionsTotal();
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // On cherche d'abord à compter et identifier le type dominant
   for(int i=0; i<total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      state.count++;
      
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double current = PositionGetDouble(POSITION_PRICE_CURRENT);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      
      // Accumulate for Weighted Average
      state.total_vol += vol;
      state.weighted_price_sum += (op * vol);
      
      double profit_pts = 0;
      if(type == POSITION_TYPE_BUY) profit_pts = (current - op) / point;
      else profit_pts = (op - current) / point;
      
      // Le "Lead" est celui qui a le plus de profit (le premier ouvert)
      if(profit_pts > state.lead_profit_pts) {
         state.lead_profit_pts = profit_pts;
         state.lead_ticket = ticket;
         state.lead_open_price = op;
         state.lead_sl = sl;
         state.type = type;
         state.lead_vol = vol;
      }
      
      // On track le dernier ajout
      if(state.last_layer_open_price == 0) {
         state.last_layer_open_price = op;
      } else {
         if(type == POSITION_TYPE_BUY && op > state.last_layer_open_price) state.last_layer_open_price = op;
         if(type == POSITION_TYPE_SELL && op < state.last_layer_open_price) state.last_layer_open_price = op;
      }
   }
   m_current_layers = state.count;
}

//+------------------------------------------------------------------+
//| Process                                                          |
//| Main Tick Loop Logic                                             |
//+------------------------------------------------------------------+
void CAuroraPyramiding::Process(ulong magic, string symbol, double confidence_score, double current_spread)
{
   if(!m_enable) return;
   
   SGroupState state;
   ScanGroup(magic, symbol, state);
   
   if(state.count == 0) return; // Rien à faire
   if(state.count >= m_max_layers + 1) return; // Max layers atteints (+1 pour le lead)
   
   // Check Distance depuis le DERNIER ajout
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double dist_from_last = 0;
   double current_price = (state.type == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK));
   
   if(state.type == POSITION_TYPE_BUY) {
      dist_from_last = (current_price - state.last_layer_open_price) / point;
   } else {
      dist_from_last = (state.last_layer_open_price - current_price) / point;
   }
   
   if(dist_from_last < m_step_pts) return; // Trop tôt
   
   // Execute Scaling (Includes Secure First logic & Confidence Check inside)
   if(ExecuteScaling(magic, symbol, state, confidence_score, current_spread)) {
      m_last_scale_time = TimeTradeServer();
   }
   
   // 3. TRAILING SYNC
   if(m_trail_sync) SyncTrailing(magic, symbol, state);
}

//+------------------------------------------------------------------+
//| SyncTrailing (Version Agressive pour Pyramidage)                 |
//+------------------------------------------------------------------+
void CAuroraPyramiding::SyncTrailing(ulong magic, string symbol, const SGroupState &state)
{
   if(state.count < 2) return; // Si on n'a qu'une position, on laisse l'EA principal gérer
   
   // --- LOGIQUE AGRESSIVE ---
   // Plus on a de positions, plus on doit serrer le SL pour protéger les gains latents (Ligne verte)
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double current_price = (state.type == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK));
   
   // On calcule un SL théorique très serré basé sur le dernier plus haut
   // Mode Points ou Mode ATR
   
   double aggressive_dist = 0.0;
   
   if(m_trail_mode == PYRA_TRAIL_ATR && m_atr_handle != INVALID_HANDLE)
   {
       // --- MODE ATR ---
       double atr_vals[];
       ArraySetAsSeries(atr_vals, true);
       if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_vals) > 0) {
           double atr_val = atr_vals[0];
           if(state.count >= 3) aggressive_dist = atr_val * m_atr_mult_3;
           else aggressive_dist = atr_val * m_atr_mult_2;
       } else {
           // Fallback Points si erreur ATR
           aggressive_dist = m_trail_dist_2 * point; 
           if(state.count >= 3) aggressive_dist = m_trail_dist_3 * point; 
       }
   }
   else
   {
       // --- MODE POINTS (Défaut) ---
       aggressive_dist = m_trail_dist_2 * point; 
       if(state.count >= 3) aggressive_dist = m_trail_dist_3 * point; 
   }
   
   double aggressive_sl = 0;
   
   if(state.type == POSITION_TYPE_BUY) {
      aggressive_sl = current_price - aggressive_dist;
      // On s'assure qu'on ne redescend jamais le SL (cliquet)
      // On prend le MAX entre le SL actuel du Lead et notre calcul agressif
      if(state.lead_sl > aggressive_sl) aggressive_sl = state.lead_sl; 
   } else { // SELL
      aggressive_sl = current_price + aggressive_dist;
      // On prend le MIN (car SL au dessus)
      if(state.lead_sl > 0 && state.lead_sl < aggressive_sl) aggressive_sl = state.lead_sl;
      if(state.lead_sl == 0) aggressive_sl = current_price + aggressive_dist; // Init si pas de SL
   }
   
   // --- NORMALIZATION ---
   aggressive_sl = NormalizeDouble(aggressive_sl, digits);

   // --- APPLICATION A TOUT LE GROUPE ---
   int total = PositionsTotal();
   for(int i=0; i<total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      double sl = PositionGetDouble(POSITION_SL);
      bool update = false;
      
      if(state.type == POSITION_TYPE_BUY) {
         // Si le SL calculé est plus haut que le SL actuel, on monte !
         if(sl < aggressive_sl - _Point) update = true;
      } else {
         // Si le SL calculé est plus bas que le SL actuel, on descend !
         if(sl == 0 || sl > aggressive_sl + _Point) update = true;
      }
      
      if(update) {
          MqlTradeRequest req;
          ZeroMemory(req);
          req.action = TRADE_ACTION_SLTP;
          req.position = ticket;
          req.symbol = symbol;
          req.sl = aggressive_sl;
          req.tp = PositionGetDouble(POSITION_TP);
          req.magic = magic;
          
          g_asyncManager.SendAsync(req);
      }
   }
}

//+------------------------------------------------------------------+
//| NormalizeVolume                                                  |
//+------------------------------------------------------------------+
double CAuroraPyramiding::NormalizeVolume(string symbol, double vol)
{
   double step_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double min_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   if(step_vol > 0) vol = MathRound(vol / step_vol) * step_vol;
   if(vol < min_vol) vol = min_vol;
   if(vol > max_vol) vol = max_vol;
   
   return vol;
}

//+------------------------------------------------------------------+
//| UpdateGroupStopLoss                                              |
//+------------------------------------------------------------------+
void CAuroraPyramiding::UpdateGroupStopLoss(ulong magic, string symbol, double new_sl)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   new_sl = NormalizeDouble(new_sl, digits);
   
   int total = PositionsTotal();
   for(int i=0; i<total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      // Optimisation : On ne touche pas si le SL est déjà "mieux" ou identique
      // (Sauf si on veut forcer l'alignement strict au BE Groupe, ce qui est recommandé ici)
      double current_sl = PositionGetDouble(POSITION_SL);
      
      if(MathAbs(current_sl - new_sl) > _Point) // Si différence significative
      {
         MqlTradeRequest req; ZeroMemory(req);
         req.action = TRADE_ACTION_SLTP;
         req.position = ticket;
         req.symbol = symbol;
         req.sl = new_sl;
         req.tp = PositionGetDouble(POSITION_TP);
         req.magic = magic;
         g_asyncManager.SendAsync(req);
      }
   }
}

//+------------------------------------------------------------------+
//| ExecuteScaling (Logique: Secure First -> Check Conf -> Open)     |
//+------------------------------------------------------------------+
bool CAuroraPyramiding::ExecuteScaling(ulong magic, string symbol, const SGroupState &state, double confidence_score, double spread)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // --- CALCUL DU VOLUME FUTUR (Nécessaire pour le calcul du BE Projeté) ---
   // On calcule le volume AVANT de sécuriser, car le niveau de sécurité dépend du volume ajouté.
   double raw_vol = state.lead_vol * m_vol_mult;
   double new_vol = NormalizeVolume(symbol, raw_vol);
   if(new_vol <= 0) return false;
   
   // --- CALCUL DU GROUP BREAK-EVEN PROJETÉ ---
   // BE = (Sum(Price * Vol) + NewPrice * NewVol) / (TotalVol + NewVol)
   double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double entry_price = (state.type == POSITION_TYPE_BUY ? current_ask : current_bid);
   
   double total_vol_future = state.total_vol + new_vol;
   double weighted_sum_future = state.weighted_price_sum + (entry_price * new_vol);
   double group_be_level = weighted_sum_future / total_vol_future;
   
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // --- ÉTAPE 1 : DÉFENSE (INCONDITIONNELLE) ---
   // On place le SL au niveau du BE Projeté + Offset de Sécurité
   
   // Offset de sécurité (Spread * 2)
   double secure_offset = MathMax(spread * 2.0 * point, 50 * point); 
   double target_sl = group_be_level;
   
   if(state.type == POSITION_TYPE_BUY) target_sl += secure_offset;
   else target_sl -= secure_offset;
   
   // --- NORMALIZATION ---
   target_sl = NormalizeDouble(target_sl, digits);
   
   // Vérification : Est-ce que TOUT le groupe est sécurisé au moins à ce niveau ?
   // On doit vérifier si au moins UNE position traîne avec un mauvais SL
   bool group_needs_update = false;
   int total = PositionsTotal();
   
   for(int i=0; i<total; i++) {
      if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == symbol) {
         double current_sl = PositionGetDouble(POSITION_SL);
         if(state.type == POSITION_TYPE_BUY) {
             if(current_sl < target_sl - _Point) group_needs_update = true;
         } else {
             if(current_sl == 0 || current_sl > target_sl + _Point) group_needs_update = true;
         }
      }
   }
   
   if(group_needs_update) {
      // On met à jour TOUT le monde
      UpdateGroupStopLoss(magic, symbol, target_sl);
      
      if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
          CAuroraLogger::InfoStrategy(StringFormat("[TREND SCALE] Step 1: Securing ENTIRE Group to Projected BE @ %.5f", target_sl));
      
      return false; // On attend la confirmation au prochain tick
   }
   
   // =================================================================================
   // ÉTAPE 2 : FILTRE DE CONFIANCE (CONDITIONNEL)
   // Maintenant que c'est sécurisé, on regarde si le marché est assez sain pour ajouter
   // =================================================================================
   
   if(confidence_score < m_min_conf)
   {
      // C'est ici que votre logique brille : 
      // On est sécurisé (BE), mais le moteur nous dit "Attention".
      // On ne risque pas de nouveaux profits.
      return false; 
   }

   // =================================================================================
   // ÉTAPE 3 : ATTAQUE (PYRAMIDAGE)
   // Confiance validée -> On ouvre
   // =================================================================================

   // Note: 'new_vol' est déjà calculé au début de la fonction
   
   MqlTradeRequest req;
   ZeroMemory(req);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.volume = new_vol;
   req.magic = magic;
   req.type = (state.type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   req.price = entry_price; // Déjà calculé (Ask/Bid)
   req.sl = target_sl; // SL aligné sur le BE Projeté du Groupe
   req.tp = 0; 
   req.deviation = 20; // Slippage
   
   // --- Filling Mode (AUDIT FIX) ---
   int fill_mode = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((fill_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) req.type_filling = ORDER_FILLING_FOK;
   else if((fill_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) req.type_filling = ORDER_FILLING_IOC;
   else req.type_filling = ORDER_FILLING_RETURN;
   // --------------------------------
   
   if(g_asyncManager.SendAsync(req)) {
      if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
         CAuroraLogger::InfoStrategy(StringFormat("[TREND SCALE] Step 2: High Confidence (%.2f). Adding Layer #%d (AvgPrice: %.5f)", confidence_score, state.count+1, group_be_level));
      return true;
   }
   
   return false;
}
