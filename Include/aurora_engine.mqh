//+------------------------------------------------------------------+
//|                                                    Aurora Engine |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict
#property version   "1.5"

#include <aurora_error_utils.mqh>
#include <aurora_logger.mqh>
#include <aurora_inputs_structs.mqh>

#define AURORA_EAUTILS_VERSION "1.45"

// --- ENUMS ---
enum ENUM_SL {
    SL_SWING, 
    SL_AR, 
    SL_MR, 
    SL_FIXED_POINT 
};

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

// --- MARKET INFO HELPERS ---

double Ask(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    MqlTick tick;
    if (!SymbolInfoTick(name, tick))
        return 0;
    return tick.ask;
}

double Bid(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    MqlTick tick;
    if (!SymbolInfoTick(name, tick))
        return 0;
    return tick.bid;
}

int Spread(string name = NULL) {
    name = name == NULL ? _Symbol : name;
    return (int) SymbolInfoInteger(name, SYMBOL_SPREAD);
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
    
    // Tentative de calcul précis via OrderCalcProfit
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

// Optimization 🟡: Redundant API Calls removed (direct return)
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

double GetSimulatedMarginLevel(double virtualBalance) {
    double simEquity = GetSimulatedEquity(virtualBalance);
    double realMargin = AccountInfoDouble(ACCOUNT_MARGIN);
    if (realMargin <= 0) return 0.0; 
    return (simEquity / realMargin) * 100.0;
}

double ResolveRiskBalance(double balanceOverride, ENUM_RISK risk_mode) {
    if (balanceOverride > 0)
        return GetSimulatedBalance(balanceOverride); // Force Fixed Virtual Balance

    if (risk_mode == RISK_DEFAULT || risk_mode == RISK_FIXED_VOL || risk_mode == RISK_MIN_AMOUNT)
        return MathMin(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    return AccountInfoDouble((ENUM_ACCOUNT_INFO_DOUBLE)((int)risk_mode));
}

double ClampVolumeToSymbol(double vol, const string symbol) {
    double volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    int volDigits = CountDigits(volStep);
    if (volStep > 0)
        vol = MathFloor(vol / volStep) * volStep;
    vol = MathMax(vol, volMin);
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

    if (!HistorySelect(TimeCurrent() - 40 * PeriodSeconds(PERIOD_D1), TimeCurrent())) {
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
    if (!HistorySelect(TimeCurrent() - 2 * (nCandles + 1) * PeriodSeconds(PERIOD_CURRENT), TimeCurrent())) {
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
        if (TimeCurrent() < dealTime + nCandles * PeriodSeconds(PERIOD_CURRENT)) return true;
    }
    return false;
}

// --- CALCULATION HELPERS (Volume, Price, Cost) ---

double calcVolumeFromDistance(const string symbol,
                              double distance,
                              double risk,
                              ENUM_RISK risk_mode,
                              double balanceOverride = 0.0) {
    string sym = (symbol == NULL ? _Symbol : symbol);
    double point = SymbolInfoDouble(sym, SYMBOL_POINT);
    double tv = GetTickValue(sym);
    double balanceBase = ResolveRiskBalance(balanceOverride, risk_mode);

    if (risk_mode == RISK_FIXED_VOL)
        return ClampVolumeToSymbol(risk, sym);
    if (risk_mode == RISK_MIN_AMOUNT) {
        static bool warned = false;
        if (!warned && CAuroraLogger::IsEnabled(AURORA_LOG_RISK)) {
            CAuroraLogger::WarnRisk("RISK_MIN_AMOUNT: mode non standard, taille calculée = EQUITY/risk. Vérifiez la cohérence (lots élevés possibles).");
            warned = true;
        }
        double volStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
        double vol = AccountInfoDouble(ACCOUNT_EQUITY) / MathMax(risk, 0.0001) * volStep;
        return ClampVolumeToSymbol(vol, sym);
    }

    if (IsLessOrEqual(distance, 0) || IsLessOrEqual(point, 0) || IsLessOrEqual(tv, 0))
        distance = point;
    double vol = (balanceBase * risk) / distance * point / tv;
    return ClampVolumeToSymbol(vol, sym);
}

double CalculateMartingaleVolume(double in, double sl, double tp, double risk, double martingaleRisk, ulong magic, string name, ENUM_RISK risk_mode, double current_balance) {
    double vol = 0.0;
    ulong ticket = getLatestTicket(magic);
    if (ticket != 0) {
        if(PositionSelectByTicket(ticket)) {
            // If position still exists, use its ID to find deal history. 
            // Note: Martingale usually applies AFTER close. But let's keep original logic flows.
            HistorySelectByPosition(PositionGetInteger(POSITION_IDENTIFIER));
        } else {
            // Try to find by history if position is closed
             if(HistorySelectByPosition(ticket)) {
                // ticket might be a deal ticket or position ticket. 
                // getLatestTicket returns a DEAL ticket usually? 
                // Let's check getLatestTicket impl. It returns HistoryDealGetTicket.
             }
             // For safety, HistorySelect should cover recent history.
             // We assume getLatestTicket returns a valid DEAL ticket from history.
             HistoryDealSelect(ticket);
        }

        // Ensure we selected the deal
        if(HistoryDealSelect(ticket)) {
            double lprofit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if (lprofit < 0) {
                double lin = HistoryDealGetDouble(ticket, DEAL_PRICE);
                double lsl = HistoryDealGetDouble(ticket, DEAL_SL);
                double lvol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                
                // Avoid division by zero
                double recoveryDist = MathAbs(in - tp);
                if(recoveryDist <= 0) recoveryDist = SymbolInfoDouble(name, SYMBOL_POINT);

                vol = 2 * MathAbs(lin - lsl) * lvol / recoveryDist;
                
                double balanceBase = ResolveRiskBalance(current_balance, risk_mode);
                double point = SymbolInfoDouble(name, SYMBOL_POINT);
                double tv = GetTickValue(name);
                double dist = MathMax(MathAbs(in - sl), point);
                
                if(dist > 0 && tv > 0) {
                    double capVol = (balanceBase * martingaleRisk) / dist * point / tv;
                    vol = MathMin(vol, capVol);
                }
            }
        }
    }
    return ClampVolumeToSymbol(vol, name);
}

double calcVolume(double in, double sl, double risk = 0.01, double tp = 0, bool martingale = false, double martingaleRisk = 0.04, ulong magic = 0, string name = NULL, double balance = 0, ENUM_RISK risk_mode = 0) {
    name = name == NULL ? _Symbol : name;
    if (sl == 0)
        sl = tp;

    double distance = MathAbs(in - sl);
    if (IsLessOrEqual(distance, 0) && tp != 0)
        distance = MathAbs(in - tp);
    if (IsLessOrEqual(distance, 0))
        distance = SymbolInfoDouble(name, SYMBOL_POINT);

    double vol = calcVolumeFromDistance(name, distance, risk, risk_mode, balance);

    if (martingale) {
        // Martingale logic likely needs balanceOverride too if it uses ResolveRiskBalance internally or equity?
        // Checking CalculateMartingaleVolume signature...
        vol = CalculateMartingaleVolume(in, sl, tp, risk, martingaleRisk, magic, name, risk_mode, balance);
    }

    return vol;
}

double calcVolume(double vol, string symbol = NULL) {
    return calcVolume(1, 1, vol, 0, false, 0, 0, symbol, 0, RISK_FIXED_VOL);
}

double calcVolume(ENUM_RISK risk_mode, double risk, double in = 0, double sl = 0, string symbol = NULL) {
    return calcVolume(in, sl, risk, 0, false, 0, 0, symbol, 0, risk_mode);
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

bool IsFillingTypeAllowed(string symbol, ENUM_ORDER_TYPE_FILLING fill_type, ENUM_SYMBOL_TRADE_EXECUTION exec_type) {
    int filling = (int) SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    return((filling & fill_type & exec_type) == (fill_type & exec_type));
}

bool IsFillingTypeAllowed(string symbol, ENUM_ORDER_TYPE_FILLING fill_type) {
    int exec = (int) SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
    if ((exec & SYMBOL_TRADE_EXECUTION_INSTANT) == SYMBOL_TRADE_EXECUTION_INSTANT)
        exec = SYMBOL_TRADE_EXECUTION_INSTANT;
    else if ((exec & SYMBOL_TRADE_EXECUTION_MARKET) == SYMBOL_TRADE_EXECUTION_MARKET)
        exec = SYMBOL_TRADE_EXECUTION_MARKET;
    else if ((exec & SYMBOL_TRADE_EXECUTION_EXCHANGE) == SYMBOL_TRADE_EXECUTION_EXCHANGE)
        exec = SYMBOL_TRADE_EXECUTION_EXCHANGE;
    else if ((exec & SYMBOL_TRADE_EXECUTION_REQUEST) == SYMBOL_TRADE_EXECUTION_REQUEST)
        exec = SYMBOL_TRADE_EXECUTION_REQUEST;
    return IsFillingTypeAllowed(symbol, fill_type, (ENUM_SYMBOL_TRADE_EXECUTION) exec);
}

// --- CORE TRADING FUNCTIONS ---

bool order(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double risk = 0.01, bool martingale = false, double martingaleRisk = 0.04, int slippage = 30, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0, ENUM_FILLING filling = FILLING_DEFAULT, ENUM_RISK risk_mode = RISK_DEFAULT, double balanceOverride = -1) {
    name = name == NULL ? _Symbol : name;
    int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
    int err;


    in = NormalizeDouble(in, digits);
    tp = NormalizeDouble(tp, digits);
    sl = NormalizeDouble(sl, digits);

    if (ot == ORDER_TYPE_BUY) {
        in = Ask(name);
        if (sl != 0 && IsGreaterOrEqual(sl, Bid(name))) return false;
        if (tp != 0 && IsLessOrEqual(tp, Bid(name))) return false;
    } else if (ot == ORDER_TYPE_SELL) {
        in = Bid(name);
        if (sl != 0 && IsLessOrEqual(sl, Ask(name))) return false;
        if (tp != 0 && IsGreaterOrEqual(tp, Ask(name))) return false;
    }

    if (MQLInfoInteger(MQL_TESTER) && in == 0) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders("OpenPrice is 0!");
        return false;
    }

    if (comment == "" && positionsTotalMagic(magic, name) == 0)
        comment = sl ? DoubleToString(MathAbs(in - sl), digits) : tp ? DoubleToString(MathAbs(in - tp), digits) : "";

    if (vol == 0)
    if (vol == 0)
        vol = calcVolume(in, sl, risk, tp, martingale, martingaleRisk, magic, name, balanceOverride, risk_mode);


    if (isl) sl = 0;
    if (itp) tp = 0;


    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    MqlTradeCheckResult cres = {};

    req.action = TRADE_ACTION_DEAL;
    req.symbol = name;
    req.volume = vol;
    req.type = ot;
    req.price = in;
    req.sl = sl;
    req.tp = tp;
    req.deviation = slippage;
    req.magic = magic;
    req.comment = comment;

    if (filling == FILLING_DEFAULT) {
        if (IsFillingTypeAllowed(name, ORDER_FILLING_FOK)) {
            req.type_filling = ORDER_FILLING_FOK;
        } else if (IsFillingTypeAllowed(name, ORDER_FILLING_IOC)) {
            req.type_filling = ORDER_FILLING_IOC;
        }
    } else if (filling == FILLING_FOK) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_IOK) req.type_filling = ORDER_FILLING_IOC;
    else if (filling == FILLING_BOC) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_RETURN) req.type_filling = ORDER_FILLING_RETURN;

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_MARKET_CLOSED) return false;
        if (cres.retcode == TRADE_RETCODE_NO_MONEY) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("%s %s %.2f [No money]", name, EnumToString(ot), vol));
            return false;
        }
        if (cres.retcode == TRADE_RETCODE_INVALID_FILL && filling == FILLING_DEFAULT) {
            if (req.type_filling != ORDER_FILLING_FOK)
                req.type_filling = ORDER_FILLING_FOK;
            else
                req.type_filling = ORDER_FILLING_IOC;
        }
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

