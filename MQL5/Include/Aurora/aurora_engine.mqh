//+------------------------------------------------------------------+
//|                                                    Aurora Engine |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_ENGINE_MQH__
#define __AURORA_ENGINE_MQH__

#include <Aurora/aurora_constants.mqh>
#include <Aurora/aurora_time.mqh>
#include <Aurora/aurora_error_utils.mqh>
#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_snapshot.mqh>

#include <Aurora/aurora_types.mqh>
#include <Aurora/aurora_virtual_stops.mqh>

class CVirtualStopManager; // Legacy Forward Declaration (safe to keep)

#define AURORA_EAUTILS_VERSION "1.45"

namespace AuroraTimeHelper
{
  // retourne 0=lundi … 6=dimanche
  inline int DayIndexMondayZero(const datetime t)
  {
    return AuroraClock::DayIndexMondayZero(t);
  }

  inline int MinutesOfDay(const datetime t)
  {
    return AuroraClock::MinutesOfDay(t);
  }

  inline int MinutesOfWeek(const datetime t)
  {
    MqlDateTime dt; TimeToStruct(t, dt);
    return dt.day_of_week*1440 + dt.hour*60 + dt.min;
  }

  inline datetime TradeNow(const datetime candidate = 0)
  {
    return AuroraClock::Now(candidate);
  }
}

// --- ENUMS ---
// --- ENUMS ---
// ENUM_SL deleted (Moved to Types or deprecated)

// --- UTILS & HELPERS (Low Level) ---

// --- PRECISION HELPERS ---
#define DB_EPSILON 0.0000001

bool IsEqual(double a, double b) { return MathAbs(a - b) < DB_EPSILON; }
bool IsNotEqual(double a, double b) { return !IsEqual(a, b); }
bool IsZero(double a) { return MathAbs(a) < DB_EPSILON; }
bool IsGreater(double a, double b) { return a > b + DB_EPSILON; }
bool IsLess(double a, double b) { return a < b - DB_EPSILON; }
bool IsGreaterOrEqual(double a, double b) { return a >= b - DB_EPSILON; }
bool IsLessOrEqual(double a, double b) { return a <= b + DB_EPSILON; }

template<typename T>
int ArraySearch(const T &arr[], T value) {
    int n = ArraySize(arr);
    for (int i = 0; i < n; i++) {
        if (arr[i] == value)
            return i;
    }
    return -1;
}

template<typename T>
int ArrayAdd(T &arr[], T value) {
    int n = ArrayResize(arr, ArraySize(arr) + 1);
    arr[n - 1] = value;
    return n;
}

string Trim(string s) {
    string str = s + " ";
    StringTrimLeft(str);
    StringTrimRight(str);
    return str;
}

string NormalizeCurrencyList(const string raw) {
    string formatted = raw;
    StringReplace(formatted, " ", "");
    StringToUpper(formatted);
    return formatted;
}

int CountDigits(double val, int maxPrecision = 8) {
    int digits = 0;
    while (NormalizeDouble(val, digits) != NormalizeDouble(val, maxPrecision))
        digits++;
    return digits;
}

// Ensure price is a multiple of TickSize
double NormalizePrice(double price, string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tickSize == 0) return NormalizeDouble(price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    return NormalizeDouble(MathRound(price / tickSize) * tickSize, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

// Directional tick alignment (safer for SL against broker minimum distance checks)
double NormalizePriceDown(double price, string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tickSize <= 0.0) return NormalizeDouble(price, digits);
    return NormalizeDouble(MathFloor((price + 1e-12) / tickSize) * tickSize, digits);
}

double NormalizePriceUp(double price, string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tickSize <= 0.0) return NormalizeDouble(price, digits);
    return NormalizeDouble(MathCeil((price - 1e-12) / tickSize) * tickSize, digits);
}

double NormalizeStopForPosition(double sl, const bool isBuyPosition, string symbol = NULL) {
    return isBuyPosition ? NormalizePriceDown(sl, symbol) : NormalizePriceUp(sl, symbol);
}

// --- MARKET INFO HELPERS ---

struct STickCache {
    MqlTick tick;
    string  symbol;
    long    time_msc;
    bool    valid;
};

STickCache g_tick_cache;

bool UpdateTickCache(string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    MqlTick t;
    if (!SymbolInfoTick(symbol, t)) {
        g_tick_cache.valid = false;
        return false;
    }
    g_tick_cache.tick = t;
    g_tick_cache.symbol = symbol;
    g_tick_cache.time_msc = t.time_msc;
    g_tick_cache.valid = true;
    return true;
}

bool GetTickCached(string symbol, MqlTick &out) {
    if (symbol == NULL) symbol = _Symbol;
    if (g_tick_cache.valid && g_tick_cache.symbol == symbol) {
        out = g_tick_cache.tick;
        return true;
    }
    return SymbolInfoTick(symbol, out);
}

double Ask(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    MqlTick tick;
    if (!GetTickCached(name, tick))
        return 0;
    return tick.ask;
}

double Bid(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    MqlTick tick;
    if (!GetTickCached(name, tick))
        return 0;
    return tick.bid;
}

int Spread(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    MqlTick tick;
    if (!GetTickCached(name, tick))
        return (int) SymbolInfoInteger(name, SYMBOL_SPREAD);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);
    if (point <= 0) return (int) SymbolInfoInteger(name, SYMBOL_SPREAD);
    return (int)MathRound((tick.ask - tick.bid) / point);
}

int MinBrokerPoints(const string symbol)
{
   int stops  = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int mp = (int)MathMax((double)stops, (double)freeze);
   if(mp < 1) mp = 1;
   return mp;
}

double g_tickValueCache = 0.0;
string g_tickValueSymbol = "";

void InitTickValue(string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    g_tickValueSymbol = symbol;
    
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double profit = 0;
    
    // Attempt precise calculation via OrderCalcProfit
    if (OrderCalcProfit(ORDER_TYPE_BUY, symbol, 1, price, price + tickSize, profit) && profit > 0) {
        g_tickValueCache = profit;
    } else {
        // Fallback
        g_tickValueCache = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    }
    
    // Log pour validation
    if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
        CAuroraLogger::InfoGeneral(StringFormat("[INIT] TickValue cached for %s: %.5f", symbol, g_tickValueCache));
}

double GetTickValue(string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    
    // Utiliser le cache si correspond au symbole principal
    if (symbol == g_tickValueSymbol && g_tickValueCache > 0.0) {
        return g_tickValueCache;
    }
    
    // Fallback dynamique pour autres symboles ou si cache non init
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double profit = 0;
    if (OrderCalcProfit(ORDER_TYPE_BUY, symbol, 1, price, price + tickSize, profit) && profit > 0)
        return profit;
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

double High(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    return iHigh(symbol, timeframe, i);
}

double Low(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    return iLow(symbol, timeframe, i);
}

double Open(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    return iOpen(symbol, timeframe, i);
}

double Close(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    return iClose(symbol, timeframe, i);
}

datetime Time(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    return iTime(symbol, timeframe, i);
}

double Ind(int handle, int i, int buffer_index = 0) {
    double B[1];
    if (handle <= 0) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC)) CAuroraLogger::ErrorDiag(StringFormat("Error (%s, handle): #%d", __FUNCTION__, GetLastError()));
        return -1;
    }
    if (CopyBuffer(handle, buffer_index, i, 1, B) != 1) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC)) CAuroraLogger::ErrorDiag(StringFormat("Error (%s, CopyBuffer): #%d", __FUNCTION__, GetLastError()));
        return -1;
    }
    return B[0];
}

// --- MARKET METRICS (Dynamic Indicators Infrastructure) ---

// Calculates Kaufman Efficiency Ratio (ER)
// Result: 1.0 (Trend) to 0.0 (Noise)
// Formula: |Price - Price(N)| / Sum(|Price(i) - Price(i-1)|)
double CalculateEfficiencyRatio(string symbol, int period, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, int start_index = 0) {
    if (period < 1) return 0.0;
    
    // Optimization: Use CopyClose to get all needed data in one call
    // We need 'period + 1' values to calculate 'period' changes.
    // Index 0 in local buffer = oldest, Index 'period' = newest (start_index)
    
    double prices[];
    // CopyClose args: symbol, timeframe, start_pos, count, buffer
    // start_pos = start_index (e.g. 1 means close[1] is the newest)
    // count = period + 1 (e.g. period 10 means we need close[1]...close[11])
    if (CopyClose(symbol, timeframe, start_index, period + 1, prices) < period + 1) return 0.5; // Default safe value
    
    // prices array is sorted [0]=Oldest (Index period+start), [period]=Newest (Index start)
    // Net Change: |Price(Newest) - Price(Oldest)|
    double netChange = MathAbs(prices[period] - prices[0]);
    
    double volatilitySum = 0.0;
    for (int i = 1; i <= period; i++) {
        // Change between adjacent bars
        volatilitySum += MathAbs(prices[i] - prices[i-1]);
    }
    
    if (volatilitySum == 0.0) return 1.0; // Pure Trend (Straight line)
    
    double er = netChange / volatilitySum;
    return MathMin(1.0, MathMax(0.0, er));
}

// Calculates the Smoothing Constant (SC) for KAMA
// ER: Efficiency Ratio [0..1]
// fast_end: Fast EMA period (e.g. 2)
// slow_end: Slow EMA period (e.g. 30)
// Formula: SC = [ER * (fastSC - slowSC) + slowSC]^2
double CalculateKAMA_SC(double er, int fast_end = 2, int slow_end = 30) {
    // SC = 2 / (N + 1)
    double fastSC = 2.0 / (fast_end + 1.0);
    double slowSC = 2.0 / (slow_end + 1.0);
    
    double sc = er * (fastSC - slowSC) + slowSC;
    return sc * sc; // Square it
}

// Calculates KAMA value manually
// prevKama: The previous KAMA value
// price: Current price
// sc: The Smoothing Constant calculated via CalculateKAMA_SC
// Formula: KAMA = PrevKAMA + SC * (Price - PrevKAMA)
double CalculateKAMA_Manual(double price, double prevKama, double sc) {
    if (prevKama == 0.0) return price; // Init
    return prevKama + sc * (price - prevKama);
}

// Helper for manual ATR calculation (Simple Moving Average of True Range)
// Used for Volatility Ratio to avoid persistent handle management for auxiliary metrics
double CalculateATR(string symbol, int period, int shift = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    if (period <= 0) return 0.0;
    
    double trSum = 0.0;
    for (int i = 0; i < period; i++) {
        int idx = shift + i;
        double high = iHigh(symbol, timeframe, idx);
        double low  = iLow(symbol, timeframe, idx);
        double closePrev = iClose(symbol, timeframe, idx + 1);
        
        double tr1 = high - low;
        double tr2 = MathAbs(high - closePrev);
        double tr3 = MathAbs(low - closePrev);
        
        double tr = MathMax(tr1, MathMax(tr2, tr3));
        trSum += tr;
    }
    
    return trSum / period;
}

// Calculates Volatility Ratio (Short term volatility / Long term volatility)
// Result > 1.0 : Expanding Volatility (Price breaking out or crashing)
// Result < 1.0 : Contracting Volatility (Calm / Range)
double CalculateVolatilityRatio(string symbol, int shortPeriod, int longPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    double atrShort = CalculateATR(symbol, shortPeriod, 0, timeframe);
    double atrLong  = CalculateATR(symbol, longPeriod, 0, timeframe);
    
    if (atrLong <= 0.0) return 1.0;
    return atrShort / atrLong;
}

// Calculates Noise Factor from Efficiency Ratio
// Formula: 1.0 + (1.0 - ER)
// Range: 1.0 (Clean Trend) to 2.0 (Pure Noise)
double CalculateNoiseFactor(double er) {
    // ER is 0.0 (Noise) -> 1.0 + (1.0 - 0.0) = 2.0
    // ER is 1.0 (Trend) -> 1.0 + (1.0 - 1.0) = 1.0
    return 1.0 + (1.0 - er);
}

// Applies Exponential Smoothing to any value
// prev: The value used in the previous step
// curr: The raw calculated value for this step
// factor: Smoothing factor (0.1 means 10% weight to new, 90% history)
double SmoothValue(double prev, double curr, double factor = 0.1) {
    if (prev <= 0) return curr; // Init
    return (prev * (1.0 - factor)) + (curr * factor);
}

// --- DYNAMIC ZLSMA LOGIC ---

// Calculates the target period based on Efficiency Ratio
// ER = 1.0 (Trend) -> MinPeriod (Fast)
// ER = 0.0 (Noise) -> MaxPeriod (Slow/Flat)
double CalculateDynamicPeriodFromER(double er, int minPeriod, int maxPeriod) {
    // Formula: CurrentPeriod = MinPeriod + (MaxPeriod - MinPeriod) * (1.0 - ER)
    return minPeriod + (maxPeriod - minPeriod) * (1.0 - er);
}



// Helper: Linear Regression Moving Average (LRMA) for specific index from Symbol
// Formula: 3*WMA - 2*SMA
double CalculateLRMA(string symbol, int period, int shift, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    if (period <= 1) return iClose(symbol, timeframe, shift);
    
    double sum = 0.0;
    double wsum = 0.0;
    double weightSum = 0.0;
    
    // Optimization: Calculate sums in one pass
    for (int i = 0; i < period; i++) {
        double price = iClose(symbol, timeframe, shift + i);
        sum += price;
        wsum += price * (period - i);
        weightSum += (period - i);
    }
    
    if (weightSum == 0) return sum / period;

    double sma = sum / period;
    double wma = wsum / weightSum;
    
    return 3.0 * wma - 2.0 * sma;
}

// Helper: Linear Regression Moving Average (LRMA) from Memory Buffer
// Used for the second pass of ZLSMA (LRMA of LRMA)
double CalculateLRMA_Array(const double &arr[], int period) {
    if (period <= 1) return arr[0];
    if (ArraySize(arr) < period) return 0.0;
    
    double sum = 0.0;
    double wsum = 0.0;
    double weightSum = 0.0;
    
    for (int i = 0; i < period; i++) {
        double val = arr[i]; // arr[0] is newest
        sum += val;
        wsum += val * (period - i);
        weightSum += (period - i);
    }
    
    if (weightSum == 0) return sum / period;

    double sma = sum / period;
    double wma = wsum / weightSum;
    
    return 3.0 * wma - 2.0 * sma;
}

// Helper: Linear Regression Moving Average (LRMA) from Memory Buffer with Shift
// Used for First Pass on Price Array
double CalculateLRMA_OnBuffer(const double &arr[], int start_idx, int period) {
    if (period <= 1) return arr[start_idx];
    
    // Safety check size? Caller responsible for efficiency.
    
    double sum = 0.0;
    double wsum = 0.0;
    double weightSum = 0.0;
    
    for (int i = 0; i < period; i++) {
        double val = arr[start_idx + i]; 
        sum += val;
        wsum += val * (period - i);
        weightSum += (period - i);
    }
    
    if (weightSum == 0) return sum / period;

    double sma = sum / period;
    double wma = wsum / weightSum;
    
    return 3.0 * wma - 2.0 * sma;
}

// Helper: Linear Regression Moving Average (LRMA) from Memory Buffer (Series Optimized)
// Used for both Inner and Outer Loop of ZLSMA
// Formula: 3*WMA - 2*SMA
double CalculateLRMA_Series(const double &arr[], int start_idx, int period) {
    if (period <= 1) return arr[start_idx];
    // Safety check: arr must handle start_idx + period
    if (start_idx + period > ArraySize(arr)) return arr[start_idx]; // Fallback
    
    double sum = 0.0;
    double wsum = 0.0;
    double weightSum = 0.0;
    
    // LRMA(i) = 3*WMA(i) - 2*SMA(i)
    // WMA uses linear weights: newest (start_idx) has weight 'period', oldest has weight '1'
    
    for (int i = 0; i < period; i++) {
        double val = arr[start_idx + i];
        int weight = period - i;
        
        sum += val;
        wsum += val * weight;
        weightSum += weight;
    }
    
    if (weightSum == 0) return sum / period; // Should not happen

    double sma = sum / (double)period;
    double wma = wsum / weightSum;
    
    return 3.0 * wma - 2.0 * sma;
}

