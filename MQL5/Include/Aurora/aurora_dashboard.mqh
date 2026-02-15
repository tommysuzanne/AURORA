//+------------------------------------------------------------------+
//|                                             aurora_dashboard.mqh |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      "https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_DASHBOARD_MQH__
#define __AURORA_DASHBOARD_MQH__

#include <Canvas/Canvas.mqh>
#include <Aurora/aurora_types.mqh>
#include <Aurora/aurora_time.mqh>

#resource "\\Images\\Aurora_Icon.bmp"


// --- Paramètres Light Mode "Platinum" ---
#define CLR_BG_MAIN        C'240,242,245' // Gris "Platinum" / Bleu-Gris très pâle
#define CLR_BORDER_MAIN    C'200,205,210' // Bordure gris acier
#define CLR_TEXT_MAIN      C'40,40,40'    // Gris très sombre (pas noir total)
#define CLR_TEXT_TITLE     C'212,175,55'  // Or/Bronze
#define CLR_PROFIT         C'46,139,87'   // Vert Forêt
#define CLR_LOSS           C'205,92,92'   // Rouge Brique
#define CLR_BTN_BG         C'240,240,240' // Bouton Repos
#define CLR_BTN_HOVER      C'225,225,225' // Bouton Survol
#define CLR_BTN_CLOSE      C'255,235,235' // Close All Repos
#define CLR_BTN_CLOSE_H    C'255,215,215' // Close All Survol
#define CLR_BTN_PAUSE      C'235,245,255' // Pause Repos

#define FONT_MAIN          "Segoe UI"
#define FONT_BOLD          "Segoe UI Bold"

// --- Dimensions ---
// --- Dimensions ---
#define DASH_WIDTH         250
#define DASH_HEIGHT        320
#define MARGIN_X           22
#define MARGIN_Y           22

enum ENUM_DASH_STATE {
   DASH_RUNNING,
   DASH_PAUSED
};

//+------------------------------------------------------------------+
//| Classe CAuroraDashboard (Canvas Version)                         |
//+------------------------------------------------------------------+
class CAuroraDashboard {
private:
   CCanvas           m_canvas;
   string            m_obj_name;
   int               m_width;
   int               m_height;
   
   SAuroraState      m_state;      // État actuel
   SAuroraState      m_prev_state; // État précédent (pour redessiner que si nécessaire)
   
   ENUM_DASH_STATE   m_run_state;
   
   // Interaction
   int               m_last_mouse_x;
   int               m_last_mouse_y;
   bool              m_mouse_down;
   
   bool              m_active;
   
   // Resources Caching
   uint              m_logo_data[];
   uint              m_logo_w;
   uint              m_logo_h;
   
   bool              m_log_debug;
   double            m_scale_factor;
   string            m_version;

public:
   CAuroraDashboard();
   ~CAuroraDashboard();
   
   bool Init(long chart_id, string name_prefix="AuroraDash", ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER);
   void Destroy();
   
   // Appelé par OnTimer (Découplage)
   void Update(const SAuroraState &state);
   
   // Appelé par OnChartEvent (Latence Zéro)
   // Appelé par OnChartEvent (Latence Zéro)
   bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   
   bool IsPaused() const;
   void SetLogDebug(bool enable) { m_log_debug = enable; }
   void SetScale(double scale) { m_scale_factor = (scale <= 0.5 ? 1.0 : scale); }
   void SetVersion(string ver) { m_version = ver; }

private:
   int Scale(int v) { return (int)(v * m_scale_factor + 0.5); }
   
   void Redraw();
   void DrawBackground();
   void DrawHeader(int &y);
   void DrawStats(int &y);
   void DrawNews(int &y);
   void DrawFooter(int &y);
   
   // Helpers Vectoriels
   void RoundedRect(int x, int y, int w, int h, int r, uint clr_bg, uint clr_border);
   void Text(int x, int y, string text, uint clr, int size=16, string font=FONT_MAIN, uint align=TA_LEFT);
   
