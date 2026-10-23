# Latest Notion note on Windows

`Open-LatestNotionNote.ps1` installs Notion's official CLI with WinGet, guides the
user through browser login, remembers a journal, and opens its newest entry
dated today or earlier in the default browser. It creates a **Latest Notion
Note** desktop shortcut for subsequent runs. This opens a regular browser tab,
not an installed Notion app; browser preferences determine tab/window behavior.

Requires Windows 10/11 x64, Windows PowerShell 5.1 or later, and WinGet (Microsoft
App Installer). The Notion account needs full membership in the journal's
workspace; the official CLI does not support guests or restricted members.

Download just **Open Latest Notion Note.cmd** and double-click it (no
administrator window needed). This one-file launcher downloads the PowerShell
script from a pinned commit, verifies its SHA-256 hash, and runs it. After the
first successful run, use **Latest Notion Note** on the desktop; the downloaded
launcher can be deleted. Subsequent desktop launches reuse the installed script.

Alternatively, download the `.ps1` directly and run it from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\Downloads\Open-LatestNotionNote.ps1"
```

First run opens the Notion login page. Verify the code printed in the terminal
before approving. For an unconfigured script, paste the journal's **database**
link when prompted. If the database has several data sources, select the journal
from the numbered list. The journal must have a date property named `Date`.

You can also supply a database link, a data source UUID, or a different property:

```powershell
.\Open-LatestNotionNote.ps1 -DatabaseUrl 'https://www.notion.so/<database-id>' -DateProperty 'Date'
.\Open-LatestNotionNote.ps1 -DataSourceId '<data-source-uuid>'
```

To change a saved journal, add `-Setup` and pass the new settings. `-PrintUrl`
performs setup and the live query but prints the URL without opening the note or
creating a desktop shortcut.

Journal settings and a copy of the script live in
`%LOCALAPPDATA%\NotionDailyNote`. Notion CLI manages credentials in the Windows
credential store. The script never copies an existing user's login token. The
execution-policy option applies to that PowerShell process only; it does not
change the machine's execution policy. A managed policy may still block scripts.

For a friend using the same journal, make a local copy of the `.cmd` with the
empty `-DataSourceId ''` argument filled in. Keep that private copy out of Git.
The friend still completes their own browser login once; future shortcut
launches reuse the saved credentials and query the journal afresh. When updating
the `.ps1`, update the launcher's pinned commit and expected hash together.

Official references: [CLI installation](https://developers.notion.com/cli/get-started/installation),
[CLI authentication](https://developers.notion.com/cli/get-started/authentication),
and [WinGet installation options](https://learn.microsoft.com/en-us/windows/package-manager/winget/install).
