-- Report 8: a bottom probe of foldr, the Report's own definition its reference: foldr (\x _ -> x) 0 (1 : ul) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (foldr (\x _ -> x) 0 (1 : ul))
