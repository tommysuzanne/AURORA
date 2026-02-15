//+------------------------------------------------------------------+
//|                                                Aurora Simulation |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#ifndef __AURORA_SIMULATION_MQH__
#define __AURORA_SIMULATION_MQH__

#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict
#include <Aurora/aurora_constants.mqh>
#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_time.mqh>
#include <Aurora/aurora_trade_contract.mqh>

struct SVirtualPending {
    ulong ticket; // Fake ticket
    ENUM_ORDER_TYPE type;
    double price;
    double sl;
    double tp;
    double vol;
    string symbol;
    string comment;
    ulong magic;
    datetime expiration;
    bool active;
};

class CAuroraSimulation {
private:
    SSimulationInputs m_inputs;
    bool m_init;
    SVirtualPending m_orders[];
    ulong m_ticketCounter;

public:
    CAuroraSimulation() {
        m_init = false;
        m_ticketCounter = VIRTUAL_TICKET_START;
    }

    void Init(const SSimulationInputs &inp) {
        m_inputs = inp;
        m_init = inp.enable && MQLInfoInteger(MQL_TESTER); // Only active in Tester
        if(m_init) {
             m_ticketCounter = inp.start_ticket;
             CAuroraLogger::InfoSim(StringFormat("Reality Check ENABLED. TickStart=%I64u, Latency=%dms, Slippage=%dpts", m_ticketCounter, m_inputs.latency_ms, m_inputs.slippage_add_pts));
        }
    }

    bool IsEnabled() { return m_init; }
    
    // --- 1. SIMULATE SPREAD & REJECTION (Market) ---
    bool CheckExecution(string symbol) {
        if (!m_init) return true;
        
        // A. Spread Check (Padding)
        double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
        if (spread < m_inputs.spread_pad_pts) {
             // If real spread is super tight (0), but we want to simulate 1.0 pip min,
             // this function just checks feasibility? 
             // Ideally we should inflate spread in the signal logic, effectively reducing probability.
             // But here we block execution if spread (inflated) would technically hit SL immediately? 
             // Simplified: Just Random Rejection.
        }
        
        // B. Rejection Probability (Packet Loss / Off Quotes)
        if (m_inputs.rejection_prob > 0) {
            int randVal = MathRand() % 100;
            if (randVal < m_inputs.rejection_prob) {
                CAuroraLogger::WarnSim("Order REJECTED (Simulated Off Quotes)");
                return false;
            }
        }
        
        return true;
    }

    // --- 2. VIRTUAL PENDING ORDERS (The Core) ---
    // Instead of sending a real Pending Order to broker (which Tester fills perfectly),
    // we store it here and fill it ourselves with SLIPPAGE.
    bool PlaceVirtualPending(ENUM_ORDER_TYPE type, double price, double sl, double tp, double vol, ulong magic, string symbol, string comment, datetime expiration) {
        if (!m_init) return false;
        
        int s = ArraySize(m_orders);
        ArrayResize(m_orders, s + 1);
        
        m_orders[s].ticket = m_ticketCounter++;
        m_orders[s].type = type;
        m_orders[s].price = price;
        m_orders[s].sl = sl;
        m_orders[s].tp = tp;
        m_orders[s].vol = vol;
        m_orders[s].symbol = symbol;
        m_orders[s].comment = comment + " [SIM]";
        m_orders[s].magic = magic;
        m_orders[s].expiration = expiration;
        m_orders[s].active = true;
        
        CAuroraLogger::InfoSim(StringFormat("Virtual Pending Placed #%I64d %s @ %.5f", m_orders[s].ticket, EnumToString(type), price));
        return true;
    }

    bool CancelVirtualOrder(ulong ticket) {
        if (!m_init) return false;
        int total = ArraySize(m_orders);
        for(int i=0; i<total; i++) {
            if (m_orders[i].active && m_orders[i].ticket == ticket) {
                m_orders[i].active = false;
                CAuroraLogger::InfoSim(StringFormat("Virtual Order Cancelled #%I64d", ticket));
                return true;
            }
        }
        return false;
    }

