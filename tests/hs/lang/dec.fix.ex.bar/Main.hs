-- rows: dec.fix.ex.foo
-- Report 4.4.2's example: Bar exports op infixr 7; Foo declares its own op infix 3: Bar.op and op each keep
-- their entity's fixity.
module Main (main) where

import qualified Bar

infix 3 `op`

op :: Int -> Int -> Int
a `op` b = (a `Bar.op` b) + 1

main :: IO ()
main = print (10 `Bar.op` 3 `Bar.op` 2, 2 * 5 `op` 3, 2 * 5 `Main.op` 3)
