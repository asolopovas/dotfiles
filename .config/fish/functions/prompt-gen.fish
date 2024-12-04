function prompt-gen
    if test (count $argv) -eq 0
        echo "Usage: prompt-gen <file1> <file2> ..."
        return 1
    end

    set output ""

    for file in $argv
        if test -e $file
            set file_output "
(basename $file)
```(string lower (string match -r '\.\w+$' $file | string sub -s 2))
(cat $file)
```"
            set output "$output$file_output\n"
        else
            echo "File not found: $file"
            return 1
        end
    end

    # Determine OS and copy to clipboard
    echo $output | if test (uname) = "Linux"
        command -v xclip >/dev/null; and xclip -selection clipboard; or echo "xclip not found. Install it using: sudo apt install xclip"
    else
        command -v clip.exe >/dev/null; and clip.exe; or echo "clip.exe not found. Ensure it's in your PATH."
    end

    echo "Output copied to clipboard."
end
