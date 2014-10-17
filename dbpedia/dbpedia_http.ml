 c
type title = string
type abstract = string
type rdf_type = string list
type wiki_page = string
type is_primary_topic_of = string
type label = string
type same_as = string list

type url = string
type name = string
type album = string

type basic = (title * abstract * rdf_type * wiki_page * is_primary_topic_of *
                label * same_as)
type song = (url * title * album)

exception Dbpedia of string

(*
** PRIVATE
*)

let get_value pairs key_to_find =
  let is_key_equal (key, value) = (key = key_to_find)
  in
  let find_key pairs =
    let exist = List.exists is_key_equal pairs in
    if exist then List.find is_key_equal pairs else (key_to_find, "")in
  let (key, value) = find_key pairs in
  value

let get_values pairs key_to_find =
  let is_key_equal (key, value) = (key = key_to_find) in
  let current_pairs = List.find_all is_key_equal pairs in
  let get_value (key, value) = value in
  List.map get_value current_pairs

let get_exc_string e = "DBpedia: " ^ (Printexc.to_string e)

(*
** PUBLIC
*)

let print_basic
    (title,abstract,rdf_type,wiki_page,is_primary_topic_of,label,same_as) =
  print_endline "--------";
  print_endline title;
  print_endline abstract;
  print_endline wiki_page;
  print_endline is_primary_topic_of

let print_discography
    (song, name, album) =
  print_endline "--------";
  print_endline song;
  print_endline name;
  print_endline album


let get_basic_informations name =
  try_lwt
    let basic_query = Dbpedia_query.get_basic_query_infos name in
    (* let basic_of_pair pairs = *)
    (*   let title = get_value pairs "title" in *)
    (*   let abstract = get_value pairs "abstract" in *)
    (*   (\* let rdf_type = get_value pairs "type" in *\) *)
    (*   let wiki_page = get_value pairs "wikiPage" in *)
    (*   let is_primary_topic_of = get_value pairs "isPrimaryTopicOf" in *)
    (*   let label = get_value pairs "label" in *)
    (*   (\* let same_as = get_value pairs "sameAs" in *\) *)
    (*   (title,abstract,[] (\* rdf_type *\),wiki_page,is_primary_topic_of, *)
    (*    label,[] (\*sameAs*\)) *)
    (* in *)
    lwt dbpedia_results = Rdf_http.query
        (Rdf_uri.uri "http://dbpedia.org/sparql")
        Dbpedia_query.(basic_query.query)
    in
    let format record =
      Dbpedia_record.Basic.(record.title, record.abstract, [],
                            record.wiki_page, record.is_primary_topic_of,
                            record.label, [])
    in
    let ret = Dbpedia_record.Basic.parse dbpedia_results in
    (* let pairs_list = (Rdf_http.pairs_of_solutions ~display:false *)
    (* dbpedia_results Dbpedia_query.(basic_query.keys)) in *)
    (* List.map basic_of_pair pairs_list *)
    Lwt.return (List.map format ret)
  with e -> raise (Dbpedia (get_exc_string e))

let get_discography name =
  try_lwt
    let discography_query = Dbpedia_query.get_discography_query_infos name in
    (* let discography_of_pair pairs = *)
    (*   let song = get_value pairs "song" in *)
    (*   let name = get_value pairs "song_name" in *)
    (*   let album = get_value pairs "album" in *)
    (*   (song, name, album) *)
    (* in *)
    lwt dbpedia_results = Rdf_http.query
        (Rdf_uri.uri "http://dbpedia.org/sparql")
        Dbpedia_query.(discography_query.query)
    in
    let format record =
      Dbpedia_record.Disco.(record.song, record.song_name, record.album)
    in
    let ret = Dbpedia_record.Disco.parse dbpedia_results in
    (* let pairs_list = (Rdf_http.pairs_of_solutions ~display:false *)
    (* dbpedia_results Dbpedia_query.(discography_query.keys)) in *)
    (* List.map discography_of_pair pairs_list *)
    Lwt.return (List.map format ret)
  with e -> raise (Dbpedia (get_exc_string e))
