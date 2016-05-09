open Lwt.Infix

module IO =
  struct
    type 'a t = 'a Lwt.t
    let (>>=) = Lwt.bind
    let return = Lwt.return

    type ic = Lwt_io.input_channel
    type oc = Lwt_io.output_channel
    type conn = ic * oc

    let read_line ic = Lwt_io.read_line_opt ic
    let read ic count = Lwt_io.read ~count ic
    let write oc buf = Lwt_io.write oc buf
    let flush oc = Lwt_io.flush oc
  end

module Tls_net =
  struct
    module IO = IO
    type ctx = Tls.Config.client [@@deriving sexp_of]
    let default_ctx =
      let authenticator = X509.Authenticator.chain_of_trust [] in
      Tls.Config.(client ~authenticator ())

    let connect_uri ~ctx uri =
      let host = match Uri.host uri with None -> "" | Some s -> s in
      let port = match Uri.port uri with None -> 443 | Some n -> n in
      Tls_lwt.connect_ext
        (*~trace:eprint_sexp*)
        ctx (host, port)
        >>= fun (ic, oc) -> Lwt.return ((ic, oc), ic, oc)

    let close c = Lwt.catch (fun () -> Lwt_io.close c) (fun _ -> Lwt.return_unit)
    let close_in ic = Lwt.ignore_result (close ic)
    let close_out oc = Lwt.ignore_result (close oc)
    let close ic oc = Lwt.ignore_result (close ic >>= fun () -> close oc)
end

module Client = Cohttp_lwt.Make_client (IO) (Tls_net)

module type P =
  sig
    val dbg : string -> unit Lwt.t
    val authenticator : X509.Authenticator.a
    val certificates : Tls.Config.own_cert
  end

module Make (P:P) : Ldp_http.Requests =
  struct
    let dbg = P.dbg
    let call ?body ?chunked ?headers meth iri =
      let ctx =
        Tls.Config.client
          ~authenticator: P.authenticator ~certificates: P.certificates
          ()
      in
      Client.call ~ctx ?body ?chunked ?headers meth
        (Uri.of_string (Iri.to_uri iri))
  end