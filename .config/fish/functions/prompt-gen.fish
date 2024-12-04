function prompt-gen
    if test (count $argv) -eq 0
        echo "Usage: prompt-gen <file1> <file2> ..."
        return 1
    end

    set output ""
    for file in $argv
        if test -e $file
            set base (basename $file)
            set ext (string match -r '\.\w+$' $file | string sub -s 2 | string lower)
            set content (cat $file)
            set output "$output\n$base\n\`\`\`$ext\n$content\n\`\`\`\n"
        else
            echo "File not found: $file"
            return 1
        end
    end

    set uname_full (uname -a)
    if string match -q "*WSL2*" $uname_full
        echo -e $output | clip.exe
    else if test (uname_full) = "Linux"
        if command -v xclip >/dev/null
            echo -e $output | xclip -selection clipboard
        else
            echo "xclip not found. Install it using: sudo apt install xclip"
            return 1
        end
    end
    echo "Output copied to clipboard."
end
