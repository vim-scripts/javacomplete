" Vim completion script	- hit 80% complete tasks
" Version:	0.71
" Language:	Java
" Maintainer:	cheng fang <fangread@yahoo.com.cn>
" Last Change:	2007-01-28
" Changelog:
" 1. v0.50 2007-01-21	Use java and Reflection.class directly.
" 2. v0.60 2007-01-25	Design TClassInfo, etc.
" 3. v0.70 2007-01-27	Complete the reflection part.
" 4. v0.71 2007-01-28	Add Basic support for class in current folder.

" Installation:								{{{1
" 1. Place javacomplete.vim in the autoload directory, e.g.  $VIM/vimfiles/autoload
" 2. Place classes of Reflection into classpath.
"    You also can use jdk1.4 (and above) to compile Reflection.java by yourself.
"    Currently, You need a jre of v1.4. I will make it portable to be compiled jdk1.2.
" 3. Add more jar or class directories to classpath, if you like. e.g.
"	let g:java_classpath = '.;C:\java\lib\servlet.jar;C:\java\classes;C:\webapp\WEB-INF\lib\foo.jar;C:\webapp\WEB-INF\classes'
"    or in unix/linux
"	let g:java_classpath = '.:~/java/lib/servlet.jar:~/java/classes:~/java/webapp/WEB-INF/lib/foo.jar:~/java/webapp/WEB-INF/classes'
"
" Usage:								{{{1
" 1. Open a java file or a jsp file, press <C-X><C-O> in some places.
"
"    
"
" Requirements:								{{{1
" 1. input context:	('|' indicates cursor position)
"   (1). after '.', to get the member list of a class or a package.
"	- package.| 	sub packages and classes in this package
"	- var.|		members of var
"	- method().| 	members of method() result
"	- this.|	members of the current class
"	- super.|	members of the super class
"	- array[i].|	members of the element in the array
"	- array.|	members of an Array object
"
"   (2). after '(', or between '(' and ')', to get the list of methods matched with parameter information. It's better to provide javadoc.
"	- method(|) 	methods matched
"	- new Class(|) 	constructors matched
"
"   (3). after an incomplette word, to provide a candidates matched for selection.
"	- var.ab| 	subset of members of var begining with 'ab'
"	- ab		list of all maybes
"
"   (4). import statement
"	- " import 	java.util.|"
"	- " import 	java.ut|"
"	- " import 	ja|"
"	- " import 	java.lang.ThreadLocal.|"
"	Many products do not implements case 4, including eclipse, jcreator.
"
"   The above are in simple expression.
"   (5). after compound expression:
"	- compound_expr.var.|
"	- compound_expr.method().|
"	- compound_expr.method(|)
"	- compound_expr.var.ab|

" Implementation note:							{{{1
" Read class information in the following order:
"   1). A class defined in current editing source file.
"   2). A public class in one of java files in current directory.
"   3). A runtime loadable class avaible in classpath
"   4). A class in one of java files in current directory(can be a nonpublic class).
" For case 1),2),4), it is necessary to parse java file to read class information.
" We read it from tags file.
" For case 3), try to use reflection mechanism. We should set classpath first.
"	
" 1. Just use the 'java' program to obtain most information:
"    - Use reflection mechanism to obtain class information, including fields, methods and constructors.
"    - To obtain package information. Not use other utilities (unzip, grep) for inefficiency and availability.
"    - Use javadoc to generate document.
"    I write the 'Reflection' class to do.
"
" 2. Most java syntax recognition are done with vim script.
"    - To get the whole statement before cursor.
"    - To get the declaration statement of a variable or a class.
"    - To generate the imported packages and fqns.
"    - To parse recursively compound expression.
"    - To recognise whether an expression is a fqn.
"
" 3. Obtain Class information from tags file(s).
"
" 4. Builtin objects in JSP can be recognized. 
" You can press <C-X><C-O> after "session.|"
"									}}}

" TODO: 
"  1. Solve name conflict, same name class in two packages or same name variable in two scopes.
"  2. Improve class recognition in current folder, including nested class.
"  3. javadoc

" constants							{{{1
" context type
let s:CONTEXT_AFTER_DOT		= 1
let s:CONTEXT_METHOD_PARAM	= 2
let s:CONTEXT_IMPORT		= 3
let s:CONTEXT_INCOMPLETE_WORD	= 4
let s:CONTEXT_OTHER 		= 0

