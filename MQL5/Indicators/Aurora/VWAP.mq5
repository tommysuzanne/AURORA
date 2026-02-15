//+------------------------------------------------------------------+
//|                                                         VWAP.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- plot VWAP
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot Upper
#property indicator_label2  "VWAP Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- plot Lower
#property indicator_label3  "VWAP Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- input parameters
input double   InpDeviation   = 2.5;     // Standard Deviation Multiplier

//--- indicator buffers
double         VWAPBuffer[];
double         UpperBuffer[];
double         LowerBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, UpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowerBuffer, INDICATOR_DATA);
   
   //--- name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VWAP(%.1f SD)", InpDeviation));
   
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
   int start = prev_calculated;
   if(start > 0) start--; // Recalculate last bar
   if(start < 0) start = 0;
   
   static double cumVol[];
   static double cumPV[];
   static double cumPV2[];
   
   if (ArraySize(cumVol) < rates_total) {
      ArrayResize(cumVol, rates_total);
      ArrayResize(cumPV, rates_total);
      ArrayResize(cumPV2, rates_total);
   }
   
   for(int i = start; i < rates_total; i++)
   {
      double price = (high[i] + low[i] + close[i]) / 3.0; // Typical Price
      double vol = (double)tick_volume[i];
      if(vol <= 0) vol = 1.0; // Safety for Forex volume gaps
      
      bool newDay = (i == 0);
      if(i > 0) {
         MqlDateTime dtCurrent, dtPrev;
         TimeToStruct(time[i], dtCurrent);
         TimeToStruct(time[i-1], dtPrev);
         if(dtCurrent.day != dtPrev.day) newDay = true;
      }
      
      if(newDay) {
         cumVol[i] = vol;
         cumPV[i] = price * vol;
         cumPV2[i] = price * price * vol;
      } else {
         cumVol[i] = cumVol[i-1] + vol;
         cumPV[i] = cumPV[i-1] + price * vol;
         cumPV2[i] = cumPV2[i-1] + price * price * vol;
      }
      
      double vwap = (cumVol[i] > 0.0) ? (cumPV[i] / cumVol[i]) : price;
      VWAPBuffer[i] = vwap;
      
      double variance = 0.0;
      if(cumVol[i] > 0.0) {
         variance = (cumPV2[i] / cumVol[i]) - (vwap * vwap);
         if(variance < 0.0) variance = 0.0;
      }
      double stdDev = MathSqrt(variance);
      
      UpperBuffer[i] = vwap + InpDeviation * stdDev;
      LowerBuffer[i] = vwap - InpDeviation * stdDev;
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
