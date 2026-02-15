//+------------------------------------------------------------------+
//|                                                   TrapCandle.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property version   "1.00"
#property description "Detects Trap Candles (Stop-Hunting Patterns)"
#property description "Identifies wicks that spike beyond typical range then reverse"
#property description "Signal = 1.0 when trap detected, 0.0 otherwise"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

//--- plot Trap Signal (Arrow on chart)
#property indicator_label1  "Trap Up"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  2

#property indicator_label2  "Trap Down"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrBlue
#property indicator_width2  2

//--- input parameters
input double   InpMinWickBodyRatio    = 2.0;     // [2.0-5.0] Min Wick/Body Ratio
input int      InpMinBodyPts          = 30;      // [10-100] Min Body Size (Points)
input double   InpMaxCloseOpenRatio   = 0.4;     // [0.1-0.5] Max Close/Range Ratio (trap confirmation)
input bool     InpRequirePrevTrend    = true;    // Require prior trend (avoid ranging traps)
input int      InpTrendBars           = 3;       // [2-5] Bars for trend detection

//--- indicator buffers
double         TrapUpBuffer[];    // Arrow for upper wick trap (bearish trap)
double         TrapDownBuffer[];  // Arrow for lower wick trap (bullish trap)
double         TrapSignal[];      // Hidden buffer: 1.0 = trap, 0.0 = normal

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, TrapUpBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, TrapDownBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, TrapSignal, INDICATOR_CALCULATIONS);
   
   // Force Series mode
   ArraySetAsSeries(TrapUpBuffer, true);
   ArraySetAsSeries(TrapDownBuffer, true);
   ArraySetAsSeries(TrapSignal, true);
   
   // Arrow codes: 234 = down arrow (trap up), 233 = up arrow (trap down)
   PlotIndexSetInteger(0, PLOT_ARROW, 234); // Down arrow for upper trap
   PlotIndexSetInteger(1, PLOT_ARROW, 233); // Up arrow for lower trap
   
   // Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   //--- Name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TrapCandle(%.1f, %d)", InpMinWickBodyRatio, InpMinBodyPts));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Detect if there's a prior trend                                  |
//+------------------------------------------------------------------+
int DetectPriorTrend(const double &close[], int barIndex, int lookback)
{
   // Returns: +1 = bullish trend, -1 = bearish trend, 0 = ranging
   if (barIndex + lookback >= ArraySize(close)) return 0;
   
   int upCount = 0;
   int downCount = 0;
   
   for (int i = 0; i < lookback; i++) {
      int idx = barIndex + 1 + i; // Start from bar after current
      int idxPrev = idx + 1;
      
      if (idxPrev >= ArraySize(close)) break;
      
      if (close[idx] > close[idxPrev]) upCount++;
      else if (close[idx] < close[idxPrev]) downCount++;
   }
   
   // Need majority direction
   if (upCount >= lookback - 1) return 1;   // Bullish
   if (downCount >= lookback - 1) return -1; // Bearish
   return 0; // Ranging
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Safety
   if(rates_total < InpTrendBars + 2) return 0;

   // Match arrays to Series
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Calculate range
   int limit;
   if(prev_calculated == 0) {
       limit = rates_total - InpTrendBars - 2;
   } else {
       limit = rates_total - prev_calculated + 1;
       if (limit > rates_total - InpTrendBars - 2) 
           limit = rates_total - InpTrendBars - 2;
   }

   // Main Loop (Series: 0 = newest)
   for(int i = limit; i >= 0; i--)
   {
      // Initialize
      TrapUpBuffer[i] = 0.0;
      TrapDownBuffer[i] = 0.0;
      TrapSignal[i] = 0.0;
      
      // Calculate candle metrics
      double o = open[i];
      double h = high[i];
      double l = low[i];
      double c = close[i];
      
      double body = MathAbs(c - o);
      double range = h - l;
      double upperWick = h - MathMax(o, c);
      double lowerWick = MathMin(o, c) - l;
      
      // Filter: Body too small (doji-like) - skip
      if (body < InpMinBodyPts * _Point) continue;
      
      // Filter: Range too small
      if (range < _Point) continue;
      
      // Calculate ratios
      double upperWickRatio = (body > 0) ? upperWick / body : 0.0;
      double lowerWickRatio = (body > 0) ? lowerWick / body : 0.0;
      
      // Close distance from open (as ratio of range)
      // A trap candle closes near where it opened (price reversed)
      double closeOpenDist = MathAbs(c - o);
      double closeOpenRatio = closeOpenDist / range;
      
      // --- UPPER WICK TRAP (Bearish Trap) ---
      // Pattern: Large upper wick, price spiked UP but closed near open
      // This traps buyers/shorts who got stopped out
      bool upperTrap = false;
      if (upperWickRatio >= InpMinWickBodyRatio && closeOpenRatio <= InpMaxCloseOpenRatio) {
         // Additional: Upper wick should be dominant
         if (upperWick > lowerWick * 1.5) {
            // Check prior trend if required
            if (!InpRequirePrevTrend) {
               upperTrap = true;
            } else {
               int trend = DetectPriorTrend(close, i, InpTrendBars);
               // Upper trap more significant after bullish trend (trapped longs)
               if (trend == 1) upperTrap = true;
            }
         }
      }
      
      // --- LOWER WICK TRAP (Bullish Trap) ---
      // Pattern: Large lower wick, price spiked DOWN but closed near open
      // This traps sellers/longs who got stopped out
      bool lowerTrap = false;
      if (lowerWickRatio >= InpMinWickBodyRatio && closeOpenRatio <= InpMaxCloseOpenRatio) {
         // Additional: Lower wick should be dominant
         if (lowerWick > upperWick * 1.5) {
            if (!InpRequirePrevTrend) {
               lowerTrap = true;
            } else {
               int trend = DetectPriorTrend(close, i, InpTrendBars);
               // Lower trap more significant after bearish trend (trapped shorts)
               if (trend == -1) lowerTrap = true;
            }
         }
      }
      
      // Set signals
      if (upperTrap) {
         TrapUpBuffer[i] = h + (range * 0.1); // Arrow above candle
         TrapSignal[i] = 1.0;
      }
      
      if (lowerTrap) {
         TrapDownBuffer[i] = l - (range * 0.1); // Arrow below candle
         TrapSignal[i] = 1.0;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
