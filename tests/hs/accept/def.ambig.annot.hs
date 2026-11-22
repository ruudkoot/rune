-- rows: def.ambig.astypeof def.decl.usernum def.decl.rational
-- Report 4.3.4: a signature resolves an ambiguity, as asTypeOf does; default may name a user's Num type, and types
-- that are not constructors alone.
module Main (main) where

import Ratio

newtype T = T Integer deriving (Eq, Show)
instance Num T where
  T a + T b = T (a + b)
  T a * T b = T (a * b)
  abs = id
  signum = id
  negate (T a) = T (negate a)
  fromInteger = T

default (T, Ratio Integer)

approxSqrt :: RealFloat a => a -> a
approxSqrt x = encodeFloat 1 (exponent x `div` 2) `asTypeOf` x

main :: IO ()
main = print (let x = read "True" in show (x :: Bool), approxSqrt (16 :: Double), 1 + 2)
