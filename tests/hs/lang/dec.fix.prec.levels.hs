-- Report 4.4.2: of two operators at adjacent levels, the higher binds tighter: for all nine adjacencies.
module Main (main) where

infixl 0 `o0`
o0 :: String -> String -> String
o0 a b = "(" ++ a ++ "0" ++ b ++ ")"

infixl 1 `o1`
o1 :: String -> String -> String
o1 a b = "(" ++ a ++ "1" ++ b ++ ")"

infixl 2 `o2`
o2 :: String -> String -> String
o2 a b = "(" ++ a ++ "2" ++ b ++ ")"

infixl 3 `o3`
o3 :: String -> String -> String
o3 a b = "(" ++ a ++ "3" ++ b ++ ")"

infixl 4 `o4`
o4 :: String -> String -> String
o4 a b = "(" ++ a ++ "4" ++ b ++ ")"

infixl 5 `o5`
o5 :: String -> String -> String
o5 a b = "(" ++ a ++ "5" ++ b ++ ")"

infixl 6 `o6`
o6 :: String -> String -> String
o6 a b = "(" ++ a ++ "6" ++ b ++ ")"

infixl 7 `o7`
o7 :: String -> String -> String
o7 a b = "(" ++ a ++ "7" ++ b ++ ")"

infixl 8 `o8`
o8 :: String -> String -> String
o8 a b = "(" ++ a ++ "8" ++ b ++ ")"

infixl 9 `o9`
o9 :: String -> String -> String
o9 a b = "(" ++ a ++ "9" ++ b ++ ")"

main :: IO ()
main = mapM_ putStrLn [
    "a" `o0` "b" `o1` "c",
    "a" `o1` "b" `o2` "c",
    "a" `o2` "b" `o3` "c",
    "a" `o3` "b" `o4` "c",
    "a" `o4` "b" `o5` "c",
    "a" `o5` "b" `o6` "c",
    "a" `o6` "b" `o7` "c",
    "a" `o7` "b" `o8` "c",
    "a" `o8` "b" `o9` "c"]
