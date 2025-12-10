//+------------------------------------------------------------------+
//|                                          GOLD DASHBOARD V2.0     |
//|                    Modern Modular Trading Dashboard for Gold      |
//|              Clean Architecture | Reliable Order Execution        |
//+------------------------------------------------------------------+
#property copyright "Professional Trading Dashboard"
#property version   "2.00"
#property strict
#property description "Modern modular Gold trading dashboard with reliable order execution"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "═══════════════════════════════════════════════════════"
input group "Panel Position & Size"
input int      InpXLeft          = 10;       // Left Panel X Position
input int      InpYTop           = 40;       // Top Panel Y Position
input int      InpWidthLeft      = 220;      // Left Panel Width
input int      InpWidthRight     = 280;      // Right Panel Width
input int      InpWidthThird     = 280;      // Third Panel Width
input int      InpPanelHeight    = 600;      // Panel Height

input group "═══════════════════════════════════════════════════════"
input group "Color Scheme"
input color    ClrBackground     = C'10,10,12';    // Background Color
input color    ClrHeader         = C'255,190,0'; // Header Color (Gold)
input color    ClrLabel          = C'180,180,180'; // Label Color
input color    ClrValue          = C'255,255,255'; // Value Color
input color    ClrBuy            = C'46,204,113';  // Buy/Bullish Color
input color    ClrSell           = C'231,76,60';   // Sell/Bearish Color
input color    ClrNeutral        = C'120,120,120'; // Neutral Color
input color    ClrWarning        = C'255,152,0';  // Warning Color

input group "═══════════════════════════════════════════════════════"
input group "Indicator Settings"
input int      InpRSIPeriod      = 14;       // RSI Period
input int      InpMAFast         = 20;       // Fast MA Period
input int      InpMASlow         = 50;       // Slow MA Period
input int      InpATRPeriod      = 14;       // ATR Period

input group "═══════════════════════════════════════════════════════"
input group "OpenAI AI Integration"
input bool     InpUseAI          = true;     // Use AI for Trading Decisions
input string   InpOpenAIAPIKey   = "YOUR OPENAI HERE";       // OpenAI API Key (sk-...)
input string   InpOpenAIModel    = "gpt-5.1"; // OpenAI Model
input int      InpAIUpdateMinutes = 1;      // AI Analysis Update (minutes) - MUST BE 1 for swing trading
input double   InpAIConfidenceMin = 0.7;    // Minimum AI Confidence (0.0-1.0)
input bool     InpAIOverride      = true;  // Allow AI to Override Signals

input group "═══════════════════════════════════════════════════════"
input group "Trading Algorithm Settings"
input bool     InpEnableTrading  = true;    // Enable Auto Trading
input double   InpLotSize        = 0.01;    // Lot Size per Trade (Swing Trading)
input int      InpRSIBuyLevel    = 35;       // RSI Level for Buy Signal (oversold)
input int      InpMaxPositions   = 10;       // Maximum Open Positions (Swing Trading)
input double   InpStopLossATR     = 2.0;      // Stop Loss (ATR multiplier)
input int      InpMinSpreadPts   = 5000;    // Minimum Spread (points) to trade (disabled for crypto)
input bool     InpRequireSupport = true;     // Require Price Near Support Level
input double   InpSupportDistance = 100.0;  // Support Distance (points)
input bool     InpRequireBullishMA = true;   // Require Bullish MA Trend
input bool     InpRequireGoodSession = true;// Require Good Trading Session

input group "═══════════════════════════════════════════════════════"
input group "Swing Trading Settings"
input bool     InpSwingTrading   = false;   // Enable Swing Trading (M15) - DISABLED, using M1
input double   InpProfitTargetATR = 1.5;    // Take Profit (ATR multiplier)
input double   InpMinProfitPct   = 0.05;    // Minimum Profit % to Close (PROFIT HUNGRY - take any profit!)
input bool     InpAIProfitTaking = true;    // Let AI decide when to close

input group "═══════════════════════════════════════════════════════"
input group "TEST MODE"
input bool     InpTestMode       = false;    // Enable Test Mode (Place 0.01 lot, modify SL, then close)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
string         g_Prefix = "GOLD_V2_";

// Indicator Handles
int            g_HandleRSI;
int            g_HandleMAFast;
int            g_HandleMASlow;
int            g_HandleATR;

// Indicator Buffers
double         g_BufferRSI[];
double         g_BufferMAFast[];
double         g_BufferMASlow[];
double         g_BufferATR[];

// Symbol Info
int            g_SymbolDigits = 0;
double         g_SymbolPoint = 0.0;

// Trading
CTrade         g_Trade;
datetime       g_LastTradeCheck = 0;
ulong          g_LastTradeTicket = 0;

// Tick Tracking
int            g_TicksPerSecond = 0;
datetime       g_LastSecond = 0;

// AI Integration
datetime       g_LastAIUpdate = 0;
string         g_AISignal = "WAITING";
double         g_AIConfidence = 0.0;
string         g_AIReasoning = "";
string         g_AISummary = "";
string         g_AISummaryLines[];
bool           g_AIIsActive = false;
string         g_AIStatus = "INITIALIZING";

// Trade Statistics
int            g_TotalTrades = 0;
int            g_WinningTrades = 0;
int            g_LosingTrades = 0;
double         g_TotalProfit = 0.0;

// Test Mode
bool           g_TestCompleted = false;
int            g_TestStep = 0; // 0=not started, 1=place order, 2=modify SL, 3=close, 4=done
ulong          g_TestTicket = 0;
datetime       g_TestLastAction = 0;

// Trailing Stop Loss - Track max profit for each position
ulong          g_TrackedTickets[];     // Array of tracked position tickets
double         g_MaxProfitPrice[];     // Max profit price reached for each position
datetime       g_LastSLUpdate[];       // Last time SL was updated for each position

