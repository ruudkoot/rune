-- rows: lib.monad.join lib.monad.when lib.monad.unless lib.monad.ap lib.monad.guard lib.monad.mapandunzipm lib.monad.zipwithm lib.monad.zipwithmu lib.monad.foldm lib.monad.filterm lib.monad.liftm lib.monad.liftm2 lib.monad.liftm3 lib.monad.liftm4 lib.monad.liftm5 lib.monad.inst.monadplusmaybe lib.monad.inst.monadpluslist
-- Report 20.4: the functions of Monad, and MonadPlus's instances for Maybe and lists, against the Report's own module
-- copied under new names (a class MonadPlus_r of its own), in the list and Maybe monads.
module Main (main) where

import Monad

-- The MonadPlus_r class definition

class  (Monad m) => MonadPlus_r m  where
    mzero_r  :: m a
    mplus_r  :: m a -> m a -> m a


-- Instances of MonadPlus_r

instance  MonadPlus_r Maybe  where
    mzero_r                 = Nothing

    Nothing `mplus_r` ys    =  ys
    xs      `mplus_r` ys    =  xs

instance  MonadPlus_r []  where
    mzero_r =  []
    mplus_r = (++)


-- Functions


msum_r                 :: MonadPlus_r m => [m a] -> m a
msum_r xs                 =  foldr mplus_r mzero_r xs

join_r             :: (Monad m) => m (m a) -> m a
join_r x           =  x >>= id

when_r             :: (Monad m) => Bool -> m () -> m ()
when_r p s         =  if p then s else return ()

unless_r           :: (Monad m) => Bool -> m () -> m ()
unless_r p s       =  when_r (not p) s

ap_r               :: (Monad m) => m (a -> b) -> m a -> m b
ap_r               =  liftM2_r ($)

guard_r            :: MonadPlus_r m => Bool -> m ()
guard_r p          =  if p then return () else mzero_r

mapAndUnzipM_r     :: (Monad m) => (a -> m (b,c)) -> [a] -> m ([b], [c])
mapAndUnzipM_r f xs = sequence (map f xs) >>= return . unzip

zipWithM_r         :: (Monad m) => (a -> b -> m c) -> [a] -> [b] -> m [c]
zipWithM_r f xs ys =  sequence (zipWith f xs ys)

zipWithM__r         :: (Monad m) => (a -> b -> m c) -> [a] -> [b] -> m ()
zipWithM__r f xs ys =  sequence_ (zipWith f xs ys)

foldM_r            :: (Monad m) => (a -> b -> m a) -> a -> [b] -> m a
foldM_r f a []     =  return a
foldM_r f a (x:xs) =  f a x >>= \ y -> foldM_r f y xs

filterM_r :: Monad m => (a -> m Bool) -> [a] -> m [a]
filterM_r p []     = return []
filterM_r p (x:xs) = do { b  <- p x;
                        ys <- filterM_r p xs;
                        return (if b then (x:ys) else ys)
                   }

liftM_r            :: (Monad m) => (a -> b) -> (m a -> m b)
liftM_r f          =  \a -> do { a' <- a; return (f a') }

liftM2_r           :: (Monad m) => (a -> b -> c) -> (m a -> m b -> m c)
liftM2_r f         =  \a b -> do { a' <- a; b' <- b; return (f a' b') }

liftM3_r           :: (Monad m) => (a -> b -> c -> d) ->
                                 (m a -> m b -> m c -> m d)
