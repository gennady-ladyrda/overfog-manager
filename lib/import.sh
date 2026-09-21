#!/bin/sh

import_happ_profile() {
    input="$1"
    name="$2"
    country="$3"
    output="$4"

    jq -e \
        --arg name "$name" \
        --arg country "$country" '
        ([.outbounds[] | select(.protocol == "vless")] | length) as $count
        | if $count != 1 then
            error("expected exactly one VLESS outbound")
          else
            ([.outbounds[] | select(.protocol == "vless")][0]) as $source
            | ($source.settings.vnext[0]) as $server
            | ($server.users[0]) as $user
            | ($source.streamSettings.realitySettings) as $reality
            | if ($server.address | type) != "string"
              or ($server.port | type) != "number"
              or ($user.id | type) != "string"
              or ($reality.serverName | type) != "string"
              or ($reality.publicKey | type) != "string"
              or ($reality.shortId | type) != "string"
              then error("HAPP VLESS/REALITY fields are incomplete")
              else {
                name: $name,
                country: $country,
                outbound: {
                  type: "vless",
                  tag: "overfog",
                  server: $server.address,
                  server_port: $server.port,
                  uuid: $user.id,
                  flow: ($user.flow // ""),
                  tls: {
                    enabled: true,
                    server_name: $reality.serverName,
                    utls: {
                      enabled: true,
                      fingerprint: ($reality.fingerprint // "")
                    },
                    reality: {
                      enabled: true,
                      public_key: $reality.publicKey,
                      short_id: $reality.shortId
                    }
                  }
                }
              }
              end
          end
    ' "$input" > "$output"
}

derive_happ_profile_name() {
    input="$1"

    jq -r '.remarks // empty' "$input" \
        | sed -e 's/^[[:space:]]*//' \
              -e 's/[[:space:]]*$//' \
              -e 's/[[:space:]][[:space:]]*/_/g' \
              -e 's/\.\.//g' \
        | tr -d '/\\'
}
