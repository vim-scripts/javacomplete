" Vim filetype plugin file - a simple JAVA PARSER mainly for javacomplete.vim
" Language:	Java
" Maintainer:	cheng fang <fangread@yahoo.com.cn>
" Last Changed: 2007-02-13
" Version:	0.51
" Changelog:
" v0.50 2007-02-10	Complete the skeleton.
" v0.51 2007-02-13	Optimize several scan function.

" class definition								{{{1
" 
"TPosition = int	" calculated by b:line, b:col and b:idxes
"
"TType ={
"	'tag': int,	" The tag of this type.
"	}
"
"TTree = 	" Root class for abstract syntax tree nodes.
"	{
"	'tag': int,	" node type
"	'type': var,
"	'pos': int,
"	'value': var,
"	}
"
"TUnit = extend TTree
"	{
"	'package': '',			" package name
"	'imports': [],			" imported fqns
"	'types': [TClassInfo, ...]
"	}
"
"TClassDef = extend TTree
"	{
"	'name': '',				" type name
"	'extendings': [typename, ...]		" one for class, many for interface
"	'implementings': [typename, ...]	" the interfaces implemented by this class
"	'defs': [TMemberInfo, ...],		" all variables, methods, static blocks and inner classes defined in this class
"	'ctors': [TCtorInfo, ...],
"	'fields': [TFieldInfo,...],
"	'methods': [TMethodInfo, ...],
"	'modifier': '',				" flags, class flags
"	'javadoc': '',
"	}
"
"TMemberInfo  = extend TTree
"	{
"	'n': '', 		" name of method, field, or ctor
"	'm': '',		" modifier, or flags
"	't': ''			" type name
"	'r': '', 		" type of method return value
"	'p': [classname, ], 	" parameterTypes: the type name list of parameter
"	'w': [exception, ],	" exceptions thrown by this method
"	'b': '',		" block, statements in the method
"	'd': '',		" description or javadoc
"	}
let s:TTree = {'tag': 0}
let s:EOI = ''

" Keywords								{{{1
let s:keywords = {'+': 'PLUS', '-': 'SUB', '!': 'BANG', '%': 'PERCENT', '^': 'CARET', '&': 'AMP', '*': 'STAR', '|': 'BAR', '~': 'TILDE', '/': 'SLASH', '>': 'GT', '<': 'LT', '?': 'QUES', ':': 'COLON', '=': 'EQ', '++': 'PLUSPLUS', '--': 'SUBSUB', '==': 'EQEQ', '<=': 'LTEQ', '>=': 'GTEQ', '!=': 'BANGEQ', '<<': 'LTLT', '>>': 'GTGT', '>>>': 'GTGTGT', '+=': 'PLUSEQ', '-=': 'SUBEQ', '*=': 'STAREQ', '/=': 'SLASHEQ', '&=': 'AMPEQ', '|=': 'BAREQ', '^=': 'CARETEQ', '%=': 'PERCENTEQ', '<<=': 'LTLTEQ', '>>=': 'GTGTEQ', '>>>=': 'GTGTGTEQ', '||': 'BARBAR', '&&': 'AMPAMP', 'abstract': 'ABSTRACT', 'assert': 'ASSERT', 'boolean': 'BOOLEAN', 'break': 'BREAK', 'byte': 'BYTE', 'case': 'CASE', 'catch': 'CATCH', 'char': 'CHAR', 'class': 'CLASS', 'const': 'CONST', 'continue': 'CONTINUE', 'default': 'DEFAULT', 'do': 'DO', 'double': 'DOUBLE', 'else': 'ELSE', 'extends': 'EXTENDS', 'final': 'FINAL', 'finally': 'FINALLY', 'float': 'FLOAT', 'for': 'FOR', 'goto': 'GOTO', 'if': 'IF', 'implements': 'IMPLEMENTS', 'import': 'IMPORT', 'instanceof': 'INSTANCEOF', 'int': 'INT', 'interface': 'INTERFACE', 'long': 'LONG', 'native': 'NATIVE', 'new': 'NEW', 'package': 'PACKAGE', 'private': 'PRIVATE', 'protected': 'PROTECTED', 'public': 'PUBLIC', 'return': 'RETURN', 'short': 'SHORT', 'static': 'STATIC', 'strictfp': 'STRICTFP', 'super': 'SUPER', 'switch': 'SWITCH', 'synchronized': 'SYNCHRONIZED', 'this': 'THIS', 'throw': 'THROW', 'throws': 'THROWS', 'transient': 'TRANSIENT', 'try': 'TRY', 'void': 'VOID', 'volatile': 'VOLATILE', 'while': 'WHILE', 'true': 'TRUE', 'false': 'FALSE', 'null': 'NULL' }
let s:tokens = {'(': 'LPAREN', ')': 'RPAREN', '[': 'LBRACKET', ']': 'RBRACKET', '{': 'LBRACE', '}': 'RBRACE', '.': 'DOT', ',': 'COMMA', ';': 'SEMI'}
let g:java_modifier_keywords = ['public', 'private', 'protected', 'static', 'final', 'synchronized', 'volatile', 'transient', 'native', 'interface', 'strictfp', 'abstract']

" API								{{{1
fu! Java_InitParser(lines)
" let b:buf = ''		" The input buffer
  let b:buflen = 0		" index of one past last character in buffer
  let b:lines = a:lines		" The input buffer
  let b:idxes = [0]		" Begin index of every lines
  let b:bp = -1			" index of next character to be read
  let b:ch = ''			" The current character.
  let b:line = 0		" The line number position of the current character.
  let b:col = 0			" The column number position of the current character.
" let b:endPos = 0		" The last character position of the token.
" let b:lastEndPos = 0		" The last character position of the previous token.
  let b:errpos = 0		" 
  let b:sbuf = ''		" A character buffer for literals.
  let b:name = ''		" The name of an identifier or token:
  let b:token = 0		" The token, set by s:Java_nextToken().
  let b:docComment = ''

  "let b:cursor_line = 0
  "let b:cursor_col = 0
  "let b:cursor_pos = 0
  let b:cursor_node = {}

  let b:et_perf = ''
  let b:et_nextToken_count = 0

"  let b:buf = join(a:lines, "\r")
"  let b:buflen = strlen(b:buf)
  for line in a:lines
    let b:buflen += strlen(line) + 1
    call add(b:idxes, b:buflen)
  endfor
  call add(b:lines, '')	" avoid 'list index out of range' error from lines[] in java_scanChar
				"  if b:bp >= b:buflen
				"    return s:EOI
				"  endif
endfu

fu! Java_FreeParser(lines)
  unlet b:buf
  unlet b:buflen
  unlet b:lines
  unlet b:idxes
  unlet b:bp
  unlet b:ch
  unlet b:line
  unlet b:col
