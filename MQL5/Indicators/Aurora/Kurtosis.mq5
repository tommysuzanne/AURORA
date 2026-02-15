//+------------------------------------------------------------------+
//|                                                      Kurtosis.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property version   "1.00"
#property description "Rolling Excess Kurtosis of Log Returns"
#property description "Values > 0 indicate Fat Tails (leptokurtic distribution)"
#property description "Values < 0 indicate Thin Tails (platykurtic distribution)"
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- plot Kurtosis
#property indicator_label1  "Excess Kurtosis"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- input parameters
input int      InpWindow      = 100;     // Rolling Window (Bars) [50-500]
input double   InpThreshold   = 1.0;     // Critical Threshold (Fat Tail Warning)
input bool     InpLogVerbose  = false;   // Enable internal indicator logs

//--- indicator buffers
double         KurtosisBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, KurtosisBuffer, INDICATOR_DATA);
   
   // Force Series mode (0 = Newest bar)
   ArraySetAsSeries(KurtosisBuffer, true);
   
   //--- validation
   if(InpWindow < 10) {
       if (InpLogVerbose) Print("[Kurtosis] Window too small, minimum 10 required");
       return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Kurtosis(%d)", InpWindow));
   
   //--- Levels
   // Level 0: Zero line (normal distribution reference)
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   
   // Level 1: Threshold (fat tail warning)
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpThreshold);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrRed);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_SOLID);

   return(INIT_SUCCEEDED);
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
   // Safety: Need InpWindow + 1 bars minimum for log returns
   if(rates_total < InpWindow + 1) return 0;

   // Match input arrays to Series (0 = Newest)
   ArraySetAsSeries(close, true);

   // Series logic (iterate from limit down to 0)
   int limit;
   
   // On first run, calculate everything
   if(prev_calculated == 0) {
       limit = rates_total - InpWindow - 1;
   } else {
       // Only calculate new bars
       limit = rates_total - prev_calculated;
       if(limit > rates_total - InpWindow - 1) 
           limit = rates_total - InpWindow - 1;
   }

   // Main Loop (Descending for Series)
   for(int i = limit; i >= 0; i--)
   {
      // Boundary check
      if(i + InpWindow >= rates_total) {
         KurtosisBuffer[i] = 0.0; // Neutral at edge
         continue;
      }
      
      // === KURTOSIS CALCULATION ===
      // Using log returns: r[k] = ln(close[i+k] / close[i+k+1])
      
      // --- Pass 1: Calculate Mean ---
      double sum = 0.0;
      for(int k = 0; k < InpWindow; k++) {
          double p_curr = close[i + k];
          double p_prev = close[i + k + 1];
          if(p_prev <= 0) continue; // Safety
          double r = MathLog(p_curr / p_prev);
          sum += r;
      }
      double mean = sum / InpWindow;
      
      // --- Pass 2: Calculate Variance (M2) and Fourth Moment (M4) ---
      double sum_sq = 0.0;    // Sum of (r - mean)^2
      double sum_4th = 0.0;   // Sum of (r - mean)^4
      
      for(int k = 0; k < InpWindow; k++) {
          double p_curr = close[i + k];
          double p_prev = close[i + k + 1];
          if(p_prev <= 0) continue;
          double r = MathLog(p_curr / p_prev);
          
          double diff = r - mean;
          double diff2 = diff * diff;
          double diff4 = diff2 * diff2;
          
          sum_sq += diff2;
          sum_4th += diff4;
      }
      
      // Variance (sample)
      double variance = sum_sq / InpWindow;
      
      // Avoid division by zero
      if(variance < 1e-20) {
          KurtosisBuffer[i] = 0.0;
          continue;
      }
      
      // Fourth moment
      double m4 = sum_4th / InpWindow;
      
      // Kurtosis = M4 / Variance^2
      double variance_sq = variance * variance;
      double kurtosis = m4 / variance_sq;
      
      // Excess Kurtosis = Kurtosis - 3
      // Normal distribution has Kurtosis = 3, so Excess = 0
      KurtosisBuffer[i] = kurtosis - 3.0;
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
