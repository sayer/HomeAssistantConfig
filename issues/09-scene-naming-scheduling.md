# Allow user to name scenes and set optional schedules

- Priority: Medium
- Source: User request

## Summary
Users should be able to create custom named scenes and optionally set schedules for when those scenes should automatically run. This would allow for personalized lighting/device presets that can run automatically during camping mode, improving the user experience and automation capabilities.

## Evidence
- Current scenes may not have user-friendly names or may be limited to preset configurations
- Users want the ability to schedule scenes to run automatically (e.g., "Evening Wind Down" at sunset, "Morning Setup" at sunrise)
- Schedules should respect camping mode to avoid unwanted automation when not actively using the RV

## Proposed Work
- Implement user interface for creating and naming custom scenes
- Add scheduling functionality that allows users to set time-based triggers for scenes
- Include enable/disable toggle for scene schedules
- Ensure schedules only execute when in camping mode to prevent unwanted automation
- Store scene configurations and schedules persistently
- Provide clear UI feedback for scheduled vs. manual scene execution

## Acceptance Criteria
- Users can create scenes with custom names through the UI
- Users can optionally set schedules (time-based triggers) for any scene
- Scene schedules can be enabled or disabled independently
- Scheduled scenes only run when the system is in camping mode
- Scene names and schedules persist across Home Assistant restarts
- Clear indication in UI shows which scenes have active schedules
- Users can modify or delete both scene names and schedules after creation