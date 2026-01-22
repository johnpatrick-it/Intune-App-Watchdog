# Intune App Watchdog

Automated monitoring system for Intune-managed applications. Checks for updates and security vulnerabilities daily, with notifications via email and Microsoft Teams.

## What It Does

- ✅ Monitors 53 Intune apps (those with "PH -" prefix)
- ✅ Checks for new versions daily
- ✅ Scans for CVE security vulnerabilities
- ✅ Sends email and Teams notifications
- ✅ Runs automatically via scheduled task
- ✅ Logs all activity for auditing

## Quick Start

### 1. Initial Setup (One Time)

The system is already set up at `D:\intune-app-monitor` with:
- ✅ 53 apps imported from your Intune CSV
- ✅ Monitoring configuration created
- ✅ App plugins for version checking
- ✅ All necessary folders and scripts

### 2. Test the Monitoring

Run a dry-run to see what updates are available:

```powershell
cd D:\intune-app-monitor
.\Monitor-IntuneApps.ps1 -DryRun
```

This will check all apps but won't send notifications.

### 3. Set Up Notifications (Power Automate)

Follow the guide to create the Power Automate flow:

```powershell
notepad .\PowerAutomate\SETUP-GUIDE.md
```

Test notifications:

```powershell
.\Monitor-IntuneApps.ps1 -TestNotifications
```

Check your email and Teams for the test message.

### 4. Enable Daily Automation

Create a scheduled task to run daily at 8 AM:

```powershell
# Run as Administrator
.\Setup-MonitoringTask.ps1
```

## How It Works

### Daily Workflow

```
8:00 AM → Scheduled Task runs
        ↓
    Check all 53 apps for updates
        ↓
    Check for CVEs (security issues)
        ↓
    Updates found? → Yes → Create findings.json
                   ↓
            Power Automate detects file
                   ↓
            Send email & Teams notification
                   ↓
            You review and deploy updates
                   ↓
            Update version in config
```

### If No Updates

No findings file created = No notifications = Everything is up to date ✅

## Project Structure

```
D:\intune-app-monitor\
├── Monitor-IntuneApps.ps1              # Main monitoring script
├── Import-FromIntuneCSV.ps1            # Import apps from CSV
├── Update-AppVersion.ps1               # Update app versions after deployment
├── Setup-MonitoringTask.ps1            # Create scheduled task
├── Config\
│   └── monitoring-config.json          # Your app list (53 apps)
├── AppPlugins\                         # Version checking plugins
│   ├── NodeJS.ps1
│   ├── Chrome.ps1
│   ├── Firefox.ps1
│   ├── Git.ps1
│   ├── VSCode.ps1
│   ├── SSMS.ps1
│   └── Generic.ps1                     # Fallback for other apps
├── Output\
│   └── findings.json                   # Created when updates found
├── State\
│   └── last-run.json                   # Last run information
├── Logs\
│   └── monitor-YYYY-MM-DD.log          # Daily logs
└── PowerAutomate\
    └── SETUP-GUIDE.md                  # Power Automate setup instructions
```

## Common Tasks

### Check for Updates Manually

```powershell
.\Monitor-IntuneApps.ps1
```

### Update App Version After Deployment

After deploying a new version to Intune:

```powershell
.\Update-AppVersion.ps1 -AppName "Google Chrome" -NewVersion "144.0.7559.97"
```

### Re-import Apps from Intune CSV

If you make major changes to your Intune apps:

```powershell
.\Import-FromIntuneCSV.ps1 -CSVPath "C:\Users\ext_patrickh\Downloads\Client apps_YYYY-MM-DD.csv"
```

### View Recent Logs

```powershell
Get-Content .\Logs\monitor-$(Get-Date -Format 'yyyy-MM-dd').log
```

### Check What's Being Monitored

```powershell
Get-Content .\Config\monitoring-config.json | ConvertFrom-Json | Select-Object -ExpandProperty applications | Format-Table displayName, currentVersion, checkCVEs
```

## Currently Monitored Apps

53 apps with "PH -" prefix including:

**Development Tools:**
- Node.js (5 versions: 20.10.0, 22.18.0, 22.19.0, 24.5.0, 24.12.0)
- Git, GitHub Desktop, GitHub CLI
- Docker Desktop
- MongoDB, MongoDB Shell
- Python 3.13
- Visual Studio Code

**Browsers:**
- Google Chrome
- Mozilla Firefox

**Productivity:**
- Microsoft 365 Apps
- Power BI
- Zoom, Zoom Workplace

**Database & Cloud:**
- SQL Server Management Studio 22
- AWS CLI, Azure CLI, Google Cloud CLI
- WinSCP, PuTTY, FileZilla

**Security:**
- Trend Micro Apex One
- 1Password

**And 30+ more tools** - see `Config\monitoring-config.json` for the full list

## App Plugins

The system includes plugins for automatic version checking:

- ✅ **NodeJS** - Checks official Node.js API
- ✅ **Chrome** - Checks Google Chrome versions API
- ✅ **Firefox** - Checks Mozilla product details
- ✅ **Git** - Checks GitHub releases
- ✅ **VSCode** - Checks VS Code releases
- ⏳ **SSMS** - Manual check required (no API)
- ⏳ **Generic** - Fallback for apps without specific plugins

### Adding More Plugins

Copy an existing plugin and modify it:

```powershell
cd AppPlugins
copy Chrome.ps1 YourApp.ps1
notepad YourApp.ps1  # Edit to check your app's version source
```

## Configuration

### Notification Thresholds

Edit `Config\monitoring-config.json`:

```json
{
  "thresholds": {
    "notifyOnMinorUpdates": false,    // 1.1.0 → 1.1.1 (don't notify)
    "notifyOnMajorUpdates": true,     // 1.1.0 → 1.2.0 (notify)
    "notifyOnSecurityUpdates": true   // Always notify for CVEs
  }
}
```