bool pendingOrder(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double vol = 0, double stoplimit = 0, datetime expiration = 0, ENUM_ORDER_TYPE_TIME timeType = 0, string symbol = NULL, string comment = "", ENUM_FILLING filling = FILLING_DEFAULT, ENUM_RISK risk_mode = RISK_DEFAULT, double risk = 0.01, int slippage = 30) {
    if (symbol == NULL) symbol = _Symbol;
    int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    int err;


    in = NormalizeDouble(in, digits);
    tp = NormalizeDouble(tp, digits);
    sl = NormalizeDouble(sl, digits);

    if (vol == 0)
        vol = calcVolume(in, sl, risk, tp, false, 0, magic, symbol, 0, risk_mode);

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
    req.type_time = timeType;
    req.expiration = expiration;

    if (filling == FILLING_DEFAULT) {
        if (IsFillingTypeAllowed(symbol, ORDER_FILLING_FOK)) {
            req.type_filling = ORDER_FILLING_FOK;
        } else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_IOC)) {
            req.type_filling = ORDER_FILLING_IOC;
        } else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_RETURN)) {
            req.type_filling = ORDER_FILLING_RETURN;
        } else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_BOC)) {
            req.type_filling = ORDER_FILLING_BOC;
        }
    } else if (filling == FILLING_FOK) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_IOK) req.type_filling = ORDER_FILLING_IOC;
    else if (filling == FILLING_BOC) req.type_filling = ORDER_FILLING_BOC;
    else if (filling == FILLING_RETURN) req.type_filling = ORDER_FILLING_RETURN;

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_MARKET_CLOSED) return false;
        if (cres.retcode == TRADE_RETCODE_NO_MONEY) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("%s %s %.2f [No money]", symbol, EnumToString(ot), vol));
            return false;
        }
        if (cres.retcode == TRADE_RETCODE_INVALID_FILL && filling == FILLING_DEFAULT) {
            if (req.type_filling != ORDER_FILLING_IOC)
                req.type_filling = ORDER_FILLING_IOC;
            else
                req.type_filling = ORDER_FILLING_RETURN;
        }
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

    if (filling == FILLING_DEFAULT) {
        if (IsFillingTypeAllowed(psymbol, ORDER_FILLING_FOK)) {
            req.type_filling = ORDER_FILLING_FOK;
        } else if (IsFillingTypeAllowed(psymbol, ORDER_FILLING_IOC)) {
            req.type_filling = ORDER_FILLING_IOC;
        }
    } else if (filling == FILLING_FOK) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_IOK) req.type_filling = ORDER_FILLING_IOC;
    else if (filling == FILLING_BOC) req.type_filling = ORDER_FILLING_FOK;
    else if (filling == FILLING_RETURN) req.type_filling = ORDER_FILLING_RETURN;

    if (!OrderCheck(req, cres)) {
        if (cres.retcode == TRADE_RETCODE_MARKET_CLOSED) return false;
        if (cres.retcode == TRADE_RETCODE_INVALID_FILL && filling == FILLING_DEFAULT) {
            if (req.type_filling != ORDER_FILLING_FOK)
                req.type_filling = ORDER_FILLING_FOK;
            else
                req.type_filling = ORDER_FILLING_IOC;
        }
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

    return false;
}

bool closePendingOrder(ulong ticket) {
    int err;

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    req.action = TRADE_ACTION_REMOVE;
    req.order = ticket;


    // ASYNC MIGRATION: Delete Order
    ZeroMemory(res);
    if (!g_asyncManager.SendAsync(req)) {
         err = GetLastError();
         if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
            CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Delete Error: Ticket=%I64u, Err=%d", ticket, err));
         return false;
    }
    return true;

    return false;
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



// Helper for SL Volatility Calculation
double CalcVolatility(ENUM_SL mode, int lookback, int start, string symbol, ENUM_TIMEFRAMES timeframe) {
    if (mode == SL_AR) {
        double sum = 0;
        for (int i = start; i < start + lookback; i++) {
            sum += (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i));
        }
        return (sum / lookback);
    } 
    else if (mode == SL_MR) {
        double max = 0;
        for (int i = start; i < start + lookback; i++) {
            double range = iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i);
            if (range > max) max = range;
        }
        return max;
    }
    return 0.0;
}

