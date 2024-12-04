function prompt-gen
    if test (count $argv) -eq 0
        echo "Usage: prompt-gen <file1> <file2> ..."
        return 1
    end

    set -l output (mktemp)

    echo "# Follow these important rules
Do not include comments in the code
Avoid ending lines with semicolons
Strive for compactness, but maintain readability" > $output

    for file in $argv
        if test -e $file
            echo "" >> $output
            echo (basename $file) >> $output
            set extension (string match -r '\.\w+$' $file | string sub -s 2)
            echo '```'(string lower $extension) >> $output
            cat $file >> $output
            echo '```' >> $output
            echo "" >> $output
        else
            echo "File not found: $file"
        end
    end

    set uname_full (uname -a)
    if string match -q "*WSL2*" $uname_full
        # WSL2: use clip.exe
        cat $output | clip.exe
    else if test (uname) = "Linux"
        # Linux: use xclip
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
