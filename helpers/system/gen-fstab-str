#!/bin/bash

# Function to parse named options
parse_named_options() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --dev)
        device="$2"
        shift
        shift
        ;;
      -m|--mount)
        mount_point="$2"
        shift
        shift
        ;;
      -t|--type)
        filesystem_type="$2"
        shift
        shift
        ;;
      *)
        echo "Unknown argument: $key"
        exit 1
        ;;
    esac
  done
}

# Function to parse positional arguments
parse_positional_arguments() {
  device="$1"
  mount_point="$2"
  filesystem_type="$3"
}

# Check if at least three arguments are provided
if [ $# -lt 3 ]; then
  echo "Usage: $0 [--dev <device_path>] [-m <mount_point>] [-t <filesystem_type>]"
  echo "Or:    $0 <device_path> <mount_point> <filesystem_type>"
  exit 1
fi

# Check if the first argument starts with '-' (indicating named options)
if [[ $1 == -* ]]; then
  parse_named_options "$@"
else
  parse_positional_arguments "$@"
fi

# Check if any required variables are empty
if [ -z "$device" ] || [ -z "$mount_point" ] || [ -z "$filesystem_type" ]; then
  echo "Error: Missing required arguments."
  exit 1
fi

# Get the details of the device
output=$(lsblk $device -o UUID,NAME,SIZE --noheadings)

# Extract UUID, NAME, and SIZE
uuid=$(echo $output | awk '{print $1}')
name=$(echo $output | awk '{print $2}')
size=$(echo $output | awk '{print $3}')

# Print the formatted output
echo "UUID=$uuid $mount_point/$name $size $filesystem_type defaults 0 0"
