//+------------------------------------------------------------------+
//|                                     aurora_confidence_engine.mqh |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#include <aurora_inputs_structs.mqh>
#include <aurora_logger.mqh>

//+------------------------------------------------------------------+
//| Class CAuroraConfidenceEngine                                    |
//| Gestionnaire de risque dynamique basé sur la qualité du marché   |
//+------------------------------------------------------------------+
class CAuroraConfidenceEngine
{
private:
   bool     m_enable;
   double   m_min_factor;
   double   m_max_factor;
   double   m_last_score; // Cached score for dashboard
   
   double   m_w_er;
   double   m_w_slope;
   double   m_w_vol;
   
   int      m_er_period;
   int      m_slope_period;
   
   int      m_atr_handle_short;
   int      m_atr_handle_long;
   
   // Buffers internes pour calculs
   double   m_buf_atr_short[];
   double   m_buf_atr_long[];

public:
   CAuroraConfidenceEngine();
   ~CAuroraConfidenceEngine();
   
   void Configure(const SDynamicRiskInputs &params);
   void InitIndicators(string symbol, ENUM_TIMEFRAMES timeframe);
   
   double GetConfidenceMultiplier(string symbol, ENUM_TIMEFRAMES timeframe, const double &zlsma_buffer[]);
   double GetLastScore() const { return m_last_score; }

private:
   double CalcEfficiencyRatio(string symbol, ENUM_TIMEFRAMES timeframe);
   double CalcTrendStability(const double &zlsma_buffer[], string symbol);
   double CalcVolatilityScore(string symbol, ENUM_TIMEFRAMES timeframe);
   
