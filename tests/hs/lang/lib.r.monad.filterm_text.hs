-- rows: lib.r.monad.msum lib.r.monad.monadplus.maybe lib.r.monad.monadplus.list lib.r.monad.join lib.r.monad.mapandunzipm lib.r.monad.zipwithm lib.r.monad.foldm lib.r.monad.when lib.r.monad.example.liftm2.list lib.r.monad.example.liftm2.maybe lib.r.monad.ap
-- Report 20.1 to 20.3: the text's statements of Monad on its examples: filterM and msum at the types shown, generalising
-- filter and sum (filterM in the list monad is the powerset); MonadPlus Maybe and []; join on lists, Maybe and IO;
-- mapAndUnzipM, zipWithM; foldM and its expansion; when debug (putStr "Debugging\n"); liftM2 (+) [0,1] [0,2] =
-- [0,2,1,3] and liftM2 (+) (Just 1) Nothing = Nothing; return f `ap` x1 `ap` ... `ap` xn is liftMn f x1 ... xn
-- for n = 1 to 5. The expected output is the Report's code's.
module Main (main) where

import Monad

filterM' :: Monad m => (a -> m Bool) -> [a] -> m [a]
filterM' = filterM

sequence' :: Monad m => [m a] -> m [a]
sequence' = sequence

sequence_' :: Monad m => [m a] -> m ()
sequence_' = sequence_

msum' :: MonadPlus m => [m a] -> m a
msum' = msum

main :: IO ()
main = do
  print (filterM (const [True, False]) [1, 2, 3 :: Int], filterM' (\x -> Just (x > 1)) [1, 2, 3 :: Int], filter (> 1) [1, 2, 3 :: Int])
  print (msum [[1], [], [2, 3 :: Int]], msum [Nothing, Just 'a', Just 'b'], msum' ([] :: [Maybe Int]), sum [1, 2, 3 :: Int])
  print (mzero :: Maybe Int, Nothing `mplus` Just 'y', Just 'x' `mplus` Just 'y', Just 'x' `mplus` Nothing, (Nothing :: Maybe Int) `mplus` Nothing)
  print (mzero :: [Int], [1, 2] `mplus` [3 :: Int], [] `mplus` "ab", sequence' [Just 1, Just (2 :: Int)], sequence_' [[1, 2], [3 :: Int]])
  print (join [[1, 2], [3 :: Int]], join (Just (Just 'j')), join (Just (Nothing :: Maybe Int)))
  join (return (putStrLn "join in IO"))
  print (mapAndUnzipM (\x -> Just (x, x * x)) [1, 2, 3 :: Int], mapAndUnzipM (\x -> [(x, 'a'), (x, 'b')]) [1, 2 :: Int])
  print (zipWithM (\a b -> if b /= 0 then Just (a `div` b) else Nothing) [6, 8] [3, 2 :: Int], zipWithM (\a b -> if b /= 0 then Just (a `div` b) else Nothing) [6, 8] [3, 0 :: Int], zipWithM (\a b -> [a, b]) "ab" "cd")
  print (foldM (\a x -> [a + x, a - x]) 0 [1, 2 :: Int], foldM (\a x -> if x == 0 then Nothing else Just (a `div` x)) 100 [2, 5 :: Int])
  print (foldM f 1 [2, 3, 4] == (do { a2 <- f 1 2; a3 <- f a2 3; f a3 4 }), foldM f 1 [2, 3, 4])
  when debug (putStr "Debugging\n")
  when (not debug) (putStr "not shown\n")
  unless (not debug) (putStr "unless False\n")
  unless debug (putStr "not shown\n")
  print (liftM2 (+) [0, 1] [0, 2 :: Int], liftM2 (+) [0, 1] [0, 2 :: Int] == [0, 2, 1, 3], liftM2 (+) (Just 1) (Nothing :: Maybe Int), liftM2 (+) (Just 1) (Nothing :: Maybe Int) == Nothing)
  print (return (+ 1) `ap` [1, 2 :: Int] == liftM (+ 1) [1, 2], return (*) `ap` [1, 2] `ap` [3, 4 :: Int] == liftM2 (*) [1, 2] [3, 4], return (\a b c -> a + b + c) `ap` [1] `ap` [2, 3] `ap` [4 :: Int] == liftM3 (\a b c -> a + b + c) [1] [2, 3] [4])
  print (return (\a b c d -> [a, b, c, d]) `ap` [1, 2] `ap` [3] `ap` [4] `ap` [5, 6 :: Int] == liftM4 (\a b c d -> [a, b, c, d]) [1, 2] [3] [4] [5, 6], return (\a b c d e -> [a, b, c, d, e]) `ap` Just 'a' `ap` Just 'b' `ap` Just 'c' `ap` Just 'd' `ap` Just 'e' == liftM5 (\a b c d e -> [a, b, c, d, e]) (Just 'a') (Just 'b') (Just 'c') (Just 'd') (Just 'e'))
  where f a x = [a * x, a + x :: Int]
        debug = True
