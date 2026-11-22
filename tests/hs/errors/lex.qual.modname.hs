-- rows: R7
-- Report 2.4 and 5: modid -> conid, one conid and no more, "Module names are not qualified": `import A.B` is no
-- Haskell 98 (hierarchical names are refused by default, D35).
module Main (main) where

import Data.List

main :: IO ()
main = return ()
