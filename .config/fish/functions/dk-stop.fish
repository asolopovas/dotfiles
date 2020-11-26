# Defined in - @ line 1
function dk-stop --wraps=docker\ stop\ \'\(docker\ ps\ -a\ -q\)\'\;\ docker\ rm\ \'\(docker\ ps\ -a\ -q\)\' --description alias\ dk-stop\ docker\ stop\ \'\(docker\ ps\ -a\ -q\)\'\;\ docker\ rm\ \'\(docker\ ps\ -a\ -q\)\'
  docker stop '(docker ps -a -q)'; docker rm '(docker ps -a -q)' $argv;
end
