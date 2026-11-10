-- Report 9.5: aexp -> [ exp | qual1 , ... , qualn ] (list comprehension, n >= 1): not [x | ].
module Main (main) where

main :: IO ()
main = print [1 | ]
