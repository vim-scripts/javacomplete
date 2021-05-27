source t/helpers/setup.vim

describe '<Plug>(Acceptance Tests)'
	before
		setfiletype java

		call javacomplete#SetLogLevel(0)
		let g:java_classpath = 't/fixtures/'
		set omnifunc=javacomplete#Complete
	end

	after
		close!
	end

	describe 'after '.' list members'
		
		" PAY ATTENTION: here we cannot test all values appearing in the
		" minibuffer, so it could be green even if it is showing
		" just one subpackage ('applet'). We need for sure to add other
		" tests on the returned packages
		it 'package.| subpackage'
			new
			call PasteSourceCode('Subpackage')
			write! Subpackage.java

			normal 6G$
			Expect CharAtCursor() == '.'

			normal a

			Expect trim(getline('.')) == 'java.applet'
		end

		it 'package.| class'
			new
			call PasteSourceCode('ClassOfPackage')
			write! ClassOfPackage.java

			normal 6G$
			Expect CharAtCursor() == '.'

			normal a

			Expect trim(getline('.')) == 'java.time.Clock'
		end
	end

	describe 'after an incomplete word'

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

end

