
# LocalBirdReporter - Discover Birds While You Drive

Local Bird Reporter is your automatic birding companion that speaks to report nearby birds as you travel.  Your iPhone can be on standby and in your pocket and LocalBirdReporter will speak to report birds through your earbuds or headphones.

The app is smart about location changes - when you drive, bike, or walk more than a configurable distance, it automatically speaks to report birds at your new location. Perfect for birding road trips where you're visiting multiple parks or wildlife areas in a day.

When you run LocalBirdReporter on your iPhone and tap "Fetch Local Birds" the app automatically checks eBird for recent bird sightings in your area and speaks to report them.  If "Auto Check" is set then LocalBirdReporter will periodically check if you have moved to a new location and speaks to report new birds in that location.  So when you are driving around an area the app will automatically speak up to report birds as your location changes.

You can also manually select and monitor specific locations. Pick a wildlife refuge, park, or birding hotspot on the map and get spoken reports of birds reported there - even when you're miles away. Perfect for keeping tabs on your favorite birding locations remotely.

Some observations are so exciting you'll want to pull over and try to spot them yourself! The app provides direct links to eBird species pages and link to Apple maps for the observation locations.  Just tap the bird name to get directed to eBird, or tap the location to get directed to that spot in Apple Maps.


-----------------------------------------------
## Key Features

- **Automatic bird discovery** - Fetches recent sightings from eBird based on your location
- **Manual location** - Select a remote location to monitor
- **Interactive maps** - Search for locations or tap on the map with satellite view option
- **Text-to-speech announcements** - Hear about new birds without looking at your phone
- **Smart location tracking** - Reports new birds when you move areas
- **Background operation** - Runs continuously with configurable check intervals
- **Customizable display** - Sort by distance, count, or recency
- **Voice selection** - Choose from available English voices
- **Distance units** - Switch between kilometers and miles
- **Direct links** - Tap bird names for eBird info, locations for Apple Maps

-----------------------------------------------
## Example Use Cases

**Here is one that I use a lot**:

> I tap "Fetch Local Birds" to get a list of birds near me. 
> Sometimes there are no birds shown!  Why?
> I tap Settings and change the "Search Radius" to a larger number, say, 5 km.  
> Then tap Done and "Fetch Local Birds" again.  
> This usually turns up some birds and LocalBirdReporter will speak to report them.
> Also in Settings, I can change "Show birds from last:" to a longer time, 
> say, 7 days, or 14 days.  
> Now, even with a smaller "Search Radius" I can tap "Fetch Local Birds" 
> and possibly turn up some birds.

**Monitor a Hotspot**: Select a local wildlife refuge on the map and see what interesting birds have been reported there - perfect for planning your next visit.

**Road Trip Birding**: Enable auto-check and drive through birding areas. The app automatically announces new birds as you travel.

**Park Hopping**: Visit multiple parks in a day. The app speaks to report birds at each new location.

**Rare Bird Chase**: When you hear about a rarity, tap the location to open Apple Maps and navigate there. Tap the bird name to learn more on eBird.

**Hands-Free Birding**: Put on your earbuds or earphones and LocalBirdReporter will speak to report birds. No need to look at your phone.  Keep it in your pocket while you use your camera or binoculars.

**Sort By**: The default is to show you the birds sorted by "Largest Number" (biggest flocks first) but you can change this.  Tap Settings and notice "Sort By".  Here you can change it to "Closest", "Most Recently Reported" or "Largest Number".  LocalBirdReporter will remember your settings for next time you run the app.


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
