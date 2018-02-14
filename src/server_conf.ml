(*********************************************************************************)
(*                OCaml-Solid                                                    *)
(*                                                                               *)
(*    Copyright (C) 2016-2017 Institut National de Recherche en Informatique     *)
(*    et en Automatique. All rights reserved.                                    *)
(*                                                                               *)
(*    This program is free software; you can redistribute it and/or modify       *)
(*    it under the terms of the GNU Lesser General Public License version        *)
(*    3 as published by the Free Software Foundation.                            *)
(*                                                                               *)
(*    This program is distributed in the hope that it will be useful,            *)
(*    but WITHOUT ANY WARRANTY; without even the implied warranty of             *)
(*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *)
(*    GNU General Public License for more details.                               *)
(*                                                                               *)
(*    You should have received a copy of the GNU General Public License          *)
(*    along with this program; if not, write to the Free Software                *)
(*    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA                   *)
(*    02111-1307  USA                                                            *)
(*                                                                               *)
(*    Contact: Maxence.Guesdon@inria.fr                                          *)
(*                                                                               *)
(*********************************************************************************)

(** Server configuration options. *)

let server_cert = Ocf.string ~doc:".pem file of server certificate"
  "./server-certificates/server.pem"

let server_key = Ocf.string ~doc:".key file of server key"
  ("./server-certificates/server.key")

let server_ca = Ocf.(option_ ~doc:"CA file of server"
   Wrapper.string None)

let port = Ocf.int ~doc: "port number to listen to" 9999

let filename_wrapper =
  let to_json ?with_doc fn = `String fn in
  let from_json ?def = function
    `String str ->
      begin
        if Filename.is_relative str then
          Filename.concat (Sys.getcwd()) str
        else
          str
      end
  | json -> Ocf.invalid_value json
  in
  Ocf.Wrapper.make to_json from_json

let storage_root = Ocf.option filename_wrapper
  ~doc:"root directory to store served documents"
  "www"

let json_wrapper =
  let to_json ?with_doc x = x in
  let from_json ?def x = x in
  Ocf.Wrapper.make to_json from_json

let default_fs_type = "unix"
type fs_map_rule = {
    host : string option [@ocf Ocf.Wrapper.(option string), None] ;
    path : string option [@ocf Ocf.Wrapper.(option string), None] ;
    root : string [@ocf Ocf.Wrapper.string, ""] ;
    options : Yojson.Safe.json [@ocf json_wrapper, `Assoc []] ;
    fs_type : string [@ocf Ocf.Wrapper.string, default_fs_type] ;
  } [@@ocf]

let storage_rules = Ocf.list fs_map_rule_wrapper
  ~doc:"mappings from uri to file system"
  []

let () = Logs.set_level ~all: true (Some Logs.Warning)
let global_log_level = Ocf.option
  ~cb: (fun l -> Logs.set_level ~all: true l)
(*     prerr_endline (Printf.sprintf "level set to %s" (Logs.level_to_string l)))*)
  Ldp_log.level_wrapper (Logs.level ())

let container_listing = Ocf.(option_
   ~doc: "GET text/html on container lists content or use an existing file; \
   null means the server will return 415, else each file will be tried and if \
   none exists the server will build a simple HTML page."
  (Wrapper.list Wrapper.string) (Some ["index.html";"index.xhtml"])
  )

let add_options g =
  let https =
    let g = Ocf.group in
    let g = Ocf.add g ["cert_file"] server_cert in
    let g = Ocf.add g ["key_file"] server_key in
    let g = Ocf.add g ["ca_file"] server_ca in
    let g = Ocf.add g ["port"] port in
    g
  in
  let storage =
    let g = Ocf.group in
    let g = Ocf.add g ["root"] storage_root in
    let g = Ocf.add g ["rules"] storage_rules in
    g
  in
  let ldp =
    let g = Ocf.group in
    let g = Ocf.add g ["container_listing"] container_listing in
    g
  in
  let log =
    let g = Ocf.group in
    let g = Ocf.add g ["global"] global_log_level in
    let g = Ocf.add g ["library"] Ldp_log.log_level in
    let g = Ocf.add g ["server"] Server_log.log_level in
    g
  in
  let g = Ocf.add_group g ["https"] https in
  let g = Ocf.add_group g ["storage"] storage in
  let g = Ocf.add_group g ["ldp"] ldp in
  let g = Ocf.add_group g ["log"] log in
  g
