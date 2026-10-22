(* The pinned Language Server Protocol method and property inventory.

   Area: Protocols *)
signature LSP_METHODS =
sig
  (* Which peer sends a protocol message. *)
  datatype direction = ClientToServer | ServerToClient | Both

  (* A request expects a response; a notification does not. *)
  datatype kind = Request | Notification

  (* A method's name, direction, kind and capability/version metadata. *)
  type method = {name : string, direction : direction, kind : kind,
                 clientCapability : string option, serverCapability : string option,
                 since : string option, proposed : bool}

  (* A declared wire property, including properties of anonymous objects.
     Its owner names the declaring type or nested type path. *)
  type property = {owner : string, name : string, optional : bool,
                   since : string option, proposed : bool}

  (* An enumeration member and its literal value, written as JSON. *)
  type enumValue = {owner : string, name : string, value : string,
                    since : string option, proposed : bool}

  (* The metamodel's protocol version.

     Example: `version = "3.18.0"` *)
  val version : string

  (* The SHA-256 of the unmodified upstream metamodel. *)
  val sourceHash : string

  (* All methods, sorted by their names. *)
  val all : method list

  (* `find name` is the declared method of that name, when it exists.

     Example: `isSome (find "initialize") andalso not (isSome (find "rune/unknown"))` *)
  val find : string -> method option

  (* All declared wire properties, including nested anonymous objects. *)
  val properties : property list

  (* All declared enumeration members. *)
  val enumValues : enumValue list
end
