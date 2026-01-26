# Nimtalk build script

import os, strutils

# Build the REPL
task "repl", "Build the Nimtalk REPL":
  exec "nimble build"

# Build tests
task "test", "Run tests":
  exec "nimble test"

# Clean build artifacts
task "clean", "Clean build artifacts":
  for dir in ["nimcache", "build"]:
    if dirExists(dir):
      removeDir(dir)
  # Clean binaries in various possible locations
  for binary in ["ntalk", "ntalkc"]:
    if fileExists(binary):
      removeFile(binary)
    if fileExists(binary & ".exe"):
      removeFile(binary & ".exe")
    # Clean from source tree structure
    if fileExists("nimtalk/repl/" & binary):
      removeFile("nimtalk/repl/" & binary)
    if fileExists("nimtalk/compiler/" & binary):
      removeFile("nimtalk/compiler/" & binary)

# Install binary
task "install", "Install Nimtalk":
  # Check multiple possible binary locations
  var binPath = ""
  for possiblePath in [
    getCurrentDir() / "ntalk",
    "nimtalk/repl/ntalk"
  ]:
    if fileExists(possiblePath):
      binPath = possiblePath
      break

  when defined(windows):
    if binPath == "":
      for possiblePath in [
        getCurrentDir() / "ntalk.exe",
        "nimtalk/repl/ntalk.exe"
      ]:
        if fileExists(possiblePath):
          binPath = possiblePath
          break

  if binPath == "":
    echo "Error: ntalk binary not found. Run 'nimble build' first."
    echo "Checked locations: ./ntalk, nimtalk/repl/ntalk"
    return

  let dest = getHomeDir() / ".local" / "bin" / "ntalk"
  when defined(windows):
    # On Windows, install to a common location
    let winDest = getHomeDir() / "ntalk" / "ntalk.exe"
    createDir(getHomeDir() / "ntalk")
    copyFile(binPath, winDest)
    echo "Installed to: " & winDest
  else:
    copyFile(binPath, dest)
    discard execShellCmd("chmod +x " & dest)
    echo "Installed to: " & dest
