-- NofibCompat: the names the 2019 nofib tree takes from outside the Report for its harness.  Haskell 98.
module NofibCompat where

import IO (Handle)

type IOException = IOError

type TextEncoding = ()


infixl 4 <$>

(<$>) :: Functor f => (a -> b) -> f a -> f b
(<$>) = fmap

pure :: Monad m => a -> m a
pure = return

forM_ :: Monad m => [a] -> (a -> m b) -> m ()
forM_ xs f = mapM_ f xs

forM :: Monad m => [a] -> (a -> m b) -> m [b]
forM xs f = mapM f xs

replicateM_ :: Monad m => Int -> m a -> m ()
replicateM_ n x = sequence_ (replicate n x)

replicateM :: Monad m => Int -> m a -> m [a]
replicateM n x = sequence (replicate n x)

foldl' :: (a -> b -> a) -> a -> [b] -> a
foldl' f z [] = z
foldl' f z (x:xs) = let z' = f z x in z' `seq` foldl' f z' xs

void :: Functor f => f a -> f ()
void = fmap (const ())

evaluate :: a -> IO a
evaluate x = x `seq` return x

hSetBinaryMode :: Handle -> Bool -> IO ()
hSetBinaryMode _ _ = return ()

hSetEncoding :: Handle -> TextEncoding -> IO ()
hSetEncoding _ _ = return ()

utf8, latin1 :: TextEncoding
utf8 = ()
latin1 = ()

catchIOError :: IO a -> (IOError -> IO a) -> IO a
catchIOError = catch
