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
      "containment_action": "containment",
      "profile": "FULL",
      "inbound_whitelist": [
        {"protocol": "tcp", "port": 22, "source": "10.0.0.1"}
      ],
      "outbound_whitelist": [
        {"protocol": "tcp", "port": 80, "destination": "10.0.0.2"}
      ],
      "verification_list": ["8.8.8.8", "1.1.1.1"]
    },
    "limit": "192.168.1.191"
  }' \
  http://192.168.1.38:31998/api/v2/job_templates/7/launch/


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
