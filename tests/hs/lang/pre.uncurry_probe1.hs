-- Report 8: a bottom probe of uncurry, the Report's own definition its reference: uncurry (\_ _ -> 1 :: Int) (undefined :: (Int, Int)) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (uncurry (\_ _ -> 1 :: Int) (undefined :: (Int, Int)))
