from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 8000

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

if __name__ == "__main__":
    server = HTTPServer(('', PORT), Handler)
    print(f"Servidor pingável rodando na porta {PORT}")
    server.serve_forever()
