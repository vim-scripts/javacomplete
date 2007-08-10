/**
 * Reflection.java
 *
 * A utility class for javacomplete mainly for reading class or package information.
 * Version:	0.76.3
 * Maintainer:	cheng fang <fangread@yahoo.com.cn>
 * Last Change:	2007-08-10
 * Copyright:	Copyright (C) 2007 cheng fang. All rights reserved.
 * License:	Vim License	(see vim's :help license)
 * 
 */

import java.lang.reflect.*;
import java.io.*;
import java.util.*;
import java.util.zip.*;

class Reflection {
    static final String VERSION	= "0.76.3";

    static final int OPTION_FIELD		=  1;
    static final int OPTION_METHOD		=  2;
    static final int OPTION_STATIC_FIELD	=  4;
    static final int OPTION_STATIC_METHOD	=  8;
    static final int OPTION_CONSTRUCTOR		= 16;
    static final int OPTION_STATIC		= 12;	// compound static
    static final int OPTION_INSTANCE		= 15;	// compound instance
    static final int OPTION_ALL			= 31;	// compound all
    static final int OPTION_SUPER		= 32;
    static final int OPTION_SAME_PACKAGE	= 64;

    static final int STRATEGY_ALPHABETIC	= 128;
    static final int STRATEGY_HIERARCHY		= 256;
    static final int STRATEGY_DEFAULT		= 512;

    static final int RETURN_ALL_PACKAGE_INFO	= 0x1000;

    static final String KEY_NAME		= "'n':";	// "'name':";
    static final String KEY_TYPE		= "'t':";	// "'type':";
    static final String KEY_MODIFIER		= "'m':";	// "'modifier':";
    static final String KEY_PARAMETERTYPES	= "'p':";	// "'parameterTypes':";
    static final String KEY_RETURNTYPE		= "'r':";	// "'returnType':";
    static final String KEY_DESCRIPTION		= "'d':";	// "'description':";

    static final String NEWLINE = "";	// "\r\n"

    static boolean debug_mode = false;

    public static boolean existed(String fqn) {
	boolean result = false;
	try {
	    Class.forName(fqn);
	    result = true;
	}
	catch (Exception ex) {
	}
	return result;
    }

    public static String existedAndRead(String str) {
	StringBuffer sb = new StringBuffer(1024);
	sb.append("{");

	int prev = 0;
	int idx = -1;
	while ( (idx = str.indexOf(',', idx+1)) != -1 ) {
	    String fqn = str.substring(prev, idx);
	    prev = idx+1;

	    try {
		Class.forName(fqn);
		sb.append("'" + fqn +"': ").append(getClassInfo(fqn)).append(",");
	    }
	    catch (Exception ex) {
	    }
	    finally {
		// it is a package?
		String s = getPackageList(fqn);
		if (!s.equals("[]"))
		    sb.append("'" + fqn +"': ").append(s).append(",");
	    }
	}
	String fqn = str.substring(prev);
	try {
	    Class.forName(fqn);
	    sb.append("'" + fqn +"': ").append(getClassInfo(fqn)).append(",");
	}
	catch (Exception ex) {
	}
	finally {
	    // it is a package?
	    String s = getPackageList(fqn);
	    if (!s.equals("[]"))
		sb.append("'" + fqn +"': ").append(s).append(",");
	}


	sb.append("}");
	return sb.toString();
    }

    public static String getPackageList(String fqn) {
	fqn = fqn.replace('.', '/') + "/";
	StringBuffer sb = new StringBuffer(1024);
	sb.append("[");

	// system classpath
	String java_home_path = System.getProperty("java.home") + "/lib/";
	File file = new File(java_home_path);
	String[] items = file.list();
	for (int i = 0; i < items.length; i++) {
	    String path = items[i];
	    if (path.endsWith(".jar") || path.endsWith(".zip")) {
		appendListFromJar(sb, fqn, java_home_path + path);
	    }
	}

	// user classpath
	String classPath = System.getProperty("java.class.path");
	StringTokenizer st = new StringTokenizer(classPath, ";");
	while (st.hasMoreTokens()) {
	    String path = st.nextToken();
	    if (path.endsWith(".jar") || path.endsWith(".zip"))
		appendListFromJar(sb, fqn, path);
	    else
		appendListFromFolder(sb, fqn, path);
	}

	sb.append("]");
	return sb.toString();
    }

