-- rows: lib.maybe.export.isnothing lib.maybe.export.fromjust lib.maybe.export.frommaybe lib.maybe.export.listtomaybe lib.maybe.export.maybetolist lib.maybe.export.catmaybes lib.maybe.export.mapmaybe lib.maybe.export.maybenothingcjust lib.maybe.export.maybe
-- Report 18.1: module Maybe exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Maybe (isJust, isNothing, fromJust, fromMaybe, listToMaybe, maybeToList, catMaybes, mapMaybe, Maybe(Nothing, Just), maybe)

v0 _ = isJust

v1 _ = isNothing

v2 _ = fromJust

v3 _ = fromMaybe

v4 _ = listToMaybe

v5 _ = maybeToList

v6 _ = catMaybes

v7 _ = mapMaybe

t8 :: Maybe Int -> ()
t8 _ = ()
s8_0 _ = Nothing
s8_1 _ = Just

v9 _ = maybe

main :: IO ()
main = return ()
