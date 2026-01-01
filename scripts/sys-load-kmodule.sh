#!/bin/sh

while getopts m:f: opt; do
  case $opt in
    m)
      modules=$OPTARG
      ;;
    f)
      filename=$OPTARG
      ;;
    *)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

load_module() {
  if ! lsmod | grep -q "$1"; then
    sudo modprobe "$1" && echo "Loaded $1" || echo "Failed to load $1"
  fi
}

IFS=',' 
for module in $modules; do
  load_module $module
done
unset IFS  

if [ -n "$filename" ]; then
  echo "$modules" | tr ',' '\n' | sudo tee /etc/modules-load.d/"$filename" > /dev/null
fi
