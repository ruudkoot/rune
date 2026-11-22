-- H's probe (M16b): a derived Ord and Ix of an enumeration compare the constructors' positions, which are Ints
-- whatever the module's `default` says; under `default ()` a literal there would have no type.
module NoDefault (check) where

import Ix (Ix, range, index)

default ()

data E = A | B | C deriving (Eq, Ord, Enum, Bounded, Show, Read, Ix)

check :: (Ordering, [E], [E], Int)
check = (compare A B, [A ..], range (A, C), index (A, C) B)
