-- rows: lib.char.lexlitchar R154
-- Report 19: lexLitChar returns the characters that encode the character, those readLitChar reads (readings.md R154: the
-- prose over the code's "very crude approximation" of a named escape): a mnemonic before an upper-case letter or
-- a digit is the table's; an upper-case letter that begins none, and \o or \x with no digit, encode nothing.
module Main (main) where

import Char

main :: IO ()
main = mapM_ (print . lexLitChar) ["\\NUL1", "\\SOHH", "\\SOH", "\\SO1", "\\SOx", "\\ESC1", "\\DEL1", "\\SPA", "\\Q", "\\Qrest", "\\o8", "\\o", "\\x", "\\xG", "\\x41G", "\\^a", "\\NULLA"]
