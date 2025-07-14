#!/usr/bin/env python3

import json
import sys
import subprocess
import re

def main():
    try:
        input_data = json.load(sys.stdin)
        tool_input = input_data.get('tool_input', {})
        command = tool_input.get('command', '')
        
        if not command:
            return
            
        git_mappings = {
            r'^git\s+status': 'gcloud source repos describe',
            r'^git\s+clone\s+(.+)': r'gcloud source repos clone \1',
            r'^git\s+push': 'gcloud source repos push',
            r'^git\s+pull': 'gcloud source repos pull',
            r'^git\s+log': 'gcloud source repos log',
            r'^git\s+diff': 'gcloud source repos diff',
            r'^git\s+add\s+(.+)': r'gcloud source repos add \1',
            r'^git\s+commit\s+(.+)': r'gcloud source repos commit \1',
            r'^git\s+branch': 'gcloud source repos branches list',
            r'^git\s+checkout\s+(.+)': r'gcloud source repos checkout \1',
            r'^git\s+remote': 'gcloud source repos remote',
            r'^git\s+fetch': 'gcloud source repos fetch',
            r'^git\s+merge\s+(.+)': r'gcloud source repos merge \1',
            r'^git\s+rebase\s+(.+)': r'gcloud source repos rebase \1',
            r'^git\s+tag\s+(.+)': r'gcloud source repos tag \1',
            r'^git\s+stash': 'gcloud source repos stash',
            r'^git\s+reset\s+(.+)': r'gcloud source repos reset \1',
            r'^git\s+show\s+(.+)': r'gcloud source repos show \1',
            r'^git\s+config\s+(.+)': r'gcloud config set \1',
            r'^gh\s+': 'gcloud source repos ',
        }
        
        original_command = command
        new_command = command
        
        for pattern, replacement in git_mappings.items():
            if re.search(pattern, command):
                new_command = re.sub(pattern, replacement, command)
                break
        
        if new_command != original_command:
            print(f"Converting git command to GCP equivalent:", file=sys.stderr)
            print(f"Original: {original_command}", file=sys.stderr)
            print(f"GCP: {new_command}", file=sys.stderr)
            
            modified_input = input_data.copy()
            modified_input['tool_input']['command'] = new_command
            json.dump(modified_input, sys.stdout)
        
    except Exception as e:
        print(f"Error in GCP git hook: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()