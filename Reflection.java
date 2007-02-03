
import java.lang.reflect.*;
import java.io.*;
import java.util.*;
import java.util.jar.*;

class Reflection {
    static final String VERSION	= "0.7";

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

    public static void appendListFromJar(StringBuffer sb, String fqn, String path) {
	try {
	    for (Enumeration entries = new JarFile(path).entries(); entries.hasMoreElements(); ) {
		JarEntry jarEntry = (JarEntry)entries.nextElement();
		String entry = jarEntry.toString();
		if (entry.indexOf('$') == -1 && entry.endsWith(".class")
			&& entry.startsWith(fqn)) {
		    int splitPos = entry.indexOf('/', fqn.length());
		    if (splitPos == -1)
			splitPos = entry.indexOf(".class",fqn.length());
		    String descent = entry.substring(fqn.length(),splitPos);
		    sb.append("'").append(descent).append("',");
		    debug(descent);
		}
	    }
	}
	catch (Throwable e) {
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
	    ex.printStackTrace();
	}
	//return "[\"-- String --\", \"abd\", {\"word\" : \"method\", \"abbr\" : \"m\", \"menu\" : \"miii\", \"info\" : \"method information \", \"kind\" : \"f\"}]";
	sb.append("}");
	return sb.toString();
    }

    private static void appendModifier(StringBuffer sb, int modifier) {
	sb.append(KEY_MODIFIER).append(Integer.toString(modifier, 2)).append(", ");
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
	System.out.println("Reflection for JAVim (" + VERSION + ")");
	System.out.println("  java [-classpath] Reflection [-c] [-d] [-h] [-v] [-p] [-s] classname");
	System.out.println("Options:");
	System.out.println("  -a	list all members in alphabetic order");
	System.out.println("  -c	list constructors");
	System.out.println("  -C	return class info");
	System.out.println("  -d	default strategy, i.e. instance fields, instance methods, static fields, static methods");
	System.out.println("  -D	debug mode");
	System.out.println("  -p	list package content");
	System.out.println("  -P	in same package");
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
		case 'h':	// help
		    usage();
		    return ;
		case 'v':	// version
		    break;
		case 'p':
		    listPackageContent = true;
		    break;
		case 'P':	// same package
		    option = option | OPTION_SAME_PACKAGE;
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
	if (className == null) {
	    return;
	}
	if (option == 0x0)
	    option = OPTION_INSTANCE;

	if (wholeClassInfo)
	    output( getClassInfo(className) );
	else if (checkExisted)
	    output( String.valueOf(existed(className)) );
	else if (listPackageContent)
	    output( getPackageList(className) );
    }
}