    public static String getPackageList() {
	Hashtable map = new Hashtable();

	// system classpath
	String java_home_path = System.getProperty("java.home") + "/lib/";
	File file = new File(java_home_path);
	String[] items = file.list();
	for (int i = 0; i < items.length; i++) {
	    String path = items[i];
	    if (path.endsWith(".jar") || path.endsWith(".zip")) {
		appendListFromJar(java_home_path + path, map);
	    }
	}

	// user classpath
	String classPath = System.getProperty("java.class.path");
	StringTokenizer st = new StringTokenizer(classPath, ";");
	while (st.hasMoreTokens()) {
	    String path = st.nextToken();
	    if (path.endsWith(".jar") || path.endsWith(".zip"))
		appendListFromJar(path, map);
	    else
		appendListFromFolder(path, map, "");
	}

	StringBuffer sb = new StringBuffer(4096);
	sb.append("{");
	sb.append("'*':'").append( map.remove("") ).append("',");	// default package
	for (Enumeration e = map.keys(); e.hasMoreElements(); ) {
	    String s = (String)e.nextElement();
	    sb.append("'").append( s.replace('/', '.') ).append("':'").append(map.get(s)).append("',");
	}
	sb.append("}");
	return sb.toString();

    }

    public static void appendListFromJar(StringBuffer sb, String fqn, String path) {
	try {
	    for (Enumeration entries = new ZipFile(path).entries(); entries.hasMoreElements(); ) {
		String entry = entries.nextElement().toString();
		if (entry.indexOf('$') == -1 && entry.endsWith(".class")
			&& entry.startsWith(fqn)) {
		    int splitPos = entry.indexOf('/', fqn.length());
		    if (splitPos == -1)
			splitPos = entry.indexOf(".class",fqn.length());
		    String descent = entry.substring(fqn.length(),splitPos);
		    if (sb.toString().indexOf("'" + descent + "',") == -1)
			sb.append("'").append(descent).append("',");
		    debug(descent);
		}
	    }
	}
	catch (Throwable e) {
	}
    }

    public static void appendListFromJar(String path, Hashtable map) {
	try {
	    for (Enumeration entries = new ZipFile(path).entries(); entries.hasMoreElements(); ) {
		String entry = entries.nextElement().toString();
		int len = entry.length();
		if (entry.endsWith(".class") && entry.indexOf('$') == -1) {
		    int slashpos = entry.lastIndexOf('/');
		    AddToParent(map, entry.substring(0, slashpos), entry.substring(slashpos+1, len-6));
		}
	    }
	}
	catch (Throwable e) {
	    //e.printStackTrace();
	}
    }

    public static void AddToParent(Hashtable map, String parent, String child) {
	StringBuffer sb = (StringBuffer)map.get(parent);
	if (sb == null) {
	    sb = new StringBuffer(256);
	}
	if (sb.toString().indexOf(child + ",") == -1)
	    sb.append(child).append(",");
	map.put(parent, sb);

	int slashpos = parent.lastIndexOf('/');
	if (slashpos != -1) {
	    AddToParent(map, parent.substring(0, slashpos), parent.substring(slashpos+1));
	}
    }

    public static void appendListFromFolder(StringBuffer sb, String fqn, String path) {
	try {
	    String fullPath = path + "/" + fqn;
	    File file = new File(fullPath);
	    if (file.exists()) {
		String[] descents = file.list();
		for (int i = 0; i < descents.length; i++) {
		    if (descents[i].indexOf('$') == -1) {
			String className = null;
			String descent = null;
			if (descents[i].endsWith(".class")) {
			    descent = descents[i].substring(0,descents[i].indexOf(".class"));
			    sb.append("'").append(descent).append("',");
			    debug(descent);
			    className = (fqn + descent).replace('/','.');									
			}
			else if ((new File(fullPath + "/" + descents[i])).isDirectory()) {
			    descent = descents[i];
			    sb.append("'").append(descent).append("',");
			    debug(descent);
			}
		    }
		}
	    }						
	}
	catch (Throwable e) {
	}
    }

