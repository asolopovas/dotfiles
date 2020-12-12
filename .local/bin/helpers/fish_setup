#!/bin/bash

fishlogin=/usr/local/bin/fishlogin
#
# sudo touch $fishlogin
# sudo bash -c "cat > $fishlogin" << EOL
# #!/bin/bash -l
# exec -l fish "\$@"
# EOL
#
# sudo chmod a+rx $fishlogin
# echo $fishlogin | sudo tee -a /etc/shells
sudo usermod -s $fishlogin $( whoami )
