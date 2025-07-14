function prompt-gen
    argparse -x 'r,h' 'r/rules' 'h/help' -- $argv
    or return 1

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: prompt-gen [-r] <file1> <file2> ..."
        echo "  -r: Include coding rules"
        return 1
    end

    set -l output (mktemp)

    if set -q _flag_rules
        echo "# Follow these important rules
Use modern language features
Strive for compactness, but maintain readability" > $output
    end

    for file in $argv
        if test -e $file
            echo "" >> $output
            echo (basename $file) >> $output
            set extension (string match -r '\.\w+$' $file | string sub -s 2)
            echo '```'(string lower $extension) >> $output
            cat $file >> $output
            echo '```' >> $output
        else
            echo "File not found: $file"
        end
    end

    set uname_full (uname -a)
    if string match -q "*WSL2*" $uname_full
        cat $output | clip.exe
    else if test (uname) = "Linux"
        if command -v xclip >/dev/null
            xclip -selection clipboard < $output
        else
            echo "xclip not found. Install it using: sudo apt install xclip"
            rm $output
            return 1
        end
    else
        echo "Unsupported OS: Cannot copy to clipboard."
        rm $output
        return 1
    end

    echo "Output copied to clipboard."
    rm $output
end
