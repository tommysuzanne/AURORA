//+------------------------------------------------------------------+
//|                                                      EAUtils.mqh |
//|                                           Copyright 2025, Aurora |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Aurora"
#property link      " https://github.com/tommysuzanne"
#property version   "1.34" // Reordered for strict compilation (No Prototypes)

#include <errordescription.mqh>
#include "aurora_logger.mqh"
#include "aurora_ftmo_guard.mqh"

// Objet FTMO guard déclaré dans l'EA principal
extern CAuroraFtmoGuard g_ftmo_guard;

#define AURORA_EAUTILS_VERSION "1.34"

// --- ENUMS ---
enum ENUM_FILLING {
    FILLING_DEFAULT, 
    FILLING_FOK,     
    FILLING_IOK,     
    FILLING_BOC,     
    FILLING_RETURN   
};

enum ENUM_SL {
    SL_SWING, 
    SL_AR, 
    SL_MR, 
    SL_FIXED_POINT 
};

enum ENUM_RISK {
    RISK_DEFAULT, 
    RISK_FIXED_VOL, 
    RISK_MIN_AMOUNT, 
    RISK_EQUITY = ACCOUNT_EQUITY, 
    RISK_BALANCE = ACCOUNT_BALANCE, 
    RISK_MARGIN_FREE = ACCOUNT_MARGIN_FREE, 
    RISK_CREDIT = ACCOUNT_CREDIT 
};

// --- UTILS & HELPERS (Low Level) ---

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

int CountDigits(double val, int maxPrecision = 8) {
    int digits = 0;
    while (NormalizeDouble(val, digits) != NormalizeDouble(val, maxPrecision))
        digits++;
    return digits;
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

double GetTickValue(string symbol = NULL) {
    if (symbol == NULL) symbol = _Symbol;
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double profit = 0;
    if (OrderCalcProfit(ORDER_TYPE_BUY, symbol, 1, price, price + tickSize, profit) && profit > 0)
        return profit;
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

double High(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    double x = iHigh(symbol, timeframe, i);
    if (x == 0) { if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("Error (%s): #%d", __FUNCTION__, GetLastError())); }
    return x;
}

double Low(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    double x = iLow(symbol, timeframe, i);
    if (x == 0) { if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("Error (%s): #%d", __FUNCTION__, GetLastError())); }
    return x;
}

double Open(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    double x = iOpen(symbol, timeframe, i);
    if (x == 0) { if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("Error (%s): #%d", __FUNCTION__, GetLastError())); }
    return x;
}

double Close(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    double x = iClose(symbol, timeframe, i);
    if (x == 0) { if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("Error (%s): #%d", __FUNCTION__, GetLastError())); }
    return x;
}

datetime Time(int i, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    datetime x = iTime(symbol, timeframe, i);
    if (x == 0) { if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("Error (%s): #%d", __FUNCTION__, GetLastError())); }
    return x;
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

double ResolveRiskBalance(double balanceOverride, ENUM_RISK risk_mode) {
    if (balanceOverride > 0)
        return balanceOverride;
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
    int j = 0;
    for (int i = 0; i < total; i++) {
        ulong pticket = PositionGetTicket(i);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        if (pmagic != magic) continue;
        if (name != NULL && psymbol != name) continue;
        ArrayResize(arr, j + 1);
        arr[j] = pticket;
        j++;
    }
    return j;
}

int ordersTickets(ulong magic, ulong &arr[], string name = NULL) {
    int total = OrdersTotal();
    int j = 0;
    for (int i = 0; i < total; i++) {
        ulong oticket = OrderGetTicket(i);
        ulong omagic = OrderGetInteger(ORDER_MAGIC);
        string osymbol = OrderGetString(ORDER_SYMBOL);
        if (omagic != magic) continue;
        if (name != NULL && osymbol != name) continue;
        ArrayResize(arr, j + 1);
        arr[j] = oticket;
        j++;
    }
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

    string str = (string) magicSeed + (string) n + (string) Period();
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

    if (distance <= 0 || point <= 0 || tv <= 0)
        distance = point;
    double vol = (balanceBase * risk) / distance * point / tv;
    return ClampVolumeToSymbol(vol, sym);
}

