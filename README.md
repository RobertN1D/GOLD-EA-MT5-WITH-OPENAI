# EA-MT5-OPENAI.mq5 — Expert Advisor README

**Repository path:** `mt5-bot/EA-MT5-OPENAI.mq5`

**Purpose**
- A production MetaTrader 5 Expert Advisor for M1 XAUUSD scalping that combines indicator-based signals (RSI, EMAs, ATR, Bollinger Bands) with an AI signal layer and a tick-level trailing stop engine. Designed for low-frequency intraday scalping with UI dashboard and test-mode features.

**Quick summary**
- Strategy: AI-guided M1 scalping on XAUUSD (Gold). Entries are driven by an internal AI/signal layer plus conventional indicators. Positions use small lots and aggressive profit-taking with a trailing/SL management engine.
- Key features: dashboard and telemetry, test/trial mode, retry-safe order execution, tracked-ticket trailing engine, partial/runner logic hooks (where present), and data collection for analysis.

**Indicators & signals used (high level)**
- RSI (commonly 14 period)
- EMA / Moving averages (example: EMA 20 & 50 used for structure)
- ATR (used for volatility and stop sizing — typically ATR 14)
- Bollinger Bands (20, stddev default) for range context
- AI signal: a textual/structured signal layer that returns BUY / SELL / WAIT (the EA contains code to query & parse AI responses and falls back to simulated decisioning when AI is unavailable)

**Important notes and constraints**
- This EA places real market orders via `MqlTradeRequest` / `OrderSend()` and therefore should first be tested on a demo account before any live deployment.
- It includes a tick-level trailing stop engine that moves stop losses frequently for tracked trades. That logic is powerful but can interact with extreme volatility — review the `ManageTrailingStopLoss()` and tracked-ticket code before enabling on live accounts.
- The original `trading-off.mq5` does not implement emergency sudden-drop protec­tions by default (e.g., immediate emergency close on ultra-fast spikes), so consider using the `trading-updated-gold-with-loss-protection.mq5` variant if you want those protections added.

**Inputs (user-configurable highlights)**
- Lots / risk settings: configure `InpDefaultLot` / maximum lot size before live runs.
- Trade timing & filters: enable/disable AI signals, test mode, and per-symbol toggles.
- Indicator periods: RSI period, MA lengths, ATR period — these are exposed as inputs and can be tuned.
- Order/Execution options: slippage tolerance, broker fill mode fallback, and retries.
- Dashboard/UI: colors, refresh rates, and on-chart telemetry toggles.

(See the top of `EA-MT5-OPENAI.mq5` for the exact list of input parameters.)

**Installation & compile**
- Copy `trading-off.mq5` to your MetaTrader 5 MQL5 Experts folder (`MQL5/Experts/<your-folder>`).
- Open MetaEditor, load the file, and compile (F7). Fix any compile errors reported by your MetaEditor (these are usually environment/broker specific or missing include files).

Commands (Windows / PowerShell example):
```
# Copy file (example path)
# Ensure MetaTrader is closed or that the file is recompiled in MetaEditor
copy "C:\Users\16139\Desktop\gold-trader\mt5-bot\trading-off.mq5" "C:\Users\<YourMT5Profile>\MQL5\Experts\"
# Then open MetaEditor and press F7 to compile
```

**Attach & run (recommended sequence)**
- Attach to `XAUUSD` on timeframe `M1`.
- Start with `Visual mode` or forward-testing on a demo account.
- Enable `Test Mode` input (if you want the EA to run its internal trade-sanity tests and not use full-size lots).
- Monitor the dashboard and logs for 10–30 minutes to ensure the AI integration and order execution behave as expected.

**Backtest recommendations**
- Use `Model: Every tick` (if available) for highest-fidelity M1 backtests.
- Test range: at least 3-6 months of history with varied volatility (include both calm and high-volatility periods).
- Use tick-quality data or the broker's high-quality tick database where possible.
- Metrics to watch: maximum drawdown, average trade, profit factor, and the tail risk of large single-trade losses.

