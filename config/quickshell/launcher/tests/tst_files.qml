import QtQuick
import QtTest
import "../core/Files.js" as Files

TestCase {
    name: "Files"
    property string home: "/home/me"
    property var both: ({ files: true, folders: true, hidden: false, limit: 10 })
    property string output: "/home/me/Documents/report.pdf\u0000/home/me/Documents/reports/\u0000/home/me/Pictures/report-cover.png\u0000" +
                            "/home/me/src/tool/docs/README.md\u0000/home/me/notes/weekly report notes.md\u0000/home/me/Documents/reports/budget.xlsx\u0000\u0000"

    function test_short_or_disabled_queries_never_spawn() {
        compare(Files.cacheKey("", both), null)
        compare(Files.cacheKey("r", both), null)
        compare(Files.cacheKey("  ", both), null)
        compare(Files.cacheKey("re", { files: false, folders: false, limit: 10 }), null)
        verify(Files.cacheKey("re", both) !== null)
        // The key ignores the limit and the scope; it changes with the kinds and the hidden flag.
        compare(Files.cacheKey("Report  PDF", both), Files.cacheKey("report pdf", { files: true, folders: true, limit: 3 }))
        verify(Files.cacheKey("re", both) !== Files.cacheKey("re", { files: true, folders: true, hidden: true }))
        verify(Files.cacheKey("re", both) !== Files.cacheKey("re", { files: true, folders: false }))
    }

    function test_prefix_and_search_modes() {
        compare(Files.request("~dwnlds",both,false).query,"dwnlds")
        compare(Files.request(" ~/docs rpt ",both,false).query,"docs rpt")
        verify(Files.request("dwnlds",both,false).settings.fuzzy)
        var literal = Object.assign({},both,{searchMode:"literal"})
        verify(!Files.request("dwnlds",literal,false).settings.fuzzy)
        verify(Files.request("~dwnlds",literal,false).settings.fuzzy)
        var prefix = Object.assign({},both,{searchMode:"prefix"})
        verify(!Files.request("dwnlds",prefix,false).enabled)
        verify(Files.request("~dwnlds",prefix,false).enabled)
        verify(Files.request("dwnlds",prefix,true).settings.fuzzy)
        compare(Files.cacheKey("x".repeat(129),both),null)
        compare(Files.cacheKey("bad\u0000name",both),null)
    }

    function test_fuzzy_candidates_and_filename_safety() {
        var fuzzy = Object.assign({},both,{fuzzy:true})
        var entries = Files.parse("/home/me/Downloads/\u0000/home/me/Downloads/unrelated.pdf\u0000/home/me/Documents/report.pdf\u0000/home/me/line\nreport.pdf\u0000",home)
        compare(Files.rows("dwnlds",entries,both,false).length,0)
        compare(Files.rows("dwnlds",entries,fuzzy,false).map(function(r){return r.title}),["Downloads"])
        compare(Files.rows("dcmnts rpt",entries,fuzzy,false).map(function(r){return r.title}),["report.pdf"])
        compare(entries[3].path,"/home/me/line\nreport.pdf")
        compare(Files.argv("dwnlds",home,fuzzy).slice(-1)[0],"[^/]*d[^/]*w[^/]*n[^/]*l[^/]*d[^/]*s[^/]*/?$")
        verify(Files.argv("dwnlds",home,fuzzy).indexOf("--print0")>0)
        verify(Files.cacheKey("dwnlds",fuzzy)!==Files.cacheKey("dwnlds",both))
        // Regex syntax remains literal even in subsequence mode.
        var regex = new RegExp(Files.pattern("a+b",true))
        verify(regex.test("a long + and b")); verify(!regex.test("aaab"))
        var many=[]
        for(var i=0;i<400;i++) many.push({rel:"Documents/report-"+i+".pdf",path:home+"/Documents/report-"+i+".pdf",dir:false})
        var start=Date.now()
        for(var j=0;j<20;j++) Files.rows("dcmnts rpt",many,fuzzy,false)
        console.log("Files fuzzy scoring 400 candidates:", (Date.now()-start)/20, "ms/query")
    }

    function test_argv_is_literal_and_bounded() {
        var a = Files.argv("--version report.pdf", home, both)
        compare(a[0], "fd")
        verify(a.indexOf("--full-path") > 0)
        verify(a.indexOf("--max-results") > 0)
        compare(a[a.indexOf("--base-directory") + 1], home)
        // Earlier words ride on --and=, the last is anchored to the name after --; a dash never becomes a flag.
        compare(a.slice(-3), ["--and=\\-\\-version", "--", "[^/]*report\\.pdf[^/]*/?$"])
        compare(Files.argv("a+b (c)", home, both).slice(-1), ["[^/]*\\(c\\)[^/]*/?$"])
        verify(a.indexOf("--hidden") < 0)
        compare(Files.argv("x", home, { files: true, folders: false }).join(" ").indexOf("--type f --type d"), -1)
        compare(Files.argv("x", home, { files: false, folders: true }).join(" ").indexOf("--type d") > 0, true)
        var hidden = Files.argv("x", home, { files: true, folders: true, hidden: true })
        verify(hidden.indexOf("--hidden") > 0)
        compare(hidden[hidden.indexOf("--exclude") + 1], ".git")
    }

    function test_parse_strips_the_home_prefix_and_marks_folders() {
        var entries = Files.parse(output, home)
        compare(entries.length, 6)
        compare(entries[0], { path: "/home/me/Documents/report.pdf", rel: "Documents/report.pdf", dir: false })
        compare(entries[1], { path: "/home/me/Documents/reports", rel: "Documents/reports", dir: true })
        compare(Files.parse("/elsewhere/report.pdf\u0000/home/me/\u0000", home).length, 0)
        compare(Files.parse("/home/me/partial", home).length, 0)
    }

    function test_rows_rank_names_first_and_respect_the_limit() {
        var entries = Files.parse(output, home)
        var rows = Files.rows("report", entries, both, false)
        // budget.xlsx carries "report" only in its folder: the last word has to be in the name.
        compare(rows.length, 4)
        compare(rows[0].title, "report.pdf")
        for (var t = 0; t < rows.length; t++) verify(rows[t].title !== "budget.xlsx")
        compare(Files.rows("reports budget", entries, both, false).map(function(r) { return r.title }), ["budget.xlsx"])
        // An exact name outranks a name that merely contains the word.
        verify(Files.rows("reports", entries, both, false)[0].score > rows[rows.length - 1].score)
        for (var i = 0; i < rows.length; i++) {
            compare(rows[i].section, "Files")
            compare(rows[i].tier, "item")
            verify(rows[i].score <= 120 * 0.55 + 1)
            verify(rows[i].score >= 12)
        }
        compare(Files.rows("report", entries, { files: true, folders: true, limit: 2 }, false).length, 2)
        compare(Files.rows("report", entries, { files: true, folders: true, limit: 2 }, true).length, 4)
    }

    function test_kinds_and_relative_words_filter_rows() {
        var entries = Files.parse(output, home)
        var files = Files.rows("report", entries, { files: true, folders: false, limit: 10 }, false)
        for (var i = 0; i < files.length; i++) verify(files[i].title !== "reports")
        var folders = Files.rows("report", entries, { files: false, folders: true, limit: 10 }, false)
        compare(folders.length, 1)
        compare(folders[0].title, "reports")
        compare(folders[0].verb, "Open folder")
        // fd matched "home" against the absolute path; the relative part has to contain every word.
        compare(Files.rows("home", entries, both, false).length, 0)
        compare(Files.rows("report notes", entries, both, false).length, 1)
        compare(Files.rows("docs readme", entries, both, false)[0].title, "README.md")
    }

    function test_effects_open_files_folders_and_terminals() {
        var entries = Files.parse(output, home)
        var file = Files.rows("report.pdf", entries, both, false)[0]
        compare(file.action, { type: "exec", argv: ["xdg-open", "/home/me/Documents/report.pdf"] })
        compare(file.altAction.argv, ["uwsm-app", "--", "ghostty", "--working-directory=/home/me/Documents"])
        compare(file.subtitle, "~/Documents")
        compare(file.previewLabel, "FILE")
        verify(file.remember)
        var folder = Files.rows("reports", entries, both, false)[0]
        compare(folder.action.argv, ["xdg-open", "/home/me/Documents/reports"])
        compare(folder.altAction.argv[3], "--working-directory=/home/me/Documents/reports")
        compare(folder.subtitle, "~/Documents · Folder")
        compare(folder.previewLabel, "FOLDER")
        compare(folder.hint, "ctrl ↵ terminal")
        var image = Files.rows("cover", entries, both, false)[0]
        compare(image.previewImage, "/home/me/Pictures/report-cover.png")
        compare(file.previewImage, "")
    }
}
