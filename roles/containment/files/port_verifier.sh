#!/bin/bash

# port_verifier.sh - Simple port checking script
# Usage: ./port_verifier.sh '[{"ip":"192.168.0.18","port":22,"protocol":"tcp","expect":"success"}]'

# Set strict error handling
set -o nounset

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

# Main function
main() {
  # Check for required argument
  if [ $# -ne 1 ]; then
    echo "Usage: $0 'JSON_DATA'" >&2
    exit 1
  fi
  
  # Initialize results array
  declare -a results=()
  all_success=true
  
  # Simple manual parsing of JSON array
  json_input="$1"
  
  # Clean the input - strip spaces/newlines
  json_input=$(echo "$json_input" | tr -d '\n\r' | sed 's/ //g')
  
  # Validate that we have a JSON array
  if [[ ! "$json_input" =~ ^\[.*\]$ ]]; then
    echo "Error: Input is not a valid JSON array" >&2
    exit 1
  fi
  
  # Remove outer brackets
  json_input="${json_input#\[}"
  json_input="${json_input%\]}"
  
  # Handle empty array
  if [[ -z "$json_input" ]]; then
    echo '{"results":[]}' 
    exit 0
  fi
  
  # Split JSON objects by commas that are not within quotes
  # This uses a temporary delimiter to split objects
  temp_delim="SPLIT_HERE"
  
  # Replace object delimiter with temporary delimiter
  # This replacement handles only commas between objects
  parsed_input=$(echo "$json_input" | sed 's/},{/}'"$temp_delim"'{/g')
  
  # Now split by our temporary delimiter
  IFS="$temp_delim" read -ra objects <<< "$parsed_input"
  
  # Process each object
  for obj in "${objects[@]}"; do
    # Ensure we have complete JSON object with curly braces
    if [[ ! "$obj" =~ ^\{.*\}$ ]]; then
      obj="{$obj}"
    fi
    
    # Extract values safely using grep and sed
    ip=$(echo "$obj" | grep -o '"ip":"[^"]*"' | sed 's/"ip":"//;s/"$//')
    port=$(echo "$obj" | grep -o '"port":[0-9]*' | sed 's/"port"://')
    protocol=$(echo "$obj" | grep -o '"protocol":"[^"]*"' | sed 's/"protocol":"//;s/"$//')
    expect=$(echo "$obj" | grep -o '"expect":"[^"]*"' | sed 's/"expect":"//;s/"$//')
    
    # Set defaults for missing values
    protocol="${protocol:-tcp}"
    expect="${expect:-success}"
    
    # Validate ip and port
    if [[ -z "$ip" ]]; then
      echo "Warning: Empty IP address in input object: $obj" >&2
      ip="missing_ip"
    fi
    
    if [[ -z "$port" ]]; then
      echo "Warning: Empty port in input object: $obj" >&2
      port="0"
    fi
    
    # Check connectivity
    echo "Checking $protocol://$ip:$port..." >&2
    
    # Perform test based on protocol
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
      # Unsupported protocol
      actual="error"
    fi
    
    # Check if result matches expectation
    if [[ "$actual" == "$expect" ]]; then
      success="true"
    else
      success="false"
      all_success=false
    fi
    
    # Create JSON object for this result
    result='{'
    result+='"ip":"'"$ip"'",'
    result+='"port":'"$port"','
    result+='"protocol":"'"$protocol"'",'
    result+='"expected":"'"$expect"'",'
    result+='"actual":"'"$actual"'",'
    result+='"success":'"$success"
    result+='}'
    
    # Add to results array
    results+=("$result")
    
    echo "Result: $actual (Expected: $expect)" >&2
  done
  
  # Combine results into final JSON
  final_json='{"results":['
  for i in "${!results[@]}"; do
    if [ $i -gt 0 ]; then
      final_json+=','
    fi
    final_json+="${results[$i]}"
  done
  final_json+=']}'
  
  # Output final JSON
  echo "$final_json"
  
  # Return exit code
  if [ "$all_success" = true ]; then
    exit 0
  else
    exit 1
  fi
}

# Run main function
main "$@"