//+------------------------------------------------------------------+
//| FXTT_StrategyChecklist.mq5                                       |
//| Copyright 2016, Carlos Oliveira                                   |
//| https://www.forextradingtools.eu                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, Carlos Oliveira"
#property link      "https://www.forextradingtools.eu/"
#property version   "3.0"
#property strict
#property indicator_chart_window
#property script_show_inputs
#property indicator_plots   0
#property indicator_buffers 0
#property indicator_minimum 0.0
#property indicator_maximum 0.0

#include <Controls\Dialog.mqh>
#include <Controls\CheckBox.mqh>
#include <Controls\Label.mqh>

#define NUM_CHECKS      20
#define MAX_VISIBLE     20
#define SECTION_PREFIX  '>'

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input string TAG = "FxTT_SC_";

input group "=== Layout ==="
input ENUM_BASE_CORNER Location       = CORNER_RIGHT_LOWER;
input int  DialogWidth                = 280;   // Dialog total width (px)
input int  MarginFromEdge             = 20;    // Distance from chart edge (px)
input int  InnerPaddingX              = 8;     // Left/right inner padding (px)
input int  InnerPaddingY              = 6;     // Top inner padding (px)
input int  RowHeight                  = 24;    // Height of each row (px) ← THIS NOW WORKS
input int  RowSpacing                 = 2;     // Extra gap between rows (px)

input group "=== Appearance ==="
input string FontName                 = "Segoe UI";
input int    FontSize                 = 9;
input color  CheckedColor             = clrLimeGreen;
input color  UncheckedColor           = clrBlack;
input color  SectionColor             = clrGold;
input color  TitleColor               = clrBlack;
input bool   ShowTooltips             = true;

input group "=== Persistence ==="
input bool SavePerSymbol              = true;
input bool SavePerTimeframe           = false;

input group "=== Checklist Items ==="
input string Check01 = ">--- Setup ---";
input string Check02 = "Trend confirmed";
input string Check03 = "Structure respected";
input string Check04 = ">--- Entry ---";
input string Check05 = "Signal candle closed";
input string Check06 = "Risk/Reward >= 1:2";
input string Check07 = "";
input string Check08 = "";
input string Check09 = "";
input string Check10 = "";
input string Check11 = "";
input string Check12 = "";
input string Check13 = "";
input string Check14 = "";
input string Check15 = "";
input string Check16 = "";
input string Check17 = "";
input string Check18 = "";
input string Check19 = "";
input string Check20 = "";

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
struct Dimension { int width, height; };
struct Position  { int x, y; };

static const string DATA_DIR  = "SChecklist";
static const string DATA_FILE = "state.bin";

//+------------------------------------------------------------------+
void GetChecklistStrings(string &arr[])
{
   string src[NUM_CHECKS] = {
      Check01,Check02,Check03,Check04,Check05,
      Check06,Check07,Check08,Check09,Check10,
      Check11,Check12,Check13,Check14,Check15,
      Check16,Check17,Check18,Check19,Check20
   };
   ArrayCopy(arr, src);
}

//+------------------------------------------------------------------+
bool IsSectionHeader(const string &text)
{
   return StringLen(text) > 0 && StringGetCharacter(text, 0) == SECTION_PREFIX;
}

//+------------------------------------------------------------------+
string BuildSaveKey()
{
   string key = DATA_DIR + "//";
   if(SavePerSymbol)    key += Symbol();
   if(SavePerTimeframe) key += "_" + IntegerToString(Period());
   key += DATA_FILE;
   return key;
}

//+------------------------------------------------------------------+
int CountVisible()
{
   string c[NUM_CHECKS];
   GetChecklistStrings(c);
   int n = 0;
   for(int i = 0; i < NUM_CHECKS; i++)
      if(StringLen(c[i]) > 0) n++;
   return n;
}

//+------------------------------------------------------------------+
int CalcDialogHeight(int visibleRows)
{
   // title bar ~20px, then rows
   return InnerPaddingY + visibleRows * (RowHeight + RowSpacing) + InnerPaddingY;
}

//+------------------------------------------------------------------+
Position CalcDialogPos(const Dimension &dlg, const Dimension &chart)
{
   const int m = MarginFromEdge;
   Position p  = {m, m};
   switch(Location)
   {
      case CORNER_RIGHT_UPPER: p.x = chart.width  - dlg.width  - m; break;
      case CORNER_LEFT_LOWER:  p.y = chart.height - dlg.height - m; break;
      case CORNER_RIGHT_LOWER:
         p.x = chart.width  - dlg.width  - m;
         p.y = chart.height - dlg.height - m;
         break;
   }
   return p;
}

//+------------------------------------------------------------------+
//| CPanelDialog                                                      |
//+------------------------------------------------------------------+
class CPanelDialog : public CAppDialog
{
private:
   //--- One CCheckBox per interactive row, one CLabel per section header
   CCheckBox   *m_checkboxes[MAX_VISIBLE];   // only for non-section rows
   CLabel      *m_labels[MAX_VISIBLE];       // only for section header rows

