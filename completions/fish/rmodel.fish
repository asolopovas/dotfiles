# Fish completion for rmodel
# Save this to ~/.config/fish/completions/rmodel.fish
complete -c rmodel -e

# Main options
complete -c rmodel -s h -l help -d 'Show help message'
complete -c rmodel -s k -l kill -d 'Kill daemon for MODEL (or all)' -a 'all whisper fairface_age simple_sentiment'
complete -c rmodel -l version -d 'Show version'

# Subcommands
complete -c rmodel -n '__fish_use_subcommand' -a 'list' -d 'List available models'
complete -c rmodel -n '__fish_use_subcommand' -a 'info' -d 'Show model information'
complete -c rmodel -n '__fish_use_subcommand' -a 'cache' -d 'Cache management'
complete -c rmodel -n '__fish_use_subcommand' -a 'completion' -d 'Generate shell completion'

complete -c rmodel -n '__fish_use_subcommand' -a 'whisper' -d 'Speech transcription using OpenAI Whisper'
complete -c rmodel -n '__fish_use_subcommand' -a 'fairface_age' -d 'Age detection from facial images using FairFace'
complete -c rmodel -n '__fish_use_subcommand' -a 'simple_sentiment' -d 'Simple rule-based sentiment analysis'
complete -c rmodel -n '__fish_use_subcommand' -a 'blip_image_captioning' -d 'Image captioning using BLIP'

# List command options
complete -c rmodel -n '__fish_seen_subcommand_from list' -l detailed -d 'Show detailed information'
complete -c rmodel -n '__fish_seen_subcommand_from list' -s c -l category -d 'Filter by category' -a 'audio vision text'
complete -c rmodel -n '__fish_seen_subcommand_from list' -l json -d 'Output in JSON format'

# Info command options
complete -c rmodel -n '__fish_seen_subcommand_from info' -l json -d 'Output in JSON format'
complete -c rmodel -n '__fish_seen_subcommand_from info' -a 'whisper fairface_age simple_sentiment blip_image_captioning' -d 'Model name'

# Cache command options
complete -c rmodel -n '__fish_seen_subcommand_from cache' -a 'info clear list' -d 'Cache subcommand'

# Completion command options
complete -c rmodel -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish' -d 'Shell type'

# Model command options
complete -c rmodel -n '__fish_seen_subcommand_from whisper' -l device -d 'Device to use' -a 'cpu cuda auto'
complete -c rmodel -n '__fish_seen_subcommand_from whisper' -s d -l daemon -d 'Use daemon mode'
complete -c rmodel -n '__fish_seen_subcommand_from whisper' -s v -l verbose -d 'Verbose output with system info'
complete -c rmodel -n '__fish_seen_subcommand_from whisper' -l json -d 'Output in JSON format'
complete -c rmodel -n '__fish_seen_subcommand_from whisper' -l model-size -d 'Model size (tiny, base, small, medium, large, turbo)' -a 'tiny base small medium large turbo'
complete -c rmodel -n '__fish_seen_subcommand_from fairface_age' -l device -d 'Device to use' -a 'cpu cuda auto'
complete -c rmodel -n '__fish_seen_subcommand_from fairface_age' -s d -l daemon -d 'Use daemon mode'
complete -c rmodel -n '__fish_seen_subcommand_from fairface_age' -s v -l verbose -d 'Verbose output with system info'
complete -c rmodel -n '__fish_seen_subcommand_from fairface_age' -l json -d 'Output in JSON format'
complete -c rmodel -n '__fish_seen_subcommand_from fairface_age' -l model-name -d 'HuggingFace model name for age detection'
complete -c rmodel -n '__fish_seen_subcommand_from simple_sentiment' -l device -d 'Device to use' -a 'cpu cuda auto'
complete -c rmodel -n '__fish_seen_subcommand_from simple_sentiment' -s d -l daemon -d 'Use daemon mode'
complete -c rmodel -n '__fish_seen_subcommand_from simple_sentiment' -s v -l verbose -d 'Verbose output with system info'
complete -c rmodel -n '__fish_seen_subcommand_from simple_sentiment' -l json -d 'Output in JSON format'
complete -c rmodel -n '__fish_seen_subcommand_from simple_sentiment' -l threshold -d 'Sentiment threshold (0.0-1.0)'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l device -d 'Device to use' -a 'cpu cuda auto'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -s d -l daemon -d 'Use daemon mode'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -s v -l verbose -d 'Verbose output with system info'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l json -d 'Output in JSON format'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l model-size -d 'Model size (base, large)' -a 'base large'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l text-prompt -d 'Optional text prompt for conditional captioning (e.g., "a photography of")'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l max-length -d 'Maximum length of generated caption'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l num-beams -d 'Number of beams for beam search'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -l use-fp16 -d 'Use FP16 precision for faster inference on GPU'

# File completion
complete -c rmodel -f

# File completion for model commands
complete -c rmodel -n '__fish_seen_subcommand_from whisper' -f -a '(__fish_complete_path)'
complete -c rmodel -n '__fish_seen_subcommand_from fairface_age' -f -a '(__fish_complete_path)'
complete -c rmodel -n '__fish_seen_subcommand_from simple_sentiment' -f -a '(__fish_complete_path)'
complete -c rmodel -n '__fish_seen_subcommand_from blip_image_captioning' -f -a '(__fish_complete_path)'

# File completion for commands that take file arguments
complete -c rmodel -n '__fish_seen_subcommand_from info' -f -a '(__fish_complete_path)'
complete -c rmodel -n '__fish_seen_subcommand_from completion' -f -a '(__fish_complete_path)'
