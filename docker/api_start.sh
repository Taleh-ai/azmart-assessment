set -e
python  azmart-assessment\candidate_package\mock_api_server.py --port 8008 &
exec socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:8008