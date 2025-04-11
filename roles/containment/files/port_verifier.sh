#!/bin/bash

# port_verifier.sh - Simple port checking script (more general approach)
# Usage: ./port_verifier.sh '[{"ip":"192.168.0.18","port":22,"protocol":"tcp","expect":"success"}]'

# Set safe error handling
set -o nounset
set -o pipefail

# Function to check if a TCP port is open
check_tcp_port() {
  local ip="$1"
  local port="$2"
  local timeout=5
  
  # Validate input
  if [[ -z "$ip" ]] || [[ -z "$port" ]]; then
    echo "Invalid input: IP or port is empty" >&2
    return 1
  fi
  
  echo "Checking TCP connection to $ip:$port..." >&2
  
  # Use timeout command if available
  if command -v timeout >/dev/null 2>&1; then
    if timeout $timeout bash -c "echo > /dev/tcp/$ip/$port" >/dev/null 2>&1; then
      return 0  # Success
    else
      return 1  # Failure
    fi
  else
    # Fallback if timeout is not available
    if (echo > /dev/tcp/$ip/$port) >/dev/null 2>&1; then
      return 0  # Success
    else
      return 1  # Failure
    fi
  fi
}

# Function to check UDP port
check_udp_port() {
  local ip="$1"
  local port="$2"
  local timeout=5
  
  # Validate input
  if [[ -z "$ip" ]] || [[ -z "$port" ]]; then
    echo "Invalid input: IP or port is empty" >&2
    return 1
  fi
  
  echo "Checking UDP connection to $ip:$port..." >&2
  
  # Try nc if available
  if command -v nc >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
      if timeout $timeout nc -zu -w $timeout $ip $port >/dev/null 2>&1; then
        return 0  # Success
      else
        return 1  # Failure
      fi
    else
      if nc -zu -w $timeout $ip $port >/dev/null 2>&1; then
        return 0  # Success
      else
        return 1  # Failure
      fi
    fi
  else
    # Fallback to dev/udp
    if command -v timeout >/dev/null 2>&1; then
      if timeout $timeout bash -c "echo > /dev/udp/$ip/$port" >/dev/null 2>&1; then
        return 0  # Success
      else
        return 1  # Failure
      fi
    else
      if (echo > /dev/udp/$ip/$port) >/dev/null 2>&1; then
        return 0  # Success
      else
        return 1  # Failure
      fi
    fi
  fi
}

# Find all IP addresses in a string
find_ips() {
  local input="$1"
  # Match IPv4 addresses
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<< "$input" | sort -u
}

# Extract JSON value for key in an IP-specific context
extract_ip_value() {
  local json="$1"
  local ip="$2"
  local key="$3"
  local default="$4"
  
  # Find a section with this IP
  local section
  section=$(grep -o "{[^}]*\"ip\":\"$ip\"[^}]*}" <<< "$json" || echo "")
  
  if [[ -z "$section" ]]; then
    section=$(grep -o "{[^}]*$ip[^}]*}" <<< "$json" || echo "")
  fi
  
  if [[ -z "$section" ]]; then
    echo "$default"
    return
  fi
  
  # Now extract the key from that section
  if [[ "$key" == "port" ]]; then
    # Port is numeric
    local port
    port=$(grep -o "\"port\":[0-9]*" <<< "$section" | grep -o "[0-9]*" || echo "")
    if [[ -n "$port" ]]; then
      echo "$port"
    else
      echo "$default"
    fi
  else
    # Other keys are likely strings
    local value
    value=$(grep -o "\"$key\":\"[^\"]*\"" <<< "$section" | sed "s/\"$key\":\"//;s/\"$//" || echo "")
    if [[ -n "$value" ]]; then
      echo "$value"
    else
      echo "$default"
    fi
  fi
}

# Main function
main() {
  # Check for required argument
  if [ $# -ne 1 ]; then
    echo "Usage: $0 'JSON_DATA'" >&2
    exit 1
  fi
  
  # Get raw input
  raw_input="$1"
  echo "Processing input... (length: ${#raw_input} bytes)" >&2
  
  # Initialize results array and success tracker
  declare -a results=()
  all_success=true
  
  # Extract all IPs from the input
  ips=$(find_ips "$raw_input")
  
  if [[ -z "$ips" ]]; then
    echo "Warning: No IP addresses found in input" >&2
    exit 1
  fi
  
  # Process each IP found
  while read -r ip; do
    # Skip empty lines
    if [[ -z "$ip" ]]; then
      continue
    fi
    
    # Try to extract values for this IP
    port=$(extract_ip_value "$raw_input" "$ip" "port" "22")  # Default to port 22 if not specified
    protocol=$(extract_ip_value "$raw_input" "$ip" "protocol" "tcp")  # Default to tcp if not specified
    expected=$(extract_ip_value "$raw_input" "$ip" "expect" "success")  # Default to success if not specified
    
    echo "Found test case: $protocol://$ip:$port (expect: $expected)" >&2
    
    # Perform the test
    if [[ "$protocol" == "tcp" ]]; then
      if check_tcp_port "$ip" "$port"; then
        actual="success"
      else
        actual="failure"
      fi
    elif [[ "$protocol" == "udp" ]]; then
      if check_udp_port "$ip" "$port"; then
        actual="success"
      else
        actual="failure"
      fi
    else
      echo "Unsupported protocol: $protocol" >&2
      actual="error"
    fi
    
    # Check if result matches expectation
    if [[ "$actual" == "$expected" ]]; then
      success=true
    else
      success=false
      all_success=false
    fi
    
    # Create result object
    result="{\"ip\":\"$ip\",\"port\":$port,\"protocol\":\"$protocol\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"success\":$success}"
    results+=("$result")
    
    echo "Result: $actual (Expected: $expected)" >&2
    
  done <<< "$ips"
  
  # Check if we processed any items
  if [ ${#results[@]} -eq 0 ]; then
    echo "Error: No valid verification items found in input" >&2
    exit 1
  fi
  
  # Create final JSON
  final_json='{"results":['
  for i in "${!results[@]}"; do
    if [ $i -gt 0 ]; then
      final_json+=","
    fi
    final_json+="${results[$i]}"
  done
  final_json+=']}'
  
  echo "$final_json"
  
  # Return appropriate exit code
  if [ "$all_success" = true ]; then
    exit 0
  else
    exit 1
  fi
}

# Run the main function with all arguments
main "$@"