open Std
open Option.Infix

let id_of_patt = let open Typedtree in function
  | { pat_desc = Tpat_var (id, _) ; _ } -> Some id
  | _ -> None

let mk ?(children=[]) ~pos outline_kind id =
  { Protocol. outline_name = Ident.name id; outline_kind; pos; children }

open BrowseT

(* FIXME: pasted from track_definition, share it. *)
let path_to_list p =
  let rec aux acc = function
    | Path.Pident id -> id.Ident.name :: acc
    | Path.Pdot (p, str, _) -> aux (str :: acc) p
    | _ -> assert false
  in
  aux [] p

let rec summarize node =
  let pos = node.t_loc.Location.loc_start in
  match node.t_node with
  | Value_binding vb      -> id_of_patt vb.Typedtree.vb_pat >>| mk `Value ~pos
  | Value_description vd  -> Some (mk `Value ~pos vd.Typedtree.val_id)

  | Module_declaration md ->
    let children = get_mod_children node in
    Some (mk ~children ~pos `Module md.Typedtree.md_id)
  | Module_binding mb     ->
    let children = get_mod_children node in
    Some (mk ~children ~pos `Module mb.Typedtree.mb_id)

  | Module_type_declaration mtd ->
    let children = get_mod_children node in
    Some (mk ~children ~pos `Modtype mtd.Typedtree.mtd_id)

  | Type_declaration td ->
    let open Typedtree in
    let children = 
      let helper kind id loc = mk kind id ~pos:loc.Location.loc_start in
      List.concat_map (Lazy.force node.t_children) ~f:(fun child ->
        match child.t_node with
        | Type_kind _ ->
          List.map (Lazy.force child.t_children) ~f:(fun x ->
            match x.t_node with
            | Constructor_declaration c -> helper `Constructor c.cd_id c.cd_loc
            | Label_declaration ld      -> helper `Label ld.ld_id ld.ld_loc
            | _ -> assert false (* ! *)
          )
        | _ -> []
      )
    in
    Some (mk ~children ~pos `Type td.typ_id)

  | Type_extension te ->
    let name = String.concat ~sep:"." (path_to_list te.Typedtree.tyext_path) in
    let children =
      List.filter_map (Lazy.force node.t_children) ~f:(fun x ->
        summarize x >>| fun x -> { x with Protocol.outline_kind = `Constructor }
      )
    in
    Some { Protocol. outline_name = name; outline_kind = `Type; pos; children }

  | Extension_constructor ec ->
    Some (mk ~pos `Exn ec.Typedtree.ext_id )

  (* TODO: classes *)
  | _ -> None

and get_mod_children node =
  List.concat_map (Lazy.force node.t_children) ~f:(fun child ->
    match child.t_node with
    | Module_expr _
    | Module_type _ ->
      List.concat_map (Lazy.force child.t_children) ~f:remove_top_indir
    | _ -> []
  )

and remove_top_indir t =
  match t.t_node with
  | Structure _
  | Signature _ -> List.concat_map ~f:remove_top_indir (Lazy.force t.t_children)
  | Signature_item _
  | Structure_item _ -> List.filter_map (Lazy.force t.t_children) ~f:summarize
  | _ -> []

let get = List.concat_map ~f:remove_top_indir
