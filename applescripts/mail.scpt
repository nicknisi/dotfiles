#!/usr/bin/osascript
property defaultAccount : "Pollen"
property defaultMailbox : "INBOX"

on run args
  set justUnread to false
  set theAccount to missing value
  set theMailbox to missing value

  if defaultAccount = missing value then set defaultAccount to "-g"
  if defaultMailbox = missing value then set defaultMailbox to "INBOX"

  set theCount to the count of args

  if theCount > 0 then
    if item 1 of args = "-u" then
      set justUnread to true
      set theCount to theCount - 1
      set args to the rest of args
    else if item 1 of args = "-ug" or item 1 of args = "-gu" then
      set justUnread to true
      set item 1 of args to "-g"
    else if theCount > 1 and ¬
            item 1 of args = "-g" and item 2 of args = "-u" then
      set justUnread to true
      set theCount to theCount - 1
      set args to the rest of args
      set item 1 of args to "-g"
    end if
  end if

  tell application "Mail"
    if theCount = 0 then
      set theAccount to defaultAccount
      set theMailbox to defaultMailbox
    else if theCount = 1 then
      set theAccount to item 1 of args
      set theMailbox to defaultMailbox
    else if theCount = 2 then
      set theAccount to item 1 of args
      set theMailbox to item 2 of args
    else
      error character id 10 ¬
          & "Usage: inbox-count [-u] [[account] mailbox]" & character id 10 ¬
          & "       inbox-count [-u] -g [mailbox]"
    end if

    set mailboxValue to missing value
    if theAccount = "-g" then
      if theMailbox = "INBOX" then
        set mailboxValue to inbox
      else
        set mailboxValue to mailbox theMailbox
      end if
    else
      set mailboxValue to mailbox theMailbox of account theAccount
    end if

    if justUnread then
      return the unread count of mailboxValue
    else
      return the count of messages of mailboxValue
    end if
  end tell
end run
