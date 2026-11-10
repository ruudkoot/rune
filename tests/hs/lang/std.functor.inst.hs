-- rows: std.functor.law.id std.functor.law.comp std.monad.inst std.monad.fail.list std.monad.fail.maybe pre.inst.functorlist pre.inst.monadlist pre.inst.functormaybe pre.inst.monadmaybe pre.inst.functorio pre.inst.monadio std.monad.law.left std.monad.law.right std.monad.law.assoc std.monad.law.fmap std.monad.aux
-- Report 6.3.5, 6.3.6: the instances of Functor and Monad for lists, Maybe and IO, their laws on samples, fail at lists
-- and Maybe, and the Prelude's sequence, sequence_, mapM, mapM_ and =<< in two monads.
module Main (main) where

k :: Int -> Maybe Int
k x = if x > 0 then Just (x * 2) else Nothing

h :: Int -> Maybe Int
h x = Just (x + 1)

main :: IO ()
main = do
  print (fmap (+ 1) [1, 2 :: Int], fmap (+ 1) (Just (1 :: Int)))
  r <- fmap (+ 1) (return (1 :: Int))
  print r
  print (fmap id [1, 2 :: Int] == [1, 2], fmap ((+ 1) . (* 2)) (Just (3 :: Int)) == (fmap (+ 1) . fmap (* 2)) (Just 3))
  print (do { Just x <- [Nothing]; return (x :: Int) }, do { Just x <- Just Nothing; return (x :: Int) })
  print ((return 3 >>= k) == k 3, (Just 4 >>= return) == Just (4 :: Int), ((Just 1 >>= k) >>= h) == (Just 1 >>= (\x -> k x >>= h)))
  print (fmap (+ 1) (Just (2 :: Int)) == (Just 2 >>= return . (+ 1)))
  print (sequence [Just 1, Just (2 :: Int)], sequence [[1, 2], [3 :: Int]], mapM k [1, 2], mapM k [1, 0])
  print (k =<< Just 5, sequence_ [Just (1 :: Int), Nothing], mapM_ k [1, 2])
  mapM_ print [1, 2 :: Int]
  sequence_ [putStr "a", putStr "b"]
  putStrLn ""
