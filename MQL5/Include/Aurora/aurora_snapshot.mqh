//+------------------------------------------------------------------+
//|                                                  Aurora Snapshot |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_SNAPSHOT_MQH__
#define __AURORA_SNAPSHOT_MQH__

#include <Aurora/aurora_types.mqh>

//+------------------------------------------------------------------+
//| Position Data Structure Optimized for Speed                      |
//+------------------------------------------------------------------+
struct SAuroraPos
{
   ulong    ticket;
   ulong    magic;
   string   symbol;
   ENUM_POSITION_TYPE type;
   double   volume;
   double   price_open;
   double   sl;
   double   tp;
   double   profit;      // Defines profit + swap + commission
   double   swap;
   double   commission;
   datetime time_open;
   string   comment;
   long     identifier;  // Position ID for history correlation
};

//+------------------------------------------------------------------+
//| Class CAuroraSnapshot                                            |
//| "Speed of Light" - Single Pass Position Aggregator               |
//+------------------------------------------------------------------+
class CAuroraSnapshot
{
private:
   SAuroraPos m_all[];
   int        m_indices_buy[];
   int        m_indices_sell[];
   int        m_count_all;
   int        m_count_buy;
   int        m_count_sell;
   
   // Summary Metrics (calculated on the fly during snapshot)
   double     m_total_profit;
   double     m_total_volume;
   double     m_net_exposure; // Buys - Sells
   
   // --- OPTIMIZATION CACHE ---
   struct SCacheItem {
       ulong ticket;
       double commission;
   };
   SCacheItem m_cache[];
   ulong      m_last_refresh_time; // ms
   
   // Helper: Binary Search (O(log N))
   int FindInCache(ulong ticket) {
       int low = 0;
       int high = ArraySize(m_cache) - 1;
       while(low <= high) {
           int mid = low + (high - low) / 2;
           if(m_cache[mid].ticket == ticket) return mid;
           if(m_cache[mid].ticket < ticket) low = mid + 1;
           else high = mid - 1;
       }
       return -1;
   }
   
   void SetCache(ulong ticket, double comm) {
       int idx = FindInCache(ticket);
       if(idx >= 0) {
           m_cache[idx].commission = comm;
       } else {
           int s = ArraySize(m_cache);
           ArrayResize(m_cache, s+1);
           m_cache[s].ticket = ticket;
           m_cache[s].commission = comm;
           
           // Keep it sorted (Binary Insertion or Simple Sort)
           // For N < 100, simple sort is fast. For institutional standard, we sort.
           // Since MQL5 ArraySort doesn't work on structs, we do a manual shift insertion.
           for (int i = s; i > 0 && m_cache[i-1].ticket > m_cache[i].ticket; i--) {
               SCacheItem temp = m_cache[i];
               m_cache[i] = m_cache[i-1];
               m_cache[i-1] = temp;
           }
       }
   }
   
public:
   CAuroraSnapshot();
   ~CAuroraSnapshot();

   // [OPTIMIZATION-PART-2] Periodic Refresh & Smart Invalidations
   void Invalidate() {
        m_last_refresh_time = 0; // Force refresh on next Update
    }
   
   void SetCommission(ulong ticket, double comm) {
        if (ticket == 0) return;
        SetCache(ticket, comm);
   }
   
   void AddCommission(ulong ticket, double delta) {
        if (ticket == 0) return;
        int idx = FindInCache(ticket);
        if (idx >= 0) m_cache[idx].commission += delta;
        else SetCache(ticket, delta);
   }

   // Core Operation: Refreshes state. Call ONCE at start of OnTick.
   void Update(ulong magicFilter, string symbolFilter);
   
   // Accessors
   int Total() const { return m_count_all; }
   int CountBuys() const { return m_count_buy; }
   int CountSells() const { return m_count_sell; }
   
   // Direct Access - Return by VALUE to avoid reference strictness issues
   SAuroraPos Get(int index) const { return m_all[index]; }
   
   // Side Access
   SAuroraPos GetBuy(int i) const { return m_all[m_indices_buy[i]]; }
   SAuroraPos GetSell(int i) const { return m_all[m_indices_sell[i]]; }
   
   // Aggregates
   double GetTotalProfit() const { return m_total_profit; }
   double GetTotalVolume() const { return m_total_volume; }
   double GetNetExposure() const { return m_net_exposure; }
   
   // Helpers
   bool HasOpenPositions() const { return m_count_all > 0; }
   