// Calculates ZLSMA manually using the correct Double-Smoothing algorithm (Vectorized)
// Optimization: Vectorized Read (Pass Array) instead of N^2 CopyClose calls.
// Original Formula: B2=LRMA(Price); ZLSMA = 2*B2 - LRMA(B2)
// NOTE: expects 'prices' to be AS_SERIES (Newest at index 0)!
double CalculateZLSMA_Manual(const double &prices[], int period, int shift) {
    if (period < 1) return prices[shift];
    
    int total_bars = ArraySize(prices);
    // We need 'period' values of Inner LRMA to calculate 1 Outer LRMA
    // Inner LRMA[0] needs prices[shift ... shift+period]
    // Inner LRMA[period-1] needs prices[shift+period-1 ... shift+2*period-1]
    
    if (shift + 2 * period > total_bars) return prices[shift]; // Not enough history
    
    // 1. Calculate the 'inner' LRMA (B2) for the current point (Index 0 relative to shift)
    double innerLRMA_Current = CalculateLRMA_Series(prices, shift, period);
    
    // 2. To calculate LRMA(B2), we need PREVIOUS values of B2 (history).
    // B2[i] = LRMA(prices, shift+i, period)
    // We need B2 from i=0 to p-1
    
    // Optimization: Compute the Sums for LRMA(B2) directly? No, LRMA is weighted.
    // We must generate the temporary B2 buffer.
    double b2_history[];
    ArrayResize(b2_history, period);
    
    for(int i=0; i<period; i++) {
        b2_history[i] = CalculateLRMA_Series(prices, shift + i, period);
    }
    
    // 3. Calculate outer LRMA from b2_history (0 is newest)
    double outerLRMA = CalculateLRMA_Series(b2_history, 0, period);
    
    return 2.0 * innerLRMA_Current - outerLRMA;
}

// --- DYNAMIC CHANDELIER EXIT LOGIC ---

// --- DYNAMIC CHANDELIER EXIT LOGIC ---

// Calculates the dynamic multiplier for Chandelier Exit based on Volatility Ratio
// VolRatio > 1.0 (High Vol) -> Multiplier Increases (Wider Stop)
// VolRatio < 1.0 (Low Vol) -> Multiplier Decreases (Tighter Stop)
double CalculateDynamicMultiplierFromVolRatio(double volRatio, double baseMult, double minMult, double maxMult) {
    // Formula: DynamicMult = BaseMult * VolRatio
    // Bounded by [MinMult, MaxMult]
    double dynamicMult = baseMult * volRatio;
    return MathMin(maxMult, MathMax(minMult, dynamicMult));
}

// Helper: Highest High over N periods (Generic Source)
double CalculateHighestHigh(const double &highArr[], int period, int shift) {
    if (period <= 0 || shift + period > ArraySize(highArr)) return 0.0;
    
    double maxVal = -DBL_MAX;
    for(int i=0; i<period; i++) {
        if(highArr[shift+i] > maxVal) maxVal = highArr[shift+i];
    }
    return maxVal;
}

// Helper: Lowest Low over N periods (Generic Source)
double CalculateLowestLow(const double &lowArr[], int period, int shift) {
     if (period <= 0 || shift + period > ArraySize(lowArr)) return 0.0;
     
     double minVal = DBL_MAX;
     for(int i=0; i<period; i++) {
         if(lowArr[shift+i] < minVal) minVal = lowArr[shift+i];
     }
     return minVal;
}

// Calculates Chandelier Exit stops manually for Dynamic Mode
// Note: To match the original indicator behavior which uses Heiken Ashi inputs,
// we must perform the calculation on the Heiken Ashi Highs and Lows if available, or fallback to standard High/Low.
// CURRENT DECISION: We use STANDARD High/Low for safety in the Engine implementation (Wick Protection on real price).
// The indicator uses HA which smooths wicks, potentially hiding real price danger.
// By using Real Price High/Low here, we are slightly more conservative/safe than the indicator.
void CalculateChandelierExit_Manual(string symbol, int lookbackPeriod, int atrPeriod, double multiplier, int shift, double &outLongStop, double &outShortStop, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    // We use standard iHigh/iLow for robustness against real price wicks
    // (Deviation from Indicator which uses HA, but intentional for safety)
    int highestIndex = iHighest(symbol, timeframe, MODE_HIGH, lookbackPeriod, shift);
    int lowestIndex  = iLowest(symbol, timeframe, MODE_LOW, lookbackPeriod, shift);
    
    double highest = (highestIndex != -1) ? iHigh(symbol, timeframe, highestIndex) : iHigh(symbol, timeframe, shift);
    double lowest  = (lowestIndex != -1) ? iLow(symbol, timeframe, lowestIndex) : iLow(symbol, timeframe, shift);

    // Note: We use the Manual ATR helper defined earlier
    double atr = CalculateATR(symbol, atrPeriod, shift, timeframe);
    
    outLongStop  = highest - (atr * multiplier);
    outShortStop = lowest + (atr * multiplier);
}

// --- ACCOUNT & RISK HELPERS ---

// --- VIRTUAL BALANCE SIMULATION HELPERS ---
double GetSimulatedBalance(double virtualBalance) {
    return virtualBalance;
}

double GetSimulatedEquity(double virtualBalance) {
    double realBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double realEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatingPL = realEquity - realBalance;
    return virtualBalance + floatingPL;
}



double ResolveRiskBalance(double balanceOverride, ENUM_RISK risk_mode) {
    if (balanceOverride > 0)
        return GetSimulatedBalance(balanceOverride); // Force Fixed Virtual Balance

    if (risk_mode == RISK_DEFAULT || risk_mode == RISK_FIXED_VOL || risk_mode == RISK_MIN_AMOUNT)
        return MathMin(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    return AccountInfoDouble((ENUM_ACCOUNT_INFO_DOUBLE)((int)risk_mode));
}

double ClampVolumeToSymbol(double vol, const string symbol, double maxLotLimit = -1) {
    double volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    int volDigits = CountDigits(volStep);
    if (volStep > 0)
        vol = MathFloor(vol / volStep) * volStep;
    vol = MathMax(vol, volMin);
    if (maxLotLimit > 0)
        vol = MathMin(vol, maxLotLimit);
    vol = MathMin(vol, volMax);
    return NormalizeDouble(vol, volDigits);
}

// --- ORDER & POSITION COUNTING HELPERS ---

int positionsTotalMagic(ulong magic, string name = NULL) {
    int cnt = 0;
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        cnt++;
    }
    return cnt;
}

double positionsTotalVolume(ulong magic, string name = NULL) {
    double totalVol = 0.0;
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        totalVol += PositionGetDouble(POSITION_VOLUME);
    }
    return totalVol;
}

int ordersTotalMagic(ulong magic, string name = NULL) {
    int cnt = 0;
    int total = OrdersTotal();
    for (int i = 0; i < total; i++) {
        ulong oticket = OrderGetTicket(i);
        ulong omagic = OrderGetInteger(ORDER_MAGIC);
        string osymbol = OrderGetString(ORDER_SYMBOL);
        if (omagic != magic) continue;
        if (name != NULL && osymbol != name) continue;
        cnt++;
    }
    return cnt;
}

double ordersTotalVolume(ulong magic, string name = NULL) {
    double totalVol = 0.0;
    int total = OrdersTotal();
    for (int i = 0; i < total; i++) {
        ulong oticket = OrderGetTicket(i);
        ulong omagic = OrderGetInteger(ORDER_MAGIC);
        string osymbol = OrderGetString(ORDER_SYMBOL);
        if (omagic != magic) continue;
        if (name != NULL && osymbol != name) continue;
        ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if (otype == ORDER_TYPE_BUY || otype == ORDER_TYPE_SELL) continue;
        totalVol += OrderGetDouble(ORDER_VOLUME_CURRENT);
    }
    return totalVol;
}

int positionsTickets(ulong magic, ulong &arr[], string name = NULL) {
    int total = PositionsTotal();
    ArrayResize(arr, total); // Optimization: Single allocation
    int j = 0;
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        // ArrayResize(arr, j + 1); // REMOVED: Inefficient
        arr[j] = pticket;
        j++;
    }
    ArrayResize(arr, j); // Resize down to actual count
    return j;
}

int ordersTickets(ulong magic, ulong &arr[], string name = NULL) {
    int total = OrdersTotal();
    ArrayResize(arr, total); // Optimization: Single allocation
    int j = 0;
    for (int i = 0; i < total; i++) {
        ulong oticket = OrderGetTicket(i);
        ulong omagic = OrderGetInteger(ORDER_MAGIC);
        string osymbol = OrderGetString(ORDER_SYMBOL);
        if (omagic != magic) continue;
        if (name != NULL && osymbol != name) continue;
        // ArrayResize(arr, j + 1); // REMOVED
        arr[j] = oticket;
        j++;
    }
    ArrayResize(arr, j); 
    return j;
}

int opTotalMagic(ulong magic, string name = NULL) {
    int cnt, n;
    ulong ots[], pts[], opts[];
    ordersTickets(magic, ots, name);
    positionsTickets(magic, pts, name);
    cnt = 0;
    n = ArraySize(ots);
    for (int i = 0; i < n; i++) {
        if (ArraySearch(opts, ots[i]) != -1) continue;
        ArrayResize(opts, cnt + 1);
        opts[cnt] = ots[i];
        cnt++;
    }
    n = ArraySize(pts);
    for (int i = 0; i < n; i++) {
        if (ArraySearch(opts, pts[i]) != -1) continue;
        ArrayResize(opts, cnt + 1);
        opts[cnt] = pts[i];
        cnt++;
    }
    return cnt;
}

int positionsDouble(ENUM_POSITION_PROPERTY_DOUBLE prop, ulong magic, double &arr[], string name = NULL) {
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    ArrayResize(arr, n);
    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        arr[i] = PositionGetDouble(prop);
    }
    return n;
}

int positionsVolumes(ulong magic, double &arr[], string name = NULL) {
    return positionsDouble(POSITION_VOLUME, magic, arr, name);
}

int positionsPrices(ulong magic, double &arr[], string name = NULL) {
    return positionsDouble(POSITION_PRICE_OPEN, magic, arr, name);
}

double NetLotsForSymbol(const string symbol) {
    double sum = 0.0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; --i) {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
        if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
        sum += PositionGetDouble(POSITION_VOLUME);
    }
    return sum;
}

ulong getLatestTicket(ulong magic) {
    int err;
    ulong latestTicket = 0;
    const datetime now = AuroraClock::Now();

    if (!HistorySelect(now - 40 * PeriodSeconds(PERIOD_D1), now)) {
        err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
        return latestTicket;
    }

    int totalDeals = HistoryDealsTotal();
    datetime latestDeal = 0;

    for (int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);

        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;

        datetime dealTime = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
        if (dealTime > latestDeal) {
            latestDeal = dealTime;
            latestTicket = ticket;
        }
    }

    return latestTicket;
}

ulong getPendingTicket(ulong magic, ENUM_ORDER_TYPE type, string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    
    // --- SIMULATION HOOK ---
    if (g_simulation.IsEnabled()) {
        ulong vt = g_simulation.GetVirtualTicket(magic, type, symbol);
        if (vt > 0) return vt;
    }
    // -----------------------

    int total = OrdersTotal();
    for (int i = 0; i < total; i++) {
        ulong ticket = OrderGetTicket(i);
        if (OrderGetInteger(ORDER_MAGIC) == magic &&
            OrderGetString(ORDER_SYMBOL) == symbol &&
            (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == type) {
            return ticket;
        }
    }
    return 0;
}

double OrderOpenPriceSafe(ulong ticket) {
    if (g_simulation.IsEnabled() && ticket >= VIRTUAL_TICKET_START) {
        return g_simulation.GetVirtualOrderPrice(ticket);
    }
    if (OrderSelect(ticket)) return OrderGetDouble(ORDER_PRICE_OPEN);
    return 0;
}

bool OrderSelectSafe(ulong ticket) {
    if (g_simulation.IsEnabled() && ticket >= VIRTUAL_TICKET_START) return true; // Pretend it's selected
    return OrderSelect(ticket);
}

ulong calcMagic(int magicSeed = 1) {
    string s = StringSubstr(_Symbol, 0);
    StringToLower(s);

    int n = 0;
    int l = StringLen(s);

    for(int i = 0; i < l; i++) {
        n += StringGetCharacter(s, i);
    }

    string str = (string) magicSeed + (string) n; // Removed Period() dependency for stability
    return (ulong) str;
}

bool hasDealRecently(ulong magic, string symbol, int nCandles) {
    const datetime now = AuroraClock::Now();
    if (!HistorySelect(now - 2 * (nCandles + 1) * PeriodSeconds(PERIOD_CURRENT), now)) {
        int err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
        return false;
    }
    int totalDeals = HistoryDealsTotal();
    for (int i = totalDeals - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
        datetime dealTime = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
        if (now < dealTime + nCandles * PeriodSeconds(PERIOD_CURRENT)) return true;
    }
    return false;
}

// --- CALCULATION HELPERS (Volume, Price, Cost) ---

double calcVolumeFromDistance(const string symbol,
                              double distance,
                              double risk,
                              ENUM_RISK risk_mode,
                              double balanceOverride = 0.0,
                              double maxLotLimit = -1) {
    string sym = (symbol == NULL ? _Symbol : symbol);
    double point = SymbolInfoDouble(sym, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
    if (tickSize <= 0) tickSize = point;
    double tv = GetTickValue(sym);
    double balanceBase = ResolveRiskBalance(balanceOverride, risk_mode);

    if (risk_mode == RISK_FIXED_VOL)
        return ClampVolumeToSymbol(risk, sym, maxLotLimit);
    if (risk_mode == RISK_MIN_AMOUNT) {
        static bool warned = false;
        if (!warned && CAuroraLogger::IsEnabled(AURORA_LOG_RISK)) {
            CAuroraLogger::WarnRisk("RISK_MIN_AMOUNT: taille calculée sur risque fixe (monétaire) et distance SL.");
            warned = true;
        }
        if (IsLessOrEqual(risk, 0.0)) return 0.0;
        if (IsLessOrEqual(distance, 0) || IsLessOrEqual(tickSize, 0) || IsLessOrEqual(tv, 0))
            distance = (tickSize > 0 ? tickSize : point);
        double perLotLoss = (distance / tickSize) * tv;
        if (IsLessOrEqual(perLotLoss, 0)) return 0.0;
        double vol = risk / perLotLoss;
        return ClampVolumeToSymbol(vol, sym, maxLotLimit);
    }

    if (risk_mode == RISK_MARGIN_PERCENT) {
        // MODE SMART RISK: TARGET MARGIN %
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double targetMargin = equity * risk;
        
        double marginPerLot = 0.0;
        if(!OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, SymbolInfoDouble(sym, SYMBOL_ASK), marginPerLot) || marginPerLot <= 0.0) {
             // Fallback
             double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
             double contract = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
             double price    = SymbolInfoDouble(sym, SYMBOL_ASK);
             if(leverage > 0) marginPerLot = (contract * price) / leverage;
        }

        if(marginPerLot > 0) {
            double vol = targetMargin / marginPerLot;
            return ClampVolumeToSymbol(vol, sym, maxLotLimit);
        }
        // Fallback
        return ClampVolumeToSymbol(0.01, sym, maxLotLimit);
    }

    if (IsLessOrEqual(distance, 0) || IsLessOrEqual(tickSize, 0) || IsLessOrEqual(tv, 0))
        distance = (tickSize > 0 ? tickSize : point);
    double perLotLoss = (distance / tickSize) * tv;
    if (IsLessOrEqual(perLotLoss, 0)) return 0.0;
    double vol = (balanceBase * risk) / perLotLoss;
    return ClampVolumeToSymbol(vol, sym, maxLotLimit);
}


double calcVolume(double in, double sl, double risk = 0.01, double tp = 0, ulong magic = 0, string name = NULL, double balance = 0, ENUM_RISK risk_mode = 0, double maxLotLimit = -1) {
    name = name == NULL ? _Symbol : name;
    if (sl == 0)
        sl = tp;

    double distance = MathAbs(in - sl);
    if (IsLessOrEqual(distance, 0) && tp != 0)
        distance = MathAbs(in - tp);
    if (IsLessOrEqual(distance, 0))
        distance = SymbolInfoDouble(name, SYMBOL_POINT);

    double vol = calcVolumeFromDistance(name, distance, risk, risk_mode, balance, maxLotLimit);


    
    // Final Clamp to ensure Max Limit is respected even after Martingale
    return ClampVolumeToSymbol(vol, name, maxLotLimit);
}

double calcVolume(double vol, string symbol = NULL) {
    return calcVolume(1, 1, vol, 0, 0, symbol, 0, RISK_FIXED_VOL);
}

double calcVolume(ENUM_RISK risk_mode, double risk, double in = 0, double sl = 0, string symbol = NULL) {
    return calcVolume(in, sl, risk, 0, 0, symbol, 0, risk_mode);
}

double calcVolumeFromPoints(double sl_points, double risk, ENUM_RISK risk_mode, string symbol = NULL) {
    string sym = (symbol == NULL ? _Symbol : symbol);
    double point = SymbolInfoDouble(sym, SYMBOL_POINT);
    double distance = MathMax(sl_points, 1.0) * point;
    return calcVolumeFromDistance(sym, distance, risk, risk_mode);
}

double calcCostByTicket(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) {
        int err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
        return 0;
    }
    double pswap = PositionGetDouble(POSITION_SWAP);
    double pcomm = 0;
    double pfee = 0;
    HistorySelectByPosition(PositionGetInteger(POSITION_IDENTIFIER));
    HistoryDealSelect(ticket);
    if (!HistoryDealGetDouble(ticket, DEAL_FEE, pfee) || !HistoryDealGetDouble(ticket, DEAL_COMMISSION, pcomm)) {
        pcomm = 0;
        pfee = 0;
        int err = GetLastError();
        if (err != ERR_TRADE_DEAL_NOT_FOUND) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s (ticket=%d)", __FUNCTION__, err, ErrorDescription(err), ticket));
        }
    }
    return -(pcomm + pswap + pfee);
}

