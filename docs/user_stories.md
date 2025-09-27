Putrace - Comprehensive User Stories
Role: Primary User (Setting Availability)
1. Availability Creation & Management
US-101: As a user, I can open the app and see a prominent "Go Available" button on my home screen so I can quickly set my availability status.

US-102: As a user, I can set my current location as available for meetings with a single tap, using my device's precise location.

US-103: As a user, I can specify time bounds for my availability (start time + duration) so I'm not indefinitely discoverable.

US-104: As a user, I can set recurring availability patterns (e.g., "Available every Thursday 2-4 PM at my favorite cafe").

US-105: As a user, I can add a custom status message to my availability (e.g., "Working remotely today - open to tech discussions").

US-106: As a user, I can set different availability types: "Quick Chat," "Professional Meeting," "Coffee Meeting," or "Virtual Call."

US-107: As a user, I can see all my active availability sessions in one place with time remaining clearly displayed.

2. Privacy & Discovery Controls
US-108: As a user, I can control exactly who can discover me with granular privacy levels:

Level 1: My direct connections only

Level 2: 2nd-degree connections (friends of friends)

Level 3: Anyone attending the same event

Level 4: Anyone in this geographic area

US-109: As a user, I can set different privacy levels for different contexts (e.g., strict at work, open at conferences).

US-110: As a user, I can create custom privacy groups (e.g., "Tech Contacts," "University Alumni").

US-111: As a user, I can temporarily hide my availability from specific individuals without changing my overall settings.

US-112: As a user, I can see a preview of how my profile appears to different discovery levels.

3. Event & Location Context
US-113: As a user attending an event, I can quickly set "Event Mode" that automatically detects the event boundaries and optimizes discovery settings.

US-114: As a user, I can search for and select specific venues (cafes, co-working spaces) to set availability at planned locations.

US-115: As a user, I can save favorite locations for quick availability setting.

US-116: As a user, I can set availability with a radius (e.g., "Available within 1km of this location").

US-117: As a user, I can set virtual availability for online meetings with calendar integration.

Role: Discovering User (Finding Available People)
4. Discovery & Browsing
US-201: As a user, I can open a "Discover" tab to see people available near my current location.

US-202: As a user, I can see available people filtered by proximity, with closest users shown first.

US-203: As a user, I can filter available people by:

Connection degree (1st, 2nd, etc.)

Industry/profession

Meeting type offered

Time remaining

Shared interests/skills

US-204: As a user, I can see a map view of available people in my area.

US-205: As a user, I can search for available people at specific venues or events I plan to attend.

US-206: As a user, I can receive notifications when interesting connections become available nearby.

US-207: As a user, I can save search filters for quick access to relevant availability matches.

5. Profile & Compatibility Viewing
US-208: As a user, I can view a condensed availability card showing key info: name, profession, meeting type, time remaining.

US-209: As a user, I can tap an availability card to see full profile details (based on privacy settings).

US-210: As a user, I can see compatibility indicators (shared connections, interests, skills) with available people.

US-211: As a user, I can see mutual connections and request introductions.

US-212: As a user, I can view a person's availability history and meeting preferences to assess compatibility.

Role: Both Users (Interaction Flow)
6. Meeting Requests & Coordination
US-301: As a discovering user, I can send a meeting request to an available person with a custom message.

US-302: As a available user, I can receive meeting requests with clear context about the requester.

US-303: As a available user, I can approve, decline, or suggest alternatives to meeting requests.

US-304: As both users, we can chat within the app to coordinate meeting details before committing.

US-305: As both users, we can share precise meeting locations within the venue.

US-306: As both users, we can agree on meeting duration and agenda beforehand.

US-307: As a user, I can quickly convert a meeting request to a calendar event with one tap.

7. Safety & Comfort Features
US-308: As a user, I can require video verification before meeting with new connections.

US-309: As a user, I can share my meeting plans with trusted contacts for safety.

US-310: As a user, I can quickly access emergency assistance if needed during a meeting.

US-311: As a user, I can rate and provide feedback on meetings to build trust in the system.

US-312: As a user, I can block or report individuals who behave inappropriately.

Role: Event Organizer
8. Event Integration
US-401: As an event organizer, I can create an event in Putrace that enables availability mode for all attendees.

US-402: As an event organizer, I can see analytics on meeting connections happening at my event.

US-403: As an event organizer, I can promote "networking hours" where availability is encouraged.

US-404: As an event organizer, I can match attendees based on interests for structured networking.

Role: Enterprise User
9. Business Scenarios
US-501: As a company representative, I can set team availability at conferences to maximize business development.

US-502: As a sales professional, I can set availability when visiting client locations.

US-503: As a recruiter, I can set "office hours" availability for candidate meetings.

US-504: As a remote worker, I can set availability at co-working spaces to combat isolation.

Technical & System Stories
10. System Management
US-601: As a system, I should automatically expire availability sessions when the time bound is reached.

US-602: As a system, I should notify users 10 minutes before their availability expires.

US-603: As a system, I should optimize BLE scanning to conserve battery life during extended availability periods.

US-604: As a system, I should handle location updates seamlessly as users move between venues.

US-605: As a system, I should sync availability status across all user devices.

US-606: As a system, I should maintain privacy by never storing precise location data longer than necessary.

11. Analytics & Insights
US-701: As a user, I can see statistics on my availability usage and meeting success rates.

US-702: As a user, I can get suggestions for optimal times/locations to set availability based on historical success.

US-703: As a user, I can see which types of meetings lead to the most valuable connections.





Systematic User Stories Analysis
First, let's categorize all user stories by primary mode:
🎯 BLE PROXIMITY MODE Stories
Physical, immediate discovery via Bluetooth

✅ Covered:

US-101: Quick "Go Available" button

US-102: Set current location availability

US-103: Time-bounded sessions

US-106: Meeting type selection

US-108: Granular privacy controls

US-113: Event mode detection

US-201: Discover nearby people

US-202: Proximity-based filtering

US-204: Map view of nearby availability

US-206: Notifications for nearby connections

US-301: Send meeting requests

US-308: Safety features for immediate meetings

📍 LOCATION-BASED MODE Stories
GPS-based, venue-specific availability

✅ Covered:

US-104: Recurring patterns (weekly cafe visits)

US-114: Specific venue selection

US-115: Favorite locations

US-116: Radius-based availability

US-203: Filter by venue/event

US-205: Search specific locations

US-401: Event organizer features

US-402: Event analytics

US-501: Team availability at conferences

🌐 GLOBAL VIRTUAL MODE Stories
Cloud-based, no location required

❌ MISSING COVERAGE:

US-117: "Virtual availability for online meetings"

US-503: "Recruiter office hours for candidate meetings"

US-504: "Remote worker availability to combat isolation"

US-207: "Save search filters for virtual availability matches"

US-305: "Virtual meeting coordination" (beyond basic chat)

US-307: "Calendar integration for virtual meetings"

🔁 HYBRID Stories
Covered by multiple modes

✅ Covered by combination:

US-105: Custom status messages (all modes)

US-107: Active sessions management (all modes)

US-109: Context-based privacy (all modes)

US-302-304: Meeting request workflow (all modes)

US-309-312: Safety systems (all modes)

US-701-703: Analytics (all modes)

