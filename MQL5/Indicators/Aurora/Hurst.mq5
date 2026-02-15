//+------------------------------------------------------------------+
//|                                                        Hurst.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property version   "1.10"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- plot Hurst
#property indicator_label1  "Hurst Exponent"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- input parameters
input int      InpWindow      = 100;     // Rolling Window (Bars)
input int      InpSmoothing   = 5;       // Smoothing Period (WMA)
input double   InpThreshold   = 0.45;    // Critical Threshold (Visual Reference)

//--- indicator buffers
double         HurstBuffer[]; // Visible Smoothed Buffer
double         RawBuffer[];   // Hidden Raw Calculation Buffer

//--- Global variables for optimization
double         g_log_denominator; 
double         g_log10_2;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, HurstBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, RawBuffer, INDICATOR_CALCULATIONS);
   
   // --- INSTITUTIONAL GRADE FIX: FORCE SERIES ---
   // This guarantees that Index[0] is always the NEWEST bar.
   ArraySetAsSeries(HurstBuffer, true);
   ArraySetAsSeries(RawBuffer, true);
   // ---------------------------------------------
   
   //--- optimization
   g_log10_2 = MathLog10(2.0);
   // Pre-calculate the denominator constant: log(n) - log(2)
   // We use InpWindow as 'n' for the scale reference.
   if(InpWindow < 8) {
       // Preventing math error if user inputs garbage, though loop handles it
       g_log_denominator = 1.0; 
   } else {
       g_log_denominator = MathLog10((double)InpWindow) - g_log10_2;
   }
   
   //--- Name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Hurst(%d, Sm=%d)", InpWindow, InpSmoothing));
   
   //--- Levels
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.5);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   
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
   // Safety checks
   if(rates_total < InpWindow + InpSmoothing) return 0;

   // --- CRITICAL FIX: Match Input Arrays to Series Buffers ---
   // Since HurstBuffer is AS_SERIES (0=Newest), we MUST treat 'close' as series
   // to strictly align indices (close[0] = current price).
   ArraySetAsSeries(close, true); 
   // ----------------------------------------------------------

   // Series Array Logic (0 = Newest, rates_total-1 = Oldest)
   // We iterate from 'limit' down to '0'.
   
   int limit = rates_total - prev_calculated;
   
   // If new data or first run, check how far back we need to go
   if(limit > rates_total - InpWindow - 1) limit = rates_total - InpWindow - 1;
   
   // On first run, calculate everything
   if(prev_calculated == 0) limit = rates_total - InpWindow - 1;

   // Main Loop (Descending for Series)
   for(int i = limit; i >= 0; i--)
   {
      // Hurst Window: We need 'InpWindow' bars ending at 'i'.
      // With Series: 
      // i = Current Bar (Target)
      // i+InpWindow-1 = Oldest bar in window
      
      // Boundary check handled by limit logic, but safe guard:
      // We need InpWindow + 1 bars for returns (k goes up to InpWindow)
      if(i + InpWindow >= rates_total) {
         RawBuffer[i] = 0.5;
         HurstBuffer[i] = 0.5;
         continue;
      }
      
      // --- 1. Calculate RAW Hurst (O(N) optimized on Log Returns) ---
      
      // We need InpWindow returns. This requires InpWindow + 1 prices.
      // Returns: r[k] = log(close[i+k] / close[i+k+1])
      
      double mean_r = 0.0;
      
      // First pass: Calculate Mean of Returns
      // We perform this on the fly to avoid allocating a huge array
      for(int k=0; k<InpWindow; k++) {
          double p_curr = close[i+k];
          double p_prev = close[i+k+1];
          // Log Return
          double r = MathLog(p_curr / p_prev);
          mean_r += r;
      }
      mean_r /= InpWindow;
      
      // Second pass: Calculate Cumulative Deviations (Range) and StdDev
      double sum_sq_diff = 0.0;
      double cumul_dev = 0.0;
      double max_cumul = -DBL_MAX;
      double min_cumul = DBL_MAX;
      
      for(int k=0; k<InpWindow; k++) {
          double p_curr = close[i+k];
          double p_prev = close[i+k+1];
          double r = MathLog(p_curr / p_prev);
          
          double diff = r - mean_r;
          
          // Accumulate deviation for Range (R)
          cumul_dev += diff;
          if(cumul_dev > max_cumul) max_cumul = cumul_dev;
          if(cumul_dev < min_cumul) min_cumul = cumul_dev;
          
          // Accumulate squared diff for StdDev (S)
          sum_sq_diff += diff * diff;
      }
      
      // Standard Deviation of Returns
      double std = MathSqrt(sum_sq_diff / InpWindow);
      if(std < _Point) std = _Point; // Avoid div by zero
      
      // Range of Cumulative Deviations
      double R = max_cumul - min_cumul;
      
      // Rescaled Range
      double RS = R / std;
      
      if(RS <= 0) RS = 0.0001; 
      
      // Optimized Calc using pre-calculated denominator
      // H = log(RS) / (log(n) - log(2))
      double h = MathLog10(RS) / g_log_denominator;
      
      // Clamp
      if(h > 1.0) h = 1.0;
      if(h < 0.0) h = 0.0;
      
      RawBuffer[i] = h;
      
      // --- 2. Calculate SMOOTHED Hurst (SMA) ---
      // We need InpSmoothing bars of RawBuffer.
      // Since we calculate from Past (High Index) to Present (Low Index),
      // Future bars [i-1] are not yet calc, but Past bars [i+1] ARE calc.
      // So we can average RawBuffer[i]...RawBuffer[i+InpSmoothing-1]
      
      if(InpSmoothing <= 1) {
          HurstBuffer[i] = h;
      } else {
          // Check if we have enough Raw History
          // i + InpSmoothing needs to be valid
          if(i + InpSmoothing > rates_total) {
             HurstBuffer[i] = h; // Fallback edge case
          } else {
             double sum = 0.0;
             for(int s=0; s<InpSmoothing; s++) {
                sum += RawBuffer[i+s]; 
             }
             HurstBuffer[i] = sum / InpSmoothing;
          }
      }
   }
   
   return(rates_total);
}