    void CancelAllVirtualOrders(ulong magic, string symbol = NULL) {
        if (!m_init) return;
        int total = ArraySize(m_orders);
        for(int i=0; i<total; i++) {
            if (m_orders[i].active && m_orders[i].magic == magic) {
                if (symbol == NULL || m_orders[i].symbol == symbol) {
                    m_orders[i].active = false;
                    CAuroraLogger::InfoSim(StringFormat("Virtual Order Batch Cancelled #%I64d", m_orders[i].ticket));
                }
            }
        }
    }

    bool ModifyVirtualOrder(ulong ticket, double price, double sl, double tp) {
        if (!m_init) return false;
        int total = ArraySize(m_orders);
        for(int i=0; i<total; i++) {
            if (m_orders[i].active && m_orders[i].ticket == ticket) {
                m_orders[i].price = price;
                m_orders[i].sl = sl;
                m_orders[i].tp = tp;
                CAuroraLogger::InfoSim(StringFormat("Virtual Order Modified #%I64d: Price=%.5f, SL=%.5f, TP=%.5f", ticket, price, sl, tp));
                return true;
            }
        }
        return false;
    }

    ulong GetVirtualTicket(ulong magic, ENUM_ORDER_TYPE type, string symbol = NULL) {
        if (!m_init) return 0;
        int total = ArraySize(m_orders);
        for(int i=0; i<total; i++) {
            if (m_orders[i].active && m_orders[i].magic == magic && (symbol == NULL || m_orders[i].symbol == symbol) && m_orders[i].type == type) {
                return m_orders[i].ticket;
            }
        }
        return 0;
    }

    double GetVirtualOrderPrice(ulong ticket) {
        if (!m_init) return 0;
        int total = ArraySize(m_orders);
        for(int i=0; i<total; i++) {
            if (m_orders[i].active && m_orders[i].ticket == ticket) {
                return m_orders[i].price;
            }
        }
        return 0;
    }

