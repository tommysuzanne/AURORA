//+------------------------------------------------------------------+
//|                                            aurora_pyramiding.mqh |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_PYRAMIDING_MQH__
#define __AURORA_PYRAMIDING_MQH__

#include <Aurora/aurora_types.mqh>
#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_error_utils.mqh>
#include <Aurora/aurora_time.mqh>
#include <Aurora/aurora_trade_contract.mqh>

#include <Aurora/aurora_async_manager.mqh> // Need access to send orders
#include <Aurora/aurora_snapshot.mqh>

// Execution helpers are consumed via aurora_trade_contract.mqh.
// Async dispatch relies on the global g_asyncManager instance.

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
   void Process(ulong magic, string symbol, double current_spread, double confidence, const CAuroraSnapshot &snap, bool allowEntry = true, bool exitOnClose = false, double hardSLMult = 1.5, double maxTotalLots = -1);
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

   void ScanGroup(ulong magic, string symbol, SGroupState &state, const CAuroraSnapshot &snap);
   bool ExecuteScaling(ulong magic, string symbol, const SGroupState &state, double confidence_score, double spread, const CAuroraSnapshot &snap, bool allowEntry, bool exitOnClose, double hardSLMult, double maxTotalLots);
   void SyncTrailing(ulong magic, string symbol, const SGroupState &state, const CAuroraSnapshot &snap);
   double NormalizeVolume(string symbol, double vol);
   void UpdateGroupStopLoss(ulong magic, string symbol, double new_sl, const CAuroraSnapshot &snap);
   double CurrentExposureVolume(ulong magic, string symbol) const;
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
   
   // Initialize indicator if necessary
   if(m_trail_mode == PYRA_TRAIL_ATR) {
      if(m_atr_handle == INVALID_HANDLE) {
         m_atr_handle = iATR(NULL, PERIOD_CURRENT, m_atr_period);
         if(m_atr_handle == INVALID_HANDLE) {
            CAuroraLogger::ErrorGeneral("[PYRAMIDING] Failed to create ATR handle!");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ScanGroup                                                        |
//| Analyzes existing positions for this magic                        |
//+------------------------------------------------------------------+
void CAuroraPyramiding::ScanGroup(ulong magic, string symbol, SGroupState &state, const CAuroraSnapshot &snap)
{
   state.count = 0;
   m_current_layers = 0;
   state.lead_ticket = 0;
   state.lead_profit_pts = -DBL_MAX;
   state.type = POSITION_TYPE_BUY; // Default
   state.last_layer_open_price = 0;
   state.total_vol = 0;
   state.weighted_price_sum = 0;
   
   int total = snap.Total();
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // First, count and identify the dominant type
   for(int i=0; i<total; i++) {
      SAuroraPos pos = snap.Get(i);
      if(pos.magic != magic) continue;
      if(pos.symbol != symbol) continue;
      
      state.count++;
      
      ulong ticket = pos.ticket;
      double op = pos.price_open;
      double current = (pos.type == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK)); 
      // Note: Snapshot doesn't store Current Price, assume real-time fetch or approx?
      // Real-time fetch of Bid/Ask is cheap (SymbolInfoDouble usually cached/fast).
      // CAUTION: 'pos.profit' is in money. We need Pts.
      
      ENUM_POSITION_TYPE type = pos.type;
      double sl = pos.sl;
      double vol = pos.volume;
      
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
void CAuroraPyramiding::Process(ulong magic, string symbol, double current_spread, double confidence, const CAuroraSnapshot &snap, bool allowEntry, bool exitOnClose, double hardSLMult, double maxTotalLots)
{
   if(!m_enable) return;
   
   SGroupState state;
   ScanGroup(magic, symbol, state, snap);
   
   if(state.count == 0) return; // Nothing to do
   if(state.count >= m_max_layers + 1) return; // Max layers reached (+1 for lead)
   
   // Anti-spam: avoid stacking async requests
   if(g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_DEAL, (state.type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL)))
      return;
   if(m_last_scale_time != 0 && (AuroraClock::Now() - m_last_scale_time) < 1) return;
   
   // Check distance from LAST layer
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double dist_from_last = 0;
   double current_price = (state.type == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK));
   
   if(state.type == POSITION_TYPE_BUY) {
      dist_from_last = (current_price - state.last_layer_open_price) / point;
   } else {
      dist_from_last = (state.last_layer_open_price - current_price) / point;
   }
   
   if(dist_from_last < m_step_pts) return; // Too early
   
   // Execute Scaling (Includes Secure First logic & Confidence Check inside)
   if(ExecuteScaling(magic, symbol, state, confidence, current_spread, snap, allowEntry, exitOnClose, hardSLMult, maxTotalLots)) {
      m_last_scale_time = AuroraClock::Now();
   }
   
   // 3. TRAILING SYNC
   if(m_trail_sync && !exitOnClose) SyncTrailing(magic, symbol, state, snap);
}

//+------------------------------------------------------------------+
//| SyncTrailing (Aggressive Version for Pyramiding)                  |
//+------------------------------------------------------------------+
void CAuroraPyramiding::SyncTrailing(ulong magic, string symbol, const SGroupState &state, const CAuroraSnapshot &snap)
{
   if(state.count < 2) return; // If only one position, let main EA manage
   if(g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_SLTP)) return;
   
   // --- AGGRESSIVE LOGIC ---
   // The more positions we have, the tighter we must set SL to protect unrealized gains
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double current_price = (state.type == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK));
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) tick_size = point;
   double min_dist_price = MinBrokerPoints(symbol) * point;
   
   // Calculate a very tight theoretical SL based on latest high
   // Mode: Points or ATR
   
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
           // Fallback to Points mode if ATR error
           aggressive_dist = m_trail_dist_2 * point; 
           if(state.count >= 3) aggressive_dist = m_trail_dist_3 * point; 
       }
   }
   else
   {
       // --- POINTS MODE (Default) ---
       aggressive_dist = m_trail_dist_2 * point; 
       if(state.count >= 3) aggressive_dist = m_trail_dist_3 * point; 
   }
   
   double aggressive_sl = 0;
   
   if(state.type == POSITION_TYPE_BUY) {
      aggressive_sl = current_price - aggressive_dist;
      // Ensure we never lower the SL (ratchet effect)
      // Take MAX between current Lead SL and our aggressive calc
      if(state.lead_sl > aggressive_sl) aggressive_sl = state.lead_sl; 
   } else { // SELL
      aggressive_sl = current_price + aggressive_dist;
      // Take MIN (since SL is above)
      if(state.lead_sl > 0 && state.lead_sl < aggressive_sl) aggressive_sl = state.lead_sl;
      if(state.lead_sl == 0) aggressive_sl = current_price + aggressive_dist; // Init if no SL
   }
   
   // --- VALIDATION + NORMALIZATION (tick-safe) ---
   if(state.type == POSITION_TYPE_BUY) {
      double maxAllowed = current_price - min_dist_price;
      if(aggressive_sl > maxAllowed) aggressive_sl = maxAllowed;
      aggressive_sl = NormalizePriceDown(aggressive_sl, symbol);
   } else {
      double minAllowed = current_price + min_dist_price;
      if(aggressive_sl < minAllowed) aggressive_sl = minAllowed;
      aggressive_sl = NormalizePriceUp(aggressive_sl, symbol);
   }

   // --- APPLY TO ENTIRE GROUP ---
   int total = snap.Total();
   for(int i=0; i<total; i++) {
      SAuroraPos pos = snap.Get(i);
      
      if(pos.magic != magic) continue;
      if(pos.symbol != symbol) continue;
      
      ulong ticket = pos.ticket;
      double sl = pos.sl;
      bool update = false;
      
      if(state.type == POSITION_TYPE_BUY) {
         // If calculated SL is higher than current SL, move up !
         if(sl < aggressive_sl - (tick_size * 0.5)) update = true;
      } else {
         // If calculated SL is lower than current SL, move down !
         if(sl == 0 || sl > aggressive_sl + (tick_size * 0.5)) update = true;
      }
      
      if(update) {
          MqlTradeRequest req;
          ZeroMemory(req);
          req.action = TRADE_ACTION_SLTP;
          req.position = ticket;
          req.symbol = symbol;
          req.sl = aggressive_sl;
          req.tp = pos.tp;
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

double CAuroraPyramiding::CurrentExposureVolume(ulong magic, string symbol) const
{
   double totalVol = 0.0;
   int totalPos = PositionsTotal();
   for(int i=0; i<totalPos; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      totalVol += PositionGetDouble(POSITION_VOLUME);
   }
   int totalOrd = OrdersTotal();
   for(int i=0; i<totalOrd; i++) {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetInteger(ORDER_MAGIC) != (long)magic) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype == ORDER_TYPE_BUY || otype == ORDER_TYPE_SELL) continue;
      totalVol += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return totalVol;
}

//+------------------------------------------------------------------+
//| UpdateGroupStopLoss                                              |
//+------------------------------------------------------------------+
void CAuroraPyramiding::UpdateGroupStopLoss(ulong magic, string symbol, double new_sl, const CAuroraSnapshot &snap)
{
   if(g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_SLTP)) return;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) tick_size = point;
   double min_dist_price = MinBrokerPoints(symbol) * point;
   double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   int total = snap.Total();
   for(int i=0; i<total; i++) {
      SAuroraPos pos = snap.Get(i);
      
      if(pos.magic != magic) continue;
      if(pos.symbol != symbol) continue;
      
      ulong ticket = pos.ticket;
      
      // Optimisation : On ne touche pas si le SL est déjà "mieux" ou identique
      double current_sl = pos.sl;
      bool isBuy = (pos.type == POSITION_TYPE_BUY);
      double target_sl = new_sl;
      if(isBuy) {
         double maxAllowed = current_bid - min_dist_price;
         if(target_sl > maxAllowed) target_sl = maxAllowed;
         target_sl = NormalizePriceDown(target_sl, symbol);
      } else {
         double minAllowed = current_ask + min_dist_price;
         if(target_sl < minAllowed) target_sl = minAllowed;
         target_sl = NormalizePriceUp(target_sl, symbol);
      }
      
      if(MathAbs(current_sl - target_sl) > (tick_size * 0.5)) // Si différence significative
      {
         MqlTradeRequest req; ZeroMemory(req);
         req.action = TRADE_ACTION_SLTP;
         req.position = ticket;
         req.symbol = symbol;
         req.sl = target_sl;
         req.tp = pos.tp;
         req.magic = magic;
         g_asyncManager.SendAsync(req);
      }
   }
}