**Safety checklist before live use**
- [ ] Confirm lots are set to a safe demo size (`InpDefaultLot` small, e.g., 0.01).
- [ ] Review `ManageTrailingStopLoss()` and ensure the trailing logic aligns with your risk tolerance.
- [ ] Confirm the EA `MagicNumber` (used to identify positions) does not collide with other EAs/strategies.
- [ ] Ensure slippage, margin requirements, and instrument specifications match your broker (XAUUSD contract size, digits, point value).
- [ ] Run the updated protected variant (`trading-updated-gold-with-loss-protection.mq5`) if you want emergency-drop and max-loss-per-trade protections added.

**Troubleshooting**
- Compile errors: open in MetaEditor, and read the error log — missing includes or name collisions are the most common causes.
- Orders being rejected: check the `Experts` and `Journal` tabs in MT5 for broker rejection reasons (insufficient margin, invalid stops, trade context busy, wrong symbol suffix/prefix).
- Unexpected behavior: enable `Test Mode` or reduce lot size and re-run to observe the EA's internal test and decision logs.

**Where to look in code**
- `OnInit()` — initialization, indicator handles, UI creation.
- `OnTick()` / `OnTimer()` — main loop, data updates, calls to `UpdateAllData()`, `CheckAndExecuteTrades()`, and trailing logic.
- `RunTestMode()` — internal testing routine used for validation and regression tests.
- `ManageTrailingStopLoss()` — the existing tick-level trailing engine for open tracked tickets.
- `ExecuteBuyOrder()` / `ExecuteSellOrder()` — order placement logic (request formation, `OrderSend`, retry behavior).
- AI integration: functions that build market context and call the AI endpoint (simulated if not available).

**Limitations & recommended improvements**
- No built-in emergency large-drop protections in the original file — catastrophic single-trade losses are possible during sudden spikes. Consider using the merged protected variant or add emergency-check code that closes positions when sudden drop thresholds are breached.
- If you depend on the AI layer, add robust timeouts and fallback rules (the EA contains a fallback, but review/update thresholds to your risk comfort).
- Consider limits on the total open exposure (max concurrent positions or max aggregate lot size) to prevent compounding risk.

**Changelog / version notes**
 - `EA-MT5-OPENAI.mq5` — original production EA. Contains full dashboard, test-mode, AI integration, and trailing engine.
 - For an updated version with loss protections, see `trading-updated-gold-with-loss-protection.mq5` in the same folder.
**Detailed Code Walkthrough**

This section explains the main modules, functions, inputs and runtime behavior inside `trading-off.mq5`. Read this to understand exactly what each component does, how data flows through the EA, and how trades are opened, managed and closed.

**Global / Inputs**
- **Magic number & symbol filtering**: The EA uses a single `MagicNumber` (an integer constant) to tag all its positions. This allows the EA to identify and manage only the trades it created, avoiding interference with other EAs or manual trades. Many position-management loops test `PositionGetInteger(POSITION_MAGIC)` to filter.
- **`InpDefaultLot` and risk inputs**: Control the default order size. Always validate this value against your account leverage and margin rules. The EA may also contain inputs for maximum allowed lot or dynamic sizing.
- **Indicator inputs**: Periods and parameters for RSI, EMAs, ATR and Bollinger Bands are exposed as inputs. These change the EA's signal sensitivity and stop sizing. Example: `InpRSIPeriod`, `InpATRPeriod`, `InpFastEMA`, `InpSlowEMA`.
- **Execution inputs**: Slippage tolerance, retry counts, and whether to use market vs. pending orders are configurable.
- **UI / telemetry toggles**: Enable or disable on-chart dashboard elements and refresh rates.

**OnInit()**
- Purpose: create indicator handles, initialize global variables, set up arrays and UI objects, and start periodic timers (via `EventSetTimer()` when used).
- What it does:
  - Calls indicator functions (iRSI, iMA, iATR, iBands, etc.) to create handles. These handles are used to pull arrays of values without recalculating indicators each tick.
  - Initializes arrays/buffers used for tracking ticket state (e.g., `g_TrackedTickets[]`, `g_MaxProfitPrice[]`, `g_LastSLUpdate[]`).
  - Draws the initial dashboard UI elements (rectangles, labels) and may set the `Test Mode` flag defaults.

**OnDeinit(const int reason)**
- Purpose: cleanup. Remove UI objects, release indicator handles, clear timers, and optionally log final state messages.

