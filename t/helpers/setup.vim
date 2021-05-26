filetype plugin on
runtime! autoload/javacomplete.vim

function! PasteSourceCode(scenario)
	read `='t/fixtures/' . a:scenario . '.java'`
endfunction
