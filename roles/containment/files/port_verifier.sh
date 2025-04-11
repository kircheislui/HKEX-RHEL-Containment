- name: Copy port verifier script
  copy:
    dest: "{{ backup_path }}/port_verifier.sh"
    mode: 0755
    content: |
      #!/bin/bash
      
      # Simple port verifier with improved timeout
      # Usage: ./port_verifier.sh '[{"ip":"192.168.1.1","port":22,"protocol":"tcp","expect":"success"},...]'
      
      # Function to check if a TCP port is open with timeout
      check_tcp_port() {
        local ip=$1
        local port=$2
        local max_time=5  # 5 second timeout
        
        # Use timeout command if available
        if command -v timeout >/dev/null 2>&1; then
          if timeout $max_time bash -c "echo > /dev/tcp/$ip/$port" >/dev/null 2>&1; then
            return 0  # Open
          else
            return 1  # Closed or timeout
          fi
        else
          # Set a timer to kill process after timeout
          (sleep $max_time; kill $$) 2>/dev/null & 
          timer_pid=$!
          
          # Try the connection
          if (echo > /dev/tcp/$ip/$port) >/dev/null 2>&1; then
            kill $timer_pid 2>/dev/null
            return 0  # Open
          else
            kill $timer_pid 2>/dev/null
            return 1  # Closed
          fi
        fi
      }
      
      # Function to check if a UDP port is responding with timeout
      check_udp_port() {
        local ip=$1
        local port=$2
        local max_time=5  # 5 second timeout
        
        # Try nc if available
        if command -v nc >/dev/null 2>&1; then
          if command -v timeout >/dev/null 2>&1; then
            if timeout $max_time nc -zu -w $max_time $ip $port >/dev/null 2>&1; then
              return 0  # Open
            else
              return 1  # Closed or timeout
            fi
          else
            if nc -zu -w $max_time $ip $port >/dev/null 2>&1; then
              return 0  # Open
            else
              return 1  # Closed
            fi
          fi
        fi
        
        # Fallback to /dev/udp
        if command -v timeout >/dev/null 2>&1; then
          if timeout $max_time bash -c "echo > /dev/udp/$ip/$port" >/dev/null 2>&1; then
            return 0  # Open
          else
            return 1  # Closed or timeout
          fi
        else
          # Set a timer to kill process after timeout
          (sleep $max_time; kill $$) 2>/dev/null & 
          timer_pid=$!
          
          # Try the connection
          if (echo > /dev/udp/$ip/$port) >/dev/null 2>&1; then
            kill $timer_pid 2>/dev/null
            return 0  # Open
          else
            kill $timer_pid 2>/dev/null
            return 1  # Closed
          fi
        fi
      }
      
      # Main execution
      if [ $# -ne 1 ]; then
        echo "Usage: $0 'JSON_DATA'"
        exit 1
      fi
      
      # Extract entries from the JSON string
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
        
        # Extract values
        ip=$(echo "$entry" | grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f 4)
        port=$(echo "$entry" | grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
        protocol=$(echo "$entry" | grep -o '"protocol"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f 4)
        expect=$(echo "$entry" | grep -o '"expect"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f 4)
        
        # Set defaults
        protocol=${protocol:-tcp}
        expect=${expect:-success}
        
        echo "Checking $protocol://$ip:$port..." >&2
        
        # Perform the check with timeout
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
        
        echo "Result: $actual (Expected: $expect)" >&2
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

- name: Run port verification script
  shell: "{{ backup_path }}/port_verifier.sh '{{ verification_list | to_json }}'"
  register: verification_result
  failed_when: false

- name: Display verification results
  debug:
    var: verification_result.stdout | from_json

- name: Check verification success
  fail:
    msg: "Verification failed: Not all tests passed"
  when: verification_result.rc != 0