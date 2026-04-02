# #!/bin/bash

# sudo yum update -y
# sudo yum install python3 python3-pip tmux git -y

# pip3 install fastapi uvicorn flask requests

# mkdir -p ~/sandbox_server

# echo "Setup complete."
# echo "Run:"
# echo "tmux new -s sandbox"
# echo "cd ~/sandbox_server"
# echo "uvicorn server:app --host 0.0.0.0 --port 8000"
#!/bin/bash
# Run this on a fresh EC2 instance to set up the sandbox
sudo yum update -y
sudo yum install python3 python3-pip tmux git -y
pip3 install fastapi uvicorn flask requests
mkdir -p ~/sandbox_server
cd ~/sandbox_server
tmux new-session -d -s sandbox "uvicorn server:app --host 0.0.0.0 --port 8000"
echo "Sandbox started on port 8000"