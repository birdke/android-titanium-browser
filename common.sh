export SCRIPT_DIR=$(realpath $(dirname $0))

replace() {
    export org=$2 new=$3
    find $1 -type f -exec sed -i 's@'$org'@'$new'@g' {} \;
}

set_keys() {
    mkdir -p "$SCRIPT_DIR/keys"
    printf '%s' "$LOCAL_TEST_JKS" | base64 -d > "$SCRIPT_DIR/keys/local.properties"
    printf '%s' "$STORE_TEST_JKS" | base64 -d > "$SCRIPT_DIR/keys/test.jks"
    # Properties are frequently created on Windows. Remove a trailing CR so it
    # cannot silently become part of the alias or passwords when read on Linux.
    sed -i 's/\r$//' "$SCRIPT_DIR/keys/local.properties"
    unset LOCAL_TEST_JKS
    unset STORE_TEST_JKS
}

read_signing_property() {
    local property_name=$1
    local property_value
    property_value=$(sed -n "s/^${property_name}=//p" "$SCRIPT_DIR/keys/local.properties" | head -n 1)
    property_value=${property_value%$'\r'}
    if [[ -z "$property_value" ]]; then
        echo "Missing signing property: $property_name" >&2
        return 1
    fi
    printf '%s' "$property_value"
}

validate_signing_key() {
    local keytool=$1
    local key_alias store_password
    key_alias=$(read_signing_property keyAlias)
    store_password=$(read_signing_property storePassword)
    "$keytool" -list -keystore "$SCRIPT_DIR/keys/test.jks" \
        -storepass "$store_password" -alias "$key_alias" >/dev/null
    echo "Signing keystore and alias validated."
}

sign_apk() {
    local apksigner key_alias key_password store_password
    apksigner=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort | tail -n 1)
    key_alias=$(read_signing_property keyAlias)
    key_password=$(read_signing_property keyPassword)
    store_password=$(read_signing_property storePassword)
    "$apksigner" sign -verbose -ks "$SCRIPT_DIR/keys/test.jks" \
        --ks-pass "pass:$store_password" --key-pass "pass:$key_password" \
        --ks-key-alias "$key_alias" --out "$2" "$1" || exit 1
}

sign_aab() {
    local key_alias key_password store_password
    key_alias=$(read_signing_property keyAlias)
    key_password=$(read_signing_property keyPassword)
    store_password=$(read_signing_property storePassword)
    jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
        -keystore "$SCRIPT_DIR/keys/test.jks" -storepass "$store_password" \
        -keypass "$key_password" -signedjar "$2" "$1" "$key_alias" || exit 1
}

version_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}
