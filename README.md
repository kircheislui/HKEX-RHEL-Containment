Prerequisite:

Preparation of AAP configuration tasks at Client Side:

•⁠  ⁠Create Job template for API calls

    * Variable for inbound / outbound for testing

•⁠  ⁠Generate user Token for API calls.

•⁠  ⁠Prepare limit host for test

•⁠  ⁠Prepare Credential



Example to launch playbook via API call.

curl -vvv -s -k -X POST \
  -H "Authorization: Bearer UgvDUmM0AlmCQuzrnuATLYEhIUacTH" \
  -H "Content-Type: application/json" \
  -d '{
    "extra_vars": {
      "tower_host": "http://192.168.131.100:31998",
      "tower_token": "UgvDUmM0AlmCQuzrnuATLYEhIUacTH",
      "containment_action": "containment",
      "profile": "FULL",
      "inbound_whitelist": [{"protocol": "tcp", "port": 22, "source": "10.0.0.1"}],
      "outbound_whitelist": [{"protocol": "tcp", "port": 22, "destination": "192.168.131.100"}],
      "verification_list": [
        {"ip": "192.168.131.100", "port": 22, "protocol": "tcp", "expect": "success"},
        {"ip": "10.0.0.2", "port": 22, "protocol": "tcp", "expect": "failure"}
      ],
      "limit": "192.168.131.117,192.168.131.118,192.168.131.21,192.168.131.6"
    }
  }' \
  https://{{ aap }}/api/v2/job_templates/8/launch/


  curl -vvv -s -k -X POST \
  -H "Authorization: Bearer UgvDUmM0AlmCQuzrnuATLYEhIUacTH" \
  -H "Content-Type: application/json" \
  -d '{
    "extra_vars": {
      "containment_action": "resume",
      "profile": "FULL"
    },
    "limit": "10.211.55.4"
  }' \
  http://10.211.55.3:31998/api/v2/job_templates/7/launch/
HKEX_Resume (END)