" unlet b:endPos
" unlet b:lastEndPos
  unlet b:sbuf
  unlet b:name
  unlet b:token
endfu

fu! Java_compilationUnit(...)
  let b:cursor_line = a:0 > 0 ? a:1 : 0
  let b:cursor_pos  = a:0 > 1 ? a:2 : 0

  return s:Java_compilationUnit()
endfu

fu! Java_getPackageName()
  " excerpt from CompilationUnit()
  let result = ''
  call s:Java_scanChar()
  call s:Java_nextToken()
  if b:name == 'package'
    call s:Java_nextToken()
    let result = s:Java_qualident()
    call s:Java_accept('SEMI')
  endif
  return result
endfu

fu! Java_getImports()
  call s:Java_scanChar()
  call s:Java_nextToken()
  if b:name == 'package'
    call s:Java_nextToken()
    call s:Java_qualident()
    call s:Java_accept('SEMI')
  endif

  " import declaration
  let imports = []
  while (b:token == 'IMPORT')
    call add(imports, s:Java_importDeclaration())
  endwhile
  return imports
endfu

" node can be a class/interface, member.
fu! Java_NodeAt(line, col)
  return b:cursor_node
endfu

fu! Java_GetVarDeclaration(line, col, var)
endfu

fu! PrintUnit(unit)
  call s:PrintUnit(a:unit)
endfu

fu! New(propotype)
  return copy(a:propotype)
endfu

fu! Set(obj, field, value)
  if has_key(a:obj, a:field)
    let a:obj[a:field] = a:value
  else
    echoerr a:field . ' not defined in ' . a:obj
  endif
endfu


" Scanner								{{{1

" nextToken								{{{2
fu! s:Java_nextToken()
  let b:et_nextToken_count += 1
  let b:sbuf = ''
  while (1)
    if b:ch =~ '[ \t\r\n]'
      " OAO optimized code: skip spaces
      let idx = match(b:lines[b:line], '[^ \t\r\n]\|$', b:col)
      if idx > -1
        let b:col = idx
        let b:bp = b:idxes[b:line] + b:col
      endif
      call s:Java_scanChar()
      continue

    elseif b:ch =~ '[a-zA-Z$_]'
      " read a identifier
      call s:Java_scanIdent()
      return

    elseif b:ch == '0'
      call s:Java_scanChar()
      " hex
      if b:ch == 'x' || b:ch == 'X'
	call s:Java_scanChar()
	if b:ch =~? '[0-9A-F]'
	  let b:token = 'HEX_NUMBER'
	  call s:Java_scanNumber(16)
	else
	  call s:LexError("invalid.hex.number")
	endif
      " oct
      else
	let b:sbuf .= '0'
	let b:token = 'OCT_NUMBER'
	call s:Java_scanNumber(8)
	return
      endif
      return

    elseif b:ch =~ '[1-9]'
      " read number
      let b:token = 'NUMBER'
      call s:Java_scanNumber(10)
      return

    elseif b:ch == '.'
      call s:Java_scanChar()
      if b:ch =~ '[0-9]'
	call s:Info('meeting ''.'' at ' . b:bp . ' before digit')
	let b:sbuf .= '.'
	call s:Java_scanFractionAndSuffix()
      else
	call s:Info('meeting ''.'' at ' . b:bp . ' before digit')
	let b:token = 'DOT'
      endif
      return

    elseif b:ch =~ '[,;(){}[\]]'
      let b:token = s:tokens[b:ch]
      call s:Java_scanChar()
      return

    elseif b:ch == '/'
      call s:Java_scanComment()
      continue

    elseif b:ch == "'"
      call s:Java_scanSingleQuote()
      return

    elseif b:ch == '"'
      call s:Java_scanDoubleQuote()
      return

    else
      if Java_IsSpecial(b:ch)
	call s:Java_scanOperator()
      elseif b:ch =~ '[a-zA-Z_]'
	call s:Java_scanIdent()
      elseif b:bp >= b:buflen 
	let b:token = 'EOF'
      else
	call s:LexError("illegal.char '" . b:ch . "'")
	call s:Java_scanChar()
      endif
      return
    endif
  endwhile
endfu

" scanChar()								{{{2
" one buf version 
"fu! s:Java_scanChar()
"  let b:bp += 1
"  if b:bp % 256 == 0
"    let b:buf2 = strpart(b:buf, b:bp, 256)
"  endif
"  let b:ch = b:buf2[b:bp % 256]
""  let b:ch = b:buf[b:bp]	" it will be extremely slow when buf is large
"  "call s:Trace( "'" . b:ch . "'" )
"
"  if b:ch == "\r"
"    let b:line += 1
"    let b:col = 0
"  elseif b:ch == "\n"
"    if b:bp == 0 || b:buf[b:bp-1] == "\r"
"      let b:line += 1
"      let b:col = 0
"    endif
"  else
"    let b:col += 1
"  endif
"endfu

" multiple line version 
fu! s:Java_scanChar()
 let b:bp+=1
 if empty(b:lines[b:line]) || b:col == len(b:lines[b:line])
  let b:ch="\r"
  let b:line+=1
  let b:col=0
 else
  let b:ch=b:lines[b:line][b:col]
  let b:col+=1
 endif
endfu

fu! s:Java_CharAt(line, col)
  if empty(b:lines[a:line]) || a:col == len(b:lines[a:line])
    return "\r"
  else
    return b:lines[a:line][a:col]
  endif
endfu

" scanIdent()								{{{2
" OAO optimized code
fu! s:Java_scanIdent()
  let col_old = b:col
  let idx = match(b:lines[b:line], '[^a-zA-Z0-9$_]\|$', b:col)
  if idx != -1
    let b:name = strpart(b:lines[b:line], col_old-1, idx-col_old+1)
    let b:token = has_key(s:keywords, b:name) ? s:keywords[b:name] : 'IDENTIFIER'
    call s:Debug('name: "' . b:name . '" of token type ' . b:token )
    let b:col = idx
    let b:bp = b:idxes[b:line] + b:col
    call s:Java_scanChar()
  endif
endfu
" OLD
fu! s:Java_scanIdent_old()
  " do ... while ()
  let b:sbuf .= b:ch
  call s:Java_scanChar()
  if b:ch !~ '[a-zA-Z0-9$_]' || b:bp >= b:buflen
    let b:name = b:sbuf
    let b:token = has_key(s:keywords, b:name) ? s:keywords[b:name] : 'IDENTIFIER'
    call s:Debug('name: "' . b:name . '" of token type ' . b:token )
    return
  endif

  while (1)
    let b:sbuf .= b:ch
    call s:Java_scanChar()
    if b:ch !~ '[a-zA-Z0-9$_]' || b:bp >= b:buflen
      let b:name = b:sbuf
      let b:token = has_key(s:keywords, b:name) ? s:keywords[b:name] : 'IDENTIFIER'
      call s:Debug('name: "' . b:name . '" of token type ' . b:token )
      break
    endif
  endwhile
