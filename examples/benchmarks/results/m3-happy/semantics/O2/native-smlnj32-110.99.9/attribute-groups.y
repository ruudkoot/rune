%tokentype {T}
%token x {X}
%attribute a {Int}
%attribute b {Int}
%%
start : child child { $1.a = 1; $1.b = 2; $1.a = 3; $2.a = 4; $$.a = $1.a; where ok $2 }
child : x { $$ = $1 }