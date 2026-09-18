# Contextual Monitor

`ContextualMonitorWindow` is the single HUD surface for actively monitored external feeds. It is hidden when its providers report no active sources, appears when the first source starts, and hides after the last source stops. Simultaneous feed categories are selected through compact tabs.

Collapsing the full window leaves only `MONITOR // N ACTIVE`; it reserves no full-panel presentation but keeps feed awareness and processing intact. Clicking the indicator or invoking the configurable global `TOGGLE_MONITOR` action (C by default) restores the window. With no active feeds, neither window nor indicator is shown.

Initial providers adapt the existing video, communications, and physical-alarm managers without copying their authoritative state. Discovery alone does not open the window: a camera must be open, a communications session must be monitored/intercepted, or an alarm endpoint must be explicitly monitored.

New feed families register a label, presentation scene, and callable returning active source IDs. The feed type taxonomy already reserves telemetry, sensor, team, audio, and custom categories. Runtime processes continue independently of whether their presentation is selected.