liftM3_r f         =  \a b c -> do { a' <- a; b' <- b; c' <- c;
                                   return (f a' b' c') }

liftM4_r           :: (Monad m) => (a -> b -> c -> d -> e) ->
                                 (m a -> m b -> m c -> m d -> m e)
liftM4_r f         =  \a b c d -> do { a' <- a; b' <- b; c' <- c; d' <- d;
                                     return (f a' b' c' d') }

liftM5_r           :: (Monad m) => (a -> b -> c -> d -> e -> f) ->
                                 (m a -> m b -> m c -> m d -> m e -> m f)
liftM5_r f         =  \a b c d e -> do { a' <- a; b' <- b; c' <- c; d' <- d;
                                       e' <- e; return (f a' b' c' d' e') }

ms :: [Maybe Int]
ms = [Nothing, Just 1, Just 2]

ls :: [[Int]]
ls = [[], [1], [2, 3]]

g :: Int -> [Int]
g x = [x, x + 100]

main :: IO ()
main = do
  print (and [mplus a b == mplus_r a b | a <- ms, b <- ms], and [mplus a b == mplus_r a b | a <- ls, b <- ls], (mzero :: Maybe Int) == mzero_r, (mzero :: [Int]) == mzero_r)
  print (and [msum xs == msum_r xs | xs <- [[], ms, reverse ms]], and [msum xs == msum_r xs | xs <- [[], ls]], and [join x == join_r x | x <- [Nothing, Just Nothing, Just (Just 'j')]], join [[1, 2], [], [3 :: Int]] == join_r [[1, 2], [], [3]])
  print (and [(guard b :: Maybe ()) == guard_r b && (guard b :: [()]) == guard_r b | b <- [False, True]], and [when b (Just ()) == when_r b (Just ()) && unless b Nothing == unless_r b Nothing && when b [(), ()] == when_r b [(), ()] | b <- [False, True]])
  print (and [ap fs xs == ap_r fs xs | fs <- [[], [(+ 1), (* 2)]], xs <- ls], ap (Just (+ 1)) (Just 2) == ap_r (Just (+ 1)) (Just (2 :: Int)), ap Nothing (Just 'a') == (ap_r Nothing (Just 'a') :: Maybe Char))
  print (mapAndUnzipM (\x -> [(x, -x), (x * 2, x)]) [1, 2 :: Int] == mapAndUnzipM_r (\x -> [(x, -x), (x * 2, x)]) [1, 2], and [mapAndUnzipM h xs == mapAndUnzipM_r h xs | xs <- ls ++ [[0, 1]]])
  print (and [zipWithM (\a b -> g (a + b)) xs ys == zipWithM_r (\a b -> g (a + b)) xs ys && zipWithM_ (\a b -> g (a + b)) xs ys == zipWithM__r (\a b -> g (a + b)) xs ys | xs <- ls, ys <- ls])
  print (and [foldM k 0 xs == foldM_r k 0 xs | xs <- [[], [1, 3, 7], [1, 0, 5]]], foldM (\a x -> [a + x, a * x]) 1 [2, 3 :: Int] == foldM_r (\a x -> [a + x, a * x]) 1 [2, 3])
  print (and [filterM p xs == filterM_r p xs | p <- [const [True, False], \x -> [x > 1]], xs <- ls ++ [[1, 2, 3]]], filterM (\x -> if x > 0 then Just (even x) else Nothing) [2, 3 :: Int] == filterM_r (\x -> if x > 0 then Just (even x) else Nothing) [2, 3])
  print (liftM (+ 1) [1, 2 :: Int] == liftM_r (+ 1) [1, 2], liftM2 (+) [0, 1] [0, 2 :: Int] == liftM2_r (+) [0, 1] [0, 2], liftM3 (\a b c -> a + b + c) [1, 2] [10] [100, 200 :: Int] == liftM3_r (\a b c -> a + b + c) [1, 2] [10] [100, 200])
  print (liftM4 (\a b c d -> [a, b, c, d]) [1, 2] [3] [4, 5] [6 :: Int] == liftM4_r (\a b c d -> [a, b, c, d]) [1, 2] [3] [4, 5] [6], liftM5 (\a b c d e -> [a, b, c, d, e]) [1] [2, 3] [4] [5] [6, 7 :: Int] == liftM5_r (\a b c d e -> [a, b, c, d, e]) [1] [2, 3] [4] [5] [6, 7], liftM5 (\a _ _ _ _ -> a) (Just 'x') (Just ()) Nothing (Just ()) (Just ()) == liftM5_r (\a _ _ _ _ -> a) (Just 'x') (Just ()) Nothing (Just ()) (Just ()))
  where h x = if x > 0 then Just (x, x * x) else Nothing
        k a x = if x > a then Just (a + x) else Nothing
