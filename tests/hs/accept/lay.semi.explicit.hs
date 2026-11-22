-- rows: lay.semi.empty
-- Report 9.3: explicit semicolons may stand in an implicit block, and layout's ; before an empty item is harmless where
-- the grammar has empty items: empty declarations, alternatives and statements, and empty imports.
module Main (main) where

import Prelude ; ;
import Char

;
f :: Int -> Int
;
f x = case x of
  0 -> 1 ;
  ;
  _ -> 2

main :: IO ()
main = do print (f 0); print (f 1)
          ; ;
          print (ord 'a')