double calcVolume(double in, double sl, double risk = 0.01, double tp = 0, bool martingale = false, double martingaleRisk = 0.04, ulong magic = 0, string name = NULL, double balance = 0, ENUM_RISK risk_mode = 0) {
    name = name == NULL ? _Symbol : name;
    if (sl == 0)
        sl = tp;

    double distance = MathAbs(in - sl);
    if (distance <= 0 && tp != 0)
        distance = MathAbs(in - tp);
    if (distance <= 0)
        distance = SymbolInfoDouble(name, SYMBOL_POINT);

    double vol = calcVolumeFromDistance(name, distance, risk, risk_mode, balance);

    if (martingale) {
        ulong ticket = getLatestTicket(magic);
        if (ticket != 0) {
            PositionSelectByTicket(ticket);
            HistorySelectByPosition(PositionGetInteger(POSITION_IDENTIFIER));
            HistoryDealSelect(ticket);
            double lprofit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if (lprofit < 0) {
                double lin = HistoryDealGetDouble(ticket, DEAL_PRICE);
                double lsl = HistoryDealGetDouble(ticket, DEAL_SL);
                double lvol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                vol = 2 * MathAbs(lin - lsl) * lvol / MathAbs(in - tp);
                double balanceBase = ResolveRiskBalance(balance, risk_mode);
                double point = SymbolInfoDouble(name, SYMBOL_POINT);
                double tv = GetTickValue(name);
                double dist = MathMax(MathAbs(in - sl), point);
                double capVol = (balanceBase * martingaleRisk) / dist * point / tv;
                vol = MathMin(vol, capVol);
            }
        }
        vol = ClampVolumeToSymbol(vol, name);
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
    line = NormalizeDouble(line, digits);
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
    line = NormalizeDouble(line, digits);

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

bool order(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double risk = 0.01, bool martingale = false, double martingaleRisk = 0.04, int slippage = 30, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT, ENUM_RISK risk_mode = RISK_DEFAULT) {
    name = name == NULL ? _Symbol : name;
    int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
    int err;
    bool os, osc;

    in = NormalizeDouble(in, digits);
    tp = NormalizeDouble(tp, digits);
    sl = NormalizeDouble(sl, digits);

    if (ot == ORDER_TYPE_BUY) {
        in = Ask(name);
        if (sl != 0 && sl >= Bid(name)) return false;
        if (tp != 0 && tp <= Bid(name)) return false;
    } else if (ot == ORDER_TYPE_SELL) {
        in = Bid(name);
        if (sl != 0 && sl <= Ask(name)) return false;
        if (tp != 0 && tp >= Ask(name)) return false;
    }

    if (MQLInfoInteger(MQL_TESTER) && in == 0) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders("OpenPrice is 0!");
        return false;
    }

    if (comment == "" && positionsTotalMagic(magic, name) == 0)
        comment = sl ? DoubleToString(MathAbs(in - sl), digits) : tp ? DoubleToString(MathAbs(in - tp), digits) : "";

    if (vol == 0)
        vol = calcVolume(in, sl, risk, tp, martingale, martingaleRisk, magic, name, 0, risk_mode);
    // Caps FTMO (ordre + net lots + max positions)
    vol = g_ftmo_guard.CapVolumeForSymbol(name, vol);
    if (g_ftmo_guard.PreTradeEnabled()) {
        // Cap net lots par symbole
        const double cap = g_ftmo_guard.CapNetLotsPerSymbol();
        if (cap > 0) {
            double net = NetLotsForSymbol(name);
            double room = cap - net;
            if (room <= 0) return false; // déjà au plafond
            if (vol > room) vol = room;
        }
        // Cap nombre max de positions
        const int maxpos = g_ftmo_guard.MaxOpenPositions();
        if (maxpos > 0 && PositionsTotal() >= maxpos) return false;
    }

    if (isl) sl = 0;
    if (itp) tp = 0;

    // Pre‑Trade Check (bloque si la position violerait MDL/MaxLoss)
    if (g_ftmo_guard.PreTradeEnabled()) {
        double sl_points = 0.0;
        if (sl != 0) {
            const double point = SymbolInfoDouble(name, SYMBOL_POINT);
            sl_points = (ot==ORDER_TYPE_BUY ? (in - sl)/point : (sl - in)/point);
        }
        if (sl_points <= 0) sl_points = (double)SymbolInfoInteger(name, SYMBOL_TRADE_STOPS_LEVEL);
        if (!g_ftmo_guard.PreTradeOK(name, vol, sl_points)) return false;
    }

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

    int cnt = 1;
    do {
        ZeroMemory(res);
        ResetLastError();
        os = OrderSend(req, res);
        err = GetLastError();

        if (os && cnt == 1) return true;
        if (os) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::InfoOrders(StringFormat("OrderSend success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));
            return true;
        }

        osc = false;
        osc = osc || res.retcode == TRADE_RETCODE_REQUOTE;
        osc = osc || res.retcode == TRADE_RETCODE_TIMEOUT;
        osc = osc || res.retcode == TRADE_RETCODE_INVALID_PRICE;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_CHANGED;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_OFF;
        osc = osc || res.retcode == TRADE_RETCODE_CONNECTION;

        if (!osc) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::ErrorOrders(StringFormat("OrderSend error: retcode=%u  deal=%I64u  order=%I64u  %s", res.retcode, res.deal, res.order, res.comment));
            return false;
        }

        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("OrderSend error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));

        Sleep(mRetry);
        cnt++;

        if (ot == ORDER_TYPE_BUY) {
            if (res.ask && Ask(name) == req.price) req.price = res.ask;
            else req.price = Ask(name);
        } else if (ot == ORDER_TYPE_SELL) {
            if (res.bid && Bid(name) == req.price) req.price = res.bid;
            else req.price = Bid(name);
        }

    } while (!os && cnt <= nRetry);

    return false;
}

bool pendingOrder(ENUM_ORDER_TYPE ot, ulong magic, double in, double sl = 0, double tp = 0, double vol = 0, double stoplimit = 0, datetime expiration = 0, ENUM_ORDER_TYPE_TIME timeType = 0, string symbol = NULL, string comment = "", ENUM_FILLING filling = FILLING_DEFAULT, ENUM_RISK risk_mode = RISK_DEFAULT, double risk = 0.01, int slippage = 30, int nRetry = 5, int mRetry = 2000) {
    if (symbol == NULL) symbol = _Symbol;
    int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    int err;
    bool os, osc;

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

    int cnt = 1;
    do {
        ZeroMemory(res);
        ResetLastError();
        os = OrderSend(req, res);
        err = GetLastError();

        if (os && cnt == 1) return true;
        if (os) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::InfoOrders(StringFormat("PendingOrderSend success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));
            return true;
        }

        osc = false;
        osc = osc || res.retcode == TRADE_RETCODE_REQUOTE;
        osc = osc || res.retcode == TRADE_RETCODE_TIMEOUT;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_OFF;
        osc = osc || res.retcode == TRADE_RETCODE_CONNECTION;

        if (!osc) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::ErrorOrders(StringFormat("PendingOrderSend error: retcode=%u  deal=%I64u  order=%I64u  %s", res.retcode, res.deal, res.order, res.comment));
            return false;
        }

        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("PendingOrderSend error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));

        Sleep(mRetry);
        cnt++;

    } while (!os && cnt <= nRetry);

    return false;
}

bool closeOrder(ulong ticket, int slippage = 30, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
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

    bool os, osc;
    int cnt = 1;
    do {
        ZeroMemory(res);
        ResetLastError();
        os = OrderSend(req, res);
        err = GetLastError();

        if (os && cnt == 1) return true;
        if (os) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::InfoOrders(StringFormat("OrderClose success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));
            return true;
        }

        osc = false;
        osc = osc || res.retcode == TRADE_RETCODE_REQUOTE;
        osc = osc || res.retcode == TRADE_RETCODE_TIMEOUT;
        osc = osc || res.retcode == TRADE_RETCODE_INVALID_PRICE;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_CHANGED;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_OFF;
        osc = osc || res.retcode == TRADE_RETCODE_CONNECTION;

        if (!osc) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::ErrorOrders(StringFormat("OrderClose error: retcode=%u  deal=%I64u  order=%I64u  %s", res.retcode, res.deal, res.order, res.comment));
            return false;
        }

        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("OrderClose error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));

        Sleep(mRetry);
        cnt++;

        if (ptype == POSITION_TYPE_BUY) {
            if (res.bid && Bid(psymbol) == req.price) req.price = res.bid;
            else req.price = Bid(psymbol);
        } else {
            if (res.ask && Ask(psymbol) == req.price) req.price = res.ask;
            else req.price = Ask(psymbol);
        }

    } while (!os && cnt <= nRetry);

    return false;
}

bool closePendingOrder(ulong ticket, int nRetry = 5, int mRetry = 2000) {
    int err;

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    req.action = TRADE_ACTION_REMOVE;
    req.order = ticket;

    bool os, osc;
    int cnt = 1;
    do {
        ZeroMemory(res);
        ResetLastError();
        os = OrderSend(req, res);
        err = GetLastError();

        if (os && cnt == 1) return true;
        if (os) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::InfoOrders(StringFormat("PendingOrderClose success: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));
            return true;
        }

        osc = false;
        osc = osc || res.retcode == TRADE_RETCODE_REQUOTE;
        osc = osc || res.retcode == TRADE_RETCODE_TIMEOUT;
        osc = osc || res.retcode == TRADE_RETCODE_INVALID_PRICE;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_CHANGED;
        osc = osc || res.retcode == TRADE_RETCODE_PRICE_OFF;
        osc = osc || res.retcode == TRADE_RETCODE_CONNECTION;

        if (!osc) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::ErrorOrders(StringFormat("PendingOrderClose error: retcode=%u  deal=%I64u  order=%I64u  %s", res.retcode, res.deal, res.order, res.comment));
            return false;
        }

        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("PendingOrderClose error: iter=%u  retcode=%u  deal=%I64u  order=%I64u  %s", cnt, res.retcode, res.deal, res.order, res.comment));

        Sleep(mRetry);
        cnt++;

    } while (!os && cnt <= nRetry);

    return false;
}

void closeOrders(ENUM_POSITION_TYPE pt, ulong magic, int slippage = 30, string name = NULL, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        string psymbol = PositionGetString(POSITION_SYMBOL);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        if (pmagic != magic) continue;
        if (ptype != pt) continue;
        if (name != NULL && psymbol != name) continue;
        closeOrder(pticket, slippage, nRetry, mRetry, filling);
    }
}

void closePendingOrders(ENUM_ORDER_TYPE ot, ulong magic, string name = NULL, int nRetry = 5, int mRetry = 2000) {
    int total = OrdersTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong oticket = OrderGetTicket(i);
        string osymbol = OrderGetString(ORDER_SYMBOL);
        ulong omagic = OrderGetInteger(ORDER_MAGIC);
        ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE) OrderGetInteger(ORDER_TYPE);
        if (omagic != magic) continue;
        if (otype != ot) continue;
        if (name != NULL && osymbol != name) continue;
        closePendingOrder(oticket, nRetry, mRetry);
    }
}