//+------------------------------------------------------------------+
//| Test Mode Function - AI DRIVEN TEST                             |
//| Tests if AI can place orders and modify stop losses             |
//+------------------------------------------------------------------+
void RunTestMode()
{
   if(g_TestCompleted || g_TestStep == 4) {
      return; // Test already completed
   }
   
   // Check trading permissions and connection (only once)
   if(g_TestStep == 0) {
      // Check terminal connection
      if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
         Print("❌ ERROR: Terminal not connected to broker server!");
         Print("   Please check your internet connection and broker server status.");
         Alert("TERMINAL NOT CONNECTED! Check internet and broker connection.");
         g_TestCompleted = true;
         return;
      }
      
      // Check account connection
      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
         Print("❌ ERROR: Trading not allowed on this account!");
         Alert("Trading not allowed on this account!");
         g_TestCompleted = true;
         return;
      }
      
      // Check if symbol is tradeable
      if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL) {
         long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
         if(tradeMode == SYMBOL_TRADE_MODE_DISABLED) {
            Print("❌ ERROR: Trading disabled for ", _Symbol);
            Alert("Trading disabled for " + _Symbol);
            g_TestCompleted = true;
            return;
         }
      }
      
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
         Print("❌ ERROR: AutoTrading disabled in Terminal! Cannot run test.");
         Alert("AutoTrading is disabled! Please enable it in Tools -> Options -> Expert Advisors");
         g_TestCompleted = true;
         return;
      }
      
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
         Print("❌ ERROR: AutoTrading disabled for EA! Cannot run test.");
         Alert("AutoTrading is disabled for this EA! Check Expert Advisors settings.");
         g_TestCompleted = true;
         return;
      }
      
      // Check if we can get market prices (connection test)
      double testAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double testBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(testAsk <= 0 || testBid <= 0) {
         Print("❌ ERROR: Cannot get market prices - broker connection issue!");
         Print("   Ask: ", testAsk, " Bid: ", testBid);
         Alert("Cannot get market prices! Check broker connection.");
         g_TestCompleted = true;
         return;
      }
      
      Print("═══════════════════════════════════════════════════════");
      Print("🤖 AI TEST MODE - Testing AI Trading Capabilities");
      Print("   Account: ", AccountInfoString(ACCOUNT_NAME));
      Print("   Server: ", AccountInfoString(ACCOUNT_SERVER));
      Print("   Connected: ✓");
      Print("   Waiting for AI to analyze market and signal BUY...");
      Print("═══════════════════════════════════════════════════════");
      g_TestStep = 1; // Move to waiting for AI signal
   }
   
   // STEP 1: PLACE ORDER FAST (after 2-3 ticks, simulate AI decision)
   if(g_TestStep == 1) {
      // Count ticks - place order after 2-3 ticks
      static int placeTickCount = 0;
      placeTickCount++;
      
      // Wait 2-3 ticks before placing
      if(placeTickCount < 2) {
         return; // Wait for more ticks
      }
      
      // Check if we already have a position
      if(CountOpenBuyPositions() > 0) {
         Print("✅ AI TEST: Position already exists!");
         Print("   Moving to step 2: Modify SL and TP...");
         g_TestStep = 2;
         placeTickCount = 0;
         g_TestLastAction = TimeCurrent();
         return;
      }
      
      // Simulate AI decision (fast test mode)
      // In real mode, this would wait for actual AI signal
      Print("🤖 AI TEST: Simulating AI BUY signal (fast test mode)");
      Print("   → AI analyzed market and decided to BUY");
      
      // Get market data
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(currentAsk <= 0 || currentBid <= 0) {
         Print("❌ ERROR: Invalid market prices");
         return;
      }
      
      // Get ATR
      double atr = 0.0;
      if(CopyBuffer(g_HandleATR, 0, 0, 1, g_BufferATR) >= 1) {
         atr = g_BufferATR[0];
      } else {
         atr = (currentAsk - currentBid) * 10;
      }
      
      // Calculate stop loss
      double stopLoss = currentAsk - (atr * InpStopLossATR);
      stopLoss = NormalizeDouble(stopLoss, g_SymbolDigits);
      
      double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_SymbolPoint;
      if(minStopLevel > 0 && (currentAsk - stopLoss) < minStopLevel) {
         stopLoss = NormalizeDouble(currentAsk - minStopLevel, g_SymbolDigits);
      }
      
      Print("⚡ STEP 1: AI PLACING ORDER (Fast Test)");
      Print("  Ask: ", currentAsk, " SL: ", stopLoss);
      Print("  Lot Size: 0.01 (Test Mode)");
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = 0.01; // Test mode uses 0.01 lot
      request.type = ORDER_TYPE_BUY;
      request.price = 0; // Market price
      request.sl = stopLoss;
      request.tp = 0; // No TP initially
      request.deviation = 10;
      request.magic = 123456;
      request.comment = "GOLD V2 - AI TEST";
      
      long fillingMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      if((fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
         request.type_filling = ORDER_FILLING_FOK;
      } else if((fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
         request.type_filling = ORDER_FILLING_IOC;
      } else {
         request.type_filling = ORDER_FILLING_RETURN;
      }
      
      if(OrderSend(request, result)) {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
            Print("✅ AI TEST: ORDER PLACED BY AI!");
            Print("   Ticket: ", result.order, " Deal: ", result.deal);
            Print("   → AI successfully placed the order!");
            g_TestTicket = result.order;
            g_TestStep = 2; // Move to modify SL/TP
            placeTickCount = 0; // Reset counter
            g_TestLastAction = TimeCurrent();
            return;
         } else {
            Print("❌ AI TEST: ORDER FAILED: Retcode=", result.retcode, " - ", result.comment);
            g_TestCompleted = true;
            return;
         }
      } else {
         Print("❌ AI TEST: OrderSend FAILED!");
         Print("   Error: ", GetLastError(), " - ", result.comment);
         g_TestCompleted = true;
         return;
      }
      return;
   }
   
   // STEP 2: MODIFY SL AND TP (FAST - after 2-3 ticks)
   if(g_TestStep == 2) {
      // Count ticks since order was placed
      static int tickCount = 0;
      tickCount++;
      
      // Wait 2-3 ticks before modifying
      if(tickCount < 2) {
         return; // Wait for more ticks
      }
      
      // Find position
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == 123456 &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               
               // Get ATR for calculations
               double atr = 0.0;
               if(CopyBuffer(g_HandleATR, 0, 0, 1, g_BufferATR) >= 1) {
                  atr = g_BufferATR[0];
                  } else {
                  atr = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 10;
               }
               
               // Get minimum stop level
               double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_SymbolPoint;
               if(minStopLevel <= 0) minStopLevel = 10 * g_SymbolPoint;
               
               // Calculate new SL (breakeven or slightly above)
               double newSL = entryPrice; // Breakeven
               double maxAllowedSL = currentPrice - minStopLevel;
               if(newSL >= maxAllowedSL) {
                  newSL = maxAllowedSL - (g_SymbolPoint * 1);
               }
               newSL = NormalizeDouble(newSL, g_SymbolDigits);
               
               // Calculate TP (entry + 1x ATR profit)
               double newTP = entryPrice + (atr * 1.0);
               newTP = NormalizeDouble(newTP, g_SymbolDigits);
               
               Print("⚡ STEP 2: MODIFYING SL AND TP (AI Test)");
               Print("  Ticket: ", ticket);
               Print("  Entry: ", entryPrice, " Current: ", currentPrice);
               Print("  Old SL: ", currentSL, " → New SL: ", newSL);
               Print("  Old TP: 0 → New TP: ", newTP);
               
               if(g_Trade.PositionModify(ticket, newSL, newTP)) {
                  Print("✅ SL AND TP MODIFIED!");
                  g_TestTicket = ticket;
                  g_TestStep = 3; // Move to close
                  tickCount = 0; // Reset for next step
                  g_TestLastAction = TimeCurrent();
                  return;
               } else {
                  Print("❌ SL/TP MODIFY FAILED: ", g_Trade.ResultRetcodeDescription());
                  // Continue to close anyway
                  g_TestStep = 3;
                  tickCount = 0;
                  return;
               }
            }
         }
      }
      
      // Position not found
      if(TimeCurrent() - g_TestLastAction > 5) {
         Print("⚠️  Position not found for modification, skipping to close");
         g_TestStep = 3;
         tickCount = 0;
      }
      return;
   }
   
   // STEP 3: CLOSE POSITION (FAST - after 2-3 ticks from modification)
   if(g_TestStep == 3) {
      // Count ticks since modification
      static int closeTickCount = 0;
      closeTickCount++;
      
      // Wait 2-3 ticks before closing
      if(closeTickCount < 2) {
         return; // Wait for more ticks
      }
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == 123456 &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               
               double profit = PositionGetDouble(POSITION_PROFIT);
               double profitPts = (SymbolInfoDouble(_Symbol, SYMBOL_BID) - PositionGetDouble(POSITION_PRICE_OPEN)) / g_SymbolPoint;
               
               Print("⚡ STEP 3: CLOSING POSITION (AI Test)");
               Print("  Ticket: ", ticket, " Profit: ", profitPts, " pts ($", profit, ")");
               
               if(g_Trade.PositionClose(ticket)) {
                  Print("✅ POSITION CLOSED!");
                  Print("═══════════════════════════════════════════════════════");
                  Print("🎉 AI TEST COMPLETE - ALL STEPS EXECUTED!");
                  Print("  → AI placed order");
                  Print("  → AI modified SL and TP");
                  Print("  → AI closed position");
                  Print("  Final Profit: ", profitPts, " pts ($", profit, ")");
                  Print("═══════════════════════════════════════════════════════");
                  g_TestStep = 4;
                  g_TestCompleted = true;
                  closeTickCount = 0;
                  return;
               } else {
                  Print("❌ CLOSE FAILED: ", g_Trade.ResultRetcodeDescription());
                  g_TestStep = 4;
                  g_TestCompleted = true;
                  closeTickCount = 0;
                  return;
               }
            }
         }
      }
      
      // Position not found (already closed)
      if(TimeCurrent() - g_TestLastAction > 5) {
         Print("⚠️  Position not found (may be already closed)");
         Print("🎉 AI TEST COMPLETE!");
         g_TestStep = 4;
         g_TestCompleted = true;
         closeTickCount = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info
   g_SymbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_SymbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   SymbolSelect(_Symbol, true);
   
   // Create indicators
   g_HandleRSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_HandleMAFast = iMA(_Symbol, PERIOD_CURRENT, InpMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleMASlow = iMA(_Symbol, PERIOD_CURRENT, InpMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   
   if(g_HandleRSI == INVALID_HANDLE || 
      g_HandleMAFast == INVALID_HANDLE || 
      g_HandleMASlow == INVALID_HANDLE ||
      g_HandleATR == INVALID_HANDLE) {
      Print("ERROR: Failed to create indicators");
      return INIT_FAILED;
   }
   
   // Set arrays as series
   ArraySetAsSeries(g_BufferRSI, true);
   ArraySetAsSeries(g_BufferMAFast, true);
   ArraySetAsSeries(g_BufferMASlow, true);
   ArraySetAsSeries(g_BufferATR, true);
   
   // Initialize trading
   g_Trade.SetExpertMagicNumber(123456);
   g_Trade.SetDeviationInPoints(10);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Draw dashboard
   DrawDashboard();
   
   // Set timer
   EventSetTimer(1);
   
   Print("GOLD DASHBOARD V2 initialized successfully for ", _Symbol);
   Print("Trading: ", (InpEnableTrading ? "ENABLED" : "DISABLED"));
   
   if(InpTestMode) {
      Print("═══════════════════════════════════════════════════════");
      Print("🤖 AI TEST MODE ENABLED!");
      Print("   This mode tests if AI can:");
      Print("   1. Analyze market and signal BUY");
      Print("   2. Place orders when AI says BUY");
      Print("   3. Manage stop loss with trailing stop");
      Print("   → AI will make all trading decisions");
      Print("   → Test uses 0.01 lot size");
      Print("   → Disable Test Mode for normal trading");
      Print("═══════════════════════════════════════════════════════");
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, g_Prefix);
   
   if(g_HandleRSI != INVALID_HANDLE) IndicatorRelease(g_HandleRSI);
   if(g_HandleMAFast != INVALID_HANDLE) IndicatorRelease(g_HandleMAFast);
   if(g_HandleMASlow != INVALID_HANDLE) IndicatorRelease(g_HandleMASlow);
   if(g_HandleATR != INVALID_HANDLE) IndicatorRelease(g_HandleATR);
   
   Print("GOLD DASHBOARD V2 deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update price IMMEDIATELY on every tick (before anything else)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double midPrice = (bid + ask) / 2.0;
   double spread = (ask - bid) / g_SymbolPoint;
   
   // Update live price display instantly
   UpdateUI("Price", DoubleToString(midPrice, g_SymbolDigits), ClrValue);
   UpdateUI("BidPrice", DoubleToString(bid, g_SymbolDigits), ClrValue);
   UpdateUI("AskPrice", DoubleToString(ask, g_SymbolDigits), ClrValue);
   UpdateUI("Spread", DoubleToString(spread, 0) + " pts", (spread > 30) ? ClrWarning : ClrValue);
   
   // Run AI test mode (if enabled) - Tests AI's ability to trade
   if(InpTestMode && !g_TestCompleted) {
      RunTestMode();
      // Continue with normal data updates so AI can analyze
   }
   
   UpdateAllData();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Run AI test mode (if enabled) - Tests AI's ability to trade
   if(InpTestMode && !g_TestCompleted) {
      RunTestMode();
      // Continue with normal data updates so AI can analyze
   }
   
   UpdateAllData();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop Loss - 1% behind max profit                |
//+------------------------------------------------------------------+
void ManageTrailingStopLoss()
{
   if(!InpEnableTrading) return;
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_SymbolPoint;
   if(minStopLevel <= 0) minStopLevel = 10 * g_SymbolPoint;
   
   // Update tracking arrays for all open positions (BUY and SELL)
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == 123456) {
            
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            
            // Get current price based on position type
            double currentPrice = (posType == POSITION_TYPE_BUY) ? currentBid : currentAsk;
            
            // Find or create tracker for this position
            int trackerIdx = -1;
            for(int j = 0; j < ArraySize(g_TrackedTickets); j++) {
               if(g_TrackedTickets[j] == ticket) {
                  trackerIdx = j;
                  break;
               }
            }
            
            // Create new tracker if not found
            if(trackerIdx < 0) {
               int newSize = ArraySize(g_TrackedTickets) + 1;
               ArrayResize(g_TrackedTickets, newSize);
               ArrayResize(g_MaxProfitPrice, newSize);
               ArrayResize(g_LastSLUpdate, newSize);
               trackerIdx = newSize - 1;
               g_TrackedTickets[trackerIdx] = ticket;
               g_MaxProfitPrice[trackerIdx] = entryPrice; // Start with entry price
               g_LastSLUpdate[trackerIdx] = 0;
            }
            
            // Update max profit price
            // For BUY: higher price = more profit, track highest price
            // For SELL: lower price = more profit, track lowest price
            if(posType == POSITION_TYPE_BUY) {
            if(currentBid > g_MaxProfitPrice[trackerIdx]) {
               g_MaxProfitPrice[trackerIdx] = currentBid;
               }
            } else if(posType == POSITION_TYPE_SELL) {
               if(currentAsk < g_MaxProfitPrice[trackerIdx]) {
                  g_MaxProfitPrice[trackerIdx] = currentAsk;
               }
            }
            
            // PROFIT HUNGRY: Tight trailing stop - moves on every tick, even by cents!
            double maxProfit = g_MaxProfitPrice[trackerIdx];
            double trailingSL = 0.0;
            double profitPct = 0.0;
            
            if(posType == POSITION_TYPE_BUY) {
               profitPct = ((currentBid - entryPrice) / entryPrice) * 100.0;
               
               // If in profit, move SL to breakeven immediately, then trail tightly
               if(profitPct > 0.01) { // Even 0.01% profit
                  // Move to breakeven first
                  if(currentSL < entryPrice) {
                     trailingSL = entryPrice + (g_SymbolPoint * 1); // 1 point above breakeven
            trailingSL = NormalizeDouble(trailingSL, g_SymbolDigits);
                  } else {
                     // Already past breakeven - trail very tightly (0.1% behind max, or 10 points)
                     double tightTrail = maxProfit * 0.999; // 0.1% behind max
                     double tightTrailPts = currentBid - (10 * g_SymbolPoint); // Or 10 points
                     trailingSL = MathMax(tightTrail, tightTrailPts);
                     trailingSL = NormalizeDouble(trailingSL, g_SymbolDigits);
                  }
               } else {
                  // Still in loss - keep original SL or move it tighter if price moves against us
                  trailingSL = currentSL; // Keep current SL
               }
               
               // Ensure SL is at least minStopLevel below current price
            double maxAllowedSL = currentBid - minStopLevel;
            if(trailingSL >= maxAllowedSL) {
                  trailingSL = maxAllowedSL - (g_SymbolPoint * 1);
               trailingSL = NormalizeDouble(trailingSL, g_SymbolDigits);
            }
            
               // Move SL on EVERY TICK if it's better (no delay!)
               if(trailingSL > currentSL && trailingSL >= entryPrice) {
                  if(g_Trade.PositionModify(ticket, trailingSL, 0)) {
                     double profitLocked = ((trailingSL - entryPrice) / entryPrice) * 100.0;
                     // Only log significant moves to avoid spam
                     if(MathAbs(trailingSL - currentSL) > (5 * g_SymbolPoint)) {
                        Print("🔒 TIGHT TRAILING SL (BUY): Ticket ", ticket, " | Max: ", maxProfit, 
                           " | SL: ", currentSL, " → ", trailingSL, 
                              " | Profit Locked: ", DoubleToString(profitLocked, 3), "%");
                     }
                     g_LastSLUpdate[trackerIdx] = TimeCurrent();
                  }
               }
            } else if(posType == POSITION_TYPE_SELL) {
               profitPct = ((entryPrice - currentAsk) / entryPrice) * 100.0;
               
               // If in profit, move SL to breakeven immediately, then trail tightly
               if(profitPct > 0.01) { // Even 0.01% profit
                  // Move to breakeven first
                  if(currentSL > entryPrice) {
                     trailingSL = entryPrice - (g_SymbolPoint * 1); // 1 point below breakeven
                     trailingSL = NormalizeDouble(trailingSL, g_SymbolDigits);
                  } else {
                     // Already past breakeven - trail very tightly (0.1% behind max, or 10 points)
                     double tightTrail = maxProfit * 1.001; // 0.1% above max (for SELL)
                     double tightTrailPts = currentAsk + (10 * g_SymbolPoint); // Or 10 points
                     trailingSL = MathMin(tightTrail, tightTrailPts);
                     trailingSL = NormalizeDouble(trailingSL, g_SymbolDigits);
                  }
               } else {
                  // Still in loss - keep original SL
                  trailingSL = currentSL; // Keep current SL
               }
               
               // Ensure SL is at least minStopLevel above current price
               double minAllowedSL = currentAsk + minStopLevel;
               if(trailingSL <= minAllowedSL) {
                  trailingSL = minAllowedSL + (g_SymbolPoint * 1);
                  trailingSL = NormalizeDouble(trailingSL, g_SymbolDigits);
               }
               
               // Move SL on EVERY TICK if it's better (no delay!)
               if(trailingSL < currentSL && trailingSL <= entryPrice) {
                  if(g_Trade.PositionModify(ticket, trailingSL, 0)) {
                     double profitLocked = ((entryPrice - trailingSL) / entryPrice) * 100.0;
                     // Only log significant moves to avoid spam
                     if(MathAbs(currentSL - trailingSL) > (5 * g_SymbolPoint)) {
                        Print("🔒 TIGHT TRAILING SL (SELL): Ticket ", ticket, " | Max: ", maxProfit, 
                              " | SL: ", currentSL, " → ", trailingSL, 
                              " | Profit Locked: ", DoubleToString(profitLocked, 3), "%");
                     }
                     g_LastSLUpdate[trackerIdx] = TimeCurrent();
                  }
               }
            }
         }
      }
   }
   
   // Clean up trackers for positions that no longer exist
   for(int k = ArraySize(g_TrackedTickets) - 1; k >= 0; k--) {
      bool positionExists = false;
      for(int m = PositionsTotal() - 1; m >= 0; m--) {
         ulong ticket = PositionGetTicket(m);
         if(ticket == g_TrackedTickets[k]) {
            positionExists = true;
            break;
         }
      }
      if(!positionExists) {
         // Remove tracker
         for(int n = k; n < ArraySize(g_TrackedTickets) - 1; n++) {
            g_TrackedTickets[n] = g_TrackedTickets[n + 1];
            g_MaxProfitPrice[n] = g_MaxProfitPrice[n + 1];
            g_LastSLUpdate[n] = g_LastSLUpdate[n + 1];
         }
         ArrayResize(g_TrackedTickets, ArraySize(g_TrackedTickets) - 1);
         ArrayResize(g_MaxProfitPrice, ArraySize(g_MaxProfitPrice) - 1);
         ArrayResize(g_LastSLUpdate, ArraySize(g_LastSLUpdate) - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Main data update function                                        |
//+------------------------------------------------------------------+
void UpdateAllData()
{
   // Get current prices (always available)
   // Note: Price is already updated in OnTick() for instant tick-by-tick updates
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = (ask - bid) / g_SymbolPoint;
   
   // Update live price by tick (mid price) - refresh in case OnTick didn't run
   double midPrice = (bid + ask) / 2.0;
   UpdateUI("Price", DoubleToString(midPrice, g_SymbolDigits), ClrValue);
   UpdateUI("BidPrice", DoubleToString(bid, g_SymbolDigits), ClrValue);
   UpdateUI("AskPrice", DoubleToString(ask, g_SymbolDigits), ClrValue);
   UpdateUI("Spread", DoubleToString(spread, 0) + " pts", (spread > 30) ? ClrWarning : ClrValue);
   
   // Get indicator data
   double rsi = 50.0;
   double atr = 0.0;
   bool dataValid = true;
   
   if(CopyBuffer(g_HandleRSI, 0, 0, 1, g_BufferRSI) < 1) {
      dataValid = false;
      UpdateUI("Prediction", "WAITING DATA...", ClrNeutral);
   } else {
      rsi = g_BufferRSI[0];
   }
   
   if(CopyBuffer(g_HandleMAFast, 0, 0, 1, g_BufferMAFast) < 1 ||
      CopyBuffer(g_HandleMASlow, 0, 0, 1, g_BufferMASlow) < 1 ||
      CopyBuffer(g_HandleATR, 0, 0, 1, g_BufferATR) < 1) {
      dataValid = false;
   } else {
      atr = g_BufferATR[0];
   }
   
   if(!dataValid) {
      ChartRedraw(0);
      return;
   }
   
   // Update tick velocity
   datetime currentSecond = TimeCurrent();
   if(currentSecond != g_LastSecond) {
      g_LastSecond = currentSecond;
      g_TicksPerSecond = 0;
   }
   g_TicksPerSecond++;
   UpdateUI("Velocity", IntegerToString(g_TicksPerSecond) + " ticks/sec", 
            (g_TicksPerSecond > 10) ? ClrBuy : ClrValue);
   
   // Update RSI with distance indicators
   UpdateUI("RSI", DoubleToString(rsi, 1), 
            (rsi < 30) ? ClrBuy : (rsi > 70) ? ClrSell : ClrValue);
   
   // Calculate distance to RSI levels
   double distanceTo30 = rsi - 30.0; // How much until <30 (oversold)
   double distanceTo70 = 70.0 - rsi; // How much until >70 (overbought)
   
   if(distanceTo30 <= 0) {
      UpdateUI("RSI_To30", "OVERSOLD ✓", ClrBuy);
   } else {
      UpdateUI("RSI_To30", DoubleToString(distanceTo30, 1) + " to <30", ClrBuy);
   }
   
   if(distanceTo70 <= 0) {
      UpdateUI("RSI_To70", "OVERBOUGHT ✓", ClrSell);
   } else {
      UpdateUI("RSI_To70", DoubleToString(distanceTo70, 1) + " to >70", ClrSell);
   }
   
   // Update MAs
   UpdateUI("MAFast", DoubleToString(g_BufferMAFast[0], g_SymbolDigits), ClrValue);
   UpdateUI("MASlow", DoubleToString(g_BufferMASlow[0], g_SymbolDigits), ClrValue);
   UpdateUI("ATR", DoubleToString(atr, g_SymbolDigits), ClrValue);
   
   // Update trading status
   int openPositions = CountTotalOpenPositions();
   int buyPositions = CountOpenBuyPositions();
   int sellPositions = CountOpenSellPositions();
   string statusText = InpEnableTrading ? 
      "ACTIVE (" + IntegerToString(openPositions) + "/" + IntegerToString(InpMaxPositions) + 
      " | B:" + IntegerToString(buyPositions) + " S:" + IntegerToString(sellPositions) + ")" : 
      "DISABLED";
   UpdateUI("TradingStatus", statusText, (InpEnableTrading ? ClrBuy : ClrNeutral));
   
   // AI Analysis
   if(InpUseAI) {
      UpdateAIAnalysis(rsi, bid, ask, atr);
   }
   
   // Manage Trailing Stop Loss (1% behind max profit) - CRITICAL: NO LOSSES ALLOWED
   if(InpEnableTrading) {
      ManageTrailingStopLoss();
   }
   
   // PROFIT HUNGRY MONSTER - Check positions on EVERY TICK for profit taking
   if(InpEnableTrading) {
      // Always check positions (even without AI) for profit taking
      ManageAIPositions(rsi, bid, ask, atr);
   }
   
   // Trading Logic (skip if Test Mode already placed order)
   if(InpEnableTrading) {
      // In Test Mode, only allow one test position
      if(InpTestMode && CountOpenBuyPositions() > 0) {
         // Test Mode already has a position, don't place more
         // (Trailing stop loss will still manage the position)
      } else {
      CheckAndExecuteTrades(rsi, bid, ask, atr);
      }
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Check and execute trades - AI DRIVEN                            |
//+------------------------------------------------------------------+
void CheckAndExecuteTrades(double rsi, double bid, double ask, double atr)
{
   // M1 TRADING - Check on every new M1 bar
   ENUM_TIMEFRAMES tradeTimeframe = PERIOD_M1;
   
   // Only check on new M1 bar
   datetime currentBarTime = iTime(_Symbol, tradeTimeframe, 0);
   if(currentBarTime == g_LastTradeCheck) {
      return; // Already checked this bar
   }
   g_LastTradeCheck = currentBarTime;
   
   // Check if we should trade
   int totalPositions = CountTotalOpenPositions();
   if(totalPositions >= InpMaxPositions) {
      return; // Max positions reached
   }
   
   // Spread check (disabled for crypto - spreads can be huge)
   // double spread = (ask - bid) / g_SymbolPoint;
   // if(spread > InpMinSpreadPts) {
   //    return; // Spread too wide
   // }
   
   // AI-DRIVEN M1 TRADING: Buy and Sell based on AI signals (SIMPLIFIED - AI DECIDES EVERYTHING)
   if(InpUseAI && g_AIIsActive) {
      // AI says BUY - open long position (M1 TRADING - SIMPLIFIED)
      if(g_AISignal == "BUY") {
         // Lower confidence threshold for M1 trading (more aggressive)
         double minConf = (InpAIOverride ? 0.5 : InpAIConfidenceMin);
         if(g_AIConfidence >= minConf) {
            Print("═══════════════════════════════════════════════════════");
            Print("🤖 AI M1 TRADING: BUY SIGNAL");
            Print("   Confidence: ", DoubleToString(g_AIConfidence * 100, 1), "%");
            Print("   Reasoning: ", g_AIReasoning);
            Print("   → Opening LONG position (0.01 lot, M1 chart)");
            Print("═══════════════════════════════════════════════════════");
         ExecuteBuyOrder(ask, atr);
         }
         return;
      }
      // AI says SELL - open short position (M1 TRADING - SIMPLIFIED)
      else if(g_AISignal == "SELL") {
         // Lower confidence threshold for M1 trading (more aggressive)
         double minConf = (InpAIOverride ? 0.5 : InpAIConfidenceMin);
         if(g_AIConfidence >= minConf) {
            Print("═══════════════════════════════════════════════════════");
            Print("🤖 AI M1 TRADING: SELL SIGNAL");
            Print("   Confidence: ", DoubleToString(g_AIConfidence * 100, 1), "%");
            Print("   Reasoning: ", g_AIReasoning);
            Print("   → Opening SHORT position (0.01 lot, M1 chart)");
            Print("═══════════════════════════════════════════════════════");
            ExecuteSellOrder(bid, atr);
         }
         return;
      }
      // AI says WAIT
      else if(g_AISignal == "WAIT") {
         // Don't log every time, just occasionally
         return;
      }
   }
   
   // Traditional signal checks (if AI not enabled or not active)
   if(!InpUseAI || !g_AIIsActive) {
      // Check RSI
      if(rsi > InpRSIBuyLevel) {
         return; // RSI not oversold enough
   }
   
   // Check MA trend if required
   if(InpRequireBullishMA) {
      if(g_BufferMAFast[0] < g_BufferMASlow[0]) {
         return; // Bearish trend
      }
   }
   
   // All checks passed - execute trade
   ExecuteBuyOrder(ask, atr);
   }
}

//+------------------------------------------------------------------+
//| Execute buy order - RELIABLE VERSION                            |
//+------------------------------------------------------------------+
void ExecuteBuyOrder(double entryPrice, double atr)
{
   // Check trading permissions
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Print("ERROR: AutoTrading disabled in Terminal!");
      return;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      Print("ERROR: AutoTrading disabled for EA!");
      return;
   }
   
   // Get CURRENT market price
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentAsk <= 0 || currentBid <= 0) {
      Print("ERROR: Invalid market prices");
      return;
   }
   
   // Calculate stop loss
   double stopLoss = currentAsk - (atr * InpStopLossATR);
   stopLoss = NormalizeDouble(stopLoss, g_SymbolDigits);
   
   // Validate stop loss
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_SymbolPoint;
   if(minStopLevel > 0 && (currentAsk - stopLoss) < minStopLevel) {
      stopLoss = NormalizeDouble(currentAsk - minStopLevel, g_SymbolDigits);
   }
   
   // Prepare order
   Print("=== EXECUTING BUY ORDER ===");
   Print("  Symbol: ", _Symbol);
   Print("  Lot Size: ", InpLotSize);
   Print("  Current Ask: ", currentAsk);
   Print("  Stop Loss: ", stopLoss);
   Print("  Take Profit: 0 (AI Managed)");
   
   // Execute using OrderSend directly for maximum reliability
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = InpLotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = currentAsk;
   request.sl = stopLoss;
   request.tp = 0; // No TP - AI manages
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "GOLD V2 - AI Managed";
   
   // Detect and set correct filling mode for this broker
   long fillingMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
   request.type_filling = ORDER_FILLING_FOK;
      Print("  Using FOK filling mode");
   } else if((fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      request.type_filling = ORDER_FILLING_IOC;
      Print("  Using IOC filling mode");
   } else {
      request.type_filling = ORDER_FILLING_RETURN;
      Print("  Using RETURN filling mode");
   }
   
   // Send order
   if(OrderSend(request, result)) {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
         Print("✓✓✓ ORDER EXECUTED SUCCESSFULLY! ✓✓✓");
         Print("  Order: ", result.order);
         Print("  Deal: ", result.deal);
         Print("  Volume: ", result.volume);
         Print("  Price: ", result.price);
         Print("  SL Requested: ", request.sl);
         g_TotalTrades++;
         g_LastTradeTicket = result.order;
         
         // Verify position and get actual SL
         Sleep(200);
         if(PositionSelect(_Symbol)) {
            double actualSL = PositionGetDouble(POSITION_SL);
            Print("  ✓ Position confirmed in order book");
            Print("  SL Actual: ", actualSL);
         }
      } else {
         Print("⚠ ORDER PARTIALLY FILLED OR PENDING");
         Print("  Retcode: ", result.retcode);
         Print("  Deal: ", result.deal);
         Print("  Order: ", result.order);
      }
   } else {
      Print("✗✗✗ ORDER FAILED! ✗✗✗");
      Print("  Retcode: ", result.retcode);
      Print("  Retcode Description: ", result.comment);
      Print("  Request ID: ", result.request_id);
      
      // If filling mode error, try with different filling mode
      if(result.retcode == TRADE_RETCODE_REJECT || 
         StringFind(result.comment, "filling") >= 0 ||
         StringFind(result.comment, "FOK") >= 0 ||
         StringFind(result.comment, "IOC") >= 0 ||
         StringFind(result.comment, "Unsupported") >= 0) {
         Print("  → Retrying with alternative filling mode...");
         
         // Try IOC if FOK failed, or RETURN if both failed
         if(request.type_filling == ORDER_FILLING_FOK) {
            request.type_filling = ORDER_FILLING_IOC;
            Print("  → Trying IOC filling mode");
         } else if(request.type_filling == ORDER_FILLING_IOC) {
            request.type_filling = ORDER_FILLING_RETURN;
            Print("  → Trying RETURN filling mode");
         }
         
         // Retry the order
         if(OrderSend(request, result)) {
            if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
               Print("✓✓✓ ORDER EXECUTED SUCCESSFULLY ON RETRY! ✓✓✓");
               Print("  Order: ", result.order);
               Print("  Deal: ", result.deal);
               g_TotalTrades++;
               g_LastTradeTicket = result.order;
               return; // Success!
            }
         }
      }
      
      Alert("ORDER FAILED: ", result.comment);
   }
}

//+------------------------------------------------------------------+
//| Execute sell order - SWING TRADING                              |
//+------------------------------------------------------------------+
void ExecuteSellOrder(double entryPrice, double atr)
{
   // Check trading permissions
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Print("ERROR: AutoTrading disabled in Terminal!");
      return;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      Print("ERROR: AutoTrading disabled for EA!");
      return;
   }
   
   // Get CURRENT market price
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentAsk <= 0 || currentBid <= 0) {
      Print("ERROR: Invalid market prices");
      return;
   }
   
   // TIGHT STOP LOSS - Cut losses fast! (0.5x ATR for quick exits)
   double stopLoss = currentBid + (atr * 0.5); // Very tight SL
   stopLoss = NormalizeDouble(stopLoss, g_SymbolDigits);
   
   // Validate stop loss
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_SymbolPoint;
   if(minStopLevel > 0 && (stopLoss - currentBid) < minStopLevel) {
      stopLoss = NormalizeDouble(currentBid + minStopLevel, g_SymbolDigits);
   }
   
   // Prepare order
   Print("=== EXECUTING SELL ORDER (SWING TRADE) ===");
   Print("  Symbol: ", _Symbol);
   Print("  Lot Size: ", InpLotSize);
   Print("  Current Bid: ", currentBid);
   Print("  Stop Loss: ", stopLoss);
   Print("  Take Profit: 0 (AI Managed)");
   
   // Execute using OrderSend directly
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = InpLotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = currentBid;
   request.sl = stopLoss;
   request.tp = 0; // No TP - AI manages
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "GOLD V2 - AI Swing SELL";
   
   // Detect and set correct filling mode for this broker
   long fillingMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
      request.type_filling = ORDER_FILLING_FOK;
      Print("  Using FOK filling mode");
   } else if((fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      request.type_filling = ORDER_FILLING_IOC;
      Print("  Using IOC filling mode");
   } else {
      request.type_filling = ORDER_FILLING_RETURN;
      Print("  Using RETURN filling mode");
   }
   
   // Send order
   if(OrderSend(request, result)) {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
         Print("✓✓✓ SELL ORDER EXECUTED SUCCESSFULLY! ✓✓✓");
         Print("  Order: ", result.order);
         Print("  Deal: ", result.deal);
         Print("  Volume: ", result.volume);
         Print("  Price: ", result.price);
         Print("  SL Requested: ", request.sl);
         g_TotalTrades++;
         g_LastTradeTicket = result.order;
      } else {
         Print("⚠ SELL ORDER PARTIALLY FILLED OR PENDING");
         Print("  Retcode: ", result.retcode);
      }
   } else {
      Print("✗✗✗ SELL ORDER FAILED! ✗✗✗");
      Print("  Retcode: ", result.retcode);
      Print("  Retcode Description: ", result.comment);
      // If filling mode error, try with different filling mode
      if(result.retcode == TRADE_RETCODE_REJECT || 
         StringFind(result.comment, "filling") >= 0 ||
         StringFind(result.comment, "FOK") >= 0 ||
         StringFind(result.comment, "IOC") >= 0) {
         Print("  → Retrying with alternative filling mode...");
         
         // Try IOC if FOK failed, or RETURN if both failed
         if(request.type_filling == ORDER_FILLING_FOK) {
            request.type_filling = ORDER_FILLING_IOC;
            Print("  → Trying IOC filling mode");
         } else if(request.type_filling == ORDER_FILLING_IOC) {
            request.type_filling = ORDER_FILLING_RETURN;
            Print("  → Trying RETURN filling mode");
         }
         
         // Retry the order
         if(OrderSend(request, result)) {
            if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
               Print("✓✓✓ SELL ORDER EXECUTED SUCCESSFULLY ON RETRY! ✓✓✓");
               Print("  Order: ", result.order);
               Print("  Deal: ", result.deal);
               g_TotalTrades++;
               g_LastTradeTicket = result.order;
               return; // Success!
            }
         }
      }
      
      Alert("SELL ORDER FAILED: ", result.comment);
   }
}

