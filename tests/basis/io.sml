(* requires: IO *)
(* The IO structure (signature IO): the exceptions of the I/O subsystem and
   the buffering modes. Expected values follow the text of
   https://smlfamily.github.io/Basis/io.html. How TextIO and BinIO use Io is
   checked in textio.sml and binio.sml; io_sig.sml matches IO against the
   signature. *)
structure TestIO =
struct
  val eqS = T.eq T.string
  val eqB = T.eq T.bool

  (* ---- Io: "The components of Io are: name, function, cause" ---- *)
  val () = eqS ("IO.Io/carries-name-function-cause", "n,f,c",
                fn () => (raise IO.Io {name = "n", function = "f", cause = Fail "c"})
                         handle IO.Io {name, function, cause = Fail c} => name ^ "," ^ function ^ "," ^ c)
  val () = eqS ("IO.Io/fields-in-any-order", "f:n",
                fn () => (raise IO.Io {cause = Subscript, function = "f", name = "n"})
                         handle IO.Io {cause = Subscript, name, function} => function ^ ":" ^ name)
  val () = eqB ("IO.Io/cause-is-any-exn", true,
                fn () => (raise IO.Io {name = "", function = "", cause = Div})
                         handle IO.Io {cause = Div, ...} => true | IO.Io _ => false)
  val () = eqS ("IO.Io/cause-may-be-Io", "inner",
                fn () => (raise IO.Io {name = "outer", function = "g",
                                       cause = IO.Io {name = "inner", function = "f", cause = Subscript}})
                         handle IO.Io {cause = IO.Io {name, ...}, ...} => name)
  val () = eqS ("IO.Io/empty-strings", "",
                fn () => (raise IO.Io {name = "", function = "", cause = Subscript})
                         handle IO.Io {name, function, ...} => name ^ function)
  val () = T.raises ("IO.Io/is-raised", fn IO.Io _ => true | _ => false,
                     fn () => raise IO.Io {name = "n", function = "f", cause = Subscript})
  val () = eqB ("IO.Io/is-not-its-cause", false,
                fn () => (raise IO.Io {name = "n", function = "f", cause = Subscript})
                         handle Subscript => true | _ => false)
  val () = eqB ("IO.Io/value-of-type-exn", true,
                fn () => let val e : exn = IO.Io {name = "n", function = "f", cause = Subscript}
                         in case e of IO.Io {name = "n", function = "f", cause = Subscript} => true | _ => false end)

  (* ---- ClosedStream: "only be used in the cause field of an Io exception" ---- *)
  val () = eqB ("IO.ClosedStream/raise-handle", true,
                fn () => (raise IO.ClosedStream) handle IO.ClosedStream => true)
  val () = eqB ("IO.ClosedStream/as-cause", true,
                fn () => (raise IO.Io {name = "n", function = "output", cause = IO.ClosedStream})
                         handle IO.Io {cause = IO.ClosedStream, function = "output", ...} => true | _ => false)
  val () = eqB ("IO.ClosedStream/is-not-Io", false,
                fn () => (raise IO.ClosedStream) handle IO.Io _ => true | _ => false)
  val () = eqB ("IO.ClosedStream/is-not-a-General-exception", false,
                fn () => (raise IO.ClosedStream)
                         handle Subscript => true | Size => true | Fail _ => true | Option => true
                              | Empty => true | Domain => true | IO.ClosedStream => false)

  (*<< BlockingNotSupported *)
  val () = eqB ("IO.BlockingNotSupported/raise-handle", true,
                fn () => (raise IO.BlockingNotSupported) handle IO.BlockingNotSupported => true)
  val () = eqB ("IO.BlockingNotSupported/as-cause", true,
                fn () => (raise IO.Io {name = "n", function = "input", cause = IO.BlockingNotSupported})
                         handle IO.Io {cause = IO.BlockingNotSupported, ...} => true | _ => false)
  val () = eqB ("IO.BlockingNotSupported/is-not-ClosedStream", false,
                fn () => (raise IO.BlockingNotSupported) handle IO.ClosedStream => true | _ => false)
  (*>> BlockingNotSupported *)

  (*<< NonblockingNotSupported *)
  val () = eqB ("IO.NonblockingNotSupported/raise-handle", true,
                fn () => (raise IO.NonblockingNotSupported) handle IO.NonblockingNotSupported => true)
  val () = eqB ("IO.NonblockingNotSupported/as-cause", true,
                fn () => (raise IO.Io {name = "n", function = "canInput", cause = IO.NonblockingNotSupported})
                         handle IO.Io {cause = IO.NonblockingNotSupported, ...} => true | _ => false)
  val () = eqB ("IO.NonblockingNotSupported/is-not-ClosedStream", false,
                fn () => (raise IO.NonblockingNotSupported) handle IO.ClosedStream => true | _ => false)
  (*>> NonblockingNotSupported *)

  (*<< RandomAccessNotSupported *)
  val () = eqB ("IO.RandomAccessNotSupported/raise-handle", true,
                fn () => (raise IO.RandomAccessNotSupported) handle IO.RandomAccessNotSupported => true)
  val () = eqB ("IO.RandomAccessNotSupported/as-cause", true,
                fn () => (raise IO.Io {name = "n", function = "setPosOut", cause = IO.RandomAccessNotSupported})
                         handle IO.Io {cause = IO.RandomAccessNotSupported, ...} => true | _ => false)
  val () = eqB ("IO.RandomAccessNotSupported/is-not-ClosedStream", false,
                fn () => (raise IO.RandomAccessNotSupported) handle IO.ClosedStream => true | _ => false)
  (*>> RandomAccessNotSupported *)

  (*<< distinct *)
  (* The four exceptions without an argument are four different exceptions:
     each one is recognised as itself, in whatever order the handlers are. *)
  fun which (e : exn) : string =
    (raise e) handle IO.RandomAccessNotSupported => "RandomAccessNotSupported"
                   | IO.NonblockingNotSupported => "NonblockingNotSupported"
                   | IO.ClosedStream => "ClosedStream"
                   | IO.BlockingNotSupported => "BlockingNotSupported"
                   | IO.Io _ => "Io"
                   | _ => "other"
  val () = eqS ("IO.BlockingNotSupported/distinct", "BlockingNotSupported", fn () => which IO.BlockingNotSupported)
  val () = eqS ("IO.NonblockingNotSupported/distinct", "NonblockingNotSupported",
                fn () => which IO.NonblockingNotSupported)
  val () = eqS ("IO.RandomAccessNotSupported/distinct", "RandomAccessNotSupported",
                fn () => which IO.RandomAccessNotSupported)
  val () = eqS ("IO.ClosedStream/distinct", "ClosedStream", fn () => which IO.ClosedStream)
  val () = eqS ("IO.Io/distinct", "Io", fn () => which (IO.Io {name = "", function = "", cause = IO.ClosedStream}))
  (*>> distinct *)

  (*<< buffer_mode *)
  (* "datatype buffer_mode = NO_BUF | LINE_BUF | BLOCK_BUF": three different
     constructors of a type that admits equality. *)
  fun modeName IO.NO_BUF = "NO_BUF"
    | modeName IO.LINE_BUF = "LINE_BUF"
    | modeName IO.BLOCK_BUF = "BLOCK_BUF"
  val () = eqS ("IO.NO_BUF/match", "NO_BUF", fn () => modeName IO.NO_BUF)
  val () = eqS ("IO.LINE_BUF/match", "LINE_BUF", fn () => modeName IO.LINE_BUF)
  val () = eqS ("IO.BLOCK_BUF/match", "BLOCK_BUF", fn () => modeName IO.BLOCK_BUF)
  val () = eqB ("IO.NO_BUF/equal-to-itself", true, fn () => IO.NO_BUF = IO.NO_BUF)
  val () = eqB ("IO.LINE_BUF/equal-to-itself", true, fn () => IO.LINE_BUF = IO.LINE_BUF)
  val () = eqB ("IO.BLOCK_BUF/equal-to-itself", true, fn () => IO.BLOCK_BUF = IO.BLOCK_BUF)
  val () = eqB ("IO.NO_BUF/differs-from-LINE_BUF", false, fn () => IO.NO_BUF = IO.LINE_BUF)
  val () = eqB ("IO.LINE_BUF/differs-from-BLOCK_BUF", false, fn () => IO.LINE_BUF = IO.BLOCK_BUF)
  val () = eqB ("IO.BLOCK_BUF/differs-from-NO_BUF", false, fn () => IO.BLOCK_BUF = IO.NO_BUF)
  val () = eqS ("IO.buffer_mode/type", "LINE_BUF,NO_BUF",
                fn () => String.concatWith "," (List.map modeName ([IO.LINE_BUF, IO.NO_BUF] : IO.buffer_mode list)))
  (*>> buffer_mode *)

  (*<< exnName *)
  (* General.exnName: "returns a name for the exception ex". *)
  val () = eqS ("IO.Io/exnName", "Io",
                fn () => General.exnName (IO.Io {name = "n", function = "f", cause = Subscript}))
  val () = eqS ("IO.ClosedStream/exnName", "ClosedStream", fn () => General.exnName IO.ClosedStream)
  (*>> exnName *)

  (*<< exnName-not-supported *)
  val () = eqS ("IO.BlockingNotSupported/exnName", "BlockingNotSupported",
                fn () => General.exnName IO.BlockingNotSupported)
  val () = eqS ("IO.NonblockingNotSupported/exnName", "NonblockingNotSupported",
                fn () => General.exnName IO.NonblockingNotSupported)
  val () = eqS ("IO.RandomAccessNotSupported/exnName", "RandomAccessNotSupported",
                fn () => General.exnName IO.RandomAccessNotSupported)
  (*>> exnName-not-supported *)
end
