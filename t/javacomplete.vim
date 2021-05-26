source t/helpers/setup.vim

describe '<Plug>(javacomplete)'
	before
		setfiletype java

		call javacomplete#SetLogLevel(0)
		let g:java_classpath = 't/fixtures/'
		set omnifunc=javacomplete#Complete
	end

	after
		close!
	end

	it 'var.ab| : subset of members of var beginning with ab'
		new
		call PasteSourceCode('SubsetOfVar')
		write! SubsetOfVar.java

		normal 7G$
		Expect CharAtCursor() == 'F'

		normal a

		Expect trim(getline('.')) == 'customer.getFirstName('
	end

	it 'ab| : list of all maybes'
		new
		call PasteSourceCode('ListAllMaybes')
		write! VariableName.java

		normal 7G$
		Expect CharAtCursor() == 'u'

		normal a

		Expect trim(getline('.')) == 'customer'
	end

end

