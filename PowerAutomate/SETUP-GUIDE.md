# Power Automate Desktop Flow Setup Guide

This guide will help you create a Power Automate Desktop flow to send email and Teams notifications when app updates or CVEs are found.

## Overview

The PowerShell monitoring script creates a `findings.json` file in the `Output` folder when updates or security issues are detected. Power Automate Desktop will:

1. Monitor for new findings files
2. Read and parse the JSON data
3. Send formatted email via Outlook
4. Post to Microsoft Teams with Adaptive Cards
5. Archive the processed findings

## Prerequisites

- Power Automate Desktop installed (included with Windows 11 or downloadable for Windows 10)
- Outlook/Office 365 account
- Microsoft Teams access
- The monitoring script already set up and tested

## Step-by-Step Setup

### Part 1: Create the Flow

1. **Open Power Automate Desktop**
   - Press Windows key and search for "Power Automate Desktop"
   - Click "New flow"
   - Name it: "Intune App Notifier"

2. **Add File Monitor Trigger**
   - Click "+ Add trigger" at the top
   - Search for "When a file is created or modified"
   - Configure:
     - Folder: `D:\intune-app-monitor\Output`
     - File filter: `findings.json`
     - Include subfolders: No
     - Monitor for: File created

3. **Read the Findings File**
   - Add action: "Read text from file"
   - Configure:
     - File path: `%TriggerData['FilePath']%`
     - Store content as: `FileContents`

4. **Parse JSON**
   - Add action: "Parse JSON"
   - Configure:
     - JSON text: `%FileContents%`
     - Store as: `FindingsData`

5. **Build Email Body**
   - Add action: "Set variable"
   - Variable name: `EmailBody`
   - Value (paste this):

```html
<html>
<head>
<style>
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
.header { background-color: #0078D4; color: white; padding: 20px; border-radius: 5px; }
.critical { background-color: #D13438; color: white; padding: 15px; margin: 10px 0; border-radius: 5px; }
.warning { background-color: #FFB900; color: black; padding: 15px; margin: 10px 0; border-radius: 5px; }
.info { background-color: #F3F2F1; padding: 15px; margin: 10px 0; border-radius: 5px; }
.app-item { border-left: 4px solid #0078D4; padding: 10px; margin: 10px 0; background-color: #FAF9F8; }
</style>
</head>
<body>
<div class="header">
<h2>🚨 Intune App Updates Available</h2>
<p>Generated: %FindingsData['timestamp']%</p>
</div>

<div class="info">
<h3>Summary</h3>
<ul>
<li>Total apps checked: %FindingsData['summary']['totalApps']%</li>
<li>Apps needing updates: %FindingsData['summary']['appsNeedingUpdate']%</li>
<li>Critical CVEs: %FindingsData['summary']['criticalCVEs']%</li>
<li>High CVEs: %FindingsData['summary']['highCVEs']%</li>
</ul>
</div>

<!-- This section will be built dynamically -->
%EmailAppsList%

<p style="color: #666; font-size: 12px; margin-top: 30px;">
🤖 Generated automatically by Intune App Watchdog<br/>
Log location: D:\intune-app-monitor\Logs\
</p>
</body>
</html>
```

6. **Loop Through Findings**
   - Add action: "For each"
   - Value to iterate: `%FindingsData['findings']%`
   - Loop variable: `CurrentFinding`

7. **Inside the Loop - Build App Details**
   - Add action: "Set variable"
   - Variable name: `AppDetails`
   - Value:

```html
<div class="app-item">
<h4>%CurrentFinding['app']%</h4>
<p><strong>Current:</strong> %CurrentFinding['currentVersion']%<br/>
<strong>Latest:</strong> %CurrentFinding['latestVersion']%<br/>
<strong>Update Type:</strong> %CurrentFinding['updateType']%</p>
<p><a href="%CurrentFinding['downloadUrl']%">Download Link</a></p>
</div>
```

   - Add action: "Set variable"
   - Variable name: `EmailAppsList`
   - Value: `%EmailAppsList% %AppDetails%`

