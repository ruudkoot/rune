-- Report 18.1: a bottom probe of mapMaybe, the Report's own definition its reference: mapMaybe (\x -> if x > 1 then Nothing else Just x) (1 : 2 : ul) is bottom;
-- a marker, then the term, element by element.
module Main (main) where

import Maybe

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (mapMaybe (\x -> if x > 1 then Nothing else Just x) (1 : 2 : ul)))
