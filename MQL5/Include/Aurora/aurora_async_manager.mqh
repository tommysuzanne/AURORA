//+------------------------------------------------------------------+
//|                                             Aurora Async Manager |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_ASYNC_MANAGER_MQH__
#define __AURORA_ASYNC_MANAGER_MQH__

#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_error_utils.mqh>
#include <Aurora/aurora_time.mqh>

#define MAX_ASYNC_RETRIES 5
#define AURORA_ASYNC_PERSIST_TTL_SEC 300
#define AURORA_ASYNC_DEAL_LOCK_TTL_SEC 12
#define AURORA_ASYNC_PERSIST_MAX     50
#define AURORA_ASYNC_PERSIST_INTERVAL_SEC 5

#include <Aurora/aurora_types.mqh>
#include <Aurora/aurora_state_manager.mqh>

class CAsyncOrderManager {
private:
    SAsyncRequest m_pending[];
    CStateManager m_state; // State Manager Instance
    bool m_configured;
    ulong m_magic;
    string m_symbol;
    bool m_state_dirty;
    datetime m_last_persist;

    bool PersistenceEnabled() const
    {
        if(!m_configured) return false;
        if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return false;
        return true;
    }

    void MarkDirty()
    {
        m_state_dirty = true;
    }

    void PersistIfNeeded(const bool force = false)
    {
        if(!m_state_dirty) return;
        if(!PersistenceEnabled()) { m_state_dirty = false; return; }
        if(!force) {
            datetime now = AuroraClock::Now();
            if(m_last_persist > 0 && (now - m_last_persist) < AURORA_ASYNC_PERSIST_INTERVAL_SEC) return;
        }
        if(m_state.SaveState(m_pending)) {
            m_last_persist = AuroraClock::Now();
            m_state_dirty = false;
        }
    }

    void TrimPending()
    {
        datetime now = AuroraClock::Now();
        int size = ArraySize(m_pending);
        if(size == 0) return;
        
        SAsyncRequest filtered[];
        ArrayResize(filtered, size);
        int count = 0;
        
        for(int i=0; i<size; i++) {
            if(m_pending[i].timestamp <= 0) continue;
            const bool isDealLock = (m_pending[i].req.action == TRADE_ACTION_DEAL);
            const int ttlSec = (isDealLock ? AURORA_ASYNC_DEAL_LOCK_TTL_SEC : AURORA_ASYNC_PERSIST_TTL_SEC);
            if((now - m_pending[i].timestamp) > ttlSec) continue;
            filtered[count++] = m_pending[i];
        }
        
        ArrayResize(filtered, count);
        bool changed = (count != size);
        
        if(count > AURORA_ASYNC_PERSIST_MAX) {
            for(int i=0; i<count-1; i++) {
                for(int j=i+1; j<count; j++) {
                    if(filtered[j].timestamp > filtered[i].timestamp) {
                        SAsyncRequest tmp = filtered[i];
                        filtered[i] = filtered[j];
                        filtered[j] = tmp;
                    }
                }
            }
            ArrayResize(filtered, AURORA_ASYNC_PERSIST_MAX);
            changed = true;
        }
        
        ArrayResize(m_pending, ArraySize(filtered));
        for(int k=0; k<ArraySize(filtered); k++) m_pending[k] = filtered[k];
        if(changed) MarkDirty();
    }

    void ReconcileWithBrokerState()
    {
        int size = ArraySize(m_pending);
        if(size == 0) return;

        SAsyncRequest filtered[];
        ArrayResize(filtered, size);
        int count = 0;
        bool changed = false;

        for(int i=0; i<size; i++) {
            const SAsyncRequest item = m_pending[i];
            bool keep = true;

            if((ulong)item.req.magic != m_magic || item.req.symbol != m_symbol) {
                keep = false;
            } else if(item.req.action == TRADE_ACTION_PENDING && item.req.order == 0) {
                // Rebuild from broker state on boot; open pending locks are transient.
                keep = false;
            } else if(item.req.action == TRADE_ACTION_DEAL && item.req.position == 0) {
                // Open DEAL locks are transient and can safely be dropped on startup.
                keep = false;
            } else if(item.req.action == TRADE_ACTION_MODIFY || item.req.action == TRADE_ACTION_REMOVE) {
                if(item.req.order == 0 || !OrderSelect(item.req.order)) keep = false;
            } else if(item.req.action == TRADE_ACTION_SLTP || (item.req.action == TRADE_ACTION_DEAL && item.req.position != 0)) {
                if(item.req.position == 0 || !PositionSelectByTicket(item.req.position)) keep = false;
            }

            if(keep) filtered[count++] = item;
            else changed = true;
        }

        if(!changed) return;

        ArrayResize(m_pending, count);
        for(int j=0; j<count; j++) m_pending[j] = filtered[j];
        MarkDirty();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
            CAuroraLogger::InfoOrders(StringFormat("[ASYNC-MGR] Reconciled restored state with broker: %d -> %d", size, count));
    }

