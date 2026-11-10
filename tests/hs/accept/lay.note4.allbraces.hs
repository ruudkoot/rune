-- rows: lay.note4.pattern lay.note4.nosemi
-- Report 9.3, Note 4: "all brace pairs are treated as explicit layout contexts, including labelled construction and update
-- (Section 3.15)": a record's lines may stand left of the do block, and its lines get no ;.
module Main (main) where

data R = R { a :: Int,
  b :: Int } deriving Show

f :: R -> Int
f (R { a = x,
b = y }) = x + y

main :: IO ()
main = do
    print (R { a = 1,
  b = 2 })
    print (f ((R { a = 1, b = 2 }) { a = 3
}))