   bool IsStateChanged(const SAuroraState &a, const SAuroraState &b);
   
   void DrawImage(int x, int y, const uint &data[], uint img_w, uint img_h, int target_w, int target_h);
   
   uint ColorToUint(color clr, uchar alpha=255);
};

CAuroraDashboard::CAuroraDashboard() : m_active(false), m_run_state(DASH_RUNNING), m_log_debug(false), m_scale_factor(1.0), m_version("v2.20") {
   m_width = DASH_WIDTH;
   m_height = DASH_HEIGHT;
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CAuroraDashboard::~CAuroraDashboard() {
   Destroy();
}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CAuroraDashboard::Init(long chart_id, string name_prefix, ENUM_BASE_CORNER corner) {
   m_obj_name = name_prefix + "_Canvas";
   
   // Set Dimensions
   m_width = Scale(DASH_WIDTH);
   m_height = Scale(DASH_HEIGHT);
   
   if(!m_canvas.CreateBitmapLabel(m_obj_name, Scale(MARGIN_X), Scale(MARGIN_Y), m_width, m_height, COLOR_FORMAT_ARGB_NORMALIZE)) {
      return false;
   }
   
   // Critical: Enable Mouse Move for Hover/Click detection
   ChartSetInteger(chart_id, CHART_EVENT_MOUSE_MOVE, true);
   
   // Définir l'ancrage dynamiquement
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_CORNER, corner);
   
   // Auto-match anchor to corner for intuitive margins
   ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER;
   if(corner == CORNER_LEFT_LOWER) anchor = ANCHOR_LEFT_LOWER;
   if(corner == CORNER_RIGHT_UPPER) anchor = ANCHOR_RIGHT_UPPER;
   if(corner == CORNER_RIGHT_LOWER) anchor = ANCHOR_RIGHT_LOWER;
   
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_XDISTANCE, Scale(MARGIN_X));
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_YDISTANCE, Scale(MARGIN_Y));
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_ZORDER, 100); // Très haut dessus
   
   // Bordure Objet (Style demandé)
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_BORDER_COLOR, C'210,200,180');
   ObjectSetInteger(chart_id, m_obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   
   // Init Bounding Boxes (Removed)
   
   // --- Resource Caching ---
   if(!ResourceReadImage("::Images\\Aurora_Icon.bmp", m_logo_data, m_logo_w, m_logo_h)) {
       if(m_log_debug) Print("[DASH] Critical: Cannot load Logo Icon!");
       // Fallback or empty
   }
   
   m_active = true;
   Redraw();
   return true;
}

//+------------------------------------------------------------------+
//| Destroy                                                          |
//+------------------------------------------------------------------+
void CAuroraDashboard::Destroy() {
   if (m_active) {
      m_canvas.Destroy();
      m_active = false;
   }
}

//+------------------------------------------------------------------+
//| Update (Timer Driven)                                            |
//+------------------------------------------------------------------+
void CAuroraDashboard::Update(const SAuroraState &state) {
   if(!m_active) return;
   
   m_state = state;
   
   // --- OPTIMIZATION: Dirty Check ---
   // Si l'état n'a pas changé visuellement et que la hauteur est stable, on ne redessine pas.
   if(!IsStateChanged(m_state, m_prev_state)) {
       return;
   }
   
   // --- Refactored Height Calculation (Simulating y_cursor) ---
   int y_cursor = Scale(20); // Top Padding
   
   // Header
   y_cursor += Scale(45); // Logo Height (Increased)
   y_cursor += Scale(20); // Gap after logo
   
   // Stats (4 rows * 15px gap approx)
   // Actual logic in DrawStats: 4 lines with 'gap' spacing.
   // 1st line at y. 4th line at y + 3*gap. + TextHeight.
   // Let's approximate or match exact:
   int stats_line_gap = Scale(15);
   // Corrected height calculation: 4 rows (0, 1, 2, 3) -> 3 gaps.
   // Was previously 5 rows with Regime.
   int stats_block_h = stats_line_gap * 3 + Scale(15); 
   y_cursor += stats_block_h;
   
   y_cursor += Scale(20); // Margin before News
   
   // News
   int news_header_h = Scale(18); // Header Height
   int news_row_h = Scale(19);    // Row Height
   y_cursor += Scale(20);         // "Prochaines actualités" title space
   y_cursor += news_header_h; // Headers
   
   int n_news = ArraySize(state.news);
   int content_h = (n_news * news_row_h);
   if (n_news == 0) content_h += Scale(20); // "Aucune actulité"
   y_cursor += content_h;
   
   y_cursor += Scale(15); // Gap before Footer
   y_cursor += Scale(20); // Footer Height approx
   
   int needed_h = y_cursor + Scale(10); // Bottom Padding
   
   // Minimum height check
   int min_h = Scale(250);
   if(needed_h < min_h) needed_h = min_h;
   
   // DEBUG
   if(m_log_debug) PrintFormat("[DASH_DEBUG] Update: needed_h=%d", needed_h);
   
   if(m_height != needed_h) {
       m_height = needed_h;
       m_canvas.Resize(m_width, m_height);
   }
   
   Redraw();
   m_prev_state = m_state;
}

