{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- Data.List (T10 chapter 20): the Prelude's list functions are the shim Prelude's (the same entities); the rest are
-- base's at list types; the generic functions are the Report's code (98's List, with 2010's Num for genericLength).
module Data.List (
    (++), head, last, tail, init, null, length, map, reverse,
    intersperse, intercalate, transpose, subsequences, permutations,
    foldl, foldl', foldl1, foldl1', foldr, foldr1, concat, concatMap,
    and, or, any, all, sum, product, maximum, minimum, scanl, scanl1,
    scanr, scanr1, mapAccumL, mapAccumR, iterate, repeat, replicate,
    cycle, unfoldr, take, drop, splitAt, takeWhile, dropWhile, span,
    break, stripPrefix, group, inits, tails, isPrefixOf, isSuffixOf,
    isInfixOf, elem, notElem, lookup, find, filter, partition, (!!),
    elemIndex, elemIndices, findIndex, findIndices, zip, zip3, zip4,
    zip5, zip6, zip7, zipWith, zipWith3, zipWith4, zipWith5, zipWith6,
    zipWith7, unzip, unzip3, unzip4, unzip5, unzip6, unzip7, lines,
    words, unlines, unwords, nub, delete, (\\), union, intersect, sort,
    insert, nubBy, deleteBy, deleteFirstsBy, unionBy, intersectBy,
    groupBy, sortBy, insertBy, maximumBy, minimumBy, genericLength,
    genericTake, genericDrop, genericSplitAt, genericIndex, genericReplicate
  ) where

import "this" Prelude
import "base" Data.List (intersperse, intercalate, transpose, subsequences, permutations, unfoldr, stripPrefix,
    group, inits, tails, isPrefixOf, isSuffixOf, isInfixOf, partition, elemIndex, elemIndices, findIndex,
    findIndices, zip4, zip5, zip6, zip7, zipWith4, zipWith5, zipWith6, zipWith7, unzip4, unzip5, unzip6, unzip7,
    nub, delete, (\\), union, intersect, sort, insert, nubBy, deleteBy, deleteFirstsBy, unionBy, intersectBy,
    groupBy, sortBy, insertBy)
import qualified "base" Data.List as L



foldl' :: (a -> b -> a) -> a -> [b] -> a
foldl' = L.foldl'
foldl1' :: (a -> a -> a) -> [a] -> a
foldl1' = L.foldl1'
mapAccumL, mapAccumR :: (acc -> x -> (acc, y)) -> acc -> [x] -> (acc, [y])
mapAccumL = L.mapAccumL
mapAccumR = L.mapAccumR
find :: (a -> Bool) -> [a] -> Maybe a
find = L.find
maximumBy, minimumBy :: (a -> a -> Ordering) -> [a] -> a
maximumBy = L.maximumBy
minimumBy = L.minimumBy

genericLength           :: (Num i) => [b] -> i
genericLength []        =  0
genericLength (x:xs)    =  1 + genericLength xs

genericTake             :: (Integral i) => i -> [a] -> [a]
genericTake n _ | n <= 0 = []
genericTake _ []        =  []
genericTake n (x:xs)    =  x : genericTake (n-1) xs

genericDrop             :: (Integral i) => i -> [a] -> [a]
genericDrop n xs | n <= 0 = xs
genericDrop _ []        =  []
genericDrop n (_:xs)    =  genericDrop (n-1) xs

genericSplitAt          :: (Integral i) => i -> [b] -> ([b],[b])
genericSplitAt n xs | n <= 0 =  ([],xs)
genericSplitAt _ []     =  ([],[])
genericSplitAt n (x:xs) =  (x:xs',xs'') where
    (xs',xs'') = genericSplitAt (n-1) xs

genericIndex            :: (Integral a) => [b] -> a -> b
genericIndex (x:_)  0   =  x
genericIndex (_:xs) n
        | n > 0         =  genericIndex xs (n-1)
        | otherwise     =  error "List.genericIndex: negative argument"
genericIndex _ _        =  error "List.genericIndex: index too large"

genericReplicate        :: (Integral i) => i -> a -> [a]
genericReplicate n x    =  genericTake n (repeat x)
