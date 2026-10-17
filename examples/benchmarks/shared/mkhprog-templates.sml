(* Crown Copyright 1992. Original auxiliary Haskell templates by N. D. North. *)
structure BenchMkhprogTemplates =
struct
  val strings = [
    "main :: IO ()\nmain  =  getArgs >>= (parse_args defaultArgs . unlines)",
    "readbool :: (String -> IO ()) -> String -> IO ()\nreadbool f \"\"         =  f \"\"\nreadbool f ('\\n':cs)  =  f cs\nreadbool f _          =  usage",
    "readstring :: (String -> String -> IO ()) -> String -> IO ()\nreadstring f \"\"  =  f \"\" \"\"\nreadstring f cs@(c:cs')\n    =  f s t\n       where\n       st      =  if c == '\\n' then cs' else cs\n       (s,t1)  =  span ((/=) '\\n') st\n       t       =  if t1 == \"\" then t1 else (tail t1)",
    "readval :: (Read a) => ReadS a -> (a -> String -> IO ()) -> String\n                       -> IO ()\nreadval readsfn f str\n    =  case thing of\n           []    -> usage\n           (_:_) -> f val (if str' == \"\" then str' else (tail str'))\n       where\n       thing        =  readsfn str\n       (val, str')  =  head thing"]
end
