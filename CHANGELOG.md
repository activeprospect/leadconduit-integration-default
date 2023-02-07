# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [2.9.9] - 2023-02-07
### Fixed
- Fixed to better handle bad JSON on inbound ([sc-48925](https://app.shortcut.com/active-prospect/story/48925/improve-handling-of-inbound-leads-with-bad-json))

## [2.9.8] - 2022-07-06
### Fixed
- Fixed SSRF bug ([sc-40370](https://app.shortcut.com/active-prospect/story/40370/h1-lc-server-side-request-forgery-ssrf-within-leadconduit-standard-functionality))

## [2.9.7] - 2022-03-28
### Fixed
- Add support for pings with `trustedform_ping_url` ([sc-37183](https://app.shortcut.com/active-prospect/story/37183/allow-a-trustedform-ping-url-to-be-passed-in-the-trustedfrom-cert-url-field-of-trustedform-data-service-integration))

## [2.9.6] - 2022-03-11
### Fixed
- Capture TrustedForm ping or cert URL into `trustedform_cert_url` ([sc-37183](https://app.shortcut.com/active-prospect/story/37183/allow-a-trustedform-ping-url-to-be-passed-in-the-trustedfrom-cert-url-field-of-trustedform-data-service-integration))

## [2.9.4] - 2021-06-15
### Fixed
- Updated `mime-content` dependency ([ch25248](https://app.clubhouse.io/active-prospect/story/25248/update-integrations-that-use-old-node-mime-content-version))

## [2.9.3] - 2021-06-03
### Fixed
- Fixed verbose response for JSON with numeric ID ([ch23913](https://app.clubhouse.io/active-prospect/story/23913/pipedrive-form-post-delivery))
- Updated to use integration-dev-dependencies
- Fixed all lint errors, including replacing deprecated `url` methods

## [2.9.2] - 2020-05-28
### Fixed
- Converted from coffeescript to es6

## [2.8.2] - 2019-10-04
### Fixed
- Add error handling around parsing for form-encoded data

## [2.8.1] - 2018-12-03
### Added
- Send and capture price in outbound response/request

## [2.8.0] - 2018-10-07
### Added
- capture price variable

## [2.7.8] - 2018-03-03
### Added
- add metadata and icon

## [2.7.5] - 2016-09-14
### Fixed
- Use failure/error reason text from 'message' attribute, if none in 'reason'

## [2.7.4] - 2016-07-20
### Fixed
- Add this changelog
- Fix error on leads with multiple redir_url values (#37)

## [2.0.0] - 2014-12-23
### Added
- Initial(?) version