double BuySL(ENUM_SL sltype, int lookback, double price = 0, int dev = 0, int start = 0, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    symbol = symbol == NULL ? _Symbol : symbol;
    price = price == 0 ? Ask(symbol) : price;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = 0;

    if (sltype == SL_SWING) {
        int i = iLowest(symbol, timeframe, MODE_LOW, lookback, start);
        sl = iLow(symbol, timeframe, i) - dev * point;
    }
    else if (sltype == SL_AR || sltype == SL_MR) {
        sl = price - CalcVolatility(sltype, lookback, start, symbol, timeframe) - dev * point;
    }
    else if (sltype == SL_FIXED_POINT) {
        sl = price - dev * point;
    }

    return NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

double SellSL(ENUM_SL sltype, int lookback, double price = 0, int dev = 0, int start = 0, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    symbol = symbol == NULL ? _Symbol : symbol;
    price = price == 0 ? Bid(symbol) : price;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = 0;

    if (sltype == SL_SWING) {
        int i = iHighest(symbol, timeframe, MODE_HIGH, lookback, start);
        sl = iHigh(symbol, timeframe, i) + dev * point;
    }
    else if (sltype == SL_AR || sltype == SL_MR) {
        sl = price + CalcVolatility(sltype, lookback, start, symbol, timeframe) + dev * point;
    }
    else if (sltype == SL_FIXED_POINT) {
        sl = price + dev * point;
    }

    return NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

double GetATRForGrid(string symbol, int period) {
    int handle = iATR(symbol, PERIOD_CURRENT, period);
    if (handle == INVALID_HANDLE) return 0.0;
    
    double buf[1];
    if (CopyBuffer(handle, 0, 0, 1, buf) < 1) return 0.0;
    
    return buf[0];
}

// --- STRATEGY CORE (Trail, Grid, Equity, BE) ---

void checkForTrail(ulong magic, double stopLevel = 0.5, double gridStopLevel = 0.4, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT, double minProfit = 0.0, bool minProfitPct = false, bool infinityEnable = false, double infinityTriggerPct = 90.0, double infinityTrailingStep = 0.4, int infinityTpDistance = 50000, ENUM_TRAIL_MODE trailMode = TRAIL_STANDARD, int trailAtrHandle = INVALID_HANDLE, double trailAtrMult = 2.5, ENUM_INFINITY_STEP_MODE infinityStepMode = INF_STEP_PERCENT, int infAtrHandle = INVALID_HANDLE, double infAtrMult = 1.5) {
    int minPoints = 1; // dynamic per symbol
    MqlTradeRequest req;
    MqlTradeResult res;

    struct SGroupKey {
        ulong magic;
        string symbol;
        ENUM_POSITION_TYPE type;
    };
    SGroupKey processed_groups[]; // Optimization: Process by group to avoid O(N^2)

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        if (!pticket) continue;

        // 1. Identify Group
        string psymbol = PositionGetString(POSITION_SYMBOL);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        
        // 2. Skip if already processed
        bool is_processed = false;
        int pg_size = ArraySize(processed_groups);
        for(int p=0; p<pg_size; p++) {
            if(processed_groups[p].magic == pmagic && 
               processed_groups[p].type == ptype && 
               processed_groups[p].symbol == psymbol) { 
               is_processed = true; 
               break; 
            }
        }
        if(is_processed) continue;

        // 3. Mark as processed
        ArrayResize(processed_groups, pg_size + 1);
        processed_groups[pg_size].magic = pmagic;
        processed_groups[pg_size].symbol = psymbol;
        processed_groups[pg_size].type = ptype;

        // 4. Retrieve Group Context (Once per group)
        ulong tickets[];
        int n = positionsTickets(pmagic, tickets, psymbol);
        
        // Calc 'k' (positions with comment) - Once per group
        int k = 0;
        for (int j = 0; j < n; j++) {
            PositionSelectByTicket(tickets[j]);
            if (StringToDouble(PositionGetString(POSITION_COMMENT))) k++;
        }

        // Shared Group Data
        minPoints = MinBrokerPoints(psymbol);
        double ppoint = SymbolInfoDouble(psymbol, SYMBOL_POINT);
        double minModDiff = ppoint * 0.5; // Anti-Spam: Min distance to modify SL
        int pdigits = (int) SymbolInfoInteger(psymbol, SYMBOL_DIGITS);
        ENUM_SYMBOL_TRADE_MODE pstm = (ENUM_SYMBOL_TRADE_MODE) SymbolInfoInteger(psymbol, SYMBOL_TRADE_MODE);
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        // 5. Process Tickets in this Group
        bool grid_logic_done = false;

        // Iterate all tickets belonging to this magic/symbol
        for(int t=0; t<n; t++) {
            ulong curr_ticket = tickets[t];
            if(!PositionSelectByTicket(curr_ticket)) continue;
            
            // Filter: Only process tickets matching current group type (BUY or SELL)
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != ptype) continue;
            
            // Extract current ticket properties
            double pin = PositionGetDouble(POSITION_PRICE_OPEN);
            double psl = PositionGetDouble(POSITION_SL);
            double ptp = PositionGetDouble(POSITION_TP);
            double pprof = PositionGetDouble(POSITION_PROFIT);
            double pd = StringToDouble(PositionGetString(POSITION_COMMENT));
            
            if (pmagic != magic) continue; // Should match if positionsTickets worked, but safe check
            if (IsZero(pd)) continue;

            ZeroMemory(req);
            ZeroMemory(res);
            req.action = TRADE_ACTION_SLTP;
            req.position = curr_ticket;
            req.symbol = psymbol;
            req.magic = pmagic;
            req.sl = psl;
            req.tp = ptp;


            // --- LOGIC A: Individual Trail (Simple or Recovered) ---
            if (n == 1 || k > 1) {
                // If STANDARD mode and stopLevel is 0, skip
                if (trailMode == TRAIL_STANDARD && IsZero(stopLevel)) continue;

                double sl = 0;
                double cost = MathMax(calcCostByTicket(curr_ticket), 0);
                double brkeven = calcPriceByTicket(curr_ticket, cost);

                // --- CALCULATE TRAILING DISTANCE (gap) ---
                double trailGap = 0;
                string pcomment = PositionGetString(POSITION_COMMENT);
                double pd = StringToDouble(pcomment);

                if (trailMode == TRAIL_ATR) {
                     // Mode ATR
                     double atrVal[];
                     ArraySetAsSeries(atrVal, true);
                     // Use handle if valid
                     if (trailAtrHandle != INVALID_HANDLE && CopyBuffer(trailAtrHandle, 0, 0, 1, atrVal) == 1) {
                         trailGap = atrVal[0] * trailAtrMult;
                     } else {
                         // Fallback to Standard
                         if (pd == 0) continue;
                         trailGap = pd * stopLevel;
                     }
                } else {
                     // Mode STANDARD
                     if (pd == 0) continue;
                     trailGap = pd * stopLevel;
                }

                if (ptype == POSITION_TYPE_BUY) {
                    double h = Bid(psymbol);
                    if (IsLessOrEqual(h, pin)) continue;
                    
                    // SL = CurrentHigh - Gap
                    sl = h - trailGap;
                    
                    // Ensure we don't move SL lower than Entry/BreakEven (Lock Profit)
                    // The original logic seemed to allow locking from Entry. 
                    // Let's protect profit: max(Entry, SL_Calculated)
                    // But we must also support BreakEven logic.
                    // Existing logic: sl = MathMax(pin, brkeven) + d - stopLevel * pd; 
                    // d = h - pin. So sl = MathMax(pin, brkeven) + h - pin - gap.
                    // If pin > brkeven (usually), then sl = h - gap.
                    
                    // Simplify: Trailing means SL follows Price.
                    // We just need to check if NewSL > CurrentSL.
                    
                    // To respect the "MathMax(pin, brkeven)" original intent:
                    // It ensures SL never goes below Entry if we are in profit.
                    // But actually, trailing should just simply follow price.
                    
                    sl = NormalizePrice(sl, psymbol);
                    
                    if (IsLess(sl, pin)) continue; // Don't trail if below entry (wait for profit)
                    
                    if (psl != 0 && IsGreaterOrEqual(psl, sl)) continue;
                    if (psl != 0 && (sl - psl) < minModDiff) continue; // Anti-Spam
                    if (!IsGreaterOrEqual(Bid(psymbol) - sl, minPoints * ppoint)) {
                        if (pprof - cost > 0 && CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                            CAuroraLogger::WarnOrders(StringFormat("[TRAIL] Skip Update: SL too close to Bid (SL=%.5f, Bid=%.5f, Min=%.5f)", sl, Bid(psymbol), minPoints*ppoint));
                        continue;
                    }
                    req.sl = sl;
                }
                else if (ptype == POSITION_TYPE_SELL) {
                    double l = Ask(psymbol);
                    if (IsGreaterOrEqual(l, pin)) continue;
                    
                    // SL = CurrentLow + Gap
                    sl = l + trailGap;

                    sl = NormalizePrice(sl, psymbol);

                    if (IsGreater(sl, pin)) continue; // Don't trail if above entry
                    
                    if (psl != 0 && IsLessOrEqual(psl, sl)) continue;
                    if (psl != 0 && (psl - sl) < minModDiff) continue; // Anti-Spam
                    if (!IsGreaterOrEqual(sl - Ask(psymbol), minPoints * ppoint)) {
                        if (pprof - cost > 0 && CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                            CAuroraLogger::WarnOrders(StringFormat("[TRAIL] Skip Update: SL too close to Ask (SL=%.5f, Ask=%.5f, Min=%.5f)", sl, Ask(psymbol), minPoints*ppoint));
                        continue;
                    }
                    req.sl = sl;
                }


                // ASYNC MIGRATION: Single Async Call
                ZeroMemory(res);
                if (!g_asyncManager.SendAsync(req)) {
                    // Retry logic removed for pure async. Manual intervention or next tick retry needed.
                    int err = GetLastError();
                    if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s [ASYNC] error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
                } else {
                     if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                        CAuroraLogger::InfoOrders(StringFormat("[ASYNC] Trail Updated: Ticket=%I64u SL=%.5f", curr_ticket, req.sl));
                }
            }
            // --- LOGIC B: Grid Trail (Group) ---
            else {
                // Optimization: Execute Grid Logic ONLY ONCE per group
                if(grid_logic_done) continue; 
                
                // HYBRID LOGIC: Allow entry if infinity enabled EVEN if gridStopLevel is 0
                if (IsZero(gridStopLevel) && !infinityEnable) continue;

                double sl;
                double cost = MathMax(calcCost(pmagic, psymbol), 0);
                double brkeven = calcPrice(pmagic, cost, 0, 0, psymbol);
                double profit = getProfit(pmagic, psymbol);

                // Recalc min/max TP for group
                double group_tp = ptp;
                for (int j = 0; j < n; j++) {
                    PositionSelectByTicket(tickets[j]);
                    if (ptype == POSITION_TYPE_BUY && PositionGetDouble(POSITION_TP) < group_tp)
                        group_tp = PositionGetDouble(POSITION_TP);
                    if (ptype == POSITION_TYPE_SELL && PositionGetDouble(POSITION_TP) > group_tp)
                        group_tp = PositionGetDouble(POSITION_TP);
                }
                ptp = group_tp; // Update local var for calcProfit

                double target_prof = calcProfit(pmagic, ptp, psymbol);
                bool infinityTriggered = false;
                bool sl_calc_ok = false;
                if(infinityEnable && infinityTriggerPct > 0) {
                     double triggerAmt = target_prof * (infinityTriggerPct / 100.0);
                     if (profit - cost >= triggerAmt && target_prof > 0.0) {
                          infinityTriggered = true;
                          // If we are here, we should push TP to moon.
                          if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                               // Log once (needs static or smart logging)
                               // CAuroraLogger::InfoStrategy("Infinity Mode Triggered!");
                          }
                     }
                }

                if (infinityTriggered) {
                    // INFINITY MODE: Use Current Price for Trail (ignore fixed target)
                    // If BUY, use Bid (Current High). If SELL, use Ask (Current Low).
                    if (ptype == POSITION_TYPE_BUY) {
                        double h = Bid(psymbol);
                        // Force Safe Trailing Step (from Input) if GridTrailingStopLevel is 0
                        double effectiveTrailingStep = (IsZero(gridStopLevel) ? infinityTrailingStep : gridStopLevel);

                        // Override target for calculation
                        // Effective Target = Current Profit (converted to Price)
                        double effective_target_price = h;
                        double effective_entry = brkeven;
                        double total_dist = effective_target_price - effective_entry;
                        // Trail at % of total distance
                        double trail_dist = 0.0;
                        

                        if (infinityStepMode == INF_STEP_POINTS) {
                             // MODE POINTS: Fixed distance from Price
                             trail_dist = infinityTrailingStep * ppoint;
                        } else if (infinityStepMode == INF_STEP_ATR) {
                             // MODE ATR: Volatility based
                             double atrVal[];
                             ArraySetAsSeries(atrVal, true);
                             if (infAtrHandle != INVALID_HANDLE && CopyBuffer(infAtrHandle, 0, 0, 1, atrVal) == 1) {
                                  trail_dist = atrVal[0] * infAtrMult;
                             } else {
                                  // Fallback to Points if ATR fails
                                  trail_dist = infinityTrailingStep * ppoint;
                             }
                        } else {
                             // MODE PERCENT (Legacy)
                             trail_dist = total_dist * effectiveTrailingStep; // e.g. 50% of distance
                        }
                        
                        sl = effective_target_price - trail_dist; // Secure distance
                        
                        sl = NormalizePrice(sl, psymbol);
                        if (psl == 0 || IsLess(psl, sl)) {
                             if (psl != 0 && (sl - psl) < minModDiff) continue; // Anti-Spam
                             
                             // SAFETY: Check if SL is too close to price. If so, CLOSE to secure profit.
                             if (!IsGreaterOrEqual(Bid(psymbol) - sl, minPoints * ppoint)) {
                                 // Warn only, do not force close entire grid
                                 if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                                     CAuroraLogger::WarnOrders(StringFormat("[INFINITY] Skip: SL too close (SL=%.5f, Bid=%.5f)", sl, Bid(psymbol)));
                             } 
                             else {
                                 req.sl = sl;
                                 // Push TP if needed
                                 if (ptp < h + 1000 * ppoint) {
                                     req.tp = h + infinityTpDistance * ppoint; // Push far away
                                 } else {
                                     req.tp = ptp; // Keep valid
                                 }
                                 sl_calc_ok = true;
                             }
                        }
                    }
                    else if (ptype == POSITION_TYPE_SELL) {
                         double l = Ask(psymbol);
                         // Force Safe Trailing Step need here too? Yes.
                         double effectiveTrailingStep = (IsZero(gridStopLevel) ? infinityTrailingStep : gridStopLevel);

                         double effective_target_price = l;
                         double effective_entry = brkeven;
                         double total_dist = effective_entry - effective_target_price;
                         
                         double trail_dist = 0.0;

                         if (infinityStepMode == INF_STEP_POINTS) {
                             trail_dist = infinityTrailingStep * ppoint;
                         } else if (infinityStepMode == INF_STEP_ATR) {
                             // MODE ATR
                             double atrVal[];
                             ArraySetAsSeries(atrVal, true);
                             if (infAtrHandle != INVALID_HANDLE && CopyBuffer(infAtrHandle, 0, 0, 1, atrVal) == 1) {
                                  trail_dist = atrVal[0] * infAtrMult;
                             } else {
                                  trail_dist = infinityTrailingStep * ppoint;
                             }
                         } else {
                             trail_dist = total_dist * effectiveTrailingStep; 
                         }
                         
                         sl = effective_target_price + trail_dist;
                         
                         sl = NormalizePrice(sl, psymbol);
                         if (psl == 0 || IsGreater(psl, sl)) {
                             if (psl != 0 && (psl - sl) < minModDiff) continue; // Anti-Spam

                             // SAFETY: Check if SL is too close to price.
                             if (!IsGreaterOrEqual(sl - Ask(psymbol), minPoints * ppoint)) {
                                 if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                                     CAuroraLogger::WarnOrders(StringFormat("[INFINITY] Skip: SL too close (SL=%.5f, Ask=%.5f)", sl, Ask(psymbol)));
                             }
                             else {
                                 req.sl = sl;
                                 if (ptp > l - 1000 * ppoint || ptp == 0) {
                                     req.tp = l - infinityTpDistance * ppoint;
                                 } else {
                                     req.tp = ptp;
                                 }
                                 sl_calc_ok = true;
                             }
                         }
                    }
                }
                else {
                    // STANDARD LOGIC (Fixed Target)
                    if (IsZero(gridStopLevel)) continue; // Double check for Safety if not Infinity

                    double per_target = calcPrice(pmagic, gridStopLevel * target_prof, 0, 0, psymbol);
                    if (ptype == POSITION_TYPE_BUY) {
                        double h = Bid(psymbol);
                        if (IsGreater(h, per_target)) {
                             double d = h - per_target;
                             sl = brkeven + d;
                                  sl = NormalizePrice(sl, psymbol);
                             if (psl == 0 || IsLess(psl, sl)) {
                                if (psl != 0 && (sl - psl) < minModDiff) continue; // Anti-Spam

                                if (IsGreaterOrEqual(Bid(psymbol) - sl, minPoints * ppoint)) {
                                    req.sl = sl;
                                    sl_calc_ok = true;
                                } else if (profit - cost > 0) {
                                    // Removed Panic Close
                                    continue;
                                }
                             }
                        }
                    }
                    else if (ptype == POSITION_TYPE_SELL) {
                        double l = Ask(psymbol);
                        if (IsLess(l, per_target)) {
                             double d = per_target - l;
                             sl = brkeven - d;
                                  sl = NormalizePrice(sl, psymbol);
                             if (psl == 0 || IsGreater(psl, sl)) {
                                 if (psl != 0 && (psl - sl) < minModDiff) continue; // Anti-Spam

                                 if (IsGreaterOrEqual(sl - Ask(psymbol), minPoints * ppoint)) {
                                     req.sl = sl;
                                     sl_calc_ok = true;
                                 } else if (profit - cost > 0) {
                                     closeOrders(ptype, pmagic, slippage, psymbol, filling);
    
                                 }
                             }
                        }
                    }
                } // End Standard Logic
                
                if(sl_calc_ok) {
                    // Apply to current ticket (main) - ASYNC
                    ZeroMemory(res);
                    if (!g_asyncManager.SendAsync(req)) {
                        int err = GetLastError();
                        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s (grid) [ASYNC] error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
                    } else {
                        // Apply to ALL other tickets in group (Async) - Optimization: loops all tickets here, so we mark grid_logic_done
                         for (int j = 0; j < n; j++) {
                            if (tickets[j] == curr_ticket) continue;
                            ZeroMemory(res);
                            req.position = tickets[j];
                            if (!g_asyncManager.SendAsync(req)) {
                                int err = GetLastError();
                                if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s (grid) error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
                            }
                        }
                    }
                }
                
                grid_logic_done = true; // Ensure we don't repeat this block for other tickets in same group
            }
        }
    }
}

void checkForGrid(ulong magic, double risk, double volCoef, int maxLvl, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT, int sideFilter = -1, bool dynamicSpacing = false, int atrHandle = INVALID_HANDLE, int atrPeriod = 14, double atrMult = 1.0, double minProfit = 0.0, bool minProfitPct = false, double maxATR = 0.0,
                  bool marginGuard = false, double mgStretchLvl = 2000.0, double mgMaxMult = 5.0,
                  bool mgDampingEnable = false, double mgDampingStart = 1500.0, double mgDampingMin = 0.8, double dampingLowBound = 500.0, int spreadLimit = -1, double maxLots = 50.0, double balanceOverride = -1) {
    int minPoints = 1; // dynamic per symbol
    MqlTradeRequest req;
    MqlTradeResult res;

    // ... (struct SGridKey omitted for brevity, assuming existing) ...
    // Note: Re-declaring struct inside function is fine or if it was moved out. 
    // In previous view it was inside. I will keep the surrounding code intact. 
    
    struct SGridKey {
        ulong magic;
        string symbol;
        string typeStr; // "BUY" or "SELL"
    };
    SGridKey processed_grids[]; // Optimization: Track processed grids to avoid O(N^2) complexity

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        // ... (standard retrieval code) ...
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        double ptv = GetTickValue(psymbol);
        datetime ptime = (datetime) PositionGetInteger(POSITION_TIME);
        double ppoint = SymbolInfoDouble(psymbol, SYMBOL_POINT);
        minPoints = MinBrokerPoints(psymbol);
        double pin = PositionGetDouble(POSITION_PRICE_OPEN);
        double pd = StringToDouble(PositionGetString(POSITION_COMMENT));
        double psl = PositionGetDouble(POSITION_SL);
        double ptp = PositionGetDouble(POSITION_TP);
        double pvol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        ENUM_SYMBOL_TRADE_MODE pstm = (ENUM_SYMBOL_TRADE_MODE) SymbolInfoInteger(psymbol, SYMBOL_TRADE_MODE);

        if (pmagic != magic) continue;
        if (IsZero(pd)) continue;
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        // Filtre de côté: -1=both (aucun filtre), 0=BUY only, 1=SELL only
        if (sideFilter == 0 && ptype != POSITION_TYPE_BUY)  continue;
        if (sideFilter == 1 && ptype != POSITION_TYPE_SELL) continue;

        // --- OPTIMIZATION: Process each grid only once per tick ---
        string typeStr = (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL");
        bool is_processed = false;
        int p_cnt = ArraySize(processed_grids);
        for(int k=0; k<p_cnt; k++) {
            if(processed_grids[k].magic == pmagic && 
               processed_grids[k].symbol == psymbol &&
               processed_grids[k].typeStr == typeStr) { 
               is_processed = true; 
               break; 
            }
        }
        if(is_processed) continue;
        
        ArrayResize(processed_grids, p_cnt + 1);
        processed_grids[p_cnt].magic = pmagic;
        processed_grids[p_cnt].symbol = psymbol;
        processed_grids[p_cnt].typeStr = typeStr;
        // ----------------------------------------------------------

        ulong tickets[];
        int n = positionsTickets(pmagic, tickets, psymbol);
        if (n < 1 || n >= maxLvl) continue;

        double vols[];
        positionsVolumes(pmagic, vols, psymbol);
        double lastVol = vols[ArrayMaximum(vols)];

        double prices[];
        positionsPrices(pmagic, prices, psymbol);
        double lastPrice = ptype == POSITION_TYPE_BUY ? prices[ArrayMinimum(prices)] : prices[ArrayMaximum(prices)];
        
        // --- LOGIQUE ESPACEMENT DYNAMIQUE (v1.31) ---
        double spacing = pd;
        double currentATR = 0.0; // Declare here so we can use for volatility filter too
        
        if (dynamicSpacing || maxATR > 0.0) { // Calculate ATR if needed for Spacing OR Filter
            if (atrHandle != INVALID_HANDLE) {
               double buf[1];
               if (CopyBuffer(atrHandle, 0, 0, 1, buf) > 0) currentATR = buf[0];
            } else {
               currentATR = GetATRForGrid(psymbol, atrPeriod);
            }
            if (dynamicSpacing && currentATR > 0) spacing = currentATR * atrMult;
        }
        spacing = MathMax(spacing, minPoints * ppoint);

        // --- MARGIN GUARD: STRETCHING ---
        if (marginGuard && mgStretchLvl > 0 && mgMaxMult > 1.0) {
            double currentMargin = (balanceOverride > 0) ? GetSimulatedMarginLevel(balanceOverride) : AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
            if (currentMargin > 0 && currentMargin < mgStretchLvl) {
                // Formula: 1.0 + (Max - 1) * percent_below_start
                // Example: Start=2000, Curr=1000 (50% drop) -> 1 + 4 * 0.5 = 3x spacing
                double dropRatio = (mgStretchLvl - currentMargin) / mgStretchLvl;
                double multiplier = 1.0 + (mgMaxMult - 1.0) * dropRatio;
                spacing *= multiplier;
                
                // Optional: Log once per tick/grid if meaningful change
                // if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) ...
            }
        }
        // --------------------------------

        // --- VOLATILITY FILTER (Step 3.2) ---
        if (maxATR > 0.0 && currentATR > maxATR) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
                CAuroraLogger::InfoStrategy(StringFormat("[GRID-FILTER] High Volatility (ATR=%.5f > Max=%.5f). Skipping grid add for %s", currentATR, maxATR, psymbol));
             continue; 
        }
        // ------------------------------------

        // --- MARGIN GUARD: VOLUME DAMPING ---
        double finalVolCoef = volCoef;
        if (marginGuard && mgDampingEnable && mgDampingStart > 0) {
             double currentMargin = (balanceOverride > 0) ? GetSimulatedMarginLevel(balanceOverride) : AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
             if (currentMargin > 0 && currentMargin < mgDampingStart) {
                 // Interpolation linéaire:
                 // Start (1500) -> Original Coef
                 // LowBound (param) -> Min Coef (0.8)
                 double lowBound = dampingLowBound;
                 double range = mgDampingStart - lowBound;
                 double progress = 0.0;
                 if (range > 0) progress = (currentMargin - lowBound) / range;
                 
                 if (progress < 0) progress = 0;
                 if (progress > 1) progress = 1;
                 
                 // Lerp
                 finalVolCoef = mgDampingMin + (volCoef - mgDampingMin) * progress;
             }
        }
        // ------------------------------------

        double lvl, tp;
        // Pass balanceOverride to calcVolume
        // Usage: calcVolume(in, sl, risk(vol), tp, martingale, martRisk, magic, symbol, balance, riskMode)
        double vol = calcVolume(1, 1, lastVol * finalVolCoef, 0, false, 0, 0, psymbol, balanceOverride, RISK_FIXED_VOL);
        double loss = pvol * ptv * (pd / ppoint);
        double target_prof = loss;
        double cost = calcCost(pmagic, psymbol);
        if (cost > 0) target_prof += cost;

        // --- LOGIQUE CIBLE PROFIT (v1.32) ---
        double extra_prof = minProfit;
        if (minProfitPct) {
            // Use Simulated Balance for % Profit Target
            double refBalance = (balanceOverride > 0) ? GetSimulatedBalance(balanceOverride) : AccountInfoDouble(ACCOUNT_BALANCE);
            extra_prof = refBalance * (minProfit / 100.0);
        }
        target_prof += MathMax(0.0, extra_prof);
        // ------------------------------------

        ZeroMemory(req);
        ZeroMemory(res);
        req.action = TRADE_ACTION_SLTP;
        req.position = pticket;
        req.symbol = psymbol;
        req.magic = pmagic;
        req.sl = psl;
        req.tp = ptp;

        if (ptype == POSITION_TYPE_BUY) {
            // Logique Dynamique
            if (IsLess(MathAbs(lastPrice - Ask(psymbol)), spacing))
                continue; 

            double low = Bid(psymbol);
            lvl = lastPrice - spacing; 

            if (IsGreater(low, lvl)) continue;
            
            tp = calcPrice(pmagic, target_prof, Ask(psymbol), vol, psymbol);

            if (!IsGreaterOrEqual(tp - Bid(psymbol), minPoints * ppoint))
                tp = Bid(psymbol) + minPoints * ppoint;

            if (spreadLimit > 0) {
               long spread = SymbolInfoInteger(psymbol, SYMBOL_SPREAD);
               if (spread > spreadLimit) {
                   if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
                       CAuroraLogger::WarnStrategy(StringFormat("[GRID] Add Level BLOCKED. Spread %d > Limit %d", spread, spreadLimit));
                   continue;
               }
            }

            if (maxLots > 0) {
                double currentTotalVol = 0.0;
                ulong tks[]; 
                int n_vol = positionsTickets(pmagic, tks); 
                for(int v=0; v<n_vol; v++) {
                    if(PositionSelectByTicket(tks[v])) currentTotalVol += PositionGetDouble(POSITION_VOLUME);
                }
                
                if ((currentTotalVol + vol) > maxLots) {
                    if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
                        CAuroraLogger::WarnRisk(StringFormat("[RISK] Max Lots Reached: Curr=%.2f + New=%.2f > Max=%.2f. Grid add blocked.", currentTotalVol, vol, maxLots));
                    continue;
                }
            }

            if (!order(ORDER_TYPE_BUY, pmagic, Ask(psymbol), psl, tp, risk, false, 0, slippage, false, false, "", psymbol, vol, filling, RISK_DEFAULT, balanceOverride)) continue;

            req.tp = tp;
        }

        else if (ptype == POSITION_TYPE_SELL) {
            // Logique Dynamique
            if (IsLess(MathAbs(lastPrice - Bid(psymbol)), spacing))
                continue; 

            double high = Ask(psymbol);
            lvl = lastPrice + spacing;

            if (IsLess(high, lvl)) continue;
            
            tp = calcPrice(pmagic, target_prof, Bid(psymbol), vol, psymbol);

            if (!IsGreaterOrEqual(Ask(psymbol) - tp, minPoints * ppoint))
                tp = Ask(psymbol) - minPoints * ppoint;

            if (spreadLimit > 0) {
               long spread = SymbolInfoInteger(psymbol, SYMBOL_SPREAD);
               if (spread > spreadLimit) {
                   if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
                       CAuroraLogger::WarnStrategy(StringFormat("[GRID] Add Level BLOCKED. Spread %d > Limit %d", spread, spreadLimit));
                   continue;
               }
            }

            if (maxLots > 0) {
                double currentTotalVol = 0.0;
                ulong tks[]; 
                int n_vol = positionsTickets(pmagic, tks); 
                for(int v=0; v<n_vol; v++) {
                    if(PositionSelectByTicket(tks[v])) currentTotalVol += PositionGetDouble(POSITION_VOLUME);
                }
                
                if ((currentTotalVol + vol) > maxLots) {
                    if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK))
                        CAuroraLogger::WarnRisk(StringFormat("[RISK] Max Lots Reached: Curr=%.2f + New=%.2f > Max=%.2f. Grid add blocked.", currentTotalVol, vol, maxLots));
                    continue;
                }
            }

            if (!order(ORDER_TYPE_SELL, pmagic, Bid(psymbol), psl, tp, risk, false, 0, slippage, false, false, "", psymbol, vol, filling, RISK_DEFAULT, balanceOverride)) continue;

            req.tp = tp;
        }

        for (int j = 0; j < n; j++) {
            PositionSelectByTicket(tickets[j]);
            ZeroMemory(res);
            req.position = tickets[j];
            if (IsEqual(PositionGetDouble(POSITION_TP), req.tp) && IsEqual(PositionGetDouble(POSITION_SL), req.sl)) continue;
            if (!g_asyncManager.SendAsync(req)) {
                int err = GetLastError();
                if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
            }
        }

    }
}

