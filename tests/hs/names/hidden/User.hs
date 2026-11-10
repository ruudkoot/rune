module User where
import PreludeList (map)
import qualified PreludeBuiltin
import Char (toUpper)
main = putStrLn (map toUpper "hello")
