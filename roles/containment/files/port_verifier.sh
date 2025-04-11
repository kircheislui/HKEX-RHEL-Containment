#!/bin/bash

# Simple port verifier - minimal dependencies
# Usage: ./port_verifier.sh '[{"ip":"192.168.1.1","port":22,"protocol":"tcp","expect":"success"},...]'

# Function to check if a TCP port is open
check_tcp_port() {
  local ip=$1
  local port=$2
  
  # Using bash built-in /dev/tcp with a timeout
  if (echo > /dev/tcp/$ip/$port) >/dev/null 2>&1; then
    return 0  # Success, port is open
  else
    return 1  # Failure, port is closed
  fi
}

# Function to check if a UDP port is responding
check_udp_port() {
  local ip=$1
  local port=$2
  
  # Using bash built-in /dev/udp (less reliable for UDP)
  if (echo > /dev/udp/$ip/$port) >/dev/null 2>&1; then
    return 0  # Success
  else
    return 1  # Failure
  fi
}

# Main execution
if [ $# -ne 1 ]; then
  echo "Usage: $0 'JSON_DATA'"
  exit 1
fi

# Extract entries from the JSON string
# This is very simplistic and won't handle complex JSON
input="$1"
input="${input#[}" # Remove leading [
input="${input%]}" # Remove trailing ]

IFS='},{'
entries=($input)

success_all=true
results="{"
results+='"results":['

for i in "${!entries[@]}"; do
  entry="${entries[$i]}"
  entry="${entry#'{'}"  # Remove leading {
  entry="${entry%'}'}"  # Remove trailing }
  
  # Extract values with simple pattern matching
  ip=$(echo "$entry" | grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f 4)
  port=$(echo "$entry" | grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
  protocol=$(echo "$entry" | grep -o '"protocol"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f 4)
  expect=$(echo "$entry" | grep -o '"expect"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f 4)
  
  # Set defaults
  protocol=${protocol:-tcp}
  expect=${expect:-success}
  
  # Perform the check
  if [ "$protocol" = "tcp" ]; then
    if check_tcp_port "$ip" "$port"; then
      actual="success"
    else
      actual="failure"
    fi
  elif [ "$protocol" = "udp" ]; then
    if check_udp_port "$ip" "$port"; then
      actual="success"
    else
      actual="failure"
    fi
  else
    actual="error"
  fi
  
  # Check if it matches expectation
  if [ "$actual" = "$expect" ]; then
    success="true"
  else
    success="false"
    success_all=false
  fi
  
  # Add comma for all but the first entry
  if [ $i -gt 0 ]; then
    results+=","
  fi
  
  # Add this result to the JSON output
  results+='{'
  results+='"ip":"'"$ip"'",'
  results+='"port":'"$port"','
  results+='"protocol":"'"$protocol"'",'
  results+='"expected":"'"$expect"'",'
  results+='"actual":"'"$actual"'",'
  results+='"success":'"$success"
  results+='}'
done

# Close the JSON
results+=']}'

# Output the results
echo "$results"

# Exit with error if any test failed
if [ "$success_all" = false ]; then
  exit 1
fi

exit 0