endfu

" scanNumber()								{{{2
fu! s:Java_scanNumber(radix)
  if a:radix <= 10
    while b:ch =~ '[0-9]'
      let b:sbuf .= b:ch
      call s:Java_scanChar()
    endwhile
    if b:ch == '.'
      let b:sbuf .= b:ch
      call s:Java_scanChar()
      call s:Java_scanFractionAndSuffix()
    endif
  else
  endif
endfu

fu! s:Java_scanFractionAndSuffix()
  " scan fraction
  while b:ch =~ '[0-9]'
    let b:sbuf .= b:ch
    call s:Java_scanChar()
  endwhile
  " floating point number
  if b:ch == 'e' || b:ch == 'E'
    let b:sbuf .= b:ch
    call s:Java_scanChar()
    if b:ch == '+' || b:ch == '-'
      let b:sbuf .= b:ch
      call s:Java_scanChar()
    endif
    if b:ch =~ '[0-9]'
      while b:ch =~ '[0-9]'
	let b:sbuf .= b:ch
	call s:Java_scanChar()
      endwhile
    endif
  endif
  " Read fractional part and 'd' or 'f' suffix of floating point number.
  if b:ch == 'f' || b:ch == 'F'
    let b:sbuf .= b:ch
    call s:Java_scanChar()
  elseif b:ch == 'd' || b:ch == 'D'
    let b:sbuf .= b:ch
    call s:Java_scanChar()
  endif
endfu

" scanLitChar()								{{{2
fu! s:Java_scanLitChar()
  if b:ch == '\'
    call s:Java_scanChar()
    if b:ch =~ '[0-7]'
      call s:Java_scanChar()

    elseif b:ch == "'" || b:ch =~ '[btnfr"\\]'
      let b:sbuf .= b:ch
      call s:Java_scanChar()

    " unicode escape
    elseif b:ch == 'u'
      while b:ch =~ '[a-zA-Z0-9]'
	call s:Java_scanChar()
      endwhile

    else
      call s:LexError("illegal.esc.char")
    endif
    
  elseif b:bp < b:buflen
    let b:sbuf .= b:ch
    call s:Java_scanChar()
  endif
endfu

" scanOperator()								{{{2
fu! s:Java_scanOperator()
  while (1)
    if !has_key(s:keywords, b:sbuf . b:ch)
      break
    endif

    let b:sbuf .= b:ch
    let b:token = has_key(s:keywords, b:sbuf) ? s:keywords[b:sbuf] : 'IDENTIFIER'
    call s:Debug('sbuf: "' . b:sbuf . '" of token type ' . b:token )
    call s:Java_scanChar()
    if !Java_IsSpecial(b:ch)
      break
    endif
  endwhile
endfu

fu! Java_IsSpecial(ch)
  return a:ch =~ '[!%&*?+-:<=>^|~]' ? 1 : 0
endfu

" scan comment								{{{2
fu! s:Java_scanComment()
  call s:Java_scanChar()
  " line comment
  if b:ch == '/'
    let b:token = 'LINECOMMENT'
    call s:Info('line comment')
    call s:Java_scanChar()
    call s:Java_SkipLineComment()
    return

  " classic comment
  elseif b:ch == '*'
    let b:token = 'BLOCKCOMMENT'
    call s:Info('block comment')
    call s:Java_scanChar()
    let time = reltime()
    " javadoc
    if b:ch == '*'
      let b:docComment = s:Java_scanDocComment()
    " normal comment
    else
      call s:Java_skipComment()
    endif
    let b:et_perf .= "\r" . 'comment ' . reltimestr(reltime(time))

    if b:ch == '/'
      call s:Info('end block comment')
      call s:Java_scanChar()
    else
      call s:LexError('unclosed.comment')
    endif
  endif
endfu

fu! s:Java_SkipLineComment()
  " OAO optimized code
  if b:ch != "\r"
    let b:ch = "\r"
    let b:line += 1
    let b:col = 0
    let b:bp = b:idxes[b:line] + b:col
  endif
  " OLD 
  "while (b:ch != "\r")
  "  call s:Java_scanChar()
  "endwhile
endfu

fu! s:Java_skipComment()
  " OAO optimized code
  let idx = s:Stridx('*/')
  if idx > -1
    call s:Java_scanChar()
  endif
  " OLD 
  "while (b:bp < b:buflen)
  "  if b:ch == '*'
  "    call s:Java_scanChar()
  "    if b:ch == '/'
  "      break
  "    endif
  "  else
  "    call s:Java_scanChar()
  "  endif
  "endwhile
endfu

fu! s:Java_scanDocComment()
  call s:Info('It is javadoc')
  return s:Java_skipComment()

  " skip star '*'
  while (b:bp < b:buflen && b:ch == '*')
    call s:Java_scanChar()
  endwhile

  if b:bp < b:buflen && b:ch == '/'
    return ''
  endif

  let result = ''
  while b:bp < b:buflen
    if b:ch == '*'
      call s:Java_scanChar()
      if b:ch == '/'
	break
      else
	let result .= b:ch
      endif
    else
      call s:Java_scanChar()
      let result .= b:ch
    endif
  endwhile

  return result
endfu

" scan single quote							{{{2
fu! s:Java_scanSingleQuote()
  call s:Java_scanChar()
  if (b:ch == "'")
    call s:LexError("empty.char.lit")
  else
    if (b:ch =~ '[\r\n]')
      call s:LexError("illegal.line.end.in.char.lit")
    endif

    call s:Java_scanLitChar()
    if b:ch == "'"
      call s:Java_scanChar()
      let b:token = 'CHARLITERAL'
    else
      call s:LexError("unclosed.char.lit")
    endif
  endif
endfu

" scan double quote							{{{2
fu! s:Java_scanDoubleQuote()
  call s:Java_scanChar()
  while b:ch != '"' && b:ch !~ '[\r\n]' && b:bp < b:buflen
    " OAO: avoid '\"', '\\\"'
    "let idx = stridx(b:lines[b:line], '"', b:col)
    "if idx > -1
    "  let b:col = idx
    "  let b:bp = b:idxes[b:line] + b:col
    "  call s:Java_scanChar()
    "endif
    " OLD
    call s:Java_scanLitChar()
  endwhile

  if b:ch == '"'
    let b:token = 'STRINGLITERAL'
    call s:Java_scanChar()
  else
    call s:LexError("unclosed.str.lit")
  endif
endfu

