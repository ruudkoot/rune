-- Module PreludeEnum: rhc's, not the Report's (overlay ov.prelude.numericenum).
-- Ratio's Enum instance names four functions "as defined in Prelude.hs but
-- not exported from it!", as Ratio's comment says, so that by chapter 5
-- they are not in scope there. Their 14 lines move here, as the Report
-- prints them, and the Prelude and Ratio import them (results/E16's
-- overlay.py). A program cannot import this module.

module PreludeEnum (
    numericEnumFrom, numericEnumFromThen, numericEnumFromTo,
    numericEnumFromThenTo
  ) where

numericEnumFrom         :: (Fractional a) => a -> [a]

numericEnumFromThen     :: (Fractional a) => a -> a -> [a]

numericEnumFromTo       :: (Fractional a, Ord a) => a -> a -> [a]

numericEnumFromThenTo   :: (Fractional a, Ord a) => a -> a -> a -> [a]
numericEnumFrom         =  iterate (+1)
numericEnumFromThen n m =  iterate (+(m-n)) n
numericEnumFromTo n m   =  takeWhile (<= m+1/2) (numericEnumFrom n)
numericEnumFromThenTo n n' m = takeWhile p (numericEnumFromThen n n')
                             where
                               p | n' >= n   = (<= m + (n'-n)/2)
                                 | otherwise = (>= m + (n'-n)/2)
