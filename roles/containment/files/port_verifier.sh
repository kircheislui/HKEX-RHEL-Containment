#!/bin/bash

# port_verifier.sh - Simple port checking script for RHEL 7/8/9
# Usage: ./port_verifier.sh '[{"ip":"192.168.1.1","port":22,"protocol":"tcp","expect":"success"}]'

# Set safe error handling
set -o pipefail

# Function to check if a TCP port is open using timeout
check_tcp_port() {
  local ip="$1"
  local port="$2"
  local timeout_seconds=3
  
  echo "Checking TCP connection to $ip:$port..." >&2
  
  # Use timeout with bash's /dev/tcp for TCP port checking
  if timeout $timeout_seconds bash -c "</dev/tcp/$ip/$port" >/dev/null 2>&1; then
    echo "TCP port $ip:$port is OPEN" >&2
    return 0  # Success
  else
    echo "TCP port $ip:$port is CLOSED or filtered" >&2
    return 1  # Failure
  fi
}

# Function to check UDP port using timeout
check_udp_port() {
  local ip="$1"
  local port="$2"
  local timeout_seconds=3
  
  echo "Checking UDP connection to $ip:$port..." >&2
  
  # Use timeout with bash's /dev/udp for UDP port checking
  if timeout $timeout_seconds bash -c "</dev/udp/$ip/$port" >/dev/null 2>&1; then
    echo "UDP port $ip:$port appears to be OPEN" >&2
    # Add warning about UDP check limitations
    echo "Note: UDP check can only verify if packets can be sent, not if service is responding" >&2
    return 0  # Success
  else
    echo "UDP port $ip:$port appears to be CLOSED or filtered" >&2
    return 1  # Failure
  fi
}

# Main function with improved JSON parsing
main() {
  # Check for required argument
  if [ $# -ne 1 ]; then
    echo "Usage: $0 'JSON_DATA'" >&2
    exit 1
  fi
  
  # Get raw input
  raw_input="$1"
  echo "Processing verification tests..." >&2
  
  # Remove any escaped quotes and normalize JSON format
  # This is critical for handling JSON passed through Ansible
  clean_json=$(echo "$raw_input" | sed 's/\\"/"/g')
  
  # Initialize results array and success tracker
  declare -a results=()
  all_success=true
  
  # Extract verification items using regex
  # Remove square brackets to process the array contents
  clean_input="${clean_json#\[}"
  clean_input="${clean_input%\]}"
  
  # Debug output for troubleshooting
  echo "Parsing input: $clean_input" >&2
  
  # Split by closing/opening braces of objects
  # Use a more robust splitting approach for JSON
  json_objects=()
  brace_count=0
  current_object=""
  
  for (( i=0; i<${#clean_input}; i++ )); do
    char="${clean_input:$i:1}"
    current_object+="$char"
    
    if [[ "$char" == "{" ]]; then
      ((brace_count++))
    elif [[ "$char" == "}" ]]; then
      ((brace_count--))
      if [[ $brace_count -eq 0 && "${current_object: -1}" == "}" ]]; then
        json_objects+=("$current_object")
        current_object=""
        # Skip the comma if present
        if [[ "${clean_input:$i+1:1}" == "," ]]; then
          ((i++))
        fi
      fi
    fi
  done
  
  # Check if we have any objects
  if [ ${#json_objects[@]} -eq 0 ]; then
    # Try an alternative approach - simple splitting by },{
    IFS='},{' read -ra objects <<< "$clean_input"
    
    for obj in "${objects[@]}"; do
      # Ensure object has proper braces
      if [[ ! "$obj" =~ ^\{ ]]; then
        obj="{"$obj
      fi
      if [[ ! "$obj" =~ \}$ ]]; then
        obj=$obj"}"
      fi
      
      json_objects+=("$obj")
    done
  fi
  
  echo "Found ${#json_objects[@]} verification items to process" >&2
  
  # Process each object
  for obj in "${json_objects[@]}"; do
    # Extract IP address
    ip=""
    if [[ "$obj" =~ \"ip\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      ip="${BASH_REMATCH[1]}"
    fi
    
    # Skip if no IP found
    if [[ -z "$ip" ]]; then
      echo "Warning: Skipping object with no IP address: $obj" >&2
      continue
    fi
    
    # Extract port (default to 22 if not found)
    port=22
    if [[ "$obj" =~ \"port\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
      port="${BASH_REMATCH[1]}"
    fi
    
    # Extract protocol (default to tcp if not found)
    protocol="tcp"
    if [[ "$obj" =~ \"protocol\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      protocol="${BASH_REMATCH[1]}"
    fi
    
    # Extract expected result (default to success if not found)
    expected="success"
    if [[ "$obj" =~ \"expect\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      expected="${BASH_REMATCH[1]}"
    fi
    
    echo "Testing $protocol://$ip:$port (expect: $expected)" >&2
    
    # Perform the actual port check
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
      echo "Warning: Unsupported protocol '$protocol', defaulting to tcp" >&2
      if check_tcp_port "$ip" "$port"; then
        actual="success"
      else
        actual="failure"
      fi
    fi
    
    # Check if result matches expectation
    success=$([[ "$actual" == "$expected" ]] && echo true || echo false)
    if [[ "$success" == "false" ]]; then
      all_success=false
    fi
    
    # Add to results
    results+=("{\"ip\":\"$ip\",\"port\":$port,\"protocol\":\"$protocol\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"success\":$success}")
    echo "Result: $actual (Expected: $expected) - $([ "$success" == "true" ] && echo "PASS" || echo "FAIL")" >&2
  done
  
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
  final_json+='],"all_success":'$all_success'}'
  
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