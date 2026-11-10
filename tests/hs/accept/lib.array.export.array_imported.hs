-- rows: lib.array.export.array.2 lib.array.export.listarray lib.array.export.bang lib.array.export.bounds lib.array.export.indices lib.array.export.elems lib.array.export.assocs lib.array.export.accumarray lib.array.export.slashslash lib.array.export.accum lib.array.export.ixmap
-- Report 16.4: module Array exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Array (Array, array, listArray, (!), bounds, indices, elems, assocs, accumArray, (//), accum, ixmap)

t0 :: Array Int Int -> ()
t0 _ = ()

v1 _ = array

v2 _ = listArray

v3 _ = (!)

v4 _ = bounds

v5 _ = indices

v6 _ = elems

v7 _ = assocs

v8 _ = accumArray

v9 _ = (//)

v10 _ = accum

v11 _ = ixmap

main :: IO ()
main = return ()
