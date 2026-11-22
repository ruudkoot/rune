-- rows: std.list.read std.list.show std.list.eq std.list.ord std.list.monad std.list.functor
-- Report 6.1.3: lists, [] before :, with Eq, Ord, Read, Show, Functor and Monad.
module Main (main) where

main :: IO ()
main = do
  print (case [1 :: Int] of { [] -> 0; (x : _) -> x })
  print ([1, 2] == (read "[1,2]" :: [Int]), show [1, 2 :: Int], [1] == [1 :: Int], [1] < [1, 2 :: Int], [] < [0 :: Int])
  print (do { x <- [1, 2 :: Int]; y <- "ab"; return (x, y) })
  print (fmap (+ 1) [1, 2 :: Int])