double calcCost(ulong magic, string name = NULL) {
    double cost = 0;
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    for (int i = 0; i < n; i++) {
        cost += calcCostByTicket(tickets[i]);
    }
    return cost;
}

double calcPriceByTicket(ulong ticket, double target) {
    if (!PositionSelectByTicket(ticket)) {
        int err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
        return 0;
    }
    string symbol = PositionGetString(POSITION_SYMBOL);
    double tv = GetTickValue(symbol);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double op = PositionGetDouble(POSITION_PRICE_OPEN);
    double vol = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
    bool isBuy = ptype == POSITION_TYPE_BUY;
    double line = isBuy ? (target + tv * vol * op / point) / (tv * vol / point) : (target - tv * vol * op / point) / (- tv * vol / point);
    line = NormalizePrice(line, symbol);
    return line;
}

double calcPrice(ulong magic, double target, double newOp = 0, double newVol = 0, string name = NULL) {
    name = name == NULL ? _Symbol : name;
    double tv = GetTickValue(name);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);

    bool isBuy = true;
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    double sum_vol_op = 0;
    double sum_vol = 0;

    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        double op = PositionGetDouble(POSITION_PRICE_OPEN);
        double vol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        isBuy = ptype == POSITION_TYPE_BUY;
        sum_vol_op += vol * op;
        sum_vol += vol;
    }

    sum_vol_op += newVol * newOp;
    sum_vol += newVol;

    double line = isBuy ? (target + tv * sum_vol_op / point) / (tv * sum_vol / point) : (target - tv * sum_vol_op / point) / (- tv * sum_vol / point);
    line = NormalizePrice(line, name);

    return line;
}

double calcPrice(ulong magic, double target, string name = NULL) {
    return calcPrice(magic, target, 0, 0, name);
}

double calcProfit(ulong magic, double target, string name = NULL) {
    name = name == NULL ? _Symbol : name;
    double tv = GetTickValue(name);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);

    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    double prof = 0;

    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        double op = PositionGetDouble(POSITION_PRICE_OPEN);
        double vol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        bool isBuy = ptype == POSITION_TYPE_BUY;
        double d = isBuy ? target - op : op - target;
        prof += vol * tv * (d / point);
    }

    return prof;
}

double getProfit(ulong magic, string name = NULL) {
    ulong tickets[];
    int n = positionsTickets(magic, tickets, name);
    double prof = 0;
    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        prof += PositionGetDouble(POSITION_PROFIT);
    }
    return prof;
}

// --- TRADE EXECUTION HELPERS ---

// --- SNAPSHOT OVERLOADS ---
double calcPrice(ulong magic, double target, double newOp, double newVol, string name, const CAuroraSnapshot &snap) {
    name = name == NULL ? _Symbol : name;
    double tv = GetTickValue(name);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);

    int indices[];
    int n = snap.GetGroupIndices(magic, name, indices);
    double sum_vol_op = 0;
    double sum_vol = 0;
    bool isBuy = true;

    for (int i = 0; i < n; i++) {
        SAuroraPos sub = snap.Get(indices[i]);
        sum_vol_op += sub.volume * sub.price_open;
        sum_vol += sub.volume;
        isBuy = (sub.type == POSITION_TYPE_BUY);
    }

    sum_vol_op += newVol * newOp;
    sum_vol += newVol;
    
    if (sum_vol == 0) return 0;

    double line = isBuy ? (target + tv * sum_vol_op / point) / (tv * sum_vol / point) : (target - tv * sum_vol_op / point) / (- tv * sum_vol / point);
    line = NormalizePrice(line, name);
    return line;
}

double calcPrice(ulong magic, double target, string name, const CAuroraSnapshot &snap) {
    return calcPrice(magic, target, 0, 0, name, snap);
}

double calcProfit(ulong magic, double target, string name, const CAuroraSnapshot &snap) {
    name = name == NULL ? _Symbol : name;
    double tv = GetTickValue(name);
    double point = SymbolInfoDouble(name, SYMBOL_POINT);

    int indices[];
    int n = snap.GetGroupIndices(magic, name, indices);
    double prof = 0;

    for (int i = 0; i < n; i++) {
        SAuroraPos sub = snap.Get(indices[i]);
        bool isBuy = (sub.type == POSITION_TYPE_BUY);
        double d = isBuy ? target - sub.price_open : sub.price_open - target;
        prof += sub.volume * tv * (d / point);
    }

    return prof;
}

ENUM_ORDER_TYPE_FILLING MapFillingMode(ENUM_FILLING filling) {
    switch(filling) {
        case FILLING_FOK:    return ORDER_FILLING_FOK;
        case FILLING_IOK:    return ORDER_FILLING_IOC;
        case FILLING_RETURN: return ORDER_FILLING_RETURN;
        case FILLING_BOC:    return ORDER_FILLING_BOC;
        default:             return ORDER_FILLING_RETURN;
    }
}

ENUM_ORDER_TYPE_FILLING AutoFillingFromSymbol(const string symbol) {
    // SYMBOL_FILLING_MODE is a *bitmask* of allowed modes (FOK=1, IOC=2, BOC=4).
    // RETURN is implied (and is the safest default) except in Market Execution where RETURN is prohibited.
    const long execMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
    const long mask = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

    const bool canBOC = ((mask & SYMBOL_FILLING_BOC) != 0);
    const bool canIOC = ((mask & SYMBOL_FILLING_IOC) != 0);
    const bool canFOK = ((mask & SYMBOL_FILLING_FOK) != 0);

    // Exchange symbols may expose BOC; prefer it when available.
    if (canBOC) return ORDER_FILLING_BOC;

    if ((ENUM_SYMBOL_TRADE_EXECUTION)execMode == SYMBOL_TRADE_EXECUTION_MARKET) {
        // In Market execution mode, RETURN is prohibited. Prefer IOC when available (more permissive).
        if (canIOC) return ORDER_FILLING_IOC;
        if (canFOK) return ORDER_FILLING_FOK;
        // If the mask is 0/unknown, default to FOK rather than RETURN to avoid "Unsupported filling mode".
        return ORDER_FILLING_FOK;
    }

    // In non-market execution, RETURN is a safe default; keep IOC/FOK as fallbacks.
    if (canIOC) return ORDER_FILLING_IOC;
    if (canFOK) return ORDER_FILLING_FOK;
    return ORDER_FILLING_RETURN;
}

ENUM_ORDER_TYPE_FILLING SelectFilling(const string symbol, ENUM_FILLING preferred) {
    if (preferred != FILLING_DEFAULT) return MapFillingMode(preferred);
    return AutoFillingFromSymbol(symbol);
}

void AddFillingCandidate(ENUM_ORDER_TYPE_FILLING &arr[], const ENUM_ORDER_TYPE_FILLING v) {
    int n = ArraySize(arr);
    for (int i = 0; i < n; i++) {
        if (arr[i] == v) return;
    }
    ArrayResize(arr, n + 1);
    arr[n] = v;
}

bool FixFillingByOrderCheck(MqlTradeRequest &req, const ENUM_FILLING preferred, MqlTradeCheckResult &ioCheck) {
    // If the broker rejects the filling mode, retry with a small ordered set of fallbacks.
    if (ioCheck.retcode != TRADE_RETCODE_INVALID_FILL) return false;

    ENUM_ORDER_TYPE_FILLING candidates[];
    ArrayResize(candidates, 0);

    if (preferred != FILLING_DEFAULT) AddFillingCandidate(candidates, MapFillingMode(preferred));
    if (req.action == TRADE_ACTION_PENDING) {
        // For pending orders, ORDER_FILLING_RETURN is the recommended policy.
        AddFillingCandidate(candidates, ORDER_FILLING_RETURN);
    }
    AddFillingCandidate(candidates, AutoFillingFromSymbol(req.symbol));
    AddFillingCandidate(candidates, ORDER_FILLING_FOK);
    AddFillingCandidate(candidates, ORDER_FILLING_IOC);
    AddFillingCandidate(candidates, ORDER_FILLING_RETURN);
    AddFillingCandidate(candidates, ORDER_FILLING_BOC);

	    for (int i = 0; i < ArraySize(candidates); i++) {
	        req.type_filling = candidates[i];
	        MqlTradeCheckResult c2 = {};
	        // We only care about invalid fill here; OrderCheck's boolean is checked to satisfy compiler warnings.
	        if (!OrderCheck(req, c2)) {
	            // Keep c2.retcode for analysis (it is still populated on failure).
	        }
	        if (c2.retcode == TRADE_RETCODE_INVALID_FILL) continue;
	        ioCheck = c2;
	        return true;
	    }

    return false;
}

#ifndef SYMBOL_EXPIRATION_GTC
#define SYMBOL_EXPIRATION_GTC 1
#endif
#ifndef SYMBOL_EXPIRATION_DAY
#define SYMBOL_EXPIRATION_DAY 2
#endif
#ifndef SYMBOL_EXPIRATION_SPECIFIED
#define SYMBOL_EXPIRATION_SPECIFIED 4
#endif
#ifndef SYMBOL_EXPIRATION_SPECIFIED_DAY
#define SYMBOL_EXPIRATION_SPECIFIED_DAY 8
#endif

void NormalizeExpirationForSymbol(const string symbol, datetime &expiration, ENUM_ORDER_TYPE_TIME &timeType) {
    // If broker does not support explicit expirations, forcing ORDER_TIME_SPECIFIED will fail
    // with TRADE_RETCODE_INVALID_EXPIRATION ("Invalid expiration").
    if (expiration <= 0) {
        timeType = ORDER_TIME_GTC;
        expiration = 0;
        return;
    }

    if ((int)timeType == 0) timeType = ORDER_TIME_SPECIFIED;

    long mode = SymbolInfoInteger(symbol, SYMBOL_EXPIRATION_MODE);
    bool allowGTC = ((mode & SYMBOL_EXPIRATION_GTC) != 0) || (mode == 0);
    bool allowDay = ((mode & SYMBOL_EXPIRATION_DAY) != 0);
    bool allowSpecified = ((mode & SYMBOL_EXPIRATION_SPECIFIED) != 0);
    bool allowSpecifiedDay = ((mode & SYMBOL_EXPIRATION_SPECIFIED_DAY) != 0);

    datetime now = AuroraClock::Now();
    if (expiration <= now) expiration = now + 60;

    if (timeType == ORDER_TIME_SPECIFIED) {
        if (!allowSpecified) {
            timeType = ORDER_TIME_GTC;
            expiration = 0;
            if (!allowGTC && allowDay) timeType = ORDER_TIME_DAY;
        }
        return;
    }

    if (timeType == ORDER_TIME_SPECIFIED_DAY) {
        if (!allowSpecifiedDay) {
            timeType = ORDER_TIME_GTC;
            expiration = 0;
            if (!allowGTC && allowDay) timeType = ORDER_TIME_DAY;
        }
        return;
    }

    if (timeType == ORDER_TIME_DAY) {
        if (!allowDay) {
            timeType = ORDER_TIME_GTC;
        }
        expiration = 0;
        return;
    }

    // Unknown type -> be conservative.
    timeType = ORDER_TIME_GTC;
    expiration = 0;
}

// --- CORE TRADING FUNCTIONS ---

