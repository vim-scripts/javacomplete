# vim-javacomplete
> This is javacomplete, an omni-completion script of JAVA language for vim.
[![Build Status](https://travis-ci.com/sixro/javacomplete.svg?branch=master)](https://travis-ci.com/sixro/javacomplete)

This is a fork of the [mirror](https://github.com/vim-scripts/javacomplete) of http://www.vim.org/scripts/script.php?script_id=1785


## Summary

  * [Features](#features)
  * [Requirements](#requirements)
  * [How it works](#how-it-works)
  * [Limitations](#limits)
  * [TODOs](#todos)
  * [Credits](#credits)


## <a name="features"></a>Features

  * List members of a class, including (static) fields, (static) methods and ctors.
  * List classes or subpackages of a package.
  * Provide parameters information of a method, list all overload methods.
  * Complete an incomplete word.
  * Provide a complete JAVA parser written in Vim script language.
  * Use the JVM to obtain most information.
  * Use the embedded parser to obtain the class information from source files.
  * Tags generated by ctags can also be used.
  * JSP is supported, Builtin objects such as request, session can be recognized.
  * The classes and jar files in the WEB-INF will be appended automatically to classpath.


## <a name="requirements"></a>Requirements

It works on all the platforms where
  * Vim version 7.0 and above
  * JDK version 1.1 and above
existed 


## <a name="how-it-works"></a>How it works

It recognize nearly all kinds of Primary Expressions (see langspec-3.0)
except for "Primary.new Indentifier". Casting conversion is also supported.
Samples of input contexts are as following:	('|' indicates cursor)
    (1). after '.', list members of a class or a package
    - package.|         subpackages and classes of a package
    - Type.|                static members of the 'Type' class and "class"
    - var.| or field.|     members of a variable or a field
    - method().|         members of result of method()
    - this.|                   members of the current class
    - ClassName.this.|  members of the qualified class
    - super.|               members of the super class
    - array.|                members of an array object
    - array[i].|             array access, return members of the element of array
    - "String".|            String literal, return members of java.lang.String
    - int.| or void.|       primitive type or pseudo-type, return "class"
    - int[].|                   array type, return members of a array type and "class"
    - java.lang.String[].|
    - new int[].|           members of the new array instance
    - new java.lang.String[i=1][].|
    - new Type().|      members of the new class instance 
    - Type.class.|      class literal, return members of java.lang.Class
    - void.class.| or int.class.|
    - ((Type)var).|         cast var as Type, return members of Type.
    - (var.method()).|   same with "var.|"
    - (new Class()).|    same with "new Class().|"

   (2). after '(', list matching methods with parameters information.
    - method(|)                 methods matched
    - var.method(|)           methods matched
    - new ClassName(|)  constructors matched
    - this(|)                        constructors of current class matched
    - super(|)                     constructors of super class matched
    Any place between '(' and ')' will be supported soon.
    Help information of javadoc is not supported yet.

   (3). after an incomplete word, list all the matched beginning with it.
    - var.ab|          subset of members of var beginning with `ab`
    - ab|                list of all maybes

   (4). import statement
    - " import         java.util.|"
    - " import         java.ut|"
    - " import         ja|"
    - " import         java.lang.Character.|"        e.g. "Subset"
    - " import static java.lang.Math.|"        e.g. "PI, abs"

   (5). package declaration
    - " package         com.|"

   The above are in simple expression.
   (6). after compound expression:
    - PrimaryExpr.var.|
    - PrimaryExpr.method().|
    - PrimaryExpr.method(|)
    - PrimaryExpr.var.ab|
    e.g.
    - "java.lang        . System.in .|"
    - "java.lang.System.getenv().|"
    - "int.class.toString().|"
    - "list.toArray().|"
    - "new ZipFile(path).|"
    - "new ZipFile(path).entries().|"

   (7). Nested expression:
    - "System.out.println( str.| )"
    - "System.out.println(str.charAt(| )"
    - "for (int i = 0; i < str.|; i++)"
    - "for ( Object o : a.getCollect| )"


## <a name="limits"></a>Limitations

The embedded parser works a bit slower than expected.


## <a name="todos"></a>TODOs

-  Improve performance of the embedded parser. Incremental parser.
-  Add quick information using balloonexpr, ballooneval, balloondelay.
-  Add javadoc
-  Give a hint for class name conflict in different packages.
-  Support parameter information for template
-  Make it faster and more robust.


## <a name="credits"></a>Credits

The first version has been created and maintained by [Fang Cheng](mailto:fangread@yahoo.com.cn).