void checkForEquity(ulong magic, double limit, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT, double balanceOverride = -1) {
    if (IsZero(limit)) return;

    double balance = (balanceOverride > 0) ? GetSimulatedBalance(balanceOverride) : AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = (balanceOverride > 0) ? GetSimulatedEquity(balanceOverride) : AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Drawdown % formula: (Equity - Balance) / Balance
    double p = (equity - balance) / balance;
    if (p >= 0) return;
    if (MathAbs(p) < limit) return;

    double max_loss = -DBL_MAX;
    string max_symbol = "";
    ulong tickets[];
    int n = positionsTickets(magic, tickets);
    for (int i = 0; i < n; i++) {
        PositionSelectByTicket(tickets[i]);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        double loss = calcCost(magic, psymbol) - getProfit(magic, psymbol);
        if (loss > max_loss) {
            max_loss = loss;
            max_symbol = psymbol;
        }
    }

    closeOrders(POSITION_TYPE_BUY, magic, slippage, max_symbol, filling);
    closeOrders(POSITION_TYPE_SELL, magic, slippage, max_symbol, filling);
}

// --- SMART GRID REDUCTION ---
void checkSmartGridReduction(ulong magic, int startLvl, double profitRatio, double minVol, double winnerClosePercent, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT) {
    // Process positions for this magic number
    
    // 1. Identify active symbol(s) for this magic
    int total = PositionsTotal();
    // Note: startLvl check moved AFTER magic filter (see below)

    // Helper structs
    struct SPosMetric {
        ulong ticket;
        double profit;
        double volume;
        datetime time;
        ENUM_POSITION_TYPE type;
    };
    
    // Find best Winner (highest profit) and worst Loser (lowest profit) per side
    
    // Store indices - Find by PROFIT (not timestamp)
    int best_buy_winner = -1; double p_buy_winner = -DBL_MAX;
    int best_buy_loser  = -1; double p_buy_loser  = DBL_MAX;
    
    int best_sell_winner = -1; double p_sell_winner = -DBL_MAX;
    int best_sell_loser  = -1; double p_sell_loser  = DBL_MAX;

    // We need to store data to avoid multiple PositionSelect calls
    SPosMetric positions[]; 
    ArrayResize(positions, total);
    int cnt = 0;

    for(int i=0; i<total; i++) {
        ulong t = PositionGetTicket(i);
        if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
        
        positions[cnt].ticket = t;
        positions[cnt].profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        positions[cnt].volume = PositionGetDouble(POSITION_VOLUME);
        positions[cnt].time   = (datetime)PositionGetInteger(POSITION_TIME);
        positions[cnt].type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Find candidates by PROFIT
        if (positions[cnt].type == POSITION_TYPE_BUY) {
             if (positions[cnt].profit > p_buy_winner) { p_buy_winner = positions[cnt].profit; best_buy_winner = cnt; }
             if (positions[cnt].profit < p_buy_loser)  { p_buy_loser  = positions[cnt].profit; best_buy_loser  = cnt; }
        } else {
             if (positions[cnt].profit > p_sell_winner) { p_sell_winner = positions[cnt].profit; best_sell_winner = cnt; }
             if (positions[cnt].profit < p_sell_loser)  { p_sell_loser  = positions[cnt].profit; best_sell_loser  = cnt; }
        }
        cnt++;
    }
    
    // Check against ACTUAL Aurora positions count (not global total)
    if (cnt < startLvl) return;
    
    // Process BUY side
    if (best_buy_winner != -1 && best_buy_loser != -1 && best_buy_winner != best_buy_loser) {
         SPosMetric limitP = positions[best_buy_winner]; // Winner (highest profit)
         SPosMetric toxicP = positions[best_buy_loser];  // Loser (lowest profit)
         
         if (limitP.profit > 0 && toxicP.profit < 0) {
             // SAFETY IMPROVEMENT: Keep Winner Alive.
             // Only close up to X% of the Winner to generate budget (default 50%).
             double winnerVolToClose = limitP.volume * winnerClosePercent;
             winnerVolToClose = ClampVolumeToSymbol(winnerVolToClose, _Symbol); 
             
             if (winnerVolToClose >= minVol) {
                 // Adjusted Budget: winnerClosePercent of profit * Ratio
                 double adjustedBudget = (limitP.profit * winnerClosePercent) * profitRatio;
                 
                 // Recalculate target Loser volume with this smaller budget
                 double ratio = adjustedBudget / MathAbs(toxicP.profit);
                 double targetLoserVol = toxicP.volume * ratio;
                 targetLoserVol = ClampVolumeToSymbol(targetLoserVol, _Symbol);

                 if (targetLoserVol >= minVol && winnerVolToClose >= minVol) {
                      // Execute Partial Close on Winner FIRST
                      MqlTradeRequest wReq; ZeroMemory(wReq); MqlTradeResult wRes;
                      wReq.action = TRADE_ACTION_DEAL;
                      wReq.position = limitP.ticket;
                      wReq.symbol = _Symbol;
                      wReq.volume = winnerVolToClose;
                      wReq.deviation = slippage;
                      wReq.magic = magic; // Add magic
                      wReq.type = ORDER_TYPE_SELL; // Close BUY (LimitP is BUY)
                      wReq.price = Bid(_Symbol);
                      wReq.type_filling = ORDER_FILLING_IOC;
                      
                      // We use OrderClose async
                       if(g_asyncManager.SendAsync(wReq)) {
                            // Send Loser Close immediately after.
                            // Loser is BUY too (Close with SELL)
                            MqlTradeRequest lReq; ZeroMemory(lReq);
                            lReq.action = TRADE_ACTION_DEAL;
                            lReq.position = toxicP.ticket;
                            lReq.symbol = _Symbol;
                            lReq.volume = targetLoserVol;
                            lReq.deviation = slippage;
                            lReq.magic = magic;
                            lReq.type = ORDER_TYPE_SELL;
                            lReq.price = Bid(_Symbol);
                            lReq.type_filling = ORDER_FILLING_IOC;
                            
                            g_asyncManager.SendAsync(lReq);
                            
                            if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                                CAuroraLogger::InfoStrategy(StringFormat("[SMART GRID] Active Scrubbing: Partial Winner %I64u (%.2f lots) & Loser %I64u (%.2f lots)", limitP.ticket, winnerVolToClose, toxicP.ticket, targetLoserVol));
                            }
                       }
                 }
             }
         }
    }

    // Process SELL side
    if (best_sell_winner != -1 && best_sell_loser != -1 && best_sell_winner != best_sell_loser) {
         SPosMetric limitP = positions[best_sell_winner]; // Winner (highest profit)
         SPosMetric toxicP = positions[best_sell_loser];  // Loser (lowest profit) 
         
         if (limitP.profit > 0 && toxicP.profit < 0) {
             // SAFETY IMPROVEMENT: Keep Winner Alive.
             // Only close up to X% of the Winner to generate budget.
             double winnerVolToClose = limitP.volume * winnerClosePercent;
             winnerVolToClose = ClampVolumeToSymbol(winnerVolToClose, _Symbol); 
             
             if (winnerVolToClose >= minVol) {
                 // Adjusted Budget: winnerClosePercent of profit * Ratio
                 double adjustedBudget = (limitP.profit * winnerClosePercent) * profitRatio;
                 
                 // Recalculate target Loser volume with this smaller budget
                 double ratio = adjustedBudget / MathAbs(toxicP.profit);
                 double targetLoserVol = toxicP.volume * ratio;
                 targetLoserVol = ClampVolumeToSymbol(targetLoserVol, _Symbol);

                 if (targetLoserVol >= minVol && winnerVolToClose >= minVol) {
                      // Execute Partial Close on Winner FIRST
                      MqlTradeRequest wReq; ZeroMemory(wReq); MqlTradeResult wRes;
                      wReq.action = TRADE_ACTION_DEAL;
                      wReq.position = limitP.ticket;
                      wReq.symbol = _Symbol;
                      wReq.volume = winnerVolToClose;
                      wReq.deviation = slippage;
                      wReq.magic = magic; // Add magic
                      wReq.type = ORDER_TYPE_BUY; // Close SELL (LimitP is SELL)
                      wReq.price = Ask(_Symbol);
                      wReq.type_filling = ORDER_FILLING_IOC;
                      
                      // We use OrderClose async
                       if(g_asyncManager.SendAsync(wReq)) {
                            // Send Loser Close immediately after.
                            // Loser is SELL (Close with BUY)
                            MqlTradeRequest lReq; ZeroMemory(lReq);
                            lReq.action = TRADE_ACTION_DEAL;
                            lReq.position = toxicP.ticket;
                            lReq.symbol = _Symbol;
                            lReq.volume = targetLoserVol;
                            lReq.deviation = slippage;
                            lReq.magic = magic;
                            lReq.type = ORDER_TYPE_BUY;
                            lReq.price = Ask(_Symbol);
                            lReq.type_filling = ORDER_FILLING_IOC;

                            g_asyncManager.SendAsync(lReq);
                            
                            if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                                CAuroraLogger::InfoStrategy(StringFormat("[SMART GRID] Active Scrubbing: Partial Winner %I64u (%.2f lots) & Loser %I64u (%.2f lots)", limitP.ticket, winnerVolToClose, toxicP.ticket, targetLoserVol));
                            }
                       }
                 }
             }

         }
    }
    
    // --- CROSS-SIDE SCRUBBING: Global Best Winner vs Global Best Loser ---
    int global_winner = -1; double pmax = -DBL_MAX;
    int global_loser  = -1; double pmin = DBL_MAX;
    
    for(int i=0; i<cnt; i++) {
        if (positions[i].profit > pmax) { pmax = positions[i].profit; global_winner = i; }
        if (positions[i].profit < pmin) { pmin = positions[i].profit; global_loser  = i; }
    }
    
    if (global_winner != -1 && global_loser != -1 && global_winner != global_loser) {
        SPosMetric winP = positions[global_winner];
        SPosMetric losP = positions[global_loser];
        
        if (winP.profit > 0 && losP.profit < 0) {
            double winnerVolToClose = winP.volume * winnerClosePercent;
            winnerVolToClose = ClampVolumeToSymbol(winnerVolToClose, _Symbol);
            
            if (winnerVolToClose >= minVol) {
                double adjustedBudget = (winP.profit * winnerClosePercent) * profitRatio;
                double ratio = adjustedBudget / MathAbs(losP.profit);
                double targetLoserVol = losP.volume * ratio;
                targetLoserVol = ClampVolumeToSymbol(targetLoserVol, _Symbol);
                
                if (targetLoserVol >= minVol && winnerVolToClose >= minVol) {
                    // Close Winner (partial)
                    MqlTradeRequest wReq; ZeroMemory(wReq);
                    wReq.action = TRADE_ACTION_DEAL;
                    wReq.position = winP.ticket;
                    wReq.symbol = _Symbol;
                    wReq.volume = winnerVolToClose;
                    wReq.deviation = slippage;
                    wReq.magic = magic;
                    wReq.type = (winP.type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                    wReq.price = (winP.type == POSITION_TYPE_BUY) ? Bid(_Symbol) : Ask(_Symbol);
                    wReq.type_filling = ORDER_FILLING_IOC;
                    
                    if(g_asyncManager.SendAsync(wReq)) {
                        // Close Loser (partial)
                        MqlTradeRequest lReq; ZeroMemory(lReq);
                        lReq.action = TRADE_ACTION_DEAL;
                        lReq.position = losP.ticket;
                        lReq.symbol = _Symbol;
                        lReq.volume = targetLoserVol;
                        lReq.deviation = slippage;
                        lReq.magic = magic;
                        lReq.type = (losP.type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                        lReq.price = (losP.type == POSITION_TYPE_BUY) ? Bid(_Symbol) : Ask(_Symbol);
                        lReq.type_filling = ORDER_FILLING_IOC;
                        
                        g_asyncManager.SendAsync(lReq);
                        
                        if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                            CAuroraLogger::InfoStrategy(StringFormat("[SMART GRID] Cross-Side Scrubbing: Winner %I64u (%.2f lots) & Loser %I64u (%.2f lots)", winP.ticket, winnerVolToClose, losP.ticket, targetLoserVol));
                        }
                    }
                }
            }
        }
    }
}

