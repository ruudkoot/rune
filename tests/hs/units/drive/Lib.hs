-- A module of hs/units/drive (rhc --units FILE.hs --store): Main takes two of its
-- values; the job edits a copy of it.
module Lib (double, greeting) where

double :: Int -> Int
double x = x + x

greeting :: String
greeting = "hello"