   // Group Query optimizations
   double GetProfit(ulong magic, string symbol) const {
       double sum = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) {
               sum += m_all[i].profit;
           }
       }
       return sum;
   }
   
   // Returns count and fills indices array for direct access
   int GetGroupIndices(ulong magic, string symbol, int &indices[]) const {
       int count = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) count++;
       }
       ArrayResize(indices, count);
       if(count == 0) return 0;
       
       int c = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) {
               indices[c++] = i;
           }
       }
       return count;
   }

   // Returns count and fills tickets array
   int GetTickets(ulong magic, string symbol, ulong &tickets[]) const {
       int count = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) count++;
       }
       ArrayResize(tickets, count);
       if(count == 0) return 0;
       
       int c = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) {
               tickets[c++] = m_all[i].ticket;
           }
       }
       return count;
   }
   
   // Calculates Total Cost (Swap + Commission) as positive magnitude
   double CalcCost(ulong magic, string symbol) const {
       double sum = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) {
               sum += MathAbs(m_all[i].swap + m_all[i].commission);
           }
       }
       return sum;
   }
   
   // Returns volume for symbol
   double GetVolume(ulong magic, string symbol) const {
       double sum = 0;
       for(int i=0; i<m_count_all; i++) {
           if(m_all[i].magic == magic && m_all[i].symbol == symbol) {
               sum += m_all[i].volume;
           }
       }
       return sum;
   }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAuroraSnapshot::CAuroraSnapshot() 
   : m_count_all(0), m_count_buy(0), m_count_sell(0),
     m_total_profit(0.0), m_total_volume(0.0), m_net_exposure(0.0),
     m_last_refresh_time(0)
{
   ArrayResize(m_all, 50);
   ArrayResize(m_indices_buy, 50);
   ArrayResize(m_indices_sell, 50);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAuroraSnapshot::~CAuroraSnapshot()
{
}

//+------------------------------------------------------------------+
//| Update                                                           |
//+------------------------------------------------------------------+
void CAuroraSnapshot::Update(ulong magicFilter, string symbolFilter)
{
   m_count_all = 0;
   m_count_buy = 0;
   m_count_sell = 0;
   m_total_profit = 0.0;
   // Ensure all metrics reset
   m_total_volume = 0.0;
   m_net_exposure = 0.0;
   
   // [OPTIMIZATION] Periodic Refresh (10s)
   ulong now = GetTickCount();
   if(now - m_last_refresh_time > 10000) m_last_refresh_time = now;
   m_total_volume = 0.0;
   m_net_exposure = 0.0;
   
   int total = PositionsTotal();
   
   if(ArraySize(m_all) < total) {
       int newSize = total + 20; 
       ArrayResize(m_all, newSize);
       ArrayResize(m_indices_buy, newSize);
       ArrayResize(m_indices_sell, newSize);
   }
   
   for(int i=0; i<total; i++) {
       ulong t = PositionGetTicket(i);
       
       if(PositionGetInteger(POSITION_MAGIC) != magicFilter) continue;
       string sym = PositionGetString(POSITION_SYMBOL);
       if(symbolFilter != NULL && sym != symbolFilter) continue;
       
       int idx = m_count_all;
       m_all[idx].ticket = t;
       m_all[idx].magic = magicFilter;
       m_all[idx].symbol = sym; 
       
       ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
       m_all[idx].type = type;
       
       m_all[idx].volume = PositionGetDouble(POSITION_VOLUME);
       m_all[idx].price_open = PositionGetDouble(POSITION_PRICE_OPEN);
       m_all[idx].sl = PositionGetDouble(POSITION_SL);
       m_all[idx].tp = PositionGetDouble(POSITION_TP);
       m_all[idx].swap = PositionGetDouble(POSITION_SWAP);
       long posId = PositionGetInteger(POSITION_IDENTIFIER);
       
       // --- COMMISSION CACHE (OnTradeTransaction incremental) ---
       double comm = 0.0;
       int cIdx = FindInCache(t);
       if (cIdx != -1) comm = m_cache[cIdx].commission;
       m_all[idx].commission = comm;
       
       m_all[idx].profit = PositionGetDouble(POSITION_PROFIT) + m_all[idx].swap + m_all[idx].commission; 
       m_all[idx].time_open = (datetime)PositionGetInteger(POSITION_TIME);
       m_all[idx].comment = PositionGetString(POSITION_COMMENT);
       m_all[idx].identifier = posId;
       
       if(type == POSITION_TYPE_BUY) {
           m_indices_buy[m_count_buy++] = idx;
           m_net_exposure += m_all[idx].volume;
       } else if(type == POSITION_TYPE_SELL) {
           m_indices_sell[m_count_sell++] = idx;
           m_net_exposure -= m_all[idx].volume;
       }
       
       m_total_profit += m_all[idx].profit;
       m_total_volume += m_all[idx].volume;
       
       m_count_all++;
   }
}

#endif // __AURORA_SNAPSHOT_MQH__
