-- rows: lay.l.4.inzero lay.l.9 lay.l.7 lay.note3.match
-- Report 9.3: an explicit { pushes the context 0 (equation 9), in which no layout token is made, so its lines may stand
-- at any column; an implicit block inside opens at any column, since n > 0 (equation 4); an explicit } closes
-- the explicit { (equation 7, Note 3).
module Main (main) where

main :: IO ()
main = print (f 1) where {
f :: Int -> Int;
   f x = let y = x
             z = y
         in z
 ; }
