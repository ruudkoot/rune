(* signature OS_IO, transcribed from
   https://smlfamily.github.io/Basis/os-io.html

   Time.time is the type of the top-level structure Time. The signature of
   the substructure Kind is written on one line: scripts/check-basis-coverage.sh
   takes every line that starts with `val` for a member of OS_IO itself, and
   the checks of its members are labelled OS.IO.Kind.file/..., not
   OS.IO.file/... (tests/basis/os.io.sml has one for each of the seven). *)
signature SPEC_OS_IO =
sig
  eqtype iodesc
  val hash : iodesc -> word
  val compare : iodesc * iodesc -> order
  eqtype iodesc_kind
  val kind : iodesc -> iodesc_kind
  structure Kind : sig val file : iodesc_kind  val dir : iodesc_kind  val symlink : iodesc_kind  val tty : iodesc_kind  val pipe : iodesc_kind  val socket : iodesc_kind  val device : iodesc_kind end
  eqtype poll_desc
  type poll_info
  val pollDesc : iodesc -> poll_desc option
  val pollToIODesc : poll_desc -> iodesc
  exception Poll
  val pollIn : poll_desc -> poll_desc
  val pollOut : poll_desc -> poll_desc
  val pollPri : poll_desc -> poll_desc
  val poll : poll_desc list * Time.time option -> poll_info list
  val isIn : poll_info -> bool
  val isOut : poll_info -> bool
  val isPri : poll_info -> bool
  val infoToPollDesc : poll_info -> poll_desc
end
