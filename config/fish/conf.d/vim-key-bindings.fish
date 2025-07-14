function fish_user_key_bindings
    bind h 'if commandline --paging-mode; commandline --function backward-char; else; commandline --insert h; end'
    bind l 'if commandline --paging-mode; commandline --function forward-char; else; commandline --insert l; end'
    bind k 'if commandline --paging-mode; commandline --function up-line; else; commandline --insert k; end'
    bind j 'if commandline --paging-mode; commandline --function down-line; else; commandline --insert j; end'
end
