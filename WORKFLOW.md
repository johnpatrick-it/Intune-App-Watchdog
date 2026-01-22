# Intune App Watchdog - Complete Workflow

Let me break down how this system works from start to finish:

## 🎯 The Big Picture

```
You deploy apps to Intune → System monitors for updates → Alerts you → You deploy updates
```

---

## 📋 One-Time Setup (What We Just Did)

### 1. Import Your Intune Apps
```powershell
.\Import-FromIntuneCSV.ps1 -CSVPath "C:\Users\...\Client apps_2026-01-22.csv"
```

**What happens:**
- Reads your Intune CSV export
- Filters apps with "PH -" prefix (your Philippines scope)
- Only includes Windows apps that are "Assigned"
- Only includes apps with version numbers
- Creates `Config/monitoring-config.json` with 53 apps

**Result:** Your app inventory is now tracked (53 apps found)

---

### 2. Set Up Notifications (Power Automate)
```powershell
# Follow the guide:
notepad PowerAutomate\SETUP-GUIDE.md
```

**What you'll create:**
- A Power Automate Desktop flow that watches the `Output` folder
- When `findings.json` appears → sends email & Teams message
- Uses your logged-in Outlook/Teams (no passwords needed!)

---

### 3. Enable Daily Automation
```powershell
# Run as Administrator:
.\Setup-MonitoringTask.ps1
```

**What happens:**
- Creates a Windows Scheduled Task
- Runs every day at 8:00 AM
- Executes `Monitor-IntuneApps.ps1` automatically

---

## 🔄 Daily Workflow (Automated)

### Every Morning at 8:00 AM

**Step 1: Scheduled Task Triggers**
```
Windows Task Scheduler → Runs Monitor-IntuneApps.ps1
```

**Step 2: Check Each App** (53 apps)
```powershell
For each app in Config/monitoring-config.json:
  1. Load the app plugin (e.g., Chrome.ps1, NodeJS.ps1)
  2. Query the internet for latest version
     - Chrome → Google Chrome API
     - Node.js → Node.js official API
     - Firefox → Mozilla API
     - Git → GitHub releases
     - Others → Generic plugin (no check)
  3. Compare latest version vs current version
  4. Check if update is significant (major/minor)
  5. If CVE checking enabled → Query vulnerability database
```

**Step 3: Decide What to Report**

Based on thresholds in config:
```json
{
  "notifyOnMinorUpdates": false,     // 1.1.0 → 1.1.1 = silent
  "notifyOnMajorUpdates": true,      // 1.1.0 → 1.2.0 = notify!
  "notifyOnSecurityUpdates": true    // CVE found = notify!
}
```

**Step 4A: No Updates Found**
```
✅ All apps up to date
→ No findings.json created
→ No notification sent
→ Log saved to Logs/monitor-2026-01-22.log
→ Script exits
```

**Step 4B: Updates Found!**
```
⚠️ Chrome: 142.0.7444.163 → 144.0.7559.97 (Major)
⚠️ Firefox: 142.0.1.0 → 147.0.1 (Major)

→ Creates Output/findings.json with details
→ Saves log to Logs/monitor-2026-01-22.log
→ Script exits
```

**Step 5: Power Automate Flow Activates**
```
1. Power Automate Desktop detects findings.json
2. Reads the JSON file
3. Parses the update information
4. Sends email via Outlook:
   Subject: "Intune App Updates - 2 apps need attention"
   Body: Formatted list of updates with download links
5. Posts to Microsoft Teams:
   "🚨 Intune App Updates Available - 2 apps"
6. Moves findings.json to Output/Archive/
```

**Step 6: You Get Notified**
```
📧 Email in your inbox
💬 Teams message in your channel
```

---

## 👤 Your Manual Actions (When Notified)

### When You Receive an Alert

**1. Read the Notification**
```
Email/Teams says:
- Chrome needs update: 142.0.7444.163 → 144.0.7559.97
- Download link provided
```

**2. Download New Version**
- Click the download link in email
- Get the installer (e.g., `ChromeStandaloneSetup64.exe`)

