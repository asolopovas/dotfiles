function prompt-gen
    if test (count $argv) -eq 0
        echo "Usage: prompt-gen <file1> <file2> ..."
        return 1
    end

    echo "# Follow these important rules
Do not include comments in the code
Avoid ending lines with semicolons
Strive for compactness, but maintain readability"

    for file in $argv
        if test -e $file
            echo ""
            echo (basename $file)
            set extension (string match -r '\.\w+$' $file | string sub -s 2)
            echo '```'(string lower $extension)
            cat $file
            echo '```'
            echo ""
        else
            echo "File not found: $file"
        end
    end

    set uname_full (uname -a)
    if string match -q "*WSL2*" $uname_full
        # WSL2: use clip.exe
        cat | clip.exe
    else if test (uname) = "Linux"
        # Linux: use xclip
        if command -v xclip >/dev/null
            cat | xclip -selection clipboard
        else
            echo "xclip not found. Install it using: sudo apt install xclip"
            return 1
        end
    else
        echo "Unsupported OS: Cannot copy to clipboard."
        return 1
    end

    echo "Output copied to clipboard."
end
