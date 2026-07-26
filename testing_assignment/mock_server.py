
from http.server import SimpleHTTPRequestHandler, HTTPServer
import threading

class MockServerRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = '/login.html'
        elif self.path == '/dashboard':
            self.path = '/dashboard.html'
        return super().do_GET()

def start_server():
    server = HTTPServer(('127.0.0.1', 8080), MockServerRequestHandler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    return server

if __name__ == '__main__':
    server = start_server()
    print("Mock server running on http://127.0.0.1:8080")
    import time
    while True: time.sleep(1)
