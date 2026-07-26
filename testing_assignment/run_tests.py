
import subprocess
import time
import os
from mock_server import start_server

if __name__ == '__main__':
    server = start_server()
    time.sleep(2)
    print("Running pytest...")
    subprocess.run(["pytest", "-v", "--html=report.html", "--self-contained-html"])
    print("Tests finished. Stopping server.")
    server.shutdown()
