-- Module Data.Maybe, section 21.2 of the Haskell 2010 Report.
-- The code of the Report's sources, as the online Report of 2010-07-20
-- prints it, with rhc's overlay applied: a modified version of the Report's
-- code, which does not define Haskell 2010. LICENSE says what was changed;
-- overlay.tsv lists each change, corrections.tsv the corrections of the
-- Report's text that rhc reads it with, and pristine/ holds the code as
-- printed.

module Data.Maybe(
    Maybe(Nothing, Just),
    isJust, isNothing,
    fromJust, fromMaybe, listToMaybe, maybeToList,
    catMaybes, mapMaybe,
    maybe
  ) where

-- maybe is the Prelude's, which the export list names (overlay ov.maybe.maybe)

isJust                 :: Maybe a -> Bool
isJust (Just a)        =  True
isJust Nothing         =  False

isNothing              :: Maybe a -> Bool
isNothing              =  not . isJust

fromJust               :: Maybe a -> a
fromJust (Just a)      =  a
fromJust Nothing       =  error "Maybe.fromJust: Nothing"

fromMaybe              :: a -> Maybe a -> a
fromMaybe d Nothing    =  d
fromMaybe d (Just a)   =  a

maybeToList            :: Maybe a -> [a]
maybeToList Nothing    =  []
maybeToList (Just a)   =  [a]

listToMaybe            :: [a] -> Maybe a
listToMaybe []         =  Nothing
listToMaybe (a:_)      =  Just a
 
catMaybes              :: [Maybe a] -> [a]
catMaybes ms           =  [ m | Just m <- ms ]

mapMaybe               :: (a -> Maybe b) -> [a] -> [b]
mapMaybe f             =  catMaybes . map f
