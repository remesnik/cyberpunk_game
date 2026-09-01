# Authoring Tool Limitations

The first functional version establishes document persistence, graph topology editing, cross-domain browsing, structured condition/action lists, realtime timelines, templates, preview controls, and deterministic validation. Some detailed editing still requires Godot's Resource inspector or direct structured-field editing.

Current limitations:

- The inspector edits common text fields and displays complete structured data, but does not yet provide a bespoke control for every field in every content type.
- Nested ALL/ANY/NOT conditions are represented structurally; the visual editor currently appends rows rather than drawing a nested condition tree.
- Story workspace uses rapid collection editing rather than a dedicated visual Story Graph with cycle visualization.
- Operation view shows linked cyber and meatspace lists plus a combined timeline; it does not yet draw the physical location graph with interactive edges.
- Timeline controls support event creation and editor-only scrubbing, but audio waveform editing and drag-to-reschedule are not implemented.
- Preview clocks and profiles are safe and non-persistent, but the preview does not yet compile the complete authored document into an isolated runtime simulation.
- `PLAY FROM HERE` saves and launches the runtime main scene. Passing a selected node through a dedicated preview launch context remains future work.
- Validation covers high-value referential and timeline errors but does not yet perform SAT-style impossible-condition analysis, full story reachability, or unused-variable graph analysis.
- Template selection uses a compact popup and creates ordinary entries. A template options dialog is not yet present.
- The proof scenario is authored as a `.tres` Resource, but the current runtime vertical slice still has a separate hand-composed bootstrap. A deterministic document-to-runtime compiler is the highest-value bridge still missing.

No arbitrary authored code execution, external telephony, real control protocols, or gameplay speed control was added.
