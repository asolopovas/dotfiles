# Defined in /tmp/fish.0b9gCo/fish_user_key_bindings.fish @ line 20
function bind_bang
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end
