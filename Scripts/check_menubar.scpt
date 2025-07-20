-- Simple script to check if our menu bar item exists
tell application "System Events"
    try
        set menuBarItems to menu bar items of menu bar 1 of application process "SystemUIServer"
        set itemCount to count of menuBarItems
        log "Total menu bar items: " & itemCount
        
        repeat with i from 1 to itemCount
            try
                set menuBarItem to item i of menuBarItems
                set itemTitle to title of menuBarItem
                if itemTitle is not "" then
                    log "Menu bar item " & i & ": " & itemTitle
                    if itemTitle contains ":" then
                        log "*** Found timer item: " & itemTitle & " ***"
                    end if
                end if
            on error errMsg
                log "Error getting item " & i & ": " & errMsg
            end try
        end repeat
        
        return "Check complete"
    on error errMsg
        return "Error: " & errMsg
    end try
end tell
