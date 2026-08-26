
# LocalBirdReporter - Discover Birds While You Drive

Tired of missing rare birds that were spotted just down the road? Local Bird Reporter is your automatic birding companion that announces nearby bird observations as you travel.

When you run Local Bird Reporter on your iPhone, it automatically checks for recent bird sightings from eBird in your area and announces new birds via text-to-speech. It runs in background and standby at custom intervals (as low as every minute), so you'll never miss interesting birds reported near your current location.

The app is smart about location changes - when you drive more than a configurable distance (for example, 3 km), it automatically resets and treats all birds at your new location as "new". Perfect for birding road trips where you're visiting multiple parks or wildlife areas in a day!

You can now manually select and monitor specific locations. Pin a wildlife refuge, park, or birding hotspot on the map and get alerts for birds reported there - even when you're miles away. Perfect for keeping tabs on your favorite birding locations remotely.

Some observations are so exciting you'll want to pull over and try to spot them yourself! The app provides direct links to eBird species pages and maps to the observation locations.


-----------------------------------------------
## Key Features

- **Automatic bird discovery** - Fetches recent observations from eBird based on your location
- **Manual location pinning** - Set a fixed location to monitor remotely
- **Interactive maps** - Search for locations or tap on map with satellite view option
- **Text-to-speech announcements** - Hear about new birds without looking at your phone
- **Smart location tracking** - Auto-resets when you move to new areas (GPS mode only)
- **Background operation** - Runs continuously with configurable check intervals
- **Customizable display** - Sort by distance, count, or recency
- **Voice selection** - Choose from available English voices
- **Distance units** - Switch between kilometers and miles
- **Direct links** - Tap bird names for eBird info, locations for Apple Maps

-----------------------------------------------
## Example Use Cases

**Road Trip Birding**: Enable auto-check and drive through birding areas. The app automatically announces new birds as you travel, resetting when you move to new locations.

**Monitor a Hotspot**: Pin your local wildlife refuge on the map and get alerts whenever interesting birds are reported there - perfect for planning your next visit.

**Park Hopping**: Visit multiple parks in a day. The app resets birds at each new location, so you hear about local specialties at every stop.

**Rare Bird Chase**: When you hear about a rarity, tap the location to open maps and navigate there. Tap the bird name to learn more on eBird.

**Hands-Free Birding**: Use speech announcements while driving or hiking. No need to look at your phone - just listen for new birds.

**Sort By**: The default is to show you the birds sorted by "Largest Number" (biggest flocks first) but you can change this.  Tap Settings and notice "Sort By".  Here you can change it to "Closest", "Most Recently Reported" or "Largest Number".

**Here is one that I use a lot**:  I tap "Fetch Local Birds" to get a list of birds near me.
Sometimes there are no birds shown!  Why?  I tap Settings and change the "Search Radius" to a larger number, say, 5 km.  Then tap Done and "Fetch Local Birds" again.  This usually turns up some birds.
Also in Settings,  I can change "Show birds from last:" to a longer time, say, 7 days, or 14 days.  Now, even with a smaller "Search Radius" I can tap "Fetch Local Birds" and possibly turn up some birds.


-----------------------------------------------
## Documentation

See [SoftwareDesignDocument.md](LocalBirdReporter/SoftwareDesignDocument.md) for detailed technical documentation including:

  - Architecture overview (MVVM pattern)
  - Manual location features and map integration
  - eBird API integration
  - Background operation with location tracking
  - Speech synthesis configuration
  - Location-based reset logic
  - Data persistence strategy

-----------------------------------------------
## Privacy Policy

**Local Bird Reporter does not collect, store, or share any personal information or user data.**

All settings and bird tracking are stored locally on your device using UserDefaults. No data is transmitted to external servers except for necessary API calls to eBird.org to retrieve bird observations using your provided API key. Location data is used only on-device for calculating distances and querying nearby observations.

**Contact**: stewart.french@gmail.com

**Last Updated**: 08/25/2026

## Support Information

For any support issues, questions, or feedback, please contact:

**Stewart French**
Email: stewart.french@gmail.com

-----------------------------------------------
## Requirements

  - iOS 17.0 or later
  - iPhone (iPad supported but optimized for iPhone)
  - Location Services enabled (with "Always Allow" permission for background operation)
  - Internet connection for eBird API access
  - Free eBird API key (obtain from https://ebird.org/api/keygen)

-----------------------------------------------
## Getting Started

1. **Obtain an eBird API Key**

   - Visit https://ebird.org/api/keygen
   - Request a free API key (requires eBird account)
   - Copy your API key

2. **Configure the App**

   - Open Settings in the app
   - Paste your eBird API key
   - Adjust settings to your preference:

     - Auto-check interval (default: 2 minutes)
     - Distance threshold for reset (default: 3 km / 1.9 miles)
     - Search radius (default: 3 km / 1.9 miles)
     - Days back to search (default: 1 day)
     - Sort order (default: Largest Number)

3. **Choose Your Location Mode**

   **GPS Mode** (default):
   - Uses your current location
   - Automatically resets when you move beyond distance threshold
   - Perfect for birding road trips

   **Manual Location Mode**:
   - Tap "Change Location" in Settings
   - Search for a location or tap on the map
   - Choose standard or satellite map view
   - Monitor that location from anywhere
   - Perfect for tracking favorite birding spots

4. **Grant Permissions**

   - Allow location access "While Using App" when first prompted
   - After enabling auto-check and using in background, iOS will prompt for "Always Allow"
   - Grant "Always Allow" for best experience with background operation

5. **Start Birding**

   - Tap "Fetch Local Birds" to see what's nearby
   - Or enable "Auto Check" in Settings for automatic background operation
   - Drive to new birding locations and let the app announce new birds!

-----------------------------------------------
## Copyright and Legal Analysis

All bird observation data displayed in this app is sourced from eBird (www.ebird.org) and is used in accordance with eBird's API Terms of Use. eBird is a project of the Cornell Lab of Ornithology. This app is not affiliated with or endorsed by the Cornell Lab of Ornithology or eBird.

Bird observation data is retrieved via the eBird API v2 and presented with appropriate attribution. Users must obtain their own free API key from eBird to use this application.

This application is **powered by eBird data** but is independently developed and not officially supported by eBird or the Cornell Lab of Ornithology.

-----------------------------------------------
## License

This software is released into the **public domain**. Anyone is free to copy, modify, publish, use, compile, sell, or distribute this software, either in source code form or as a compiled binary, for any purpose, commercial or non-commercial, and by any means.

No copyright is claimed on this work. Use it freely without restriction.

## Acknowledgments

Developed with assistance from Claude Sonnet 4.5 by Anthropic.

Bird observation data powered by eBird (www.ebird.org), a project of the Cornell Lab of Ornithology.

-----------------------------------------------
end