// --- LOGIC HELPERS (Fill Symbols, Fix Multi, etc) ---

void fillSymbols(string &arr[], bool multiple_symbols, string symbols_str = "", string currencies_str = "EUR, USD, JPY, CHF, AUD, GBP, CAD, NZD") {
    if (!multiple_symbols) {
        ArrayResize(arr, 1);
        arr[0] = _Symbol;
        return;
    }

    string sbls[];
    int n = StringSplit(symbols_str, ',', sbls);
    if (n > 0) {
        int k = 0;
        string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
        for (int i = 0; i < n; i++) {
            string symbol = Trim(sbls[i]) + postfix;
            bool b = false;
            if (!SymbolExist(symbol, b)) continue;
            ArrayResize(arr, k + 1);
            arr[k] = symbol;
            k++;
        }
        return;
    }

    string curs[];
    n = StringSplit(currencies_str, ',', curs);
    int k = 0;
    string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (i == j) continue;
            string symbol = Trim(curs[i]) + Trim(curs[j]) + postfix;
            bool b = false;
            if (!SymbolExist(symbol, b))
                symbol = Trim(curs[i]) + AccountInfoString(ACCOUNT_CURRENCY) + postfix;
            if (!SymbolExist(symbol, b)) continue;
            Ask(symbol);
        }
    }
}

