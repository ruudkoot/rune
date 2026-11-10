-- rows: lib.monad.export.join lib.monad.export.guard lib.monad.export.when lib.monad.export.unless lib.monad.export.ap lib.monad.export.msum lib.monad.export.filterm lib.monad.export.mapandunzipm lib.monad.export.zipwithm lib.monad.export.zipwithmu lib.monad.export.foldm lib.monad.export.liftm lib.monad.export.liftm2 lib.monad.export.liftm3 lib.monad.export.liftm4 lib.monad.export.liftm5 lib.monad.export.monadgtgteqcgtgtcreturncfail lib.monad.export.functorfmap lib.monad.export.mapm lib.monad.export.mapmu lib.monad.export.sequence lib.monad.export.sequenceu lib.monad.export.eqltlt
-- Report 20.4: module Monad exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Monad (MonadPlus(mzero, mplus), join, guard, when, unless, ap, msum, filterM, mapAndUnzipM, zipWithM, zipWithM_, foldM, liftM, liftM2, liftM3, liftM4, liftM5, Monad((>>=), (>>), return, fail), Functor(fmap), mapM, mapM_, sequence, sequence_, (=<<))

c0 :: (MonadPlus f) => f a -> ()
c0 _ = ()
s0_0 _ = mzero
s0_1 _ = mplus

v1 _ = join

v2 _ = guard

v3 _ = when

v4 _ = unless

v5 _ = ap

v6 _ = msum

v7 _ = filterM

v8 _ = mapAndUnzipM

v9 _ = zipWithM

v10 _ = zipWithM_

v11 _ = foldM

v12 _ = liftM

v13 _ = liftM2

v14 _ = liftM3

v15 _ = liftM4

v16 _ = liftM5

c17 :: (Monad f) => f a -> ()
c17 _ = ()
s17_0 _ = (>>=)
s17_1 _ = (>>)
s17_2 _ = return
s17_3 _ = fail

c18 :: (Functor f) => f a -> ()
c18 _ = ()
s18_0 _ = fmap

v19 _ = mapM

v20 _ = mapM_

v21 _ = sequence

v22 _ = sequence_

v23 _ = (=<<)

main :: IO ()
main = return ()
