import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.io.UnsupportedEncodingException;

public class ReflectionTest {

    /*
     * NOTE: this test failed in the past using a JDK with version major than 8
     */
    @Test
    public void returns_expected_info_for_java_package() throws UnsupportedEncodingException {
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        System.setOut(new PrintStream(os));
        Reflection.main(new String[]{ "-E", "java,java.lang.java," });
        String output = os.toString("UTF-8");
        Assertions.assertEquals("{'java':{'tag':'PACKAGE','subpackages':['applet','lang','time','rmi','util','nio','io','awt','net','math','security','text','beans','sql',],'classes':[]},}", output);
    }

//    @Test
//    public void findJavaPackagesStartingWith_with_javatime() throws UnsupportedEncodingException {
//        ByteArrayOutputStream os = new ByteArrayOutputStream();
//        System.setOut(new PrintStream(os));
//        Reflection.main(new String[]{ "-E", "java.time," });
//        String output = os.toString("UTF-8");
//        Assertions.assertEquals("{'java':{'tag':'PACKAGE','subpackages':['applet','lang','time','rmi','util','nio','io','awt','net','math','security','text','beans','sql',],'classes':[]},}", output);
//    }


    @Test public void jdkVersion() {
        Assertions.assertEquals(8, Reflection.jdkVersion("1.8"));
        Assertions.assertEquals(13, Reflection.jdkVersion("13"));
    }
}
