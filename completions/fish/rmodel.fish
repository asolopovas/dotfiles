# Fish completion for rmodel using Typer's completion system
complete -c rmodel -f
complete -c rmodel -l help -d 'Show help message'
complete -c rmodel -l version -d 'Show version information'
complete -c rmodel -s k -l kill -d 'Kill daemon for MODEL or all' -xa 'all whisper fairface-age simple-sentiment blip-image-captioning'
complete -c rmodel -l install-completion -d 'Install completion for the current shell'
complete -c rmodel -l show-completion -d 'Show completion for the current shell'
# Subcommands from Typer app
complete -c rmodel -n '__fish_use_subcommand' -xa 'list' -d 'List all available models'
complete -c rmodel -n '__fish_use_subcommand' -xa 'info' -d 'Show system information or model details'
complete -c rmodel -n '__fish_use_subcommand' -xa 'cache' -d 'Cache management commands'
complete -c rmodel -n '__fish_use_subcommand' -xa 'whisper' -d 'Whisper transcription model'
complete -c rmodel -n '__fish_use_subcommand' -xa 'fairface-age' -d 'FairFace age detection model'
complete -c rmodel -n '__fish_use_subcommand' -xa 'simple-sentiment' -d 'Simple sentiment analysis model'
complete -c rmodel -n '__fish_use_subcommand' -xa 'blip-image-captioning' -d 'Image captioning using BLIP model'
