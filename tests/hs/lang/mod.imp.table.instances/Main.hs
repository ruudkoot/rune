-- Report 5.3.4: each of the table's thirteen import forms of A brings A's instances into scope.
module Main (main) where

import M0
import M1
import M2
import M3
import M4
import M5
import M6
import M7
import M8
import M9
import M10
import M11
import M12

main :: IO ()
main = print [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12]
