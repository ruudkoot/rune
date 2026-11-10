-- rows: lib.list.export.elemindices lib.list.export.find lib.list.export.findindex lib.list.export.findindices lib.list.export.nub lib.list.export.nubby lib.list.export.delete lib.list.export.deleteby lib.list.export.bsbs lib.list.export.deletefirstsby lib.list.export.union lib.list.export.unionby lib.list.export.intersect lib.list.export.intersectby lib.list.export.intersperse lib.list.export.transpose lib.list.export.partition lib.list.export.group lib.list.export.groupby lib.list.export.inits lib.list.export.tails lib.list.export.isprefixof lib.list.export.issuffixof lib.list.export.mapaccuml lib.list.export.mapaccumr lib.list.export.sort lib.list.export.sortby lib.list.export.insert lib.list.export.insertby lib.list.export.maximumby lib.list.export.minimumby lib.list.export.genericlength lib.list.export.generictake lib.list.export.genericdrop lib.list.export.genericsplitat lib.list.export.genericindex lib.list.export.genericreplicate lib.list.export.zip4 lib.list.export.zip5 lib.list.export.zip6 lib.list.export.zip7 lib.list.export.zipwith4 lib.list.export.zipwith5 lib.list.export.zipwith6 lib.list.export.zipwith7 lib.list.export.unzip4 lib.list.export.unzip5 lib.list.export.unzip6 lib.list.export.unzip7 lib.list.export.unfoldr lib.list.export.map lib.list.export.plusplus lib.list.export.concat lib.list.export.filter lib.list.export.head lib.list.export.last lib.list.export.tail lib.list.export.init lib.list.export.null lib.list.export.length lib.list.export.bangbang lib.list.export.foldl lib.list.export.foldl1 lib.list.export.scanl lib.list.export.scanl1 lib.list.export.foldr lib.list.export.foldr1 lib.list.export.scanr lib.list.export.scanr1 lib.list.export.iterate lib.list.export.repeat lib.list.export.replicate lib.list.export.cycle lib.list.export.take lib.list.export.drop lib.list.export.splitat lib.list.export.takewhile lib.list.export.dropwhile lib.list.export.span lib.list.export.break lib.list.export.lines lib.list.export.words lib.list.export.unlines lib.list.export.unwords lib.list.export.reverse lib.list.export.and lib.list.export.or lib.list.export.any lib.list.export.all lib.list.export.elem lib.list.export.notelem lib.list.export.lookup lib.list.export.sum lib.list.export.product lib.list.export.maximum lib.list.export.minimum lib.list.export.concatmap lib.list.export.zip lib.list.export.zip3 lib.list.export.zipwith lib.list.export.zipwith3 lib.list.export.unzip lib.list.export.unzip3
-- Report 17.9: module List exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import List (elemIndex, elemIndices, find, findIndex, findIndices, nub, nubBy, delete, deleteBy, (\\), deleteFirstsBy, union, unionBy, intersect, intersectBy, intersperse, transpose, partition, group, groupBy, inits, tails, isPrefixOf, isSuffixOf, mapAccumL, mapAccumR, sort, sortBy, insert, insertBy, maximumBy, minimumBy, genericLength, genericTake, genericDrop, genericSplitAt, genericIndex, genericReplicate, zip4, zip5, zip6, zip7, zipWith4, zipWith5, zipWith6, zipWith7, unzip4, unzip5, unzip6, unzip7, unfoldr, map, (++), concat, filter, head, last, tail, init, null, length, (!!), foldl, foldl1, scanl, scanl1, foldr, foldr1, scanr, scanr1, iterate, repeat, replicate, cycle, take, drop, splitAt, takeWhile, dropWhile, span, break, lines, words, unlines, unwords, reverse, and, or, any, all, elem, notElem, lookup, sum, product, maximum, minimum, concatMap, zip, zip3, zipWith, zipWith3, unzip, unzip3)

v0 _ = elemIndex

v1 _ = elemIndices

v2 _ = find

v3 _ = findIndex

v4 _ = findIndices

v5 _ = nub

v6 _ = nubBy

v7 _ = delete

v8 _ = deleteBy

v9 _ = (\\)

v10 _ = deleteFirstsBy

v11 _ = union

v12 _ = unionBy

v13 _ = intersect

v14 _ = intersectBy

v15 _ = intersperse

v16 _ = transpose

v17 _ = partition

v18 _ = group

v19 _ = groupBy

v20 _ = inits

v21 _ = tails

v22 _ = isPrefixOf

v23 _ = isSuffixOf

v24 _ = mapAccumL

v25 _ = mapAccumR

v26 _ = sort

v27 _ = sortBy

v28 _ = insert

v29 _ = insertBy

v30 _ = maximumBy

v31 _ = minimumBy

v32 _ = genericLength

v33 _ = genericTake

v34 _ = genericDrop

v35 _ = genericSplitAt

v36 _ = genericIndex

v37 _ = genericReplicate

v38 _ = zip4

v39 _ = zip5

v40 _ = zip6

v41 _ = zip7

v42 _ = zipWith4

v43 _ = zipWith5

v44 _ = zipWith6

v45 _ = zipWith7

v46 _ = unzip4

v47 _ = unzip5

v48 _ = unzip6

v49 _ = unzip7

v50 _ = unfoldr

v51 _ = map

v52 _ = (++)

v53 _ = concat

v54 _ = filter

v55 _ = head

v56 _ = last

v57 _ = tail

v58 _ = init

v59 _ = null

v60 _ = length

v61 _ = (!!)

v62 _ = foldl

v63 _ = foldl1

v64 _ = scanl

v65 _ = scanl1

v66 _ = foldr

v67 _ = foldr1

v68 _ = scanr

v69 _ = scanr1

v70 _ = iterate

v71 _ = repeat

v72 _ = replicate

v73 _ = cycle

v74 _ = take

v75 _ = drop

v76 _ = splitAt

v77 _ = takeWhile

v78 _ = dropWhile

v79 _ = span

v80 _ = break

v81 _ = lines

v82 _ = words

v83 _ = unlines

v84 _ = unwords

v85 _ = reverse

v86 _ = and

v87 _ = or

v88 _ = any

v89 _ = all

v90 _ = elem

v91 _ = notElem

v92 _ = lookup

v93 _ = sum

v94 _ = product

v95 _ = maximum

v96 _ = minimum

v97 _ = concatMap

v98 _ = zip

v99 _ = zip3

v100 _ = zipWith

v101 _ = zipWith3

v102 _ = unzip

v103 _ = unzip3

main :: IO ()
main = return ()