    public static void appendListFromFolder(String path, Hashtable map, String fqn) {
	try {
	    File file = new File(path);
	    if (file.isDirectory()) {
		String[] descents = file.list();
		for (int i = 0; i < descents.length; i++) {
		    if (descents[i].indexOf('$') == -1 && descents[i].endsWith(".class")) {
			StringBuffer sb = (StringBuffer)map.get(fqn);
			if (sb == null) {
			    sb = new StringBuffer(256);
			}
			sb.append(descents[i].substring(0, descents[i].length()-6)).append(',');
			map.put(fqn, sb);
		    }
		    else {
			String qn = fqn.length() == 0 ? "" : fqn + ".";
			appendListFromFolder(path + "/" + descents[i], map, qn + descents[i]);
		    }
		}
	    }
	}
	catch (Throwable e) {
	    //e.printStackTrace();
	}
    }

    public static String getClassInfo(String className) {
	StringBuffer sb = new StringBuffer(1024);
	sb.append("{");

	try {
	    Class clazz = Class.forName(className);

	    Constructor[] ctors = clazz.getConstructors();
	    sb.append("'ctors':[");
	    for (int i = 0, n = ctors.length; i < n; i++) {
		Constructor ctor = ctors[i];
		sb.append("{");
		appendModifier(sb, ctor.getModifiers());
		appendParameterTypes(sb, ctor.getParameterTypes());
		sb.append(KEY_DESCRIPTION).append("'").append(ctors[i].toString()).append("'");
		sb.append("},").append(NEWLINE);
	    }
	    sb.append("], ").append(NEWLINE);

	    Field[] fields = clazz.getFields();
	    //java.util.Arrays.sort(fields, comparator);
	    sb.append("'fields':[");
	    for (int i = 0, n = fields.length; i < n; i++) {
		Field f = fields[i];
		int modifier = f.getModifiers();
		sb.append("{");
		sb.append(KEY_NAME).append("'").append(f.getName()).append("',");
		appendModifier(sb, modifier);
		sb.append(KEY_TYPE).append("'").append(f.getType().getName()).append("'");
		sb.append("},").append(NEWLINE);
	    }
	    sb.append("], ").append(NEWLINE);

	    Method[] methods = clazz.getMethods();
	    //java.util.Arrays.sort(methods, comparator);
	    sb.append("'methods':[");
	    for (int i = 0, n = methods.length; i < n; i++) {
		Method m = methods[i];
		int modifier = m.getModifiers();
		sb.append("{");
		sb.append(KEY_NAME).append("'").append(m.getName()).append("',");
		appendModifier(sb, modifier);
		sb.append(KEY_RETURNTYPE).append("'").append(m.getReturnType().getName()).append("',");
		appendParameterTypes(sb, m.getParameterTypes());
		sb.append(KEY_DESCRIPTION).append("'").append(m.toString()).append("'");
		sb.append("},").append(NEWLINE);
	    }
	    sb.append("], ").append(NEWLINE);
	}
	catch (Exception ex) {
	    //ex.printStackTrace();
	}
	//return "[\"-- String --\", \"abd\", {\"word\" : \"method\", \"abbr\" : \"m\", \"menu\" : \"miii\", \"info\" : \"method information \", \"kind\" : \"f\"}]";
	sb.append("}");
	return sb.toString();
    }

    private static void appendModifier(StringBuffer sb, int modifier) {
	sb.append(KEY_MODIFIER).append("'").append(Integer.toString(modifier, 2)).append("', ");
    }