" lex errors					{{{2
fu! s:LexError(msg)
  let b:token = 'ERROR'
  let b:errpos = b:bp
  echo '[lex error]:' . (s:GetLine(b:bp)+1) . ': ' . a:msg
endfu

fu! s:LexWarn(msg)
  echo '[lex warn] ' . a:msg
endfu
" gotoMatchEnd								{{{2
fu! s:Java_gotoMatchEnd(one, another)
  while (b:bp < b:buflen)
    if b:ch == a:another
      call s:Java_scanChar()
      if has_key(s:tokens, a:another)
	let b:token = s:tokens[a:another]
      else
	echoerr '<strange>'
      endif
      break

    elseif b:ch == a:one
      call s:Java_scanChar()
      call s:Java_gotoMatchEnd(a:one, a:another)

    " skip commment
    elseif b:ch == '/'
      call s:Java_scanComment()

    " skip literal character
    elseif b:ch == "'"
      call s:Java_scanSingleQuote()

    " skip literal string
    elseif b:ch == '"'
      call s:Java_scanDoubleQuote()

    else
      " OAO 
      call s:Match('[' . a:one . a:another . '/"'']')
      " OLD 
      "call s:Java_scanChar()
    endif
  endwhile
  return b:bp
endfu

" gotoSemi								{{{2
fu! s:Java_gotoSemi()
  while (b:bp < b:buflen)
    if b:ch == ';'
      call s:Java_scanChar()
      let b:token = 'SEMI'
      return

    " skip commment
    elseif b:ch == '/'
      call s:Java_scanComment()

    " skip literal character
    elseif b:ch == "'"
      call s:Java_scanSingleQuote()

    " skip literal string
    elseif b:ch == '"'
      call s:Java_scanDoubleQuote()

    elseif b:ch == '{'
      call s:Java_scanChar()
      call s:Java_gotoMatchEnd('{', '}')

    elseif b:ch == '('
      call s:Java_scanChar()
      call s:Java_gotoMatchEnd('(', ')')

    elseif b:ch == '['
      call s:Java_scanChar()
      call s:Java_gotoMatchEnd('[', ']')

    else
      " OAO 
      call s:Match('[;({[/"'']')
      " OLD 
      "call s:Java_scanChar()
    endif
  endwhile
endfu

" Scanner Helper							{{{1
fu! s:Strpart(start, len)
  let startline = s:GetLine(a:start)
  let endline   = s:GetLine(a:start + a:len)
  let str = ''
  let l = startline
  while l < endline
    let str .= b:lines[l]
    let l += 1
  endwhile
  let str .= b:lines[endline]
  return strpart(str, a:start-b:idxes[startline], a:len)
endfu

fu! s:Stridx(needle)
  let bp_old = b:bp
  let line_old = b:line
  let col_old = b:col

  let found = 0
  while b:line < len(b:lines)-1
    let idx = stridx(b:lines[b:line], a:needle, b:col)
    if idx > -1
      let found = 1
      let b:col = idx
      break
    endif
    let b:line += 1
    let b:col = 0
  endwhile

  if found
    let b:bp = b:idxes[b:line] + b:col
    call s:Java_scanChar()
    return b:bp
  else
    let b:bp = bp_old
    let b:line = line_old
    let b:col = col_old
    return -1
  endif
endfu

fu! s:Match(pat)
  let bp_old = b:bp
  let line_old = b:line
  let col_old = b:col

  let found = 0
  while b:line < len(b:lines)-1
    let idx = match(b:lines[b:line], a:pat, b:col)
    if idx > -1
      let found = 1
      let b:col = idx
      break
    endif
    let b:line += 1
    let b:col = 0
  endwhile

  if found
    let b:bp = b:idxes[b:line] + b:col-1
    call s:Java_scanChar()
    return b:bp
  else
    let b:bp = bp_old
    let b:line = line_old
    let b:col = col_old
    call s:Java_scanChar()
    return -1
  endif
endfu

fu! s:MakePosition()
  return b:idxes[b:line] + b:col
endfu

fu! s:GetLine(pos)
  let line = 0
  for idx in b:idxes
    if idx >= a:pos
      break
    endif
    let line += 1
  endfor
  return line-1
endfu

fu! s:GetCol(pos)
  let line = 0
  for idx in b:idxes
    if idx >= a:pos
      let line -= 1
      break
    endif
    let line += 1
  endfor
  return a:pos - b:idxes[line]
endfu

fu! s:ContainsCursor(from, to)
  let cursor = b:idxes[b:cursor_line] + b:cursor_col
  return a:from <= cursor && cursor <= a:to
endfu

" java function emulations						{{{1
"fu! IsJavaIdentifierPart()
"endfu


" 
fu! Java_Modifier2String(mod)
endfu

fu! Java_String2Modifier(str)
  let mod = [0,0,0,0,0,0,0,0,0,0,0,0,]
  let i = 1
  while i <= len(g:java_modifier_keywords)
      if a:str =~? g:java_modifier_keywords[i-1]
	  let mod[-i] = '1'
      endif
      let i += 1
  endwhile
  return join(mod, '')
endfu

" debug utilities							{{{1
fu! s:Trace(msg)
  "echo a:msg
endfu

fu! s:Debug(msg)
  "echo '[debug] ' . a:msg
endfu

fu! s:Info(msg)
  "echo '[info] ' . a:msg
endfu

fu! s:ShowWatch(...)
  let at = a:0 > 0 ? a:1 : ''
  echo '-- b:bp ' . b:bp . s:Position2String(b:bp) . ' b:ch "' . b:ch . '" b:name ' . b:name . ' b:token ' . b:token . at
endfu

fu! s:Position2String(pos)
  return '(' . (s:GetLine(a:pos)+1) . ', ' . s:GetCol(a:pos) . ')'
endfu


fu! s:PrintUnit(unit)
  echo '=================== unit ==================='

  if has_key(a:unit, 'package')
    echo 'package: ' . a:unit['package']
  endif

  if has_key(a:unit, 'imports')
    for import in a:unit['imports']
      echo 'import: ' . import
    endfor
  endif

  echo ''
  for type in a:unit['types']
    call s:PrintType(type, '')
  endfor

  echo string(b:cursor_node)
endfu

