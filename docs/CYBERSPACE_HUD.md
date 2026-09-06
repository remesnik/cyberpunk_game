# Cyberspace HUD hierarchy

The main HUD treats the local network graph as the primary workspace. Its safe interaction rectangle excludes the right contextual rail, top status strip, and bottom quick-access strips, so larger hex nodes do not sit beneath controls. Current-node details start collapsed; the node itself and graph remain the primary default presentation.

- **Primary:** local graph, contextual target/threat actions, and Sphere minimap.
- **Secondary:** the compact trace/tick/objective strip and one-row program bindings.
- **Contextual:** target details, event history, realtime comms/video/alarm monitors, and team status.

The top strip holds trace/alert, tick, objective, and concise risk. The right rail keeps the Sphere minimap permanently discoverable and hosts transient target or Monitor presentations. The bottom program strip preserves visible bindings; the thin row above it hosts Team Status only when relevant. Target details remain hidden until a node, link, service, capability, hacker, or ICE contact is selected. The event log is collapsed independently. Team Status is a thin knowledge-safe roster of relevant physical teams and allied remote hackers; selecting it reveals operational detail. External feeds use the unified contextual Monitor and leave no empty panel when inactive.

The target inspector and expanded Monitor share the contextual rail rather than overlapping the graph or each other. An expanded Monitor temporarily yields that rail to the live feed; collapsing it with the configured Monitor key restores any requested target inspector immediately.

Responsive layout has explicit checks at 1280×720 and 1920×1080. It changes reserved panel widths rather than applying per-resolution node positions; graph placement continues to use the visualization configuration and computed safe rectangle.
