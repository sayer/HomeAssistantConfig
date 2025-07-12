# Timezone Selection Feature Setup

This feature allows you to change the Home Assistant system timezone directly from the dashboard.

## Setup Instructions

**No setup required!** The timezone feature is ready to use immediately.

## Using the Timezone Feature

### Systems Tab
- Go to the **Systems** tab in the dashboard
- Find the "System Configuration" section at the top

#### Manual Timezone Selection
- Tap the "System Timezone" card to open the selection dialog
- Choose your desired timezone from the dropdown
- The system will automatically update the timezone and restart Home Assistant

#### Auto-Detect Timezone from Location
- Tap the **"Auto-Detect Timezone"** button (blue button)
- The system will use your current GPS location to determine the correct timezone
- If a different timezone is detected, it will automatically update the system
- Perfect for motorhome travel across different time zones!

#### Location Timezone Display
- The "Location Timezone" card shows the timezone for your current GPS location
- Compare this with your "System Timezone" to see if an update is needed
- Updates automatically every 5 minutes based on your GPS coordinates

## Available Timezones

The system includes the following US and Canadian timezones:

### Eastern Time
- America/New_York (Eastern Standard/Daylight Time)
- America/Indiana/Indianapolis (Eastern Time - Indiana)
- America/Detroit (Eastern Time - Michigan)
- America/Kentucky/Louisville (Eastern Time - Kentucky)

### Central Time
- America/Chicago (Central Standard/Daylight Time)

### Mountain Time
- America/Denver (Mountain Standard/Daylight Time)
- America/Boise (Mountain Time - Idaho)
- America/Regina (Central Standard Time - Saskatchewan)

### Pacific Time
- America/Los_Angeles (Pacific Standard/Daylight Time)
- America/Vancouver (Pacific Time - British Columbia)

### Alaska & Hawaii
- America/Anchorage (Alaska Standard/Daylight Time)
- Pacific/Honolulu (Hawaii Standard Time)

### Arizona
- America/Phoenix (Mountain Standard Time - No DST)

### Canada
- America/Winnipeg (Central Standard/Daylight Time - Manitoba)
- America/Toronto (Eastern Standard/Daylight Time - Ontario)
- America/Edmonton (Mountain Standard/Daylight Time - Alberta)
- America/Calgary (Mountain Standard/Daylight Time - Alberta)
- America/Montreal (Eastern Standard/Daylight Time - Quebec)
- America/Halifax (Atlantic Standard/Daylight Time - Nova Scotia)
- America/St_Johns (Newfoundland Standard/Daylight Time)

## How It Works

### Manual Timezone Changes
1. When you select a new timezone, an automation triggers
2. The system uses a shell command to modify the configuration.yaml file
3. A notification is sent to confirm the change
4. Home Assistant automatically restarts after 10 seconds to apply the new timezone
5. All time-sensitive components are updated with the new timezone

### Auto-Detect Feature
1. Uses your GPS coordinates to query timezone information
2. Compares detected timezone with current system timezone
3. If different, automatically updates the system timezone
4. Sends notifications to confirm the change
5. Restarts Home Assistant to apply changes

### Location-Based Suggestions
1. Monitors your GPS location for significant changes
2. When parked and location changes, suggests timezone updates
3. Sends notifications when new timezone is detected
4. Only suggests changes when motorhome is parked (not driving)
5. Provides easy one-tap auto-detect option

## Troubleshooting

### Timezone Not Changing
- Check the Home Assistant logs for shell command errors
- Ensure the shell command has proper permissions
- Verify the configuration.yaml file is writable

### Restart Issues
- If Home Assistant doesn't restart automatically, restart it manually
- Check that the homeassistant.restart service is available
- Verify there are no configuration errors preventing restart

### Components Not Updating
- All components should update automatically after restart
- Check individual component documentation for timezone requirements
- Some external integrations may need manual reconfiguration

## Security Notes

- The shell command directly modifies the configuration file
- No external API calls or tokens required
- Changes are applied immediately and securely
- The system automatically restarts to ensure all changes take effect

## Files Modified

- `configuration.template.yaml` - Added timezone configuration and input_select
- `shell_commands.yaml` - Added timezone change shell command
- `scripts.yaml` - Added timezone change script with restart
- `automations.yaml` - Added automation to trigger timezone changes
- `.storage/lovelace.dashboard_remote` - Added timezone selection cards to dashboard 