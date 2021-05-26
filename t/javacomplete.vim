source t/helpers/setup.vim

j
describe '<Plug>(javacomplete)'
	before
		new
		setfiletype java

		call javacomplete#SetLogLevel(0)
		let g:java_classpath = 't/fixtures/'
		set omnifunc=javacomplete#Complete
	end

	after
		close!
	end

	it 'variable name'
		new
		call PasteSourceCode('VariableName')
		write! VariableName.java
		Expect getline(1) == 'package javacompletetestproject;'

		normal 9G$
		Expect CharAtCursor() == 'u'

		normal a

		Expect trim(getline('.')) == 'customer'
	end

end