let s:ARRAY_CLASS_INFO = [
\	{'kind': 'f', 'word': 'equals(', 'abbr' : 'equals()', 'menu' : 'boolean equals(Object)', }, 
\	{'kind': 'f', 'word': 'getClass(', 'abbr' : 'getClass()', 'menu' : 'final native Class Object.getClass()', }, 
\	{'kind': 'f', 'word': 'hashCode(', 'abbr' : 'hashCode()', 'menu' : 'int hashCode()', }, 
\	{'kind': 'm', 'word': 'length'}, 
\	{'kind': 'f', 'word': 'notify(', 'abbr' : 'notify()', 'menu' : 'final native void Object.notify()', }, 
\	{'kind': 'f', 'word': 'notifyAll(', 'abbr' : 'notifyAll()', 'menu' : 'final native void Object.notifyAll()', }, 
\	{'kind': 'f', 'word': 'toString(', 'abbr' : 'toString()', 'menu' : 'String toString()', }, 
\	{'kind': 'f', 'word': 'wait(', 'abbr' : 'wait()', 'menu' : 'final void Object.wait() throws InterruptedException', }, 
\	{'kind': 'f', 'word': 'wait(', 'abbr' : 'wait()', 'menu' : 'final native void Object.wait(long) throws InterruptedException', }, 
\	{'kind': 'f', 'word': 'wait(', 'abbr' : 'wait()', 'menu' : 'final void Object.wait(long,int) throws InterruptedException', }]

let s:JSP_BUILTIN_OBJECTS = {'session':	'javax.servlet.http.HttpSession',
\	'request':	'javax.servlet.http.HttpServletRequest',
\	'response':	'javax.servlet.http.HttpServletResponse',
\	'pageContext':	'javax.servlet.jsp.PageContext', 
\	'application':	'javax.servlet.ServletContext',
\	'config':	'javax.servlet.ServletConfig',
\	'out':		'javax.servlet.jsp.JspWriter',
\	'page':		'javax.servlet.jsp.HttpJspPage', }

let s:CLASS_ABBRS = {'Object': 'java.lang.Object',
\	'Class': 'java.lang.Class', 
\	'System': 'java.lang.System', 
\	'String': 'java.lang.String', 
\	'StringBuffer': 'java.lang.StringBuffer', 
\	}
let s:INVALID_FQNS = ['java', 'java.lang', 'com', 'org', 'javax']

" local variables						{{{1
let b:context_type = s:CONTEXT_OTHER
let b:statement = ''			" statement before cursor
let b:dotexpr = ''			" expression before '.'
let b:incomplete = ''			" incomplete word, three types: a. dotexpr.method(|) b. new classname(|) c. dotexpr.ab|
let b:errormsg = ''
let b:packages = []			
let b:fqns = []

" script variables						{{{1
"TFieldInfo   = {
"		'n': '',	 	" name
"		'm': '',	 	" modifier: public, private, protected, package
"		't': ''			" type name
"		}
"TMethodInfo  = {
"		'n': '', 		" name
"		'm': '',		" modifier
"		'r': '', 		" return type name
"		'p': [classname, ], 	" parameterTypes: the type name list of parameter
"		'd': ''			" description
"		}
"TCtorInfo    = {
"		'n': '', 		" name
"		'm': '',		" modifier
"		'p': [classname, ], 	" parameterTypes
"		'd': ''			" description
"		}
"TClassInfo   = {
"		'ctors': [TCtorInfo, ...],
"		'fields': [TFieldInfo,...],
"		'methods': [TMethodInfo, ...],
"		}
"TPackageInfo = ['subpackage', 'class', ......]
let s:cache = {}		" class FQN -> member list, e.g. {'java.lang.StringBuffer': classinfo, 'java.util': packageinfo, }


