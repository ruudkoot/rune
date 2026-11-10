-- Report 17.9: a bottom probe of mapAccumL, the Report's own definition its reference: head (snd (mapAccumL (\s x -> (s, x)) 0 (1 : ul))) is not;
-- a marker, then the term.
module Main (main) where

import List

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (head (snd (mapAccumL (\s x -> (s, x)) 0 (1 : ul))))
