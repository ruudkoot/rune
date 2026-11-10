-- E15's three signed modules (results/E15/run/boot3/v0), each a type and a
-- function over all three: GHC refuses them with no boot files, and with
-- boots for all three fails with "Unexpected non-cycle"; one unit per SCC
-- reads them (D30). Haskell 98 has no empty data declaration, so each type
-- has a constructor.
module A where
import B
import C
data A = A
a :: A -> B -> C
a = b `seq` c `seq` undefined