**OnTick()**
- Purpose: main per-tick runtime logic. It's called for every incoming price tick.
- Typical high-level flow inside `OnTick()`:
  1. Read current `SymbolInfoDouble(_Symbol, SYMBOL_BID)` and `SYMBOL_ASK` into local variables.
  2. Update UI/dash elements to reflect current price and positions.
  3. Run `RunTestMode()` when `Test Mode` is enabled (this executes internal validation trades and quickly reverts them for checks).
  4. Call `UpdateAllData()` to refresh indicator arrays and compute derived values (RSI, EMA cross state, ATR value, Bollinger Bands widths).
  5. Evaluate AI signal (if enabled) by building a market context and calling the AI helper — result is `BUY`, `SELL` or `WAIT`.
  6. `CheckAndExecuteTrades()` — decide whether to place orders based on signals and filters.
  7. `ManageTrailingStopLoss()` and other position-management helpers are executed every tick to move stops or perform partial closes.

**OnTimer()**
- Purpose: periodic housekeeping at a lower frequency than ticks (for example, once per second or once per N seconds).
- Typical tasks: background telemetry updates, persistent logging, non-urgent cleanup, and periodic health checks for AI/network timeouts.

**UpdateAllData()**
- Purpose: central data aggregation function.
- What it computes:
  - Indicator values pulled using indicator handles (last N values of RSI, EMA, ATR, Bands).
  - Derived values, such as moving-average cross states, momentum direction, ATR-based volatility estimates, and internally smoothed values.
  - Internal signals used by `CheckAndExecuteTrades()` and UI values for the dashboard.

**AI integration (BuildMarketContext / CallOpenAI / ParseOpenAIResponse)**
- Purpose: create a textual/structured representation of the most recent market state and ask an AI for a decision.
- How it works:
  - `BuildMarketContext()` collects recent bars, indicator values, position status, and optionally recent trade outcomes and formats a prompt or JSON payload for the AI.
  - `CallOpenAI()` attempts to contact an upstream AI service with that payload. If unreachable (timeout/failure), a fallback simulated decision may be used.
  - `ParseOpenAIResponse()` inspects the returned payload and converts it into one of the canonical signals (`BUY`, `SELL`, `WAIT`) and an optional confidence score.
- Notes:
  - The EA contains fallback behavior to avoid blocking order logic if the AI is unavailable.
  - Timeouts and retry behavior are important; long waits must not delay per-tick decision paths.

**CheckAndExecuteTrades()**
- Purpose: evaluate signals and place orders when conditions are met.
- Core responsibilities:
  - Consolidate indicator signals + AI layer + trade filters (e.g., max concurrent positions, daily trading windows).
  - Validate position sizing and margin before attempting an order.
  - Call `ExecuteBuyOrder()` or `ExecuteSellOrder()` when a trade meets entry criteria.

**ExecuteBuyOrder() / ExecuteSellOrder()**
- Purpose: prepare `MqlTradeRequest`, fill in `symbol`, `volume`, `price`, `sl`, `tp`, `deviation`, and other fields, then call `OrderSend()`.
- Important fields & handling:
  - `request.type`: `ORDER_TYPE_BUY` or `ORDER_TYPE_SELL` for market orders.
  - `request.price`: current Ask for a buy, Bid for a sell. The EA accounts for `SymbolInfoDouble(_Symbol, SYMBOL_ASK)` / `SYMBOL_BID`.
  - `request.sl` / `request.tp`: Stop loss and take profit values. The EA typically computes TP fixed or via ATR multiples and SL either fixed or ATR-based. If `Test Mode` is enabled, smaller SL/TP or simulated values are used.
  - `request.deviation`: slippage tolerance.
  - Filling mode & retries: after `OrderSend` failure due to `TRADE_RETCODE_REQUOTE` or `TRADE_RETCODE_TRADE_CONTEXT_BUSY`, the EA may retry with small waits and incrementally adjusted parameters.
- Side effects:
  - On successful `OrderSend()`, the EA often records the created ticket in `g_TrackedTickets[]`, sets initial `g_MaxProfitPrice[ticketIndex]` and `g_LastSLUpdate[ticketIndex]` to drive later trailing logic.

