# Shared Win32 GUI contracts

Area: Foreign interfaces

The native Windows, SDL3 and deterministic mock implementations share
`Win32Common.Types`. Their registries validate every identity and reject
values belonging to another implementation or an ended lifetime. Provider
support factories create unregistered tokens; they carry no native pointer
or permission to use a native resource.

A pen or brush and its generic GDI object share one identity and lifetime.
Paint scopes and registered classes have separate identities. Native
addresses stay in the generic foreign resource registry. Public messages
carry copied values; text characters preserve individual UTF-16 code units.

`WIN32` is the stable public surface. Applications select an implementation
through a virtual build module; implementation setup and deterministic mock
controls have separate interfaces.
