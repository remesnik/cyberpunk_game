# Frontend Quality Pass

## Inventory

Scenes: `frontend_root`, `splash_screen`, `main_menu`, `game_mode_selection`, `load_screen`, `settings_screen`, `credits_screen`, reusable menu/panel/label/background/mode-option components, the audio controller, and the transition layer.

Scripts: central frontend navigation; splash sequencing; menu focus, feedback, and idle behavior; data-driven credits; load/settings screen adapters; accessibility propagation; frontend audio; procedural background and transition rendering.

Resources: the shared frontend `Theme`, `CreditsData` with structured sections and entries, `FrontendAccessibilityConfig`, and `FrontendAudioProfile`. Final fonts, logo treatment, sound streams, and third-party attribution can be replaced without changing navigation scripts.

## Navigation

`project.godot` has one startup scene: `frontend_root.tscn`. `FrontendRoot.transition_to(screen_id, transition_type)` is the sole frontend screen switcher. It owns Splash, Main Menu, Game Mode Selection, Load, Settings, and Credits, blocks duplicate input during transitions, and defers destination focus to prevent input leakage. New Game opens Game Mode Selection; only explicit STORY MODE or FREE ROAM activation emits `game_mode_requested` and performs the gameplay handoff. Continue and Load delegate save operations to `FrontendSaveProvider`.

Automated coverage checks 1920x1080, 2560x1440, 3440x1440, 1280x720, and a 960x540 resized layout; splash skip and automatic completion; explicit focus navigation; rapid-transition rejection; credits scrolling; Back routes; quit confirmation; and reduced-animation operation.

The Game Mode Selection screen uses a two-frame release gate after entry, so the mouse/controller/keyboard action that opened the screen cannot activate a mode. Wide layouts use two centered horizontal cards; narrow or short layouts stack compact cards. Directional focus neighbors follow the active layout. Focus adds a strong perimeter, side rail, corner treatment, and explicit `SELECTED // CONFIRM TO CONTINUE` state without moving the hitbox. Hover has a separate pointed state, activation always opens the summary, and Back returns either to the cards or Main Menu. Reduced-animation mode preserves all static focus treatments.

## Outstanding placeholders

- Settings currently reports applied accessibility values; persistent preference storage and editable controls remain TODO.
- Save/Load uses a clean provider contract and empty browser state; aggregate gameplay serialization and production save-slot widgets remain TODO.
- Audio streams, final logo/font assets, localized copy, controller glyphs, and platform-specific quit behavior require final production assets and platform QA.
- Physical mouse/controller hardware, HDR, DPI scaling, localization expansion, and console safe-area behavior still require device testing; headless checks validate layout bounds and logic only.
