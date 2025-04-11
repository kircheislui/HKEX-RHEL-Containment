#!/bin/bash

# port_verifier.sh - Simple port checking script without hardcoding
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

# Extract value from JSON object
extract_value() {
  local json="$1"
  local key="$2"
  
  # Extract value for the given key
  local pattern="\"$key\"[[:space:]]*:[[:space:]]*"
  
  # Check if it's a string value (has quotes)
  if echo "$json" | grep -q "\"$key\"[[:space:]]*:[[:space:]]*\""; then
    # It's a string value with quotes
    echo "$json" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
  else
    # It's a numeric value without quotes
    echo "$json" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p'
  fi
}

# Main function
main() {
  # Check for required argument
  if [ $# -ne 1 ]; then
    echo "Usage: $0 'JSON_DATA'" >&2
    exit 1
  fi
  
  # Initialize results array and success tracker
  declare -a results=()
  all_success=true
  
  # Get the JSON input
  local input="$1"
  
  # Clean the input - strip unnecessary whitespace
  input=$(echo "$input" | tr -d '\n\r')
  
  # Validate that we have a JSON array
  if [[ ! "$input" =~ ^\[.*\]$ ]]; then
    echo "Error: Input is not a valid JSON array" >&2
    exit 1
  fi
  
  # Extract the items more reliably by using jq-like approach with sed
  # Remove the outer brackets
  content="${input#\[}"
  content="${content%\]}"
  
  # Check if we have content
  if [[ -z "$content" ]]; then
    echo '{"results":[]}' 
    exit 0
  fi
  
  # Split the items using temporary delimiter
  # Replace },{
  content=$(echo "$content" | sed 's/},{/@@@/g')
  
  # Now we can split by our delimiter
  IFS="@@@" read -ra items <<< "$content"
  
  # Process each item
  for item in "${items[@]}"; do
    # Clean up the item to ensure it has proper JSON format
    item=$(echo "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    
    # Add braces if missing
    if [[ ! "$item" =~ ^\{.*\}$ ]]; then
      item="{$item}"
    fi
    
    # Skip empty objects
    if [[ "$item" == "{}" ]]; then
      continue
    fi
    
    # Extract the values using our helper function
    ip=$(extract_value "$item" "ip")
    port=$(extract_value "$item" "port")
    protocol=$(extract_value "$item" "protocol")
    expect=$(extract_value "$item" "expect")
    
    # Set defaults for optional fields
    protocol="${protocol:-tcp}"
    expect="${expect:-success}"
    
    # Skip items without required fields
    if [[ -z "$ip" ]]; then
      echo "Warning: Missing IP address in item. Skipping." >&2
      continue
    fi
    
    if [[ -z "$port" ]]; then
      echo "Warning: Missing port in item. Skipping." >&2
      continue
    fi
    
    # Perform the check
    echo "Checking $protocol://$ip:$port..." >&2
    
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
      echo "Error: Unsupported protocol $protocol" >&2
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
  
  # If no valid results, return empty array
  if [ ${#results[@]} -eq 0 ]; then
    echo '{"results":[]}' 
    exit 1
  fi
  
  # Add results to JSON with commas
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