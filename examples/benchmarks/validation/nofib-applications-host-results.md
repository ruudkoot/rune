# Parser, Reptile, HPG and Fluid host results

The [recorded wave](../results/m4-parser-reptile-hpg-fluid/README.md) contains
209 passing profile combinations out of 224. All 128 Rune combinations pass.
Fifteen host failures remain visible: three ML Kit smoke compile timeouts,
four HPG legacy SML/NJ result failures, two Fluid legacy result failures and
six Fluid strict SML/NJ fatal signals during interactive loading.

The related [SML/NJ real-pair defect](../../../docs/bugreport/smlnj/Datatype/real-pair-through-type-constructor/BUGREPORT.md)
explains why constructor-boundary probes matter; source-level similarity is
not proof of the cause of each application failure. Canonical semantic checks
record 52 complete groups plus four incomplete SML/NJ groups. All attempted
checks, initial test compiles and final source identities are preserved.
