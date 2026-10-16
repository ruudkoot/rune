module Main where
import Pretty
cases=[("nil",80,ppNil),("empty-string",80,ppStr ""),
       ("beside",80,ppBeside(ppStr "a")(ppStr "b")),
       ("cat",80,ppCat[ppStr "a",ppStr "b"]),
       ("above-nil",80,ppAbove(ppStr "a")ppNil),
       ("above-empty-string",80,ppAbove(ppStr "a")(ppStr "")),
       ("nest-horizontal",80,ppNest 8(ppAbove(ppStr "a")(ppStr "b"))),
       ("nest-vertical",80,ppAbove ppNil(ppNest 8(ppAbove(ppStr "a")(ppStr "b")))),
       ("embedded-newline",80,ppAbove ppNil(ppNest 8(ppStr "a\nb"))),
       ("sep-fit",7,ppSep[ppStr "aaa",ppStr "bbb"]),
       ("sep-wrap",6,ppSep[ppStr "aaa",ppStr "bbb"])]
main=mapM_(\(name,width,doc)->print(name,ppShow width doc))cases
