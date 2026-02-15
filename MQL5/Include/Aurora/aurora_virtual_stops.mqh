//+------------------------------------------------------------------+
//|                                         aurora_virtual_stops.mqh |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_VIRTUAL_STOPS_MQH__
#define __AURORA_VIRTUAL_STOPS_MQH__

// --- DEPENDENCIES ---
#include <Aurora/aurora_snapshot.mqh> // For SAuroraPos
#include <Aurora/aurora_logger.mqh>

// --- CONSTANTS ---
#define VIRTUAL_STOP_LINE_PREFIX "Aurora_VStop_"

//+------------------------------------------------------------------+
//| CVirtualStopManager                                              |
//| Manages Virtual Stop Loss levels in memory and draws visuals.    |
//| Used for "Exit On Close" logic to hide stops from volatility.    |
//+------------------------------------------------------------------+
class CVirtualStopManager {
private:
    struct SVirtualStop {
        ulong ticket;
        double level;
        bool isBuy;
        long time_setup;
    };
    
    SVirtualStop m_stops[];
    
    // Helper: Find index by ticket
    int FindIndex(ulong ticket) {
        int total = ArraySize(m_stops);
        for(int i=0; i<total; i++) {
            if(m_stops[i].ticket == ticket) return i;
        }
        return -1;
    }
    
    // Helper: Visual Management
    void UpdateVisual(ulong ticket, double level, bool isBuy) {
        // Only draw if we are on a chart
        if(!MQLInfoInteger(MQL_VISUAL_MODE) && !MQLInfoInteger(MQL_TESTER) && !TerminalInfoInteger(TERMINAL_CONNECTED)) return; 
        // Note: In optimization, avoid drawing.
        
        string objName = VIRTUAL_STOP_LINE_PREFIX + IntegerToString(ticket);
        
        // Check if exists
        if(ObjectFind(0, objName) < 0) {
            ObjectCreate(0, objName, OBJ_HLINE, 0, 0, level);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, (isBuy ? clrRed : clrRed)); // Classic SL Color
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true); // Hide from object list to avoid clutter
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Virtual Stop #" + IntegerToString(ticket));
        } else {
            // Move level
            ObjectSetDouble(0, objName, OBJPROP_PRICE, level);
        }
    }
    
    void RemoveVisual(ulong ticket) {
        string objName = VIRTUAL_STOP_LINE_PREFIX + IntegerToString(ticket);
        if(ObjectFind(0, objName) >= 0) ObjectDelete(0, objName);
    }

public:
    CVirtualStopManager() {}
    ~CVirtualStopManager() {
        // Cleanup all objects on destruction
        ObjectsDeleteAll(0, VIRTUAL_STOP_LINE_PREFIX);
    }
    
    // Sync/Register a Virtual Stop
    // If ticket exists, updates level (Ratchet logic should be handled by caller, but we can enforce here too?)
    // Caller (CheckForTrail) knows best. We blindly update here.
    void Set(ulong ticket, double level, bool isBuy) {
        int idx = FindIndex(ticket);
        if(idx == -1) {
            // Add new
            int size = ArraySize(m_stops);
            ArrayResize(m_stops, size + 1);
            m_stops[size].ticket = ticket;
            m_stops[size].level = level;
            m_stops[size].isBuy = isBuy;
            m_stops[size].time_setup = GetTickCount();
            idx = size;
        } else {
            // Update existing
            m_stops[idx].level = level;
        }
        
        UpdateVisual(ticket, level, isBuy);
    }
    
    // Retrieve Virtual Stop Level (Returns 0.0 if not found)
    double Get(ulong ticket) {
        int idx = FindIndex(ticket);
        if(idx != -1) return m_stops[idx].level;
        return 0.0;
    }
    
    // Garbage Collection: Remove stops for tickets not in snapshot
    void Clean(const CAuroraSnapshot &snap) {
        int totalStops = ArraySize(m_stops);
        if(totalStops == 0) return;
        
        // Check active tickets in snapshot (for efficiency, convert snap to fast lookup if huge, but here N < 100 usually)
        for(int i = totalStops - 1; i >= 0; i--) {
            ulong t = m_stops[i].ticket;
            bool found = false;
            
            // Check snapshot
            int snapTotal = snap.Total();
            for(int k=0; k<snapTotal; k++) {
                if(snap.Get(k).ticket == t) {
                    found = true;
                    break;
                }
            }
            
            if(!found) {
                // Ticket closed -> Remove Virtual Stop
                RemoveVisual(t);
                // Shift array to delete
                if(i < totalStops - 1) {
                     ArrayCopy(m_stops, m_stops, i, i+1);
                }
                ArrayResize(m_stops, totalStops - 1);
                totalStops--;
            }
        }
    }
    
    // Force Clear All (e.g. On Deinit)
    void ClearAll() {
        ObjectsDeleteAll(0, VIRTUAL_STOP_LINE_PREFIX);
        ArrayResize(m_stops, 0);
    }
};

#endif // __AURORA_VIRTUAL_STOPS_MQH__
