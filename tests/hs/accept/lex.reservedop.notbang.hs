-- rows: lex.op.rebind
-- Report 2.4: "! is not reserved", nor are - and . ; "all of the standard infix operators are just predefined
-- symbols and may be rebound": (!), (+), (-) and (.) defined at top level, the Prelude's hidden, and + locally.
module Main (main) where

import Prelude hiding ((+), (-), (.))
import qualified Prelude as P

(!), (+), (-), (.) :: Int -> Int -> Int
a ! b = a P.* b
a + b = a P.- b
a - b = a P.+ b
a . b = a P.* b P.* 2

main :: IO ()
main = print (2 ! 3, 2 + 3, 2 - 3, 2 . 3, let a + b = a P.* b in 2 + 3)
