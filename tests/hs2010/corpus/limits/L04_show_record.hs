-- Report (11.4): showsPrec for a record constructor uses precedence 11 for its whole record; derived Show of
-- Just (R {f = 1}) is "Just (R {f = 1})" in GHC; GHC's bugs.rst says the Report calls for "Just R {f = 1}".
module Main where
data R = R { f :: Int } deriving Show
main = print (Just (R { f = 1 }))
