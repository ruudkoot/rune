%tokentype {T}
%token x {X}
%monad {Ctx}{M}{bind}{ret}
%lexer {lex}{eof}
%error {bad}
%expect 0
%%
a : x {$1}