fu! s:PrintType(type, indent)
    echo a:indent . 'type name: ---------- ' . a:type['name'] . ' ----------  from ' . s:Position2String(a:type['pos'])

    if has_key(a:type, 'extends')
      echo a:indent . 'extends'
      for extend in a:type['extends']
	echo a:indent . "\t" . extend
      endfor
    endif

    if has_key(a:type, 'implements')
      echo a:indent . 'implements'
      for impl in a:type['implements']
	echo a:indent . "\t" . impl
      endfor
    endif

    if has_key(a:type, 'defs')
      for def in a:type['defs']
	if def['tag'] == 'METHODDEF' || def['tag'] == 'VARDEF' 
	  echo a:indent . '  ' . def['tag'] . ' ' . def['n']
	  echo a:indent . '  from ' . s:Position2String(def['pos']) . ' to ' . s:Position2String(def['pos_end'])
	  if has_key(def, 'm')
	    echo a:indent . "    modifier\t" . def['m']
	  endif
	  if has_key(def, 't')
	    echo a:indent . "    type\t" . string(def['t'])
	  endif
	  if has_key(def, 'p')
	    echo a:indent . "    params\t" . def['p']
	  endif
	  if has_key(def, 'r')
	    echo a:indent . "    return\t" . string(def['r'])
	  endif
	  if has_key(def, 'w')
	    echo a:indent . "    return\t" . string(def['w'])
	  endif
	  if has_key(def, 'b')
	    echo a:indent . "    block\t" . def['b']
	  endif
	elseif def['tag'] == 'CLASSDEF'
	  call s:PrintType(def, a:indent . '  ')
	elseif def['tag'] == 'BLOCK'
	endif
      endfor
    endif

"    echo 'fields'
"    if has_key(a:type, 'fields')
"      for field in a:type['fields']
"	echo "\t" . field
"      endfor
"    endif
"
"    echo 'ctors'
"    if has_key(a:type, 'ctors')
"      for ctor in a:type['ctors']
"	echo "\t" . ctor
"      endfor
"    endif
"
"    echo 'methods'
"    if has_key(a:type, 'methods')
"      for method in a:type['methods']
"	echo "\t" . method
"      endfor
"    endif
endfu

" Parser								{{{1
"fu! Java_InComment()
"endfu
"
"fu! Java_InStringLiteral()
"endfu

" skip() Skip forward until a suitable stop token is found.		{{{2
fu! s:Java_skip()
  let nbraces = 0
  let nparens = 0
  while (1)
    if b:token == 'EOF' || b:token == 'CLASS' || b:token == 'INTERFACE'
      return
    elseif b:token == 'SEMI'
      if nbraces == 0 && nparens == 0
	return
      endif
    elseif b:token == 'RBRACE'
      if nbraces == 0
	return
      endif
      let nbraces -= 1
    elseif b:token == 'RPAREN'
      if nparens > 0
	let nparens -= 1
      endif
    elseif b:token == 'LBRACE'
      let nbraces += 1
    elseif b:token == 'LPAREN'
      let nparens += 1
    endif
    call s:Java_nextToken()
  endwhile
endfu

" syntax errors					{{{2
fu! s:SyntaxError(msg)
  call s:Java_skip()
  let b:errpos = b:bp
  echo '[syntax error]:' . (s:GetLine(b:bp)+1) . ': ' . a:msg
endfu

fu! s:SyntaxWarn(msg)
  echo '[syntax warn] ' . a:msg
endfu

" accept()								{{{2
fu! s:Java_accept(token_type)
  "call s:Debug(b:token . ' == ' . a:token_type  . (b:token == a:token_type))
  if b:token == a:token_type
    call s:Java_nextToken()
  else
    call s:SyntaxError(s:Java_token2string(a:token_type) . " expected")
    call s:Java_nextToken()
  endif
endfu

fu! s:Java_token2string(token)
  for e in items(s:tokens)
    if e[1] == a:token
      return "'" . e[0] . "'"
    endif
  endfor
  return a:token
endfu


" ident()								{{{2
" Ident = IDENTIFIER
fu! s:Java_ident()
  call s:Trace('s:Java_ident ' . b:token)
  if b:token == 'IDENTIFIER'
    let name = b:name
    call s:Java_nextToken()
    return name
  endif

  if b:token == 'ASSERT'
    if s:allowAsserts
    else
    endif
  else
    call s:Java_accept('IDENTIFIER')
    return '<error>'
  endif
endfu

" qualident()								{{{2
" Qualident = Ident { DOT Ident }
fu! s:Java_qualident()
  let result = s:Java_ident()
  while b:token == 'DOT'
    call s:Java_nextToken()
    let result .= '.' . s:Java_ident()
  endwhile
  return result
endfu

fu! s:Java_qualidentList()
  let result = New(s:TTree)
  let result['tag'] = 'THROWS'
  let ts = []
  call add(ts, s:Java_qualident())
  while b:token == 'COMMA'
    call Java_nextToken()
    call add(ts, s:Java_qualident())
  endwhile
  let result['throws'] = ts
  return result
endfu


" terms, expression, type						{{{2
" When terms are parsed, the mode determines which is expected:
"     mode = EXPR        : an expression
"     mode = TYPE        : a type
"     mode = NOPARAMS    : no parameters allowed for type
let s:EXPR = 1
let s:TYPE = 2
let s:NOPARAMS = 4
let b:mode = 0

fu! s:Java_modeAndEXPR()
  return b:mode == s:EXPR || b:mode == (s:EXPR+s:TYPE) ? 1 : 0
endfu

" terms can be either expressions or types. 
fu! Java_expression()
  let b:mode = s:EXPR
  return Java_term(s:EXPR)
endfu

fu! Java_type()
  let b:mode = s:TYPE
  return Java_term()
endfu

" Expression = Expression1 [ExpressionRest]
" ExpressionRest = [AssignmentOperator Expression1]
" AssignmentOperator = "=" | "+=" | "-=" | "*=" | "/=" |  "&=" | "|=" | "^=" |
"                      "%=" | "<<=" | ">>=" | ">>>="
" Type = Type1
" TypeNoParams = TypeNoParams1
" StatementExpression = Expression
" ConstantExpression = Expression
fu! Java_term()
  let t = Java_term1()
  if s:Java_modeAndEXPR()
    return Java_termRest(t)
  else
    return t
  endif
endfu

fu! Java_termRest(t)
endfu

" Expression1   = Expression2 [Expression1Rest]
"  Type1         = Type2
"  TypeNoParams1 = TypeNoParams2
fu! Java_term1()
  let t = Java_term2()
  if s:Java_modeAndEXPR()
    let b:mode = s:EXPR
    return Java_term1Rest(t)
  else
    return t
  endif
endfu

" Expression1Rest = ["?" Expression ":" Expression1]
fu! Java_term1Rest(t)
endfu

" Expression2   = Expression3 [Expression2Rest]
"  Type2         = Type3
"  TypeNoParams2 = TypeNoParams3
fu! Java_term2()
  let t = Java_term3()
  if s:Java_modeAndEXPR()
    let b:mode = s:EXPR
    return Java_term2Rest(t)
  else
    return t
  endif
endfu

fu! Java_term2Rest(t)
endfu

