#!/usr/bin/env python3

import socket
import sys
import json
import time

def check_tcp_port(ip, port, timeout=3):
    """Test if a TCP port is open"""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect((ip, port))
        s.shutdown(socket.SHUT_RDWR)
        return True
    except Exception:
        return False
    finally:
        s.close()

def check_udp_port(ip, port, timeout=3):
    """Test if a UDP port is responding
    Note: UDP port checking is less reliable as many services don't respond to empty packets"""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        s.sendto(b"", (ip, port))
        data, addr = s.recvfrom(1024)
        return True
    except socket.timeout:
        # Many UDP services might not respond to our probe
        # For more accurate checking, use protocol-specific probes
        return False
    except Exception:
        return False
    finally:
        s.close()

def main():
    if len(sys.argv) != 2:
        print("Usage: %s 'JSON_DATA'" % sys.argv[0])
        sys.exit(1)
    
    try:
        verification_data = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        print("Error parsing JSON data")
        sys.exit(1)
    
    results = []
    
    for item in verification_data:
        ip = item.get('ip')
        port = int(item.get('port'))
        protocol = item.get('protocol', 'tcp').lower()
        expected = item.get('expect', 'success').lower()
        
        if protocol == 'tcp':
            is_open = check_tcp_port(ip, port)
        elif protocol == 'udp':
            is_open = check_udp_port(ip, port)
        else:
            results.append({
                'ip': ip,
                'port': port,
                'protocol': protocol,
                'expected': expected,
                'actual': 'error',
                'error': 'Unsupported protocol',
                'success': False
            })
            continue
        
        actual = 'success' if is_open else 'failure'
        success = (actual == expected)
        
        results.append({
            'ip': ip,
            'port': port,
            'protocol': protocol,
            'expected': expected,
            'actual': actual,
            'success': success
        })
    
    print(json.dumps({'results': results}))
    
    # If any test fails (didn't match expectation), exit with non-zero code
    if not all(result['success'] for result in results):
        sys.exit(1)

if __name__ == "__main__":
    main()