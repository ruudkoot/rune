-- rows: mod.inst.imported mod.inst.chain mod.inst.emptylist mod.inst.qualified mod.inst.hidden
-- Report 5.4: instances are exported by an export list naming nothing, imported by any import, so along a chain, by an
-- empty list, a qualified one and one that hides the type.
module Main (main) where

import B (useB, theT)
import Q
import H
import E

main :: IO ()
main = mapM_ putStrLn [useB, useQ, useH, useE, show theT]
