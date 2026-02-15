//+------------------------------------------------------------------+
//|                                                AuKeltnerKama.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

// --- PLOTS ---
#property indicator_label1  "KAMA (Mid)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDarkGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "Upper Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

// --- INPUTS ---
input group "1. KAMA Settings"
input int InpKama_Period = 10;   // Efficiency Period (ER)
input int InpKama_Fast   = 2;    // Fast EMA Period
input int InpKama_Slow   = 30;   // Slow EMA Period

input group "2. Channel Settings"
input int InpATR_Period  = 14;   // ATR Period
input double InpATR_Mult = 2.5;  // Channel Multiplier
input bool InpLogVerbose = false; // Enable internal indicator logs

// --- BUFFERS ---
double KamaBuffer[];      // Buffer 0
double LowerBuffer[];     // Buffer 1
double UpperBuffer[];     // Buffer 2
double ErBuffer[];        // Buffer 3 (Hidden: Logic Export)

// --- HANDLES & GLOBALS ---
int hATR;

// --- KAMA HELPERS (Inline to avoid Engine dependency in Resource) ---
double CalculateKAMA_SC_Local(double er, int fast_end, int slow_end) {
   double fastSC = 2.0 / (fast_end + 1.0);
   double slowSC = 2.0 / (slow_end + 1.0);
   double sc = er * (fastSC - slowSC) + slowSC;
   return sc * sc;
}
// -------------------------------------------------------------------

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Buffers Mapping
   SetIndexBuffer(0, KamaBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, LowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ErBuffer, INDICATOR_CALCULATIONS); // Not drawn, used for iCustom reading
   
   // 2. Plot Names
   PlotIndexSetString(0, PLOT_LABEL, "KAMA Mid");
   PlotIndexSetString(1, PLOT_LABEL, "Lower Band");
   PlotIndexSetString(2, PLOT_LABEL, "Upper Band");
   
   // 3. Digits
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   // 4. Init ATR Handle
   hATR = iATR(NULL, PERIOD_CURRENT, InpATR_Period);
   if (hATR == INVALID_HANDLE) {
      if (InpLogVerbose) Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }

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
   if (rates_total < InpKama_Period + 2) return 0;
   
   static double atrArr[];
   static double volSum[];
   if (ArraySize(atrArr) < rates_total) ArrayResize(atrArr, rates_total);
   if (ArraySize(volSum) < rates_total) ArrayResize(volSum, rates_total);
   
   int start = InpKama_Period + 1;
   if (prev_calculated > start) start = prev_calculated - 1;
   if (start < 0) start = 0;
   
   // --- 1. CALCUL ATR (only required range) ---
   int atrCount = rates_total - start;
   if (atrCount > 0) {
      double atrTemp[];
      ArrayResize(atrTemp, atrCount);
      if (CopyBuffer(hATR, 0, start, atrCount, atrTemp) <= 0) return 0;
      for (int i = 0; i < atrCount; i++) {
         atrArr[start + i] = atrTemp[i];
      }
   }
   
   int seedIndex = InpKama_Period + 1;
   if (prev_calculated == 0 || start <= seedIndex) {
      // Seed rolling volatility sum
      double vs = 0.0;
      for (int k = 0; k < InpKama_Period; k++) {
         vs += MathAbs(close[seedIndex - k] - close[seedIndex - k - 1]);
      }
      volSum[seedIndex] = vs;
      for (int i = seedIndex + 1; i < rates_total; i++) {
         volSum[i] = volSum[i-1]
                     + MathAbs(close[i] - close[i-1])
                     - MathAbs(close[i - InpKama_Period] - close[i - InpKama_Period - 1]);
      }
      start = seedIndex;
   } else {
      for (int i = start; i < rates_total; i++) {
         volSum[i] = volSum[i-1]
                     + MathAbs(close[i] - close[i-1])
                     - MathAbs(close[i - InpKama_Period] - close[i - InpKama_Period - 1]);
      }
   }
   
   // --- 2. MAIN LOOP ---
   for(int i = start; i < rates_total; i++)
   {
      // A. Efficiency Ratio (ER)
      double change = MathAbs(close[i] - close[i - InpKama_Period]);
      double volatility = volSum[i];
      
      double er = (volatility != 0.0) ? (change / volatility) : 0.0;
      ErBuffer[i] = er;
      
      // B. KAMA
      double sc = CalculateKAMA_SC_Local(er, InpKama_Fast, InpKama_Slow);
      
      double prevK = KamaBuffer[i-1];
      if (prevK == 0.0 && i > 0) prevK = close[i-1]; // Catchup init
      if (prevK == 0.0) prevK = close[i]; // Very first tick
      
      double kama = prevK + sc * (close[i] - prevK);
      KamaBuffer[i] = kama;
      
      // C. Bands
      double atr = atrArr[i];
      double dist = atr * InpATR_Mult;
      
      UpperBuffer[i] = kama + dist;
      LowerBuffer[i] = kama - dist;
   }
   
   return(rates_total);
}

void OnDeinit(const int reason)
{
   if (hATR != INVALID_HANDLE) {
      IndicatorRelease(hATR);
      hATR = INVALID_HANDLE;
   }
}
//+------------------------------------------------------------------+