" Complete function							{{{1
function! javacomplete#Complete(findstart, base)
  if a:findstart
    let b:performance = ''
    let b:et_whole = reltime()
    let start = col('.') - 1

    " reset enviroment
    let b:dotexpr = ''
    let b:incomplete = ''
    let b:context_type = s:CONTEXT_OTHER

    let statement = s:GetStatement()
    call s:WatchVariant('statement: "' . statement . '"')
    if statement =~ '^\s*$'
      return -1
    endif

    " import statement
    if statement =~ '^\s*import\s\+'
      let b:context_type = s:CONTEXT_IMPORT
      let b:dotexpr = substitute(statement, '^\s*import\s\+', '', '')

      let idx_dot = strridx(b:dotexpr, '.')
      " case: " import 	java.util.|"
      if idx_dot == strlen(b:dotexpr)-1
	let b:dotexpr = strpart(b:dotexpr, 0, strlen(b:dotexpr)-1)
      " case: " import 	java.ut|"
      elseif idx_dot != -1
	let b:incomplete = strpart(b:dotexpr, idx_dot+1)
	let b:dotexpr = strpart(b:dotexpr, 0, idx_dot)
      " case: " import 	ja|"
      "else
      endif
      return start - strlen(b:incomplete)
    endif

    let b:dotexpr = statement
    call s:GenerateImports()

    " method parameters, treat methodname or 'new' as an incomplete word
    let len = strlen(statement)
    if statement =~ '(\s*$'
      let b:context_type = s:CONTEXT_METHOD_PARAM
      let pos = strridx(statement, '(')
      let statement = strpart(statement, 0, pos)
      let start = start - (len - pos)

      " skip a word
      let pos = pos - 1
      while (pos != 0 && statement[pos] =~ '\w')
	let pos = pos - 1
      endwhile
      let b:incomplete = statement
      if pos > 0
	" test case: expr.method(|)
	if statement[pos] == '.'
	  let b:dotexpr = strpart(statement, 0, pos+1)
	  let b:incomplete = strpart(statement, pos+1)
	endif

	" test special case: new ClassName(|)
	if statement[pos] == ' ' && pos-3 >= 0
	  let b:incomplete = strpart(statement, pos-3, 3)
	  if b:incomplete == 'new'
	    let b:dotexpr = strpart(statement, pos+1)
	    " excluding 'new this()' or 'new super()'
	    if b:dotexpr == 'this' || b:dotexpr == 'super'
	      let b:dotexpr = ''
	      let b:incomplete = ''
	      return -1
	    endif
	    return start - strlen(b:dotexpr)
	  endif
	else
	  let idx_begin = match(statement, '\s\+new\s\+[a-zA-Z0-9_. \t\r\n]\+')
	  if idx_begin > -1
	    let idx_end = matchend(statement, '\s\+new\s\+[a-zA-Z0-9_. \t\r\n]\+')
	    if idx_end >= pos
	      let b:dotexpr = substitute(strpart(statement, idx_begin, idx_end-idx_begin), '\s\+new\s\+\([a-zA-Z0-9_. \t\r\n\n]\+\)', '\1', '')
	      let b:dotexpr = substitute(b:dotexpr, '[ \t\r\n]', '', 'g')
	      let b:incomplete = 'new'
	      " excluding 'new this()' or 'new super()'
	      if b:dotexpr == 'this' || b:dotexpr == 'super'
		let b:dotexpr = ''
		let b:incomplete = ''
		return -1
	      endif
	      return start - strlen(b:dotexpr)
	    endif
	  endif
	endif
      end
      "let b:dotexpr = s:ExtractCleanExpr(b:dotexpr)
      return start - strlen(b:incomplete)
    endif

    " TODO: To extract a clean expr by calling Parse()?
    "let b:dotexpr = s:ExtractCleanExpr(b:dotexpr)

    let end_char = statement[strlen(statement)-1]
    if end_char == '.'
      let b:context_type = s:CONTEXT_AFTER_DOT

    " an incomplete word, identifier, or method
    elseif end_char =~ '\w'
      let b:context_type = s:CONTEXT_INCOMPLETE_WORD
      let idx_dot = strridx(b:dotexpr, '.')
      if idx_dot != -1
	let b:incomplete = strpart(b:dotexpr, idx_dot+1)
	let b:dotexpr = strpart(b:dotexpr, 0, idx_dot+1)
      endif

    else
      let b:context_type = s:CONTEXT_OTHER
      echoerr 'Cannot correctly parse ' . statement . ''
    end

    return start - strlen(b:incomplete)
  endif


  call s:WatchVariant('b:context_type: "' . b:context_type . '"  b:incomplete: "' . b:incomplete . '"  b:dotexpr: "' . b:dotexpr . '"')
  if b:dotexpr =~ '^\s*$' && b:incomplete =~ '^\s*$'
    return []
  endif


  let result = []
  if b:context_type == s:CONTEXT_AFTER_DOT || b:context_type == s:CONTEXT_INCOMPLETE_WORD
    let result = s:CompleteAfterDot()
  elseif b:context_type == s:CONTEXT_IMPORT
    let result = s:GetPackageContent(b:dotexpr)
  elseif b:context_type == s:CONTEXT_METHOD_PARAM
    if b:incomplete == 'new'
      let fqn = s:GetFQN(b:dotexpr)
      if (fqn != '')
	let result = s:GetConstructorList(fqn, b:dotexpr)
      endif
    else
      let result = s:CompleteAfterDot()
    endif
  endif


  if len(result) > 0
    " filter according to b:incomplete
    if len(b:incomplete) > 0 && b:incomplete != 'new'
      let result = filter(result, "type(v:val) == type('') ? v:val =~ '^" . b:incomplete . "' : v:val['word'] =~ '^" . b:incomplete . "'")
    endif

    let b:performance = reltimestr(reltime(b:et_whole)) . "s" . b:performance
    return result
  endif

  if strlen(b:errormsg) > 0
    echoerr 'omni-completion error: ' . b:errormsg
  endif
endfunction

