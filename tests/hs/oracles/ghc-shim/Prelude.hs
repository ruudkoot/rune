{-# LANGUAGE PackageImports, NoImplicitPrelude #-}
-- The Haskell 98 Prelude's export list over GHC's: only the names the Report exports, the list functions at
-- their list types, catch restored.  What cannot be shimmed: Num's superclasses (Eq, Show), Monad's superclass
-- (Applicative) and Monad's fail (MonadFail).
module Prelude (
    map, (++), filter, concat, concatMap,
    head, last, tail, init, null, length, (!!),
    foldl, foldl1, scanl, scanl1, foldr, foldr1, scanr, scanr1,
    iterate, repeat, replicate, cycle,
    take, drop, splitAt, takeWhile, dropWhile, span, break,
    lines, words, unlines, unwords, reverse, and, or,
    any, all, elem, notElem, lookup,
    sum, product, maximum, minimum,
    zip, zip3, zipWith, zipWith3, unzip, unzip3,
    ReadS, ShowS,
    Read(readsPrec, readList),
    Show(showsPrec, show, showList),
    reads, shows, read, lex,
    showChar, showString, readParen, showParen,
    FilePath, IOError, ioError, userError, catch,
    putChar, putStr, putStrLn, print,
    getChar, getLine, getContents, interact,
    readFile, writeFile, appendFile, readIO, readLn,
    Bool(False, True),
    Maybe(Nothing, Just),
    Either(Left, Right),
    Ordering(LT, EQ, GT),
    Char, String, Int, Integer, Float, Double, Rational, IO,
    Eq((==), (/=)),
    Ord(compare, (<), (<=), (>=), (>), max, min),
    Enum(succ, pred, toEnum, fromEnum, enumFrom, enumFromThen,
         enumFromTo, enumFromThenTo),
    Bounded(minBound, maxBound),
    Num((+), (-), (*), negate, abs, signum, fromInteger),
    Real(toRational),
    Integral(quot, rem, div, mod, quotRem, divMod, toInteger),
    Fractional((/), recip, fromRational),
    Floating(pi, exp, log, sqrt, (**), logBase, sin, cos, tan,
             asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh),
    RealFrac(properFraction, truncate, round, ceiling, floor),
    RealFloat(floatRadix, floatDigits, floatRange, decodeFloat,
              encodeFloat, exponent, significand, scaleFloat, isNaN,
              isInfinite, isDenormalized, isIEEE, isNegativeZero, atan2),
    Monad((>>=), (>>), return), fail,
    Functor(fmap),
    mapM, mapM_, sequence, sequence_, (=<<),
    maybe, either,
    (&&), (||), not, otherwise,
    subtract, even, odd, gcd, lcm, (^), (^^),
    fromIntegral, realToFrac,
    fst, snd, curry, uncurry, id, const, (.), flip, ($), until,
    asTypeOf, error, undefined,
    seq, ($!)
  ) where

import "base" Prelude hiding (
    concat, concatMap, null, length, foldl, foldl1, foldr, foldr1, and, or, any, all,
    elem, notElem, sum, product, maximum, minimum, mapM, mapM_, sequence, sequence_)
import qualified "base" Prelude as P
import "base" System.IO.Error (catchIOError)

infix 4 `elem`, `notElem`

catch :: IO a -> (IOError -> IO a) -> IO a
catch = catchIOError

concat :: [[a]] -> [a]
concat = P.concat
concatMap :: (a -> [b]) -> [a] -> [b]
concatMap = P.concatMap
null :: [a] -> Bool
null = P.null
length :: [a] -> Int
length = P.length
foldl :: (a -> b -> a) -> a -> [b] -> a
foldl = P.foldl
foldl1 :: (a -> a -> a) -> [a] -> a
foldl1 = P.foldl1
foldr :: (a -> b -> b) -> b -> [a] -> b
foldr = P.foldr
foldr1 :: (a -> a -> a) -> [a] -> a
foldr1 = P.foldr1
and, or :: [Bool] -> Bool
and = P.and
or = P.or
any, all :: (a -> Bool) -> [a] -> Bool
any = P.any
all = P.all
elem, notElem :: Eq a => a -> [a] -> Bool
elem = P.elem
notElem = P.notElem
sum, product :: Num a => [a] -> a
sum = P.sum
product = P.product
maximum, minimum :: Ord a => [a] -> a
maximum = P.maximum
minimum = P.minimum
mapM :: Monad m => (a -> m b) -> [a] -> m [b]
mapM = P.mapM
mapM_ :: Monad m => (a -> m b) -> [a] -> m ()
mapM_ = P.mapM_
sequence :: Monad m => [m a] -> m [a]
sequence = P.sequence
sequence_ :: Monad m => [m a] -> m ()
sequence_ = P.sequence_
