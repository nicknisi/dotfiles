import QtQuick
import QtTest
import "../core/Match.js" as Match
import "../core/Frecency.js" as Frecency
import "../core/Files.js" as Files
import "../core/SmartMatch.js" as Smart

TestCase {
    name: "MatchAndRank"
    readonly property string aiPath: "Keystroke Settings › AI & Web Search › Preferred assistant"
    readonly property string aiKeywords: "provider chatgpt claude"

    function test_word_starts_and_exact_titles_rank_first() {
        verify(Match.match("chrome", "Google Chrome") > 95)
        verify(Match.match("chrome", "Chrome") > Match.match("chrome", "Google Chrome"))          // exact title bonus
        verify(Match.match("Calculator", "Calculator") > 115)
        verify(Match.match("code", "Visual Studio Code") > 95)
        verify(Match.match("vsc", "Visual Studio Code") > 60)                                       // initials
        compare(Match.match("chrome", "Chromium"), 0)
        compare(Match.match("chrome", "Keystroke Settings", "preferences configuration"), 0)
        compare(Match.match("zzz", "Google Chrome"), 0)
        compare(Match.match("", "Anything"), 1)
        compare(Match.match("   ", "Anything"), 1)
    }
    function test_gaps_and_mid_word_letters_cost_points() {
        var prefix = Match.match("chrom", "Google Chrome")
        var typo = Match.match("chroe", "Google Chrome")
        var scattered = Match.match("cme", "Chrome")
        verify(typo > 0 && typo < prefix)
        verify(scattered > 0 && scattered < typo)
        compare(Match.match("e", "Google Chrome"), 0)                                               // a lone mid-word letter is noise
        verify(Match.match("e", "Emoji Picker") > 95)
        verify(Match.match("Ünïcode", "ünïCODE stuff") > 95)
    }
    function test_paths_and_keywords_are_searchable_but_rank_below_titles() {
        var onTitle = Match.match("assist", "Preferred assistant", aiKeywords, aiPath)
        var viaPath = Match.match("keystroke", "Preferred assistant", aiKeywords, aiPath)
        var viaKeywords = Match.match("chatgpt", "Preferred assistant", aiKeywords, aiPath)
        verify(onTitle > viaPath)
        verify(viaPath > viaKeywords)
        verify(viaKeywords > 0)
        verify(Match.match("chrom", "Google Chrome") > Match.match("chrom", "Default browser", "Chrome"))
    }
    function test_abbreviations_walk_the_breadcrumb() {
        var abbreviations = ["prefp", "keysepro", "setaiprv", "kspa", "ai prov", "prov ai"]
        for (var i = 0; i < abbreviations.length; i++)
            verify(Match.match(abbreviations[i], "Preferred assistant", aiKeywords, aiPath) > 0, abbreviations[i])
        compare(Match.match("ai prov", "Preferred assistant", aiKeywords, aiPath), Match.match("prov ai", "Preferred assistant", aiKeywords, aiPath))
        compare(Match.match("prefp", "Power profiles", "", "Setup › Power › Power profiles"), 0)
        verify(Match.match("sysshut", "Shutdown", "", "System › Shutdown") > 80)
        verify(Match.match("shutdown", "Shutdown", "", "System › Shutdown") > 115)
    }
    function test_descriptions_match_by_whole_word_only() {
        var prose = "Uses Omarchy's existing history"
        compare(Match.match("chrome", "Clipboard History", "clipboard", "", prose), 0)                // scattered letters in prose never match
        verify(Match.match("exist", "Clipboard History", "clipboard", "", prose) > 0)                 // a word prefix does
        verify(Match.match("exist", "Clipboard History", "clipboard", "", prose) < Match.match("clip", "Clipboard History"))
        compare(Match.match("e", "Clipboard History", "", "", prose), 0)                              // single letters do not search prose
        verify(Match.match("omarchy hist", "Clipboard History", "", "", prose) > 0)
        verify(Match.match("browser", "Google Chrome", "", "", "Web Browser Access the Internet") > 0)
        compare(Match.match("chrome", "Browser", "", "Keystroke Settings › AI & Web Search › Open conversations in › Browser", "mode"), 0)
    }
    function test_tiers_dominate_scores_and_frecency() {
        var rows = [
            {title: "Search Google", tier: "fallback", score: 999},
            {title: "Google Chrome", tier: "item", score: 50, key: "chrome"},
            {title: "Chromium", tier: "item", score: 60},
            {title: "145", tier: "answer", score: 1}
        ]
        var ranked = Match.rank(rows, function(r) { return r.key === "chrome" ? 36 : 0 })
        compare(ranked.map(function(r) { return r.title }), ["145", "Google Chrome", "Chromium", "Search Google"])
        var unlearned = Match.rank(rows, null)
        compare(unlearned[1].title, "Chromium")
    }
    function test_frecency_halves_in_two_weeks_and_prunes() {
        var now = 1800000000
        var k = Frecency.key("apps", "chrome")
        compare(k.length, 32)
        var entries = Frecency.record({}, k, now)
        entries = Frecency.record(entries, k, now)
        compare(Frecency.weight(entries, k, now), 2)
        fuzzyCompare(Frecency.weight(entries, k, now + Frecency.HALF_LIFE), 1, 1e-9)
        var reparsed = Frecency.parse(Frecency.serialize(entries))
        fuzzyCompare(Frecency.weight(reparsed, k, now + Frecency.HALF_LIFE), 1, 1e-9)
        verify(Frecency.serialize(entries).indexOf("chrome") < 0)
        compare(Frecency.parse("{ broken"), ({}))
        verify(Frecency.bonus(entries, k, now) <= 36)
        compare(Frecency.bonus(entries, "", now), 0)
    }
    function test_query_learning_overcomes_file_discount_after_one_selection() {
        var now = 1800000000, query = "downlo"
        var folder = {uid:"files/downloads",providerKey:"files",id:"downloads",title:"Downloads",tier:"item",
                      score:Files.score(query,{rel:"Downloads"}),action:{type:"open"}}
        var video = {uid:"hotkeys/video",providerKey:"hotkeys",id:"video",title:"Download video from web app",tier:"item",
                     score:Match.match(query,"Download video from web app"),action:{type:"hotkey",dispatcher:"exec",arg:"download-video"}}
        var window = {uid:"hotkeys/down",providerKey:"hotkeys",id:"down",title:"Expand window down a lot",tier:"item",
                      score:Match.match(query,"Expand window down a lot"),action:{type:"hotkey",dispatcher:"resizeactive",arg:"0 300"}}
        var rows = Smart.merge([video,window,folder],[video,window],Smart.request(query),[{id:window.uid,score:.9}])
        compare(Match.rank(rows,null)[0].id,"video")
        var globalKey = Frecency.key(folder.providerKey,folder.id)
        var learnedKey = Frecency.queryKey(folder.providerKey,folder.id,query,"")
        var entries = Frecency.record({},globalKey,now)
        entries = Frecency.record(entries,learnedKey,now)
        function boost(r) {
            return Frecency.bonus(entries,Frecency.key(r.providerKey,r.id),now)
              + Frecency.queryBonus(entries,Frecency.queryKey(r.providerKey,r.id,query,""),now)
        }
        compare(Match.rank(rows,boost)[0].id,"downloads")
        // Also works with embeddings off; the learned preference is the final pass.
        compare(Match.rank([video,window,folder],boost)[0].id,"downloads")
        entries = Frecency.parse(Frecency.serialize(entries))
        compare(Match.rank(rows,boost)[0].id,"downloads")
        compare(Frecency.queryBonus(entries,Frecency.queryKey("files","downloads","download video",""),now),0)
        compare(Frecency.queryBonus(entries,Frecency.queryKey("files","downloads",query,"files"),now),0)
        compare(Frecency.queryKey("files","downloads","  DOWNLO  ",""),learnedKey)
        compare(Frecency.queryKey("files","downloads","   ",""),"")
        verify(Frecency.serialize(entries).indexOf(query)<0)
        verify(Frecency.queryBonus(entries,learnedKey,now+Frecency.HALF_LIFE)<Frecency.queryBonus(entries,learnedKey,now))
        for(var i=0;i<20;i++) entries=Frecency.record(entries,learnedKey,now)
        compare(Frecency.queryBonus(entries,learnedKey,now),108)
        var withAnswer = rows.concat([{id:"answer",tier:"answer",score:1},{id:"fallback",tier:"fallback",score:999}])
        compare(Match.rank(withAnswer,boost)[0].id,"answer")
        compare(Match.rank(withAnswer,boost).slice(-1)[0].id,"fallback")
    }
    function test_a_keystroke_over_a_full_menu_stays_fast() {
        var titles = [], paths = []
        for (var i = 0; i < 700; i++) {
            paths.push("Setup › Section " + (i % 17) + " › Item number " + i + " with some words")
            titles.push("Item number " + i + " with some words")
        }
        var queries = ["e", "se", "itm", "setnum", "prefp", "xq"]
        var started = Date.now(), hits = 0
        for (var r = 0; r < 20; r++)
            for (var q = 0; q < queries.length; q++)
                for (var j = 0; j < titles.length; j++) if (Match.match(queries[q], titles[j], "alias words", paths[j], "a longer description of the item")) hits++
        var perKeystroke = (Date.now() - started) / (20 * queries.length)
        console.log("Match: " + perKeystroke.toFixed(2) + " ms per keystroke over 700 rows (" + hits / 20 + " hits per six queries)")
        verify(perKeystroke < 40)
    }
}
