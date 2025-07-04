-- AppleScript to test menu bar functionality
tell application "System Events"
    -- Get all menu bar items
    set menuBarItems to menu bar items of menu bar 1 of application process "SystemUIServer"
    
    -- Look for our timer menu bar item
    repeat with menuBarItem in menuBarItems
        try
            set itemTitle to title of menuBarItem
            if itemTitle contains ":" then
                log "Found timer menu bar item with title: " & itemTitle
                -- Click the menu bar item
                click menuBarItem
                delay 1
                return "Successfully clicked timer menu bar item"
            end if
        on error
            -- Skip items that don't have titles
        end try
    end repeat
    
    return "Timer menu bar item not found"
end tell
