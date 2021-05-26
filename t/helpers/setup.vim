filetype plugin on
runtime! autoload/javacomplete.vim

function! PasteSourceCode(scenario)
	read `='t/fixtures/' . a:scenario . '.java'`
endfunction

function! CharAtCursor()
	return strcharpart(getline('.')[col('.') - 1:], 0, 1)
endfunction
