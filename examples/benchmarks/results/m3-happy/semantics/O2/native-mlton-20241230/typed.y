%tokentype {T}
%token x {X}
%%
start :: {A} : x {one}; | {zero}
next :: {B} ignored : start {two}