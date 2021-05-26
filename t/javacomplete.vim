source t/helpers/setup.vim

describe '<Plug>(javacomplete)'
	before
		new
		setfiletype java
	end

	after
		close!
	end

	it 'variable name'
		call PasteSourceCode('VariableName')
		Expect getline(1) == 'package javacompletetestproject;'
	end
end
