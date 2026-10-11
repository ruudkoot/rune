(* The exnMessage of fix.diff, copied into a standalone program (inside the
   Basis, OS is OSImp), against the specification's requirement that
   exnMessage ex contain exnName ex. Run: sml fix-check.sml *)
structure ExnName = struct
    val exnName = General.exnName
    fun exnMessage (OS.SysErr(s, NONE)) =
	  "SysErr: " ^ s
      | exnMessage (OS.SysErr(s, SOME e)) =
	  concat["SysErr: ", s, " [", OS.errorName e, "]"]
      | exnMessage (IO.Io{cause, function, name}) = let
	  val causeMsg = (case cause
		 of (OS.SysErr(s, _)) => [", ", s]
		  | IO.BlockingNotSupported => [", blocking I/O not supported"]
		  | IO.NonblockingNotSupported =>
		      [", non-blocking I/O not supported"]
		  | IO.RandomAccessNotSupported => [", random access not supported"]
		  | IO.TerminatedStream => [", terminated input stream"]
		  | IO.ClosedStream => [", closed stream"]
		  | _ => [" with exception ", exnMessage cause]
		(* end case *))
	  in
	    concat("Io: " :: function :: " failed on \"" :: name :: "\"" :: causeMsg)
	  end
      | exnMessage (Fail s) = "Fail: " ^ s
(** NOTE: we should probably include line/file info for Match and Bind *)
    (* the Basis requires the message to contain `exnName ex` *)
      | exnMessage Bind = "Bind: nonexhaustive binding failure"
      | exnMessage Match = "Match: nonexhaustive match failure"
      | exnMessage Subscript = "Subscript: subscript out of bounds"
      | exnMessage Div = "Div: divide by zero"
      | exnMessage Domain = "Domain: domain error"
      | exnMessage e = exnName e
end
exception Mine of int
val all = [Bind, Match, Div, Domain, Overflow, Size, Subscript, Chr, Empty, Option, Span,
           Fail "why", OS.SysErr ("No such file", NONE), Mine 3, Time.Time, Date.Date,
           IO.Io {name = "f", function = "inputAll", cause = Div},
           IO.Io {name = "f", function = "openIn", cause = OS.SysErr ("No such file", NONE)}]
val bad = List.filter (fn ex => not (String.isSubstring (exnName ex) (ExnName.exnMessage ex))) all
val () = List.app (fn ex => print (ExnName.exnMessage ex ^ "\n")) all
val () = print (Int.toString (length bad) ^ " of " ^ Int.toString (length all) ^ " messages lack exnName ex\n")
val () = OS.Process.exit OS.Process.success
