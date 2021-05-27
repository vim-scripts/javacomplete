import org.junit.jupiter.api.Test;

public class ReflectionTest {

    @Test
    public void do_not_fail_on_info_about_package() {
        Reflection.main(new String[]{ "-E", "java" });
    }
    
}