8. **Send Email via Outlook**
   - Add action: "Send email via Outlook"
   - Configure:
     - To: Your email address
     - Subject: `Intune App Updates - %FindingsData['summary']['appsNeedingUpdate']% apps need attention`
     - Body: `%EmailBody%`
     - Body is HTML: Yes

9. **Send Teams Message**
   - Add action: "Post message in a chat or channel (Teams)"
   - Configure:
     - Post as: Flow bot
     - Post in: Channel
     - Team: Select your team
     - Channel: Select your channel
     - Message: `Intune App Updates Available - see email for details`
     - (Or build an Adaptive Card - see below)

10. **Archive the Findings File**
    - Add action: "Move file"
    - Configure:
      - Source: `%TriggerData['FilePath']%`
      - Destination: `D:\intune-app-monitor\Output\Archive\findings-%CurrentDateTime%.json`
      - If file exists: Overwrite

11. **Save and Enable the Flow**
    - Click "Save"
    - Toggle the flow to "Enabled"

### Part 2: Teams Adaptive Card (Optional but Recommended)

For a richer Teams experience, use an Adaptive Card instead of plain text:

1. In the "Post message in Teams" action, select "Adaptive Card"
2. Use this template:

```json
{
  "type": "AdaptiveCard",
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.4",
  "body": [
    {
      "type": "Container",
      "style": "emphasis",
      "items": [
        {
          "type": "TextBlock",
          "text": "🚨 Intune App Updates",
          "weight": "Bolder",
          "size": "Large"
        },
        {
          "type": "TextBlock",
          "text": "Generated: ${timestamp}",
          "isSubtle": true,
          "spacing": "None"
        }
      ]
    },
    {
      "type": "FactSet",
      "facts": [
        {
          "title": "Apps checked:",
          "value": "${summary.totalApps}"
        },
        {
          "title": "Updates needed:",
          "value": "${summary.appsNeedingUpdate}"
        },
        {
          "title": "Critical CVEs:",
          "value": "${summary.criticalCVEs}"
        }
      ]
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "View Logs",
      "url": "file:///D:/intune-app-monitor/Logs/"
    }
  ]
}
```

## Testing the Flow

1. **Test with Test Data**
   - Run: `.\Monitor-IntuneApps.ps1 -TestNotifications`
   - This creates a test findings file
   - Power Automate should trigger within 1-2 minutes
   - Check your email and Teams for the notification

2. **Troubleshooting**
   - If flow doesn't trigger, check Power Automate Desktop is running
   - View flow run history in Power Automate Desktop
   - Check the Output folder permissions
   - Verify email and Teams connectors are authorized

## Customization Ideas

### Change Email Styling
Edit the `<style>` section in the EmailBody variable to match your organization's branding.

### Add More Recipients
In the "Send email via Outlook" action, add more email addresses separated by semicolons.

### Filter by Severity
Add a conditional action to only send notifications for Critical or High severity updates.

### Daily Summary
Instead of immediate notifications, collect findings throughout the day and send a summary at 5 PM.

## Flow Maintenance

- **Check logs**: Power Automate Desktop > Flow > View run history
- **Pause notifications**: Disable the flow temporarily
- **Update email template**: Edit the flow and modify the EmailBody variable

## Troubleshooting

### Flow not triggering
- Ensure Power Automate Desktop is running (system tray icon)
- Check if the trigger folder path is correct
- Verify file permissions on the Output folder

### Email not sending
- Re-authenticate the Outlook connector
- Check if your email account is logged in

### Teams message failing
- Re-authenticate the Teams connector
- Verify you have permission to post in the selected channel

## Support

For issues with Power Automate Desktop, visit:
https://powerautomate.microsoft.com/en-us/support/

For monitoring script issues, check the logs at:
`D:\intune-app-monitor\Logs\`