void fixMultiCurrencies(string currencies_str = "EUR, USD, JPY, CHF, AUD, GBP, CAD, NZD") {
    string postfix = StringLen(_Symbol) > 6 ? StringSubstr(_Symbol, 6) : "";
    string cur = AccountInfoString(ACCOUNT_CURRENCY);
    string symbol;
    string curs[];
    bool b;
    int n = StringSplit(currencies_str, ',', curs);
    for (int i = 0; i < n; i++) {
        if (cur == curs[i]) continue;
        symbol = cur + Trim(curs[i]) + postfix;
        if (!SymbolExist(symbol, b))
            symbol = Trim(curs[i]) + cur + postfix;
        if (!SymbolExist(symbol, b)) continue;
        Ask(symbol);
    }
}

// --- STRATEGY HELPERS (SL, ATR) ---

double BuySL(ENUM_SL sltype, int lookback, double price = 0, int dev = 0, int start = 0, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    symbol = symbol == NULL ? _Symbol : symbol;
    price = price == 0 ? Ask(symbol) : price;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double sl = 0;

    if (sltype == SL_SWING) {
        int i = iLowest(symbol, timeframe, MODE_LOW, lookback, start);
        sl = iLow(symbol, timeframe, i) - dev * point;
    }

    else if (sltype == SL_AR) {
        double sum = 0;
        for (int i = start; i < start + lookback; i++) {
            double high = iHigh(symbol, timeframe, i);
            double low = iLow(symbol, timeframe, i);
            double range = high - low;
            sum += range;
        }
        sl = price - (sum / lookback) - dev * point;
    }

    else if (sltype == SL_MR) {
        double max = 0;
        for (int i = start; i < start + lookback; i++) {
            double high = iHigh(symbol, timeframe, i);
            double low = iLow(symbol, timeframe, i);
            double range = high - low;
            if (range > max)
                max = range;
        }
        sl = price - max - dev * point;
    }

    else if (sltype == SL_FIXED_POINT) {
        sl = price - dev * point;
    }

    sl = NormalizeDouble(sl, digits);
    return sl;
}

