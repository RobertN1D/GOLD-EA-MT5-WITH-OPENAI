Here is the corrected and detailed technical documentation for the code provided. As requested, this document refers to the system as Gold Dashboard V2, acknowledging that the "3.2" in the code header was a labeling error.

This document breaks down the specific algorithms found in the source code (Regime Detection, Kelly Criterion, 100-Bar Analysis) and explains exactly how the AI component functions.

📘 Gold Dashboard V2 – Technical Documentation
Version: 2.0 (Codebase internally labeled 3.2)

Strategy: AI-Driven Pattern Recognition & Swing Trading

Timeframe: M15 (Primary Analysis) with Multi-Timeframe Context

1. System Overview
Gold Dashboard V2 is a sophisticated hybrid trading system. Unlike simple scalpers, this version uses a "Deep Analysis" approach. It is designed to identify complex market structures (like accumulation zones, flags, and reversals) by feeding massive amounts of historical data to OpenAI.

It combines an AI Neural Layer for decision-making with Hard-Coded Algorithms for risk management and trade execution.

2. The AI Engine: "The Elite Auditor"
The core differentiator of V2 is the sheer volume of data it sends to the AI and the specific "persona" it forces the AI to adopt.

A. What Data is Sent to the AI? (The Payload)
Every time the AI updates (default: 15 minutes), the BuildMarketContext function gathers a massive text block. It does not just send the current price. It sends Context:

100-Bar Deep History:

It sends Open, High, Low, Close, and Volume data for the last 100 candles on the M5, M15, H1, and D1 charts.

Why? This allows the AI to "see" chart patterns like Head & Shoulders, Bull Flags, or Double Bottoms that require historical context to identify.

M1 Momentum (30 Bars):

Sends the last 30 minutes of 1-minute data to gauge immediate entry momentum and volume spikes.

Indicator Trajectory:

Instead of just "RSI is 30," it sends the history of the RSI and Moving Averages over the last 25 periods. This enables the AI to detect Divergences (e.g., Price making lower lows while RSI makes higher lows).

Market Depth:

Sends Bid/Ask spreads and Tick Velocity to determine if liquidity is sufficient for entry.

B. How the AI Thinks (The System Prompt)
The code includes a specific "System Prompt" that trains the AI before it answers. The AI is instructed to act as an "Elite Gold Market Auditor" with these strict rules:

Bullish Bias: The AI is taught that Gold has a natural long-term upward drift. Therefore, it is instructed to be "Twice as tough on SELL signals," requiring a higher confidence threshold to short the market.

Pattern Recognition: The AI is explicitly told to look for:

SFP (Swing Failure Pattern): Where price sweeps a liquidity level and snaps back.

FVG (Fair Value Gaps): Imbalances in the candle structure that need to be filled.

QM (Quasimodo): Complex reversal patterns involving higher highs and lower lows.

Asymmetric Grading: A "Wait" is the default. The AI only signals a trade if patterns align across multiple timeframes (Confluence).

3. The Algorithmic Modules (Non-AI Features)
While the AI decides when to trade, V2 includes several advanced algorithms to decide how much to trade and when to exit.

🛡️ 1. Market Regime Detection (DetectMarketRegime)
This algorithm runs every 60 minutes to determine the "mood" of the market. It uses math, not AI:

Trend Strength: Uses ADX (Average Directional Index). If ADX > 25, the market is Trending.

Trend Direction: Uses Linear Regression Slope on the last 50 candles to mathematically determine if the trend is Up or Down.

Volatility: Compares the current Price Range against the ATR.

Impact: The EA adjusts its strategy based on this. For example, in a "Volatile" regime, it may reduce lot sizes or widen stops.

🧠 2. Kelly Criterion Position Sizing (CalculateKellyCriterionLots)
If InpUseKellyCriterion is enabled, the EA ignores your fixed lot size.

It reads your entire trading history to calculate your Win Rate and Risk/Reward Ratio.

It uses the Kelly Formula (fractional) to calculate the mathematically optimal bet size to grow the account.

Note: It requires at least 20 trades in history to activate. Before that, it uses the default lot size.

🏃 3. "Let Winners Run" Management
V2 uses a dynamic exit strategy designed for Swing Trading:

Breakeven Trigger: Once the trade is up by $30 (configurable), the Stop Loss moves to Entry + $15. This "locks in" the win.

Dollar-Based Trailing: Instead of pips, it uses a Dollar Trail (e.g., $25). If the trade is up $500, the SL will sit at $475. This allows the price to swing violently (common in Gold) without stopping you out, as long as it doesn't retrace more than the dollar value you set.

Rescue Mode: If a trade is losing (e.g., -$25), the algorithm tightens the trail aggressively. The goal is to minimize the final loss if the market turns against you.

⏱️ 4. Time Filters
To avoid bad liquidity, the code includes hard filters:

Asian Dead Zone: Blocks trading between 02:00 and 05:00 GMT (low volume, high spread risk).

Session Filters: Avoids the first and last 15 minutes of major sessions (London/NY) to avoid volatility spikes.

4. Input Parameters Guide
🤖 AI Configuration
InpUseAI: Master switch.

InpOpenAIAPIKey: Your private OpenAI Key.

InpAIUpdateMinutes: (Default 1). How often the AI re-scans the 100-bar history.

InpAIConfidenceMin: (Default 0.80). The AI must be 80% confident to execute.

📊 Risk Management
InpLotSize: The base lot size (used if Kelly Criterion is off).

InpMaxDailyLoss: Hard dollar stop. If you lose this amount in one day, the bot shuts down until tomorrow.

InpUseRegimeDetection: Enables the ADX/Regression logic.

InpUseKellyCriterion: Enables mathematical position sizing.

📉 Trade Settings
InpStopLossATR: Sets the initial stop loss based on volatility (e.g., 3x ATR).

InpSniperEntry: If True, even after the AI says BUY, the bot waits for the 1-minute RSI to dip before entering to get a better price.

5. Summary of Logic
Wake Up: EA checks Time Filters and Regime (Trending/Ranging).

Scan: It sends 100 bars of M5/M15/H1/D1 data + Indicators to AI.

Think: AI analyzes for patterns (SFP, FVG) using the "Elite Auditor" persona.

Signal: AI returns "BUY" with 85% confidence.

Refine: CheckSniperEntry checks M1 chart. If price is peaking, it waits for a dip.

Size: KellyCriterion calculates exact lot size based on past performance.

Execute: Trade is placed.

Manage: ManageTrailingStopLoss watches the trade tick-by-tick to lock in profits.

⚠️ Disclaimer
Gold Dashboard V2 is a professional tool involving complex statistical and AI layers.

Demo Testing: You must test on Demo for at least 2 weeks to ensure your broker's execution speed is compatible with the "Sniper" entry logic.

Kelly Criterion: This feature can increase lot sizes significantly if you have a winning streak. Monitor it closely.

AI Latency: This EA relies on OpenAI API uptime. If the API is down, the EA will pause trading or revert to basic indicator logic.
