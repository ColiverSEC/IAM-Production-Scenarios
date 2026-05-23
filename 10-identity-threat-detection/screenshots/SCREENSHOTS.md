# Screenshots — Scenario 10

Capture screenshots at each implementation step.
Name them to match the README references exactly.

| Filename | Step | Description |
|----------|------|-------------|
| 01-addon-install.png | Method A Step 1 | Splunk Add-on for Microsoft Security — installed |
| 02-addon-credentials.png | Method A Step 2 | Add-on Azure credential configuration |
| 03-addon-inputs.png | Method A Step 3 | Sign-in and audit log inputs configured |
| 04-ingestion-verified.png | Method A Step 4 | First sign-in events visible in Splunk Search |
| 05-hec-token.png | Method B Step 1 | HEC token created in Splunk settings |
| 06-hec-script-output.png | Method B Step 2 | Python ingestor script console output |
| 07-task-scheduler.png | Method B Step 3 | Windows Task Scheduler — 5-minute schedule |
| 08-mfa-fatigue-alert.png | D-01 | Alert configured in Splunk — triggered result shown |
| 09-impossible-travel-alert.png | D-02 | Alert configured in Splunk — triggered result shown |
| 10-pim-afterhours-alert.png | D-03 | Alert configured in Splunk — triggered result shown |
| 11-legacy-auth-spike-alert.png | D-04 | Alert configured in Splunk — triggered result shown |
| 12-identity-threat-dashboard.png | Dashboard | Full dashboard view in Splunk |

## Screenshot Tips

- For alert screenshots: capture the Triggered Alerts view showing the
  alert name, time fired, and severity badge
- For the dashboard: capture the full page in dark mode with all panels
  showing data from the test event generator
- For script output: capture the terminal showing event counts and
  [+] confirmation lines
