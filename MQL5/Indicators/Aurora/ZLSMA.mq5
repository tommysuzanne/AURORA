//+------------------------------------------------------------------+
//|                                                        ZLSMA.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property description "Zero Lag Least Squares Moving Average (ZLSMA)"
#property indicator_chart_window

#property indicator_buffers 4 // Augmenté pour stocker HA en interne
#property indicator_plots   1

#property indicator_label1 "ZLSMA"
#property indicator_type1  DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_color1 clrCyan
#property indicator_width1 2

// Buffers principaux
double B1[];
double B2[];

// Buffers internes pour le calcul Heiken Ashi
double HA_Open[];
double HA_Close[];

input int LRPeriod = 14; // Period
input bool HeikenAshi = true; // Use HeikenAshi

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    // Buffer d'affichage
    SetIndexBuffer(0, B1, INDICATOR_DATA);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    
    // Buffers de calcul
    SetIndexBuffer(1, B2, INDICATOR_CALCULATIONS);
    SetIndexBuffer(2, HA_Open, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, HA_Close, INDICATOR_CALCULATIONS);

    // Initialisation des séries (sera géré dynamiquement dans OnCalculate)
    ArraySetAsSeries(B1, true);
    ArraySetAsSeries(B2, true);
    // HA buffers restent en mode standard pour le calcul, puis inversés si besoin

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
                const int &spread[]) {

    if (rates_total <= LRPeriod + 1) return(0);

    // ---------------------------------------------------------
    // ETAPE 1 : Calcul Heiken Ashi (Boucle Standard 0 -> Total)
    // ---------------------------------------------------------
    // On s'assure que les tableaux HA sont en mode "Oldest First" pour le calcul récursif
    ArraySetAsSeries(HA_Open, false);
    ArraySetAsSeries(HA_Close, false);
    
    int start_ha;
    if (prev_calculated == 0) {
        // Initialisation de la première bougie HA
        HA_Open[0] = open[0]; 
        HA_Close[0] = close[0]; // (O+H+L+C)/4 pour la première est souvent approx par close ou OHLC/4 standard
        start_ha = 1;
    } else {
        start_ha = prev_calculated - 1;
    }

    // Calcul HA (nécessite l'accès à i-1)
    for (int i = start_ha; i < rates_total; i++) {
        // Formule standard Heiken Ashi
        // HA_Close = Moyenne OHLC courant
        HA_Close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
        
        // HA_Open = Moyenne (HA_Open prev + HA_Close prev)
        HA_Open[i] = (HA_Open[i - 1] + HA_Close[i - 1]) / 2.0;
    }

    // ---------------------------------------------------------
    // ETAPE 2 : Calcul ZLSMA (Boucle Série Total -> 0)
    // ---------------------------------------------------------
    // Pour correspondre à la logique originale de la ZLSMA, on passe tout en "Series" (0 = Newest)
    ArraySetAsSeries(close, true); // Attention: ceci n'affecte que l'accès local dans cette fonction
    ArraySetAsSeries(HA_Close, true);
    ArraySetAsSeries(B1, true);
    ArraySetAsSeries(B2, true);

    int limit = rates_total - prev_calculated;
    if (limit > 1) {
        // Si recalcul complet ou quasi complet, on nettoie les buffers ZLSMA
        // Note: ne pas faire Initialize sur HA sinon on perd l'historique nécessaire au calcul HA
        // On ne touche pas à B1/B2 ici sauf si reset total nécessaire
        limit = rates_total - LRPeriod - 1;
    }

    // Boucle inversée (du plus récent au plus ancien traité)
    for (int pos = limit; pos >= 0; pos--) {
        // Si HeikenAshi est activé, on utilise le buffer HA_Close calculé ci-dessus
        // Sinon on utilise le prix Close standard
        if (HeikenAshi) {
            B2[pos] = LRMA(pos, LRPeriod, HA_Close);
        } else {
            B2[pos] = LRMA(pos, LRPeriod, close);
        }
    }

    for (int pos = limit; pos >= 0; pos--) {
        B1[pos] = 2 * B2[pos] - LRMA(pos, LRPeriod, B2);
    }

    return(rates_total);
}


//+------------------------------------------------------------------+
//| Calculate LRMA                                                   |
//+------------------------------------------------------------------+
double LRMA(const int pos, const int period, const double &price[]) {
    // Sécurité débordement tableau
    if (pos + period >= ArraySize(price)) return 0.0;

    double tmpS = 0;
    double tmpW = 0;
    double wsum = 0;

    for (int i = 0; i < period; i++) {
        double val = price[pos + i];
        tmpS += val;
        tmpW += val * (period - i);
        wsum += (period - i);
    }
    
    if (period == 0 || wsum == 0) return 0.0; // Protection div/0

    tmpS /= period;
    tmpW /= wsum;
    
    return 3.0 * tmpW - 2.0 * tmpS;
}
//+------------------------------------------------------------------+