double SellSL(ENUM_SL sltype, int lookback, double price = 0, int dev = 0, int start = 0, string symbol = NULL, ENUM_TIMEFRAMES timeframe = 0) {
    symbol = symbol == NULL ? _Symbol : symbol;
    price = price == 0 ? Bid(symbol) : price;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double sl = 0;

    if (sltype == SL_SWING) {
        int i = iHighest(symbol, timeframe, MODE_HIGH, lookback, start);
        sl = iHigh(symbol, timeframe, i) + dev * point;
    }

    else if (sltype == SL_AR) {
        double sum = 0;
        for (int i = start; i < start + lookback; i++) {
            double high = iHigh(symbol, timeframe, i);
            double low = iLow(symbol, timeframe, i);
            double range = high - low;
            sum += range;
        }
        sl = price + (sum / lookback) + dev * point;
    }

    else if (sltype == SL_MR) {
        double max = 0;
        for (int i = start; i < start + lookback; i++) {
            double high = iHigh(symbol, timeframe, i);
            double low = iLow(symbol, timeframe, i);
            double range = high - low;
            if (range > max)
                max = range;
        }
        sl = price + max + dev * point;
    }

    else if (sltype == SL_FIXED_POINT) {
        sl = price + dev * point;
    }

    sl = NormalizeDouble(sl, digits);
    return sl;
}

double GetATRForGrid(string symbol, int period) {
    int handle = iATR(symbol, PERIOD_CURRENT, period);
    if (handle == INVALID_HANDLE) return 0.0;
    
    double buf[1];
    if (CopyBuffer(handle, 0, 0, 1, buf) < 1) return 0.0;
    
    return buf[0];
}

// --- STRATEGY CORE (Trail, Grid, Equity, BE) ---

void checkForTrail(ulong magic, double stopLevel = 0.5, double gridStopLevel = 0.4, int slippage = 30, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    int minPoints = 1; // dynamic per symbol
    MqlTradeRequest req;
    MqlTradeResult res;

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong pticket = PositionGetTicket(i);
        if (!pticket) continue;
        string psymbol = PositionGetString(POSITION_SYMBOL);
        double ppoint = SymbolInfoDouble(psymbol, SYMBOL_POINT);
        minPoints = MinBrokerPoints(psymbol);
        int pdigits = (int) SymbolInfoInteger(psymbol, SYMBOL_DIGITS);
        ulong pmagic = PositionGetInteger(POSITION_MAGIC);
        double pin = PositionGetDouble(POSITION_PRICE_OPEN);
        double psl = PositionGetDouble(POSITION_SL);
        double ptp = PositionGetDouble(POSITION_TP);
        double pprof = PositionGetDouble(POSITION_PROFIT);
        double pd = StringToDouble(PositionGetString(POSITION_COMMENT));
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
        ENUM_SYMBOL_TRADE_MODE pstm = (ENUM_SYMBOL_TRADE_MODE) SymbolInfoInteger(psymbol, SYMBOL_TRADE_MODE);

        if (pmagic != magic) continue;
        if (pd == 0) continue;
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        ZeroMemory(req);
        ZeroMemory(res);
        req.action = TRADE_ACTION_SLTP;
        req.position = pticket;
        req.symbol = psymbol;
        req.magic = pmagic;
        req.sl = psl;
        req.tp = ptp;

        ulong tickets[];
        int n = positionsTickets(pmagic, tickets, psymbol);
        int k = 0;
        for (int j = 0; j < n; j++) {
            PositionSelectByTicket(tickets[j]);
            if (StringToDouble(PositionGetString(POSITION_COMMENT))) k++;
        }

        if (n == 1 || k > 1) {
            if (stopLevel == 0) continue;

            double sl;
            double cost = MathMax(calcCostByTicket(pticket), 0);
            double brkeven = calcPriceByTicket(pticket, cost);

            if (ptype == POSITION_TYPE_BUY) {
                double h = Bid(psymbol);
                if (h <= pin) continue;
                double d = h - pin;

                sl = MathMax(pin, brkeven) + d - stopLevel * pd;

                sl = NormalizeDouble(sl, pdigits);
                if (sl < pin) continue;
                if (psl != 0 && psl >= sl) continue;
                if (!(Bid(psymbol) - sl >= minPoints * ppoint)) {
                    if (pprof - cost > 0)
                        closeOrder(pticket, slippage, nRetry, mRetry, filling);
                    continue;
                }

                req.sl = sl;
            }

            else if (ptype == POSITION_TYPE_SELL) {
                double l = Ask(psymbol);
                if (l >= pin) continue;
                double d = pin - l;

                sl = MathMin(pin, brkeven) - d + stopLevel * pd;

                sl = NormalizeDouble(sl, pdigits);
                if (sl > pin) continue;
                if (psl != 0 && psl <= sl) continue;
                if (!(sl - Ask(psymbol) >= minPoints * ppoint)) {
                    if (pprof - cost > 0)
                        closeOrder(pticket, slippage, nRetry, mRetry, filling);
                    continue;
                }

                req.sl = sl;
            }

            if (!OrderSend(req, res)) {
                if (res.retcode == TRADE_RETCODE_INVALID_STOPS && pprof - cost > 0)
                    if (closeOrder(pticket, slippage, nRetry, mRetry, filling)) continue;
                int err = GetLastError();
                if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
            }
        }

        else {
            if (gridStopLevel == 0) continue;

            double sl;
            double cost = MathMax(calcCost(pmagic, psymbol), 0);
            double brkeven = calcPrice(pmagic, cost, 0, 0, psymbol);
            double profit = getProfit(pmagic, psymbol);

            for (int j = 0; j < n; j++) {
                PositionSelectByTicket(tickets[j]);
                if (ptype == POSITION_TYPE_BUY && PositionGetDouble(POSITION_TP) < ptp)
                    ptp = PositionGetDouble(POSITION_TP);
                if (ptype == POSITION_TYPE_SELL && PositionGetDouble(POSITION_TP) > ptp)
                    ptp = PositionGetDouble(POSITION_TP);
            }

            double target_prof = calcProfit(pmagic, ptp, psymbol);
            double per_target = calcPrice(pmagic, gridStopLevel * target_prof, 0, 0, psymbol);

            if (ptype == POSITION_TYPE_BUY) {
                double h = Bid(psymbol);
                if (h <= per_target) continue;
                double d = h - per_target;

                sl = brkeven + d;
                sl = NormalizeDouble(sl, pdigits);
                if (psl != 0 && psl >= sl) continue;

                if (!(Bid(psymbol) - sl >= minPoints * ppoint)) {
                    if (profit - cost > 0) {
                        closeOrders(ptype, pmagic, slippage, psymbol, nRetry, mRetry, filling);
                        Sleep(2000);
                    }
                    continue;
                }

                req.sl = sl;
            }

            else if (ptype == POSITION_TYPE_SELL) {
                double l = Ask(psymbol);
                if (l >= per_target) continue;
                double d = per_target - l;

                sl = brkeven - d;
                sl = NormalizeDouble(sl, pdigits);
                if (psl != 0 && psl <= sl) continue;

                if (!(sl - Ask(psymbol) >= minPoints * ppoint)) {
                    if (profit - cost > 0) {
                        closeOrders(ptype, pmagic, slippage, psymbol, nRetry, mRetry, filling);
                        Sleep(2000);
                    }
                    continue;
                }

                req.sl = sl;
            }

            if (!OrderSend(req, res)) {
                if (res.retcode == TRADE_RETCODE_INVALID_STOPS && profit - cost > 0) {
                    closeOrders(ptype, pmagic, slippage, psymbol, nRetry, mRetry, filling);
                    Sleep(2000);
                    continue;
                }
                int err = GetLastError();
                if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s (grid) error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
                continue;
            }

            for (int j = 0; j < n; j++) {
                if (tickets[j] == pticket) continue;
                ZeroMemory(res);
                req.position = tickets[j];
                if (!OrderSendAsync(req, res)) {
                    int err = GetLastError();
                    if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s (grid) error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
                }
            }

        }
    }
}