" Precondition:	b:dotexpr must end with '.'
" return empty string if no matches
function! s:CompleteAfterDot()
  " Firstly, remove the last '.' in the b:dotexpr 
  let expr = strpart(b:dotexpr, 0, strlen(b:dotexpr)-1)
  let expr = s:Trim(expr)	" trim head and tail spaces

  " Simple expression without dot.
  " Assumes in the following order:
  "	1) "str.|"	- Simple variable declared in the file
  "	2) "String.|" 	- Type (whose definition is imported)
  "	3) "java.|"   	- First part of the package name
  if (stridx(expr, '.') == -1)
    " 1. assume it as variable 
    let class = s:GetDeclaredClassName(expr)
    call s:Info('S1. "str.|"  classname: "' . class . '"')
    if (class != '')
      " array
      if (class[strlen(class)-1] == ']')
	return s:ARRAY_CLASS_INFO
      " class in current project, including current file or files in current folder
      elseif globpath(expand('%:p:h'), class . '.java') != ''
	return s:DoGetClassInfoFromTags(class)
      else
	let fqn = s:GetFQN(class)
	if fqn != ''
	  return s:GetMemberList(fqn)
	endif
      endif
    endif

    " 2. assume identifier as an TYPE name. 
    " It is right if there is a fully qualified name matched. Then return member list
    call s:Info('S2. "String.|"')
    let fqn = s:GetFQN(expr)
    if (fqn != '')
      return s:GetStaticMemberList(fqn)
    endif

    " 3. it may be the first part of a package name.
    call s:Info('S3. "java.|"')
    return s:GetPackageContent(expr)

  "
  " an dot separated expression 
  " Assumes in the following order:
  "	1) "java.lang.String.|"	- A fully qualified class name
  "	
  "	2) "obj.var.|"		- An object's field
  "	3) "obj.getStr().|"	- An method's result
  "							  
  "	4) "System.in.|"	- A static field of a type (System)
  "	5) "System.getenv().|"	- Return value of static method getEnv()
  "	
  "	6) "java.lang.Sytem.in.|"	- Same as 4 and type given in FQN
  "	7) "java.lang.System.getenv().|"- Same as 5 and type given in FQN
  "	
  "	8) "java.lang.|"		- Part or Full package name
  "
  else
    " prepend 'this.' if it is a local method. e.g.
    " 	getFoo() --> 	this.getFoo()
    if (stridx(expr, '.') == -1 && expr[strlen(expr)-1] == ')')
      let expr = 'this.' . expr
    endif

    " 1.
    call s:Info('C1. "java.lang.String.|"')
    let fqn = s:GetFQN(expr)
    if (fqn != '')
      return s:GetStaticMemberList(fqn)
    endif

    let idx_dot = stridx(expr, '.')
    let first = strpart(expr, 0, idx_dot)

    " 2|3. 
    call s:Info('C2|3. "obj.var.|", or "sb.append().|"')
    let classname = s:GetDeclaredClassName(first)
    if (classname != '')
      let fqn = s:GetFQN(classname)
      if (fqn != '')
	let fqn = s:GetNextSubexprType(fqn, strpart(expr, idx_dot+1))
	if (fqn != '')
	  return s:GetMemberList(fqn)
	endif
      endif
    endif

    " 4|5.
    call s:Info('C4|5. "System.in.|", or "System.getenv().|"')
    let fqn = s:GetFQN(first)
    if (fqn != '')
      let fqn = s:GetNextSubexprType(fqn, strpart(expr, idx_dot+1))
      if (fqn != '')
	return s:GetMemberList(fqn)
      endif
    endif

    " 6|7.
    call s:Info('C6|7. "java.lang.System.in.|", or "java.lang.System.getenv().|"')
    let idx_dot_prev = 0
    let idx_dot_next = idx_dot
    while idx_dot_next != -1 && fqn == ''
      let idx_dot_prev = idx_dot_next
      let subexpr = strpart(expr, 0, idx_dot_next)
      let subexpr = s:Trim(subexpr)
      let subexpr = substitute(subexpr, '\s*\.\s*', '.', 'g')
      let fqn = s:GetFQN(subexpr)
      let idx_dot_next = stridx(expr, '.', idx_dot_prev+1)
      call s:Trace('fqn: "' . fqn . '"' . '  idx_dot_next: ' . idx_dot_next . ' subexpr: ' . subexpr)
    endwhile
    if fqn != ''
      let fqn = s:GetNextSubexprType(fqn, strpart(expr, idx_dot_prev+1))
      if (fqn != '')
	return s:GetMemberList(fqn)
      endif
    endif

    " 8. 
    return s:GetPackageContent(expr)
  endif

  return ''		"return s:GetMemberList('java.lang.Object')
endfunction


" scanning and parsing							{{{1

" Search back from the cursor position till meeting '{' or ';'.
" '{' means statement start, ';' means end of a previous statement.
" Return: statement before cursor
" Note: It's the base for parsing. And It's OK for most cases.
function! s:GetStatement()
  let lnum_old = line('.')
  let col_old = col('.')

  if search('[{;]', 'bW') == 0
    let lnum = 1
    let col  = 1
  else
    normal w
    let lnum = line('.')
    let col = col('.')
  endif
  "echoerr 'lnum_old ' . lnum_old . ' col_old: ' . col_old . ' lnum: ' . lnum. ' col: ' . col

  " Merge lines into a string, and remove comments, trim spaces
  if lnum == lnum_old
    let statement = substitute(strpart(getline(lnum_old), col-1, col_old-col), '^\s*', '', '')
  else
    let statement = s:Prune(strpart(getline(lnum), col-1))
    let lnum = lnum + 1
    while (lnum < lnum_old)
      let statement = statement . s:Prune(getline(lnum))
      let lnum = lnum + 1
    endwhile
    if lnum == lnum_old
      let statement = statement . substitute(strpart(getline(lnum_old), 0, col_old-1), '^\s*', '', '')
    endif
  end

  silent call cursor(lnum_old, col_old)
  return substitute(statement, '\s\+', ' ', '')
