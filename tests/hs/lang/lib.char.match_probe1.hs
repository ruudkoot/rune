-- Report 19.1: a bottom probe of match, the Report's own definition its reference: fst (head (readLitChar ("\\NUL" ++ undefined))) is not;
-- a marker, then the term.
module Main (main) where

import Char

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (fst (head (readLitChar ("\\NUL" ++ undefined))))