void checkMarginDeleverage(ulong magic, double criticalLevel, bool worstFirst, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT, double balanceOverride = -1) {
    double marginLevel = (balanceOverride > 0) ? GetSimulatedMarginLevel(balanceOverride) : AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    if (marginLevel <= 0 || marginLevel > criticalLevel) return;

    // Safety: don't loop delete. One per call (timer).
    
    int total = PositionsTotal();
    ulong bestCandidate = 0;
    double worstMetric = worstFirst ? DBL_MAX : DBL_MAX; // Pour worstFirst: profit (chercher min), Pour old: time (chercher min)
    
    // Si worstFirst=false (Oldest), on cherche le timestamp le plus petit (min)
    // Si worstFirst=true (Worst Profit), on cherche le profit le plus petit (négatif le plus bas)

    for (int i = 0; i < total; i++) {
        ulong ticker = PositionGetTicket(i);
        if (ticker == 0) continue;
        if (!PositionSelectByTicket(ticker)) continue;
        if ((ulong)PositionGetInteger(POSITION_MAGIC) != magic) continue;
        
        if (worstFirst) {
            double prof = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); // Include Swap in 'pain'
            if (prof < worstMetric) {
                worstMetric = prof;
                bestCandidate = ticker;
            }
        } else {
             // Oldest
             datetime dt = (datetime)PositionGetInteger(POSITION_TIME);
             if ((double)dt < worstMetric) {
                 worstMetric = (double)dt;
                 bestCandidate = ticker;
             }
        }
    }

    if (bestCandidate != 0) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_RISK)) 
            CAuroraLogger::WarnRisk(StringFormat("[MARGIN GUARD] CRITICAL MARGIN LEVEL (%.2f%% < %.2f%%). De-leveraging trade %I64u (Metric=%.2f)", marginLevel, criticalLevel, bestCandidate, worstMetric));
        
        closeOrder(bestCandidate, slippage, filling);
    }
}

