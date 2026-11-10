-- rows: pre.data.bool pre.data.char pre.data.maybe pre.data.either pre.data.io pre.data.ordering pre.data.int pre.data.integer pre.data.float pre.data.double pre.data.lista pre.data.acb pre.data.acbcc pre.type.string pre.text.type.reads pre.text.type.shows pre.text.class.read pre.text.class.show pre.io.type.filepath pre.io.data.ioerror
-- Report 8: the Prelude's types as the Report declares them: their constructors in patterns and expressions, their
-- derived classes, and their kinds (Maybe, IO, [] and Either Int of kind * -> *); String, ReadS, ShowS, FilePath,
-- IOError and the classes Read and Show.
module Main (main) where

data K f a = K (f a)

k :: (K Maybe Int, K IO (), K [] Char, K (Either Int) Bool)
k = (K (Just 1), K (return ()), K "a", K (Right True))

units :: [()]
units = [minBound .. maxBound] ++ [read "()", ()]

bools :: (Bool, Bool, Ordering, [Ordering])
bools = (False < True, read "True", compare LT GT, [minBound .. maxBound])

maybes :: Maybe Int -> Either Char Int -> Int
maybes Nothing (Left _) = 0
maybes (Just n) (Right m) = n + m
maybes _ _ = 1

nums :: (Int, Integer, Float, Double, Char)
nums = (minBound, 2 ^ (70 :: Int), 1.5, 2.5, maxBound)

lists :: ([Int], (Int, Bool), (Int, Bool, Char))
lists = ([] ++ (1 : [2]), (,) 1 True, (,,) 1 False 'c')

text :: (String, ReadS Int, ShowS)
text = (['a'], reads, showString "x")

cls :: (Read a, Show a) => a -> String -> (String, a)
cls x s = (show x, read s)

io :: (FilePath, IOError)
io = ("f", userError "x")

main :: IO ()
main = return ()
