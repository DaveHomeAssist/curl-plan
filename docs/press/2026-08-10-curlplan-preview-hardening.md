# CurlPlan makes its public preview credential-free and strengthens cross-platform verification

**Draft press release. Not yet distributed.**

**FOR IMMEDIATE RELEASE**

## CurlPlan makes its public preview credential-free and strengthens cross-platform verification

### The curling season planner now presents a clearly labeled demo while expanding browser security, accessibility, metadata, and web-to-iOS quality gates

August 10, 2026

CurlPlan today released a reliability and trust update for its public web preview and native iOS codebase. The public preview now operates as an explicitly credential-free demo. It does not request an email address or password, and it removes legacy local password-shaped records during migration.

The release keeps a firm boundary between the available demo and future account functionality. Real accounts and cloud synchronization will remain unavailable in the public interface until the backend can prove account creation, restoration, deletion, and cross-device isolation.

## What changed

- Added a credential-free demo gate and plain-language disclosure.
- Added browser-enforced content security and referrer policies.
- Added canonical, social, robots, and sitemap metadata for the public preview.
- Added a main content landmark and improved contrast and touch behavior.
- Migrated the service worker cache and removed obsolete cached shells.
- Strengthened workflow integrity with commit-pinned GitHub Actions.
- Retained shared seed generation and functional parity checks across the web and iOS implementations.

## Verification

The release passed CurlPlan's root-app, classic-app, API, merge-algebra, seed, and 12-capability parity checks. GitHub Actions also completed the web and iOS simulator build-and-test jobs successfully.

A mobile Lighthouse verification run returned scores of 100 for accessibility, best practices, and search engine optimization. Performance scored 89 in the same lab run.

## Availability

The credential-free preview is available now at [davehomeassist.github.io/curl-plan](https://davehomeassist.github.io/curl-plan/).

## About CurlPlan

CurlPlan is a curling-native season planner built around a player's Passport, Locker Room, clubs, bonspiels, results, contributions, and team connections. The project includes a web preview, an archived classic planner, a native SwiftUI implementation, and tested synchronization foundations.