void checkForBE(ulong magic, ENUM_BE_MODE mode, double triggerRatio, int triggerPts, double spreadMult, int slDevFallbackPts, bool onNewBar, int beMinOffsetPts = 10, int slippage = 30, ENUM_FILLING filling = FILLING_DEFAULT) {
    if (mode == BE_MODE_RATIO && triggerRatio <= 0) return;
    if (mode == BE_MODE_POINTS && triggerPts <= 0) return;

    string symbol = _Symbol;
    const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    const int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    const int minPts = MinBrokerPoints(symbol);
    const int spreadPts = (int)MathMax((double)SymbolInfoInteger(symbol, SYMBOL_SPREAD), 1.0);
    
    // Modification RAW : Le calcul basé sur le spread seul est dangereux sur RAW (spread~0)
    // On calcule l'offset demandé par l'utilisateur, mais on force un minimum de sécurité (10pts = 1 pip)
    const int offsetPts = (int)MathMax((double)beMinOffsetPts, MathRound(spreadPts * spreadMult));

    // Option OnNewBar: se base sur l'heure d'ouverture de la bougie courante (iTime)
    static datetime last_bar_ts = 0;
    if (onNewBar) {
        datetime t0 = iTime(symbol, PERIOD_CURRENT, 0);
        if (t0 == last_bar_ts) return; // déjà traité pour cette barre
        last_bar_ts = t0;
    }

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; --i) {
        ulong ticket = PositionGetTicket(i);
        if(ticket==0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if ((ulong)PositionGetInteger(POSITION_MAGIC) != magic) continue;
        if (PositionGetString(POSITION_SYMBOL) != symbol) continue;

        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        const bool isBuy = (ptype == POSITION_TYPE_BUY);
        const double op   = PositionGetDouble(POSITION_PRICE_OPEN);
        const double sl   = PositionGetDouble(POSITION_SL);
        const double cur  = isBuy ? Bid(symbol) : Ask(symbol);

        // --- CALCUL DISTANCE DE DECLENCHEMENT ---
        double triggerDistPtrs = 0.0;
        
        if (mode == BE_MODE_POINTS) {
            triggerDistPtrs = (double)triggerPts;
        } else {
             // MODE RATIO
             double riskPts = 0.0;
             if (sl > 0) {
                 riskPts = (isBuy ? (op - sl)/point : (sl - op)/point);
             } else {
                 riskPts = (double)MathMax(slDevFallbackPts, 1);
             }
             if (IsLessOrEqual(riskPts, 0)) continue;
             triggerDistPtrs = riskPts * triggerRatio;
        }

        const double gainPts = (isBuy ? (cur - op)/point : (op - cur)/point);
        // Si gain < trigger distance -> NEXT
        if (IsLess(gainPts, triggerDistPtrs)) continue;

        // Modification RAW : Calcul précis du niveau "Net Profit = 0" incluant comm + swap
        // calcCostByTicket retourne -(comm+swap). On prend sa valeur absolue (MathMax(..., 0)).
        double cost = MathMax(calcCostByTicket(ticket), 0.0);
        double beBase = calcPriceByTicket(ticket, cost);
        if(beBase == 0) beBase = op; // Fallback si erreur calcul/historique

        // Cible BE : Prix compensé (Entry+Comm) + offset minimum
        double bePrice = isBuy ? (beBase + offsetPts*point) : (beBase - offsetPts*point);
        bePrice = NormalizeDouble(bePrice, digits);

        // Non régression: le SL ne doit jamais reculer
        if (sl > 0) {
            if (isBuy && IsGreaterOrEqual(sl, bePrice)) continue;
            if (!isBuy && IsLessOrEqual(sl, bePrice)) continue;
        }

        // Respect FREEZE/STOPS
        if (isBuy) {
            if (!IsGreaterOrEqual(cur - bePrice, minPts * point)) continue;
        } else {
            if (!IsGreaterOrEqual(bePrice - cur, minPts * point)) continue;
        }

        // Appliquer SLTP (SL uniquement)
        MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
        req.action   = TRADE_ACTION_SLTP;
        req.position = ticket;
        req.symbol   = symbol;
        req.magic    = magic;
        req.deviation= slippage;
        req.sl       = bePrice;
        req.tp       = PositionGetDouble(POSITION_TP);
        if(!g_asyncManager.SendAsync(req)){
            int err = GetLastError();
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("[BE] ticket=%I64u [ASYNC] error #%d : %s", ticket, err, ErrorDescription(err)));
            continue;
        }
        if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
            string trigInfo = (mode==BE_MODE_POINTS) ? StringFormat("%d pts", triggerPts) : StringFormat("R=%.2f", triggerRatio);
            CAuroraLogger::InfoStrategy(StringFormat("[BE] ticket=%I64u -> SL=%.0fpts @ %.5f (Trig: %s, cost covered, offset=%dpts)", ticket, (isBuy?(bePrice-op):(op-bePrice))/point, bePrice, trigInfo, offsetPts));
        }
    }
}

