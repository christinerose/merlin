(* Name of the extension *)
type description = {
  name : string;
  version : string;
}

(* Services provided by extension *)
type capabilities = {
  reader: bool;
}

(* Reader protocol *)
module Reader = struct

  open Reader_def

  type request =
    | Load of buffer
    | Parse
    | Parse_line of Lexing.position * string
    | Parse_for_completion of Lexing.position
    | Get_ident_at of Lexing.position
    | Print of tree list

  type response =
    | Ret_loaded
    | Ret_tree of tree
    | Ret_tree_for_competion of complete_info * tree
    | Ret_ident of string Location.loc list
    | Ret_printed of string list

end

(* Main protocol *)
type request =
  | Start_communication
  | Reader_request of Reader.request

type response =
  | Notify of string
  | Debug of string
  | Exception of string * string
  | Reader_response of Reader.response