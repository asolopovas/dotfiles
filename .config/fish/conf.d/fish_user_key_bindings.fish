bind h 'if commandline --paging-mode; commandline --function backward-char; else; commandline --insert h; end'
bind j 'if commandline --paging-mode; commandline --function down-line; else; commandline --insert j; end'
bind k 'if commandline --paging-mode; commandline --function up-line; else; commandline --insert k; end'
bind l 'if commandline --paging-mode; commandline --function forward-char; else; commandline --insert l; end'
