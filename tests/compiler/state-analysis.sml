structure CompilerIntegrationStateTests =
struct
  fun need (ok, message) = if ok then () else raise Fail message
  val text = "signature S = sig type t val x : t end\n"
    ^ "functor F () = struct datatype t = C val x = C end\n"
    ^ "structure A :> S = F ()\nstructure B :> S = F ()\n"
    ^ "exception E of int\nexception E2 = E\nval id = fn x => x\n"
  fun compile () =
    let
      val () = UnitBasis.startSession ()
      val () = Pass.whole := false
      val () = CompilerSettings.target := "registers"
      val file = Source.fromString ("state-probe.sml",text)
      val () = Source.register file
      val (ds,fx) = Parser.parseTokensWith (Lexer.tokenize file,Fixity.initial)
      val env = ref Env.initial
      val start = UnitBasis.begin (!env,Fixity.initial)
      val () = Elaborate.elabTop (env,ds)
      val () = Elaborate.finish ()
      val delta = !Elaborate.lastDelta
      val r = Pipeline.unitThrough {start=start,name="state-probe.sml",file="state-probe.sml",text=fn () => text,
        mode=Source.Ascii,decs=ds,delta=delta,fixity=fx,used=[],fresh=false}
    in String.concat (UnitFile.chunks (Pipeline.fingerprint (),#code r)) end
  fun main () =
    let
      val a = CompilerState.session ()
      val b = CompilerState.session ()
      val first = CompilerState.withSession (a,compile)
      val () = CompilerState.withSession (a,fn () =>
        (Types.tyconCounter := 7000; Elaborate.stampCounter := 9000;
         Source.overlays := StringMap.insert (!Source.overlays,"private.sml","val private = 1");
         IntTable.insert (Vector.sub (UnitBasis.paths,0),123,"private")))
      val second = CompilerState.withSession (b,compile)
      val () = need (first=second,"separate sessions emitted different bytes")
      val () = CompilerState.withSession (b,fn () =>
        need (StringMap.find (!Source.overlays,"private.sml") = NONE andalso
              IntTable.find (Vector.sub (UnitBasis.paths,0),123) = NONE,"B sees A roots"))
      val () = CompilerState.withSession (a,fn () =>
        need (!Types.tyconCounter=7000 andalso !Elaborate.stampCounter=9000 andalso
          IntTable.find (Vector.sub (UnitBasis.paths,0),123) = SOME "private","A roots lost"))
    in print ("PASS compiler-state integration: " ^ Int.toString (length (CompilerState.names ())) ^ " roots, byte agreement and ownership\n") end
end
val () = CompilerIntegrationStateTests.main ()
