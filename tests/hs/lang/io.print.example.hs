-- Report 7.1: the Report's example main = print ([(n, 2^n) | n <- [0..19]]), n's type defaulted to Integer.
module Main (main) where

main = print ([(n, 2^n) | n <- [0..19]])