   double NormalizeScore(double raw, double min, double max);
   double Map(double val, double in_min, double in_max, double out_min, double out_max);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAuroraConfidenceEngine::CAuroraConfidenceEngine()
   : m_enable(false),
     m_min_factor(0.5),
     m_max_factor(1.5),
     m_last_score(0.5),
     m_atr_handle_short(INVALID_HANDLE),
     m_atr_handle_long(INVALID_HANDLE)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAuroraConfidenceEngine::~CAuroraConfidenceEngine()
{
   if(m_atr_handle_short != INVALID_HANDLE) IndicatorRelease(m_atr_handle_short);
   if(m_atr_handle_long != INVALID_HANDLE)  IndicatorRelease(m_atr_handle_long);
}

//+------------------------------------------------------------------+
//| Configure                                                        |
//+------------------------------------------------------------------+
void CAuroraConfidenceEngine::Configure(const SDynamicRiskInputs &params)
{
   m_enable       = params.enable;
   m_min_factor   = params.min_risk_factor;
   m_max_factor   = params.max_risk_factor;
   m_w_er         = params.weight_efficiency;
   m_w_slope      = params.weight_trend_stability;
   m_w_vol        = params.weight_volatility;
   m_er_period    = params.er_period;
   m_slope_period = params.zlsma_slope_period;
}

//+------------------------------------------------------------------+
//| InitIndicators                                                   |
//+------------------------------------------------------------------+
void CAuroraConfidenceEngine::InitIndicators(string symbol, ENUM_TIMEFRAMES timeframe)
{
   if(!m_enable) return;
   
   // ATR Court (Réactivité)
   if(m_atr_handle_short == INVALID_HANDLE)
      m_atr_handle_short = iATR(symbol, timeframe, 14);
      
   // ATR Long (Contexte)
   if(m_atr_handle_long == INVALID_HANDLE)
      m_atr_handle_long = iATR(symbol, timeframe, 100);
      
   if(m_atr_handle_short == INVALID_HANDLE || m_atr_handle_long == INVALID_HANDLE)
      if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
         CAuroraLogger::ErrorGeneral("ConfidenceEngine: Failed to init ATR handles.");
}

//+------------------------------------------------------------------+
//| GetConfidenceMultiplier                                          |
//| Retourne le facteur de risque (ex: 1.2 pour +20%)                |
//+------------------------------------------------------------------+
double CAuroraConfidenceEngine::GetConfidenceMultiplier(string symbol, ENUM_TIMEFRAMES timeframe, const double &zlsma_buffer[])
{
   if(!m_enable) return 1.0;
   
   // 1. Efficiency Ratio (0.0 - 1.0)
   double scoreER = CalcEfficiencyRatio(symbol, timeframe);
   
   // 2. Trend Stability (0.0 - 1.0+)
   double scoreSlope = CalcTrendStability(zlsma_buffer, symbol);
   
   // 3. Volatility Regime (0.0 - 1.0)
   double scoreVol = CalcVolatilityScore(symbol, timeframe);
   
   // Pondération
   double totalScore = (scoreER * m_w_er) + (scoreSlope * m_w_slope) + (scoreVol * m_w_vol);
   double totalWeight = m_w_er + m_w_slope + m_w_vol;
   
   if(totalWeight <= 0) return 1.0;
   
   double finalScoreNormalized = totalScore / totalWeight; // 0.0 à 1.0 (théorique)
   
   // Mapping vers facteur de risque
   // On considère que 0.5 (score moyen) = facteur 1.0 (neutre)
   // Score < 0.5 -> Réduction
   // Score > 0.5 -> Augmentation
   
   m_last_score = finalScoreNormalized; // Store for dashboard

   // Mapping plus fin:
   // Score 0.0 -> MinFactor
   // Score 0.5 -> 1.0
   // Score 1.0 -> MaxFactor
   
   double riskFactor = 1.0;
   if(finalScoreNormalized < 0.5)
   {
      // Interpolation linéaire entre Min et 1.0
      riskFactor = Map(finalScoreNormalized, 0.0, 0.5, m_min_factor, 1.0);
   }
   else
   {
      // Interpolation linéaire entre 1.0 et Max
      riskFactor = Map(finalScoreNormalized, 0.5, 1.0, 1.0, m_max_factor);
   }
   
   if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
   {
      CAuroraLogger::InfoStrategy(StringFormat("[SMART CONFIDENCE] ER: %.2f | Slope: %.2f | Vol: %.2f => Score: %.2f => Multiplier: x%.2f", 
         scoreER, scoreSlope, scoreVol, finalScoreNormalized, riskFactor));
   }
   
   return riskFactor;
}

//+------------------------------------------------------------------+
//| Helper: Map                                                      |
//+------------------------------------------------------------------+
double CAuroraConfidenceEngine::Map(double val, double in_min, double in_max, double out_min, double out_max)
{
   if(in_max - in_min == 0) return out_min;
   return out_min + (val - in_min) * (out_max - out_min) / (in_max - in_min);
}

//+------------------------------------------------------------------+
//| CalcEfficiencyRatio (Kaufman)                                    |
//+------------------------------------------------------------------+
double CAuroraConfidenceEngine::CalcEfficiencyRatio(string symbol, ENUM_TIMEFRAMES timeframe)
{
   int period = m_er_period;
   if(period < 1) period = 10;
   
   double prices[];
   if(CopyClose(symbol, timeframe, 1, period + 1, prices) < period + 1) return 0.5;
   
   double netChange = MathAbs(prices[period] - prices[0]);
   double sumChange = 0.0;
   
   for(int i = 0; i < period; i++)
   {
      sumChange += MathAbs(prices[i+1] - prices[i]);
   }
   
   if(sumChange == 0) return 1.0;
   return netChange / sumChange;
}

//+------------------------------------------------------------------+
//| CalcTrendStability (ZLSMA Slope)                                 |
//+------------------------------------------------------------------+
double CAuroraConfidenceEngine::CalcTrendStability(const double &zlsma_buffer[], string symbol)
{
   // Nécessite au moins slope_period + 1 valeurs
   if(ArraySize(zlsma_buffer) < m_slope_period + 3) return 0.5; // +3 sécurité index
   
   // Pente sur N périodes
   // Index 1 est le plus récent fermé
   double currentZ = zlsma_buffer[1];
   double prevZ    = zlsma_buffer[1 + m_slope_period];
   
   double slopeAbs = MathAbs(currentZ - prevZ);
   
   // Normalisation par ATR (pour être indépendant de la paire)
   // On utilise l'ATR court pour avoir l'échelle locale
   double atr = 0;
   double bufAtr[];
   if(CopyBuffer(m_atr_handle_short, 0, 1, 1, bufAtr) > 0) atr = bufAtr[0];
   if(atr == 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100;
   
   double normalizedSlope = slopeAbs / atr;
   
   // Interprétation:
   // Slope/ATR > 1.0 sur la période = Tendance très forte
   // Slope/ATR < 0.2 = Plat
   
   // Clamp à 1.0 pour le score
   if(normalizedSlope > 1.0) return 1.0;
   return normalizedSlope; 
}

//+------------------------------------------------------------------+
//| CalcVolatilityScore (Relative ATR)                               |
//+------------------------------------------------------------------+
double CAuroraConfidenceEngine::CalcVolatilityScore(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double shortATR=0, longATR=0;
   double bufS[], bufL[];
   
   if(CopyBuffer(m_atr_handle_short, 0, 1, 1, bufS) <= 0) return 0.5;
   if(CopyBuffer(m_atr_handle_long, 0, 1, 1, bufL) <= 0) return 0.5;
   
   shortATR = bufS[0];
   longATR = bufL[0];
   
   if(longATR == 0) return 0.5;
   
   double ratio = shortATR / longATR;
   
   // Goldilocks zone logic:
   // Trop calme (< 0.5) = Score faible (0.2)
   // Normal (0.8 - 1.2) = Score haut (1.0)
   // Panique (> 2.0) = Score faible (0.0)
   
   if(ratio < 0.5) return 0.3; // Marché mort
   if(ratio > 2.0) return 0.0; // Krach/News violent
   
   // Zone idéale autour de 1.0
   if(ratio >= 0.8 && ratio <= 1.2) return 1.0;
   
   // Dégradé pour le reste
   if(ratio < 0.8) return Map(ratio, 0.5, 0.8, 0.3, 1.0);
   if(ratio > 1.2) return Map(ratio, 1.2, 2.0, 1.0, 0.0);
   
   return 0.5;
}
