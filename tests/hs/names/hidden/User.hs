module User where
import PreludeList (map)
import qualified PreludeBuiltin
import qualified PreludeRuntime
import PreludeEnum ()
import Char (toUpper)
main = putStrLn (map toUpper "hello")
