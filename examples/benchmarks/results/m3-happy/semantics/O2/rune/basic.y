%tokentype { T }
%token x { X }
%%
start : x { $1 }
