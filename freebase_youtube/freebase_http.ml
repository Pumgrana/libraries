(*
** Binding http of freebase with ocaml
*)

type id = string
type name = string
type sliced_description = string
type social_media_presences = string list
type types = (string * string) list
type wiki_url = string list

exception Freebase of string

type freebase_object =
  (
    id
    * name
    * sliced_description
    * social_media_presences
    * types
    * wiki_url
  )


(*
** PRIVATE
*)

(*** freebase url ***)
let api_base_url = "https://www.googleapis.com/freebase/v1/"
let api_search_url = api_base_url ^ "search?query="
let api_topic_url = api_base_url ^ "topic"

let get_exc_string e = "Freebase: " ^ (Printexc.to_string e)

(*** url creators ***)
let create_search_url request = api_search_url ^ request
let create_topic_url ids filter limit lang =
  api_topic_url ^ ids
  ^ "?filter=" ^ (Bfy_helpers.strings_of_list filter "&filter=")
  ^ "&limit=" ^ (string_of_int limit)
  ^ "&lang=" ^ lang

(*** json accessor ***)
let get_result_field json =
  Yojson_wrap.(to_list (member "result" json))

let get_mid_field json =
  Yojson_wrap.(to_string (member "mid" json))

let get_property_field json =
  Yojson_wrap.member "property" json

let get_ctdescription_field json =
  Yojson_wrap.member "/common/topic/description" json

let get_values_field json =
  Yojson_wrap.(to_list (member "values" json))

let get_value_field json =
  Yojson_wrap.(to_string (member "value" json))

let get_id_field json =
  Yojson_wrap.(to_string (member "id" json))

let get_error_field json =
  Yojson_wrap.member "error" json

let get_text_field json =
  Yojson_wrap.(to_string (member "text" json))

let get_ctsocial_media_presence_field json =
  Yojson_wrap.member "/common/topic/social_media_presence" json

let get_toname_field json =
  Yojson_wrap.member "/type/object/name" json

let get_totype_field json =
  Yojson_wrap.member "/type/object/type" json

let get_cttopic_equivalent_webpage_field json =
  Yojson_wrap.member "/common/topic/topic_equivalent_webpage" json

let hd d l =
  if List.length l = 0
  then d
  else List.hd l

(*** Unclassed ***)
let freebase_object_of_json json =
  let id = get_id_field json in
  let property = get_property_field json in
  let sliced_description =
    let ct_descr = hd (`Assoc [])
      (get_values_field (get_ctdescription_field property))
    in
    get_text_field ct_descr in
  let social_media_presences =
    List.map
      get_value_field
      (get_values_field (get_ctsocial_media_presence_field property)) in
  let name =
    get_value_field (hd (`String "") (get_values_field (get_toname_field property))) in
  let types =
    let create_type json = (get_id_field json, get_text_field json) in
    List.map create_type (get_values_field (get_totype_field property)) in
  let rec wiki_url =
    let rec get_wiki_url =
      let uri_reg =
        Str.regexp "\\(https?://\\)?\\(www\\.\\)?en\\.wikipedia.org/wiki/.+" in
      let is_en_wiki_url url = Str.string_match uri_reg url 0 in
      function
      | (url::t)  ->
        if ((is_en_wiki_url url) = true)
        then [url]
        else get_wiki_url t
      | _       -> []
    in
    let url_list =
      List.map
        get_value_field
        (get_values_field (get_cttopic_equivalent_webpage_field property))
    in
    let toto = get_wiki_url url_list in
    toto
  in
  (id, name, sliced_description, social_media_presences, types, wiki_url)

let is_an_error_object freebase_object =
  let error = get_error_field freebase_object
  in
  match error with
    | `Null       -> false
    | _           -> true


(*
** PUBLIC
*)

(*** printing ***)
(** Print a basic freebase object on stdout *)
let print_freebase_object
    (id, name, sliced_description, sm_presences, types, wiki_url) =
  let rec string_of_sm = function
    | (h::t)    -> "\n  -" ^ h ^ (string_of_sm t)
    | _         -> "" in
  let rec string_of_type = function
    | (id, text)::t     ->
      "\n  -id:\"" ^ id ^ "\"\n  -text:\"" ^ text ^ "\"\n" ^ (string_of_type t)
    | _                 -> ""
  in
  print_endline ("\n<== Freebase object ==>\n"
    ^"->id:\"" ^ id ^ "\"\n"
    ^ "->name:\"" ^ name ^ "\"\n"
    ^ "->sliced_description:\"" ^ sliced_description ^ "\"\n"
    ^ "->sm_presences:" ^ (string_of_sm sm_presences) ^ "\n"
    ^ "->types:" ^ (string_of_type types) ^ "\n"
    ^ "->wiki_url:\"" ^ (hd "" wiki_url) ^ "\"\n")


(*** requests ***)
(* for now it is private, this function isn't finished *)
let search query =
  try_lwt
    let url = create_search_url query in
    lwt freebase_json = Http_request_manager.request url in
    Lwt.return (freebase_json)
  with e -> raise (Freebase (get_exc_string e))


(* TODO: ids must become a list *)
(**
** return a list of freebase basic object from a list of topic_ids
*)
let get_topics ids =
  try_lwt
    let url =
      create_topic_url
        ids
        [
          "/common/topic/description";
          "/common/topic/topic_equivalent_webpage";
          "/type/object/name";
          "/type/object/type";
          "/common/topic/description";
          "/common/topic/social_media_presence"
        ]
        1000
        "en"
    in
    lwt freebase_json = Http_request_manager.request ~display_body:true url
    in
    if is_an_error_object freebase_json
    then (Lwt.return None)
    else (Lwt.return (Some (freebase_object_of_json freebase_json)))
  with e -> raise (Freebase (get_exc_string e))
