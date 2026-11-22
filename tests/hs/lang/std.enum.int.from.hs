-- rows: std.enum.int.then std.enum.int.then.zero std.enum.int.then.neg std.enum.int.to std.enum.int.to.empty std.enum.int.thento.pos std.enum.int.thento.zero std.enum.int.thento.pos.empty std.enum.int.thento.neg std.enum.int.thento.neg.empty R40
-- Report 6.3.4: the integral sequences: [n..], [n,n'..], [n..m] and [n,n'..m], increasing, constant and decreasing.
module Main (main) where

main :: IO ()
main = do
  print (take 3 [1 :: Int ..], take 3 [1 :: Int, 3 ..], take 3 [1 :: Int, 1 ..], take 3 [3 :: Int, 2 ..])
  print ([1 .. 3 :: Int], [3 .. 1 :: Int], [1, 3 .. 6 :: Int], take 2 [1, 1 .. 1 :: Int])
  print ([3, 4 .. 1 :: Int], [5, 3 .. 0 :: Int], [1, 0 .. 5 :: Int])
  print (take 3 [1 :: Integer ..], [5, 3 .. 0 :: Integer])
