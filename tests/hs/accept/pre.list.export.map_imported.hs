-- rows: pre.list.export.plusplus pre.list.export.filter pre.list.export.concat pre.list.export.concatmap pre.list.export.head pre.list.export.last pre.list.export.tail pre.list.export.init pre.list.export.null pre.list.export.length pre.list.export.bangbang pre.list.export.foldl pre.list.export.foldl1 pre.list.export.scanl pre.list.export.scanl1 pre.list.export.foldr pre.list.export.foldr1 pre.list.export.scanr pre.list.export.scanr1 pre.list.export.iterate pre.list.export.repeat pre.list.export.replicate pre.list.export.cycle pre.list.export.take pre.list.export.drop pre.list.export.splitat pre.list.export.takewhile pre.list.export.dropwhile pre.list.export.span pre.list.export.break pre.list.export.lines pre.list.export.words pre.list.export.unlines pre.list.export.unwords pre.list.export.reverse pre.list.export.and pre.list.export.or pre.list.export.any pre.list.export.all pre.list.export.elem pre.list.export.notelem pre.list.export.lookup pre.list.export.sum pre.list.export.product pre.list.export.maximum pre.list.export.minimum pre.list.export.zip pre.list.export.zip3 pre.list.export.zipwith pre.list.export.zipwith3 pre.list.export.unzip pre.list.export.unzip3
-- Report 8: module Prelude exports each of these (PreludeList): an explicit import of every one compiles, and each name
-- is used.
module Main (main) where

import Prelude (map, (++), filter, concat, concatMap, head, last, tail, init, null, length, (!!), foldl, foldl1, scanl, scanl1, foldr, foldr1, scanr, scanr1, iterate, repeat, replicate, cycle, take, drop, splitAt, takeWhile, dropWhile, span, break, lines, words, unlines, unwords, reverse, and, or, any, all, elem, notElem, lookup, sum, product, maximum, minimum, zip, zip3, zipWith, zipWith3, unzip, unzip3, IO, Int, return)

v0 _ = map

v1 _ = (++)

v2 _ = filter

v3 _ = concat

v4 _ = concatMap

v5 _ = head

v6 _ = last

v7 _ = tail

v8 _ = init

v9 _ = null

v10 _ = length

v11 _ = (!!)

v12 _ = foldl

v13 _ = foldl1

v14 _ = scanl

v15 _ = scanl1

v16 _ = foldr

v17 _ = foldr1

v18 _ = scanr

v19 _ = scanr1

v20 _ = iterate

v21 _ = repeat

v22 _ = replicate

v23 _ = cycle

v24 _ = take

v25 _ = drop

v26 _ = splitAt

v27 _ = takeWhile

v28 _ = dropWhile

v29 _ = span

v30 _ = break

v31 _ = lines

v32 _ = words

v33 _ = unlines

v34 _ = unwords

v35 _ = reverse

v36 _ = and

v37 _ = or

v38 _ = any

v39 _ = all

v40 _ = elem

v41 _ = notElem

v42 _ = lookup

v43 _ = sum

v44 _ = product

v45 _ = maximum

v46 _ = minimum

v47 _ = zip

v48 _ = zip3

v49 _ = zipWith

v50 _ = zipWith3

v51 _ = unzip

v52 _ = unzip3

main :: IO ()
main = return ()
