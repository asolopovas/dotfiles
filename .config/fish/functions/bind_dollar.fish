# Defined in /tmp/fish.0b9gCo/fish_user_key_bindings.fish @ line 29
function bind_dollar
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end
