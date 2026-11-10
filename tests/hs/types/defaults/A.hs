-- A module's own default in a cycle (D30): the ambiguity in `a` arises in A,
-- whose default is (Int), so it is an Int under --cycle-default=module; under
-- scc the cycle has one default, and A's and B's, the Report's (Integer,
-- Double), differ, so it is refused.
module A (a) where

import B

default (Int)

a :: String
a = show 7
