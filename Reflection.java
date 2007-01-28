
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
    static final Comparator comparator = new MemberComparator();

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
		sb.append(KEY_DESCRIPTION).append("'").append(concise(ctors[i].toString(), className)).append("'");
		sb.append("},").append(NEWLINE);
	    }
	    sb.append("], ").append(NEWLINE);

	    Field[] fields = clazz.getFields();
	    java.util.Arrays.sort(fields, comparator);
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
	    java.util.Arrays.sort(methods, comparator);
	    sb.append("'methods':[");
	    for (int i = 0, n = methods.length; i < n; i++) {
		Method m = methods[i];
		int modifier = m.getModifiers();
		sb.append("{");
		sb.append(KEY_NAME).append("'").append(m.getName()).append("',");
		appendModifier(sb, modifier);
		sb.append(KEY_RETURNTYPE).append("'").append(m.getReturnType().getName()).append("',");
		appendParameterTypes(sb, m.getParameterTypes());
		sb.append(KEY_DESCRIPTION).append("'").append(concise(m.toString(), className)).append("'");
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
    private static String concise(String desc, String className) {
	return desc.replaceAll(className + "\\.", "")
		.replaceAll("java.lang.", "")
		.replaceAll("\\bpublic\\b\\s*", "")
		.replaceAll("\\bstatic\\b\\s*", "");
    }

    // deprecated							{{{

    /**
     * 成员列表由以下几个部分组成：
     * 1. 字段
     * 2. 方法
     * 3. 静态字段
     * 4. 静态方法
     * 5. 构造器
     *
     * 成员列表有几种需求：
     * 1. 创建实例(new AClass)，列出构造器
     * 2. 类(System.)，列出类成员，即静态字段和静态方法。
     * 3. 变量(String s; s.)，列出公共的实例成员和类成员。
     * 4. this，列出所有的实例成员和类成员。一般由语法解析器完成，此类不负责。
     * 5. super，列出非私有的实例成员和类成员。
     *
     * 成员列表有几种策略：
     * 1. 不管字段、方法和构造器，不区分是否静态，不管类继承分层，都按字母排序列出。
     * 2. 不区分是否静态，不管类继承分层，按字段、方法和构造器分类，内部字母排序。
     * 3. 按类继承层次分类，从最低层到根类，内部仍然采用上述策略。
     * 不过，JAVA反射机制无法取得某类的父类。
     * @deprecated
     */
    public static String getMemberList(String className, int option) {
	StringBuffer sb = new StringBuffer(1024);
	sb.append("[");

	try {
	    Class clazz = Class.forName(className);
	    if ((option & STRATEGY_ALPHABETIC) == STRATEGY_ALPHABETIC)
		appendByAllInAlphabetic(sb, clazz, option);
	    else
		appendByDefaultStrategy(sb, clazz, option);
	}
	catch (Exception ex) {
	    ex.printStackTrace();
	}
	//return "[\"-- String --\", \"abd\", {\"word\" : \"method\", \"abbr\" : \"m\", \"menu\" : \"miii\", \"info\" : \"method information \", \"kind\" : \"f\"}]";
	sb.append("]");
	return sb.toString()
		 .replaceAll(className + "\\.", "")
		 .replaceAll("java.lang.", "")
		 .replaceAll("\\bpublic\\b\\s*", "")
		 .replaceAll("\\bstatic\\b\\s*", "");
    }

    /**
     * @deprecated
     */
    private static void appendByAllInAlphabetic(StringBuffer sb, Class clazz, int option) {
	Member[] members = null;
	Field[] fields = clazz.getFields();
	Method[] methods = clazz.getMethods();
	Constructor[] ctors = clazz.getConstructors();
	if ((option & OPTION_SAME_PACKAGE) == OPTION_SAME_PACKAGE) {
	    debug("same package");
	    fields = clazz.getDeclaredFields();
	    methods = clazz.getDeclaredMethods();
	    List list = new ArrayList(fields.length + methods.length + ctors.length);
	    for (int i = 0, n = fields.length; i < n; i++) {
		Field f = fields[i];
		if (Modifier.isProtected(f.getModifiers()) 
			|| Modifier.isPublic(f.getModifiers()))
		    list.add(f);
	    }
	    for (int i = 0, n = methods.length; i < n; i++) {
		Method m = methods[i];
		if (Modifier.isProtected(m.getModifiers()) 
			|| Modifier.isPublic(m.getModifiers()))
		    list.add(m);
	    }
	    for (int i = 0, n = ctors.length; i < n; i++)
		list.add(ctors[i]);
	    members = (Member[])list.toArray(new Member[0]);
	}
	else if ((option & OPTION_SUPER) == OPTION_SUPER) {
	}
	else if ((option & OPTION_INSTANCE) == OPTION_INSTANCE) {
	    members = new Member[fields.length + methods.length + ctors.length];
	    for (int i = 0, n = fields.length; i < n; i++)
		members[i] = fields[i];
	    for (int i = 0, n = methods.length; i < n; i++)
		members[fields.length + i] = methods[i];
	    for (int i = 0, n = ctors.length; i < n; i++)
		members[fields.length + methods.length + i] = ctors[i];
	}
	else if ((option & OPTION_STATIC) == OPTION_STATIC) {
	    List list = new ArrayList(fields.length + methods.length + ctors.length);
	    for (int i = 0, n = fields.length; i < n; i++) {
		Field f = fields[i];
		if (Modifier.isStatic(f.getModifiers())) 
		    list.add(f);
	    }
	    for (int i = 0, n = methods.length; i < n; i++) {
		Method m = methods[i];
		if (Modifier.isStatic(m.getModifiers()))
		    list.add(m);
	    }
	    for (int i = 0, n = ctors.length; i < n; i++)
		list.add(ctors[i]);
	    members = (Member[])list.toArray(new Member[0]);
	}
	debug("members.length: " + members.length);
	java.util.Arrays.sort(members, comparator);
	for (int i = 0, n = members.length; i < n; i++) {
	    Member m = members[i];
	    debug(m.getName());
	    if (m instanceof Field ) 
		appendField(sb, (Field)m);
	    else if (m instanceof Method ) 
		appendMethod(sb, (Method)m);
	    else if (m instanceof Constructor ) 
		appendConstructor(sb, (Constructor)m);
	}
    }

    /**
     * @deprecated
     */
    private static void appendByDefaultStrategy(StringBuffer sb, Class clazz, int option) {
	if ((option & OPTION_FIELD) == OPTION_FIELD)
	    appendFieldList(sb, clazz);
	if ((option & OPTION_METHOD) == OPTION_METHOD)
	    appendMethodList(sb, clazz);
	if ((option & OPTION_STATIC_FIELD) == OPTION_STATIC_FIELD)
	    appendStaticFieldList(sb, clazz);
	if ((option & OPTION_STATIC_METHOD) == OPTION_STATIC_METHOD)
	    appendStaticMethodList(sb, clazz);
	if ((option & OPTION_CONSTRUCTOR) == OPTION_CONSTRUCTOR)
	    appendConstructorList(sb, clazz);
    }




    private static void appendField(StringBuffer sb, Field f) {
	sb.append("{")
	  .append("'kind' : '").append(Modifier.isStatic(f.getModifiers()) ? "M" : "m").append("', ")
	  .append("'word' : '").append(f.getName()).append("', ")
	  .append("'menu' : '").append(f.getType().getName()).append("', ")
	  .append("}, ");
    }

    private static void appendMethod(StringBuffer sb, Method m) {
	sb.append("{")
	  .append("'kind' : '").append(Modifier.isStatic(m.getModifiers()) ? "F" : "f").append("', ")
	  .append("'word' : '").append(m.getName()).append("(', ")
	  .append("'abbr' : '").append(m.getName()).append("()', ")
	  .append("'menu' : '").append(m.toString()).append("', ")
	  .append("'dup' : '1'")
	  .append("}, ");
    }

    private static void appendConstructor(StringBuffer sb, Constructor ctor) {
	sb.append("{")
	  .append("'kind' : '+', ")
	  .append("'word' : '").append(ctor.getName()).append("', ")
	  .append("'menu' : '").append(ctor.toString()).append("', ")
	  .append("'dup' : '1'")
	  .append("}, ");
    }


    private static void appendConstructorList(StringBuffer sb, Class clazz) {
	Constructor[] ctors = clazz.getConstructors();
	for (int i = 0, n = ctors.length; i < n; i++) {
	    appendConstructor(sb, ctors[i]);
	}
    }

    private static void appendFieldList(StringBuffer sb, Class clazz) {
	Field[] fields = clazz.getDeclaredFields();
	java.util.Arrays.sort(fields, new MemberComparator());
	AccessibleObject.setAccessible(fields, true);
	for (int i = 0; i < fields.length; i++) {
	    Field f = fields[i];
	    if (!Modifier.isStatic(f.getModifiers())
		    && Modifier.isPublic(f.getModifiers())) {
		appendField(sb, f);
	    }
	}
    }

    private static void appendStaticFieldList(StringBuffer sb, Class clazz) {
	Field[] fields = clazz.getFields();
	java.util.Arrays.sort(fields, new MemberComparator());
	for (int i = 0; i < fields.length; i++) {
	    Field f = fields[i];
	    if (Modifier.isStatic(f.getModifiers())
		    && Modifier.isPublic(f.getModifiers())) {
		appendField(sb, f);
	    }
	}
    }

    private static void appendMethodList(StringBuffer sb, Class clazz) {
	Method[] methods = clazz.getMethods();
	java.util.Arrays.sort(methods, new MemberComparator());
	for (int i = 0; i < methods.length; i++) {
	    Method m = methods[i];
	    if (!Modifier.isStatic(m.getModifiers())) {
		appendMethod(sb, m);
	    }
	}
    }

    private static void appendStaticMethodList(StringBuffer sb, Class clazz) {
	Method[] methods = clazz.getMethods();
	java.util.Arrays.sort(methods, new MemberComparator());
	for (int i = 0; i < methods.length; i++) {
	    Method m = methods[i];
	    if (Modifier.isStatic(m.getModifiers())) {
		appendMethod(sb, m);
	    }
	}
    }


    /**
     * @deprecated
     */
    private static String GetMethodShortInfo(String str) {
	StringTokenizer st = new StringTokenizer(str," .(,)",true);
	String prev = "";
	String op = "";
	boolean started = false;
	while (st.hasMoreTokens()) {
	    String item = st.nextToken();
	    if (item.equals("(") && !started) {
		op = prev;
		started = true;
	    }
	    if (started) {
		op += item;
		if (item.equals(")")) {
		    break;
		}
	    }
	    prev = item;
	}
	return op;
    }

    
    // deprecated }}}
    

    // test methods

    static void listLoadedPackages() {
	Package[] packages = Package.getPackages();
	debug("packages.length: " + packages.length);
	for (int i = 0; i < packages.length; i++)
	    debug(packages[i].getName());
    }

    static void listClasses(String className) {
	try {
	    Class clazz = Class.forName(className);
	    Class[] classes = clazz.getDeclaredClasses();
	    for (int i = 0; i < classes.length; i++)
		debug(classes[i].getName());
	}
	catch (Exception ex) {
	    ex.printStackTrace();
	}
    }

    static void debug(String s) {
	if (debug_mode)
	    System.out.println(s);
    }
    static void output(String s) {
	if (!debug_mode)
	    System.out.println(s);
    }

    public static void test(String[] args) {
	if (!debug_mode)
	    return ;

	System.out.println( getClassInfo("java.lang.Object") );
	//getPackageList("java.lang");
	//getPackageList("java.lang", "C:/j2sdk1.4.2_13/jre/lib/rt.jar");
	//getPackageList("com.datanew", "D:/fcDev/java/DNOlap/DNPivot/build/web/WEB-INF/classes");

	//listClasses("java.util.ArrayList");
	//listLoadedPackages();

	//try {
	//    Class clazz = Class.forName("java.lang.Object");
	//    Method[] methods = clazz.getMethods();
	//    for (int i = 0; i < methods.length; i++) {
	//	debug(methods[i].toString());
	//	debug(methods[i].getReturnType().getName());
	//	//debug(methods[i].getParameterTypes().toString());
	//    }
	//}
	//catch (Exception ex) {
	//    ex.printStackTrace();
	//}

	//System.out.println(getStaticMemberList("java.lang.String"));
	//System.out.println(getMemberList("java.lang.String"));
	//System.out.println(getConstructorList("java.lang.String"));
	//String s = "[LObject";
	//s = s.replaceAll("(\\[)L?([a-zA-Z_$.])", "\2\1");
	//System.out.println(s);
	//String str = GetMemberList("java.util.ArrayList");
	//System.out.println(str.replaceAll("java.lang.", ""));
	//System.out.println(str);

	/*
	try {
	Class clazz = Class.forName("java.util.ArrayList");
	Class superClass = clazz.getSuperclass();
	if (superClass != null) {
	    System.out.println(" extends " + superClass.getName());
	}
	}
	catch (Exception ex) {
	    
	}
	*/
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

	for (int i = 0, n = args.length; i < n; i++) {
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
	else
	    output( getMemberList(className, option) );

	test(args);
    }

    /**
     * @deprecated
     */
    static class MemberComparator implements Comparator {
	public int compare(Object o1, Object o2) {
	    Member m1 = (Member)o1;
	    Member m2 = (Member)o2;
	    //debug("comparing...................." + m1.getName().compareTo(m2.getName()));
	    return m1.getName().compareTo(m2.getName());
	}
	public boolean equals(Object obj) { return true; }
    }
}
