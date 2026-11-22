-- Report 8: a bottom probe of lcm, the Report's own definition its reference: lcm u 0 is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (lcm u 0)