   //--- Parallel arrays indexed by visible slot
   bool         m_is_section[MAX_VISIBLE];   // true → section header
   int          m_orig_index[MAX_VISIBLE];   // → index into checks[NUM_CHECKS]
   int          m_visible_count;

   //--- Persistent state, indexed by original checks[] index
   bool         m_state[NUM_CHECKS];

public:
                CPanelDialog(void);
               ~CPanelDialog(void);

   virtual bool Create(const long chart, const string name,
                       const int subwin,
                       const int x1, const int y1,
                       const int x2, const int y2);

   virtual bool OnEvent(const int id, const long &lparam,
                        const double &dparam, const string &sparam);

   //--- called by event map when any checkbox fires ON_CHANGE
   void         OnCheckboxChanged(void);

   void         ResetAllChecks(void);
   void         SaveState(void);
   void         LoadState(void);

private:
   bool         BuildRows(void);
   void         RefreshColors(void);
   void         ApplyCheckboxFont(CCheckBox *cb, const string &label);
   void         ApplyLabelFont(CLabel *lbl, const string &text);
};

//+------------------------------------------------------------------+
CPanelDialog::CPanelDialog(void) : m_visible_count(0)
{
   ArrayInitialize(m_state,      false);
   ArrayInitialize(m_is_section, false);
   ArrayInitialize(m_orig_index, -1);
   for(int i = 0; i < MAX_VISIBLE; i++)
   {
      m_checkboxes[i] = NULL;
      m_labels[i]     = NULL;
   }
}

//+------------------------------------------------------------------+
CPanelDialog::~CPanelDialog(void)
{
   SaveState();
   for(int i = 0; i < MAX_VISIBLE; i++)
   {
      if(m_checkboxes[i] != NULL) { delete m_checkboxes[i]; m_checkboxes[i] = NULL; }
      if(m_labels[i]     != NULL) { delete m_labels[i];     m_labels[i]     = NULL; }
   }
}

//+------------------------------------------------------------------+
bool CPanelDialog::Create(const long chart, const string name,
                           const int subwin,
                           const int x1, const int y1,
                           const int x2, const int y2)
{
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;
   if(!BuildRows())
      return false;
   LoadState();
   return true;
}

