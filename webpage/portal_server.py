#!/usr/bin/env python3
"""
WiFi Portal Web Server with Captive Portal Support
Handles open and secured networks
"""

import json
import subprocess
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

class PortalHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass
    
    def do_GET(self):
        # Serve logo image
        if self.path == '/logo.png':
            self.send_response(200)
            self.send_header('Content-type', 'image/png')
            self.send_header('Cache-Control', 'public, max-age=3600')
            self.end_headers()
            try:
                with open('/var/www/portal/logo.png', 'rb') as f:
                    self.wfile.write(f.read())
            except Exception as e:
                pass
        
        # Android captive portal detection - must return specific responses
        elif self.path.startswith('/generate_204'):
            # Android expects 204 No Content when internet is available
            # Return 302 redirect to force captive portal
            self.send_response(302)
            self.send_header('Location', 'http://192.168.5.1/')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
        
        # Apple captive portal detection
        elif self.path.startswith('/hotspot-detect.html') or \
             self.path.startswith('/library/test/success.html'):
            # Apple expects specific HTML with "Success"
            # Return portal instead to trigger captive portal
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
            # Return portal page instead of success
            try:
                with open('/var/www/portal/index.html', 'rb') as f:
                    self.wfile.write(f.read())
            except Exception as e:
                error_page = f'<html><body><h1>Portal Error</h1><p>{str(e)}</p></body></html>'
                self.wfile.write(error_page.encode())
        
        # Microsoft/Windows captive portal detection
        elif self.path.startswith('/connecttest.txt') or \
             self.path.startswith('/ncsi.txt'):
            # Return redirect to force captive portal
            self.send_response(302)
            self.send_header('Location', 'http://192.168.5.1/')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
        
        # Serve portal page for main requests
        elif self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
            try:
                with open('/var/www/portal/index.html', 'rb') as f:
                    self.wfile.write(f.read())
            except Exception as e:
                error_page = f'<html><body><h1>Portal Error</h1><p>{str(e)}</p></body></html>'
                self.wfile.write(error_page.encode())
        
        elif self.path == '/scan':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
            
            try:
                # Scan for WiFi networks
                result = subprocess.run(
                    ['sudo', 'iw', 'dev', 'wlan0', 'scan'], 
                    capture_output=True, 
                    text=True, 
                    timeout=10
                )
                
                # Parse SSIDs and security from scan results
                networks = []
                current_network = {}
                
                for line in result.stdout.split('\n'):
                    line = line.strip()
                    
                    # New BSS entry
                    if line.startswith('BSS '):
                        if current_network.get('ssid'):
                            networks.append(current_network)
                        current_network = {'ssid': '', 'security': 'OPEN'}
                    
                    # SSID
                    elif 'SSID:' in line:
                        ssid = line.split('SSID:')[1].strip()
                        if ssid:
                            current_network['ssid'] = ssid
                    
                    # Security
                    elif 'RSN:' in line or 'WPA:' in line:
                        current_network['security'] = 'SECURED'
                
                # Add last network
                if current_network.get('ssid'):
                    networks.append(current_network)
                
                # Remove duplicates and sort
                unique_networks = {}
                for net in networks:
                    ssid = net['ssid']
                    if ssid not in unique_networks:
                        unique_networks[ssid] = net
                    elif net['security'] == 'SECURED':
                        # Prefer secured status if network appears multiple times
                        unique_networks[ssid] = net
                
                sorted_networks = sorted(unique_networks.values(), key=lambda x: x['ssid'])
                
                response = {'networks': sorted_networks}
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                error_response = {'networks': [], 'error': str(e)}
                self.wfile.write(json.dumps(error_response).encode())
        
        else:
            # Redirect all other requests to portal
            self.send_response(302)
            self.send_header('Location', 'http://192.168.5.1/')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/connect':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            
            ssid = data.get('ssid', '')
            password = data.get('password', '')
            is_open = data.get('is_open', False)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
            
            if ssid:
                try:
                    # Call the connection script with appropriate parameters
                    if is_open:
                        subprocess.Popen(['/usr/local/bin/wifi-connect.sh', ssid, '--open'])
                    else:
                        if password:
                            subprocess.Popen(['/usr/local/bin/wifi-connect.sh', ssid, password])
                        else:
                            response = {'success': False, 'message': 'Password required for secured network'}
                            self.wfile.write(json.dumps(response).encode())
                            return
                    
                    response = {
                        'success': True, 
                        'message': f'Connecting to {ssid}... The portal will close shortly.'
                    }
                except Exception as e:
                    response = {'success': False, 'message': f'Error: {str(e)}'}
            else:
                response = {'success': False, 'message': 'SSID required'}
            
            self.wfile.write(json.dumps(response).encode())

if __name__ == '__main__':
    print("=" * 50)
    print("WiFi Portal Server Starting")
    print("=" * 50)
    print("Listening on: http://192.168.5.1:80")
    print("Captive Portal: Enabled")
    print("Open Networks: Supported")
    print("Press Ctrl+C to stop")
    print("=" * 50)
    
    server = HTTPServer(('192.168.5.1', 80), PortalHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\nShutting down server...")
        server.shutdown()