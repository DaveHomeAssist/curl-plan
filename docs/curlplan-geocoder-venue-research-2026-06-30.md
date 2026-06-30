# CurlPlan Geocoder And Venue Research

## Status

Research pass plus first implementation slice. The app now has a venue model, seeded curated venues, New Spiel venue search, Apple Maps lookup, and geocoded fallback.

## Current App Baseline

The native app now separates display labels from stronger event state:

- `Spiel.startDate` and `Spiel.endDate` store ISO date strings.
- `Spiel.stopID` can link a bonspiel to a `Stop`.
- `Stop.latitude` and `Stop.longitude` can hold real coordinates.
- `LiveMapStop.coordinate(for:)` prefers explicit coordinates before falling back to seeded demo coordinates.
- Unknown venue text is preserved as venue text, but no fake map pin is created.

That is the right truth boundary. The next step should add a real venue resolution path without weakening that boundary.

## Primary Findings

### Apple Platform Options

`CLGeocoder` is the narrowest fit for converting a user-entered address string into placemarks. Apple documents `geocodeAddressString` as taking a location description string, such as a street address, and returning matching locations.

Use this when the user enters a complete enough address or club name plus city/province. It does not by itself provide a curated curling club identity or durable place identifier.

Source: Apple CLGeocoder address lookup docs  
https://developer.apple.com/documentation/corelocation/clgeocoder/geocodeaddressstring%28_%3Acompletionhandler%3A%29

`MKLocalSearchCompleter` is the better UX fit for a venue text field. Apple describes it as generating completion strings as the user types for map-based search controls.

Use this for the New Spiel location field if the goal is to let users pick "Kelowna Curling Club" instead of typing free text.

Source: Apple MKLocalSearchCompleter docs  
https://developer.apple.com/documentation/mapkit/mklocalsearchcompleter

`MKLocalSearch` is the better final lookup step after autocomplete. Apple describes it as executing map searches for addresses or points of interest.

Use this after the user selects or submits a venue candidate. Store the selected map item data, not just the typed query.

Source: Apple MKLocalSearch docs  
https://developer.apple.com/documentation/mapkit/mklocalsearch

`MKMapItem.identifier` is important for durability. Apple describes it as a unique identifier for a place that can be persisted and later used to recall place information.

If available on the deployment target, store this alongside coordinates and display name so CurlPlan can distinguish "Granite" collisions and refresh metadata later.

Source: Apple MKMapItem identifier docs  
https://developer.apple.com/documentation/mapkit/mkmapitem/identifier-swift.property

Location permission is a separate concern. The venue search flow does not need current device location permission if it searches from typed text plus a region hint. Only request Core Location authorization later if CurlPlan actually verifies "I am here" or uses the user's current location.

Sources: Apple location authorization and privacy manifest docs  
https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services  
https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

### Curling Venue Data Options

Curling Canada is useful as a manual discovery starting point, but it does not look like a reliable machine source for CurlPlan venue hydration. The public site blocked command-line verification with HTTP 403 in this pass, so do not build an automated importer on it without separate permission or a documented feed.

Browser source to review manually: Curling Canada Find a Curling Centre  
https://www.curling.ca/about-us/about-curling/find-a-curling-centre/

Curling IO has a public club directory across Canada and the United States with club names, provinces, cities, street addresses, and registration links.

Source: Curling IO Club Directory  
https://clubs.curling.io/en

Curl BC exposes a rich member centre directory with zone, phone, website, accessibility, sheets, and service offerings. It is useful for BC coverage and source validation, but not enough for a national app by itself.

Source: Curl BC Curling Centres  
https://curlbc.ca/curling-centres/

## Recommended Product Path

Use a two-layer resolver:

1. Curated curling venue table
   - Holds known curling clubs with stable internal `venueID`.
   - Fields: `venueID`, `displayName`, `aliases`, `clubName`, `city`, `region`, `country`, `postalAddress`, `latitude`, `longitude`, `timezone`, `sourceKind`, `sourceURL`, `sourceCheckedAt`, `mapItemIdentifier`.
   - Starts with seeded high-confidence venues already used by CurlPlan, then expands by province.

2. Apple Maps lookup for user search
   - `MKLocalSearchCompleter` powers location suggestions.
   - `MKLocalSearch` resolves a selected suggestion to map items.
   - `CLGeocoder` remains a fallback for full postal addresses.
   - When a resolved map item matches a curated venue alias or address, link to the curated `venueID`.
   - When no curated match exists, store the resolved map item as user-confirmed venue data with lower authority.

## Truth Model

Do not store every successful geocode as equally authoritative.

Recommended authority levels:

- `curated`: reviewed CurlPlan venue row with source URL.
- `map_item`: selected Apple Maps result, with `MKMapItem.identifier` when available.
- `geocoded_address`: typed address resolved by `CLGeocoder`, no place identity.
- `free_text`: user-entered venue text, no coordinates.
- `unmapped`: intentionally not shown on map.

Visible copy should reflect the authority:

- Curated or map item: "Mapped venue"
- Geocoded address: "Mapped address"
- Free text: "Venue saved"
- Unmapped: no pin and no distance claim

## Data Model Changes To Plan

Add a dedicated `Venue` model before expanding the current `Stop` table further.

Candidate shape:

```swift
struct Venue: Identifiable, Hashable, Codable {
    var id: String
    var displayName: String
    var aliases: [String]
    var clubName: String
    var city: String
    var region: String
    var country: String
    var postalAddress: String
    var latitude: Double?
    var longitude: Double?
    var timezone: String?
    var mapItemIdentifier: String?
    var authority: VenueAuthority
    var sourceURL: String?
    var sourceCheckedAt: String?
}

enum VenueAuthority: String, Codable {
    case curated
    case mapItem = "map_item"
    case geocodedAddress = "geocoded_address"
    case freeText = "free_text"
    case unmapped
}
```

Then link:

- `Spiel.venueID`
- `BonspielRecord.venueID`
- `Stop.venueID`

Keep existing `whereText`, `BonspielVenue`, and `Stop` fields for migration and display compatibility.

## Implementation Sequence

1. Add `Venue`, `VenueAuthority`, and migration-safe optional `venueID` links.
2. Move the hardcoded `SpielRouteLocation` rows into a seed venue table.
3. Add a `VenueResolver` service with:
   - exact alias match
   - normalized city/province match
   - Apple Maps search result conversion
   - explicit no-match result
4. Replace New Spiel location text with:
   - text search
   - suggestion list
   - manual free-text fallback
   - clear "mapped" versus "saved only" state
5. Add tests for:
   - curated venue match
   - Apple map item result accepted
   - geocoder failure leaves venue unmapped
   - no location permission prompt in typed-search flow
   - persisted venue survives export/import

## Open Decisions

- Decide whether CurlPlan should depend on Apple Maps only, or also maintain a curated source-driven venue dataset.
- Decide whether source-backed venue rows should be local seed data, account-backend data, or both.
- Decide whether to support current-location club search in v1. That would add Core Location authorization and privacy surface area.

## Recommendation

Do not jump straight from free text to live geocoding. Add a `Venue` layer first, then plug Apple Maps search into that layer. This keeps CurlPlan from making false venue identity claims and creates a place to store source provenance, map identifiers, coordinates, timezone, and future draw-sheet metadata.
