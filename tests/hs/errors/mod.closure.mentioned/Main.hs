-- Report 5.5.3: every name mentioned is defined locally or imported.
module Main (main) where



main :: IO ()
main = print unbound