" Expression3    = PrefixOp Expression3
"                 | "(" Expr | TypeNoParams ")" Expression3
"                 | Primary {Selector} {PostfixOp}
"  Primary        = "(" Expression ")"
"                 | THIS [Arguments]
"                 | SUPER SuperSuffix
"                 | Literal
"                 | NEW Creator
"                 | Ident { "." Ident }
"                   [ "[" ( "]" BracketsOpt "." CLASS | Expression "]" )
"                   | Arguments
"                   | "." ( CLASS | THIS | SUPER Arguments | NEW InnerCreator )
"                   ]
"                 | BasicType BracketsOpt "." CLASS
"  PrefixOp       = "++" | "--" | "!" | "~" | "+" | "-"
"  PostfixOp      = "++" | "--"
"  Type3          = Ident { "." Ident } [TypeArguments] {TypeSelector} BracketsOpt
"                 | BasicType
"  TypeNoParams3  = Ident { "." Ident } BracketsOpt
"  Selector       = "." Ident [Arguments]
"                 | "." THIS
"                 | "." SUPER SuperSuffix
"                 | "." NEW InnerCreator
"                 | "[" Expression "]"
"  TypeSelector   = "." Ident [TypeArguments]
"  SuperSuffix    = Arguments | "." Ident [Arguments]
" NOTE: We need only type expression.
fu! Java_term3()
  let t = New(s:TTree)

  if b:token == 'PLUSPLUS' || b:token == 'SUBSUB' || b:token == 'BANG' || b:token == 'TILDE' || b:token == 'PLUS' || b:token == 'SUB' 
    if s:Java_modeAndEXPR()
    else
      return s:SyntaxError("illegal.start.of.type");
    endif
  elseif b:token == 'LPAREN'
    if s:Java_modeAndEXPR()
    else
      return s:SyntaxError("illegal.start.of.type");
    endif
  elseif b:token == 'THIS'
    if s:Java_modeAndEXPR()
    else
      return s:SyntaxError("illegal.start.of.type");
    endif
  elseif b:token == 'SUPER'
    if s:Java_modeAndEXPR()
    else
      return s:SyntaxError("illegal.start.of.type");
    endif
  elseif b:token == 'INTLITERAL' || b:token == 'LONGLITERAL' || b:token == 'FLOATLITERAL' || b:token == 'DOUBLELITERAL' || b:token == 'CHARLITERAL' || b:token == 'STRINGLITERAL' || b:token == 'TRUE' || b:token == 'FALSE' || b:token == 'NULL'
    if s:Java_modeAndEXPR()
    else
      return s:SyntaxError("illegal.start.of.type");
    endif
  elseif b:token == 'NEW'
    if s:Java_modeAndEXPR()
    else
      return s:SyntaxError("illegal.start.of.type");
    endif
  elseif b:token == 'IDENTIFIER' || b:token == 'ASSERT'
    let id = s:Java_ident()
    while (1)
      if b:token == 'LBRACKET'
	call s:Java_accept('LBRACKET')
	if b:token != 'RBRACKET'
	  call s:Java_gotoMatchEnd('[', ']')
	endif
	call s:Java_accept('RBRACKET')
	let id .= '[]'
	break
      elseif b:token == 'LPAREN'
	if s:Java_modeAndEXPR()
	  call s:Java_accept('LPAREN')
	  call s:Java_gotoMatchEnd('(', ')')
	  call s:Java_accept('RPAREN')
	endif
	break
      elseif b:token == 'DOT'
	call s:Java_nextToken()
	if s:Java_modeAndEXPR()
	endif
	let id .= '.' . s:Java_ident()
      else
	break
      endif
    endwhile
    call Set(t, 'tag', 'IDENTIFIER')
    let t['value'] = id

  elseif b:token =~# '^\(BYTE\|SHORT\|CHAR\|INT\|LONG\|FLOAT\|DOUBLE\|BOOLEAN\)$'
    " basicType()
    call Set(t, 'tag', b:token)
    let t['value'] = b:name
    call s:Java_nextToken()
    let t = s:Java_bracketsOpt(t)
    "let t = Java_bracketsSuffix(s:Java_bracketsOpt(t));

  elseif b:token == 'VOID'
  else
    return s:SyntaxError("illegal.start.of.type or expr");
  endif


  while (1)
    if b:token == 'LBRACKET'
      call s:Java_nextToken()
      if b:token == 'RBRACKET' && !s:Java_modeAndEXPR()
	call s:Java_nextToken()
	return t
      else
	return t
	"if s:Java_modeAndEXPR()
	"endif
      endif
    elseif b:token == 'DOT'
      call s:Java_nextToken()
      if b:token == 'SUPER' && s:Java_modeAndEXPR()
      elseif b:token == 'NEW' && s:Java_modeAndEXPR()
      else
      endif
    else
      break
    endif
  endwhile


  while b:token == 'PLUSPLUS' || b:token == 'SUBSUB' || s:Java_modeAndEXPR()
    let b:mode == EXPR
    call s:Java_nextToken()
  endwhile
  return t
endfu


" part2								{{{2
" ModifiersOpt = { Modifier }
"  Modifier = PUBLIC | PROTECTED | PRIVATE | STATIC | ABSTRACT | FINAL
"           | NATIVE | SYNCHRONIZED | TRANSIENT | VOLATILE
fu! s:Java_modifiersOpt()
  let flags = ''
  while (1)
    if b:token =~# '\<PUBLIC\|PROTECTED\|PRIVATE\|STATIC\|ABSTRACT\|FINAL\|NATIVE\|SYNCHRONIZED\|TRANSIENT\|VOLATILE\>'
      let flags .= b:token
      let flags .= ' '
    else
      return flags
    endif
    call s:Java_nextToken()
  endwhile
endfu

" FormalParameters = "(" [FormalParameter {"," FormalParameter}] ")"
fu! Java_formalParameters()
  let result = []
  call s:Java_accept('LPAREN')
  if b:token != 'RPAREN'
    call add(result, Java_FormalParameter())
    while b:token == 'COMMA'
      call s:Java_nextToken()
      call add(result, Java_FormalParameter())
    endwhile
  endif
  call s:Java_nextToken()
  call s:Java_accept('RPAREN')
  return result
endfu

" FormalParameter = [FINAL] Type VariableDeclaratorId
fu! Java_FormalParameter()
  let name = s:Java_ident()
  " FIXME
  if s:Java_bracketsOpt()
    let name .= '[]'
  endif
  return name
endfu

" BracketsOpt = {"[" "]"}
fu! s:Java_bracketsOpt(t)
  let t = a:t
  while b:token == 'LBRACKET'
    call s:Java_nextToken()
    call s:Java_accept('RBRACKET')
    let t['value'] .= '[]'
    return t
  endwhile
  return t
endfu

