-- Report 9.3: L tokens [] is the layout-insensitive translation of the module's annotated lexemes. This module uses
-- each of L's equations: a block opened after where, let, do and of at a deeper column ({n}), a line at a block's
-- column (<n>, a ;), a line left of it (an implicit }), an empty block where the next lexeme is no deeper, an
-- explicit { } inside an implicit block, and a close by parse-error(t) (a let and its in on one line). That rhc's L
-- is the section's is what hs/syntax/expansions holds, token by token, against tests/hs/roundtrip's hand expansions.
module Main (main) where

class C a where
instance C Int

main :: IO ()
main = do
  let x = 1
      y = x + 1
  print (f y)
  case y of
    2 -> putStrLn "two"
    _ -> return ()
  do { putStr "a"; putStrLn "b" }
  print (let z = 3 in z + y :: Int)
  where
    f :: Int -> Int
    f n = g n where g m = m * 2