    int FindIndex(uint req_id) {
        int size = ArraySize(m_pending);
        for(int i=0; i<size; i++) {
            if(m_pending[i].request_id == req_id) return i;
        }
        return -1;
    }

    void Remove(int index, bool persist = true) {
        int size = ArraySize(m_pending);
        if(index < 0 || index >= size) return;
        
        // Quick swap remove if order doesn't matter, but let's keep it simple
        // Shift remaining
        for(int i=index; i<size-1; i++) {
            m_pending[i] = m_pending[i+1];
        }
        ArrayResize(m_pending, size-1);
        if(persist) MarkDirty();
    }

    bool IsDuplicateInFlight(const MqlTradeRequest &request) const
    {
        const ulong magic = (ulong)request.magic;
        const string symbol = request.symbol;

        if(request.action == TRADE_ACTION_PENDING) {
            return HasPending(magic, symbol, TRADE_ACTION_PENDING, request.type);
        }

        if(request.action == TRADE_ACTION_MODIFY || request.action == TRADE_ACTION_REMOVE) {
            if(request.order == 0) return false;
            return HasPending(magic, symbol, request.action, (ENUM_ORDER_TYPE)-1, 0, request.order);
        }

        if(request.action == TRADE_ACTION_SLTP) {
            if(request.position == 0) return false;
            return HasPending(magic, symbol, TRADE_ACTION_SLTP, (ENUM_ORDER_TYPE)-1, request.position);
        }

        if(request.action == TRADE_ACTION_DEAL) {
            // Close/partial close path: de-duplicate by position ticket.
            if(request.position != 0) {
                return HasPending(magic, symbol, TRADE_ACTION_DEAL, (ENUM_ORDER_TYPE)-1, request.position);
            }
            // Open path: de-duplicate by side while in-flight.
            return HasPending(magic, symbol, TRADE_ACTION_DEAL, request.type);
        }

        return false;
    }

public:
    CAsyncOrderManager() {
        m_configured = false;
        m_magic = 0;
        m_symbol = "";
        m_state_dirty = false;
        m_last_persist = 0;
    }
    
    void Configure(const ulong magic, const string symbol) {
        if(m_configured && m_magic == magic && m_symbol == symbol) return;
        m_configured = true;
        m_magic = magic;
        m_symbol = symbol;
        m_state.Configure(magic, symbol);
        ArrayResize(m_pending, 0);
        m_state.LoadState(m_pending, AURORA_ASYNC_PERSIST_MAX);
        ReconcileWithBrokerState();
        TrimPending();
        PersistIfNeeded(true);
    }

    // Send async request and register for tracking
    bool SendAsync(MqlTradeRequest &request) {
        if(!m_configured) Configure(request.magic, request.symbol);
        TrimPending();

        if(IsDuplicateInFlight(request)) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
                CAuroraLogger::InfoOrders(StringFormat("[ASYNC-MGR] Skip duplicate in-flight request action=%s order=%I64u type=%s",
                    EnumToString(request.action), request.order, EnumToString(request.type)));
            return true;
        }

        MqlTradeResult result;
        ZeroMemory(result);
        ResetLastError();

        if(!OrderSendAsync(request, result)) {
            // Immediate failure (local validation)
            int err = GetLastError();
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Send Fail: %s, Err=%d", EnumToString(request.action), err));
            return false;
        }

