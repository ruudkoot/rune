structure Main =
struct
  fun main (_ : string, args : string list) : OS.Process.status =
    (List.app (fn f =>
       let val file = Source.load f
           val prog = Parser.parseFile file
           val () = Elaborate.allowPrim := true
           val env = Elaborate.elabProgram prog
       in StringMap.appi (fn (n, Env.Val {scheme, ...}) => print ("val " ^ n ^ " : " ^ Types.toString scheme ^ "\n")
                           | (n, Env.Con {scheme, ...}) => print ("con " ^ n ^ " : " ^ Types.toString scheme ^ "\n")
                           | (n, Env.Exn {ty, ...}) => print ("exn " ^ n ^ " : " ^ Types.toString ty ^ "\n")
                           | _ => ()) (Env.vals env)
       end
       handle Error.CompileError (sp, msg) => print (Error.format (sp, msg) ^ "\n")) args;
     OS.Process.success)
end