### CVE Checking

Apps with `checkCVEs: true` will be scanned for security vulnerabilities:
- NodeJS ✓
- Chrome ✓
- Firefox ✓
- Git ✓
- Docker ✓
- MongoDB ✓
- Python ✓
- Zoom ✓
- Teams ✓
- VSCode ✓
- Power BI ✓
- SSMS ✓
- AWS CLI ✓

Note: CVE checking is currently a placeholder. Full implementation will use the NVD API.

### Disable Monitoring for Specific Apps

Edit `Config\monitoring-config.json` and set `enabled: false` for any app:

```json
{
  "name": "1Password",
  "displayName": "PH - 1Password",
  "currentVersion": "2025.731.1929.0",
  "enabled": false,  // ← Set to false to skip this app
  "checkCVEs": false
}
```

## Scheduled Task

The scheduled task runs daily at 8:00 AM with these settings:

- ✅ Runs whether you're logged in or not
- ✅ Wakes computer from sleep
- ✅ Runs on battery power
- ✅ Starts if previous run was missed
- ✅ Requires network connection

### Manage the Task

```powershell
# View task status
Get-ScheduledTask -TaskName "Intune App Monitor - Daily Check"

# Run manually
Start-ScheduledTask -TaskName "Intune App Monitor - Daily Check"

# Disable
Disable-ScheduledTask -TaskName "Intune App Monitor - Daily Check"

# Remove
Unregister-ScheduledTask -TaskName "Intune App Monitor - Daily Check"
```

## Troubleshooting

### No Notifications Received

1. Check if updates were actually found:
   ```powershell
   Get-Content .\Logs\monitor-$(Get-Date -Format 'yyyy-MM-dd').log
   ```

2. Check if findings file was created:
   ```powershell
   dir .\Output\findings.json
   ```

3. Verify Power Automate Desktop is running

4. Test notifications:
   ```powershell
   .\Monitor-IntuneApps.ps1 -TestNotifications
   ```

### Plugins Not Working

Some apps use the Generic plugin (no actual version check). To see which:

```powershell
Get-Content .\Logs\monitor-$(Get-Date -Format 'yyyy-MM-dd').log | Select-String "Generic.ps1"
```

Consider creating specific plugins for important apps.

### Version Checking Failed

If a specific app fails to check:

1. Look for errors in the log file
2. Test the plugin directly:
   ```powershell
   .\AppPlugins\NodeJS.ps1 -CurrentVersion "24.12.0"
   ```

3. Check your internet connection
4. Some APIs may have rate limits

### Scheduled Task Not Running

1. Open Task Scheduler: `taskschd.msc`
2. Find "Intune App Monitor - Daily Check"
3. Check "History" tab for errors
4. Ensure your account has permissions
5. Try running manually: Right-click → Run

## Maintenance

### Weekly

- Review logs to ensure monitoring is working
- Check for any failed plugin checks

### After Each Intune Deployment

Update the app version:

```powershell
.\Update-AppVersion.ps1 -AppName "App Name" -NewVersion "X.Y.Z"
```

### Monthly

- Review which apps are using Generic plugin
- Consider creating specific plugins for critical apps
- Check if any apps should be added/removed from monitoring

### Quarterly

- Re-import from Intune CSV to catch new apps
- Review and adjust notification thresholds
- Update Power Automate flow if needed

## Security Notes

- No credentials are stored in the monitoring scripts
- Power Automate uses your logged-in Outlook/Teams account
- All communication uses HTTPS
- Findings file contains no sensitive data
- Logs are stored locally only

## Limitations

- **CVE Checking**: Currently placeholder - full implementation pending
- **Some Apps**: Use Generic plugin (no automatic version check)
- **SSMS**: No public API available - requires manual checking
- **Rate Limits**: Some APIs may throttle frequent requests
- **Local Only**: Runs on your laptop only (not cloud-based)

## Future Enhancements

Possible improvements:

- [ ] Full CVE integration with NVD API
- [ ] More app-specific plugins
- [ ] Web scraping for apps without APIs
- [ ] Dashboard UI to view status
- [ ] Historical trend tracking
- [ ] Automatic download of installers
- [ ] Integration with Intune API for automatic deployment

## Getting Help

1. **Check the logs**: `D:\intune-app-monitor\Logs\`
2. **Run dry-run**: `.\Monitor-IntuneApps.ps1 -DryRun`
3. **Test notifications**: `.\Monitor-IntuneApps.ps1 -TestNotifications`
4. **Review config**: `.\Config\monitoring-config.json`

## Quick Reference

```powershell
# Daily monitoring (manual)
.\Monitor-IntuneApps.ps1

# Test without notifications
.\Monitor-IntuneApps.ps1 -DryRun

# Test notifications
.\Monitor-IntuneApps.ps1 -TestNotifications

# Update app version after deployment
.\Update-AppVersion.ps1 -AppName "Chrome" -NewVersion "144.0.0"

# Re-import from CSV
.\Import-FromIntuneCSV.ps1 -CSVPath "path\to\csv"

# Setup scheduled task (admin required)
.\Setup-MonitoringTask.ps1

# View today's log
Get-Content .\Logs\monitor-$(Get-Date -Format 'yyyy-MM-dd').log

# View current config
Get-Content .\Config\monitoring-config.json | ConvertFrom-Json

# Test a specific plugin
.\AppPlugins\NodeJS.ps1 -CurrentVersion "24.12.0"
```

---

**Version**: 1.0
**Created**: 2026-01-22
**Location**: D:\intune-app-monitor
**Monitored Apps**: 53 (PH - prefix)
**Automation**: Windows Scheduled Task + Power Automate Desktop