        // Send success -> Register for tracking
        int size = ArraySize(m_pending);
        ArrayResize(m_pending, size+1);
        m_pending[size].request_id = result.request_id;
        m_pending[size].req = request;
        m_pending[size].retries = 0;
        m_pending[size].timestamp = AuroraClock::Now();
        MarkDirty();
        
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
             CAuroraLogger::InfoOrders(StringFormat("[ASYNC-MGR] Sent ReqID=%u Action=%s Vol=%.2f", result.request_id, EnumToString(request.action), request.volume));
        
        return true;
    }

    // Call from OnTradeTransaction
    void OnTradeTransaction(const MqlTradeTransaction &trans,
                            const MqlTradeRequest &request,
                            const MqlTradeResult &result) {
        
        if(trans.type != TRADE_TRANSACTION_REQUEST) return;

        int index = FindIndex(result.request_id);
        if(index == -1) return; // Not an order managed by us (or already processed)

        // Analyze result
        if(result.retcode == TRADE_RETCODE_DONE || 
           result.retcode == TRADE_RETCODE_PLACED || 
           result.retcode == TRADE_RETCODE_DONE_PARTIAL ||
           result.retcode == TRADE_RETCODE_NO_CHANGES) {
            // Success
            Remove(index);
            return;
        }

        // Echec -> Retry logic
        SAsyncRequest current = m_pending[index];
        
        // Remove old entry (car le req_id va changer au resend)
        Remove(index, false);

        if(current.retries >= MAX_ASYNC_RETRIES) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Max Retries Reached for ReqID=%u. Drop. Retcode=%u (%s)", current.request_id, result.retcode, TradeServerReturnCodeDescription(result.retcode)));
             MarkDirty();
             return;
        }

        // Check fatal errors (where retry is useless)
        // STRICT LIMIT IOC HANDLING:
        // If Invalid Price (10015) or Invalid Stops (10016) occurs on an IOC Limit order, 
        // it means the market moved beyond our strict price. 
        // ACTION: ABORT IMMEDIATELY (Do not retry, do not fallback).
        if(result.retcode == TRADE_RETCODE_INVALID_PRICE || result.retcode == TRADE_RETCODE_INVALID_STOPS) {
             if(current.req.type_filling == ORDER_FILLING_IOC) {
                if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                    CAuroraLogger::WarnOrders(StringFormat("[ASYNC-MGR] Strict Limit IOC Rejected (Err=%u %s). ABORTING to prevent slippage.", result.retcode, TradeServerReturnCodeDescription(result.retcode)));
                MarkDirty();
                return;
             }
        }

        bool pending_like_action = (current.req.action == TRADE_ACTION_MODIFY || current.req.action == TRADE_ACTION_PENDING);
        if(result.retcode == TRADE_RETCODE_INVALID_VOLUME ||
           result.retcode == TRADE_RETCODE_INVALID_FILL ||
           ((result.retcode == TRADE_RETCODE_INVALID_EXPIRATION) && !pending_like_action) ||
           result.retcode == TRADE_RETCODE_NO_MONEY ||
           result.retcode == TRADE_RETCODE_MARKET_CLOSED) { 
             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Fatal Error %u (%s). No Retry.", result.retcode, TradeServerReturnCodeDescription(result.retcode)));
             MarkDirty();
             return;
        }

        // Resend
        current.retries++;
        
        // --- FIX ZOMBIE ORDERS: Refresh Price ---
        // If market order (Deal), update price with latest tick
        // otherwise risk TRADE_RETCODE_INVALID_PRICE loop on volatile markets (US30).
        if(current.req.action == TRADE_ACTION_DEAL) {
            MqlTick tick;
            if(SymbolInfoTick(current.req.symbol, tick)) {
                double oldPrice = current.req.price;
                if(current.req.type == ORDER_TYPE_BUY)  current.req.price = tick.ask;
                if(current.req.type == ORDER_TYPE_SELL) current.req.price = tick.bid;
                
                if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                    CAuroraLogger::InfoOrders(StringFormat("[ASYNC-MGR] Refreshing Price for Retry: Old=%.5f -> New=%.5f", oldPrice, current.req.price));
                }
            }
        }

        // Pending retry hardening: adapt expiration/price to current market constraints.
        if ((current.req.action == TRADE_ACTION_MODIFY || current.req.action == TRADE_ACTION_PENDING) &&
            result.retcode == TRADE_RETCODE_INVALID_EXPIRATION) {
            current.req.type_time = ORDER_TIME_GTC;
            current.req.expiration = 0;
        }
        if ((current.req.action == TRADE_ACTION_MODIFY || current.req.action == TRADE_ACTION_PENDING) &&
            (result.retcode == TRADE_RETCODE_INVALID_PRICE || result.retcode == TRADE_RETCODE_INVALID_STOPS)) {
            const string symbol = current.req.symbol;
            MqlTick tick;
            if (SymbolInfoTick(symbol, tick)) {
                int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
                double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
                double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                if (point <= 0.0) point = _Point;
                if (tickSize <= 0.0) tickSize = point;
                int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                int freeze = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int minPoints = (int)MathMax((double)stops, (double)freeze);
                if (minPoints < 1) minPoints = 1;
                double minDist = minPoints * point;

                double price = current.req.price;
                if (current.req.type == ORDER_TYPE_BUY_STOP) {
                    double minAllowed = tick.ask + minDist + tickSize;
                    if (price < minAllowed) price = minAllowed;
                    price = NormalizeDouble(MathCeil((price - 1e-12) / tickSize) * tickSize, digits);
                } else if (current.req.type == ORDER_TYPE_SELL_STOP) {
                    double maxAllowed = tick.bid - minDist - tickSize;
                    if (price > maxAllowed) price = maxAllowed;
                    price = NormalizeDouble(MathFloor((price + 1e-12) / tickSize) * tickSize, digits);
                } else if (current.req.type == ORDER_TYPE_BUY_LIMIT) {
                    double maxAllowed = tick.ask - minDist - tickSize;
                    if (price > maxAllowed) price = maxAllowed;
                    price = NormalizeDouble(MathFloor((price + 1e-12) / tickSize) * tickSize, digits);
                } else if (current.req.type == ORDER_TYPE_SELL_LIMIT) {
                    double minAllowed = tick.bid + minDist + tickSize;
                    if (price < minAllowed) price = minAllowed;
                    price = NormalizeDouble(MathCeil((price - 1e-12) / tickSize) * tickSize, digits);
                } else {
                    price = NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
                }
                current.req.price = price;
            }
        }
        
        // Resend logic
        MqlTradeResult new_res;
        ZeroMemory(new_res);
        if(OrderSendAsync(current.req, new_res)) {
            int n = ArraySize(m_pending);
            ArrayResize(m_pending, n+1);
            m_pending[n] = current;
            m_pending[n].request_id = new_res.request_id; // Update Request ID
            m_pending[n].timestamp = AuroraClock::Now();
            
            MarkDirty();

             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::WarnOrders(StringFormat("[ASYNC-MGR] Retry #%d for %s (PrevID=%u, NewID=%u) Error=%u (%s)", 
                    current.retries, EnumToString(current.req.action), current.request_id, new_res.request_id, result.retcode, TradeServerReturnCodeDescription(result.retcode)));
        } else {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                 CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Retry Send Failed. Err=%d", GetLastError()));
             MarkDirty();
        }
    }

    void FlushState(const bool force = false) {
        PersistIfNeeded(force);
    }

    bool HasPending(ulong magic, const string symbol, const ENUM_TRADE_REQUEST_ACTIONS action, const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)-1, const ulong position = 0, const ulong order = 0) const {
        int size = ArraySize(m_pending);
        for(int i=0; i<size; i++) {
            SAsyncRequest req = m_pending[i];
            if(magic != 0 && req.req.magic != (long)magic) continue;
            if(symbol != NULL && symbol != "" && req.req.symbol != symbol) continue;
            if(action != (ENUM_TRADE_REQUEST_ACTIONS)-1 && req.req.action != action) continue;
            if(type != (ENUM_ORDER_TYPE)-1 && req.req.type != type) continue;
            if(position != 0 && req.req.position != position) continue;
            if(order != 0 && req.req.order != order) continue;
            return true;
        }
        return false;
    }
};

// Global instance declaration (to be defined in main EA)
extern CAsyncOrderManager g_asyncManager;

#endif // __AURORA_ASYNC_MANAGER_MQH__
