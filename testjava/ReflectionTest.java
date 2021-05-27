import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.io.UnsupportedEncodingException;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

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

    @Test
    public void returns_expected_info_for_javatime_package() throws UnsupportedEncodingException {
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        System.setOut(new PrintStream(os));
        Reflection.main(new String[]{ "-E", "java.time" });
        String output = os.toString("UTF-8");
        Assertions.assertEquals("{'java.time':{'tag':'PACKAGE','subpackages':['zone','chrono','temporal','format',],'classes':['Duration','Month','LocalDate','OffsetDateTime','Clock','ZoneId','MonthDay','LocalDateTime','LocalTime','Instant','YearMonth','Period','Year','ZoneRegion','DayOfWeek','ZoneOffset','DateTimeException','ZonedDateTime','Ser','OffsetTime',]},}", output);
    }

    @Test
    public void packages_under_javatime() throws IOException {
        Assumptions.assumeTrue(Reflection.jdkVersion() > 8);
        List<String> list = Reflection.findPackagesUnder("java.time");
        System.out.println(list.size());
        Assertions.assertFalse(list.isEmpty());
    }

    @Test
    public void classes_under_javatime() throws IOException {
        Assumptions.assumeTrue(Reflection.jdkVersion() > 8);
        List<String> list = Reflection.findClassesUnder("java.time");
        Assertions.assertTrue(list.contains("Duration"));
    }

    @Test public void jdkVersion() {
        Assertions.assertEquals(8, Reflection.jdkVersion("1.8"));
        Assertions.assertEquals(13, Reflection.jdkVersion("13"));
    }
}