bool order(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double risk = 0.01, int slippage = 30, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0, ENUM_FILLING filling = FILLING_DEFAULT, ENUM_RISK risk_mode = RISK_DEFAULT, double balanceOverride = -1, double maxLotLimit = -1, double maxTotalLots = -1) {
    name = name == NULL ? _Symbol : name;
    int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
    int err;

    // --- SIMULATION HOOK (Market Rejection) ---
    if (g_simulation.IsEnabled() && (ot == ORDER_TYPE_BUY || ot == ORDER_TYPE_SELL)) {
        if (!g_simulation.CheckExecution(name)) return false;
    }
    // -------------------------------------------


    in = NormalizePrice(in, name);
    tp = (tp != 0.0 ? NormalizePrice(tp, name) : 0.0);
    sl = (sl != 0.0 ? NormalizePrice(sl, name) : 0.0);

    if (ot == ORDER_TYPE_BUY) {
        in = NormalizePrice(Ask(name), name);
        if (sl != 0 && IsGreaterOrEqual(sl, Bid(name))) return false;
        if (tp != 0 && IsLessOrEqual(tp, Bid(name))) return false;
    } else if (ot == ORDER_TYPE_SELL) {
        in = NormalizePrice(Bid(name), name);
        if (sl != 0 && IsLessOrEqual(sl, Ask(name))) return false;
        if (tp != 0 && IsGreaterOrEqual(tp, Ask(name))) return false;
    }

    // Hard safety: never submit invalid numeric values to OrderCheck/OrderSend.
    if (!MathIsValidNumber(in) || in <= 0.0 || in == EMPTY_VALUE) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
            CAuroraLogger::ErrorOrders(StringFormat("[ORDER] Invalid price: %s %s price=%g sl=%g tp=%g", name, EnumToString(ot), in, sl, tp));
        return false;
    }
    if (sl != 0.0 && (!MathIsValidNumber(sl) || sl <= 0.0 || sl == EMPTY_VALUE)) return false;
    if (tp != 0.0 && (!MathIsValidNumber(tp) || tp <= 0.0 || tp == EMPTY_VALUE)) return false;

    if (MQLInfoInteger(MQL_TESTER) && in == 0) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders("OpenPrice is 0!");
        return false;
    }

    if (comment == "" && positionsTotalMagic(magic, name) == 0)
        comment = sl ? DoubleToString(MathAbs(in - sl), digits) : tp ? DoubleToString(MathAbs(in - tp), digits) : "";

    if (vol == 0)
        vol = calcVolume(in, sl, risk, tp, magic, name, balanceOverride, risk_mode, maxLotLimit);
    if (!MathIsValidNumber(vol) || vol <= 0.0) return false;
    
    // Ensure Vol Limit is respected (Calculated or Passed)
    if (maxLotLimit > 0) 
        vol = ClampVolumeToSymbol(vol, name, maxLotLimit);

    // Enforce Max Total Lots (Positions + Pending)
    if (maxTotalLots > 0) {
        double curTotal = positionsTotalVolume(magic, name) + ordersTotalVolume(magic, name);
        if ((curTotal + vol) > maxTotalLots) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
                CAuroraLogger::WarnRisk(StringFormat("[MAX LOTS] Limite %.2f dépassée (actuel=%.2f, nouveau=%.2f)", maxTotalLots, curTotal, vol));
            return false;
        }
    }


    if (isl) sl = 0;
    if (itp) tp = 0;


    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    MqlTradeCheckResult cres = {};

    if (ot == ORDER_TYPE_BUY || ot == ORDER_TYPE_SELL)
        req.action = TRADE_ACTION_DEAL;
    else
        req.action = TRADE_ACTION_PENDING;

    req.symbol = name;
    req.volume = vol;
    req.type = ot;
    req.price = in;
    req.sl = sl;
    req.tp = tp;
    req.deviation = slippage;
    req.magic = magic;
    req.comment = comment;

    if (req.action == TRADE_ACTION_PENDING) {
        // Best practice: for pending orders, use RETURN; other fill modes are for market execution.
        req.type_filling = (filling == FILLING_DEFAULT) ? ORDER_FILLING_RETURN : MapFillingMode(filling);
    } else {
        req.type_filling = SelectFilling(name, filling);
    }

    // --- AUTO-REDUCTION LOOP ("Smart Money") ---
    // Check if margin is sufficient, otherwise reduce volume
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double marginRequired = 0.0;
    
    // Safety break to prevent infinite loop
    int maxRetries = 20; 
    
    // On calcule la marge requise pour le volume initial
    if (OrderCalcMargin(ot, name, req.volume, req.price, marginRequired)) {
        if (marginRequired > freeMargin) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK)) 
                CAuroraLogger::WarnRisk(StringFormat("[AUTO-REDUCE] Marge insuffisante pour %.2f lots (Req: %.2f > Free: %.2f). Tentative de réduction...", req.volume, marginRequired, freeMargin));
             
             // Reduction loop
             while(marginRequired > freeMargin && req.volume > SymbolInfoDouble(name, SYMBOL_VOLUME_MIN) && maxRetries > 0) {
                 double step = SymbolInfoDouble(name, SYMBOL_VOLUME_STEP);
                 req.volume -= step; // Reduce by one step
                 req.volume = NormalizeDouble(req.volume, 2); // Clean precision
                 
                 // Recalculer marge
                 if(!OrderCalcMargin(ot, name, req.volume, req.price, marginRequired)) break; // Erreur calc, on sort
                 maxRetries--;
             }
             
             if(req.volume < SymbolInfoDouble(name, SYMBOL_VOLUME_MIN)) {
                 if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK)) 
                     CAuroraLogger::ErrorRisk("[AUTO-REDUCE] Impossible de réduire plus : Volume trop petit.");
                 return false; 
             }
             
             if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK)) 
                CAuroraLogger::InfoRisk(StringFormat("[AUTO-REDUCE] Volume ajusté à %.2f lots (Marge OK)", req.volume));
        }
    }
    // -------------------------------------------

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_MARKET_CLOSED) return false;
        if (cres.retcode == TRADE_RETCODE_NO_MONEY) {
            // Should be caught by loop above, but double check
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("%s %s %.2f [No money - Check Failed]", name, EnumToString(ot), vol));
            return false;
        }
    }

    if (cres.retcode == TRADE_RETCODE_INVALID_FILL) {
        FixFillingByOrderCheck(req, filling, cres);
    }

    // ASYNC MIGRATION: No retry loop, single async call
    ZeroMemory(res);
    ResetLastError();
    if (g_asyncManager.SendAsync(req)) {
        // if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
        //    CAuroraLogger::InfoOrders(StringFormat("[ASYNC] Order Sent: %s %s %.2f @ %.5f", name, EnumToString(ot), vol, req.price));
        // Manager logs automatically
        return true;
    } else {
        err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] OrderSendAsync Error: %s %s %.2f, Err=%d", name, EnumToString(ot), vol, err));
        return false;
    }
}

bool pendingOrder(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double vol = 0, double stoplimit = 0, datetime expiration = 0, ENUM_ORDER_TYPE_TIME timeType = 0, string symbol = NULL, string comment = "", ENUM_FILLING filling = FILLING_DEFAULT, ENUM_RISK risk_mode = RISK_DEFAULT, double risk = 0.01, int slippage = 30, double maxTotalLots = -1) {
    if (symbol == NULL) symbol = _Symbol;
    int err;


    in = NormalizePrice(in, symbol);
    tp = (tp != 0.0 ? NormalizePrice(tp, symbol) : 0.0);
    sl = (sl != 0.0 ? NormalizePrice(sl, symbol) : 0.0);

    // Hard safety: never submit invalid numeric values to OrderCheck/OrderSend.
    if (!MathIsValidNumber(in) || in <= 0.0 || in == EMPTY_VALUE) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
            CAuroraLogger::ErrorOrders(StringFormat("[PENDING] Invalid price: %s %s price=%g sl=%g tp=%g", symbol, EnumToString(ot), in, sl, tp));
        return false;
    }
    if (sl != 0.0 && (!MathIsValidNumber(sl) || sl <= 0.0 || sl == EMPTY_VALUE)) return false;
    if (tp != 0.0 && (!MathIsValidNumber(tp) || tp <= 0.0 || tp == EMPTY_VALUE)) return false;

    if (vol == 0)
        vol = calcVolume(in, sl, risk, tp, magic, symbol, 0, risk_mode);
    if (!MathIsValidNumber(vol) || vol <= 0.0) return false;

    vol = ClampVolumeToSymbol(vol, symbol);

    // Async safety: single source of truth for pending orders (broker + local in-flight).
    if (getPendingTicket(magic, ot, symbol) > 0 ||
        g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_PENDING, ot)) {
        return true;
    }

    // Enforce Max Total Lots (Positions + Pending)
    if (maxTotalLots > 0) {
        double curTotal = positionsTotalVolume(magic, symbol) + ordersTotalVolume(magic, symbol);
        if ((curTotal + vol) > maxTotalLots) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
                CAuroraLogger::WarnRisk(StringFormat("[MAX LOTS] Limite %.2f dépassée (actuel=%.2f, nouveau=%.2f)", maxTotalLots, curTotal, vol));
            return false;
        }
    }
    
    // --- SIMULATION HOOK (Virtual Pending) ---
    if (g_simulation.IsEnabled()) {
        if (ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP || ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT) {
             g_simulation.PlaceVirtualPending(ot, in, sl, tp, vol, magic, symbol, comment, expiration);
             return true;
        }
    }
    // -----------------------------------------
    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    MqlTradeCheckResult cres = {};

    req.action = TRADE_ACTION_PENDING;
    req.symbol = symbol;
    req.volume = vol;
    req.type = ot;
    req.price = in;
    req.sl = sl;
    req.tp = tp;
    req.deviation = slippage;
    req.magic = magic;
    req.comment = comment;
    req.stoplimit = stoplimit;

    ENUM_ORDER_TYPE_TIME reqTimeType = timeType;
    datetime reqExpiration = expiration;
    NormalizeExpirationForSymbol(symbol, reqExpiration, reqTimeType);
    req.type_time = reqTimeType;
    req.expiration = reqExpiration;

    // Best practice: for pending orders, use RETURN in Auto mode; broker will reject unsupported modes.
    req.type_filling = (filling == FILLING_DEFAULT) ? ORDER_FILLING_RETURN : MapFillingMode(filling);

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_MARKET_CLOSED) return false;
        if (cres.retcode == TRADE_RETCODE_NO_MONEY) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("%s %s %.2f [No money]", symbol, EnumToString(ot), vol));
            return false;
        }
    }

    // Some brokers reject explicit expirations entirely (even if SYMBOL_EXPIRATION_MODE is ambiguous).
	    if (cres.retcode == TRADE_RETCODE_INVALID_EXPIRATION) {
	        req.type_time = ORDER_TIME_GTC;
	        req.expiration = 0;
	        if (!OrderCheck(req, cres)) {
	            // Keep cres.retcode for analysis.
	        }
	    }

    if (cres.retcode == TRADE_RETCODE_INVALID_FILL) {
        FixFillingByOrderCheck(req, filling, cres);
    }

    // ASYNC MIGRATION: No retry loop, single async call
    ZeroMemory(res);
    ResetLastError();
    if (g_asyncManager.SendAsync(req)) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::InfoOrders(StringFormat("[ASYNC] Pending Order Sent: %s %s %.2f @ %.5f", symbol, EnumToString(ot), vol, req.price));
        return true;
    } else {
        err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Pending Order Error: %s %s, Err=%d", symbol, EnumToString(ot), err));
        return false;
    }
}

bool closeOrder(ulong ticket, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT) {
    int err;

    if (!PositionSelectByTicket(ticket)) {
        err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::ErrorOrders(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
        return false;
    }

    string psymbol = PositionGetString(POSITION_SYMBOL);

    // --- SIMULATION HOOK ---
    if (g_simulation.IsEnabled()) {
        if (!g_simulation.CheckExecution(psymbol)) return false;
    }
    // -----------------------

    ulong pmagic = PositionGetInteger(POSITION_MAGIC);
    double pvolume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    MqlTradeCheckResult cres = {};

    req.action = TRADE_ACTION_DEAL;
    req.position = ticket;
    req.symbol = psymbol;
    req.volume = pvolume;
    req.deviation = slippage;
    req.magic = pmagic;

    if (ptype == POSITION_TYPE_BUY) {
        req.price = Bid(psymbol);
        req.type = ORDER_TYPE_SELL;
    } else {
        req.price = Ask(psymbol);
        req.type = ORDER_TYPE_BUY;
    }

    req.type_filling = SelectFilling(psymbol, filling);

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_MARKET_CLOSED) return false;
    }

    if (cres.retcode == TRADE_RETCODE_INVALID_FILL) {
        FixFillingByOrderCheck(req, filling, cres);
    }


    // ASYNC MIGRATION: Close Order
    ZeroMemory(res);
    if (!g_asyncManager.SendAsync(req)) {
         err = GetLastError();
         if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Close Error: Ticket=%I64u, Err=%d", ticket, err));
         return false;
    }
    return true;
}

bool closePendingOrder(ulong ticket) {
    int err;

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    if (!OrderSelect(ticket)) {
        return true; // Already absent on broker side.
    }

    const string symbol = OrderGetString(ORDER_SYMBOL);
    const ulong magic = (ulong)OrderGetInteger(ORDER_MAGIC);
    const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

    if (g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_REMOVE, (ENUM_ORDER_TYPE)-1, 0, ticket)) {
        return true;
    }

    req.action = TRADE_ACTION_REMOVE;
    req.order = ticket;
    req.symbol = symbol;
    req.magic = magic;
    req.type = type;


    // ASYNC MIGRATION: Delete Order
    ZeroMemory(res);
    if (!g_asyncManager.SendAsync(req)) {
         err = GetLastError();
         if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Delete Error: Ticket=%I64u, Err=%d", ticket, err));
         return false;
    }
    return true;
}

bool modifyPendingOrder(ulong ticket, double price, double sl = 0, double tp = 0, double stoplimit = 0, ENUM_ORDER_TYPE_TIME timeType = ORDER_TIME_GTC, datetime expiration = 0) {
    // --- SIMULATION HOOK ---
    if (g_simulation.IsEnabled() && ticket >= VIRTUAL_TICKET_START) {
        return g_simulation.ModifyVirtualOrder(ticket, price, sl, tp);
    }
    // -----------------------
    if (!OrderSelect(ticket)) return false;

    const string symbol = OrderGetString(ORDER_SYMBOL);
    const ulong magic = (ulong)OrderGetInteger(ORDER_MAGIC);
    const ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

    if (g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_REMOVE, (ENUM_ORDER_TYPE)-1, 0, ticket)) return true;
    if (g_asyncManager.HasPending(magic, symbol, TRADE_ACTION_MODIFY, otype, 0, ticket)) return true;

    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    MqlTradeCheckResult cres = {};

    req.action = TRADE_ACTION_MODIFY;
    req.order = ticket;
    req.symbol = symbol;
    req.magic = magic;
    req.type = otype;
    req.price = NormalizePrice(price, symbol);
    req.sl = (sl != 0.0 ? NormalizePrice(sl, symbol) : 0.0);
    req.tp = (tp != 0.0 ? NormalizePrice(tp, symbol) : 0.0);
    req.stoplimit = stoplimit;
    ENUM_ORDER_TYPE_TIME reqTimeType = timeType;
    datetime reqExpiration = expiration;
    NormalizeExpirationForSymbol(symbol, reqExpiration, reqTimeType);

    // Keep broker-compatible mode sticky: if current order is GTC, do not force SPECIFIED on modify.
    ENUM_ORDER_TYPE_TIME currentTimeType = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
    if (currentTimeType == ORDER_TIME_GTC && reqTimeType == ORDER_TIME_SPECIFIED) {
        reqTimeType = ORDER_TIME_GTC;
        reqExpiration = 0;
    }

    // Re-validate pending price against current market + broker minimal distance.
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point <= 0.0) point = _Point;
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tickSize <= 0.0) tickSize = point;
    double minDist = MinBrokerPoints(symbol) * point;
    double bidNow = Bid(symbol);
    double askNow = Ask(symbol);
    if (!MathIsValidNumber(bidNow) || bidNow <= 0.0) bidNow = SymbolInfoDouble(symbol, SYMBOL_BID);
    if (!MathIsValidNumber(askNow) || askNow <= 0.0) askNow = SymbolInfoDouble(symbol, SYMBOL_ASK);

    if (otype == ORDER_TYPE_BUY_STOP) {
        double minAllowed = askNow + minDist + tickSize;
        if (IsLess(req.price, minAllowed)) req.price = NormalizePriceUp(minAllowed, symbol);
    } else if (otype == ORDER_TYPE_SELL_STOP) {
        double maxAllowed = bidNow - minDist - tickSize;
        if (IsGreater(req.price, maxAllowed)) req.price = NormalizePriceDown(maxAllowed, symbol);
    } else if (otype == ORDER_TYPE_BUY_LIMIT) {
        double maxAllowed = askNow - minDist - tickSize;
        if (IsGreater(req.price, maxAllowed)) req.price = NormalizePriceDown(maxAllowed, symbol);
    } else if (otype == ORDER_TYPE_SELL_LIMIT) {
        double minAllowed = bidNow + minDist + tickSize;
        if (IsLess(req.price, minAllowed)) req.price = NormalizePriceUp(minAllowed, symbol);
    }

    // Keep SL/TP coherent after potential price recentering.
    if (req.sl > 0.0) {
        bool isBuyPending = (otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_LIMIT || otype == ORDER_TYPE_BUY_STOP_LIMIT);
        if (isBuyPending && !IsLess(req.sl, req.price)) req.sl = NormalizePriceDown(req.price - tickSize, symbol);
        if (!isBuyPending && !IsGreater(req.sl, req.price)) req.sl = NormalizePriceUp(req.price + tickSize, symbol);
    }
    if (req.tp > 0.0) {
        bool isBuyPending = (otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_LIMIT || otype == ORDER_TYPE_BUY_STOP_LIMIT);
        if (isBuyPending && !IsGreater(req.tp, req.price)) req.tp = NormalizePriceUp(req.price + tickSize, symbol);
        if (!isBuyPending && !IsLess(req.tp, req.price)) req.tp = NormalizePriceDown(req.price - tickSize, symbol);
    }

    req.type_time = reqTimeType;
    req.expiration = reqExpiration;

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_INVALID_EXPIRATION) {
            req.type_time = ORDER_TIME_GTC;
            req.expiration = 0;
            if (!OrderCheck(req, cres)) {
                if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                    CAuroraLogger::WarnOrders(StringFormat("[MODIFY] ticket=%I64u pre-check fail ret=%u (%s)", ticket, cres.retcode, TradeServerReturnCodeDescription(cres.retcode)));
                return false;
            }
        } else {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                CAuroraLogger::WarnOrders(StringFormat("[MODIFY] ticket=%I64u pre-check fail ret=%u (%s)", ticket, cres.retcode, TradeServerReturnCodeDescription(cres.retcode)));
            return false;
        }
    }

    // ASYNC MIGRATION: Modify Order
    ZeroMemory(res);
    if (!g_asyncManager.SendAsync(req)) {
         int err = GetLastError();
         if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Modify Error: Ticket=%I64u, Err=%d", ticket, err));
         return false;
    }
    return true;
}

