# Defined in - @ line 1
function rs --wraps='rsync -zrvhP ' --description 'alias rs=rsync -zrvhP '
  rsync -zrvhP  $argv;
end
