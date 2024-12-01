function prompt-gen
    if test (count $argv) -eq 0
        echo "Usage: prompt-gen <file1> <file2> ..."
        return 1
    end
    set output_file .prompt.txt
    echo "# Follow these important rules
Do not include comments in the code
Avoid ending lines with semicolons
Strive for compactness, but maintain readability" > $output_file

    for file in $argv
        if test -e $file
            echo "" >> $output_file
            echo (basename $file) >> $output_file
            set extension (string match -r '\.\w+$' $file | string sub -s 2)
            echo '```'(string lower $extension) >> $output_file
            cat $file >> $output_file
            echo '```' >> $output_file
            echo "" >> $output_file
        else
            echo "File not found: $file"
        end
    end
    echo "Combined file created: $output_file"
end
