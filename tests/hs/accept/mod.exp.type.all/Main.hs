-- rows: mod.exp.type.all.qualified
-- Report 5.2: T(..) exports the type with every constructor and field in scope, qualified or not.
module Main (main) where

import M
import M2

main :: IO ()
main = print (case C 1 of { C n -> n ; D m -> m ; E -> 0 }, fld (D 2), case P of P -> 0)
