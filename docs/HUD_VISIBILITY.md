# HUD visibility state

`HudVisibilityManager` coordinates whether major HUD surfaces are visible, collapsed, user-enabled, contextual, hidden, or temporarily suppressed. Widgets still own content, rendering, animation, and interaction.

The manager also consumes semantic HUD commands from `GameplayActionBindings`. It changes presentation state or emits `widget_open_requested`; it never constructs widget content. Contextual commands fail cleanly through `action_feedback` when a Monitor has no feeds, Team Status has no contacts, or the Node Inspector has no valid target.

The manager tracks Sphere Minimap, Program Quickbar, Monitor, Team Status, Node Inspector, Objective, Trace, and Alerts. Default policies keep the minimap, quickbar, objective, and trace present; Monitor and Node Inspector require context; Team Status starts collapsed and requires a relevant contact or alert.

Suppression is presentation coordination rather than content mutation. For example, an expanded Monitor suppresses the Node Inspector in the shared contextual rail. Collapsing or closing the Monitor removes that suppressor and restores the inspector if its selection context still exists.