" Block = "{" BlockStatements "}"
fu! Java_block(flags)
  let block = New(s:TTree)
  let block['pos'] = b:bp
  let block['tag'] = 'BLOCK'
  call s:Java_accept('LBRACE')
  let pos_begin = b:bp
  call s:Java_gotoMatchEnd('{', '}')
  let pos_end = b:bp
  call s:Java_accept('RBRACE')
  let block['pos_end'] = b:bp
  "let block['b'] = s:Strpart(pos_begin, pos_end-pos_begin-1)
  return block
endfu
" ImportDeclaration = IMPORT Ident { "." Ident } [ "." "*" ] ";"	{{{2
"
fu! s:Java_importDeclaration()
  call s:Info('==import==')
  let pos = b:bp
  call s:Java_nextToken()
  call s:Java_ident()

  " 
  call s:Java_accept('DOT')
  if b:token == 'STAR'
    call s:Java_nextToken()
  else
    call s:Java_ident()
  endif
  while (b:token == 'DOT')
    call s:Java_accept('DOT')
    if b:token == 'STAR'
      call s:Java_nextToken()
      break
    else
      call s:Java_ident()
    endif
  endwhile
  let fqn = s:Strpart(pos, b:bp-pos-2)
  call s:Java_accept('SEMI')
  return fqn
endfu

" TypeDeclaration = ClassOrInterfaceDeclaration | ";"		{{{2
fu! s:Java_typeDeclaration()
  call s:Info('== type ==')

  " handle wrong case
  if b:bp == b:errpos
    let flags = s:Java_modifiersOpt()
    while b:token != 'CLASS' && b:token != 'INTERFACE' && b:token != 'EOF'
      call s:Java_nextToken()
      let flags = s:Java_modifiersOpt()
    endwhile
  endif


  if b:token == 'SEMI'
    call s:Java_nextToken()
    return Java_block(0)
  else
    " doc comment

    let flags = s:Java_modifiersOpt()

    " classOrInterfaceDeclaration
    if b:token == 'CLASS'
      return s:Java_classDeclaration(flags)
    elseif b:token == 'INTERFACE'
      return s:Java_interfaceDeclaration(flags)
    else
      echo s:SyntaxError("class.or.intf.expected")
    endif
  endif
endfu


fu! s:Java_classDeclaration(flags)
  let type = New(s:TTree)
  let type['pos'] = s:MakePosition()
  let type['tag'] = 'CLASSDEF'
  let type['modifier'] = a:flags

  call s:Java_accept('CLASS')
  let type['name'] = s:Java_ident()

  " extends
  if b:token == 'EXTENDS'
    call s:Java_nextToken()
    let type['extends'] = [Java_type()['value']]
  endif

  " implements
  let implements = []
  if b:token == 'IMPLEMENTS'
    call s:Java_nextToken()
    " typeList()
    call add(implements, Java_type()['value'])
    while (b:token == 'COMMA')
      call s:Java_nextToken()
      call add(implements, Java_type()['value'])
    endwhile
  endif
  if len(implements) > 0
    let type['implements'] = implements
  endif

  let type['defs'] = Java_ClassOrInterfaceBody(type['name'], 0)
  " TODO: Consider to divide defs into fields, methods, ctors
  return type
endfu

fu! s:Java_interfaceDeclaration(flags)
  let type = New(s:TTree)
  let type['pos'] = s:MakePosition()
  let type['tag'] = 'CLASSDEF'
  let type['modifier'] = a:flags

  call s:Java_accept('INTERFACE')
  let type['name'] = s:Java_ident()

  " extends
  let extends = []
  if b:token == 'EXTENDS'
    call s:Java_nextToken()
    " typeList()
    call add(extends, Java_type()['value'])
    while (b:token == 'COMMA')
      call s:Java_nextToken()
      call add(extends, Java_type()['value'])
    endwhile
  endif
  let type['extends'] = extends

  let type['defs'] = Java_ClassOrInterfaceBody(type['name'], 0)
  return type
endfu

" ClassBody     = "{" {ClassBodyDeclaration} "}"
" InterfaceBody = "{" {InterfaceBodyDeclaration} "}"
fu! Java_ClassOrInterfaceBody(classname, isInterface)
  call s:Info('== type definition body ==')

  let defs = []
  call s:Java_accept('LBRACE')
  while b:token != 'RBRACE' && b:token != 'EOF'
    let time = reltime()
    let def = s:Java_classOrInterfaceBodyDeclaration(a:classname, a:isInterface)
    let b:et_perf .= "\r" . reltimestr(reltime(time)) . ' def ' . def['tag']
    if def['tag'] == 'METHODDEF' || def['tag'] == 'VARDEF' 
      let b:et_perf .= ' ' . def['n']
    endif
    call add(defs, def)
  endwhile
  call s:Java_accept('RBRACE')
  return defs
endfu

" ClassBodyDeclaration =
"      ";"
"    | [STATIC] Block
"    | ModifiersOpt
"      ( Type Ident
"        ( VariableDeclaratorsRest ";" | MethodDeclaratorRest )
"      | VOID Ident MethodDeclaratorRest
"      | TypeParameters (Type | VOID) Ident MethodDeclaratorRest
"      | Ident ConstructorDeclaratorRest
"      | TypeParameters Ident ConstructorDeclaratorRest
"      | ClassOrInterfaceDeclaration
"      )
"  InterfaceBodyDeclaration =
"      ";"
"    | ModifiersOpt Type Ident
"      ( ConstantDeclaratorsRest | InterfaceMethodDeclaratorRest ";" )
fu! s:Java_classOrInterfaceBodyDeclaration(classname, isInterface)
  call s:Info('s:Java_classOrInterfaceBodyDeclaration')
  if b:token == 'SEMI'
    call s:Java_nextToken()
    return Java_block(0)
  else
    "let dc = b:docComment
    let flags = s:Java_modifiersOpt()

    if b:token == 'CLASS'
      let type = s:Java_classDeclaration(flags)
      call add(s:types, type)
      return type
    elseif b:token == 'INTERFACE'
      let type = s:Java_interfaceDeclaration(flags)
      call add(s:types, type)
      return type

    " [STATIC] block
    elseif b:token == 'LBRACE'
      return Java_block(0)

    else
      let member = {}
      let name = b:name
      let token = b:token

      let type = New(s:TTree)
      let isVoid = b:token == 'VOID'
      if isVoid
	let type['tag'] = 'VOID'
	let type['value'] = ''
	let member['tag'] = 'METHODDEF'
	call s:Java_nextToken()
      else
	let time = reltime()
	let type = Java_type()
	let b:et_perf .= "\r" . reltimestr(reltime(time)) . ' type() '
      endif


      " ctor
      if b:token == 'LPAREN' && !a:isInterface && type['tag'] == 'IDENTIFIER'
	if a:isInterface || name != a:classname 
	  call s:SyntaxError('invalid.meth.decl.ret.type.req')
	endif
	return s:Java_methodDeclaratorRest(member, 1, flags, type, name, a:isInterface)
      else
	let name = s:Java_ident()
	" method
	if b:token == 'LPAREN'
	  return s:Java_methodDeclaratorRest(member, isVoid, flags, type, name, a:isInterface)
	" field
	elseif !isVoid
	  let time3 = reltime()
	  let member = Java_variableDeclaratorRest(member, isVoid, flags, type, name, '')
	  call s:Java_accept('SEMI')
	  let b:et_perf .= "\r" . reltimestr(reltime(time3)) . ' varrest() '
	  return member
	else
	  call s:SyntaxError("LPAREN expected")
	  return member
	endif
      endif
    endif
  endif
