#!/usr/bin/env python3
import http.server
import socketserver
import subprocess
import html
import os
import signal
import sys

PORT = 7681

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.end_headers()
            
            try:
                pane = subprocess.check_output(['tmux', 'capture-pane', '-pt', 'agy'], text=True)
            except Exception as e:
                pane = f"Waiting for tmux session 'agy'...\n({e})"
            
            status = "Initializing..."
            remote_url = ""
            if os.path.exists('/tmp/agy-status.txt'):
                try:
                    with open('/tmp/agy-status.txt', 'r') as f:
                        lines = [line.strip() for line in f.readlines() if line.strip()]
                        if lines:
                            status = lines[0]
                        for l in lines:
                            if l.startswith("Remote URL:"):
                                remote_url = l.replace("Remote URL:", "").strip()
                except Exception as e:
                    status = f"Error reading status: {e}"

            remote_link_html = ""
            if remote_url:
                remote_link_html = f'<div class="link-box">🔗 <strong>Remote Control Hub:</strong> <a href="{remote_url}" target="_blank" style="color: #58a6ff;">{remote_url}</a></div>'

            html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="2">
<title>Antigravity Live Remote Control</title>
<style>
body {{
    background-color: #0d1117;
    color: #c9d1d9;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace;
    margin: 0;
    padding: 24px;
}}
.container {{
    max-width: 1100px;
    margin: 0 auto;
}}
.header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #30363d;
    padding-bottom: 14px;
    margin-bottom: 18px;
}}
.title {{
    font-size: 20px;
    font-weight: 600;
    color: #f0f6fc;
    display: flex;
    align-items: center;
    gap: 8px;
}}
.badge {{
    background-color: #238636;
    color: white;
    padding: 4px 10px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.5px;
}}
.status-box {{
    background: #161b22;
    border-left: 4px solid #58a6ff;
    padding: 10px 16px;
    border-radius: 4px;
    margin-bottom: 14px;
    font-size: 14px;
}}
.link-box {{
    background: #1f2937;
    border-left: 4px solid #2ea043;
    padding: 10px 16px;
    border-radius: 4px;
    margin-bottom: 14px;
    font-size: 14px;
}}
pre {{
    background-color: #0b0e14;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 20px;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    font-size: 14px;
    line-height: 1.5;
    color: #79c0ff;
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-all;
    box-shadow: inset 0 1px 3px rgba(0,0,0,0.5);
}}
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <div class="title">⚡ Antigravity Live Preview</div>
        <div class="badge">● LIVE AUTO-REFRESH (2s)</div>
    </div>
    <div class="status-box">
        <strong>Session Status:</strong> {html.escape(status)}
    </div>
    {remote_link_html}
    <pre>{html.escape(pane)}</pre>
</div>
</body>
</html>"""
            self.wfile.write(html_content.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

if __name__ == '__main__':
    try:
        with ThreadingHTTPServer(("0.0.0.0", PORT), Handler) as httpd:
            httpd.serve_forever()
    except Exception as e:
        sys.exit(0)
