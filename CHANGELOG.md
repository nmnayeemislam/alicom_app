# Changelog

This document records all notable changes to the Alicom customer application.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — 1.0.0

### Added

#### Push notifications (Firebase Cloud Messaging)

- Integrated Firebase Cloud Messaging by means of the `firebase_core`,
  `firebase_messaging` and `flutter_local_notifications` packages, together with
  a dedicated Android notification channel (`alicom_default`).
- Implemented per-account device registration. The device token is submitted to
  `PUT /profile/fcm-token` upon authentication and revoked upon sign-out, thereby
  preventing a subsequent user of the same handset from receiving the previous
  customer's order notifications.
- Deferred the notification permission prompt until after authentication, at
  which point order updates are relevant to the user.
- Implemented notification routing. An order notification opens the
  corresponding order; a broadcast notification's `link` payload is resolved
  through the existing deep-link handler. A notification that launches the
  application from a terminated state is deferred until the application shell
  has been presented.
- Added support for broadcast imagery. Images are rendered by the operating
  system while the application is backgrounded, and are retrieved and presented
  as an expanded image (Android) or an attachment (iOS) while it is in the
  foreground.
- Supplied a monochrome notification icon at five screen densities, together
  with the brand accent colour. The previous configuration used the colour
  launcher icon, which the platform rendered as a blank square.

#### Notification inbox

- Introduced a Notifications screen backed by the inbox API, supporting unread
  state, deletion by swipe, a mark-all-as-read action and an empty state.
- Added an unread-count badge to the application bar, refreshed on receipt or
  selection of a push notification.
- Replaced the generic glyph on inbox rows with the Alicom brand mark.

#### Invoices

- Added retrieval of the server-generated invoice document from the order detail
  screen.
- Implemented in-application rendering of the document by means of the `pdfx`
  package, in preference to delegation to an external viewer, which cannot be
  assumed to be installed.
- Implemented a save-to-downloads action that writes the document to the
  device's Downloads collection through MediaStore, making it discoverable in
  the Files application. On releases prior to Android 10 the action falls back
  to the system share sheet.
- Added a share action for onward distribution of the invoice.

#### Order progress

- Added a stage indicator to the order detail and order list screens, replacing
  the previous plain-text status label.

#### Two-step registration

- Replaced single-step registration with an email one-time-password flow. A
  verification code is issued to the customer's address and validated prior to
  account creation.
- Added a code-entry component supporting paste, resend with a countdown, and
  error presentation.

#### Account management

- Added an account deletion facility, guarded by a confirmation dialog.

#### Access control

- Unauthenticated users are now directed to the sign-in screen before adding
  items to the basket or wishlist, and checkout is no longer available to them.
  This resolves an inconsistency whereby the basket required an account but
  checkout did not.
- Sign-out now returns the user to the Home screen rather than leaving them on a
  screen to which they no longer have access.

#### General

- Introduced a shared loading indicator, applied throughout the application,
  including a blocking variant used during sign-in, registration and sign-out.
- Added authentic brand marks to the "Follow us" section by means of the
  `font_awesome_flutter` package.
- Completed the three onboarding screens, including animated presentation of the
  accompanying copy on page transitions.

### Changed

- Consolidated wishlist handling into a single state object, so that marking a
  product as a favourite is reflected on the Wishlist screen immediately rather
  than upon reload.
- Revised the bottom navigation to four destinations with a central basket
  control, distinguished by a tinted ring.
- Each screen's application bar now presents the title of that screen in place
  of the application name, by means of a shared component.
- Reduced the dimensions of the product card while retaining its full content,
  using measured heights to prevent overflow within the grid.
- Redesigned the Orders, Product Detail, Checkout, Products and Edit Profile
  screens, and the Refer and Earn component. The product gallery now presents
  images over a blurred backdrop.
- Enabled core library desugaring for Android release builds, as required by
  `flutter_local_notifications`.

### Fixed

- Resolved a defect whereby authentication failed immediately following
  registration. The Android autofill service was substituting the password
  entered by the user. Addressed by introducing an autofill group, applying the
  `newPassword` hint, committing the autofill context on submission, and
  removing the demonstration credentials previously pre-filled on the sign-in
  screen.
- Resolved a defect whereby card payments could not be completed. The payment
  URL returned by the backend was not being acted upon; the hosted checkout page
  is now presented in an in-application browser.
- Corrected the appearance of order cards, whose shadow was being drawn within a
  clipping boundary.
- Corrected an unbounded-width constraint on the onboarding screen that resulted
  in a rendering exception.
- Corrected loading indicators that exceeded the bounds of small controls and
  text-field affixes.
- Corrected the alignment of brand marks, which are not self-centring.

### Known issues

The following matters remain outstanding and should be addressed prior to
public release.

- **Release signing.** Release builds are presently signed with the debug
  certificate. This is acceptable for internal distribution but precludes
  submission to Google Play, and a subsequent change of certificate will oblige
  existing users to uninstall the application before updating. A keystore must
  be created and configured.
- **Launcher icon.** The generated `mipmap` resources derive from a superseded
  logo and are clipped by the Android adaptive icon mask. The current source
  asset has not been regenerated into them.
- **Default API host.** The application defaults to the UAT environment.
  Production builds require `--dart-define=API_BASE_URL=...`.
- **Test suite.** Four widget tests fail: three relating to the two-step
  registration flow and one to the navigation shell.
- **Artefact size.** The release APK is 80 MB. Building with `--split-per-abi`
  reduces this by approximately half.
- **Localisation.** The Bengali translation is incomplete, covering 12 of 46
  screens.
- **iOS.** Push notifications have not been verified on a physical device.
  Presentation of broadcast imagery while the application is backgrounded would
  require a Notification Service Extension.
- **Build toolchain.** The `firebase_core`, `pdfx` and `share_plus` packages
  continue to apply the Kotlin Gradle Plugin. Builds succeed at present, but
  future releases of Flutter will reject this configuration.

### Matters referred to the backend team

- Password recovery by email returns HTTP 500. The `phone_otps.country_iso`
  column is declared NOT NULL.
- The payment return URL resolves to `localhost`, causing the browser to fail
  following an otherwise successful transaction. Payments themselves are
  recorded correctly.
- The order list endpoint does not return item thumbnails.
- HTTP 500 responses disclose raw SQL statements and exception messages to the
  client.
