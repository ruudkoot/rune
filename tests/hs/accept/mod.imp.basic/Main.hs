-- rows: mod.imp.multiple mod.imp.toplevel mod.imp.cumulative mod.imp.order mod.imp.list.var mod.imp.list.op mod.imp.list.type mod.imp.list.type.some mod.imp.list.type.none mod.imp.list.class mod.imp.list.dotdot mod.imp.hiding.rest mod.imp.hiding.empty mod.imp.all
-- Report 5.3, 5.3.1: imports bring exported entities into scope over the whole module, several imports of one module add up
-- in any order, an import list names values, fields, methods, operators, types and classes with their parts or
-- (..), and hiding brings in the rest.
module Main (main) where

import Lib (z, T(B, fld), U(), C, D(dm), (+++))
import Lib hiding (w)
import Lib (w)
import Lib2 (V(..))
import Lib2 hiding ()

g :: C a => a -> Int
g = cm

main :: IO ()
main = print ((z, fld (B 1), dm True, 1 +++ 2), (w, P, v2), (case Q of Q -> 0, g True))
