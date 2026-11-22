-- rows: std.list.ord
-- Report 6.1.3, 8 (overlay ov.prelude.list; M17's bottom probes on the literal Prelude): Eq and Ord of lists, which
-- the Report declares by its deriving clause and rhc writes out; the reference is that clause under another name,
-- data L a = N | C a (L a) deriving (Eq, Ord) (chapter 10). A marker, then the terms; the last is bottom.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print ([1, 2] == [1, 3 :: Int], [1] == [1, 2 :: Int], [] == ([] :: [Int]), compare [1, 2] [1 :: Int], [] < [0 :: Int])
  print ((1 : 2 : ul) == [1, 3], (1 : ul) == [], compare (1 : ul) [2], (1 : ul) > [], max [] (1 : ul) /= [])
  print (compare [3, u] [2, u], [3, u] > [2, u])
  print ([1, u] == [1, 2])
