#!/usr/bin/env python3

from __future__ import annotations

import argparse
import http.client
import os
import select
import shutil
import socket
from http import HTTPStatus
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}

PRECOMPRESSIBLE_EXTENSIONS = {
    ".css",
    ".html",
    ".js",
    ".json",
    ".pck",
    ".svg",
    ".wasm",
}


class StaticWrapperHandler(SimpleHTTPRequestHandler):
    auth_base_url: str = ""
    rooms_base_url: str = ""
    game_server_url: str = ""

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:
        if self.headers.get("Upgrade", "").lower() == "websocket":
            self._proxy_websocket()
            return
        if self.path.startswith("/auth/") or self.path.startswith("/v0/rooms"):
            self._proxy_request()
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path.startswith("/auth/") or self.path.startswith("/v0/rooms"):
            self._proxy_request()
            return
        self.send_error(501, "Unsupported method")

    def do_OPTIONS(self) -> None:
        if self.path.startswith("/auth/") or self.path.startswith("/v0/rooms"):
            self._proxy_request()
            return
        self.send_error(501, "Unsupported method")

    def copyfile(self, source, outputfile) -> None:
        try:
            shutil.copyfileobj(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            # The browser or tunnel closed the downstream connection while a
            # large static asset was still streaming. Treat this as a normal
            # client disconnect instead of printing a full server traceback.
            pass

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            if not self.path.endswith("/"):
                self.send_response(HTTPStatus.MOVED_PERMANENTLY)
                self.send_header("Location", self.path + "/")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return None

            for index_name in self.index_pages:
                index_path = os.path.join(path, index_name)
                if os.path.isfile(index_path):
                    path = index_path
                    break
            else:
                return self.list_directory(path)

        if path.endswith("/"):
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        selected_path, content_encoding = self._select_static_variant(path)
        try:
            file_handle = open(selected_path, "rb")
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        try:
            file_stat = os.fstat(file_handle.fileno())
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-type", self.guess_type(path))
            self.send_header("Content-Length", str(file_stat.st_size))
            self.send_header("Last-Modified", self.date_time_string(file_stat.st_mtime))
            if content_encoding is not None:
                self.send_header("Content-Encoding", content_encoding)
                self.send_header("Vary", "Accept-Encoding")
            self.end_headers()
            return file_handle
        except Exception:
            file_handle.close()
            raise

    def _select_static_variant(self, path: str) -> tuple[str, str | None]:
        original_path = Path(path)
        if original_path.suffix not in PRECOMPRESSIBLE_EXTENSIONS:
            return path, None

        accepted_encodings = self.headers.get("Accept-Encoding", "").lower()
        preferred_variants = (
            (".br", "br"),
            (".gz", "gzip"),
        )
        for extension, encoding in preferred_variants:
            if encoding not in accepted_encodings:
                continue
            candidate_path = Path("%s%s" % (path, extension))
            if candidate_path.is_file():
                return os.fspath(candidate_path), encoding

        return path, None

    def _proxy_request(self) -> None:
        target_base_url: str
        if self.path.startswith("/auth/"):
            target_base_url = self.auth_base_url
        else:
            target_base_url = self.rooms_base_url

        parsed_target = urlparse(target_base_url)
        target_path = self.path
        if parsed_target.path not in ("", "/"):
            target_path = "%s%s" % (parsed_target.path.rstrip("/"), self.path)

        connection_class = (
            http.client.HTTPSConnection
            if parsed_target.scheme == "https"
            else http.client.HTTPConnection
        )
        connection = connection_class(parsed_target.netloc, timeout=30)
        body_length = int(self.headers.get("Content-Length", "0") or "0")
        request_body = self.rfile.read(body_length) if body_length > 0 else None

        forwarded_headers: dict[str, str] = {}
        for header_name, header_value in self.headers.items():
            normalized_name = header_name.lower()
            if normalized_name in HOP_BY_HOP_HEADERS:
                continue
            if normalized_name == "host":
                forwarded_headers[header_name] = parsed_target.netloc
                continue
            forwarded_headers[header_name] = header_value

        try:
            connection.request(
                self.command,
                target_path,
                body=request_body,
                headers=forwarded_headers,
            )
            upstream_response = connection.getresponse()
            response_body = upstream_response.read()
        except OSError as exc:
            self.send_error(502, "Proxy request failed: %s" % exc)
            return
        finally:
            connection.close()

        self.send_response(upstream_response.status, upstream_response.reason)
        for header_name, header_value in upstream_response.getheaders():
            if header_name.lower() in HOP_BY_HOP_HEADERS:
                continue
            self.send_header(header_name, header_value)
        self.end_headers()
        self.wfile.write(response_body)

    def _proxy_websocket(self) -> None:
        parsed_target = urlparse(self.game_server_url)
        target_host = parsed_target.hostname or "127.0.0.1"
        target_port = parsed_target.port or 80
        target_path = self.path
        if parsed_target.path not in ("", "/"):
            target_path = parsed_target.path
        if "?" in self.path and "?" not in target_path:
            target_path = "%s?%s" % (
                target_path,
                self.path.split("?", 1)[1],
            )

        try:
            upstream_socket = socket.create_connection((target_host, target_port), timeout=30)
        except OSError as exc:
            self.send_error(502, "WebSocket proxy connection failed: %s" % exc)
            return

        request_lines = ["GET %s HTTP/1.1" % target_path]
        for header_name, header_value in self.headers.items():
            normalized_name = header_name.lower()
            if normalized_name in HOP_BY_HOP_HEADERS and normalized_name not in ("upgrade", "connection"):
                continue
            if normalized_name == "host":
                request_lines.append("Host: %s:%d" % (target_host, target_port))
                continue
            request_lines.append("%s: %s" % (header_name, header_value))
        request_lines.append("")
        request_lines.append("")

        try:
            upstream_socket.sendall("\r\n".join(request_lines).encode("utf-8"))
            response_buffer = b""
            while b"\r\n\r\n" not in response_buffer:
                chunk = upstream_socket.recv(65536)
                if not chunk:
                    raise OSError("empty upstream response")
                response_buffer += chunk
                if len(response_buffer) > 65536:
                    raise OSError("upstream response headers too large")

            header_block, remaining_bytes = response_buffer.split(b"\r\n\r\n", 1)
            self.connection.sendall(header_block + b"\r\n\r\n")
            if remaining_bytes:
                self.connection.sendall(remaining_bytes)
            self.close_connection = True
            self._tunnel_bidirectional(self.connection, upstream_socket)
        except OSError as exc:
            try:
                self.send_error(502, "WebSocket proxy exchange failed: %s" % exc)
            except OSError:
                pass
        finally:
            upstream_socket.close()

    def _tunnel_bidirectional(
        self,
        client_socket: socket.socket,
        upstream_socket: socket.socket,
    ) -> None:
        sockets = [client_socket, upstream_socket]
        while True:
            readable, _, exceptional = select.select(sockets, [], sockets, 30)
            if exceptional:
                break
            if not readable:
                continue
            for source_socket in readable:
                try:
                    data = source_socket.recv(65536)
                except OSError:
                    return
                if not data:
                    return
                destination_socket = (
                    upstream_socket if source_socket is client_socket else client_socket
                )
                try:
                    destination_socket.sendall(data)
                except OSError:
                    return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Serve the built web-wrapper with local auth/rooms proxying."
    )
    parser.add_argument("--root", required=True, help="Directory to serve statically")
    parser.add_argument("--port", required=True, type=int, help="Port to bind")
    parser.add_argument("--auth-base-url", required=True, help="Auth service base URL")
    parser.add_argument("--rooms-base-url", required=True, help="Rooms API base URL")
    parser.add_argument("--game-server-url", required=True, help="Game server WebSocket URL")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    serve_root = Path(args.root).resolve()
    if not serve_root.is_dir():
        raise SystemExit("Static root does not exist: %s" % serve_root)

    StaticWrapperHandler.auth_base_url = args.auth_base_url.rstrip("/")
    StaticWrapperHandler.rooms_base_url = args.rooms_base_url.rstrip("/")
    StaticWrapperHandler.game_server_url = args.game_server_url.rstrip("/")
    handler_class = partial(StaticWrapperHandler, directory=os.fspath(serve_root))

    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler_class)
    print(
        "Serving static web-wrapper from %s on http://127.0.0.1:%d"
        % (serve_root, args.port)
    )
    print(
        "Proxying /auth/* to %s, /v0/rooms* to %s, and WebSocket traffic to %s"
        % (
            StaticWrapperHandler.auth_base_url,
            StaticWrapperHandler.rooms_base_url,
            StaticWrapperHandler.game_server_url,
        )
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
