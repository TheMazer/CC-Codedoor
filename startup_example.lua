currentScreen = term.current()
shell.run("codedoor/codedoor.lua")

-- Restoring Color Palette
term.setPaletteColor(colors.yellow, term.nativePaletteColor(colors.yellow))
term.setPaletteColor(colors.lightGray, term.nativePaletteColor(colors.lightGray))
term.setPaletteColor(colors.gray, term.nativePaletteColor(colors.gray))
term.setPaletteColor(colors.black, term.nativePaletteColor(colors.black))

-- Resetting Screen
term.redirect(currentScreen)
term.setTextColor(colors.yellow)
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
print(os.version())
term.setTextColor(colors.white)