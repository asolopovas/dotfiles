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
end
