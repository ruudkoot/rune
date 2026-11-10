-- rows: lib.r.monad.liftm.order lib.r.monad.example.listfile
-- Report 20.3: foldM works left to right; the lifted function's arguments are scanned left to right; the text's listFile
-- prefixes each line of a file with its number; zipWithM_, mapAndUnzipM and filterM in IO, in order.
module Main (main) where

import Monad

step :: Int -> Int -> IO Int
step a x = do { putStrLn ("step " ++ show a ++ " " ++ show x); return (a + x) }

listFile :: String -> IO ()
listFile nm =
  do cts <- readFile nm
     zipWithM_ (\i line -> do putStr (show i); putStr ": "; putStrLn line)
               [1..]
               (lines cts)

say :: String -> a -> IO a
say s x = putStrLn s >> return x

main :: IO ()
main = do
  r <- foldM step 0 [1, 2, 3]
  print r
  p <- liftM2 (,) (say "first" 'a') (say "second" 'b')
  print p
  t <- liftM5 (\a b c d e -> [a, b, c, d, e]) (say "1" 'v') (say "2" 'w') (say "3" 'x') (say "4" 'y') (say "5" 'z')
  print t
  writeFile "listfile.txt" "alpha\nbeta\n\ngamma\n"
  listFile "listfile.txt"
  zipWithM_ (\a b -> print (a, b)) "ab" [1, 2, 3 :: Int]
  u <- mapAndUnzipM (\x -> say ("m " ++ show x) (x, -x)) [1, 2 :: Int]
  print u
  v <- filterM (\x -> say ("f " ++ show x) (odd x)) [1, 2, 3 :: Int]
  print v
