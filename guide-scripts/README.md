# WindNet Guide Scripts (Advanced Implementation)

This directory contains foundational GDScript reference files for wiring advanced WindNet features into your own custom Godot game.

> **⚠️ CRITICAL ARCHITECTURE NOTE**
> The scripts provided in this folder are GUIDES and BLUEPRINTS, not "plug-and-play" components. You are expected to study, adapt, rewrite, and expand this logic to fit the specific requirements of your game. Do not blindly drag and drop these into your active Scene Tree.

## 🏗️ The Multiplayer Movement Blueprints
Provided here are three distinct movement architectures to demonstrate syncing player data over AWS AppSync. Because AppSync charges per operation, your chosen architecture drastically impacts your AWS bill.

### 1. Strict Fixed-Tick Architecture (`fixed_tick_demo.gd`)
Decouples network updates from the engine's frame rate. It processes input and sends data at a rigid, fixed interval (e.g., 10 times a second).
* **Best For:** Grid-based movement, turn-based tactics, strategy games.
* **Pros:** Highly reliable and self-correcting.
* **Cons:** Rigid, "stepped" visual movement.
* **Cost Impact: HIGH.** Holding a key for 10 seconds fires 100 continuous requests. With high concurrent users, this accumulates operations rapidly.

### 2. Event-Driven Movement (`event_driven_demo.gd`)
Relies entirely on state changes and native Godot vector extrapolation. It only contacts AWS when a key is pressed or released.
* **Best For:** Social hubs, puzzles, minimizing cloud costs.
* **Pros:** Flawless 60fps+ visual movement on remote clients.
* **Cons:** Susceptible to packet loss (e.g., dropping the "key release" packet causes infinite walking).
* **Cost Impact: EXTREMELY LOW.** Holding a key for 10 seconds fires only 2 requests (press and release).

### 3. Hybrid Architecture (`hybrid_demo.gd`) - *Recommended*
Combines the responsiveness of Event-Driven with the reliability of a Fixed-Tick heartbeat.
* **Best For:** Top-down RPGs, co-op survival games, general multiplayer.
* **Pros:** Sends instant data on direction changes, but includes a cheap "heartbeat" ping (e.g., 2Hz) to keep clients synced and correct anomalies.
* **Cons:** Requires tuning interpolation weights and timers for your specific game speed.
* **Cost Impact: OPTIMIZED.** Strikes a balance. Costs slightly more than Event-Driven, but exponentially less than Fixed-Tick.

## 📖 How to Use These Reference Scripts
To get the most out of these blueprints, treat them as educational textbooks:
1. Study how WindNet formats GraphQL mutation payloads.
2. Observe how AppSync real-time subscriptions are handled.
3. Review the use of chronological sequence numbers (`local_sequence`) to prevent rubber-banding.
4. Copy the syntax, but rewrite the state logic to map to your game's specific variables and UI architecture.