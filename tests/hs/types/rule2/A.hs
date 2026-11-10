-- Rule 2 in a cycle (4.5.5, D30): x, restricted, is monomorphic at the end
-- of A, and A alone would default it to Integer; B's use fixes it as Int.
-- Under --cycle-default=module, Rule 2 closes at the end of each module, and
-- B's use is refused; under scc, at the end of the cycle, and x is an Int.
module A (x) where

import B

x = 1

double :: Int
double = y * 2