//+------------------------------------------------------------------+
//| Redraw (Core Render Loop)                                        |
//+------------------------------------------------------------------+
void CAuroraDashboard::Redraw() {
   // 1. Nettoyage TOTAL (Transparent)
   m_canvas.Erase(0x00FFFFFF);
   
   // --- Paramètres de Style Pro ---
   // Couleur de fond: "Platinum"
   // Alpha: 250 (Quasi opaque)
   uint bg_color = ColorToARGB(CLR_BG_MAIN, 250); 
   uint border_color = ColorToARGB(CLR_BORDER_MAIN, 255); // Gris acier
   int radius = Scale(12); // Arrondi un peu moins prononcé pour faire plus "pro"

   // 2. Fond Principal
   RoundedRect(0, 0, m_width, m_height, radius, bg_color, border_color);
   
   // 3. Header Separator (Supprimé)
   
   // 4. Sections
   int y_cursor = Scale(20); // Top Padding
   
   DrawHeader(y_cursor);
   DrawStats(y_cursor);
   DrawNews(y_cursor);
   DrawFooter(y_cursor);
   
   m_canvas.Update();
}

//+------------------------------------------------------------------+
//| Event Handler (Interaction)                                      |
//+------------------------------------------------------------------+
bool CAuroraDashboard::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(!m_active) return false;
   
   // Mouse Move: Just storing position, no buttons to check hover
   if(id == CHARTEVENT_MOUSE_MOVE) {
      m_last_mouse_x = (int)lparam;
      m_last_mouse_y = (int)dparam;
      return false;
   }
   
   // Click: No buttons to handle
   if(id == CHARTEVENT_OBJECT_CLICK) {
      // Nothing to do
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Drawing Implementation                                           |
//+------------------------------------------------------------------+
void CAuroraDashboard::DrawHeader(int &y) {
   // Logo
   int icon_h = Scale(45);
   int icon_w = Scale(45);
   
   // Center Logo specially
   int x_logo = (m_width - icon_w) / 2;
   
   if(ArraySize(m_logo_data) > 0) {
      DrawImage(x_logo, y, m_logo_data, m_logo_w, m_logo_h, icon_w, icon_h);
   }
   
   // Advance cursor
   y += icon_h;
   y += Scale(20); // Gap after logo
}
   
   // Status Dot - Removed
   // uint clr_stat = (m_run_state == DASH_RUNNING ? ColorToUint(clrLimeGreen) : ColorToUint(clrRed));
   // m_canvas.FillCircle(m_width - 25, y_center, 4, clr_stat);

//+------------------------------------------------------------------+
//| Sections Draw Implementation                                     |
//+------------------------------------------------------------------+
void CAuroraDashboard::DrawStats(int &y) {
   int x1 = Scale(20);
   int x2 = m_width / 2 + Scale(10);
   
   int y_start = y; // Current cursor
   int gap = Scale(15);
   
   // Row 1
   Text(x1, y_start, "Profit Total:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   string s_tp = DoubleToString(m_state.profit_total, 2);
   uint c_tp = (m_state.profit_total >= 0 ? ColorToUint(clrLimeGreen) : ColorToUint(clrRed));
   Text(m_width/2 - Scale(5), y_start, s_tp, c_tp, Scale(10), FONT_BOLD, TA_RIGHT);
   
   Text(x2, y_start, "DD Max (Hist):", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   string s_mdd = DoubleToString(m_state.dd_max_alltime, 1) + "%";
   Text(m_width - Scale(15), y_start, s_mdd, ColorToUint(clrRed), Scale(10), FONT_BOLD, TA_RIGHT);
   
   // Row 2
   Text(x1, y_start + gap, "Profit Actuel:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   string s_cp = DoubleToString(m_state.profit_current, 2);
   uint c_cp = (m_state.profit_current >= 0 ? ColorToUint(clrLimeGreen) : ColorToUint(clrRed));
   Text(m_width/2 - Scale(5), y_start + gap, s_cp, c_cp, Scale(10), FONT_BOLD, TA_RIGHT);
   
   Text(x2, y_start + gap, "DD Actuel:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   string s_cdd = DoubleToString(m_state.dd_current, 1) + "%";
   Text(m_width - Scale(15), y_start + gap, s_cdd, ColorToUint(clrRed), Scale(10), FONT_BOLD, TA_RIGHT);
   
   // Row 3
   Text(x1, y_start + gap*2, "Levier:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   string s_lev = "1:" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE));
   Text(m_width/2 - Scale(5), y_start + gap*2, s_lev, ColorToUint(CLR_TEXT_MAIN), Scale(10), FONT_BOLD, TA_RIGHT);
   
   Text(x2, y_start + gap*2, "DD Journ.:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   string s_dd = DoubleToString(m_state.dd_daily, 1) + "%";
   Text(m_width - Scale(15), y_start + gap*2, s_dd, ColorToUint(clrOrange), Scale(10), FONT_BOLD, TA_RIGHT);
   
   // Row 4 (Spread & Heure)
   Text(x1, y_start + gap*3, "Spread:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   
   int spread_val = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   Text(m_width/2 - Scale(5), y_start + gap*3, IntegerToString(spread_val), ColorToUint(clrGray), Scale(10), FONT_BOLD, TA_RIGHT);
   
   Text(x2, y_start + gap*3, "Heure:", ColorToUint(CLR_TEXT_MAIN), Scale(10));
   
   datetime time_cur = AuroraClock::Now();
   string s_time = TimeToString(time_cur, TIME_MINUTES); // HH:MM
   
   MqlDateTime dt; TimeToStruct(time_cur, dt);
   s_time = StringFormat("%02d:%02d", dt.hour, dt.min);
   Text(m_width - Scale(15), y_start + gap*3, s_time, ColorToUint(CLR_TEXT_MAIN), Scale(10), FONT_BOLD, TA_RIGHT);
   
   // Update cursor
   // 4 rows (0, gap, gap*2, gap*3)
   // Total height consumed ~ gap*3 + text_h. 
   
   // --- Row 5 (REGIME STATUS) REMOVED ---
   
   // Update cursor
   // 4 rows consumed (0, gap, gap*2, gap*3)
   // Total height used is roughly (gap*3) + text height
   
   y += (gap * 3) + Scale(15); // + bottom padding similar to what was intended
   y += Scale(15); // Gap before News
}

// DrawNews with relative positioning
void CAuroraDashboard::DrawNews(int &y) {
   int y_sep = y; 
   int y_base = y + Scale(14); // Title position
   
   // Separator Line
   m_canvas.FillRectangle(Scale(15), y_sep, m_width - Scale(15), y_sep + 1, ColorToUint(CLR_BORDER_MAIN));
   
   Text(Scale(20), y_base, "Prochaines actualités:", ColorToUint(CLR_TEXT_MAIN), Scale(12), FONT_BOLD);
   
   // Headers
   int y_head = y_base + Scale(18);
   int h_sz = Scale(11); // Increased from 9
   uint c_h = ColorToUint(clrGray);
   
   // Columns: Time | Cur | (Dot) | Event
   // Equalized Spacing:
   int x_time = Scale(20);
   int x_dev  = Scale(55);
   int x_dot  = Scale(86); // Ecarté (+8px) pour décoller du texte "Devise"
   int x_evt  = Scale(102); // Décalé (+10px) pour laisser respirer le point
   
   Text(x_time, y_head, "Heure", c_h, h_sz);
   Text(x_dev, y_head, "Devise", c_h, h_sz);
   // Text(x_imp, y_head, "Imp", c_h, h_sz); // Header supprimé
   Text(x_evt, y_head, "Evènement", c_h, h_sz);
   
   int row_h = Scale(19); 
   int y_row = y_head + Scale(20);
   
   // Update Cursor locally to loop
   
   int n = ArraySize(m_state.news);
   
   if(n == 0) {
       Text(m_width/2, y_row + Scale(10), "Aucune actualité à venir", ColorToUint(clrGray), Scale(10), FONT_MAIN, TA_CENTER);
       y += (y_row - y) + Scale(30); // Advance past this block
       return;
   }
   
   for(int i=0; i<n; i++) {
        // Clipping check?
        if(y_row >= m_height) break;
       
       SAuroraState::SNewsItem item = m_state.news[i];
       
       string t_str = TimeToString(item.time, TIME_MINUTES);
       MqlDateTime dt; TimeToStruct(item.time, dt);
       t_str = StringFormat("%02d:%02d", dt.hour, dt.min);
       
       Text(x_time, y_row, t_str, ColorToUint(CLR_TEXT_MAIN), Scale(11));
       Text(x_dev, y_row, item.currency, ColorToUint(CLR_TEXT_MAIN), Scale(11));
       
       // Elegant Dot Logic
       uint imp_c = ColorToUint(clrGold); // Low (Jaune/Or)
       if(item.impact == 2) imp_c = ColorToUint(clrOrange); // Medium
       if(item.impact == 3) imp_c = ColorToUint(C'255,80,80'); // High (Rouge doux)
       
       int dot_r = Scale(3); // Rayon discret
       // Centrage Vertical : 
       // Police Scale(11) -> Hauteur visuelle ~8-9px. Centre ~4-5px.
       // y_row est le haut du texte.
       int y_dot = y_row + Scale(5); 
       
       m_canvas.FillCircle(x_dot, y_dot, dot_r, imp_c);
       
       // Event Title with more space
       string title = item.title;
       m_canvas.FontSet(FONT_MAIN, Scale(11));
       int w_text, h_text;
       int available_w = m_width - Scale(10) - x_evt; // Marge droite 10
       
       m_canvas.TextSize(title, w_text, h_text);
       
       if(w_text > available_w) {
           string temp = title;
           int len = StringLen(temp);
           while(w_text > available_w && len > 3) {
               len--;
               temp = StringSubstr(title, 0, len);
               m_canvas.TextSize(temp + "..", w_text, h_text);
           }
           title = temp + "..";
       }
       
       Text(x_evt, y_row, title, ColorToUint(CLR_TEXT_MAIN), Scale(11));
       
       y_row += row_h;
   }
   
   // Update Global Cursor
   y = y_row;
}

void CAuroraDashboard::DrawFooter(int &y) {
     y += Scale(15); // Gap before Footer text
     
     int y_footer = y;
     
     // Dynamic Version + Symbol + TF
     string sub = m_version + " | " + EnumToString((ENUM_TIMEFRAMES)_Period) + " | " + _Symbol;
     StringReplace(sub, "PERIOD_", "");
     
     Text(m_width/2, y_footer, sub, ColorToUint(clrGray), Scale(10), FONT_MAIN, TA_CENTER);
     
     y += Scale(20); // Consume Footer height
}

// DrawControls removed as per request

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool CAuroraDashboard::IsPaused() const {
   return (m_run_state == DASH_PAUSED);
}

//+------------------------------------------------------------------+
//| Utils                                                            |
//+------------------------------------------------------------------+
void CAuroraDashboard::RoundedRect(int x, int y, int w, int h, int r, uint clr_bg, uint clr_border) {
   // 1. Fond
   m_canvas.FillRectangle(x+r, y, x+w-r, y+h, clr_bg);
   m_canvas.FillRectangle(x, y+r, x+w, y+h-r, clr_bg);
   m_canvas.FillCircle(x+r, y+r, r, clr_bg);
   m_canvas.FillCircle(x+w-r, y+r, r, clr_bg);
   m_canvas.FillCircle(x+w-r, y+h-r, r, clr_bg);
   m_canvas.FillCircle(x+r, y+h-r, r, clr_bg);
   
   // 2. Bordure (Lignes Droites)
   m_canvas.Line(x+r, y, x+w-r, y, clr_border);             // Top
   m_canvas.Line(x+r, y+h-1, x+w-r, y+h-1, clr_border);     // Bottom
   m_canvas.Line(x, y+r, x, y+h-r, clr_border);             // Left
   m_canvas.Line(x+w-1, y+r, x+w-1, y+h-r, clr_border);     // Right
   
   // 3. Bordure (Coins - Bresenham)
   int dx = 0, dy = r;
   int d = 3 - 2 * r;
   
   int xc, yc;
   
   while(dy >= dx) {
       // TL: Center (x+r, y+r)
       xc = x+r; yc = y+r;
       m_canvas.PixelSet(xc - dx, yc - dy, clr_border);
       m_canvas.PixelSet(xc - dy, yc - dx, clr_border);
       
       // TR: Center (x+w-r-1, y+r)
       xc = x+w-r-1; yc = y+r;
       m_canvas.PixelSet(xc + dx, yc - dy, clr_border);
       m_canvas.PixelSet(xc + dy, yc - dx, clr_border);
       
       // BR: Center (x+w-r-1, y+h-r-1)
       xc = x+w-r-1; yc = y+h-r-1;
       m_canvas.PixelSet(xc + dx, yc + dy, clr_border);
       m_canvas.PixelSet(xc + dy, yc + dx, clr_border);
       
       // BL: Center (x+r, y+h-r-1)
       xc = x+r; yc = y+h-r-1;
       m_canvas.PixelSet(xc - dx, yc + dy, clr_border);
       m_canvas.PixelSet(xc - dy, yc + dx, clr_border);

       dx++;
       if(d > 0) {
           dy--;
           d = d + 4 * (dx - dy) + 10;
       } else {
           d = d + 4 * dx + 6;
       }
   }
}

void CAuroraDashboard::Text(int x, int y, string text, uint clr, int size, string font, uint align) {
   // Smart Font Handling
   uint flags = 0;
   string real_font = font;
   
   // Si on demande FONT_BOLD ("Segoe UI Bold"), on utilise "Segoe UI" avec le flag SEMIBOLD
   if(font == FONT_BOLD) {
       real_font = FONT_MAIN;
       flags = FW_SEMIBOLD; 
   }
   
   m_canvas.FontSet(real_font, size, flags);
   m_canvas.TextOut(x, y, text, clr, (uint)align);
}



uint CAuroraDashboard::ColorToUint(color clr, uchar alpha) {
   return ColorToARGB(clr, alpha);
}

bool CAuroraDashboard::IsStateChanged(const SAuroraState &a, const SAuroraState &b) {
    // 1. Compare doubles with precision relevant for display (2 decimals)
    if(MathAbs(a.profit_total - b.profit_total) > 0.009) return true;
    if(MathAbs(a.profit_current - b.profit_current) > 0.009) return true;
    if(MathAbs(a.dd_current - b.dd_current) > 0.09) return true; // 1 decimal display
    if(MathAbs(a.dd_max_alltime - b.dd_max_alltime) > 0.09) return true;
    if(MathAbs(a.dd_daily - b.dd_daily) > 0.09) return true;
    
    // 2. Compare Time (Minutes)
    // If minute changed -> Clock update needed
    long t_a = (long)AuroraClock::Now() / 60;
    static long t_prev = 0;
    if(t_a != t_prev) { t_prev = t_a; return true; }

    // 3. Compare News
    if(ArraySize(a.news) != ArraySize(b.news)) return true;
    for(int i=0; i<ArraySize(a.news); i++) {
        if(a.news[i].time != b.news[i].time) return true;
        if(a.news[i].title != b.news[i].title) return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Helper Alpha Blending                                            |
//+------------------------------------------------------------------+
uint BlendColors(uint bg, uint src) {
   // Format ARGB
   uchar a_src = (uchar)((src >> 24) & 0xFF);
   
   // Optimisation: si alpha max, source gagne
   if(a_src == 255) return src;
   // Si alpha 0, fond gagne
   if(a_src == 0) return bg;
   
   uchar r_src = (uchar)((src >> 16) & 0xFF);
   uchar g_src = (uchar)((src >> 8) & 0xFF);
   uchar b_src = (uchar)(src & 0xFF);
   
   uchar a_bg = (uchar)((bg >> 24) & 0xFF);
   uchar r_bg = (uchar)((bg >> 16) & 0xFF);
   uchar g_bg = (uchar)((bg >> 8) & 0xFF);
   uchar b_bg = (uchar)(bg & 0xFF);
   
   // Formule Blending standard
   // Out = (Src * A + Bg * (1-A))
   // Note: CCanvas utilise premultiplied alpha parfois, mais ici on assume straight alpha pour les ressources BMP
   
   double alpha = a_src / 255.0;
   double inv_alpha = 1.0 - alpha;
   
   uchar r_out = (uchar)(r_src * alpha + r_bg * inv_alpha);
   uchar g_out = (uchar)(g_src * alpha + g_bg * inv_alpha);
   uchar b_out = (uchar)(b_src * alpha + b_bg * inv_alpha);
   // On garde l'alpha du background (généralement opaque ou semi-transp pour le dashboard)
   // ou on combine les alphas. Pour le dash, on mixe sur le fond existant.
   
   // 2. Return combined ARGB
   return ((uint)a_bg << 24) | ((uint)r_out << 16) | ((uint)g_out << 8) | (uint)b_out;
}

void CAuroraDashboard::DrawImage(int x, int y, const uint &data[], uint img_w, uint img_h, int target_w, int target_h) {
   if(ArraySize(data) == 0) return;
   
   if(target_w <= 0) target_w = (int)img_w;
   if(target_h <= 0) target_h = (int)img_h;
   
   // Bilinear Interpolation manually aimed for better quality than Nearest Neighbor
   // Simplified to Bicubic-like logic would be expensive in MQL5 loops.
   // Let's stick to a safe sampling but with Alpha Blending.
   
   for(int dy = 0; dy < target_h; dy++) {
      // Mapping Y
      float fy = (float)dy * img_h / target_h;
      int sy = (int)fy;
      if(sy >= (int)img_h) sy = (int)img_h - 1;
      
      for(int dx = 0; dx < target_w; dx++) {
         // Mapping X
         float fx = (float)dx * img_w / target_w;
         int sx = (int)fx;
         if(sx >= (int)img_w) sx = (int)img_w - 1;
         
         uint pixel_src = data[sy * img_w + sx];
         
         // Alpha Blending
         // Lire le pixel existant sur le canvas
         // Attention aux limites
         if(x+dx >= m_width || y+dy >= m_height) continue;
         
         uint pixel_bg = m_canvas.PixelGet(x + dx, y + dy);
         uint pixel_final = BlendColors(pixel_bg, pixel_src);
         
         m_canvas.PixelSet(x + dx, y + dy, pixel_final);
      }
   }
}

#endif // __AURORA_DASHBOARD_MQH__
