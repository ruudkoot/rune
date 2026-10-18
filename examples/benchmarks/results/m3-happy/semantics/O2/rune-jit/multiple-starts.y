%tokentype {T}
%token x {X}
%name p a
%partial q b
%%
a : x {$1}
b : a {$1}