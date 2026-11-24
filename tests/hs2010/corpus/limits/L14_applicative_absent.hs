-- Report: no Applicative, <$> or pure in the Prelude; a program may define its own pure.
module Main where
pure :: a -> [a]
pure x = [x]
(<>) :: [a] -> [a] -> [a]
(<>) = (++)
main = print (pure 'a' <> pure 'b')