void closeOrders(ENUM_POSITION_TYPE pt, ulong magic, int slippage = 30, string name = NULL, ENUM_FILLING filling = FILLING_DEFAULT) {
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        if (pmagic != magic) continue;
        if (ptype != pt) continue;
        if (name != NULL && psymbol != name) continue;
        closeOrder(pticket, slippage, filling);
    }
}

void closePendingOrders(ENUM_ORDER_TYPE ot, ulong magic, string name = NULL) {
    
    // --- SIMULATION HOOK ---
    if (g_simulation.IsEnabled()) {
        g_simulation.CancelAllVirtualOrders(magic, name);
    }
    // -----------------------

    int total = OrdersTotal();
    for (int i = total - 1; i >= 0; i--) {

        ulong oticket = OrderGetTicket(i);
        string osymbol = OrderGetString(ORDER_SYMBOL);
        ulong omagic = OrderGetInteger(ORDER_MAGIC);
        ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE) OrderGetInteger(ORDER_TYPE);
        if (omagic != magic) continue;
        if (otype != ot) continue;
        if (name != NULL && osymbol != name) continue;
        closePendingOrder(oticket);
    }
}

// --- LOGIC HELPERS (Fill Symbols, Fix Multi, etc) ---

// Dead Code Removed: fillSymbols & fixMultiCurrencies
// These functions were identified as unused during the audit and have been removed.

// --- STRATEGY HELPERS (SL, ATR) ---

double GetATR(string symbol, int period) {
    int handle = iATR(symbol, PERIOD_CURRENT, period);
    if (handle == INVALID_HANDLE) return 0.0;
    
    double buf[1];
    if (CopyBuffer(handle, 0, 0, 1, buf) < 1) {
        IndicatorRelease(handle);
        return 0.0;
    }
    IndicatorRelease(handle);
    return buf[0];
}




// --- STRATEGY CORE (Trail, Grid, Equity, BE) ---

// Snapshot Optimized Overload
// Snapshot Optimized Overload
// Snapshot Optimized Overload
void checkForTrail(ulong magic, double stopLevel, int slippage, ENUM_FILLING filling, ENUM_TRAIL_MODE trailMode, int trailAtrHandle, double trailAtrMult, const CAuroraSnapshot &snap, CVirtualStopManager *vManager = NULL, bool exitOnClose = false, double hardSLMult = 1.5)

{
    if (stopLevel <= 0) return;
    if(snap.Total() == 0) return;

    int minPoints = 1; 
    MqlTradeRequest req;
    MqlTradeResult res;

    // Optimization check: Process by Group (Symbol+Type)
    // We can iterate the snapshot linearly and use processed registry
    struct SGroupKey {
        ulong magic;
        string symbol;
        ENUM_POSITION_TYPE type;
    };
    SGroupKey processed_groups[];

    int total = snap.Total();
    for (int i = 0; i < total; i++) {
        SAuroraPos curr = snap.Get(i);
        
        if (curr.magic != magic) continue;

        string psymbol = curr.symbol;
        ENUM_POSITION_TYPE ptype = curr.type;
        
        // Skip if group processed
        bool is_processed = false;
        int pg_size = ArraySize(processed_groups);
        for(int p=0; p<pg_size; p++) {
            if(processed_groups[p].magic == magic && 
               processed_groups[p].type == ptype && 
               processed_groups[p].symbol == psymbol) { 
               is_processed = true; 
               break; 
            }
        }
        if(is_processed) continue;

        ArrayResize(processed_groups, pg_size + 1);
        processed_groups[pg_size].magic = magic;
        processed_groups[pg_size].symbol = psymbol;
        processed_groups[pg_size].type = ptype;

        // Retrieve Group Indices (O(1) access later)
        int indices[];
        int n = snap.GetGroupIndices(magic, psymbol, indices); 
        // Note: GetGroupIndices returns BOTH buy and sell for symbol.
        // We filter by ptype inside.
        
        // Calc 'k' (positions with comment / grid ID) - LEGACY GRID LOGIC REMOVED
        // We keep 'k' just for logic compatibility if needed or remove it. 
        // Logic below uses 'n' or 'k'. Since Grid is gone, n==1 is standard.
        // If k was used to detect grid positions, it's now irrelevant.
        // We simplify to just Standard Trail logic.
        
        minPoints = MinBrokerPoints(psymbol);
        double ppoint = SymbolInfoDouble(psymbol, SYMBOL_POINT);
        double ptick = SymbolInfoDouble(psymbol, SYMBOL_TRADE_TICK_SIZE);
        if (ptick <= 0.0) ptick = ppoint;
        double minModDiff = ptick * 0.5;
        int pdigits = (int) SymbolInfoInteger(psymbol, SYMBOL_DIGITS);
        ENUM_SYMBOL_TRADE_MODE pstm = (ENUM_SYMBOL_TRADE_MODE) SymbolInfoInteger(psymbol, SYMBOL_TRADE_MODE);
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        bool grid_logic_done = false;
        bool atrReady = false;
        double atrDist = 0.0;
        if (trailMode == TRAIL_ATR) {
            double atrBuf[1];
            atrReady = (trailAtrHandle != INVALID_HANDLE && CopyBuffer(trailAtrHandle, 0, 0, 1, atrBuf) == 1 && atrBuf[0] > 0.0);
            if (atrReady) atrDist = atrBuf[0] * trailAtrMult;
        }

        for(int t=0; t<n; t++) {
            SAuroraPos p = snap.Get(indices[t]);
            if(p.type != ptype) continue; // Logic per side

            ulong curr_ticket = p.ticket;
            double pin = p.price_open;
            double psl = p.sl;
            double ptp = p.tp;
            double pprof = p.profit;
            ZeroMemory(req); ZeroMemory(res);
            req.action = TRADE_ACTION_SLTP;
            req.position = curr_ticket;
            req.symbol = psymbol;
            req.magic = magic;
            req.sl = psl;
            req.tp = ptp;

            // --- LOGIC A: Individual Trail ---
            // Standard Trail Logic
            if (n >= 1) {
                if (trailMode == TRAIL_STANDARD && IsZero(stopLevel)) continue;
                
                double sl = 0;
                if (trailMode == TRAIL_ATR) {
                    if (!atrReady) continue;
                    if (ptype == POSITION_TYPE_BUY) sl = Bid(psymbol) - atrDist;
                    else sl = Ask(psymbol) + atrDist;
                } else if (trailMode == TRAIL_FIXED_POINTS) {
                    // Fixed distance in points - optimal for M1 scalping
                    double dist = stopLevel * ppoint;  // stopLevel = points (e.g., 80, 100, 150)
                    if (ptype == POSITION_TYPE_BUY) sl = Bid(psymbol) - dist;
                    else sl = Ask(psymbol) + dist;
                } else {
                    // TRAIL_STANDARD: Percentage of profit distance
                    if (ptype == POSITION_TYPE_BUY) sl = Bid(psymbol) - stopLevel * (Bid(psymbol) - pin);
                    else sl = Ask(psymbol) + stopLevel * (pin - Ask(psymbol));
                }

                sl = NormalizePrice(sl, psymbol);
                
                // [EXIT-ON-CLOSE] Virtual Hook
                if (exitOnClose) {
                    if (vManager != NULL) {
                         vManager.Set(curr_ticket, sl, (ptype == POSITION_TYPE_BUY));
                         // Log (Verbose): Virtual Trail Updated
                    }
                    // Prevent Broker Modification (Hard SL stays static or handled separately)
                    continue;
                }
                
                bool mod = false;
                double bidNow = Bid(psymbol);
                double askNow = Ask(psymbol);
                double minDistPrice = minPoints * ppoint;
                if (ptype == POSITION_TYPE_BUY) {
                    if ((psl == 0 || IsGreater(sl, psl)) && IsGreater(sl, pin)) {
                         double maxAllowed = bidNow - minDistPrice;
                         if (IsGreater(sl, maxAllowed)) sl = maxAllowed;
                         sl = NormalizeStopForPosition(sl, true, psymbol);
                         if (IsGreater(sl, pin) && IsGreaterOrEqual(bidNow - sl, minDistPrice)) mod = true;
                    }
                } else {
                    if ((psl == 0 || IsLess(sl, psl)) && IsLess(sl, pin)) {
                         double minAllowed = askNow + minDistPrice;
                         if (IsLess(sl, minAllowed)) sl = minAllowed;
                         sl = NormalizeStopForPosition(sl, false, psymbol);
                         if (IsLess(sl, pin) && IsGreaterOrEqual(sl - askNow, minDistPrice)) mod = true;
                    }
                }

                if (mod) {
                    if (psl != 0 && MathAbs(sl - psl) < minModDiff) continue; 
                    req.sl = sl;
                    if(!g_asyncManager.SendAsync(req)) {
                         int err = GetLastError();
                         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s (trail) [ASYNC] error #%d", __FUNCTION__, err));
                    }
                }
            }

            // Grid Logic Removed

        }
    }
}

// Wrapper
void checkForTrail(ulong magic, double stopLevel = 0.5, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT, ENUM_TRAIL_MODE trailMode = TRAIL_STANDARD, int trailAtrHandle = INVALID_HANDLE, double trailAtrMult = 2.5, CVirtualStopManager *vManager = NULL, bool exitOnClose = false, double hardSLMult = 1.5) {
    CAuroraSnapshot snap;
    snap.Update(magic, _Symbol); 
    checkForTrail(magic, stopLevel, slippage, filling, trailMode, trailAtrHandle, trailAtrMult, snap, vManager, exitOnClose, hardSLMult);
}


// Snapshot Optimized Overload
void checkForEquity(ulong magic, double limit, int slippage, ENUM_FILLING filling, double balanceOverride, const CAuroraSnapshot &snap) {
    if (IsZero(limit)) return;
    if (snap.Total() == 0) return;

    double balance = (balanceOverride > 0) ? GetSimulatedBalance(balanceOverride) : AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = (balanceOverride > 0) ? GetSimulatedEquity(balanceOverride) : AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Drawdown % formula: (Equity - Balance) / Balance
    double p = (equity - balance) / balance;
    if (p >= 0) return;
    if (MathAbs(p) < limit) return;

    double max_loss = -DBL_MAX;
    string max_symbol = "";
    
    int total = snap.Total();
    for (int i = 0; i < total; i++) {
        SAuroraPos curr = snap.Get(i);
        if (curr.magic != magic) continue;
        
        // Loss calculation: Cost - NetProfit. 
        // Cost = MathAbs(Swap + Comm).
        // Profit = Profit.
        // Wait, original: calcCost(magic, psymbol) - getProfit(magic, psymbol).
        // calcCost sums positive costs. getProfit sums Net Profit.
        // So Loss = TotalCost - TotalProfit?
        // If Profit is eg -100, and Cost is 10. Loss = 10 - (-100) = 110. Correct.
        
        // This loop logic seems to want to find the SYMBOL with max loss.
        // Original looped positions -> found symbol -> calculated loss for symbol logic was O(N*M)!
        // (Outer loop N positions, Inner calcCost loops M positions for that symbol). That was O(N^2) effectively.
        
        // Optimize: We can iterate unique symbols.
        // Or simply iterate snapshot and accumulate loss per symbol?
        // But we need "max_symbol".
        
        // Let's use a small map or dictionary if MQL had it. MQL doesn't.
        // Simple approach: Linear scan of snapshot, skipping processed symbols.
        
        // The original logic:
        // for each position ticket:
        //    symbol = pos.symbol
        //    loss = calcCost(symbol) - getProfit(symbol)
        
        // This is extremely inefficient (recalculating group loss for every single position of that group).
        // Optimization:
        // 1. Collect unique symbols.
        // 2. Calc loss for each.
    }
    
    // Efficient Implementation:
    string checked_symbols[];
    int cs_cnt = 0;
    
    for(int i=0; i<total; i++) {
        SAuroraPos curr = snap.Get(i);
        if(curr.magic != magic) continue;
        
        // Check if processed
        bool processed = false;
        for(int k=0; k<cs_cnt; k++) if(checked_symbols[k] == curr.symbol) { processed = true; break; }
        if(processed) continue;
        
        ArrayResize(checked_symbols, cs_cnt+1);
        checked_symbols[cs_cnt++] = curr.symbol;
        
        // Calc Loss for this symbol group
        double grpCost = snap.CalcCost(magic, curr.symbol);
        double grpProfit = snap.GetProfit(magic, curr.symbol);
        double loss = grpCost - grpProfit;
        
        if (loss > max_loss) {
             max_loss = loss;
             max_symbol = curr.symbol;
        }
    }

    if (max_symbol != "") {
        closeOrders(POSITION_TYPE_BUY, magic, slippage, max_symbol, filling);
        closeOrders(POSITION_TYPE_SELL, magic, slippage, max_symbol, filling);
    }
}

void checkForEquity(ulong magic, double limit, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT, double balanceOverride = -1) {
    // Legacy wrapper - creates snapshot locally if called directly
    CAuroraSnapshot snap;
    snap.Update(magic, NULL);
    checkForEquity(magic, limit, slippage, filling, balanceOverride, snap);
}





