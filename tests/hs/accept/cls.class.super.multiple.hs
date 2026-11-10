-- rows: cls.class.nowhere
-- Report 4.3.1: a class may have several superclasses, or an empty context, and needs no where part.
module Main (main) where

class (Eq a, Show a) => C a
class () => D a
class (Read a, Show a) => Textual a

main :: IO ()
main = return ()
