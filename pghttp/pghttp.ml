(**
   Pghttp
   Implementing the redirection over cohttp
*)

(******************************************************************************
********************************* Functions ***********************************
*******************************************************************************)

let extract_url response =
  let header = Cohttp_lwt_unix.Response.headers response in
  match Cohttp.Header.get header "Location" with
  | Some location  -> Lwt.return (Some (Uri.of_string location))
  | None           -> Lwt.return None

let extract_rediction request =
  lwt response, body = request in
  let status = Cohttp_lwt_unix.Response.status response in
  let code = Cohttp.Code.code_of_status status in
  if code == 301 then extract_url response else Lwt.return None

let rec request_manager requester max_move url =
  let request = requester url in
  lwt redirection = extract_rediction request in
  match redirection with
  | Some dest when max_move > 0 -> request_manager requester (max_move - 1) dest
  | _ -> request  (* None or max_move <= 0 *)

(******************************************************************************
********************************** Binding ************************************
*******************************************************************************)

let get ?headers =
  request_manager (Cohttp_lwt_unix.Client.get ?headers) 1

let post ?body ?chunked ?headers =
  request_manager (Cohttp_lwt_unix.Client.post ?body ?chunked ?headers) 1

(******************************************************************************
*********************************** Test **************************************
*******************************************************************************)

(* let main url = *)
(*   lwt header, body = get url in *)
(*   lwt body_string = Cohttp_lwt_body.to_string body in *)
(*   print_endline body_string; *)
(*   Lwt.return () *)

(* lwt () = main (Uri.of_string "http://google.fr") *)
