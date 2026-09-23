# Authored network packages

`*.netspace` files are versioned, authenticated encrypted packages loaded by
`NetworkDocumentRuntimeLoader`. They are the gameplay source of truth for
network topology. Do not hand-edit them or replace them with scene serialization.

`first_contact.netspace` is generated from the former
`data/authoring/first_contact_current.tres` source by the one-time migration tool
at `tools/network_document/MigrateFirstContactNetwork.gd`. The legacy resource is
retained temporarily as migration provenance and for older focused fixture tests;
Story Mode does not load its topology.
