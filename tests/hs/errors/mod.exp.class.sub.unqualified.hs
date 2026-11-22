-- rows: R30
-- Report 5.2: subordinate method names are unqualified (and 9.5 by erratum Sept 2004): not C(N.m) (R30).
module Main (main, C(Main.m)) where

class C a where
  m :: a -> Int

main :: IO ()
main = return ()