endfu

" MethodDeclaratorRest = FormalParameters BracketsOpt [Throws TypeList] ( MethodBody | ";")
"  VoidMethodDeclaratorRest = FormalParameters [Throws TypeList] ( MethodBody | ";")
"  InterfaceMethodDeclaratorRest = FormalParameters BracketsOpt [THROWS TypeList] ";"
"  VoidInterfaceMethodDeclaratorRest = FormalParameters [THROWS TypeList] ";"
"  ConstructorDeclaratorRest = "(" FormalParameterListOpt ")" [THROWS TypeList] MethodBody
fu! s:Java_methodDeclaratorRest(member, isVoid, flags, type, name, isInterface)
  let time = reltime()
  let methoddef = a:member
  let methoddef['pos'] = b:bp
  let methoddef['tag'] = 'METHODDEF'
  let methoddef['n'] = a:name
  let methoddef['m'] = Java_String2Modifier(a:flags)
  let methoddef['r'] = a:type['value'] == '' ? 'void' : a:type['value']

  " parameters
  "  call Java_formalParameters()
  let pos_begin = b:bp
  let pos_end = s:Java_gotoMatchEnd('(', ')')
  let methoddef['p'] = s:Strpart(pos_begin, pos_end-pos_begin-1)

  " BracketsOpt
  "if !a:isVoid
  "  let type = s:Java_bracketsOpt(a:type)
  "endif

  call s:Java_nextToken()

  " throws
  if b:token == 'THROWS'
    call s:Java_nextToken()
    let methoddef['throws'] = s:Java_qualidentList()
  endif

  " method body
  if b:token == 'LBRACE'
    call s:Java_accept('LBRACE')
    if b:token !=# 'RBRACE'
      let time2 = reltime()
      call s:Java_gotoMatchEnd('{', '}')
      let b:et_perf .= "\r" . reltimestr(reltime(time2)) . ' body() '
    endif
    let methoddef['pos_end'] = b:bp
    call s:Java_accept('RBRACE')
    "let methoddef['body'] = body
  else
    call s:Java_accept('SEMI')
  endif

  "if s:ContainsCursor(methoddef['pos'], methoddef['pos_end'])
  "  let b:cursor_node = methoddef
  "endif

  let methoddef['d'] = methoddef['r'] . ' ' . a:name . '(' . methoddef['p'] . ')'
  let b:et_perf .= "\r" . reltimestr(reltime(time)) . ' methodrest() '
  return methoddef
endfu


" VariableDeclaratorsRest = VariableDeclaratorRest { "," VariableDeclarator }
"  ConstantDeclaratorsRest = ConstantDeclaratorRest { "," ConstantDeclarator }
fu! Java_variableDeclaratorsRest(member, isVoid)
  return Java_variableDeclaratorRest(a:member, isVoid)
endfu

" VariableDeclaratorRest = BracketsOpt ["=" VariableInitializer]
"  ConstantDeclaratorRest = BracketsOpt "=" VariableInitializer
" Return: VarDef
fu! Java_variableDeclaratorRest(member, isVoid, flags, type, name, javadoc)
  let vardef = a:member
  let vardef['pos'] = b:bp
  let vardef['tag'] = 'VARDEF'
  let vardef['n'] = a:name
  let vardef['m'] = Java_String2Modifier(a:flags)
  let vardef['t'] = a:type['value']

  " simple way: search forward for ;
  if b:token !=# 'SEMI'
    call s:Java_gotoSemi()
  endif
  let vardef['pos_end'] = b:bp
  "if s:ContainsCursor(vardef['pos'], vardef['pos_end'])
  "  let b:cursor_node = vardef
  "endif
  return vardef
endfu

" CompilationUnit							{{{2
" CompilationUnit = [PACKAGE Qualident ";"] {ImportDeclaration} {TypeDeclaration}
fu! s:Java_compilationUnit()
  let unit = New(s:TTree)
  let unit['tag'] = 'TOPLEVEL'

  call s:Java_scanChar()
  call s:Java_nextToken()

  " package information
  if b:name == 'package'
    call s:Info('==package==')
    " qualified identifier
    call s:Java_nextToken()
    let unit['package'] = s:Java_qualident()
    call s:Java_accept('SEMI')
  endif

  " import declaration
  let imports = []
  while (b:token == 'IMPORT')
    call add(imports, s:Java_importDeclaration())
  endwhile
  let unit['imports'] = imports

  let s:types = []
  while b:token != 'EOF'
    call add(s:types, s:Java_typeDeclaration())
  endwhile
  let unit['types'] = s:types
  unlet s:types
  return unit
endfu

" Test							{{{1
" test scanChar()					{{{2
fu! TestScanChar(lines)
  let time = reltime()
  call Java_InitParser(a:lines)
  echo reltimestr(reltime(time))
  let time = reltime()
  let i = 0
  while i < b:buflen
    call s:Java_scanChar()
    let i += 1
  endwhile
  echo reltimestr(reltime(time))
endfu

" test nextToken()					{{{2
fu! TestNextToken(lines)
  let time = reltime()
  call Java_InitParser(a:lines)
  echo reltimestr(reltime(time))

  let time = reltime()
  call s:Java_scanChar()
  call s:Java_nextToken()
  while b:token != 'EOF'
    call s:Java_nextToken()
  endwhile
  echo reltimestr(reltime(time))
endfu

" test parser()					{{{2
fu! TestParser(lines)
  let time = reltime()
  call Java_InitParser(a:lines)
  echo reltimestr(reltime(time))
  let time = reltime()
  if b:buflen > 0
    "echo '"' . b:buf . '"'
    "echo 'len "' . b:buflen . '"'

    let unit = Java_compilationUnit()
    call s:PrintUnit(unit)
  endif
  echo reltimestr(reltime(time))
endfu

"call TestScanner(readfile('Test.java'))
"call TestParser(readfile('Test.java'))
" }}}

	
" vim:set fdm=marker sw=2 nowrap:
