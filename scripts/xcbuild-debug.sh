#!/bin/bash
set -o pipefail && xcodebuild build \
  -scheme ora \
  -destination "platform=macOS" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO | xcbeautify