endfunction


" Extract a clean expr, removing some non-necessary characters. 
fu! s:ExtractCleanExpr(expr)
  let cmd = a:expr
  let pos = strlen(cmd)-1 
  let char = cmd[pos]
  while (pos != 0 && cmd[pos] =~ '[a-zA-Z0-9_.)\] \t]')
    if char == ')'
      let pos = s:GetMatchedIndex(cmd, pos)
    elseif char == ']'
      while (char != '[')
	let pos = pos - 1
	let char = cmd[pos]
      endwhile
    endif
    let pos = pos - 1
    let char = cmd[pos]
  endwhile
  if (char !~ '[a-zA-Z0-9_]')
    let cmd = strpart(cmd, pos+1)
  endif
  return cmd
endfu

" Generate the list of imported packages and classes.
" Scan file head to generate package list and fqn list.
" Scan the current line back to file head, ignore comments.
function! s:GenerateImports()
  let b:packages = ['java.lang.']
  let b:fqns = []

  let lnum_old = line('.')
  let col_old = col('.')

  while (1)
    let lnum = search('\<import\>', 'Wb')
    if (lnum == 0)
      break
    endif

    if synIDattr(synID(line("."), col(".") - 1, 1), "name") =~ 'comment'
      continue
    end

    let item = substitute(strpart(getline(lnum), col('.')-1), 'import\s\+\([a-zA-Z0-9.]\+\).*', '\1', '')
    if item[strlen(item)-1] == '.'
      call add(b:packages, item)
    else
      call add(b:fqns, item)
    end
  endwhile

  call cursor(lnum_old, col_old)
endfunction

" Return: The declaration of identifier under the cursor
" Note: The type of a variable must be imported or a fqn.
function! s:GetVariableDeclaration()
  "echoerr 'GetVariableDeclaration'
  let lnum_old = line('.')
  let col_old = col('.')

  let declaration = ''
  silent call search('[{;(]', 'b')
  normal w
  let lnum = line('.')
  let col = col('.')
  if (lnum == lnum_old && col == col_old)
    return declaration
  endif

  silent call search(';')
  let lnum_end = line('.')
  while (lnum <= lnum_end)
    let declaration = declaration . getline(lnum)
    let lnum = lnum + 1
  endwhile
  let declaration = strpart(declaration, col-1)
  let declaration = substitute(declaration, '\.[ \t]\+', '.', 'g')

  silent call cursor(lnum_old, col_old)
  return declaration
endfunction

" regexp samples:
" echo search('\(\(public\|protected|private\)[ \t\n\r]\+\)\?\(\(static\)[ \t\n\r]\+\)\?\(\<class\>\|\<interface\>\)[ \t\n\r]\+HelloWorld[^a-zA-Z0-9_$]', 'W')
" echo substitute(getline('.'), '.*\(\(public\|protected\|private\)[ \t\n\r]\+\)\?\(\(static\)[ \t\n\r]\+\)\?\(\<class\>\|\<interface\>\)\s\+\([a-zA-Z0-9_]\+\)\s\+\(\(implements\|extends\)\s\+\([^{]\+\)\)\?\s*{.*', '["\1", "\2", "\3", "\4", "\5", "\6", "\8", "\9"]', '')
" code sample: 
function! s:GetClassDeclarationOf(type)
  call cursor(0, 0)
  let decl = []

  let lnum = search('\(\<class\>\|\<interface\>\)[ \t\n\r]\+' . a:type . '[^a-zA-Z0-9_$]', 'W')
  if (lnum != 0)
    " TODO: search back for optional 'public | private' and 'static'
    " join lines till to '{'
    let lnum_end = search('{')
    if (lnum_end != 0)
      let str = ''
      while (lnum <= lnum_end)
	let str = str . getline(lnum)
	let lnum = lnum + 1
      endwhile

      exe "let decl = " . substitute(str, '.*\(\<class\>\|\<interface\>\)\s\+\([a-zA-Z0-9_]\+\)\s\+\(\(implements\|extends\)\s\+\([^{]\+\)\)\?\s*{.*', '["\1", "\2", "\4", "\5"]', '')
    endif
  endif

  return decl
endfunction

