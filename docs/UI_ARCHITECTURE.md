# Runtime UI Architecture

The primary screen is one tactical workspace. Cyberspace navigation and meatspace monitoring are concurrent views into separate simulation domains; opening a monitor never changes `SceneTree.paused`, advances a cyber tick, or replaces the network display.

## Audit findings

The realtime managers and clocks were already independent of the UI and of cyberspace actions. The previous presentation instantiated COMMS, VIDEO, ALARMS, and TEAM STATUS as unrelated fixed-position overlays. Although these overlays did not explicitly pause gameplay, they overlapped the graph and each other and could intercept pointer input across important tactical areas.

## Monitor dock

`RealtimeMonitorDock` is a presentation-only composition layer. It owns three transparent layout zones (left, right, and bottom) and four `DockableMonitorWidget` wrappers:

- COMMS
- VIDEO
- ALARMS
- TEAM STATUS

Each wrapper can be minimized, independently pinned, and moved between dock zones. Pinning is not exclusive, so several monitors can remain in the workspace. Only visible widget rectangles consume pointer input; empty dock space passes input through to `NetworkDisplay`.

Minimizing hides only the wrapper body. The contained monitor remains in the scene tree with its processing mode unchanged, so subscriptions, elapsed-time displays, camera/alarm/team state, and transcript updates continue. Comms listening and recording belong to `CommsSession` and its manager; minimizing or moving the widget does not stop either. The player must explicitly use STOP LISTENING or other domain commands.

## Ownership boundaries

- Runtime managers and definitions own objective process state.
- PlayerKnowledge owns what may be revealed.
- Monitor scenes read managers and issue explicit commands.
- Dock widgets own only layout preferences: dock zone, minimized state, and pinned state.
- No monitor stores gameplay state or drives either clock.

The explicit pause action is routed through the central `PausePolicy`. Hard pause freezes both domains, while soft pause freezes only cyber actions. Merely interacting with realtime monitoring UI never invokes either mode.
