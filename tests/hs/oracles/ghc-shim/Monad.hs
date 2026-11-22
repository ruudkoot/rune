module Monad (
    MonadPlus(mzero, mplus),
    join, guard, when, unless, ap, msum,
    filterM, mapAndUnzipM, zipWithM, zipWithM_, foldM,
    liftM, liftM2, liftM3, liftM4, liftM5,
    Monad((>>=), (>>), return), fail,
    Functor(fmap),
    mapM, mapM_, sequence, sequence_, (=<<)
  ) where
import Control.Monad (MonadPlus(mzero, mplus), join, ap, liftM, liftM2, liftM3, liftM4, liftM5)
import qualified Control.Monad as M

guard :: MonadPlus m => Bool -> m ()
guard True = return ()
guard False = mzero
when, unless :: Monad m => Bool -> m () -> m ()
when = M.when
unless = M.unless
msum :: MonadPlus m => [m a] -> m a
msum = M.msum
filterM :: Monad m => (a -> m Bool) -> [a] -> m [a]
filterM = M.filterM
mapAndUnzipM :: Monad m => (a -> m (b, c)) -> [a] -> m ([b], [c])
mapAndUnzipM = M.mapAndUnzipM
zipWithM :: Monad m => (a -> b -> m c) -> [a] -> [b] -> m [c]
zipWithM = M.zipWithM
zipWithM_ :: Monad m => (a -> b -> m c) -> [a] -> [b] -> m ()
zipWithM_ = M.zipWithM_
foldM :: Monad m => (a -> b -> m a) -> a -> [b] -> m a
foldM = M.foldM
