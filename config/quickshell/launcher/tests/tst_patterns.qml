import QtQuick
import QtTest
import "../core/Patterns.js" as Patterns

TestCase {
    name: "Patterns"

    function test_compile_keeps_valid_patterns_and_reports_the_rest() {
        var c = Patterns.compile([
            { id: "assignment", regex: "^\\s*[a-z_]\\w*\\s*=\\s*\\S", flags: "i", boost: 12, example: "price = 10" },
            { id: "broken", regex: "(unclosed" },
            { id: "flags", regex: "x", flags: "g" },
            { id: "missing" },
            "not an object",
            { regex: "\\d%", boost: "7" },
            { id: "huge", regex: "a", boost: 1e9 },
            { id: "negative", regex: "b", boost: -4 }
        ])
        compare(c.patterns.map(function(p) { return p.id }), ["assignment", "pattern-5", "huge", "negative"])
        compare(c.patterns[0].boost, 12)
        compare(c.patterns[0].example, "price = 10")
        compare(c.patterns[1].boost, 7)
        compare(c.patterns[2].boost, 100)
        compare(c.patterns[3].boost, 0)
        compare(c.errors.length, 4)
        verify(c.errors[0].indexOf("broken") === 0)
        verify(c.errors[1].indexOf("flags") === 0)
        verify(c.errors[2].indexOf("missing") === 0)
        verify(c.errors[3].indexOf("pattern 4") === 0)
    }

    function test_compile_accepts_nothing_and_regexp_objects() {
        compare(Patterns.compile(undefined).patterns.length, 0)
        compare(Patterns.compile(undefined).errors.length, 0)
        compare(Patterns.compile(null).errors.length, 0)
        compare(Patterns.compile("oops").errors, ["patterns must be an array"])
        var c = Patterns.compile([{ id: "re", regex: /now\s*[+-]/i, boost: 3 }])
        compare(c.errors.length, 0)
        compare(Patterns.evaluate(c.patterns, "NOW + 90 days").matched, ["re"])
    }

    function test_compile_caps_the_list_and_the_regex_length() {
        var many = []
        for (var i = 0; i < 80; i++) many.push({ id: "p" + i, regex: "a" })
        compare(Patterns.compile(many).patterns.length, 64)
        var long = ""
        for (var j = 0; j < 401; j++) long += "a"
        var c = Patterns.compile([{ id: "long", regex: long }])
        compare(c.patterns.length, 0)
        verify(c.errors[0].indexOf("longer") > 0)
    }

    function test_evaluate_reports_matches_and_the_largest_boost() {
        var c = Patterns.compile([
            { id: "assignment", regex: "^\\s*[a-z_]\\w*\\s*=\\s*\\S", flags: "i", boost: 12 },
            { id: "currency", regex: "[$€£]\\s*\\d", boost: 10 },
            { id: "percent", regex: "\\d\\s*%", boost: 8 }
        ]).patterns
        compare(Patterns.evaluate(c, "price = $10 - 5%"), { matched: ["assignment", "currency", "percent"], boost: 12 })
        compare(Patterns.evaluate(c, "$120 - 30%"), { matched: ["currency", "percent"], boost: 10 })
        compare(Patterns.evaluate(c, "firefox"), { matched: [], boost: 0 })
        compare(Patterns.evaluate(c, ""), { matched: [], boost: 0 })
        compare(Patterns.evaluate([], "price = 10"), { matched: [], boost: 0 })
        compare(Patterns.evaluate(undefined, "price = 10"), { matched: [], boost: 0 })
    }

    function test_evaluate_is_stable_across_calls_with_sticky_flags() {
        // A pattern compiled from a RegExp with the global flag must not keep lastIndex between queries.
        var c = Patterns.compile([{ id: "g", regex: /\d+/g }]).patterns
        compare(c.length, 0)   // g is refused outright, so no state can leak
        var d = Patterns.compile([{ id: "digits", regex: "\\d+" }]).patterns
        compare(Patterns.evaluate(d, "a1").matched, ["digits"])
        compare(Patterns.evaluate(d, "a1").matched, ["digits"])
    }

    function test_examples_lists_declared_examples_in_order() {
        var c = Patterns.compile([
            { id: "a", regex: "a", example: "price = 10" },
            { id: "b", regex: "b" },
            { id: "c", regex: "c", example: "$120 - 30%" }
        ]).patterns
        compare(Patterns.examples(c), ["price = 10", "$120 - 30%"])
        compare(Patterns.examples(c, 1), ["price = 10"])
        compare(Patterns.examples([]), [])
    }
}
