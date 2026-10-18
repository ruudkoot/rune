%tokentype {T}
%token x {X} plus {P} times {M}
%left plus
%left times
%name parse expr
%%
expr : expr plus expr {$1+$3} | expr times expr {$1*$3} | x {$1}