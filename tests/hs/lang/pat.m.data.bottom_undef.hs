-- rows: tr.case.r pat.ref.others
-- Report 3.17.2: a data constructor's pattern against bottom diverges; 3.17.3 (r).
module Main (main) where

main :: IO ()
main = print (case undefined :: Maybe Int of { Just _ -> 1; _ -> 2 :: Int })
