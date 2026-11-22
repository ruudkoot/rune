-- rows: dec.note.patbind.npk dec.note.funbind.star dec.note.funbind.paren
-- Report 4.4.3, the note: x + 1 = ... binds +, (x + 1) = ... binds x by n+k, (n + 1) * y = ... binds * with an n+k first
-- argument, and (x + y) z = ... binds + of three arguments.
module Main (main) where

import Prelude hiding ((+), (*))
import qualified Prelude as P

main :: IO ()
main = do
  print (let { a + 1 = a P.* 10 } in 7 + 1 :: Int)
  print (let { (x + 1) = 5 } in x :: Int)
  print (let { (n + 1) * y = n P.* y } in 4 * 10 :: Int)
  print (let { (a + b) c = a P.+ b P.+ c } in (+) 1 2 3 :: Int)
