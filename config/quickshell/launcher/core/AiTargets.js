.pragma library

// Hand a prompt to an assistant without the clipboard. Every link below was
// verified upstream on 2026-09-06 by opening it and reading the window:
//
//   claude-desktop 1.40609.1   claude://claude.ai/new?q=<prompt>&surface=chat
//                              opens a new chat with the prompt in the composer.
//                              It is the link Anthropic's own GNOME search
//                              provider builds (resources/gnome-search-provider/
//                              searchProvider.js, LaunchSearch). The app rejects
//                              a q that starts with "/" (slash commands), so a
//                              leading slash is padded with a space.
//                              claude://code/new?q=<prompt> starts a Claude Code
//                              session the same way.
//   openai-codex-desktop       The Linux "ChatGPT" app is the Codex app.
//   26.901                     codex://threads/new?prompt=<prompt> opens a new
//                              Codex thread in the current project with the
//                              prompt in the composer. It is the link OpenAI's
//                              own login page uses. Handing it a chatgpt.com URL
//                              only opens a signed-out tab in its embedded
//                              browser, so browser mode uses the real browser.
//   chatgpt.com                ?prompt= prefills; ?q= sends immediately.
//   claude.ai                  /new?q= prefills; there is no auto-send form.
//
// Nothing here runs at query time except string building; activation is always
// an explicit Enter.

function encode(prompt) { return encodeURIComponent(String(prompt === undefined || prompt === null ? "" : prompt)) }
function encodeClaude(prompt) {
  var text = String(prompt === undefined || prompt === null ? "" : prompt)
  return encode(text.charAt(0) === "/" ? " " + text : text)
}

function claudeDesktopUrl(prompt) { return "claude://claude.ai/new?q=" + encodeClaude(prompt) + "&surface=chat" }
function claudeCodeUrl(prompt) { return "claude://code/new?q=" + encodeClaude(prompt) }
function codexDesktopUrl(prompt) { return "codex://threads/new?prompt=" + encode(prompt) }
function claudeWebUrl(prompt) { return "https://claude.ai/new?q=" + encodeClaude(prompt) }
function chatgptWebUrl(prompt, autoSend) { return "https://chatgpt.com/?" + (autoSend ? "q=" : "prompt=") + encode(prompt) }
function googleUrl(query) { return "https://www.google.com/search?q=" + encodeURIComponent(String(query || "").trim()).replace(/%20/g, "+") }

// Prefer the app's own launcher when it is on PATH (the scheme handler may not
// be registered in mimeapps.list); otherwise let xdg-open resolve the scheme.
function openLink(bin, url, available) {
  return available && available[bin] ? { type: "exec", argv: [bin, url] } : { type: "url", url: url }
}

// One row plan per assistant. `available` maps binary name -> true for
// claude-desktop, chatgpt (Codex app), claude (CLI) and codex (CLI).
function plan(assistant, mode, autoSend, available, prompt) {
  var avail = available || {}
  var claude = assistant === "claude"
  if (mode === "cli") {
    var cli = claude ? "claude" : "codex"
    if (avail[cli])
      return { id: assistant, target: cli + "-cli", title: claude ? "Ask Claude Code" : "Ask Codex",
               subtitle: "Terminal · new " + cli + " session with your prompt", verb: "Open terminal",
               effect: { type: "exec", argv: ["uwsm-app", "--", "ghostty", "-e", cli, "--", String(prompt === undefined || prompt === null ? "" : prompt)] } }
  }
  if (mode === "desktop") {
    if (claude && avail["claude-desktop"])
      return { id: assistant, target: "claude-desktop", title: "Ask Claude",
               subtitle: "Claude desktop · new chat, prompt ready to send", verb: "Open Claude",
               effect: openLink("claude-desktop", claudeDesktopUrl(prompt), avail) }
    if (!claude && avail["chatgpt"])
      return { id: assistant, target: "codex-desktop", title: "Ask Codex",
               subtitle: "Codex desktop · new thread, prompt ready to send", verb: "Open Codex",
               effect: openLink("chatgpt", codexDesktopUrl(prompt), avail) }
  }
  var why = mode === "browser" ? "" : (mode === "cli" ? " · CLI not installed" : " · desktop app not installed")
  if (claude)
    return { id: assistant, target: "claude-web", title: "Ask Claude",
             subtitle: "claude.ai · prompt ready to send" + why, verb: "Open Claude",
             effect: { type: "url", url: claudeWebUrl(prompt) } }
  return { id: assistant, target: "chatgpt-web", title: "Ask ChatGPT",
           subtitle: "chatgpt.com · " + (autoSend ? "sends your prompt" : "prompt ready to send") + why, verb: "Open ChatGPT",
           effect: { type: "url", url: chatgptWebUrl(prompt, autoSend) } }
}
