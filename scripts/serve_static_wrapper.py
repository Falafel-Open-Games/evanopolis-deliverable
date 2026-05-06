#!/usr/bin/env python3

from __future__ import annotations

import argparse
import http.client
import os
import select
import socket
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
