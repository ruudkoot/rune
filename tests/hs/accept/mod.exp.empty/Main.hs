-- rows: mod.exp.value mod.exp.value.imported mod.exp.field mod.exp.method mod.exp.value.qualified mod.exp.op mod.exp.synonym mod.exp.type.abs.ok mod.exp.class.abs.ok
-- Report 5.2: an empty export list; a value declared or imported, a field and a method alone, qualified, an operator in
-- parentheses, a synonym, and a type and a class by their names.
module Main (main) where

import Nothing
import M

main :: IO ()
main = print ((x, y, f (R 1), m True), (z, 1 +++ 2, (1 :: S), abs1 t))
