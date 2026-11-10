-- Report 2.2: newline -> ... | formfeed: a formfeed is a newline, so a line comment ends at it and layout
-- reads the character after it as column 1, which starts a declaration of its own.
module Main (main) where

main :: IO ()
main = print (x + y) -- a comment ends at the formfeedx :: Int
x = 1
y :: Int
y = 2
