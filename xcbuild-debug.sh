#!/bin/bash
set -o pipefail && xcodebuild build \
  -target ora \
  -project Ora.xcodeproj \
  -destination "platform=macOS" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO | xcbeautify