**ManageTrailingStopLoss()**
- Purpose: a tick-level loop that adjusts stop-losses for tracked tickets to lock-in profits and reduce downside.
- Behavior:
  - For each tracked ticket, compute current profit in points and compare with thresholds.
  - If profit exceeds a set threshold, move stop to breakeven or to trailing levels based on `g_MaxProfitPrice` and configured step distances.
  - Some implementations use `PositionModify()` to change stops while preserving TP.
- Caveats:
  - Frequent stop modifications can increase slippage risk and consume broker API calls; ensure the EA respects `TRADE_RETCODE` errors and avoids tight loops when trade context is busy.

**RunTestMode()**
- Purpose: a built-in self-test that opens a small test trade, modifies SL/TP, and then closes it to validate order execution paths, permissions and symbol configuration.
- Notes:
  - Test mode uses tiny lots (e.g., 0.01) and non-destructive behavior; still, run it on a demo account first.

**UI / DrawDashboard() / On-screen telemetry**
- Purpose: draw rectangles, text labels and live metrics onto the chart for quick visual monitoring.
- What to look for: net exposure, open tickets, P/L, RSI, ATR, current AI signal and the timestamp of the last AI decision.

**Position tracking arrays**
- Purpose: hold state per-ticket in memory for advanced behaviors (smart runners, partial closes, aggressive trailing).
- Typical fields:
  - `g_TrackedTickets[]` — ticket numbers the EA actively manages.
  - `g_MaxProfitPrice[]` — historical maximum favorable price for a position used to compute trails.
  - `g_LastSLUpdate[]` — timestamp of last SL change to rate-limit modifications.

**Logging & Alerts**
- The EA uses `Print()` to record events and `Alert()` for high-severity actions (e.g., emergency closes in updated variants). Check the `Experts` and `Journal` tabs in MT5 for these messages.

**Test cases & example trade lifecycle (step-by-step)**
1. Market tick arrives -> `OnTick()` runs and reads the latest prices.
2. `UpdateAllData()` updates all indicator values and derives the current momentum/structure variables.
3. `BuildMarketContext()` formats those values for the AI; `CallOpenAI()` returns `BUY` with confidence.
4. `CheckAndExecuteTrades()` verifies that no conflicting positions or max-open constraints are violated and calls `ExecuteBuyOrder()`.
5. `ExecuteBuyOrder()` constructs a `MqlTradeRequest` with `volume = InpDefaultLot`, `price = Ask`, an ATR-based `sl`, and a target `tp` or fixed TP. `OrderSend()` returns success with a ticket.
6. On success, the ticket is appended to `g_TrackedTickets[]` and initial trailing state is saved.
7. Subsequent ticks call `ManageTrailingStopLoss()` which moves SL progressively to lock profits. Partial close logic (if present) can close part of the position at milestones.
8. Position reaches TP or trailing SL and is closed. The EA logs results and updates internal stats.

**Parameter tuning guidance**
- RSI: higher periods smooth signals and reduce noise but create lag. Typical scalping uses 9–14.
- ATR: used to size SL. Multipliers of 1.0–3.0 are common; wider for news sessions, tighter for calm ranges.
- EMAs: 20/50 are used for micro-trend detection; shorter values make entries more aggressive.
- Trailing parameters: set step sizes and minimum profit-to-trail carefully to avoid closing winners early.

**Known limitations & safety reminders**
- This version lacks emergency sudden-drop protections by default. Single large losses can occur if stops are too wide and volatility spikes.
- The trailing engine is aggressive and may move SL frequently — review and test to ensure it aligns with your broker's execution characteristics.
- Always test on a demo account for several weeks before real-money runs.

**File mapping (where to find logic in code)**
- `OnInit()` — initialization and indicator handle creation.
- `OnTick()` / `OnTimer()` — main loop and periodic tasks.
- `UpdateAllData()` — indicator updates and derived state.
- `CheckAndExecuteTrades()` — entry decision orchestration.
- `ExecuteBuyOrder()` / `ExecuteSellOrder()` — order creation and `OrderSend()` retries.
- `ManageTrailingStopLoss()` — trailing and partial-close behavior.
- `RunTestMode()` — internal validation tests.

---

This README now focuses purely on documentation and a step-by-step explanation of what each major part of the EA does and how they interact. If you want further expansion on any single function (for example, the exact fields used in the `MqlTradeRequest` or a line-level walkthrough of `ManageTrailingStopLoss()`), tell me which function and I'll expand that section in-place.