// --- GerEA CLASS (Wrappers) ---

class GerEA {
private:
    ulong magicNumber;
public:
    double risk;
    double martingaleRisk;
    bool martingale;
    int slippage;
    bool reverse;
    double trailingStopLevel;
    
    // Grid settings
    bool grid;
    double gridVolMult;
    double gridTrailingStopLevel;
    int gridMaxLvl;
    
    // Dynamic Grid Settings (New v1.31)
    bool gridDynamic;      // Activer l'espacement basé sur l'ATR
    int gridAtrPeriod;     // Période ATR pour le calcul
    double gridAtrMult;    // Multiplicateur d'espacement (ex: 1.0 x ATR)

    // Profit Target Grid (New v1.32)
    double gridMinProfit;    // Montant ou % de profit minimum visé pour fermer la grille
    ENUM_GRID_PROFIT_MODE gridProfitMode; // Mode de profit
    
    double gridMaxATR;       // Filtre Volatilité

    // Internal handle for ATR
    int gridAtrHandle;

    double equityDrawdownLimit;
    ENUM_FILLING filling;
    ENUM_RISK riskMode;
    double riskMaxTotalLots;

    // Margin Guard
    bool mgEnable;
    double mgStretchLvl;
    double mgMaxMult;
    double mgDelevLvl;
    bool mgDelevWorst;
    bool mgDampingEnable;
    double mgDampingStart;
    double mgDampingMin;
    double mgDampingLowBound;
    
    // Smart Grid Reduction
    bool   sgReductionEnable;
    int    sgReductionStartLvl;
    double sgReductionProfitRatio;
    double sgReductionMinVol;
    double sgReductionWinnerClosePercent;
    
    // Infinity
    bool   infEnable;
    double infTriggerPct;
    double infTrailingStep;
    int    infTpDistance;

    ENUM_INFINITY_STEP_MODE infStepMode;
    int    infAtrPeriod;
    double infAtrMult;
    int    infAtrHandle;
    
    // Spread Filter
    int maxSpreadLimit;

    // Virtual Balance (-1 = Disabled)
    double virtualBalance;

