-- rows: R7
-- Report 2.4 and 5: modid -> conid, so `M.Just.negate` is the qualified constructor `M.Just`, then `.`, then `negate`:
-- a composition, not a variable of a module `M.Just`.
module Main (main) where

import qualified Prelude as M
import Prelude

main :: IO ()
main = print ((M.Just.negate) 1 :: Maybe Int)