    private static void appendParameterTypes(StringBuffer sb, Class[] paramTypes) {
	sb.append(KEY_PARAMETERTYPES).append("[");
	for (int j = 0; j < paramTypes.length; j++) {
	    sb.append("'").append(paramTypes[j].getName()).append("',");
	}
	sb.append("],");
    }

    private static boolean isBlank(String str) {
        int len;
        if (str == null || (len = str.length()) == 0)
            return true;
        for (int i = 0; i < len; i++)
            if ((Character.isWhitespace(str.charAt(i)) == false))
                return false;
        return true;
    }

    // test methods

    static void debug(String s) {
	if (debug_mode)
	    System.out.println(s);
    }
    static void output(String s) {
	if (!debug_mode)
	    System.out.println(s);
    }


    private static void usage() {
	System.out.println("Reflection for javacomplete (" + VERSION + ")");
	System.out.println("  java [-classpath] Reflection [-c] [-d] [-e] [-h] [-v] [-p] [-s] classname");
	System.out.println("Options:");
	System.out.println("  -a	list all members in alphabetic order");
	System.out.println("  -c	list constructors");
	System.out.println("  -C	return class info");
	System.out.println("  -d	default strategy, i.e. instance fields, instance methods, static fields, static methods");
	System.out.println("  -e	check class existed");
	System.out.println("  -E	check class existed and read class information");
	System.out.println("  -D	debug mode");
	System.out.println("  -p	list package content");
	System.out.println("  -P	print all package info in the Vim dictionary format");
	System.out.println("  -s	list static fields and methods");
	System.out.println("  -h	help");
	System.out.println("  -v	version");
    }

    public static void main(String[] args) {
	String className = null;
	int option = 0x0;
	boolean wholeClassInfo = false;
	boolean onlyStatic = false;
	boolean onlyConstructor = false;
	boolean listPackageContent = false;
	boolean checkExisted = false;
	boolean checkExistedAndRead = false;
	boolean allPackageInfo = false;

	for (int i = 0, n = args.length; i < n && !isBlank(args[i]); i++) {
	    //debug(args[i]);
	    if (args[i].charAt(0) == '-') {
		if (args[i].length() > 1) {
		switch (args[i].charAt(1)) {
		case 'a':
		    break;
		case 'c':	// request constructors
		    option = option | OPTION_CONSTRUCTOR;
		    onlyConstructor = true;
		    break;
		case 'C':	// class info
		    wholeClassInfo = true;
		    break;
		case 'd':	// default strategy
		    option = option | STRATEGY_DEFAULT;
		    break;
		case 'D':	// debug mode
		    debug_mode = true;
		    break;
		case 'e':	// class existed
		    checkExisted = true;
		    break;
		case 'E':	// check existed and read class information
		    checkExistedAndRead = true;
		    break;
		case 'h':	// help
		    usage();
		    return ;
		case 'v':	// version
		    System.out.println("Reflection for javacomplete (" + VERSION + ")");
		    break;
		case 'p':
		    listPackageContent = true;
		    break;
		case 'P':
		    option = RETURN_ALL_PACKAGE_INFO;
		    break;
		case 's':	// request static members
		    option = option | OPTION_STATIC_METHOD | OPTION_STATIC_FIELD;
		    onlyStatic = true;
		    break;
		default:
		}
		}
	    }
	    else {
		className = args[i];
	    }
	}
	if (className == null && (option & RETURN_ALL_PACKAGE_INFO) != RETURN_ALL_PACKAGE_INFO) {
	    return;
	}
	if (option == 0x0)
	    option = OPTION_INSTANCE;

	if (wholeClassInfo)
	    output( getClassInfo(className) );
	else if ((option & RETURN_ALL_PACKAGE_INFO) == RETURN_ALL_PACKAGE_INFO)
	    output( getPackageList() );
	else if (checkExistedAndRead)
	    output( existedAndRead(className) );
	else if (checkExisted)
	    output( String.valueOf(existed(className)) );
	else if (listPackageContent)
	    output( getPackageList(className) );
    }
}
