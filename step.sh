#!/usr/bin/env bash
set -euo pipefail

# Source of the script
# https://github.com/SonarSource/sonar-scanning-examples/blob/master/swift-coverage/swift-coverage-example/xccov-to-sonarqube-generic.sh

covpath=$COV_PATH
# Check if the coverage path is provided
if [[ -z "$covpath" ]]; then
  echo "Error: covpath is not set or is empty." 1>&2
  exit 1
fi

function convert_xccov_to_xml {
  sed -n                                                                                       \
      -e '/:$/s/&/\&amp;/g;s/^\(.*\):$/  <file path="\1">/p'                                   \
      -e 's/^ *\([0-9][0-9]*\): 0.*$/    <lineToCover lineNumber="\1" covered="false"\/>/p'    \
      -e 's/^ *\([0-9][0-9]*\): [1-9].*$/    <lineToCover lineNumber="\1" covered="true"\/>/p' \
      -e 's/^$/  <\/file>/p'
}

function xccov_to_generic {
  local xcresult="$1"

  echo '<coverage version="1">'
  xcrun xccov view --archive "$xcresult" | convert_xccov_to_xml
  echo '</coverage>'
}

function check_xcode_version() {
  local major=${1:-0} minor=${2:-0}
  return $(( (major >= 14) || (major == 13 && minor >= 3) ))
}

if ! xcode_version="$(xcodebuild -version | sed -n '1s/^Xcode \([0-9.]*\)$/\1/p')"; then
  echo 'Failed to get Xcode version' 1>&2
  exit 1
elif check_xcode_version ${xcode_version//./ }; then
  echo "Xcode version '$xcode_version' not supported, version 13.3 or above is required" 1>&2
  exit 1
fi

xcresult=$BITRISE_XCRESULT_PATH
if [[ ! -d $xcresult ]]; then
  echo "Path not found: $xcresult" 1>&2
  exit 1
elif [[ $xcresult != *".xcresult"* ]]; then
  echo "Expecting input to match '*.xcresult', got: $xcresult" 1>&2
  exit 1
fi

# write the conversion to the specified coverage path
xccov_to_generic "$xcresult" > "$covpath"
