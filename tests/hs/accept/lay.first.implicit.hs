-- rows: lay.first.indented
-- Report 9.3: "If the first lexeme of a module is not { or module, then it is preceded by {n} where n is the indentation
-- of the lexeme": a module of declarations alone, Main by chapter 5, all at column 5.
    main :: IO ()
    main = print x
    x :: Int
    x = 1