//+------------------------------------------------------------------+
//| ExecuteScaling (Logic: Secure First -> Check Conf -> Open)     |
//+------------------------------------------------------------------+
bool CAuroraPyramiding::ExecuteScaling(ulong magic, string symbol, const SGroupState &state, double confidence_score, double spread, const CAuroraSnapshot &snap, bool allowEntry, bool exitOnClose, double hardSLMult, double maxTotalLots)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // --- CALCULATE FUTURE VOLUME (Required for Projected BE calc) ---
   // Calculate volume BEFORE securing, as security level depends on added volume.
   double raw_vol = state.lead_vol * m_vol_mult;
   double new_vol = NormalizeVolume(symbol, raw_vol);
   if(new_vol <= 0) return false;
   
   if(maxTotalLots > 0) {
      double curTotal = CurrentExposureVolume(magic, symbol);
      if((curTotal + new_vol) > maxTotalLots) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
            CAuroraLogger::WarnRisk(StringFormat("[TREND SCALE] MaxTotalLots %.2f dépassé (actuel=%.2f, nouveau=%.2f)", maxTotalLots, curTotal, new_vol));
         return false;
      }
   }
   
   // --- CALCULATE PROJECTED GROUP BREAK-EVEN ---
   // BE = (Sum(Price * Vol) + NewPrice * NewVol) / (TotalVol + NewVol)
   double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double entry_price = (state.type == POSITION_TYPE_BUY ? current_ask : current_bid);
   
   double total_vol_future = state.total_vol + new_vol;
   double weighted_sum_future = state.weighted_price_sum + (entry_price * new_vol);
   double group_be_level = weighted_sum_future / total_vol_future;
   
   // --- STEP 1: DEFENSE (UNCONDITIONAL) ---
   // Set SL at Projected BE level + Safety Offset
   
   // Safety offset (Spread * 2)
   double secure_offset = MathMax(spread * 2.0 * point, 50 * point); 
   double target_sl = group_be_level;
   
   if(state.type == POSITION_TYPE_BUY) target_sl += secure_offset;
   else target_sl -= secure_offset;
   
   // --- NORMALIZATION ---
   if(state.type == POSITION_TYPE_BUY) target_sl = NormalizePriceDown(target_sl, symbol);
   else target_sl = NormalizePriceUp(target_sl, symbol);
   
   double broker_sl = target_sl;
   if(exitOnClose && target_sl > 0) {
      double dist = MathAbs(entry_price - target_sl);
      double hardDist = dist * hardSLMult;
      if(state.type == POSITION_TYPE_BUY) broker_sl = entry_price - hardDist;
      else broker_sl = entry_price + hardDist;
      if(state.type == POSITION_TYPE_BUY) broker_sl = NormalizePriceDown(broker_sl, symbol);
      else broker_sl = NormalizePriceUp(broker_sl, symbol);
   }
   
   // Check: Is the ENTIRE group secured at least to this level ?
   // Must check if at least ONE position has a bad SL
   bool group_needs_update = false;
   int total = snap.Total();
   
   for(int i=0; i<total; i++) {
        SAuroraPos pos = snap.Get(i);
        if(pos.magic == magic && pos.symbol == symbol) {
             double current_sl = pos.sl;
             if(state.type == POSITION_TYPE_BUY) {
                 if(current_sl < broker_sl - _Point) group_needs_update = true;
             } else {
                 if(current_sl == 0 || current_sl > broker_sl + _Point) group_needs_update = true;
             }
        }
   }
   
   if(group_needs_update) {
      // Update ALL positions
      UpdateGroupStopLoss(magic, symbol, broker_sl, snap);
      
      if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
          CAuroraLogger::InfoStrategy(StringFormat("[TREND SCALE] Step 1: Securing ENTIRE Group to Projected BE @ %.5f", target_sl));
      
      return false; // Wait for confirmation on next tick
   }
   
   if(!allowEntry) return false;
   
   // =================================================================================
   // STEP 2: ATTACK (PYRAMIDING)
   // Secure First BE protection is sufficient - check confidence then open new layer
   // =================================================================================
   
   if (confidence_score < m_min_conf) {
       // Log only once per bar/logic cycle potentially? 
       // For now, silent return is safer to avoid log spam on every tick.
       return false;
   }

   // Note: 'new_vol' was already calculated at start of function
   
   MqlTradeRequest req;
   ZeroMemory(req);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.volume = new_vol;
   req.magic = magic;
   req.type = (state.type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   req.price = entry_price; // Already calculated (Ask/Bid)
   req.sl = broker_sl; // SL aligned to Projected Group BE (hard if ExitOnClose)
   req.tp = 0; 
   req.deviation = 20; // Slippage
   
   // --- Filling Mode (AUDIT FIX) ---
   req.type_filling = SelectFilling(symbol, FILLING_DEFAULT);
   // --------------------------------

   // Broker compatibility: validate filling mode before sending async (prevents "Unsupported filling mode")
   MqlTradeCheckResult cres = {};
   if (!OrderCheck(req, cres)) {
      // Keep cres.retcode for analysis.
   }
   if (cres.retcode == TRADE_RETCODE_INVALID_FILL) {
      FixFillingByOrderCheck(req, FILLING_DEFAULT, cres);
   }
   if (cres.retcode == TRADE_RETCODE_INVALID_FILL) {
      if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
         CAuroraLogger::ErrorOrders(StringFormat("[TREND SCALE] Unsupported filling mode after fallback. Drop. (%u %s)", cres.retcode, TradeServerReturnCodeDescription(cres.retcode)));
      return false;
   }
   
   if(g_asyncManager.SendAsync(req)) {
      if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
         CAuroraLogger::InfoStrategy(StringFormat("[TREND SCALE] Step 2: High Confidence (%.2f). Adding Layer #%d (AvgPrice: %.5f)", confidence_score, state.count+1, group_be_level));
      return true;
   }
   
   return false;
}

#endif // __AURORA_PYRAMIDING_MQH__