**3. Package for Intune** (Your Existing Process)
- Use your Win32 app packaging tool
- Create `.intunewin` package
- Upload to Intune Admin Center
- Assign to your "PH -" device groups

**4. Deploy via Intune**
- Test on pilot group
- Deploy to production
- Monitor deployment status

**5. Update the Monitoring System**
```powershell
.\Update-AppVersion.ps1 -AppName "Google Chrome" -NewVersion "144.0.7559.97"
```

**What this does:**
- Updates `Config/monitoring-config.json`
- Sets Chrome's currentVersion to "144.0.7559.97"
- Next day's check won't alert for this version anymore

---

## 📊 Example: Full Cycle for Chrome Update

### Day 1 - Morning (Automated)
```
08:00 AM → Scheduled task runs
08:00 AM → Checks Chrome: Current=142.0.7444.163, Latest=144.0.7559.97
08:00 AM → Major update detected!
08:00 AM → Creates findings.json
08:01 AM → Power Automate sends notification
08:05 AM → You receive email & Teams message
```

### Day 1 - Afternoon (Manual)
```
02:00 PM → You download Chrome 144.0.7559.97
02:30 PM → You package for Intune
03:00 PM → You upload to Intune
03:15 PM → You deploy to pilot group
04:00 PM → Pilot deployment successful
```

### Day 2 - Morning (Manual)
```
09:00 AM → You deploy to production
10:00 AM → Production deployment starts
11:00 AM → You update the monitoring config:
           .\Update-AppVersion.ps1 -AppName "Google Chrome" -NewVersion "144.0.7559.97"
```

### Day 3 - Morning (Automated)
```
08:00 AM → Scheduled task runs
08:00 AM → Checks Chrome: Current=144.0.7559.97, Latest=144.0.7559.97
08:00 AM → ✅ Up to date! No alert needed
08:00 AM → Script exits quietly
```

---

## 🔧 How Each Component Works

### Monitor-IntuneApps.ps1 (Main Script)
```
1. Load Config/monitoring-config.json
2. For each enabled app:
   a. Find matching plugin (AppPlugins/AppName.ps1)
   b. Execute plugin → gets latest version
   c. Compare versions
   d. Check CVEs (if enabled)
   e. Add to findings if update needed
3. If findings exist:
   a. Create Output/findings.json
   b. Power Automate takes over
4. Update State/last-run.json
5. Write Logs/monitor-YYYY-MM-DD.log
```

### App Plugins (Version Checkers)
```powershell
# Example: AppPlugins/Chrome.ps1
1. Receives currentVersion parameter
2. Queries Google Chrome API
3. Gets latest stable version
4. Returns:
   - LatestVersion
   - DownloadUrl
   - ReleaseNotes
```

### findings.json (Communication File)
```json
{
  "timestamp": "2026-01-22T08:00:00",
  "summary": {
    "totalApps": 53,
    "appsNeedingUpdate": 2,
    "criticalCVEs": 0
  },
  "findings": [
    {
      "app": "PH - Google Chrome",
      "currentVersion": "142.0.7444.163",
      "latestVersion": "144.0.7559.97",
      "updateType": "Major",
      "downloadUrl": "https://www.google.com/chrome/...",
      "cves": []
    }
  ]
}
```

### Power Automate Desktop Flow
```
Trigger: Watch Output folder for findings.json
↓
Action 1: Read findings.json
↓
Action 2: Parse JSON
↓
Action 3: Format email HTML
↓
Action 4: Send email via Outlook
↓
Action 5: Post to Teams
↓
Action 6: Archive findings.json
```

---

## 🎛️ Control & Customization

### Run Manually Anytime
```powershell
# Check for updates right now
.\Monitor-IntuneApps.ps1

# Test without sending notifications
.\Monitor-IntuneApps.ps1 -DryRun

# Send test notification
.\Monitor-IntuneApps.ps1 -TestNotifications
```

### Disable/Enable Apps
Edit `Config/monitoring-config.json`:
```json
{
  "name": "Chrome",
  "enabled": false,  // ← Disable Chrome monitoring
  "checkCVEs": true
}
```