    GerEA() {
        risk = 0.01;
        martingaleRisk = 0.04;
        martingale = false;
        slippage = 30;
        reverse = false;
        trailingStopLevel = 0.5;
        trailMode = TRAIL_STANDARD;
        trailAtrPeriod = 14;
        trailAtrMult = 2.5;
        grid = false;
        gridVolMult = 1.0;
        gridTrailingStopLevel = 0;
        gridMaxLvl = 20;
        
        // Initialisation Grid Dynamique
        gridDynamic = false;
        gridAtrPeriod = 14;
        gridAtrMult = 1.0;

        // Initialisation Profit Target
        gridMinProfit = 0.0;     // Par défaut 0 (Break-Even strict)
        gridProfitMode = GRID_PROFIT_CURRENCY;
        gridMaxATR = 0.0;

        gridAtrHandle = INVALID_HANDLE;
        trailAtrHandle = INVALID_HANDLE;
        
        equityDrawdownLimit = 0;
        filling = FILLING_DEFAULT;
        riskMode = RISK_DEFAULT;
        riskMaxTotalLots = 50.0;

        // Init Margin Guard
        mgEnable = true;
        mgStretchLvl = 2000.0;
        mgMaxMult = 5.0;
        mgDelevLvl = 150.0;
        mgDelevWorst = true;
        mgDampingEnable = true;
        mgDampingStart = 1500.0;
        mgDampingMin = 0.8;
        mgDampingLowBound = 500.0;
        
        sgReductionEnable = false;
        sgReductionStartLvl = 5;
        sgReductionProfitRatio = 0.8;
        sgReductionMinVol = 0.01;
        sgReductionWinnerClosePercent = 0.5; // Default 50%
        
        // Configuration Infinity
        infEnable = false;
        infTriggerPct = 90.0;
        infTrailingStep = 0.4;
        infTpDistance = 50000;
        infTriggerPct = 90.0;
        infTrailingStep = 0.4;
        infTpDistance = 50000;
        infStepMode = INF_STEP_PERCENT;
        infAtrPeriod = 14;
        infAtrMult = 1.5;
        infAtrHandle = INVALID_HANDLE;
        maxSpreadLimit = -1;
        beMinOffsetPts = 10;
        virtualBalance = -1;
    }
    
    // Trailing Params
    ENUM_TRAIL_MODE trailMode;
    int    trailAtrPeriod;
    double trailAtrMult;
    int    trailAtrHandle;

    void Init(int magicSeed = 1) {
        magicNumber = calcMagic(magicSeed);
    }

    void InitATR() {
        if (gridDynamic && gridAtrHandle == INVALID_HANDLE) {
            gridAtrHandle = iATR(NULL, PERIOD_CURRENT, gridAtrPeriod);
        }
        if (trailMode == TRAIL_ATR && trailAtrHandle == INVALID_HANDLE) {
            trailAtrHandle = iATR(NULL, PERIOD_CURRENT, trailAtrPeriod);
        }
        if (infEnable && infStepMode == INF_STEP_ATR && infAtrHandle == INVALID_HANDLE) {
             infAtrHandle = iATR(NULL, PERIOD_CURRENT, infAtrPeriod);
        }
    }

    void Deinit() {
        if (gridAtrHandle != INVALID_HANDLE) {
            IndicatorRelease(gridAtrHandle);
            gridAtrHandle = INVALID_HANDLE;
        }
        if (trailAtrHandle != INVALID_HANDLE) {
            IndicatorRelease(trailAtrHandle);
            trailAtrHandle = INVALID_HANDLE;
        }
        if (infAtrHandle != INVALID_HANDLE) {
            IndicatorRelease(infAtrHandle);
            infAtrHandle = INVALID_HANDLE;
        }
    }



    private:
    bool OpenOrder(ENUM_ORDER_TYPE type, double price, double sl, double tp, string comment = "", string name = NULL, double vol = 0, bool isl = false, bool itp = false) {
        if (name == NULL) name = _Symbol;
        
        // Handle Reverse Mode
        if (reverse) {
            if (type == ORDER_TYPE_BUY) {
                type = ORDER_TYPE_SELL;
                price = Bid(name);
                // Swap SL/TP logic if needed or just trust the caller passed correct relative distances? 
                // In original code: BuyOpen -> Reverse -> order(SELL, Bid, tp, sl...)
                // So TP and SL are swapped in the call order.
                double tmp = sl; sl = tp; tp = tmp;
                bool tmpB = isl; isl = itp; itp = tmpB;
            } else {
                type = ORDER_TYPE_BUY;
                price = Ask(name);
                double tmp = sl; sl = tp; tp = tmp;
                bool tmpB = isl; isl = itp; itp = tmpB;
            }
        }

        // Handle Comment
        if ((comment == "" || comment == NULL) && (true || grid)) { // set_comment was usually true or implicit
             // Note: Original logic had complex comment logic, simplifying for readability but keeping behavior
             // "if ((comment == "" || comment == NULL) && (set_comment || grid))"
             // We'll rely on caller passing computed comment or we compute it if empty.
             // Actually, to fully DRY, let's keep it simple here and let caller handle specific comment rules or basic fallback.
             // The original code calculated distance d = MathAbs(in - sl).
             if(sl > 0) {
                 int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
                 double d = MathAbs(price - sl);
                 comment = DoubleToString(d, digits);
             }
        }

        return order(type, magicNumber, price, sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, filling, riskMode, virtualBalance);
    }

    public:
    bool BuyOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
       return OpenOrder(ORDER_TYPE_BUY, Ask(name), sl, tp, comment, name, vol, isl, itp);
    }

    bool SellOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
       return OpenOrder(ORDER_TYPE_SELL, Bid(name), sl, tp, comment, name, vol, isl, itp);
    }

    bool BuyOpen(double in, double sl, double tp, bool isl = false, bool itp = false, string name = NULL, double vol = 0, string comment = "", bool set_comment = true) {
        if (grid) isl = true;
        // Comment Logic preserved from original to ensure exact behavior if set_comment is false
        if ((comment == "" || comment == NULL) && (set_comment || grid)) {
             // Let OpenOrder handle the default comment calc if empty string passed
             comment = ""; 
        } else if (!set_comment && !grid && (comment == "" || comment == NULL)) {
            // Force a space to prevent OpenOrder from auto-calculating if set_comment is false
             comment = " "; 
        }
        return OpenOrder(ORDER_TYPE_BUY, in, sl, tp, comment, name, vol, isl, itp);
    }
    
    // Note: To fully support the exact logic of "reverse" swapping TP/SL inside the call, OpenOrder covers it.
    
    bool SellOpen(double in, double sl, double tp, bool isl = false, bool itp = false, string name = NULL, double vol = 0, string comment = "", bool set_comment = true) {
        if (grid) isl = true;
         // Comment Logic preserved
        if ((comment == "" || comment == NULL) && (set_comment || grid)) {
             comment = ""; 
        } else if (!set_comment && !grid && (comment == "" || comment == NULL)) {
             comment = " "; 
        }
        return OpenOrder(ORDER_TYPE_SELL, in, sl, tp, comment, name, vol, isl, itp);
    }

    bool PendingOrder(ENUM_ORDER_TYPE ot, double in, double sl = 0, double tp = 0, double vol = 0, double stoplimit = 0, datetime expiration = 0, ENUM_ORDER_TYPE_TIME timeType = 0, string symbol = NULL, string comment = "") {
        return pendingOrder(ot, magicNumber, in, sl, tp, vol, stoplimit, expiration, timeType, symbol, comment, filling, riskMode, risk, slippage);
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


    
    // Ajout Variable pour BE paramétrable: stocké dans la classe aussi pour le wrapper
    int beMinOffsetPts;

    void CheckForTrail() {
        checkForTrail(magicNumber, trailingStopLevel, gridTrailingStopLevel, slippage, filling, gridMinProfit, gridProfitMode, infEnable, infTriggerPct, infTrailingStep, infTpDistance, trailMode, trailAtrHandle, trailAtrMult, infStepMode, infAtrHandle, infAtrMult);
    }

    void CheckForGrid() {
        checkForGrid(magicNumber, risk, gridVolMult, gridMaxLvl, slippage, filling, -1, gridDynamic, gridAtrHandle, gridAtrPeriod, gridAtrMult, gridMinProfit, gridProfitMode, gridMaxATR, mgEnable, mgStretchLvl, mgMaxMult, mgDampingEnable, mgDampingStart, mgDampingMin, mgDampingLowBound, maxSpreadLimit, riskMaxTotalLots, virtualBalance);
    }

    // Variante avec filtre de côté: -1=both, 0=BUY only, 1=SELL only
    void CheckForGridSide(const int sideFilter) {
        checkForGrid(magicNumber, risk, gridVolMult, gridMaxLvl, slippage, filling, sideFilter, gridDynamic, gridAtrHandle, gridAtrPeriod, gridAtrMult, gridMinProfit, gridProfitMode, gridMaxATR, mgEnable, mgStretchLvl, mgMaxMult, mgDampingEnable, mgDampingStart, mgDampingMin, mgDampingLowBound, maxSpreadLimit, riskMaxTotalLots, virtualBalance);
    }
    
    void CheckMarginDeleverage() {
        if(mgEnable) checkMarginDeleverage(magicNumber, mgDelevLvl, mgDelevWorst, slippage, filling, virtualBalance);
    }
    
    void CheckSmartGridReduction() {
        // Smart Grid doesn't use balance for sizing, but uses profitRatio.
        // However, if we added balance dependency, we should add it here too.
        // Currently it uses existing position volume scrubbing. 
        // No balance dep in current Scrubbing logic (it's volume/profit based).
        if(sgReductionEnable) checkSmartGridReduction(magicNumber, sgReductionStartLvl, sgReductionProfitRatio, sgReductionMinVol, sgReductionWinnerClosePercent, slippage, filling);
    }

    void CheckForEquity() {
        checkForEquity(magicNumber, equityDrawdownLimit, slippage, filling, virtualBalance);
    }

    void CheckForBE(const ENUM_BE_MODE mode, const double triggerRatio, const int triggerPts, const double spreadMult, const int slDevFallback, const bool onNewBar) {
        checkForBE(magicNumber, mode, triggerRatio, triggerPts, spreadMult, slDevFallback, onNewBar, beMinOffsetPts, slippage, filling);
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