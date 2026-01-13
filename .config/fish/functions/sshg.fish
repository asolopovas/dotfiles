# Defined in - @ line 1
function sshg --wraps='ssh -i ~/.ssh/google_compute_engine' --description 'alias sshg ssh -i ~/.ssh/google_compute_engine'
  ssh -i ~/.ssh/google_compute_engine $argv;
end
