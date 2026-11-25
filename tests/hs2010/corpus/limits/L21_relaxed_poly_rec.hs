-- Report 2010 (4.5.1): dependency analysis ignores references to variables with signatures (bugs.rst's example).
module Main where
f :: Eq a => a -> Bool
f x = (x == x) || g True || g "Yes"
g y = (y <= y) || f True
main = print (f 'a')
