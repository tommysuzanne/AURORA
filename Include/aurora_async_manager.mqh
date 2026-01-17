//+------------------------------------------------------------------+
//|                                             Aurora Async Manager |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property version   "1.00"
#property strict

#ifndef __AURORA_ASYNC_MANAGER_MQH__
#define __AURORA_ASYNC_MANAGER_MQH__

#include <aurora_logger.mqh>
#include <aurora_error_utils.mqh>

#define MAX_ASYNC_RETRIES 5

#include <aurora_async_structs.mqh>
#include <aurora_state_manager.mqh>

class CAsyncOrderManager {
private:
    SAsyncRequest m_pending[];
    CStateManager m_state; // State Manager Instance

    int FindIndex(uint req_id) {
        int size = ArraySize(m_pending);
        for(int i=0; i<size; i++) {
            if(m_pending[i].request_id == req_id) return i;
        }
        return -1;
    }

    void Remove(int index) {
        int size = ArraySize(m_pending);
        if(index < 0 || index >= size) return;
        
        // Quick swap remove if order doesn't matter, but let's keep it simple
        // Shift remaining
        for(int i=index; i<size-1; i++) {
            m_pending[i] = m_pending[i+1];
        }
        ArrayResize(m_pending, size-1);
        m_state.SaveState(m_pending); // Save after remove
    }

public:
    CAsyncOrderManager() {
        m_state.LoadState(m_pending); // Restore state on init
    }

    // Envoie une requête asynchrone et l'enregistre pour suivi
    bool SendAsync(MqlTradeRequest &request) {
        MqlTradeResult result;
        ZeroMemory(result);
        ResetLastError();

        if(!OrderSendAsync(request, result)) {
            // Echec immédiat (validation locale)
            int err = GetLastError();
            if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Send Fail: %s, Err=%d", EnumToString(request.action), err));
            return false;
        }

        // Succès d'envoi -> Enregistrement pour suivi
        int size = ArraySize(m_pending);
        ArrayResize(m_pending, size+1);
        m_pending[size].request_id = result.request_id;
        m_pending[size].req = request;
        m_pending[size].retries = 0;
        m_pending[size].timestamp = TimeCurrent();
        
        m_state.SaveState(m_pending); // Save after add
        
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
             CAuroraLogger::InfoOrders(StringFormat("[ASYNC-MGR] Sent ReqID=%u Action=%s Vol=%.2f", result.request_id, EnumToString(request.action), request.volume));
        
        return true;
    }

    // À appeler depuis OnTradeTransaction
    void OnTradeTransaction(const MqlTradeTransaction &trans,
                            const MqlTradeRequest &request,
                            const MqlTradeResult &result) {
        
        if(trans.type != TRADE_TRANSACTION_REQUEST) return;

        int index = FindIndex(result.request_id);
        if(index == -1) return; // Pas un ordre géré par nous (ou déjà traité)

        // Analyse du résultat
        if(result.retcode == TRADE_RETCODE_DONE || 
           result.retcode == TRADE_RETCODE_PLACED || 
           result.retcode == TRADE_RETCODE_DONE_PARTIAL) {
            // Succès
            Remove(index);
            return;
        }

        // Echec -> Retry logic
        SAsyncRequest current = m_pending[index];
        
        // Suppression de l'ancienne entrée (car le req_id va changer au resend)
        Remove(index);

        if(current.retries >= MAX_ASYNC_RETRIES) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Max Retries Reached for ReqID=%u. Drop.", current.request_id));
             return;
        }

        // Check fatal errors (where retry is useless)
        // Check fatal errors (where retry is useless)
        // Note: INVALID_PRICE is NOT fatal here anymore, we will refresh it!
        if(result.retcode == TRADE_RETCODE_INVALID_VOLUME ||
           result.retcode == TRADE_RETCODE_NO_MONEY ||
           result.retcode == TRADE_RETCODE_MARKET_CLOSED) { 
             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Fatal Error %u. No Retry.", result.retcode));
             return;
        }

        // Resend
        current.retries++;
        
        // --- FIX ZOMBIE ORDERS: Refresh Price ---
        // Si c'est un ordre au marché (Deal), on doit mettre jour le prix avec le dernier tick
        // sinon on risque TRADE_RETCODE_INVALID_PRICE en boucle sur des marchés volatils (US30).
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
        
        // Resend logic
        MqlTradeResult new_res;
        ZeroMemory(new_res);
        if(OrderSendAsync(current.req, new_res)) {
            int n = ArraySize(m_pending);
            ArrayResize(m_pending, n+1);
            m_pending[n] = current;
            m_pending[n].request_id = new_res.request_id; // Update Request ID
            m_pending[n].timestamp = TimeCurrent();
            
            m_state.SaveState(m_pending); // Save after retry update

             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                CAuroraLogger::WarnOrders(StringFormat("[ASYNC-MGR] Retry #%d for %s (PrevID=%u, NewID=%u) Error=%u", 
                    current.retries, EnumToString(current.req.action), current.request_id, new_res.request_id, result.retcode));
        } else {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) 
                 CAuroraLogger::ErrorOrders(StringFormat("[ASYNC-MGR] Retry Send Failed. Err=%d", GetLastError()));
        }
    }
};

// Global instance declaration (to be defined in main EA)
extern CAsyncOrderManager g_asyncManager;

#endif // __AURORA_ASYNC_MANAGER_MQH__