" return list
"    0	class | interface
"    1	name
"   [2	implements | extends ]
"   [3	parent list ]
function! s:GetThisClassDeclaration()
  "echoerr 'GetThisClassDeclaration'
  let lnum_old = line('.')
  let col_old = col('.')

  call search('\(\<class\>\|\<interface\>\)', 'b')

  " join lines till to '{'
  let str = ''
  let lnum = line('.')
  call search('{')
  let lnum_end = line('.')
  while (lnum <= lnum_end)
    let str = str . getline(lnum)
    let lnum = lnum + 1
  endwhile

  exe "let list = " . substitute(getline('.'), '.*\(\<class\>\|\<interface\>\)\s\+\([a-zA-Z0-9_]\+\)\s\+\(\(implements\|extends\)\s\+\([^{]\+\)\)\?\s*{.*', '["\1", "\2", "\4", "\5"]', '')

  call cursor(lnum_old, col_old)
  return list
endfunction

" Parser.GetType() in insenvim
function! s:GetDeclaredClassName(var)
  let var = s:Trim(a:var)

  call s:Trace('GetDeclaredClassName for "' . var . '"')
  if (var == 'this')
    let declaration = s:GetThisClassDeclaration()
    return declaration[1]
  elseif (var == 'super')
    let declaration = s:GetThisClassDeclaration()
  endif


  " Special handling for builtin objects in JSP
  if &ft == 'jsp'
    if len(s:JSP_BUILTIN_OBJECTS[a:var]) > 0
      return s:JSP_BUILTIN_OBJECTS[a:var]
    endif
  endif


  " If the variable ends with ']', 
  let isArrayElement = 0
  if var[strlen(var)-1] == ']'
    let var = strpart(var, 0, stridx(var, '['))
    let isArrayElement = 1
  endif

  let ic = &ignorecase
  set noignorecase

  " firstly, search local variable
  if (searchdecl(var, 0, 1) == 0)
    " code sample:
    " String tmp; java.
    " 	lang.  String str, value;
    " for (int i = 0, j = 0; i < 10; i++) {
    "   j = 0;
    " }
    let declaration = s:GetVariableDeclaration()
    let class = substitute(declaration, '\s*\([a-zA-Z0-9_.]\+\)\(\[\]\)\?\s\+.*', '\1\2', '')
    if isArrayElement
      let class = strpart(class, 0, stridx(class, '['))
    endif
    call s:Trace('class: "' . class . '" declaration: "' . declaration . '"')
    return class

  " secondly, search class field
  " TODO:
  elseif (searchdecl(var, 0) == 0)
  endif

  let ignorecase = ic
  call s:Trace('GetDeclaredClassName: cannot find')
  return ''
endfunction

" Precondition:	fqn must be valid
" Return:	type of next subexpr
" NOTE:	ListerFactory.getTypeNameInMultiDotted() in insenvim
function! s:GetNextSubexprType(fqn, expr)
  let expr = substitute(a:expr, '^\s*\.', '', '')
  let expr = substitute(expr, '\s*$', '', '')

  " try to split expr into two parts, if '(' or '.' exists
  " e.g.  expr			   next_subexpr  tail_expr	
  " 	sb.append()		-> sb		+ append()
  " 	append("str").appned()	-> append	+ append()
  let idx = match(expr, '[()\.]')
  let next_subexpr = expr
  let tail_expr = ''
  let isMethod = 0
  if idx > -1
    let next_subexpr = strpart(expr, 0, idx)
    if expr[idx] == '('
      let isMethod = 1
      let tail_expr = strpart(expr, s:GetMatchedIndexEx(expr, idx, '(', ')')+2)
    else
      let tail_expr = strpart(expr, idx)
    endif
  endif
  call s:WatchVariant('expr "' . expr . '" next_subexpr: "' . next_subexpr . '" isMethod: "' . isMethod . '" tail_expr: "' . tail_expr . '"')


  " search in the classinfo
  let classinfo = s:DoGetClassInfo(a:fqn, '-C')
  if classinfo == {}
    return ''
  endif

  let resulttype = ''
  if isMethod
    for method in classinfo['methods']
      if method['n'] == next_subexpr
	" get the class name of return type 
	let resulttype = method['r']
      endif
    endfor
  else
    for field in classinfo['fields']
      if field['n'] == next_subexpr
	" get the class name of field 
	let resulttype = field['t']
      endif
    endfor
  endif
  call s:WatchVariant('resulttype: ' . resulttype)


  if strlen(tail_expr) == 0 || resulttype == ''
    return resulttype
  else
    return s:GetNextSubexprType(resulttype, tail_expr)
  endif
endfunction

