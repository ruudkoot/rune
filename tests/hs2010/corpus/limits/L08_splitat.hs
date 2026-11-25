-- Report: splitAt n xs = (take n xs, drop n xs), so splitAt undefined [] is a pair.  base: strict in n.
module Main where
main = case splitAt undefined "" of (_, _) -> putStrLn "pair"