//+------------------------------------------------------------------+
//| Intercept control events manually since we have dynamic controls |
//+------------------------------------------------------------------+
bool CPanelDialog::OnEvent(const int id, const long &lparam,
                            const double &dparam, const string &sparam)
{
   // Let CAppDialog handle drag/close/resize first
   if(CAppDialog::OnEvent(id, lparam, dparam, sparam))
      return true;

   // Detect a checkbox click: CHARTEVENT_OBJECT_CLICK on one of our boxes
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      for(int vi = 0; vi < m_visible_count; vi++)
      {
         if(m_is_section[vi]) continue;
         if(m_checkboxes[vi] == NULL) continue;

         // Compare the clicked object name with this checkbox's name
         if(sparam == m_checkboxes[vi].Name() ||
            StringFind(sparam, m_checkboxes[vi].Name()) == 0)
         {
            // Toggle happens automatically inside CCheckBox on click;
            // we just need to sync our state array
            int oi = m_orig_index[vi];
            m_state[oi] = m_checkboxes[vi].Checked();
            RefreshColors();
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool CPanelDialog::BuildRows(void)
{
   string checks[NUM_CHECKS];
   GetChecklistStrings(checks);

   m_visible_count = 0;
   int innerW = DialogWidth - InnerPaddingX * 2 - 16; // 16 = scrollbar guard

   for(int i = 0; i < NUM_CHECKS && m_visible_count < MAX_VISIBLE; i++)
   {
      if(StringLen(checks[i]) == 0) continue;

      int vi = m_visible_count;
      m_orig_index[vi] = i;

      // Y position inside the client area of the dialog
      int rowY = InnerPaddingY + vi * (RowHeight + RowSpacing);
      int x1   = InnerPaddingX;
      int x2   = x1 + innerW;
      int y1   = rowY;
      int y2   = rowY + RowHeight;

      if(IsSectionHeader(checks[i]))
      {
         m_is_section[vi] = true;
         m_labels[vi] = new CLabel();
         if(!m_labels[vi].Create(m_chart_id, TAG + m_name + "Lbl" + IntegerToString(vi),
                                  m_subwin, x1, y1, x2, y2))
            return false;
         ApplyLabelFont(m_labels[vi], checks[i]);
         if(!Add(m_labels[vi])) return false;
      }
      else
      {
         m_is_section[vi] = false;
         m_checkboxes[vi] = new CCheckBox();
         if(!m_checkboxes[vi].Create(m_chart_id, TAG + m_name + "CB" + IntegerToString(vi),
                                      m_subwin, x1, y1, x2, y2))
            return false;
         ApplyCheckboxFont(m_checkboxes[vi], checks[i]);
         if(!Add(m_checkboxes[vi])) return false;
      }

      m_visible_count++;
   }
   return true;
}

//+------------------------------------------------------------------+
void CPanelDialog::ApplyCheckboxFont(CCheckBox *cb, const string &label)
{
   cb.Text(label);
   cb.Color(UncheckedColor);

   // Font is set on the underlying chart object after creation
   string objName = cb.Name();
   if(ObjectFind(m_chart_id, objName) >= 0)
   {
      ObjectSetString(m_chart_id,  objName, OBJPROP_FONT,     FontName);
      ObjectSetInteger(m_chart_id, objName, OBJPROP_FONTSIZE, FontSize);
      if(ShowTooltips)
         ObjectSetString(m_chart_id, objName, OBJPROP_TOOLTIP, "Toggle: " + label);
   }
}

//+------------------------------------------------------------------+
void CPanelDialog::ApplyLabelFont(CLabel *lbl, const string &text)
{
   lbl.Text(text);
   lbl.Color(SectionColor);

   string objName = lbl.Name();
   if(ObjectFind(m_chart_id, objName) >= 0)
   {
      ObjectSetString(m_chart_id,  objName, OBJPROP_FONT,     FontName);
      ObjectSetInteger(m_chart_id, objName, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(m_chart_id,  objName, OBJPROP_TOOLTIP,  "");
   }
}

//+------------------------------------------------------------------+
void CPanelDialog::RefreshColors(void)
{
   for(int vi = 0; vi < m_visible_count; vi++)
   {
      if(m_is_section[vi]) continue;
      if(m_checkboxes[vi] == NULL) continue;
      int oi = m_orig_index[vi];
      color c = m_state[oi] ? CheckedColor : UncheckedColor;
      m_checkboxes[vi].Color(c);
      string objName = m_checkboxes[vi].Name();
      if(ObjectFind(m_chart_id, objName) >= 0)
         ObjectSetInteger(m_chart_id, objName, OBJPROP_COLOR, c);
   }
   ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
void CPanelDialog::ResetAllChecks(void)
{
   ArrayInitialize(m_state, false);
   for(int vi = 0; vi < m_visible_count; vi++)
   {
      if(m_is_section[vi] || m_checkboxes[vi] == NULL) continue;
      m_checkboxes[vi].Checked(false);
   }
   RefreshColors();
}

//+------------------------------------------------------------------+
void CPanelDialog::SaveState(void)
{
   string path = BuildSaveKey();
   ResetLastError();
   int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_BIN);
   if(h == INVALID_HANDLE)
   {
      Print(__FUNCTION__, ": FileOpen failed [", path, "] err=", GetLastError());
      return;
   }
   FileSeek(h, 0, SEEK_SET);
   if(!FileWriteArray(h, m_state))
      Print(__FUNCTION__, ": FileWriteArray failed, err=", GetLastError());
   FileClose(h);
}

//+------------------------------------------------------------------+
void CPanelDialog::LoadState(void)
{
   string path = BuildSaveKey();
   ResetLastError();
   int h = FileOpen(path, FILE_READ | FILE_BIN);
   if(h == INVALID_HANDLE)
   {
      Print(__FUNCTION__, ": No saved state [", path, "], starting fresh.");
      return;
   }
   bool buf[NUM_CHECKS];
   ArrayInitialize(buf, false);
   if(!FileReadArray(h, buf))
      Print(__FUNCTION__, ": FileReadArray failed, err=", GetLastError());
   else
      ArrayCopy(m_state, buf);
   FileClose(h);

   // Restore checkbox visual state
   for(int vi = 0; vi < m_visible_count; vi++)
   {
      if(m_is_section[vi] || m_checkboxes[vi] == NULL) continue;
      int oi = m_orig_index[vi];
      m_checkboxes[vi].Checked(m_state[oi]);
   }
   RefreshColors();
}

//+------------------------------------------------------------------+
//| Global instance                                                   |
//+------------------------------------------------------------------+
CPanelDialog ExtDialog;

//+------------------------------------------------------------------+
int OnInit()
{
   int visible = CountVisible();
   int dlgH    = CalcDialogHeight(visible) + 26; // +26 for CAppDialog title bar
   int dlgW    = DialogWidth;

   Dimension chart = {
      (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS),
      (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)
   };
   Dimension dlg = {dlgW, dlgH};
   Position  pos = CalcDialogPos(dlg, chart);

   if(!ExtDialog.Create(0, "Strategy Checklist", 0,
                         pos.x, pos.y,
                         pos.x + dlgW, pos.y + dlgH))
   {
      Print("Failed to create dialog");
      return INIT_FAILED;
   }

   ExtDialog.Run();
   ChartRedraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ExtDialog.Destroy(reason);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   return rates_total;
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
   ExtDialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+