" java							{{{1
" NOTE: See CheckFQN, GetFQN in insenvim
function! s:GetFQN(name)
  " Has user-defined abbreviations?
  if has_key(s:CLASS_ABBRS, a:name)
    return s:CLASS_ABBRS[a:name]
  endif

  call s:Debug('GetFQN: to check case 1: is there ''.'' in "' . a:name . '"?')
  " Assume a:name as FQN if there is a '.' in it
  if (stridx(a:name, '.') != -1)
    if (s:IsFQN(a:name))
      return a:name
    else
      return ''
    endif
  endif

  " quick check
  for invalid in s:INVALID_FQNS
    if a:name == invalid
      return ''
    endif
  endfor

  call s:Debug('GetFQN: to check case 2: is one of b:fqns?')
  " Search for a:name in b:fqns
  " TODO: solve name conflict
  for fqn in b:fqns
    if (a:name == strpart(fqn, strridx(fqn, '.')+1))
      return fqn
    endif
  endfor

  call s:Debug('GetFQN: to check case 3: under each b:packages?')
  " Search for a:name under each b:packages
  " TODO: solve name conflict
  for package in b:packages
    let fqn = package . a:name
    if (s:IsFQN(fqn))
      return fqn
    endif
  endfor

  call s:Debug('GetFQN: is not a fqn')
  return ''
  " assumes it as a builtin class
  "return 'java.lang.' . a:name
endfunction

" Is name a full qualified class name?
" see Parser.IsFQN() in insenvim
function! s:IsFQN(name)
  " An expr cannot be fqn if it contains non-word or non-space char
  if match(a:name, '[^a-zA-Z0-9_. \t\r\n]') > -1
    return 0
  endif

  " quick check
  for invalid in s:INVALID_FQNS
    if a:name == invalid
      return 0
    endif
  endfor

  " already stored in cache
  if has_key(s:cache, a:name)
    return 1
  endif

  for a in values(s:CLASS_ABBRS)
    if a == a:name
      return 1
    endif
  endfor

  let cmd = 'java -classpath ' . s:GetClassPath() . ' Reflection -e "' . a:name . '"'
  let res = s:System(cmd, 's:IsFQN')
  return res =~ '^true'
endfunction


function! s:GetClassPath()
  if exists('b:classpath')
    return b:classpath
  endif
  if exists('g:java_classpath')
    return g:java_classpath
  endif
endfunction

fu! s:IsStatic(modifier)
  return a:modifier[strlen(a:modifier)-4]
endfu

" utilities							{{{1

function! s:InComment(line, col)
  if getline(a:line) =~ '\s*\*'
    return 1
  endif
  let idx = strridx(getline(a:line), '//')
  if idx >= 0 && idx < a:col
    return 1
  endif
  return 0
endfunction

" remove comments, trim spaces
" test case: ' 	sb.append( )	// comment '
function! s:Prune(str)
  let idx = strridx(a:str, '//')
  if idx >= 0
    let str = strpart(a:str, 0, idx)
  else
    let str = a:str
  endif
  let str = substitute(str, '^\s*', '', '')
  let str = substitute(str, '\s*$', '', '')
  return str
endfunction

fu! s:Trim(str)
  let str = substitute(a:str, '^\s*', '', '')
  return substitute(str, '\s*$', '', '')
endfu

