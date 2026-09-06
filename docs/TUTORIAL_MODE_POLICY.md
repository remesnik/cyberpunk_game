# Tutorial Mode Policy

Tutorial entry policy is separate from authored tutorial mechanics.

## Story Mode

Story Mode automatically selects `FIRST_CONTACT` as the campaign entry. Its Latch dialogue, objectives, progression flags, and authored mission context are enabled as part of the normal campaign.

## Free Roam

After selecting Free Roam, the frontend asks `RUN INTRODUCTION?`.

- **Yes** selects `FIRST_CONTACT_FREE_ROAM_TUTORIAL`, a Free-Roam-only content wrapper that reuses the FIRST_CONTACT graph, Latch actor, ICE, trace, Doorstop, realtime communications, and other production systems. Its profile explicitly disables campaign progression. Completion routes to `FREE_ROAM_HOME`.
- **No** selects `FREE_ROAM_HOME` immediately and opens deck management without a mandatory tutorial.

The wrapper avoids copying the tutorial graph or mechanics. Narrative differences and future shortening can be expressed in its content profile or per-beat eligibility rather than by forking runtime systems.

Mode cards use one inline summary state before startup. `START` commits the selected mode and `BACK` returns to the two cards. If the configured save provider reports a valid resumable session, this summary displays an overwrite warning; no warning is inferred from filenames or unrelated game flags.
