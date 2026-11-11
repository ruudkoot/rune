-- rows: R20
-- Report 4.5.5 and 5.7 (R20, D30; ruling 49 makes the row a refusal): for mutually recursive modules the Report does
-- not say what "an entire module" is when Rule 2 closes a monomorphic variable. rhc's reading is D30's: the module,
-- by default (--cycle-default=module), so A's x, restricted and unsigned, is defaulted at the end of A, and B's use of
-- it at Int is refused; --cycle-default=scc, an extension, would close it at the end of the cycle.
module Main (main) where

import A
import B

main :: IO ()
main = print (f 3, y)
