-- E16's fixture cyc (results/E16/tests/cyc): A and B export each other's
-- module, under a Prelude of the program's own, empty, so the library is not
-- read: 5 pairs at the least fixpoint, 7 at the greatest, where C's c is
-- exported by A and B, which never import C.
module All () where

import A
import B
import C
