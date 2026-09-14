# Rune bytecode contract

The bytecode format is a portable interchange format between the Standard ML
compiler and the C runtime. It is not a dump of C or SML/NJ runtime values.

Every future instruction must document:

1. opcode and format version;
2. operand widths and signedness;
3. byte order;
4. stack/register effects;
5. allocation and control-flow effects;
6. malformed-input behavior;
7. compatibility impact.

The runtime must validate the complete bytecode header and instruction stream
before execution when validation is requested. Execution of malformed input
must fail with a structured status, never undefined behavior.

The initial `Halt` opcode in `src/sml/rune.sml` and `src/runtime/rune_vm.c` is a
bootstrap placeholder, not a committed long-term encoding. Promote it to a
versioned format only alongside a serializer, verifier, and conformance
fixtures.