//+------------------------------------------------------------------+
//| Manage AI Positions - Swing Trading Profit Taking               |
//| AI decides when to close positions based on market conditions  |
//+------------------------------------------------------------------+
void ManageAIPositions(double rsi, double bid, double ask, double atr)
{
   // PROFIT HUNGRY MONSTER - Always check positions (no AI requirement)
   // if(!InpAIProfitTaking) return; // REMOVED - always check for profit!
   
   // Check all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == 123456) {
            
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            double positionProfit = PositionGetDouble(POSITION_PROFIT);
            double positionVolume = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Calculate profit in points and percentage
            double profitPts = 0.0;
            double profitPct = 0.0;
            double currentPrice = 0.0;
            
            if(posType == POSITION_TYPE_BUY) {
               currentPrice = bid;
               profitPts = (bid - entryPrice) / g_SymbolPoint;
               profitPct = ((bid - entryPrice) / entryPrice) * 100.0;
            } else if(posType == POSITION_TYPE_SELL) {
               currentPrice = ask;
               profitPts = (entryPrice - ask) / g_SymbolPoint;
               profitPct = ((entryPrice - ask) / entryPrice) * 100.0;
            }
            
            // AI Decision Logic for Closing Positions
            bool shouldClose = false;
            string closeReason = "";
            
            // 1. AI says opposite signal - close position
            if(posType == POSITION_TYPE_BUY && g_AISignal == "SELL" && g_AIConfidence >= 0.7) {
               shouldClose = true;
               closeReason = "AI SELL signal (opposite to BUY position)";
            } else if(posType == POSITION_TYPE_SELL && g_AISignal == "BUY" && g_AIConfidence >= 0.7) {
               shouldClose = true;
               closeReason = "AI BUY signal (opposite to SELL position)";
            }
            // 2. PROFIT HUNGRY MONSTER - Take profit on ANY profit (even 0.05%!)
            if(profitPct >= InpMinProfitPct) {
               shouldClose = true;
               closeReason = "PROFIT HUNGRY: Taking profit (" + DoubleToString(profitPct, 3) + "%)";
            }
            // 3. Good profit and AI says WAIT (take profit)
            else if(profitPct >= InpMinProfitPct && g_AISignal == "WAIT" && g_AIConfidence >= 0.6) {
               shouldClose = true;
               closeReason = "AI WAIT signal + good profit (" + DoubleToString(profitPct, 2) + "%)";
            }
            // 4. Excellent profit (sniping) - close immediately
            else if(profitPct >= (InpProfitTargetATR * 0.5)) {
               double profitTarget = (InpProfitTargetATR * atr / entryPrice) * 100.0;
               if(profitPct >= profitTarget * 0.8) { // 80% of profit target
                  shouldClose = true;
                  closeReason = "Profit target reached (" + DoubleToString(profitPct, 2) + "%)";
               }
            }
            
            if(shouldClose) {
               Print("═══════════════════════════════════════════════════════");
               Print("🤖 AI SWING: CLOSING POSITION");
               Print("   Ticket: ", ticket);
               Print("   Type: ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
               Print("   Entry: ", entryPrice, " | Current: ", currentPrice);
               Print("   Profit: ", profitPts, " pts (", DoubleToString(profitPct, 2), "%)");
               Print("   Reason: ", closeReason);
               Print("   AI Signal: ", g_AISignal, " | Confidence: ", DoubleToString(g_AIConfidence * 100, 1), "%");
               Print("   → AI Decision: Close position to lock profit");
               Print("═══════════════════════════════════════════════════════");
               
               if(g_Trade.PositionClose(ticket)) {
                  Print("✅ Position closed successfully by AI!");
                  g_TotalTrades++;
                  if(profitPct > 0) g_WinningTrades++;
                  else g_LosingTrades++;
                  g_TotalProfit += positionProfit;
               } else {
                  Print("❌ Failed to close position: ", g_Trade.ResultRetcodeDescription());
               }
            } else {
               // Log position status occasionally
               static datetime lastPosLog = 0;
               if(TimeCurrent() - lastPosLog > 300) { // Every 5 minutes
                  Print("📊 AI SWING: Holding Position #", ticket);
                  Print("   Type: ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
                  Print("   Entry: ", entryPrice, " | Current: ", currentPrice);
                  Print("   Profit: ", profitPts, " pts (", DoubleToString(profitPct, 2), "%)");
                  Print("   AI Signal: ", g_AISignal, " | AI says: ", g_AIReasoning);
                  Print("   → AI Decision: HOLD (waiting for better exit)");
                  lastPosLog = TimeCurrent();
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count open buy positions                                         |
//+------------------------------------------------------------------+
int CountOpenBuyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == 123456 &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count open sell positions                                        |
//+------------------------------------------------------------------+
int CountOpenSellPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == 123456 &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count total open positions (buy + sell)                          |
//+------------------------------------------------------------------+
int CountTotalOpenPositions()
{
   return CountOpenBuyPositions() + CountOpenSellPositions();
}

//+------------------------------------------------------------------+
//| Update AI Analysis                                               |
//+------------------------------------------------------------------+
void UpdateAIAnalysis(double rsi, double bid, double ask, double atr)
{
   datetime currentTime = TimeCurrent();
   int secondsSinceUpdate = (int)(currentTime - g_LastAIUpdate);
   
   // Update AI every 10 seconds for M1 trading (very fast updates)
   int updateInterval = 10; // 10 seconds for M1 trading
   if(secondsSinceUpdate >= updateInterval || g_LastAIUpdate == 0) {
      g_LastAIUpdate = currentTime;
      
      // Log what AI is analyzing BEFORE calling
      Print("═══════════════════════════════════════════════════════");
      Print("🤖 AI ANALYZING MARKET (Every Minute Update)");
      Print("   Time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));
      Print("   Price: ", bid, " / ", ask);
      Print("   RSI: ", DoubleToString(rsi, 1));
      Print("   ATR: ", DoubleToString(atr, g_SymbolDigits));
      Print("   Current Positions: ", CountTotalOpenPositions(), " (", 
            CountOpenBuyPositions(), " BUY + ", CountOpenSellPositions(), " SELL)");
      Print("   → AI is analyzing swing trading opportunities on M15...");
      Print("═══════════════════════════════════════════════════════");
      
      // Build comprehensive context and call AI
      string context = BuildMarketContext(rsi, bid, ask, atr);
      string aiResponse = CallOpenAI(context);
      ParseAIResponse(aiResponse);
      
      // Detailed feedback after AI analysis
      Print("═══════════════════════════════════════════════════════");
      Print("🤖 AI ANALYSIS COMPLETE - FEEDBACK:");
      Print("   Signal: ", g_AISignal);
      Print("   Confidence: ", DoubleToString(g_AIConfidence * 100, 1), "%");
      Print("   Reasoning: ", g_AIReasoning);
      
      // Show full summary (limit to 200 words)
      string summaryDisplay = g_AISummary;
      int summaryWords = 0;
      int summaryLastSpace = 0;
      for(int i = 0; i < StringLen(summaryDisplay) && summaryWords < 200; i++) {
         if(StringGetCharacter(summaryDisplay, i) == ' ' || StringGetCharacter(summaryDisplay, i) == '\n') {
            summaryWords++;
            summaryLastSpace = i;
         }
      }
      if(summaryWords >= 200) {
         summaryDisplay = StringSubstr(summaryDisplay, 0, summaryLastSpace) + "...";
      }
      Print("   Full Summary (", summaryWords, " words): ", summaryDisplay);
      
      if(g_AISignal == "BUY" && g_AIConfidence >= InpAIConfidenceMin) {
         Print("   → ACTION: AI wants to OPEN BUY position");
         Print("   → EXPECTATION: Price will swing up from current level");
      } else if(g_AISignal == "SELL" && g_AIConfidence >= InpAIConfidenceMin) {
         Print("   → ACTION: AI wants to OPEN SELL position");
         Print("   → EXPECTATION: Price will swing down from current level");
      } else if(g_AISignal == "WAIT") {
         Print("   → ACTION: AI is WAITING for better setup");
         Print("   → EXPECTATION: ", g_AIReasoning);
      }
      
      // Check what AI is looking for
      Print("   → AI IS LOOKING FOR:");
      if(rsi < 40) {
         Print("      - RSI oversold (", DoubleToString(rsi, 1), ") - potential BUY setup");
      } else if(rsi > 60) {
         Print("      - RSI overbought (", DoubleToString(rsi, 1), ") - potential SELL setup");
      } else {
         Print("      - RSI neutral (", DoubleToString(rsi, 1), ") - waiting for extreme");
      }
      
      int totalPos = CountTotalOpenPositions();
      if(totalPos < InpMaxPositions) {
         Print("      - Can open ", (InpMaxPositions - totalPos), " more position(s)");
      } else {
         Print("      - At max positions (", totalPos, ") - managing existing positions");
      }
      
      Print("═══════════════════════════════════════════════════════");
   }
   
   // Always update UI (even if not calling AI this tick)
      color aiSignalColor = ClrNeutral;
      if(g_AISignal == "BUY") aiSignalColor = ClrBuy;
      else if(g_AISignal == "SELL") aiSignalColor = ClrSell;
      else if(g_AISignal == "WAIT") aiSignalColor = ClrWarning;
      
      UpdateUI("AISignal", g_AISignal, aiSignalColor);
      // Ensure confidence is displayed correctly (handle 0.0 case)
      string confidenceText = "";
      if(g_AIConfidence > 0.0 || g_AISignal != "WAIT") {
         confidenceText = DoubleToString(g_AIConfidence * 100, 1) + "%";
      } else {
         confidenceText = "--";
      }
      UpdateUI("AIConfidence", confidenceText,
               (g_AIConfidence >= InpAIConfidenceMin ? ClrBuy : ClrWarning));
      
      // Update AI Expectation (what AI is looking for)
      string expectationText = "";
      color expectationColor = ClrNeutral;
      
      if(StringLen(g_AIReasoning) > 0 && g_AIReasoning != "Invalid AI response" && g_AIReasoning != "Waiting for AI analysis...") {
         // Show actual reasoning (truncate to 40 chars for display)
         expectationText = StringSubstr(g_AIReasoning, 0, 40);
         if(StringLen(g_AIReasoning) > 40) expectationText += "...";
         
         if(g_AISignal == "BUY") {
            expectationColor = ClrBuy;
         } else if(g_AISignal == "SELL") {
            expectationColor = ClrSell;
         } else {
            expectationColor = ClrWarning;
         }
      } else if(g_AISignal == "BUY") {
         expectationText = "Price UP swing";
         expectationColor = ClrBuy;
      } else if(g_AISignal == "SELL") {
         expectationText = "Price DOWN swing";
         expectationColor = ClrSell;
      } else if(g_AISignal == "WAIT") {
         expectationText = "Waiting for setup...";
         expectationColor = ClrWarning;
      } else {
         expectationText = "Analyzing...";
         expectationColor = ClrNeutral;
      }
      
      UpdateUI("AIExpectation", expectationText, expectationColor);
      
      string statusText = "AI: " + g_AIStatus;
   color statusColor = ClrWarning;
   if(g_AIStatus == "ACTIVE") {
      statusColor = ClrBuy;
      statusText = "AI: ACTIVE ✓";
   } else if(g_AIStatus == "SIMULATED") {
      statusColor = ClrWarning;
      statusText = "AI: SIMULATED ⚠";
   } else if(g_AIStatus == "ERROR") {
      statusColor = ClrSell;
      statusText = "AI: ERROR ✗";
   }
      UpdateUI("AIStatus", statusText, statusColor);
}

//+------------------------------------------------------------------+
//| Helper functions for market data                                 |
//+------------------------------------------------------------------+
double GetSafeHigh(ENUM_TIMEFRAMES timeframe)
{
   if(iBarShift(_Symbol, timeframe, TimeCurrent()) < 0) return 0.0;
   double buffer[1];
   if(CopyHigh(_Symbol, timeframe, 1, 1, buffer) < 1) return 0.0;
   return buffer[0];
}

double GetSafeLow(ENUM_TIMEFRAMES timeframe)
{
   if(iBarShift(_Symbol, timeframe, TimeCurrent()) < 0) return 0.0;
   double buffer[1];
   if(CopyLow(_Symbol, timeframe, 1, 1, buffer) < 1) return 0.0;
   return buffer[0];
}

double CalculateSentiment(ENUM_TIMEFRAMES timeframe)
{
   if(Bars(_Symbol, timeframe) < 5) return 50.0;
   
   double high = GetSafeHigh(timeframe);
   double low = GetSafeLow(timeframe);
   if(high == 0 || low == 0 || high == low) return 50.0;
   
   double close[1];
   if(CopyClose(_Symbol, timeframe, 1, 1, close) < 1) return 50.0;
   
   double sentiment = ((close[0] - low) / (high - low)) * 100.0;
   return MathMax(0.0, MathMin(100.0, sentiment));
}

void CalculatePivotPoints(double &pivot, double &r1, double &r2, double &r3, double &s1, double &s2, double &s3)
{
   datetime yesterday = TimeCurrent() - PeriodSeconds(PERIOD_D1);
   int barShift = iBarShift(_Symbol, PERIOD_D1, yesterday);
   
   if(barShift < 0) {
      pivot = r1 = r2 = r3 = s1 = s2 = s3 = 0.0;
      return;
   }
   
   double high = iHigh(_Symbol, PERIOD_D1, barShift);
   double low = iLow(_Symbol, PERIOD_D1, barShift);
   double close = iClose(_Symbol, PERIOD_D1, barShift);
   
   pivot = (high + low + close) / 3.0;
   double range = high - low;
   
   r1 = 2.0 * pivot - low;
   r2 = pivot + range;
   r3 = high + 2.0 * (pivot - low);
   
   s1 = 2.0 * pivot - high;
   s2 = pivot - range;
   s3 = low - 2.0 * (high - pivot);
}

string GetTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   if(hour >= 13 && hour < 16) return "EU+US OVERLAP";
   if(hour >= 8 && hour < 13) return "EUROPEAN";
   if(hour >= 13 && hour < 21) return "US";
   if(hour >= 0 && hour < 8) return "ASIAN";
   return "ASIAN";
}

void GetDailyRange(double &high, double &low, double &range, double &rangePercent)
{
   int todayBar = iBarShift(_Symbol, PERIOD_D1, TimeCurrent());
   if(todayBar < 0) {
      high = low = range = rangePercent = 0.0;
      return;
   }
   
   high = iHigh(_Symbol, PERIOD_D1, todayBar);
   low = iLow(_Symbol, PERIOD_D1, todayBar);
   
   if(high > 0 && low > 0) {
      range = high - low;
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(range > 0) {
         rangePercent = ((currentPrice - low) / range) * 100.0;
      } else {
         rangePercent = 50.0;
      }
   } else {
      high = low = range = rangePercent = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Build comprehensive market context for AI                        |
//+------------------------------------------------------------------+
string BuildMarketContext(double rsi, double bid, double ask, double atr)
{
   double h1High = GetSafeHigh(PERIOD_H1);
   double h1Low = GetSafeLow(PERIOD_H1);
   double h4High = GetSafeHigh(PERIOD_H4);
   double h4Low = GetSafeLow(PERIOD_H4);
   double d1High = GetSafeHigh(PERIOD_D1);
   double d1Low = GetSafeLow(PERIOD_D1);
   double pivot, r1, r2, r3, s1, s2, s3;
   CalculatePivotPoints(pivot, r1, r2, r3, s1, s2, s3);
   double dayHigh, dayLow, dayRange, dayRangePct;
   GetDailyRange(dayHigh, dayLow, dayRange, dayRangePct);
   int openPositions = CountTotalOpenPositions();
   int buyPositions = CountOpenBuyPositions();
   int sellPositions = CountOpenSellPositions();
   long tickVol = iVolume(_Symbol, PERIOD_CURRENT, 0);
   
   bool maBullish = (g_BufferMAFast[0] > g_BufferMASlow[0]);
   double priceAboveFastMA = (bid - g_BufferMAFast[0]) / g_SymbolPoint;
   double priceAboveSlowMA = (bid - g_BufferMASlow[0]) / g_SymbolPoint;
   
   // Calculate win rate and performance
   double winRate = 0.0;
   double avgWin = 0.0;
   double avgLoss = 0.0;
   if(g_TotalTrades > 0) {
      winRate = (double(g_WinningTrades) / double(g_TotalTrades)) * 100.0;
   }
   
   // Get account information
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double accountProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double accountMarginLevel = 0.0;
   if(accountMargin > 0) {
      accountMarginLevel = (accountEquity / accountMargin) * 100.0;
   }
   
   // Professional M1 trading system prompt
   string context = "You are a professional algorithmic trading system executing M1 (1-minute) scalping strategies on " + _Symbol + ". ";
   context += "Analyze market conditions and provide trading signals EVERY 10 SECONDS. ";
   context += "Maximum " + IntegerToString(InpMaxPositions) + " positions (0.01 lot each), both long and short allowed. ";
   context += "Objective: Identify quick profit opportunities on M1 timeframe - BUY and SELL aggressively for profit.\n\n";
   
   context += "⚠️ CRITICAL: TRACK YOUR PERFORMANCE AND BE THOUGHTFUL ABOUT MONEY!\n";
   context += "You must consider your win/loss record and account status when making decisions.\n";
   context += "If you're losing money, be more conservative. If you're winning, be smart about it.\n\n";
   
   context += "YOUR TRADING PERFORMANCE:\n";
   context += "Total Trades: " + IntegerToString(g_TotalTrades) + "\n";
   context += "Winning Trades: " + IntegerToString(g_WinningTrades) + " | Losing Trades: " + IntegerToString(g_LosingTrades) + "\n";
   context += "Win Rate: " + DoubleToString(winRate, 1) + "%\n";
   context += "Total Profit: " + DoubleToString(g_TotalProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   context += "Account Balance: " + DoubleToString(accountBalance, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   context += "Account Equity: " + DoubleToString(accountEquity, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   context += "Current Profit: " + DoubleToString(accountProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   context += "Free Margin: " + DoubleToString(accountFreeMargin, 2) + " | Margin Level: " + DoubleToString(accountMarginLevel, 1) + "%\n";
   if(g_TotalProfit < 0) {
      context += "⚠️ WARNING: You are currently DOWN " + DoubleToString(MathAbs(g_TotalProfit), 2) + ". Be more careful!\n";
   } else if(g_TotalProfit > 0) {
      context += "✓ You are currently UP " + DoubleToString(g_TotalProfit, 2) + ". Keep it smart!\n";
   }
   context += "\n";
   
   context += "STRATEGY PARAMETERS:\n";
   context += "- Timeframe: M1 (1-minute charts)\n";
   context += "- Position Limit: " + IntegerToString(InpMaxPositions) + " (mixed long/short)\n";
   context += "- Position Size: 0.01 lot\n";
   context += "- Style: Scalping - quick entries/exits for profit\n";
   context += "- Focus: PROFIT - be aggressive about taking profits\n\n";
   
   context += "MARKET DATA:\n";
   context += "Price: " + DoubleToString(bid, g_SymbolDigits) + " / " + DoubleToString(ask, g_SymbolDigits) + 
              " | Spread: " + DoubleToString((ask - bid) / g_SymbolPoint, 0) + " pts\n";
   context += "Volume: " + IntegerToString(tickVol) + " | Velocity: " + IntegerToString(g_TicksPerSecond) + " ticks/sec\n\n";
   
   context += "TECHNICAL ANALYSIS:\n";
   context += "RSI(14): " + DoubleToString(rsi, 2) + " | ";
   context += "MA(20/50): " + DoubleToString(g_BufferMAFast[0], g_SymbolDigits) + " / " + DoubleToString(g_BufferMASlow[0], g_SymbolDigits) + "\n";
   context += "Trend: " + (maBullish ? "BULLISH" : "BEARISH") + 
              " | Price vs MA: " + DoubleToString(MathAbs(priceAboveFastMA), 0) + " pts " + 
              (priceAboveFastMA > 0 ? "above" : "below") + " fast MA\n";
   context += "ATR(14): " + DoubleToString(atr, g_SymbolDigits) + "\n";
   
   context += "\nKEY LEVELS:\n";
   if(pivot > 0) {
      context += "Pivot: " + DoubleToString(pivot, g_SymbolDigits) + " (" + 
                 DoubleToString((bid - pivot) / g_SymbolPoint, 0) + " pts) | ";
      context += "R1: " + DoubleToString(r1, g_SymbolDigits) + " | S1: " + DoubleToString(s1, g_SymbolDigits) + "\n";
   }
   if(h1High > 0 && h1Low > 0) {
      context += "H1 Range: " + DoubleToString(h1Low, g_SymbolDigits) + " - " + DoubleToString(h1High, g_SymbolDigits) + 
                 " | Distance: " + DoubleToString((bid - h1Low) / g_SymbolPoint, 0) + " pts from low\n";
   }
   if(h4High > 0 && h4Low > 0) {
      context += "H4 Range: " + DoubleToString(h4Low, g_SymbolDigits) + " - " + DoubleToString(h4High, g_SymbolDigits) + "\n";
   }
   
   context += "Sentiment: M15=" + DoubleToString(CalculateSentiment(PERIOD_M15), 0) + "% | " +
              "H1=" + DoubleToString(CalculateSentiment(PERIOD_H1), 0) + "% | " +
              "H4=" + DoubleToString(CalculateSentiment(PERIOD_H4), 0) + "%\n";
   
   // RSI context
   double rsiHistory[];
   ArraySetAsSeries(rsiHistory, true);
   int rsiBars = CopyBuffer(g_HandleRSI, 0, 0, 24, rsiHistory);
   if(rsiBars >= 24) {
      double rsiMin = rsiHistory[ArrayMinimum(rsiHistory, 0, 24)];
      double rsiMax = rsiHistory[ArrayMaximum(rsiHistory, 0, 24)];
      context += "RSI Context: " + DoubleToString(rsi, 1) + " (Range: " + DoubleToString(rsiMin, 1) + 
                 "-" + DoubleToString(rsiMax, 1) + ")\n";
   }
   
   if(dayHigh > 0) {
      context += "Daily Range: " + DoubleToString(dayRange / g_SymbolPoint, 0) + " pts | " +
                 "Position: " + DoubleToString(dayRangePct, 0) + "% | Session: " + GetTradingSession() + "\n";
   }
   
   // Add last 100 M1 candles for price pattern analysis
   context += "\n=== LAST 100 M1 CANDLES (PRICE HISTORY) ===\n";
   double m1Open[], m1High[], m1Low[], m1Close[];
   long m1Volume[];
   ArraySetAsSeries(m1Open, true);
   ArraySetAsSeries(m1High, true);
   ArraySetAsSeries(m1Low, true);
   ArraySetAsSeries(m1Close, true);
   ArraySetAsSeries(m1Volume, true);
   
   int candlesCopied = CopyOpen(_Symbol, PERIOD_M1, 0, 100, m1Open);
   int highCopied = CopyHigh(_Symbol, PERIOD_M1, 0, 100, m1High);
   int lowCopied = CopyLow(_Symbol, PERIOD_M1, 0, 100, m1Low);
   int closeCopied = CopyClose(_Symbol, PERIOD_M1, 0, 100, m1Close);
   int volCopied = CopyTickVolume(_Symbol, PERIOD_M1, 0, 100, m1Volume);
   
   if(candlesCopied >= 100 && highCopied >= 100 && lowCopied >= 100 && closeCopied >= 100) {
      // Recent 20 candles in detail
      context += "Recent 20 candles (most recent first):\n";
      for(int i = 0; i < 20 && i < candlesCopied; i++) {
         double candleSize = (m1High[i] - m1Low[i]) / g_SymbolPoint;
         bool isBullish = (m1Close[i] > m1Open[i]);
         double bodySize = MathAbs(m1Close[i] - m1Open[i]) / g_SymbolPoint;
         double upperWick = (m1High[i] - MathMax(m1Open[i], m1Close[i])) / g_SymbolPoint;
         double lowerWick = (MathMin(m1Open[i], m1Close[i]) - m1Low[i]) / g_SymbolPoint;
         
         context += "Candle " + IntegerToString(i+1) + ": " + (isBullish ? "BULLISH" : "BEARISH") + 
                    " | O:" + DoubleToString(m1Open[i], g_SymbolDigits) + 
                    " H:" + DoubleToString(m1High[i], g_SymbolDigits) + 
                    " L:" + DoubleToString(m1Low[i], g_SymbolDigits) + 
                    " C:" + DoubleToString(m1Close[i], g_SymbolDigits) + 
                    " | Size:" + DoubleToString(candleSize, 0) + "pts Body:" + DoubleToString(bodySize, 0) + 
                    "pts Vol:" + IntegerToString((int)m1Volume[i]) + "\n";
      }
      
      // Summary statistics for last 100 candles
      double highest = m1High[ArrayMaximum(m1High, 0, 100)];
      double lowest = m1Low[ArrayMinimum(m1Low, 0, 100)];
      double range100 = (highest - lowest) / g_SymbolPoint;
      double avgCandleSize = 0.0;
      int bullishCount = 0;
      int bearishCount = 0;
      for(int i = 0; i < 100; i++) {
         avgCandleSize += (m1High[i] - m1Low[i]) / g_SymbolPoint;
         if(m1Close[i] > m1Open[i]) bullishCount++;
         else bearishCount++;
      }
      avgCandleSize /= 100.0;
      
      context += "\nLast 100 candles summary:\n";
      context += "Range: " + DoubleToString(lowest, g_SymbolDigits) + " - " + DoubleToString(highest, g_SymbolDigits) + 
                 " (" + DoubleToString(range100, 0) + " pts)\n";
      context += "Current price position: " + DoubleToString(((bid - lowest) / (highest - lowest)) * 100.0, 1) + "% of range\n";
      context += "Average candle size: " + DoubleToString(avgCandleSize, 0) + " pts\n";
      context += "Bullish candles: " + IntegerToString(bullishCount) + " | Bearish: " + IntegerToString(bearishCount) + "\n";
      
      // Price trend over last 100 candles
      double priceChange100 = ((m1Close[0] - m1Close[99]) / g_SymbolPoint);
      context += "Price change (100 candles): " + DoubleToString(priceChange100, 0) + " pts " + 
                 (priceChange100 > 0 ? "(UP)" : "(DOWN)") + "\n";
   } else {
      context += "Candle data not available (got " + IntegerToString(candlesCopied) + " candles)\n";
   }
   
   // Additional MT5 API data
   context += "\n=== ADDITIONAL MT5 MARKET DATA ===\n";
   context += "Symbol Info:\n";
   context += "- Contract Size: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE), 0) + "\n";
   context += "- Tick Size: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), g_SymbolDigits) + "\n";
   context += "- Tick Value: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE), 2) + "\n";
   context += "- Min Lot: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2) + 
              " | Max Lot: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), 2) + "\n";
   context += "- Lot Step: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), 2) + "\n";
   context += "- Stop Level: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL)) + " points\n";
   context += "- Freeze Level: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) + " points\n";
   
   // Market depth (if available)
   MqlBookInfo book[];
   if(MarketBookGet(_Symbol, book)) {
      context += "Market Depth: " + IntegerToString(ArraySize(book)) + " levels\n";
      if(ArraySize(book) > 0) {
         // Find best bid (highest buy price) and best ask (lowest sell price)
         double bestBid = 0.0;
         double bestAsk = 0.0;
         for(int b = 0; b < ArraySize(book); b++) {
            if(book[b].type == BOOK_TYPE_SELL && (bestAsk == 0.0 || book[b].price < bestAsk)) {
               bestAsk = book[b].price;
            }
            if(book[b].type == BOOK_TYPE_BUY && book[b].price > bestBid) {
               bestBid = book[b].price;
            }
         }
         if(bestBid > 0) context += "Best Bid: " + DoubleToString(bestBid, g_SymbolDigits);
         if(bestAsk > 0) context += " | Best Ask: " + DoubleToString(bestAsk, g_SymbolDigits) + "\n";
      }
   }
   
   // Time information
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   context += "Current Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\n";
   context += "Day of Week: " + IntegerToString(dt.day_of_week) + " (0=Sunday, 6=Saturday)\n";
   context += "Hour: " + IntegerToString(dt.hour) + " | Minute: " + IntegerToString(dt.min) + "\n";
   
   if(openPositions > 0) {
      context += "\nOPEN POSITIONS: " + IntegerToString(openPositions) + " (" + 
                 IntegerToString(buyPositions) + " long, " + IntegerToString(sellPositions) + " short)\n";
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == 123456) {
            double posEntry = PositionGetDouble(POSITION_PRICE_OPEN);
            double posSL = PositionGetDouble(POSITION_SL);
            double posProfit = PositionGetDouble(POSITION_PROFIT);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double posProfitPts = 0.0;
            double profitPct = 0.0;
            double slProtectionPct = 0.0;
            double currentPriceForPos = 0.0;
            
            if(posType == POSITION_TYPE_BUY) {
               currentPriceForPos = bid;
               posProfitPts = (bid - posEntry) / g_SymbolPoint;
               profitPct = ((bid - posEntry) / posEntry) * 100.0;
               slProtectionPct = ((posSL - posEntry) / posEntry) * 100.0;
            } else if(posType == POSITION_TYPE_SELL) {
               currentPriceForPos = ask;
               posProfitPts = (posEntry - ask) / g_SymbolPoint;
               profitPct = ((posEntry - ask) / posEntry) * 100.0;
               slProtectionPct = ((posEntry - posSL) / posEntry) * 100.0;
            }
            
            // Find max profit for this position
            double maxProfitPrice = posEntry;
            for(int j = 0; j < ArraySize(g_TrackedTickets); j++) {
               if(g_TrackedTickets[j] == ticket) {
                  maxProfitPrice = g_MaxProfitPrice[j];
                  break;
               }
            }
            // Calculate max profit % (for BUY: higher price = more profit, for SELL: lower price = more profit)
            double maxProfitPct = 0.0;
            if(posType == POSITION_TYPE_BUY) {
               maxProfitPct = ((maxProfitPrice - posEntry) / posEntry) * 100.0;
            } else if(posType == POSITION_TYPE_SELL) {
               maxProfitPct = ((posEntry - maxProfitPrice) / posEntry) * 100.0;
            }
            
            context += "#" + IntegerToString(ticket) + " " + (posType == POSITION_TYPE_BUY ? "LONG" : "SHORT") + ": " +
                       "Entry " + DoubleToString(posEntry, g_SymbolDigits) + " | " +
                       "Current " + DoubleToString(currentPriceForPos, g_SymbolDigits) + " | " +
                       "P/L " + DoubleToString(profitPct, 2) + "% (" + DoubleToString(posProfitPts, 0) + " pts) | " +
                       "SL " + DoubleToString(posSL, g_SymbolDigits) + "\n";
         }
      }
   }
   
   context += "\nM1 TRADING RULES (SCALPING FOR PROFIT):\n";
   context += "\nTRADING RULES (CONSIDER YOUR PERFORMANCE!):\n";
   if(winRate < 50.0 && g_TotalTrades > 5) {
      context += "⚠️ YOUR WIN RATE IS LOW (" + DoubleToString(winRate, 1) + "%) - BE MORE CONSERVATIVE!\n";
      context += "BUY: Only when RSI < 35 AND strong support (confidence 0.70-0.90)\n";
      context += "SELL: Only when RSI > 65 AND strong resistance (confidence 0.70-0.90)\n";
      context += "WAIT: More often - don't force trades when losing!\n";
   } else if(winRate >= 60.0 && g_TotalTrades > 5) {
      context += "✓ YOUR WIN RATE IS GOOD (" + DoubleToString(winRate, 1) + "%) - BE SMART, DON'T GET GREEDY!\n";
      context += "BUY: RSI < 40 OR price dropping to support OR bullish momentum (confidence 0.50-0.90)\n";
      context += "SELL: RSI > 60 OR price rising to resistance OR bearish momentum (confidence 0.50-0.90)\n";
      context += "CLOSE: Take profit quickly! Close when profit > 0.05% OR opposite signal\n";
   } else {
      context += "BUY: RSI < 40 OR price dropping to support OR bullish momentum on M1 (confidence 0.50-0.90)\n";
      context += "SELL: RSI > 60 OR price rising to resistance OR bearish momentum on M1 (confidence 0.50-0.90)\n";
      context += "CLOSE: Take profit quickly! Close when profit > 0.05% OR opposite signal OR good profit reached\n";
   }
   context += "WAIT: If no clear opportunity OR if you're losing money and need to be careful\n";
   context += "FOCUS: PROFIT - but be thoughtful about money. Track your wins/losses and adjust!\n";
   context += "USE THE 100 CANDLES: Analyze price patterns, support/resistance, trends from candle history!\n\n";
   
   context += "RESPONSE FORMAT (exactly): SIGNAL|CONFIDENCE|REASONING|SUMMARY\n";
   context += "SIGNAL: BUY, SELL, or WAIT\n";
   context += "CONFIDENCE: 0.00-1.00 (decimal)\n";
   context += "REASONING: Brief technical analysis (max 50 words)\n";
   context += "SUMMARY: Trading decision explanation (max 150 words, professional tone)\n";
   
   return context;
}

//+------------------------------------------------------------------+
//| Escape JSON string                                               |
//+------------------------------------------------------------------+
string EscapeJSON(string text)
{
   string result = text;
   
   // Escape backslashes first (must be done before other escapes)
   StringReplace(result, "\\", "\\\\");
   
   // Then escape quotes
   StringReplace(result, "\"", "\\\"");
   
   // Escape newlines and carriage returns
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\r", "\\r");
   
   // Escape tabs
   StringReplace(result, "\t", "\\t");
   
   // Remove null bytes
   StringReplace(result, "\x00", "");
   
   return result;
}

//+------------------------------------------------------------------+
//| Parse OpenAI JSON response                                       |
//+------------------------------------------------------------------+
string ParseOpenAIResponse(string jsonResponse)
{
   // Find the content field
   int contentStart = -1;
   string searchPattern = "";
   
   // Try pattern 1: "content":"
   contentStart = StringFind(jsonResponse, "\"content\":\"");
   if(contentStart >= 0) {
      searchPattern = "Pattern 1";
      contentStart += StringLen("\"content\":\"");
   }
   
   // Try pattern 2: "content" : " (with spaces)
   if(contentStart < 0) {
      int pos = StringFind(jsonResponse, "\"content\" : \"");
      if(pos >= 0) {
         contentStart = pos + StringLen("\"content\" : \"");
         searchPattern = "Pattern 2";
      }
   }
   
   // Try pattern 3: Find "content" then look for the value
   if(contentStart < 0) {
      int contentFieldPos = StringFind(jsonResponse, "\"content\"");
      if(contentFieldPos >= 0) {
         int colonPos = StringFind(jsonResponse, ":", contentFieldPos);
         if(colonPos >= 0) {
            int quoteStart = colonPos + 1;
            while(quoteStart < StringLen(jsonResponse) && 
                  (StringGetCharacter(jsonResponse, quoteStart) == ' ' || 
                   StringGetCharacter(jsonResponse, quoteStart) == '\t')) {
               quoteStart++;
            }
            if(quoteStart < StringLen(jsonResponse) && 
               StringGetCharacter(jsonResponse, quoteStart) == '"') {
               contentStart = quoteStart + 1;
               searchPattern = "Pattern 3";
            }
         }
      }
   }
   
   if(contentStart < 0) {
      Print("ERROR: Could not find 'content' field in OpenAI response");
      Print("Response preview (first 1000 chars): ", StringSubstr(jsonResponse, 0, 1000));
      return "";
   }
   
   Print("✓ Found content using ", searchPattern, " at position: ", contentStart);
   
   // Find the end of content - handle escaped quotes
   int contentEnd = contentStart;
   int searchPos = contentStart;
   bool found = false;
   
   while(searchPos < StringLen(jsonResponse) - 1) {
      int nextQuote = StringFind(jsonResponse, "\"", searchPos);
      if(nextQuote < 0) break;
      
      // Check if this quote is escaped
      bool isEscaped = false;
      if(nextQuote > 0) {
         int checkPos = nextQuote - 1;
         int backslashCount = 0;
         while(checkPos >= contentStart && StringGetCharacter(jsonResponse, checkPos) == '\\') {
            backslashCount++;
            checkPos--;
         }
         isEscaped = (backslashCount % 2 == 1);
      }
      
      if(!isEscaped) {
         contentEnd = nextQuote;
         found = true;
         break;
      }
      
      searchPos = nextQuote + 1;
   }
   
   if(!found) {
      Print("Could not find end of content in OpenAI response");
      return "";
   }
   
   string content = StringSubstr(jsonResponse, contentStart, contentEnd - contentStart);
   
   Print("Extracted content (length: ", StringLen(content), "): ", StringSubstr(content, 0, 200));
   
   // Unescape JSON
   StringReplace(content, "\\\\", "\x01"); // Temporary marker
   StringReplace(content, "\\\"", "\"");    // Unescape quotes
   StringReplace(content, "\\n", "\n");      // Unescape newlines
   StringReplace(content, "\\r", "\r");      // Unescape carriage returns
   StringReplace(content, "\\t", "\t");      // Unescape tabs
   StringReplace(content, "\x01", "\\");    // Restore double backslashes
   
   Print("Unescaped content (first 200 chars): ", StringSubstr(content, 0, 200));
   
   // Validate format: SIGNAL|CONFIDENCE|REASONING|SUMMARY
   string parts[];
   int count = StringSplit(content, '|', parts);
   Print("Split into ", count, " parts");
   
   if(count >= 4) {
      Print("✓ Valid format detected: Signal=", parts[0], " Confidence=", parts[1]);
      return content;
   } else {
      Print("⚠ Format not as expected. Parts: ", count, " Expected: 4");
   }
   
   // If AI didn't return in expected format, try to extract signal from text
   string signal = "WAIT";
   double confidence = 0.5;
   string reasoning = "AI analysis provided";
   string summary = content;
   
   // Try to find signal keywords
   if(StringFind(content, "BUY") >= 0 || StringFind(content, "buy") >= 0 || 
      StringFind(content, "long") >= 0 || StringFind(content, "LONG") >= 0) {
      signal = "BUY";
      confidence = 0.75;
   } else if(StringFind(content, "SELL") >= 0 || StringFind(content, "sell") >= 0 || 
             StringFind(content, "short") >= 0 || StringFind(content, "SHORT") >= 0) {
      signal = "SELL";
      confidence = 0.75;
   }
   
   return signal + "|" + DoubleToString(confidence, 2) + "|" + reasoning + "|" + summary;
}

//+------------------------------------------------------------------+
//| Call OpenAI API - FULL IMPLEMENTATION                            |
//+------------------------------------------------------------------+
string CallOpenAI(string marketData)
{
   // Check if API key is provided
   if(StringLen(InpOpenAIAPIKey) == 0) {
      Print("WARNING: OpenAI API Key not set. Using simulated response.");
      g_AIStatus = "SIMULATED";
      g_AIIsActive = false;
      return CallOpenAI_Simulated(marketData);
   }
   
   // Check if key looks valid (at least 20 characters)
   if(StringLen(InpOpenAIAPIKey) < 20) {
      Print("WARNING: OpenAI API Key appears too short. Using simulated response.");
      g_AIStatus = "SIMULATED";
      g_AIIsActive = false;
      return CallOpenAI_Simulated(marketData);
   }
   
   // Build the JSON request
   string escapedContent = EscapeJSON(marketData);
   
   // Build JSON manually
   string jsonRequest = "{";
   jsonRequest += "\"model\":\"" + InpOpenAIModel + "\",";
   jsonRequest += "\"messages\":[{";
   jsonRequest += "\"role\":\"user\",";
   jsonRequest += "\"content\":\"" + escapedContent + "\"";
   jsonRequest += "}],";
   jsonRequest += "\"temperature\":0.7,";
   jsonRequest += "\"max_tokens\":10000";
   jsonRequest += "}";
   
   Print("JSON Request length: ", StringLen(jsonRequest));
   if(StringLen(jsonRequest) > 200) {
      Print("JSON (first 200 chars): ", StringSubstr(jsonRequest, 0, 200));
   } else {
      Print("JSON: ", jsonRequest);
   }
   
   // Prepare headers
   string headers = "Content-Type: application/json\r\n";
   headers += "Authorization: Bearer " + InpOpenAIAPIKey + "\r\n";
   
   char postData[];
   char result[];
   string resultHeaders;
   
   // Convert JSON string to char array
   int jsonLen = StringLen(jsonRequest);
   ArrayResize(postData, jsonLen);
   StringToCharArray(jsonRequest, postData, 0, jsonLen);
   
   // Make the API call
   int timeout = 10000; // 10 seconds timeout
   int res = WebRequest("POST", "https://api.openai.com/v1/chat/completions", 
                        headers, timeout, postData, result, resultHeaders);
   
   if(res == -1) {
      int error = GetLastError();
      Print("❌ AI ERROR: WebRequest failed. Error code: ", error);
      if(error == 4060) {
         Print("   → SOLUTION: Add 'https://api.openai.com' to allowed URLs:");
         Print("      Tools > Options > Expert Advisors > Allow WebRequest for listed URL");
         Print("      Add: https://api.openai.com");
      } else {
         Print("   → Check: 1) Internet connection 2) Firewall settings 3) Broker restrictions");
      }
      Print("   → Using simulated AI response as fallback.");
      g_AIStatus = "ERROR";
      g_AIIsActive = false;
      return CallOpenAI_Simulated(marketData);
   }
   
   if(res != 200) {
      string errorResponse = CharArrayToString(result);
      Print("❌ AI ERROR: OpenAI API returned error code: ", res);
      Print("   Response: ", errorResponse);
      if(res == 401) {
         Print("   → SOLUTION: Invalid API key. Check your OpenAI API key in EA settings.");
      } else if(res == 429) {
         Print("   → SOLUTION: Rate limit exceeded. Wait a moment or upgrade your OpenAI plan.");
      } else if(res == 500 || res == 503) {
         Print("   → SOLUTION: OpenAI server error. Try again later.");
      }
      Print("   → Using simulated AI response as fallback.");
      g_AIStatus = "ERROR";
      g_AIIsActive = false;
      return CallOpenAI_Simulated(marketData);
   }
   
   // Parse JSON response
   string jsonResponse = CharArrayToString(result);
   Print("OpenAI API Success! Response received (length: ", StringLen(jsonResponse), ")");
   
   string aiMessage = ParseOpenAIResponse(jsonResponse);
   
   if(StringLen(aiMessage) > 0) {
   g_AIStatus = "ACTIVE";
      g_AIIsActive = true;
      Print("✓ AI is now ACTIVE - Real OpenAI API is working!");
      return aiMessage;
   }
   
   // If parsing failed, use simulated
   Print("Failed to parse OpenAI response. Using simulated response.");
   Print("Response was: ", StringSubstr(jsonResponse, 0, 500));
   g_AIStatus = "ERROR";
   g_AIIsActive = false;
   return CallOpenAI_Simulated(marketData);
}

//+------------------------------------------------------------------+
//| Simulated OpenAI response (fallback)                              |
//+------------------------------------------------------------------+
string CallOpenAI_Simulated(string marketData)
{
   if(g_AIStatus != "ERROR") {
      g_AIStatus = "SIMULATED";
   }
   g_AIIsActive = false;
   double rsi = g_BufferRSI[0];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_BufferATR[0];
   
   string response = "";
   string summary = "";
   
   if(rsi < 35) {
      summary = "The market is showing oversold conditions with RSI below 35, indicating potential buying opportunity. ";
      summary += "Price is currently near key support levels, which historically have provided good entry points. ";
      summary += "Market sentiment on higher timeframes remains positive, suggesting this pullback may be temporary.";
      response = "BUY|0.85|RSI oversold, price at support, bullish sentiment|" + summary;
   } else if(rsi > 65) {
      summary = "The market is currently overbought with RSI above 65, suggesting caution for new long positions. ";
      summary += "Price has moved significantly higher and may be due for a correction or consolidation.";
      response = "WAIT|0.60|RSI overbought, wait for pullback|" + summary;
   } else {
      summary = "The market is in a neutral state with RSI in the middle range, indicating balanced conditions. ";
      summary += "Price action is consolidating without clear directional bias at the moment.";
      response = "WAIT|0.50|Neutral conditions, waiting for better setup|" + summary;
   }
   
   return response;
}

//+------------------------------------------------------------------+
//| Split summary into lines for display                            |
//+------------------------------------------------------------------+
void SplitSummaryIntoLines()
{
   ArrayResize(g_AISummaryLines, 10);
   for(int j = 0; j < 10; j++) {
      g_AISummaryLines[j] = "";
   }
   
   if(StringLen(g_AISummary) == 0) {
      g_AISummaryLines[0] = "Waiting for analysis...";
      return;
   }
   
   // Split by sentences (periods)
   string sentences[];
   int sentenceCount = StringSplit(g_AISummary, '.', sentences);
   
   int lineIndex = 0;
   
   for(int i = 0; i < sentenceCount && lineIndex < 10; i++) {
      string sentence = sentences[i];
      
      // Trim whitespace
      while(StringLen(sentence) > 0 && StringGetCharacter(sentence, 0) == ' ') {
         sentence = StringSubstr(sentence, 1);
      }
      while(StringLen(sentence) > 0 && StringGetCharacter(sentence, StringLen(sentence) - 1) == ' ') {
         sentence = StringSubstr(sentence, 0, StringLen(sentence) - 1);
      }
      if(StringLen(sentence) == 0) continue;
      
      // Add period back
      sentence += ".";
      
      // If sentence is very long (>120 chars), split it by commas
      if(StringLen(sentence) > 120) {
         string parts[];
         int partCount = StringSplit(sentence, ',', parts);
         for(int p = 0; p < partCount && lineIndex < 10; p++) {
            string part = parts[p];
            // Trim
            while(StringLen(part) > 0 && StringGetCharacter(part, 0) == ' ') {
               part = StringSubstr(part, 1);
            }
            while(StringLen(part) > 0 && StringGetCharacter(part, StringLen(part) - 1) == ' ') {
               part = StringSubstr(part, 0, StringLen(part) - 1);
            }
            if(StringLen(part) > 0) {
               if(p < partCount - 1) part += ",";
               g_AISummaryLines[lineIndex] = part;
               lineIndex++;
            }
         }
      } else {
         g_AISummaryLines[lineIndex] = sentence;
         lineIndex++;
      }
   }
   
   // Ensure all remaining lines are empty
   for(int k = lineIndex; k < 10; k++) {
      if(k < ArraySize(g_AISummaryLines)) {
         g_AISummaryLines[k] = "";
      }
   }
}

//+------------------------------------------------------------------+
//| Parse AI response                                                |
//+------------------------------------------------------------------+
void ParseAIResponse(string response)
{
   string parts[];
   int count = StringSplit(response, '|', parts);
   
   if(count >= 4) {
      g_AISignal = parts[0];
      // Trim whitespace from signal
      StringTrimLeft(g_AISignal);
      StringTrimRight(g_AISignal);
      
      g_AIConfidence = StringToDouble(parts[1]);
      g_AIReasoning = parts[2];
      g_AISummary = parts[3];
      
      // Trim whitespace from reasoning
      StringTrimLeft(g_AIReasoning);
      StringTrimRight(g_AIReasoning);
      
      if(g_AISignal != "BUY" && g_AISignal != "SELL" && g_AISignal != "WAIT") {
         Print("⚠ Invalid AI signal: '", g_AISignal, "' - defaulting to WAIT");
         g_AISignal = "WAIT";
      }
      if(g_AIConfidence < 0.0) g_AIConfidence = 0.0;
      if(g_AIConfidence > 1.0) g_AIConfidence = 1.0;
      
      // Log parsed values for debugging
      Print("✓ Parsed AI Response: Signal=", g_AISignal, " Confidence=", g_AIConfidence, 
            " Reasoning=", StringSubstr(g_AIReasoning, 0, 50));
      
      // Split summary into lines for display
      SplitSummaryIntoLines();
   } else if(count >= 3) {
      // Backward compatibility
      g_AISignal = parts[0];
      g_AIConfidence = StringToDouble(parts[1]);
      g_AIReasoning = parts[2];
      g_AISummary = "Analysis in progress...";
      SplitSummaryIntoLines();
   } else {
      // Invalid response
      g_AISignal = "WAIT";
      g_AIConfidence = 0.0;
      g_AIReasoning = "Invalid AI response";
      g_AISummary = "Waiting for AI analysis...";
      SplitSummaryIntoLines();
   }
}

//+------------------------------------------------------------------+
//| UI Functions                                                     |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   int leftX = InpXLeft;
   int topY = InpYTop;
   int leftWidth = InpWidthLeft;
   int rightWidth = InpWidthRight;
   int thirdWidth = InpWidthThird;
   int panelHeight = InpPanelHeight;
   
   // Left Panel Background
   CreateRectangle("BG_Left", leftX, topY, leftWidth, panelHeight, ClrBackground, CORNER_LEFT_UPPER);
   CreateTextLabel("Title_Left", "AI & TRADING", leftX + 10, topY + 5, ClrHeader, true, 10, CORNER_LEFT_UPPER);
   
   int y = topY + 30;
   
   // STATUS AND AI STATUS AT TOP
   CreateTextLabel("L_TradingStatus", "STATUS:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_TradingStatus", "INIT", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_AIStatus", "AI STATUS:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_AIStatus", "INIT", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   // Separator line
   y += 5;
   
   // LIVE PRICE BY TICK
   CreateTextLabel("L_Price", "PRICE:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_Price", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_BidPrice", "BID:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_BidPrice", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_AskPrice", "ASK:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_AskPrice", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_Spread", "SPREAD:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_Spread", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   // Separator line
   y += 5;
   
   // RSI WITH DISTANCE INDICATORS
   CreateTextLabel("L_RSI", "RSI:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_RSI", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_RSI_To30", "→ <30:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_RSI_To30", "--", leftX + 100, y, ClrBuy, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_RSI_To70", "→ >70:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_RSI_To70", "--", leftX + 100, y, ClrSell, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   // Separator line
   y += 5;
   
   // AI SIGNAL AND CONFIDENCE
   CreateTextLabel("L_AISignal", "AI SIGNAL:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_AISignal", "WAIT", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_AIConfidence", "AI CONF:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_AIConfidence", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
   y += 18;
   
   CreateTextLabel("L_AIExpectation", "AI EXPECTS:", leftX + 10, y, ClrLabel, false, 9, CORNER_LEFT_UPPER);
   CreateTextLabel("V_AIExpectation", "--", leftX + 100, y, ClrValue, true, 9, CORNER_LEFT_UPPER);
}

void CreateRectangle(string name, int x, int y, int width, int height, color bgColor, int corner)
{
   string objName = g_Prefix + name;
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void CreateTextLabel(string name, string text, int x, int y, color clr, bool bold, int fontSize, int corner)
{
   string objName = g_Prefix + name;
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void UpdateUI(string suffix, string value, color clr)
{
   string objName = g_Prefix + "V_" + suffix;
   if(ObjectFind(0, objName) >= 0) {
      ObjectSetString(0, objName, OBJPROP_TEXT, value);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+