    // --- 3. TICK PROCESSING (Simulate Trigger + Latency + Slippage) ---
    void OnTick() {
        if (!m_init) return;
        
        int total = ArraySize(m_orders);
        for(int i=total-1; i>=0; i--) {
            if (!m_orders[i].active) continue;
            
            // Check Expiration
            if (m_orders[i].expiration > 0 && AuroraClock::Now() > m_orders[i].expiration) {
                m_orders[i].active = false; 
                CAuroraLogger::InfoSim(StringFormat("Virtual Order Expired #%I64d", m_orders[i].ticket));
                continue;
            }

            // Check Trigger
            bool triggered = false;
            double currentBid = SymbolInfoDouble(m_orders[i].symbol, SYMBOL_BID);
            double point = SymbolInfoDouble(m_orders[i].symbol, SYMBOL_POINT);
            
            // SIMULATE SPREAD WIDENING (Padding)
            // We assume widening affects Ask (Standard)
            double realSpread = (double)SymbolInfoInteger(m_orders[i].symbol, SYMBOL_SPREAD);
            double simSpread = realSpread + m_inputs.spread_pad_pts;
            double simAsk = currentBid + (simSpread * point);
            
            if (m_orders[i].type == ORDER_TYPE_BUY_STOP) {
                // Buy Stop triggers on Ask
                if (simAsk >= m_orders[i].price) triggered = true;
            }
            else if (m_orders[i].type == ORDER_TYPE_SELL_STOP) {
                // Sell Stop triggers on Bid
                if (currentBid <= m_orders[i].price) triggered = true;
            }
            
            if (triggered) {
                // 0. REJECTION CHECK (Simulate Off Quotes on Trigger)
                if (m_inputs.rejection_prob > 0) {
                    if ((MathRand() % 100) < m_inputs.rejection_prob) {
                         CAuroraLogger::WarnSim(StringFormat("Virtual Order Trigger REJECTED (Off Quotes) #%I64d", m_orders[i].ticket));
                         // Should we kill it or keep it? Real broker might cancel or keep pending. 
                         // Usually Off Quotes on Fill = Rejection. Pending stays? Or cancelled?
                         // In MT5, if Stop Limit triggers and fails, usually order is deleted?
                         // Let's assume rejection = delete to be harsh/conservative.
                         m_orders[i].active = false;
                         continue;
                    }
                }

                // 1. LATENCY
                if (m_inputs.latency_ms > 0) {
                   Sleep(m_inputs.latency_ms);
                   // Refresh prices after sleep
                   currentBid = SymbolInfoDouble(m_orders[i].symbol, SYMBOL_BID);
                   // Update SimAsk with potentially new real spread
                   realSpread = (double)SymbolInfoInteger(m_orders[i].symbol, SYMBOL_SPREAD);
                   simSpread = realSpread + m_inputs.spread_pad_pts;
                   simAsk = currentBid + (simSpread * point);
                }
                
                // 2. SLIPPAGE (The Killer)
                // Force entry at worse price
                double fillPrice = 0;
                if (m_orders[i].type == ORDER_TYPE_BUY_STOP || m_orders[i].type == ORDER_TYPE_BUY_LIMIT) {
                    // Buy filled at Ask + Slippage
                    fillPrice = simAsk + (m_inputs.slippage_add_pts * point); 
                } else {
                    // Sell filled at Bid - Slippage
                    fillPrice = currentBid - (m_inputs.slippage_add_pts * point);
                }
                
                // 3. EXECUTE PENALTY ORDER (Stop at bad price)
                // We send a Stop Order at the 'Slipped' price to force the backtester to fill us there (or worse).
                // This effectively simulates the price gap. If price never reaches this bad price (unlikely in heavy move), we miss the trade.
                bool res = order(
                    (m_orders[i].type == ORDER_TYPE_BUY_STOP || m_orders[i].type == ORDER_TYPE_BUY_LIMIT) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP,
                    m_orders[i].magic,
                    fillPrice,
                    m_orders[i].sl,
                    m_orders[i].tp,
                    0, 1000, 
                    false, false, 
                    m_orders[i].comment + " [SLIP]", // Mark as slipped
                    m_orders[i].symbol,
                    m_orders[i].vol,
                    FILLING_DEFAULT,
                    RISK_FIXED_VOL,
                    0, -1, -1
                );
                
                if (res) {
                    CAuroraLogger::InfoSim(StringFormat("Virtual Order FILLED #%I64d at %.5f (Slippage: %d pts)", m_orders[i].ticket, fillPrice, m_inputs.slippage_add_pts));
                } else {
                    CAuroraLogger::ErrorSim(StringFormat("Virtual Order FILL FAILED #%I64d", m_orders[i].ticket));
                }
                
                m_orders[i].active = false;
            }
        }
    }
    
    // Helper to count virtual orders for logic consistency (MaxOrders check)
    int CountVirtualOrders(ulong magic) {
        if (!m_init) return 0;
        int c = 0;
        int total = ArraySize(m_orders);
        for(int i=0; i<total; i++) if(m_orders[i].active && m_orders[i].magic == magic) c++;
        return c;
    }
    
    // Apply Commission Simulation (Logic Hook)
    // To be called by logic that calculates Net Profit
    double ApplyCommission(double profit, double volume) {
        if (!m_init) return profit;
        return profit - (volume * m_inputs.comm_per_lot);
    }
    
    double GetSpreadPadding() {
        return (m_init ? m_inputs.spread_pad_pts : 0);
    }
};

// Global Instance
CAuroraSimulation g_simulation;

#endif // __AURORA_SIMULATION_MQH__
