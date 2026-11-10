-- rows: lib.maybe.isnothing lib.maybe.fromjust lib.maybe.frommaybe lib.maybe.maybetolist lib.maybe.listtomaybe lib.maybe.catmaybes lib.maybe.mapmaybe
-- Report 18.1: the functions of Maybe against the Report's own module copied under new names, on samples, and on infinite
-- lists as far as both are defined.
module Main (main) where

import Maybe

isJust_r                 :: Maybe a -> Bool
isJust_r (Just a)        =  True
isJust_r Nothing         =  False

isNothing_r               :: Maybe a -> Bool
isNothing_r               =  not . isJust_r

fromJust_r               :: Maybe a -> a
fromJust_r (Just a)      =  a
fromJust_r Nothing       =  error "Maybe.fromJust_r: Nothing"

fromMaybe_r              :: a -> Maybe a -> a
fromMaybe_r d Nothing    =  d
fromMaybe_r d (Just a)   =  a

maybeToList_r            :: Maybe a -> [a]
maybeToList_r Nothing    =  []
maybeToList_r (Just a)   =  [a]

listToMaybe_r            :: [a] -> Maybe a
listToMaybe_r []         =  Nothing
listToMaybe_r (a:_)      =  Just a

catMaybes_r              :: [Maybe a] -> [a]
catMaybes_r ms           =  [ m | Just m <- ms ]

mapMaybe_r               :: (a -> Maybe b) -> [a] -> [b]
mapMaybe_r f             =  catMaybes_r . map f

ms :: [Maybe Int]
ms = [Nothing, Just 0, Just 1, Just (-7)]

xss :: [[Int]]
xss = [[], [1], [2, 3], [0, -1, 5]]

fs :: [Int -> Maybe Int]
fs = [const Nothing, Just, \x -> if even x then Just (x * 10) else Nothing]

main :: IO ()
main = do
  print (and [isJust m == isJust_r m && isNothing m == isNothing_r m | m <- ms], and [fromJust m == fromJust_r m | m <- ms, isJust_r m])
  print (and [fromMaybe d m == fromMaybe_r d m && maybeToList m == maybeToList_r m | d <- [9, -1], m <- ms])
  print (and [listToMaybe xs == listToMaybe_r xs | xs <- xss], listToMaybe [1 :: Int ..] == listToMaybe_r [1 ..])
  print (and [catMaybes l == catMaybes_r l | l <- [[], ms, reverse ms, [Nothing, Nothing]]], take 3 (catMaybes (cycle ms)) == take 3 (catMaybes_r (cycle ms)))
  print (and [mapMaybe f xs == mapMaybe_r f xs | f <- fs, xs <- xss], take 3 (mapMaybe (fs !! 2) [1 ..]) == take 3 (mapMaybe_r (fs !! 2) [1 ..]))
