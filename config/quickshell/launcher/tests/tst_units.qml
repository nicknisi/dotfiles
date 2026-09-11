import QtQuick
import QtTest
import "../core/Units.js" as Units
import "../core/Colors.js" as Colors

TestCase {
    name: "Units"
    function test_units_and_dimensions() {
        fuzzyCompare(Units.convert("2m in feet").value, 6.561679790026246, 1e-9)
        compare(Units.convert("32 F to C").value, 0)
        compare(Units.convert("1 GiB in MiB").value, 1024)
        compare(Units.formatValue(Units.convert("2m in feet").value), "6.56167979")
        var threw = false
        try { Units.convert("1 kg in m") } catch (e) { threw = true }
        verify(threw)
        threw = false
        try { Units.convert("-1 K to C") } catch (e2) { threw = true }
        verify(threw)
    }
    function test_time_gate() {
        verify(Units.isTimeQuery("10 am in London"))
        verify(Units.isTimeQuery("11 pm in new york to tokyo on 2026-09-06"))
        verify(Units.isTimeQuery("10am pt"))
        verify(Units.isTimeQuery("10:30pm est"))
        verify(Units.isTimeQuery("10.30 in london"))
        verify(Units.isTimeQuery("10 a.m. pt"))
        verify(Units.isTimeQuery("1530 utc"))
        verify(Units.isTimeQuery("noon utc to pt"))
        verify(Units.isTimeQuery("10 in london"))
        verify(Units.isTimeQuery("tomorrow 10am pt"))
        verify(Units.isTimeQuery("10am utc+2"))
        verify(Units.isTimeQuery("now in london"))
        verify(Units.isTimeQuery("what time is it in tokyo"))
        verify(Units.isTimeQuery("london time"))
        verify(!Units.isTimeQuery("2m in feet"))
        verify(!Units.isTimeQuery("chrome"))
        verify(!Units.isTimeQuery("10am"))
        verify(!Units.isTimeQuery("10:30"))
        verify(!Units.isTimeQuery("10 amsterdam"))
        verify(!Units.isTimeQuery("chrome 2026"))
        verify(!Units.isTimeQuery("128 * 1.24"))
    }
    function test_colors() {
        var c = Colors.parse("#ff6644")
        compare(c.values[0].text, "#FF6644")
        compare(c.values[1].text, "rgb(255, 102, 68)")
        compare(c.values[2].text, "hsl(11, 100%, 63%)")
        compare(Colors.parse("fa8").values[0].text, "#FFAA88")
        compare(Colors.parse("123456"), null)   // digits only without # is a number, not a color
        compare(Colors.parse("#123456").values[0].text, "#123456")
    }
}