### Change Notification Thresholds
```json
{
  "thresholds": {
    "notifyOnMinorUpdates": true,   // ← Change to true = more alerts
    "notifyOnMajorUpdates": true,
    "notifyOnSecurityUpdates": true
  }
}
```

### Change Schedule Time
```powershell
# Run task at 9 AM instead
.\Setup-MonitoringTask.ps1 -RunTime "09:00"
```

---

## 📁 Files & Their Purpose

| File | Purpose | When Used |
|------|---------|-----------|
| `Import-FromIntuneCSV.ps1` | Import apps from Intune export | Setup only (or when you re-import) |
| `Monitor-IntuneApps.ps1` | Main monitoring engine | Every day at 8 AM (automated) |
| `Update-AppVersion.ps1` | Update app version after deployment | After you deploy each update (manual) |
| `Setup-MonitoringTask.ps1` | Create scheduled task | Setup only |
| `Config/monitoring-config.json` | Your app inventory | Read by Monitor script, updated by Update script |
| `AppPlugins/*.ps1` | Version checkers | Called by Monitor script |
| `Output/findings.json` | Alert trigger file | Created when updates found |
| `Logs/monitor-*.log` | Audit trail | Every run |
| `State/last-run.json` | Run tracking | Every run |

---

## ❓ Common Scenarios

### "I deployed a new app to Intune"
```powershell
# Re-import from fresh CSV export
.\Import-FromIntuneCSV.ps1 -CSVPath "path\to\new\export.csv"
```

### "I want to stop monitoring Chrome temporarily"
Edit `Config/monitoring-config.json`, set Chrome's `enabled: false`

### "I want alerts for minor updates too"
Edit `Config/monitoring-config.json`, set `notifyOnMinorUpdates: true`

### "The scheduled task didn't run"
```powershell
# Check task status
Get-ScheduledTask -TaskName "Intune App Monitor - Daily Check"

# Run manually
Start-ScheduledTask -TaskName "Intune App Monitor - Daily Check"
```

### "I want to see what would happen without sending alerts"
```powershell
.\Monitor-IntuneApps.ps1 -DryRun
```

---

## 🎯 Summary: The Complete Loop

```
┌─────────────────────────────────────────────────────────┐
│                   AUTOMATED DAILY                        │
│  8:00 AM → Check 53 apps → Updates found? → Alert you   │
└─────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────┐
│                     YOU (MANUAL)                         │
│  Download → Package → Upload → Deploy to Intune         │
└─────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────┐
│                  UPDATE CONFIG (MANUAL)                  │
│  .\Update-AppVersion.ps1 -AppName "X" -NewVersion "Y"   │
└─────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────┐
│              NEXT DAY - NO MORE ALERTS                   │
│  System knows you deployed → No duplicate notifications │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start Checklist

- [ ] Import apps from CSV
- [ ] Review `Config/monitoring-config.json`
- [ ] Test dry run: `.\Monitor-IntuneApps.ps1 -DryRun`
- [ ] Set up Power Automate Desktop flow
- [ ] Test notifications: `.\Monitor-IntuneApps.ps1 -TestNotifications`
- [ ] Verify email and Teams alerts received
- [ ] Create scheduled task: `.\Setup-MonitoringTask.ps1`
- [ ] Wait for first automated run (next day 8 AM)
- [ ] When alerted, deploy updates and run `.\Update-AppVersion.ps1`

---

## 📞 Troubleshooting

**No notifications received?**
1. Check logs: `Get-Content .\Logs\monitor-$(Get-Date -Format 'yyyy-MM-dd').log`
2. Check if findings.json exists: `dir .\Output\`
3. Verify Power Automate Desktop is running
4. Test: `.\Monitor-IntuneApps.ps1 -TestNotifications`

**Plugin errors?**
1. Check internet connection
2. Test plugin directly: `.\AppPlugins\Chrome.ps1 -CurrentVersion "142.0.0"`
3. Check for API rate limits

**Scheduled task not running?**
1. Open Task Scheduler: `taskschd.msc`
2. Check task history for errors
3. Run manually to test
4. Verify your laptop was on at 8 AM

---

**Last Updated:** 2026-01-22
**Version:** 1.0
**Apps Monitored:** 53 (PH - prefix)
