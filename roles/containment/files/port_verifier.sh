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

# Check if string is a valid JSON object
is_valid_json_object() {
  local obj="$1"
  # Check if it has curly braces and at least one key-value pair
  if [[ "$obj" =~ ^\{.*:.*\}$ ]]; then
    return 0  # Valid
  else
    return 1  # Invalid
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
  
  # Get JSON input
  json_input="$1"
  
  # Clean the input - strip unnecessary whitespace
  json_input=$(echo "$json_input" | tr -d '\n\r' | sed 's/[[:space:]]\+/ /g')
  
  # Validate that we have a JSON array
  if [[ ! "$json_input" =~ ^\[.*\]$ ]]; then
    echo "Error: Input is not a valid JSON array" >&2
    exit 1
  fi
  
  # Extract the actual list items more reliably
  # First, remove the enclosing square brackets
  json_input="${json_input#\[}"
  json_input="${json_input%\]}"
  
  # If no items, exit early
  if [[ -z "$json_input" ]]; then
    echo '{"results":[]}' 
    exit 0
  fi
  
  # Handle verification_list directly
  # This improved approach extracts JSON objects more reliably
  # Match all complete objects with balanced braces
  while [[ "$json_input" =~ \{([^{}]|\{[^{}]*\})*\} ]]; do
    # Extract the matched object
    obj="${BASH_REMATCH[0]}"
    
    # Skip empty or invalid objects
    if ! is_valid_json_object "$obj"; then
      # Remove this object from the input and continue
      json_input="${json_input/${BASH_REMATCH[0]}/}"
      continue
    fi
    
    # Extract values more reliably
    ip=""
    port=""
    protocol="tcp"  # Default
    expect="success"  # Default
    
    # Extract IP
    if [[ "$obj" =~ \"ip\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
      ip="${BASH_REMATCH[1]}"
    fi
    
    # Extract port
    if [[ "$obj" =~ \"port\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
      port="${BASH_REMATCH[1]}"
    fi
    
    # Extract protocol
    if [[ "$obj" =~ \"protocol\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
      protocol="${BASH_REMATCH[1]}"
    fi
    
    # Extract expect
    if [[ "$obj" =~ \"expect\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
      expect="${BASH_REMATCH[1]}"
    fi
    
    # Validate required fields
    if [[ -z "$ip" ]]; then
      echo "Warning: Missing IP address in object. Skipping." >&2
      # Remove this object from the input and continue
      json_input="${json_input/${BASH_REMATCH[0]}/}"
      continue
    fi
    
    if [[ -z "$port" ]]; then
      echo "Warning: Missing port in object. Skipping." >&2
      # Remove this object from the input and continue
      json_input="${json_input/${BASH_REMATCH[0]}/}"
      continue
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
    
    # Remove this object from the input and continue
    json_input="${json_input/${BASH_REMATCH[0]}/}"
    
    # Remove leading comma if present
    json_input="${json_input#,}"
    # Remove trailing comma if present
    json_input="${json_input%,}"
    # Remove leading whitespace
    json_input="${json_input#"${json_input%%[![:space:]]*}"}"
    # Remove trailing whitespace
    json_input="${json_input%"${json_input##*[![:space:]]}"}"
  done
  
  # If no valid objects were processed, print warning
  if [ ${#results[@]} -eq 0 ]; then
    echo "Warning: No valid objects found in input JSON" >&2
    echo '{"results":[]}' 
    exit 1
  fi
  
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