void checkForBE(ulong magic, 
                ENUM_BE_MODE mode, 
                double triggerRatio, 
                int triggerPts, 
                double spreadMult, 
                int slDevFallbackPts, 
                bool onNewBar, 
                int beMinOffsetPts, 
                int atrPeriod, 
                double atrMultiplier, 
                int atrHandle, 
                int slippage, 
                ENUM_FILLING filling,
                const CAuroraSnapshot &snap,
                CVirtualStopManager *vManager = NULL, 
                bool exitOnClose = false) 
{
    if (mode == BE_MODE_RATIO && triggerRatio <= 0) return;
    if (mode == BE_MODE_POINTS && triggerPts <= 0) return;
    
    // Performance: Early exit if no positions
    if(snap.Total() == 0) return;

    string symbol = _Symbol;
    const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    const int minPts = MinBrokerPoints(symbol);
    const int spreadPts = (int)MathMax((double)SymbolInfoInteger(symbol, SYMBOL_SPREAD), 1.0);
    
    const int offsetPts = (int)MathMax((double)beMinOffsetPts, MathRound(spreadPts * spreadMult));

    static datetime last_bar_ts = 0;
    if (onNewBar) {
        datetime t0 = iTime(symbol, PERIOD_CURRENT, 0);
        if (t0 == last_bar_ts) return; 
        last_bar_ts = t0;
    }

    int total = snap.Total();
    for (int i = 0; i < total; i++) {
        SAuroraPos pos = snap.Get(i);
        
        // Filter from Snapshot (Magic already filtered if Update called with it, but we double check)
        if(pos.magic != magic) continue;
        if(pos.symbol != symbol) continue;

        const bool isBuy = (pos.type == POSITION_TYPE_BUY);
        const double op   = pos.price_open;
        const double sl   = pos.sl;
        const double cur  = isBuy ? Bid(symbol) : Ask(symbol);

        // --- CALCUL DISTANCE DE DECLENCHEMENT ---
        double triggerDistPtrs = 0.0;
        
        if (mode == BE_MODE_POINTS) {
            triggerDistPtrs = (double)triggerPts;
        } 
        else if (mode == BE_MODE_ATR) {
            double curATR = 0.0;
            if (atrHandle != INVALID_HANDLE) {
                 double buf[1];
                 if(CopyBuffer(atrHandle, 0, 0, 1, buf) > 0) curATR = buf[0];
            } else {
                 curATR = GetATR(symbol, atrPeriod);
            }
            if (curATR > 0) {
                double atrPts = curATR / point;
                triggerDistPtrs = atrPts * atrMultiplier; 
            }
        }
        else {
             double slDist = 0.0;
             if (sl > 0) {
                 slDist = MathAbs(op - sl); 
             } else {
                 if (slDevFallbackPts > 0) slDist = slDevFallbackPts * point;
                 else slDist = 100 * point; 
             }
             triggerDistPtrs = (slDist / point) * triggerRatio;
        }

        const double gainPts = (isBuy ? (cur - op)/point : (op - cur)/point);
        if (IsLess(gainPts, triggerDistPtrs)) continue;

        // Optimization: Use cached cost from snapshot
        // Cost = - (Swap + Comm). We want positive magnitude.
        double cost = MathAbs(pos.swap + pos.commission);
        
        // Compute BE Base Price (Entry + Cost converted to price distance)
        // calcPriceByTicket was: entry + (cost_in_money / tickval * ticksize * direction)
        // Let's replicate safely.
        double tv = GetTickValue(symbol);
        double beBase = op;
        if(tv > 0 && cost > 0) {
            double costDist = (cost / pos.volume) / tv * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            if(isBuy) beBase += costDist;
            else      beBase -= costDist;
        }

        double bePrice = isBuy ? (beBase + offsetPts*point) : (beBase - offsetPts*point);
        bePrice = NormalizeStopForPosition(bePrice, isBuy, symbol);

        if (sl > 0) {
             // Logic Check: avoid moving SL backwards or same
             if (isBuy) {
                 if (IsGreaterOrEqual(sl, bePrice)) continue; // Already secured
             } else {
                 if (IsLessOrEqual(sl, bePrice)) continue;
             }
        }

        if (isBuy) {
            if (!IsGreaterOrEqual(cur - bePrice, minPts * point)) continue;
        } else {
            if (!IsGreaterOrEqual(bePrice - cur, minPts * point)) continue;
        }

        MqlTradeRequest req; ZeroMemory(req);
        req.action   = TRADE_ACTION_SLTP;
        req.position = pos.ticket;
        req.symbol   = symbol;
        req.magic    = magic;
        req.deviation= slippage;
        req.sl       = bePrice;
        req.tp       = pos.tp;
        
        // [EXIT-ON-CLOSE] Virtual Hook
        if (exitOnClose) {
             if (vManager != NULL) {
                  vManager.Set(pos.ticket, req.sl, isBuy);
             }
             continue;
        }
        
        if(!g_asyncManager.SendAsync(req)){
            int err = GetLastError();
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("[BE] ticket=%I64u [ASYNC] error #%d : %s", pos.ticket, err, ErrorDescription(err)));
            continue;
        }
        if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
            string trigInfo = (mode==BE_MODE_POINTS) ? StringFormat("%d pts", triggerPts) : StringFormat("R=%.2f", triggerRatio);
            CAuroraLogger::InfoStrategy(StringFormat("[BE] ticket=%I64u -> SL=%.0fpts @ %.5f (Trig: %s, cost=%.2f, offset=%dpts)", pos.ticket, (isBuy?(bePrice-op):(op-bePrice))/point, bePrice, trigInfo, cost, offsetPts));
        }
    }
}

// Legacy Wrapper
void checkForBE(ulong magic, 
                ENUM_BE_MODE mode, 
                double triggerRatio, 
                int triggerPts, 
                double spreadMult, 
                int slDevFallbackPts, 
                bool onNewBar, 
                int beMinOffsetPts = 10, 
                int atrPeriod = 14, 
                double atrMultiplier = 1.0, 
                int atrHandle = INVALID_HANDLE, 
                int slippage = 30, 
                ENUM_FILLING filling = FILLING_DEFAULT,
                CVirtualStopManager *vManager = NULL, 
                bool exitOnClose = false) 

{
    CAuroraSnapshot snap;
    snap.Update(magic, _Symbol);
    checkForBE(magic, mode, triggerRatio, triggerPts, spreadMult, slDevFallbackPts, onNewBar, beMinOffsetPts, atrPeriod, atrMultiplier, atrHandle, slippage, filling, snap, vManager, exitOnClose);
}

// --- GerEA CLASS (Wrappers) ---

#include <Aurora/aurora_simulation.mqh>

class GerEA {
private:
    ulong magicNumber;
    CVirtualStopManager m_vStops; // [NEW] Manager
public:
    double risk;
    bool reverse; // [RESTORED]
    double trailingStopLevel; // [RESTORED]


    // Break-Even Advanced
    ENUM_BE_MODE beMode;
    int beAtrPeriod;
    double beAtrMultiplier;
    int beAtrHandle;

    // Internal handle for ATR - Removed duplicate declaration
    // trailAtrHandle = INVALID_HANDLE; // Moved to Init

    double equityDrawdownLimit;
    int slippage; // [RESTORED]
    ENUM_FILLING filling;
    ENUM_RISK riskMode;
    double riskMaxTotalLots;
    double riskMaxLotSize;


    
    // Spread Filter
    int maxSpreadLimit;

    // Virtual Balance (-1 = Disabled)
    double virtualBalance;

    // Entry Execution Mode
    ENUM_ENTRY_MODE entryMode;
    int entryDistPts;
    int entryExpirationSec;
    
    // Elastic Volatility Params
    bool   elasticEnable;
    bool   elasticApplySL;
    bool   elasticApplyTrail;
    bool   elasticApplyBE;
    int    elasticAtrShort;
    int    elasticAtrLong;
    double elasticMaxScale;
    
    // Elastic Runtime State
    double m_elasticFactor;
    double m_noiseFactor;
    uint m_lastElasticUpdateMs;
    datetime m_lastElasticBar;
    
    GerEA() {
        entryMode = ENTRY_MODE_MARKET;
        entryDistPts = 0;
        entryExpirationSec = 15;

        risk = 0.01;
        // Initialisation Profit Target (Removed Grid logic)


        beMode = BE_MODE_RATIO;
        beAtrPeriod = 14;
        beAtrMultiplier = 1.0;

        beAtrHandle = INVALID_HANDLE;

        trailAtrHandle = INVALID_HANDLE;
        
        equityDrawdownLimit = 0;
        slippage = 30;
        filling = FILLING_DEFAULT;
        riskMode = RISK_DEFAULT;
        riskMaxTotalLots = 50.0;
        riskMaxLotSize = -1;


        

        // beMinOffsetPts = 10; // This is a parameter for checkForBE, not a class member.
        virtualBalance = -1;
        
        exitOnClose = false;
        exitHardSLMult = 1.5;

        // Elastic Volatility Model
        elasticEnable = false;
        elasticApplySL = true;
        elasticApplyTrail = true;
        elasticApplyBE = true;
        elasticAtrShort = 5;
        elasticAtrLong = 20;
        elasticMaxScale = 2.0;

        m_elasticFactor = 1.0; // Default to no scaling
        m_noiseFactor = 1.0; // Default to clean market (no penalty)
        m_lastElasticUpdateMs = 0;
        m_lastElasticBar = 0;
        
        adaptiveVolThreshold = 1.2; // Default Safe Value
    }
    
    // Adaptive Settings
    double adaptiveVolThreshold;
    
    // Trailing Params
    ENUM_TRAIL_MODE trailMode;
    int    trailAtrPeriod;
    double trailAtrMult;
    int    trailAtrHandle;
    
    // Exit On Close Params
    bool   exitOnClose;
    double exitHardSLMult;

    void ConfigExitOnClose(bool enable, double hardMult) {
        exitOnClose = enable;
        exitHardSLMult = hardMult;
    }

    void Init(int magicSeed = 1) {
        magicNumber = calcMagic(magicSeed);
        // Defaults
        reverse = false;
        trailingStopLevel = 0.5;
    }

    void InitATR() {
        if (trailMode == TRAIL_ATR && trailAtrHandle == INVALID_HANDLE) {
            trailAtrHandle = iATR(NULL, PERIOD_CURRENT, trailAtrPeriod);
        }

        if (beMode == BE_MODE_ATR && beAtrHandle == INVALID_HANDLE) {
             beAtrHandle = iATR(NULL, PERIOD_CURRENT, beAtrPeriod);
        }
    }
    
    // [ELASTIC VOLATILITY] Configuration
    void ConfigElasticParams(bool enable, bool applySL, bool applyTrail, bool applyBE, int atrShort, int atrLong, double maxScale) {
        elasticEnable = enable;
        elasticApplySL = applySL;
        elasticApplyTrail = applyTrail;
        elasticApplyBE = applyBE;
        elasticAtrShort = atrShort;
        elasticAtrLong = atrLong;
        elasticMaxScale = maxScale;
    }
    
    // [ELASTIC VOLATILITY] Core Update Logic
    // Computes the 'Elastic Factor' based on Volatility Ratio and Noise Penalty
    void UpdateElasticFactor() {
        if (!elasticEnable) {
             m_elasticFactor = 1.0;
             m_noiseFactor = 1.0;
             m_lastElasticUpdateMs = 0;
             m_lastElasticBar = 0;
             return;
        }

        const datetime barNow = iTime(_Symbol, PERIOD_CURRENT, 0);
        const uint nowMs = (uint)GetTickCount();
        const bool newBar = (barNow > 0 && barNow != m_lastElasticBar);
        const uint minIntervalMs = 250;
        const uint elapsedMs = (uint)(nowMs - m_lastElasticUpdateMs);
        if (!newBar && m_lastElasticUpdateMs != 0 && elapsedMs < minIntervalMs) return;
        
        // 1. Calculate VR (Volatility Ratio)
        double vr = CalculateVolatilityRatio(_Symbol, elasticAtrShort, elasticAtrLong);
        
        // 2. Calculate Efficiency Ratio (ER) for Noise Penalty
        // Using Short ATR period as window for 'immediate noise'
        double er = CalculateEfficiencyRatio(_Symbol, elasticAtrShort);
        m_noiseFactor = CalculateNoiseFactor(er); // 1.0 (Clean) to 2.0 (Noisy)
        
        // 3. Hybrid Factor
        double rawFactor = vr * m_noiseFactor;
        
        // 4. Bound and Store
        m_elasticFactor = MathMin(elasticMaxScale, MathMax(1.0, rawFactor));
        m_lastElasticUpdateMs = nowMs;
        if (barNow > 0) m_lastElasticBar = barNow;
        
        // Debug Log (Periodic or Threshold based?)
        // if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY) && m_elasticFactor > 1.2) {
        //     CAuroraLogger::InfoStrategy(StringFormat("[ELASTIC] Factor=%.2f (VR=%.2f, Noise=%.2f)", m_elasticFactor, vr, m_noiseFactor));
        // }
    }
    
    double GetElasticFactor() { return m_elasticFactor; }
    double GetNoiseFactor() { return m_noiseFactor; }
    bool   IsElasticEnabled() { return elasticEnable; }

    void Deinit() {
        if (trailAtrHandle != INVALID_HANDLE) {
            IndicatorRelease(trailAtrHandle);
            trailAtrHandle = INVALID_HANDLE;
        }
        if (beAtrHandle != INVALID_HANDLE) {
            IndicatorRelease(beAtrHandle);
            beAtrHandle = INVALID_HANDLE;
        }
        
        m_vStops.ClearAll(); // [NEW] Cleanup Visuals
    }

private:
    // Any other private helpers...
    
    public:
    void SetNoiseFactor(double factor) { m_noiseFactor = factor; }




    private:
    bool IsBuyType(const ENUM_ORDER_TYPE type) const {
        return (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT);
    }

    ENUM_ORDER_TYPE ReverseType(const ENUM_ORDER_TYPE type) const {
        switch(type) {
            case ORDER_TYPE_BUY:            return ORDER_TYPE_SELL;
            case ORDER_TYPE_SELL:           return ORDER_TYPE_BUY;
            case ORDER_TYPE_BUY_LIMIT:      return ORDER_TYPE_SELL_LIMIT;
            case ORDER_TYPE_SELL_LIMIT:     return ORDER_TYPE_BUY_LIMIT;
            case ORDER_TYPE_BUY_STOP:       return ORDER_TYPE_SELL_STOP;
            case ORDER_TYPE_SELL_STOP:      return ORDER_TYPE_BUY_STOP;
            case ORDER_TYPE_BUY_STOP_LIMIT: return ORDER_TYPE_SELL_STOP_LIMIT;
            case ORDER_TYPE_SELL_STOP_LIMIT:return ORDER_TYPE_BUY_STOP_LIMIT;
            default:                        return type;
        }
    }

    void NormalizeStopsForOrder(const ENUM_ORDER_TYPE type, const string symbol, const double entryPrice,
                                double &sl, double &tp, const bool ignoreSL, const bool ignoreTP) const {
        if (ignoreSL) sl = 0;
        if (ignoreTP) tp = 0;
        const bool isBuy = IsBuyType(type);
        if (sl > 0) {
            double dist = MathAbs(entryPrice - sl);
            sl = isBuy ? entryPrice - dist : entryPrice + dist;
            sl = NormalizePrice(sl, symbol);
        }
        if (tp > 0) {
            double dist = MathAbs(entryPrice - tp);
            tp = isBuy ? entryPrice + dist : entryPrice - dist;
            tp = NormalizePrice(tp, symbol);
        }
    }

    int CountPendingOrders(string symbol, ENUM_ORDER_TYPE type) {
        int count = 0;
        int total = OrdersTotal();
        for(int i=0; i<total; i++) {
            ulong ticket = OrderGetTicket(i);
            if(OrderGetInteger(ORDER_MAGIC) == magicNumber && OrderGetString(ORDER_SYMBOL) == symbol) {
                if(OrderGetInteger(ORDER_TYPE) == type) count++;
            }
        }
        return count;
    }

