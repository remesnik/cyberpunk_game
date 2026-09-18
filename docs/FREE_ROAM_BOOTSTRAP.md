# Free Roam Playable Bootstrap

Free Roam begins at `SAFEHOUSE_DECK_BAY` in the non-modal deck-management state. The starter owns a Field Deck Mk1, Service Probe, Route Sniffer, two independently identified Doorstop instances, a basic network adapter, 750 credits, and software-programming resources. Programs can be installed or removed before connecting; programming, collection, equipment ordering, and hardware upgrades use the shared production systems.

The home directory exposes City Net Alpha immediately and leads for Dockworks Logistics and the Civic Archive Mirror. The playable City Net graph currently contains the Public and Industrial Mesh Spheres, a public job broker, software bazaar, logistics telemetry/control services, freight datastore/database targets, and a low-level Industrial Patrol ICE process. Unknown portions remain subject to normal discovery rules.

`free_roam_jobs.tres` supplies five static test contracts:

- Data Extraction — retrieve a routing manifest from the freight datastore.
- Feed Tap — access logistics telemetry.
- System Control — manipulate a fictional warehouse controller.
- Database Query — acquire a freight database record.
- Network Recon — map the Industrial Mesh.

`FreeRoamJobBoard` handles availability, acceptance, persistent active/completed IDs, and rewards. It is deliberately small: objective-event binding and generated contracts are future work, not a procedural mission generator. The meat-space home panel exposes the network directory and job source, and accepted jobs persist through `PersistentGameState` save data.
