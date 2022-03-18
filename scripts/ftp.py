#! /usr/bin/python3
from pathlib import Path

CWD = Path(__file__).parent

def serve_cwd_files(port=None):
    if port is None:
        port = 8080
    import http.server
    import socketserver

    PORT = port

    Handler = http.server.SimpleHTTPRequestHandler

    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print("serving at port", PORT)
        httpd.serve_forever()


def main():
    serve_cwd_files()


if __name__ == "__main__":
    main()