    bool SendStrictLimit(ENUM_ORDER_TYPE type, double sl, double tp, string comment, string name, double vol, bool isl, bool itp) {
        if(name == NULL) name = _Symbol;
        
        // Anti-Spam: One pending per side allowed
        if(CountPendingOrders(name, type) > 0) return false;

        double price = 0;
        int digits = (int)SymbolInfoInteger(name, SYMBOL_DIGITS);
        
        // STRICT SNIPER EXECUTION (ZERO SLIPPAGE)
        // We target the EXACT current price
        
        if(type == ORDER_TYPE_BUY_LIMIT) {
             // Buy Limit @ Ask (Aggressive Entry at Market Price)
             price = SymbolInfoDouble(name, SYMBOL_ASK);
        } else if(type == ORDER_TYPE_SELL_LIMIT) {
             // Sell Limit @ Bid (Aggressive Entry at Market Price)
             price = SymbolInfoDouble(name, SYMBOL_BID);
        }

        price = NormalizePrice(price, name);
        
        // Expiration Logic
        datetime expiration = 0;
        if(entryExpirationSec > 0) expiration = AuroraClock::Now() + entryExpirationSec;
        
        // ENFORCE IOC (Immediate Or Cancel)
        // This is the core of "Zero Slippage": If broker cannot fill at this price or better immediately, KILL IT.
        ENUM_FILLING strictFilling = FILLING_IOK;
        
        // Normalize SL/TP with unified semantics (isl/itp = ignore flags)
        double sentSL = sl;
        double sentTP = tp;
        NormalizeStopsForOrder(type, name, price, sentSL, sentTP, isl, itp);
        
        // [ELASTIC VOLATILITY] Apply Elastic Factor to SL/TP
        if (elasticEnable && elasticApplySL) {
            // SL Scaling
            if (sentSL > 0) {
                double baseDist = MathAbs(price - sentSL);
                double elasticDist = baseDist * m_elasticFactor;
                if (IsBuyType(type)) sentSL = price - elasticDist;
                else sentSL = price + elasticDist;
                sentSL = NormalizePrice(sentSL, name);
            }
            // TP Scaling
            if (sentTP > 0) {
                double baseDist = MathAbs(price - sentTP);
                double elasticDist = baseDist * m_elasticFactor;
                if (IsBuyType(type)) sentTP = price + elasticDist;
                else sentTP = price - elasticDist;
                sentTP = NormalizePrice(sentTP, name);
            }
        } else if (exitOnClose && sentSL > 0) {
            // ExitOnClose only (no elastic)
            double baseDist = MathAbs(price - sentSL);
            double hardDist = baseDist * exitHardSLMult;
            if (IsBuyType(type)) sentSL = price - hardDist;
            else sentSL = price + hardDist;
            sentSL = NormalizePrice(sentSL, name);
        }

        // Use PendingOrder helper (it calls async manager)
        return pendingOrder(type, magicNumber, price, sentSL, sentTP, vol, 0, expiration, (expiration>0 ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC), name, comment, strictFilling, riskMode, risk, slippage, riskMaxTotalLots);
    }
    
    // Stop Limit Helper Removed (Mode Deprecated)

    bool OpenOrder(ENUM_ORDER_TYPE type, double price, double sl, double tp, string comment = "", string name = NULL, double vol = 0, bool isl = false, bool itp = false) {
        if (name == NULL) name = _Symbol;

        // --- SIMULATION HOOK (Rejection / Spread) ---
        if (g_simulation.IsEnabled()) {
            if (!g_simulation.CheckExecution(name)) return false;
        }
        // --------------------------------------------

        if (type == ORDER_TYPE_BUY) price = Ask(name);
        else if (type == ORDER_TYPE_SELL) price = Bid(name);

        double sentSL = sl;
        double sentTP = tp;
        NormalizeStopsForOrder(type, name, price, sentSL, sentTP, isl, itp);

        // Handle Comment
        if (comment == "" || comment == NULL) { // set_comment was usually true or implicit
             // Note: Original logic had complex comment logic, simplifying for readability but keeping behavior
             // We'll rely on caller passing computed comment or we compute it if empty.
             // Actually, to fully DRY, let's keep it simple here and let caller handle specific comment rules or basic fallback.
             // The original code calculated distance d = MathAbs(in - sl).
             if(sentSL > 0) {
                 int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
                 double d = MathAbs(price - sentSL);
                 comment = DoubleToString(d, digits);
             }
        }

        // [ELASTIC/EXIT-ON-CLOSE] SL/TP Logic
        if (sentSL > 0 || sentTP > 0) {
            // 1. Elastic Scaling (Theoretical SL/TP)
            if (elasticEnable && elasticApplySL) {
                if (sentSL > 0) {
                    double baseDist = MathAbs(price - sentSL);
                    double effectiveDist = baseDist * m_elasticFactor;
                    
                    // ExitOnClose compounding (Broker Hard SL)
                    if (exitOnClose) effectiveDist *= exitHardSLMult;
                    
                    if (IsBuyType(type)) sentSL = price - effectiveDist;
                    else                 sentSL = price + effectiveDist;
                    sentSL = NormalizePrice(sentSL, name);
                }
                
                if (sentTP > 0) {
                    double baseDist = MathAbs(price - sentTP);
                    double effectiveDist = baseDist * m_elasticFactor;
                    
                    if (IsBuyType(type)) sentTP = price + effectiveDist;
                    else                 sentTP = price - effectiveDist;
                    sentTP = NormalizePrice(sentTP, name);
                }
            } 
            else if (exitOnClose && sentSL > 0) {
                // ExitOnClose only (no elastic)
                double baseDist = MathAbs(price - sentSL);
                double hardDist = baseDist * exitHardSLMult;
                if (IsBuyType(type)) sentSL = price - hardDist;
                else                 sentSL = price + hardDist;
                sentSL = NormalizePrice(sentSL, name);
            }
        }

        return order(type, magicNumber, price, sentSL, sentTP, risk, slippage, isl, itp, comment, name, vol, filling, riskMode, virtualBalance, riskMaxLotSize, riskMaxTotalLots);
    }

    public:
    bool BuyOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
       if(name == NULL) name = _Symbol;
       
       ENUM_ORDER_TYPE type = (entryMode == ENTRY_MODE_MARKET ? ORDER_TYPE_BUY :
                               entryMode == ENTRY_MODE_LIMIT  ? ORDER_TYPE_BUY_LIMIT :
                                                               ORDER_TYPE_BUY_STOP);
       if (reverse) type = ReverseType(type);
       
       if (entryMode == ENTRY_MODE_MARKET) {
           double entryPrice = IsBuyType(type) ? Ask(name) : Bid(name);
           return OpenOrder(type, entryPrice, sl, tp, comment, name, vol, isl, itp);
       }
       else if (entryMode == ENTRY_MODE_LIMIT) {
           // Institutional Guard: Deduplication
           if (CountPendingOrders(name, type) > 0) return false;
           return SendStrictLimit(type, sl, tp, comment, name, vol, isl, itp);
       }
        else if (entryMode == ENTRY_MODE_STOP) {
            // Institutional Guard: Deduplication
            if (CountPendingOrders(name, type) > 0) return false;
            
            double point = SymbolInfoDouble(name, SYMBOL_POINT);
            double trigger = IsBuyType(type) ? (Ask(name) + (entryDistPts * point)) : (Bid(name) - (entryDistPts * point));
            datetime expiry = (entryExpirationSec > 0) ? AuroraClock::Now() + entryExpirationSec : 0;
            
            double sentSL = sl;
            double sentTP = tp;
            NormalizeStopsForOrder(type, name, trigger, sentSL, sentTP, isl, itp);
            
            // [EXIT-ON-CLOSE] Hard SL Logic for Pending
            if (exitOnClose && sentSL > 0) {
                 double dist = MathAbs(trigger - sentSL);
                 double hardDist = dist * exitHardSLMult;
                 sentSL = IsBuyType(type) ? (trigger - hardDist) : (trigger + hardDist);
                 sentSL = NormalizePrice(sentSL, name);
            }
            
            // --- SIMULATION HOOK (Virtual Pending) ---
            if (g_simulation.IsEnabled()) {
                double computedVol = (vol > 0) ? vol : calcVolume(trigger, sentSL, risk, sentTP, magicNumber, name, virtualBalance, riskMode);
                if (riskMaxTotalLots > 0) {
                    double curTotal = positionsTotalVolume(magicNumber, name) + ordersTotalVolume(magicNumber, name);
                    if ((curTotal + computedVol) > riskMaxTotalLots) {
                        if (CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
                            CAuroraLogger::WarnRisk(StringFormat("[MAX LOTS] Limite %.2f dépassée (actuel=%.2f, nouveau=%.2f)", riskMaxTotalLots, curTotal, computedVol));
                        return false;
                    }
                }
                g_simulation.PlaceVirtualPending(type, trigger, sentSL, sentTP, computedVol, magicNumber, name, comment, expiry);
                return true; // Virtual Order Placed
            }
            // -----------------------------------------
            
            return pendingOrder(type, magicNumber, trigger, sentSL, sentTP, vol, 0, expiry, expiry>0?ORDER_TIME_SPECIFIED:ORDER_TIME_GTC, name, comment, filling, riskMode, risk, slippage, riskMaxTotalLots);
        }
       return false;
    }

    bool SellOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
       if(name == NULL) name = _Symbol;

       ENUM_ORDER_TYPE type = (entryMode == ENTRY_MODE_MARKET ? ORDER_TYPE_SELL :
                               entryMode == ENTRY_MODE_LIMIT  ? ORDER_TYPE_SELL_LIMIT :
                                                               ORDER_TYPE_SELL_STOP);
       if (reverse) type = ReverseType(type);

       if (entryMode == ENTRY_MODE_MARKET) {
           double entryPrice = IsBuyType(type) ? Ask(name) : Bid(name);
           return OpenOrder(type, entryPrice, sl, tp, comment, name, vol, isl, itp);
       }
       else if (entryMode == ENTRY_MODE_LIMIT) {
           // Institutional Guard: Deduplication
           if (CountPendingOrders(name, type) > 0) return false;
           return SendStrictLimit(type, sl, tp, comment, name, vol, isl, itp);
       }
        else if (entryMode == ENTRY_MODE_STOP) {
            // Institutional Guard: Deduplication
            if (CountPendingOrders(name, type) > 0) return false;

            double point = SymbolInfoDouble(name, SYMBOL_POINT);
            double trigger = IsBuyType(type) ? (Ask(name) + (entryDistPts * point)) : (Bid(name) - (entryDistPts * point));
            datetime expiry = (entryExpirationSec > 0) ? AuroraClock::Now() + entryExpirationSec : 0;

            double sentSL = sl;
            double sentTP = tp;
            NormalizeStopsForOrder(type, name, trigger, sentSL, sentTP, isl, itp);
            
            // [EXIT-ON-CLOSE] Hard SL Logic for Pending
            if (exitOnClose && sentSL > 0) {
                 double dist = MathAbs(trigger - sentSL);
                 double hardDist = dist * exitHardSLMult;
                 sentSL = IsBuyType(type) ? (trigger - hardDist) : (trigger + hardDist);
                 sentSL = NormalizePrice(sentSL, name);
            }

            // --- SIMULATION HOOK (Virtual Pending) ---
            if (g_simulation.IsEnabled()) {
                double computedVol = (vol > 0) ? vol : calcVolume(trigger, sentSL, risk, sentTP, magicNumber, name, virtualBalance, riskMode);
                if (riskMaxTotalLots > 0) {
                    double curTotal = positionsTotalVolume(magicNumber, name) + ordersTotalVolume(magicNumber, name);
                    if ((curTotal + computedVol) > riskMaxTotalLots) {
                        if (CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
                            CAuroraLogger::WarnRisk(StringFormat("[MAX LOTS] Limite %.2f dépassée (actuel=%.2f, nouveau=%.2f)", riskMaxTotalLots, curTotal, computedVol));
                        return false;
                    }
                }
                g_simulation.PlaceVirtualPending(type, trigger, sentSL, sentTP, computedVol, magicNumber, name, comment, expiry);
                return true; // Virtual Order Placed
            }
            // -----------------------------------------

            return pendingOrder(type, magicNumber, trigger, sentSL, sentTP, vol, 0, expiry, expiry>0?ORDER_TIME_SPECIFIED:ORDER_TIME_GTC, name, comment, filling, riskMode, risk, slippage, riskMaxTotalLots);
        }
       return false;
    }

    bool BuyOpen(double in, double sl, double tp, bool isl = false, bool itp = false, string name = NULL, double vol = 0, string comment = "", bool set_comment = true) {
        // Comment Logic preserved from original to ensure exact behavior if set_comment is false
        if (comment == "" || comment == NULL) {
             // Let OpenOrder handle the default comment calc if empty string passed
             comment = ""; 
        } else if (!set_comment && (comment == "" || comment == NULL)) {
            // Force a space to prevent OpenOrder from auto-calculating if set_comment is false
             comment = " "; 
        }
        ENUM_ORDER_TYPE type = reverse ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        return OpenOrder(type, in, sl, tp, comment, name, vol, isl, itp);
    }
    
    bool SellOpen(double in, double sl, double tp, bool isl = false, bool itp = false, string name = NULL, double vol = 0, string comment = "", bool set_comment = true) {
         // Comment Logic preserved
        if (comment == "" || comment == NULL) {
             comment = ""; 
        } else if (!set_comment && (comment == "" || comment == NULL)) {
             comment = " "; 
        }
        ENUM_ORDER_TYPE type = reverse ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        return OpenOrder(type, in, sl, tp, comment, name, vol, isl, itp);
    }

    bool SyncPendingOrder(ulong ticket, ENUM_ORDER_TYPE type, double price, double sl, double tp, double vol, string comment, string name = NULL, datetime expiration = 0) {
        if (ticket == 0) return false;
        if (name == NULL) name = _Symbol;

        // [EXIT-ON-CLOSE] Hard SL Logic
        if (exitOnClose && sl > 0) {
            double dist = MathAbs(price - sl);
            double hardDist = dist * exitHardSLMult;
            if (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT) sl = price - hardDist;
            else sl = price + hardDist;
            
            sl = NormalizePrice(sl, name);
        }
        
        if (!OrderSelect(ticket)) return false;

        if (g_asyncManager.HasPending(magicNumber, name, TRADE_ACTION_REMOVE, (ENUM_ORDER_TYPE)-1, 0, ticket)) return true;
        if (g_asyncManager.HasPending(magicNumber, name, TRADE_ACTION_MODIFY, type, 0, ticket)) return true;
        if (g_asyncManager.HasPending(magicNumber, name, TRADE_ACTION_PENDING, type)) return true;
        
        // 1. Check Volume Mismatch (Restart Robustness)
        double currentVol = OrderGetDouble(ORDER_VOLUME_CURRENT);
        if (MathAbs(currentVol - vol) > 0.001) {
            // Volume changed (User changed Risk on restart?) -> Must Recreate
            if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                CAuroraLogger::InfoOrders(StringFormat("[SYNC] Volume Mismatch for #%I64u (Old: %.2f, New: %.2f). Recreating...", ticket, currentVol, vol));
            }
            
            // Delete Old
            if (PendingOrderClose(ticket)) {
                 // Create New
                 return PendingOrder(type, price, sl, tp, vol, 0, expiration, (expiration > 0 ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC), name, comment);
            }
            return false;
        }
        