void checkForGrid(ulong magic, double risk, double volCoef, int maxLvl, int slippage = 30, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT, int sideFilter = -1, bool dynamicSpacing = false, int atrPeriod = 14, double atrMult = 1.0, double minProfit = 0.0, bool minProfitPct = false) {
    int minPoints = 1; // dynamic per symbol
    MqlTradeRequest req;
    MqlTradeResult res;

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
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
        if (pd == 0) continue;
        if (pstm == SYMBOL_TRADE_MODE_DISABLED || pstm == SYMBOL_TRADE_MODE_CLOSEONLY) continue;

        // Filtre de côté: -1=both (aucun filtre), 0=BUY only, 1=SELL only
        if (sideFilter == 0 && ptype != POSITION_TYPE_BUY)  continue;
        if (sideFilter == 1 && ptype != POSITION_TYPE_SELL) continue;

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
        if (dynamicSpacing) {
            double currentATR = GetATRForGrid(psymbol, atrPeriod);
            if (currentATR > 0) spacing = currentATR * atrMult;
        }
        spacing = MathMax(spacing, minPoints * ppoint);
        // --------------------------------------------

        double lvl, tp;
        double vol = calcVolume(lastVol * volCoef, psymbol);
        double loss = pvol * ptv * (pd / ppoint);
        double target_prof = loss;
        double cost = calcCost(pmagic, psymbol);
        if (cost > 0) target_prof += cost;

        // --- LOGIQUE CIBLE PROFIT (v1.32) ---
        double extra_prof = minProfit;
        if (minProfitPct) {
            extra_prof = AccountInfoDouble(ACCOUNT_BALANCE) * (minProfit / 100.0);
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
            if (MathAbs(lastPrice - Ask(psymbol)) < spacing)
                continue; 

            double low = Bid(psymbol);
            lvl = lastPrice - spacing; 

            if (low > lvl) continue;
            
            tp = calcPrice(pmagic, target_prof, Ask(psymbol), vol, psymbol);

            if (!(tp - Bid(psymbol) >= minPoints * ppoint))
                tp = Bid(psymbol) + minPoints * ppoint;

            if (!order(ORDER_TYPE_BUY, pmagic, Ask(psymbol), psl, tp, risk, false, 0, slippage, false, false, "", psymbol, vol, nRetry, mRetry, filling)) continue;

            req.tp = tp;
        }

        else if (ptype == POSITION_TYPE_SELL) {
            // Logique Dynamique
            if (MathAbs(lastPrice - Bid(psymbol)) < spacing)
                continue; 

            double high = Ask(psymbol);
            lvl = lastPrice + spacing;

            if (high < lvl) continue;
            
            tp = calcPrice(pmagic, target_prof, Bid(psymbol), vol, psymbol);

            if (!(Ask(psymbol) - tp >= minPoints * ppoint))
                tp = Ask(psymbol) - minPoints * ppoint;

            if (!order(ORDER_TYPE_SELL, pmagic, Bid(psymbol), psl, tp, risk, false, 0, slippage, false, false, "", psymbol, vol, nRetry, mRetry, filling)) continue;

            req.tp = tp;
        }

        for (int j = 0; j < n; j++) {
            PositionSelectByTicket(tickets[j]);
            ZeroMemory(res);
            req.position = tickets[j];
            if (PositionGetDouble(POSITION_TP) == req.tp && PositionGetDouble(POSITION_SL) == req.sl) continue;
            if (!OrderSendAsync(req, res)) {
                int err = GetLastError();
                if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral(StringFormat("%s error #%d : %s", __FUNCTION__, err, ErrorDescription(err)));
            }
        }

    }
}

