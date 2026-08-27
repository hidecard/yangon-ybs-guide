# YBS AI Privacy Policy

**Last updated:** 27 August 2026

YBS AI is a Yangon bus-route guide. This policy describes what the current application stores, what it sends over the network, and how users can control or delete local data.

## Data stored on the device

The application stores route and stop data locally so route search can continue without an internet connection. It may also store favorite routes, favorite stops, saved trips, recent search history, notification state, and an active arrival-alert queue in the device application storage. These records are used only to provide the corresponding feature and are not sold.

## Location data

Location permission is optional. When the user selects Near Me, map picking, live tracking, or an arrival alert, the application may read the device location to find a nearby stop, display the user on a map, or calculate distance to the selected stop. The current implementation does not send GPS coordinates to the application API. Background location is requested only for an explicitly enabled arrival alert and the foreground service stops when the alert queue is cleared or completed.

## Network requests

The application may contact the YBS service for route-data refreshes, bus-position updates, arrival estimates, notifications, and feedback links. Requests for live route information include the selected route or request parameters needed by that feature. The offline route search itself is performed on the device. Network failures do not prevent the cached route directory from being used.

## Notifications and speech

If the user grants notification permission or enables an arrival alert, the application may display a local notification, vibrate, and speak an arrival message. Users can revoke notification, location, or microphone-related permissions through Android or iOS settings. The application does not use microphone recording for the local assistant.

## User controls and deletion

Favorites, saved trips, recent searches, cached route data, and an active alert can be removed from the application settings or by clearing the application storage from the operating-system settings. Users may contact **info@arkaryan.net** with privacy questions or deletion requests.

## Children and third parties

YBS AI is a general public-transport utility. It does not knowingly sell personal information or use the local assistant to collect sensitive personal information. Third-party map tiles, operating-system location services, notification services, and the configured YBS API may process technical requests according to their own policies.

## Changes

If the data practices change, this document and the in-app privacy section will be updated before the relevant feature is released.