        // 2. Volume OK -> Check Price/SL/TP/Expiration Update (tick-aware)
        double currentPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double currentSL = OrderGetDouble(ORDER_SL);
        double currentTP = OrderGetDouble(ORDER_TP);
        double tickSize = SymbolInfoDouble(name, SYMBOL_TRADE_TICK_SIZE);
        if (tickSize <= 0.0) tickSize = _Point;
        double cmpPrice = NormalizePrice(price, name);
        double cmpSL = (sl != 0.0 ? NormalizePrice(sl, name) : 0.0);
        double cmpTP = (tp != 0.0 ? NormalizePrice(tp, name) : 0.0);
        
        bool modify = false;
        if (MathAbs(currentPrice - cmpPrice) > (tickSize * 0.5)) modify = true;
        if (MathAbs(currentSL - cmpSL) > (tickSize * 0.5)) modify = true;
        if (MathAbs(currentTP - cmpTP) > (tickSize * 0.5)) modify = true;
        ENUM_ORDER_TYPE_TIME desiredTimeType = (expiration > 0 ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC);
        datetime desiredExpiration = expiration;
        NormalizeExpirationForSymbol(name, desiredExpiration, desiredTimeType);
        ENUM_ORDER_TYPE_TIME currentTimeType = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
        datetime currentExpiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        if (currentTimeType == ORDER_TIME_GTC && desiredTimeType == ORDER_TIME_SPECIFIED) {
            desiredTimeType = ORDER_TIME_GTC;
            desiredExpiration = 0;
        }
        if (currentTimeType != desiredTimeType) modify = true;
        else if (desiredTimeType == ORDER_TIME_SPECIFIED && currentExpiration != desiredExpiration) modify = true;
    
        if (modify) {
             return modifyPendingOrder(ticket, cmpPrice, cmpSL, cmpTP, 0, desiredTimeType, desiredExpiration);
        }
        
        return true; // synced
    }

    bool PendingOrder(ENUM_ORDER_TYPE ot, double in, double sl = 0, double tp = 0, double vol = 0, double stoplimit = 0, datetime expiration = 0, ENUM_ORDER_TYPE_TIME timeType = 0, string symbol = NULL, string comment = "") {
        return pendingOrder(ot, magicNumber, in, sl, tp, vol, stoplimit, expiration, timeType, symbol, comment, filling, riskMode, risk, slippage, riskMaxTotalLots);
    }

    void BuyClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, filling);
        else
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, filling);
    }

    void SellClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, filling);
        else
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, filling);
    }

    bool PosClose(ulong ticket) {
        return closeOrder(ticket, slippage, filling);
    }

    // [NEW] Check Virtual Exits (On Bar Close)
    void CheckVirtualExits(const CAuroraSnapshot &snap) {
        if (!exitOnClose) return;
        
        // Garbage Collect
        m_vStops.Clean(snap);
        
        int total = snap.Total();
        for(int i=0; i<total; i++) {
            SAuroraPos pos = snap.Get(i);
            if(pos.magic != magicNumber) continue;
            
            double vSL = m_vStops.Get(pos.ticket);
            if (vSL <= 0) continue; // No virtual stop active
            
            bool closeIt = false;
            // Check Close[1] vs Virtual SL
            // Note: Use iClose(_Symbol, PERIOD_CURRENT, 1). 
            // We assume snap symbol matches chart symbol for now or use pos.symbol
            double close1 = iClose(pos.symbol, PERIOD_CURRENT, 1);
            
            if(pos.type == POSITION_TYPE_BUY) {
                if(close1 < vSL) closeIt = true;
            } else {
                if(close1 > vSL) closeIt = true;
            }
            
            if(closeIt) {
                if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                    CAuroraLogger::InfoStrategy(StringFormat("[EXIT-ON-CLOSE] Ticket #%I64u Closed. Close[1]=%.5f breached VirtualSL=%.5f", pos.ticket, close1, vSL));
                }
                closeOrder(pos.ticket, slippage, filling);
                // Visual removed automatically on next Clean()
            }
        }
    }
    
    // [NEW] Wrapper for Trailing to Support Virtual Stops
    void CheckForTrailAndVirtual(const CAuroraSnapshot &snap) {
        // We reuse the global checkForTrail logic BUT we need to know the 'calculated' SL level 
        // WITHOUT modifying the order if exitOnClose is true.
        // The global `checkForTrail` modifies orders directly. 
        // Refactoring global `checkForTrail` to return the value or support 'VirtualMode' is complex.
        // EASIER: Copy/Adapt logic or Add 'VirtualMode' param to global function?
        // Let's add 'VirtualMode' & 'VirtualManager' to `checkForTrail` signature (overload).
        
        // For now, let's just call the standard one. Warning: It will modify Hard SL!
        // WE MUST BLOCK IT.
        // Access `checkForTrail` inside `aurora_engine.mqh`. It needs modification.
        // Plan:
        // 1. Modify `checkForTrail` global function to accept `CVirtualStopManager*` and `bool virtualMode`.
        // 2. If virtualMode, do NOT send request, but call mgr->Set().
        
        // [ELASTIC VOLATILITY] Scale Trailing Parameters if enabled
        double effectiveStopLevel = trailingStopLevel;
        double effectiveAtrMult = trailAtrMult;
        
        if (elasticEnable && elasticApplyTrail && m_elasticFactor > 1.0) {
            effectiveStopLevel = trailingStopLevel * m_elasticFactor;
            effectiveAtrMult = trailAtrMult * m_elasticFactor;
        }

        checkForTrail(magicNumber, effectiveStopLevel, slippage, filling, trailMode, trailAtrHandle, effectiveAtrMult,
                        snap, 
                        (exitOnClose ? &m_vStops : NULL), // Pass Manager if Virtual
                        exitOnClose, exitHardSLMult);    // Pass Mode and Mult
    }

    // [LOGIC-3] Initialize virtual stop immediately when pending orders fill
    void InitVirtualStopIfNeeded(ulong ticket, double sl, ENUM_POSITION_TYPE ptype) {
        if (!exitOnClose) return;
        if (sl <= 0) return;  // No SL to virtualize
        
        // Set virtual stop to the hard SL level immediately
        m_vStops.Set(ticket, sl, (ptype == POSITION_TYPE_BUY));
        
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
            CAuroraLogger::InfoOrders(StringFormat("[VIRTUAL] Init on fill: Ticket=%I64u, SL=%.5f", ticket, sl));
    }

    bool PendingOrderClose(ulong ticket) {
        return closePendingOrder(ticket);
    }

    void PendingOrdersClose(ENUM_ORDER_TYPE ot, string name = NULL) {
        closePendingOrders(ot, magicNumber, name);
    }

    int PosTotal(string name = NULL) {
        return positionsTotalMagic(magicNumber, name);
    }

    int OrdTotal(string name = NULL) {
        return ordersTotalMagic(magicNumber, name);
    }

    int OPTotal(string name = NULL) {
        return opTotalMagic(magicNumber, name);
    }

    ulong GetMagic() {
        return magicNumber;
    }

    void SetMagic(ulong magic) {
        magicNumber = magic;
    }

    double GetTotalProfit(string symbol = NULL) {
        if(symbol == NULL) symbol = _Symbol;
        return getProfit(magicNumber, symbol);
    }

    double GetTotalVolume(string symbol = NULL) {
        if(symbol == NULL) symbol = _Symbol;
        double vols[];
        int n = positionsVolumes(magicNumber, vols, symbol);
        double total = 0.0;
        for(int i=0; i<n; i++) total += vols[i];
        return total;
    }


    
    // Added variable for configurable BE: stored in class for wrapper too
    int beMinOffsetPts;

    void CheckForTrail() {
        // [ELASTIC VOLATILITY] Scale Trailing Parameters if enabled
        double effectiveStopLevel = trailingStopLevel;
        double effectiveAtrMult = trailAtrMult;
        
        if (elasticEnable && elasticApplyTrail && m_elasticFactor > 1.0) {
            // Wider trailing distance in volatile/noisy markets
            effectiveStopLevel = trailingStopLevel * m_elasticFactor;
            effectiveAtrMult = trailAtrMult * m_elasticFactor;
        }
        
        checkForTrail(magicNumber, effectiveStopLevel, slippage, filling, trailMode, trailAtrHandle, effectiveAtrMult, CAuroraSnapshot());
    }

    void CheckForTrail(const CAuroraSnapshot &snap) {
        // [ELASTIC VOLATILITY] Scale Trailing Parameters if enabled
        double effectiveStopLevel = trailingStopLevel;
        double effectiveAtrMult = trailAtrMult;
        
        if (elasticEnable && elasticApplyTrail && m_elasticFactor > 1.0) {
            effectiveStopLevel = trailingStopLevel * m_elasticFactor;
            effectiveAtrMult = trailAtrMult * m_elasticFactor;
        }
        
        checkForTrail(magicNumber, effectiveStopLevel, slippage, filling, trailMode, trailAtrHandle, effectiveAtrMult, snap);
    }




    


    void CheckForEquity() {
        checkForEquity(magicNumber, equityDrawdownLimit, slippage, filling, virtualBalance);
    }

    void CheckForEquity(const CAuroraSnapshot &snap) {
        checkForEquity(magicNumber, equityDrawdownLimit, slippage, filling, virtualBalance, snap);
    }

    void CheckForBE(const ENUM_BE_MODE mode, const double triggerRatio, const int triggerPts, const double spreadMult, const int slDevFallback, const bool onNewBar) {
        // [ELASTIC VOLATILITY] Scale BE Trigger if enabled
        double effectiveRatio = triggerRatio;
        int effectivePts = triggerPts;
        
        if (elasticEnable && elasticApplyBE && m_elasticFactor > 1.0) {
            // Require more profit before moving to BE in volatile markets
            effectiveRatio = triggerRatio * m_elasticFactor;
            effectivePts = (int)(triggerPts * m_elasticFactor);
        }
        
        checkForBE(magicNumber, mode, effectiveRatio, effectivePts, spreadMult, slDevFallback, onNewBar, beMinOffsetPts, beAtrPeriod, beAtrMultiplier, beAtrHandle, slippage, filling, (exitOnClose ? &m_vStops : NULL), exitOnClose);
    }

    void CheckForBE(const ENUM_BE_MODE mode, const double triggerRatio, const int triggerPts, const double spreadMult, const int slDevFallback, const bool onNewBar, const CAuroraSnapshot &snap) {
        // [ELASTIC VOLATILITY] Scale BE Trigger if enabled
        double effectiveRatio = triggerRatio;
        int effectivePts = triggerPts;
        
        if (elasticEnable && elasticApplyBE && m_elasticFactor > 1.0) {
            effectiveRatio = triggerRatio * m_elasticFactor;
            effectivePts = (int)(triggerPts * m_elasticFactor);
        }
        
        checkForBE(magicNumber, mode, effectiveRatio, effectivePts, spreadMult, slDevFallback, onNewBar, beMinOffsetPts, beAtrPeriod, beAtrMultiplier, beAtrHandle, slippage, filling, snap, (exitOnClose ? &m_vStops : NULL), exitOnClose);
    }
    
    void CleanExpiredPendingOrders() {
        // Only if expiration is configured
        if(entryExpirationSec <= 0) return;
        
        int total = OrdersTotal();
        for(int i = total - 1; i >= 0; --i) {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0) continue;
            
            if((ulong)OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
            
            // Check if it's a pending order (Stop/Limit)
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL) continue; // Skip market orders (unlikely in OrdersTotal but safety check)
            
            long setupTime = OrderGetInteger(ORDER_TIME_SETUP);
            if(setupTime > 0) {
                 if(AuroraClock::Now() - setupTime > entryExpirationSec) {
                      // Expired by our internal logic
                      PendingOrderClose(ticket);
                      if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                          CAuroraLogger::InfoOrders(StringFormat("[EXPIRE] Force Cleanup Pending #%I64u (Age > %ds)", ticket, entryExpirationSec));
                      }
                 }
            }
        }
    }
    
    // --- Order Closing & Deleverage Logic (Integrated from AuroraOrderCloser) ---
    
    // Helper struct for sorting positions by volume
    struct SPosDelev {
        ulong ticket;
        double volume;
    };
    
    // Simple bubbble sort by Volume Descending (internal helper)
    void SortDelev(SPosDelev &arr[]) {
        int total = ArraySize(arr);
        for(int i=0; i<total-1; i++) {
            for(int j=i+1; j<total; j++) {
                if(arr[j].volume > arr[i].volume) {
                    SPosDelev temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }

    void CloseAllPositionsForSymbol(const string symbol) {
        int total = PositionsTotal();
        for(int i = total - 1; i >= 0; --i) {
            ulong ticket = PositionGetTicket(i);
            if(ticket==0) continue;
            if(!PositionSelectByTicket(ticket)) continue;
            if((ulong)PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
            
            if(!PosClose(ticket)) {
                const int err = GetLastError();
                if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                    CAuroraLogger::WarnOrders(StringFormat("[CLOSE-ALL] ticket=%I64u error #%d", ticket, err));
            }
        }
    }

    void ClosePendingsForSymbol(const string symbol) {
        // --- SIMULATION HOOK ---
        if (g_simulation.IsEnabled()) {
            g_simulation.CancelAllVirtualOrders(magicNumber, symbol);
        }
        // -----------------------
        int total = OrdersTotal();
        for(int i = total - 1; i >= 0; --i) {
            ulong ticket = OrderGetTicket(i);
            if(ticket==0) continue;
            if(!OrderSelect(ticket)) continue;
            if((ulong)OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
            if(OrderGetString(ORDER_SYMBOL) != symbol) continue;

            ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(otype==ORDER_TYPE_BUY_LIMIT || otype==ORDER_TYPE_SELL_LIMIT ||
               otype==ORDER_TYPE_BUY_STOP || otype==ORDER_TYPE_SELL_STOP ||
               otype==ORDER_TYPE_BUY_STOP_LIMIT || otype==ORDER_TYPE_SELL_STOP_LIMIT)
            {
               // Use Async Manager Global
               MqlTradeRequest rq; ZeroMemory(rq);
               rq.action = TRADE_ACTION_REMOVE; 
               rq.order = ticket; 
               rq.symbol = symbol; 
               rq.magic = magicNumber;
               
               if(!g_asyncManager.SendAsync(rq)) {
                   int err = GetLastError();
                   if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                       CAuroraLogger::WarnOrders(StringFormat("[CLOSE-PEND-ASYNC] remove #%I64u error %d", ticket, err));
               }
            }
        }
    }

    void DeleveragePositionsToTarget(const string symbol, double targetVolume) {
        if(targetVolume < 0.0) return;

        SPosDelev posArr[];
        double totalVol = 0.0;
        int cnt = 0;

        int total = PositionsTotal();
        for(int i = 0; i < total; ++i) {
            ulong ticket = PositionGetTicket(i);
            if(ticket==0) continue;
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
            if((ulong)PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;

            double v = PositionGetDouble(POSITION_VOLUME);
            totalVol += v;
            
            ArrayResize(posArr, cnt+1);
            posArr[cnt].ticket = ticket;
            posArr[cnt].volume = v;
            cnt++;
        }

        if(totalVol <= targetVolume || cnt == 0) return; // Already compliant

        SortDelev(posArr);

        double currentVol = totalVol;

        // Close biggest to smallest until we fit under target
        for(int i=0; i<cnt; ++i) {
            if(currentVol <= targetVolume) break; // Reached
            
            ulong t = posArr[i].ticket;
            double v = posArr[i].volume;
            
            if(PosClose(t)) { // Uses internal PosClose which handles slippage/filling
                currentVol -= v;
                if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                    CAuroraLogger::InfoOrders(StringFormat("[DELEVERAGE] Removed %.2f lots (Ticket %I64u). Vol: %.2f -> %.2f (Target %.2f)", v, t, totalVol, currentVol, targetVolume));
            }
        }
    }
};

#endif // __AURORA_ENGINE_MQH__
