-- The cycle of A and B, and a use of it.
module All () where

import A
import B

check :: (Bool, Int)
check = (isEven (10 :: Integer), size (U TEnd) <+> 1)
