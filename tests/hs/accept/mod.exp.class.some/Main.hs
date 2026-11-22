-- rows: mod.exp.class.all
-- Report 5.2: C(f1, ..., fn) exports the class with the methods listed, C(..) with all in scope.
module Main (main) where

import M

main :: IO ()
main = print (l1 mk, v1 mk, v2 mk, f mk)
  where
    f :: K a => a -> Int
    f _ = 0