void checkForEquity(ulong magic, double limit, int slippage = 30, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    if (limit == 0) return;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
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

    closeOrders(POSITION_TYPE_BUY, magic, slippage, max_symbol, nRetry, mRetry, filling);
    closeOrders(POSITION_TYPE_SELL, magic, slippage, max_symbol, nRetry, mRetry, filling);
}

void checkForBE(ulong magic, double triggerR, double spreadMult, int slDevFallbackPts, bool onNewBar, int slippage = 30, int nRetry = 5, int mRetry = 2000, ENUM_FILLING filling = FILLING_DEFAULT) {
    if (triggerR <= 0) return;
    string symbol = _Symbol;
    const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    const int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    const int minPts = MinBrokerPoints(symbol);
    const int spreadPts = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    
    // Modification RAW : Le calcul basé sur le spread seul est dangereux sur RAW (spread~0)
    // On calcule l'offset demandé par l'utilisateur, mais on force un minimum de sécurité (10pts = 1 pip)
    const int offsetPts = (int)MathMax(10.0, MathRound(spreadPts * spreadMult));

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

        double riskPts;
        if (sl > 0) {
            riskPts = (isBuy ? (op - sl)/point : (sl - op)/point);
        } else {
            // Fallback si aucun SL initial
            riskPts = (double)MathMax(slDevFallbackPts, 1);
        }
        if (riskPts <= 0) continue;

        const double gainPts = (isBuy ? (cur - op)/point : (op - cur)/point);
        if (gainPts < triggerR * riskPts) continue;

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
            if (isBuy && sl >= bePrice) continue;
            if (!isBuy && sl <= bePrice) continue;
        }

        // Respect FREEZE/STOPS
        if (isBuy) {
            if (!(cur - bePrice >= minPts * point)) continue;
        } else {
            if (!(bePrice - cur >= minPts * point)) continue;
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
        if(!OrderSend(req, res)){
            int err = GetLastError();
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) CAuroraLogger::WarnOrders(StringFormat("[BE] ticket=%I64u error #%d : %s", ticket, err, ErrorDescription(err)));
            continue;
        }
        if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) CAuroraLogger::InfoStrategy(StringFormat("[BE] ticket=%I64u -> SL=%.0fpts @ %.5f (R=%.2f, cost covered, offset=%dpts)", ticket, (isBuy?(bePrice-op):(op-bePrice))/point, bePrice, triggerR, offsetPts));
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
    int nRetry;
    int mRetry;
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
    bool   gridMinProfitPct; // true = % du solde, false = montant fixe en devise

    double equityDrawdownLimit;
    ENUM_FILLING filling;
    ENUM_RISK riskMode;

    GerEA() {
        risk = 0.01;
        martingaleRisk = 0.04;
        martingale = false;
        slippage = 30;
        reverse = false;
        nRetry = 5;
        mRetry = 2000;
        trailingStopLevel = 0.5;
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
        gridMinProfitPct = false;

        equityDrawdownLimit = 0;
        filling = FILLING_DEFAULT;
        riskMode = RISK_DEFAULT;
    }

    void Init(int magicSeed = 1) {
        magicNumber = calcMagic(magicSeed);
    }

    bool BuyOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
        if (!reverse)
            return order(ORDER_TYPE_BUY, magicNumber, Ask(name), sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry, filling, riskMode);
        return order(ORDER_TYPE_SELL, magicNumber, Bid(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry, filling, riskMode);
    }

    bool SellOpen(double sl, double tp, bool isl = false, bool itp = false, string comment = "", string name = NULL, double vol = 0) {
        if (!reverse)
            return order(ORDER_TYPE_SELL, magicNumber, Bid(name), sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry, filling, riskMode);
        return order(ORDER_TYPE_BUY, magicNumber, Ask(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry, filling, riskMode);
    }

    bool BuyOpen(double in, double sl, double tp, bool isl = false, bool itp = false, string name = NULL, double vol = 0, string comment = "", bool set_comment = true) {
        if (grid) isl = true;
        if (name == NULL) name = _Symbol;
        int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
        double d = MathAbs(in - sl);
        if ((comment == "" || comment == NULL) && (set_comment || grid))
            comment = DoubleToString(d, digits);
        if (!reverse)
            return order(ORDER_TYPE_BUY, magicNumber, in, sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry, filling, riskMode);
        return order(ORDER_TYPE_SELL, magicNumber, Bid(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry, filling, riskMode);
    }

    bool SellOpen(double in, double sl, double tp, bool isl = false, bool itp = false, string name = NULL, double vol = 0, string comment = "", bool set_comment = true) {
        if (grid) isl = true;
        if (name == NULL) name = _Symbol;
        int digits = (int) SymbolInfoInteger(name, SYMBOL_DIGITS);
        double d = MathAbs(in - sl);
        if ((comment == "" || comment == NULL) && (set_comment || grid))
            comment = DoubleToString(d, digits);
        if (!reverse)
            return order(ORDER_TYPE_SELL, magicNumber, in, sl, tp, risk, martingale, martingaleRisk, slippage, isl, itp, comment, name, vol, nRetry, mRetry, filling, riskMode);
        return order(ORDER_TYPE_BUY, magicNumber, Ask(name), tp, sl, risk, martingale, martingaleRisk, slippage, itp, isl, comment, name, vol, nRetry, mRetry, filling, riskMode);
    }

    bool PendingOrder(ENUM_ORDER_TYPE ot, double in, double sl = 0, double tp = 0, double vol = 0, double stoplimit = 0, datetime expiration = 0, ENUM_ORDER_TYPE_TIME timeType = 0, string symbol = NULL, string comment = "") {
        return pendingOrder(ot, magicNumber, in, sl, tp, vol, stoplimit, expiration, timeType, symbol, comment, filling, riskMode, risk, slippage, nRetry, mRetry);
    }

    void BuyClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, nRetry, mRetry, filling);
        else
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, nRetry, mRetry, filling);
    }

    void SellClose(string name = NULL) {
        if (!reverse)
            closeOrders(POSITION_TYPE_SELL, magicNumber, slippage, name, nRetry, mRetry, filling);
        else
            closeOrders(POSITION_TYPE_BUY, magicNumber, slippage, name, nRetry, mRetry, filling);
    }

    bool PosClose(ulong ticket) {
        return closeOrder(ticket, slippage, nRetry, mRetry, filling);
    }

    bool PendingOrderClose(ulong ticket) {
        return closePendingOrder(ticket, nRetry, mRetry);
    }

    void PendingOrdersClose(ENUM_ORDER_TYPE ot, string name = NULL) {
        closePendingOrders(ot, magicNumber, name, nRetry, mRetry);
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

    void CheckForTrail() {
        checkForTrail(magicNumber, trailingStopLevel, gridTrailingStopLevel, slippage, nRetry, mRetry, filling);
    }

    void CheckForGrid() {
        checkForGrid(magicNumber, risk, gridVolMult, gridMaxLvl, slippage, nRetry, mRetry, filling, -1, gridDynamic, gridAtrPeriod, gridAtrMult, gridMinProfit, gridMinProfitPct);
    }

    // Variante avec filtre de côté: -1=both, 0=BUY only, 1=SELL only
    void CheckForGridSide(const int sideFilter) {
        checkForGrid(magicNumber, risk, gridVolMult, gridMaxLvl, slippage, nRetry, mRetry, filling, sideFilter, gridDynamic, gridAtrPeriod, gridAtrMult, gridMinProfit, gridMinProfitPct);
    }

    void CheckForEquity() {
        checkForEquity(magicNumber, equityDrawdownLimit, slippage, nRetry, mRetry, filling);
    }

    void CheckForBE(const double triggerR, const double spreadMult, const int slDevFallback, const bool onNewBar) {
        checkForBE(magicNumber, triggerR, spreadMult, slDevFallback, onNewBar, slippage, nRetry, mRetry, filling);
    }
};