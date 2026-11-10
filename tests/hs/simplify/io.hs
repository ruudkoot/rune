-- IO through the state token (D25): binds and returns of the Prelude's
-- IO inlined, mapM_, sequence and an action run twice, whose thunk is made
-- once: the state hack (D48's D) would make it twice, which the output
-- does not show and the count does.
-- fuel: every lint holds and it prints the same whatever rewrite it stops after
module Main where

act :: Int -> IO ()
act n = let t = sum [1 .. n] in putStrLn ("t = " ++ show t)

loop :: Int -> IO ()
loop 0 = return ()
loop k = do
  if k `mod` 3 == 0 then putStr "." else return ()
  loop (k - 1)

main :: IO ()
main = do
  let a = act 100
  a
  a
  mapM_ print [1, 2, 3 :: Int]
  xs <- sequence [return 1, return 2, return (3 :: Int)]
  print xs
  loop 10
  putStrLn ""
  r <- return 5 >>= \x -> return (x * 2 :: Int)
  print r