" TODO: take match pair used in string, like 
" 	'create(ao.fox("("), new String).foo().'
function! s:GetMatchedIndexEx(str, idx, one, another)
  let pos = a:idx
  let len = strlen(a:str)
  let char = a:str[pos]
  while (char != a:another)
    if pos >= len
      return -1
    endif
    let pos = pos + 1
    let char = a:str[pos]
    "echo char
    if (char == a:one)
      let pos = s:GetMatchedIndexEx(a:str, pos, a:one, a:another)
    endif
  endwhile
  return pos
endfunction

function! s:GetMatchedIndex(str, idx)
  let str = a:str
  let pos = a:idx
  let char = str[pos]
  while (char != '(')
    let pos = pos - 1
    let char = str[pos]
    if (char == ')')
      let pos = s:GetMatchedIndex(str, pos)
    endif
  endwhile
  return pos
endfunction

" debug utilities							{{{1
fu! s:WatchVariant(variant)
  "echoerr a:variant
endfu

fu! s:Info(msg)
  "echo a:msg
endfu

fu! s:Debug(msg)
  "echo a:msg
endfu

fu! s:Trace(msg)
  "echo a:msg
endfu

fu! s:System(cmd, caller)
  call s:WatchVariant(a:cmd)
  let t = reltime()
  let res = system(a:cmd)
  let b:performance = b:performance . "\n" . reltimestr(reltime(t)) . 's to exec "' . a:cmd . '" by ' . a:caller
  return res
endfu

" functions to get information						{{{1
" implementation							{{{2

" Return:	TClassInfo
" See ClassInfoFactory.getClassInfo() in insenvim.
function! s:DoGetClassInfo(class, option)
  if has_key(s:cache, a:class)
    return s:cache[a:class]
  endif

  " case 1. 
  "let tags = taglist('^' . base)

  " case 2. 

  " case 3. 
  let cmd = 'java -classpath ' . s:GetClassPath() . ' Reflection ' . a:option . ' "' . a:class . '"'
  let res = s:System(cmd, 's:DoGetClassInfo')
  if len(res) == 0
    return {}
  endif
  if res !~ "^{"
    let b:errormsg = res
    return {}
  endif

  exe 'let dict = ' . res
  if type(dict) == type({})
    let s:cache[a:class] = dict
  endif
  return dict
endfunction

" To obtain information of the class in current file or current folder, or
" even in current project.
function! s:DoGetClassInfoFromTags(class)
  let result = []
  let tags = taglist('^' . b:incomplete)
  call filter(tags, "v:val['filename'] == '" . a:class . ".java'")
  call s:Debug('tags: ' . string(tags))
  for tag in tags
    let valid = 1
    let item = {'word': tag['name']}
    let cmd = tag['cmd']
    if has_key(tag, 'kind')
      let kind = tag['kind']
      if kind == 'm' 
	if cmd =~ 'static'
	  let kind = 'M'
	elseif tag['name'] == a:class
	  let kind = '+'
	endif
	let item['abbr'] = item['word'] . '()'
	let item['word'] = item['word'] . '('
      elseif kind == 'f' && cmd =~ 'static'
	let kind = 'F'
      elseif kind == 'c'
	let valid = 0
      endif
      let item['kind'] = kind
    endif
    let cmd = substitute(cmd, '/^\s*', '', '')
    if kind == 'M'
      let cmd = substitute(cmd, '\s\+static\s\+', ' ', '')
    endif
    let item['menu'] = substitute(cmd, '\s*{\?\s*$/$', '', '')
    if valid
      call add(result, item)
    endif
  endfor
  call s:Debug(string(result))
  return result
endfunction

function! s:DoGetPackageList(class, option)
  if has_key(s:cache, a:class)
    return s:cache[a:class]
  endif

  let cmd = 'java -classpath ' . s:GetClassPath() . ' Reflection ' . a:option . ' "' . a:class . '"'
  let res = s:System(cmd, 's:DoGetPackageList')
  if len(res) == 0
    return ''
  endif
  if res !~ "^["
    let b:errormsg = res
    return ''
  endif

  exe 'let list = ' . res
  if type(list) == type([])
    let s:cache[a:class] = list
  endif
  return list
endfunction

fu! s:DoGetFieldList(fields)
  let s = ''
  for field in a:fields
    let s = s . '{'
    let s = s . "'kind':'" . (s:IsStatic(field['m']) ? "F" : "f") . "',"
    let s = s . "'word':'" . field['n'] . "',"
    let s = s . "'menu':'" . field['t'] . "',"
    let s = s . '},'
  endfor
  return s
endfu

fu! s:DoGetMethodList(methods)
  let s = ''
  for method in a:methods
    let s = s . '{'
    let s = s . "'kind':'" . (s:IsStatic(method['m']) ? "M" : "m") . "',"
    let s = s . "'word':'" . method['n'] . "(',"
    let s = s . "'abbr':'" . method['n'] . "()',"
    let s = s . "'menu':'" . method['d'] . "',"
    let s = s . "'dup':'1'"
    let s = s . '},'
  endfor
  return s
endfu

fu! s:DoGetMemberList(class, static)
  let time_a = reltime()
  let s = ''
  let ci = s:DoGetClassInfo(a:class, '-C')
  let fieldlist = []
  let sfieldlist = []
  for field in ci['fields']
    if s:IsStatic(field['m'])
      call add(sfieldlist, field)
    elseif !a:static
      call add(fieldlist, field)
    endif
  endfor

  let methodlist = []
  let smethodlist = []
  for method in ci['methods']
    if s:IsStatic(method['m'])
      call add(smethodlist, method)
    elseif !a:static
      call add(methodlist, method)
    endif
  endfor

  if !a:static
    let s = s . s:DoGetFieldList(fieldlist)
    let s = s . s:DoGetMethodList(methodlist)
  endif
  let s = s . s:DoGetFieldList(sfieldlist)
  let s = s . s:DoGetMethodList(smethodlist)

  let s = '[' . s . ']'
  let s = substitute(s, 'java\.lang\.', '', 'g')
  let s = substitute(s, 'public\s\+', '', 'g')
  let s = substitute(s, 'static\s\+', '', 'g')

  exe 'let list = ' . s
  let b:et3 = reltimestr(reltime(time_a))
  return list
endfu

" interface							{{{2

function! s:GetMemberList(class)
  return s:DoGetMemberList(a:class, 0)
endfunction

fu! s:GetStaticMemberList(class)
  return s:DoGetMemberList(a:class, 1)
endfu

function! s:GetConstructorList(fqn, class)
  let s = '['
  let ci = s:DoGetClassInfo(a:fqn, '-C')
  for ctor in ci['ctors']
    let s = s . '{'
    let s = s . "'word':'" . a:class . "(',"
    let s = s . "'abbr':'" . ctor['d'] . "',"
    let s = s . "'dup':'1'"
    let s = s . '},'
  endfor
  let s = s . ']'

  let s = substitute(s, 'java\.lang\.', '', 'g')
  let s = substitute(s, 'public\s\+', '', 'g')
  exe 'let list = ' . s
  return list
endfunction

function! s:GetPackageContent(package)
  return sort(s:DoGetPackageList(a:package, '-p'))
endfunction
" }}}

" vim:set foldmethod=marker:
