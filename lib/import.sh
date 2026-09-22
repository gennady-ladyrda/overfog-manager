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

    jq -r '
        def transliterate:
            explode
            | map(
                if . >= 48 and . <= 57 then [.] | implode
                elif . >= 65 and . <= 90 then [.] | implode
                elif . >= 97 and . <= 122 then [.] | implode
                elif . == 45 or . == 95 then [.] | implode
                elif . == 9 or . == 10 or . == 13 or . == 32 then "_"
                elif . == 1040 then "A" elif . == 1072 then "a"
                elif . == 1041 then "B" elif . == 1073 then "b"
                elif . == 1042 then "V" elif . == 1074 then "v"
                elif . == 1043 then "G" elif . == 1075 then "g"
                elif . == 1044 then "D" elif . == 1076 then "d"
                elif . == 1045 then "E" elif . == 1077 then "e"
                elif . == 1025 then "Yo" elif . == 1105 then "yo"
                elif . == 1046 then "Zh" elif . == 1078 then "zh"
                elif . == 1047 then "Z" elif . == 1079 then "z"
                elif . == 1048 then "I" elif . == 1080 then "i"
                elif . == 1049 then "Y" elif . == 1081 then "y"
                elif . == 1050 then "K" elif . == 1082 then "k"
                elif . == 1051 then "L" elif . == 1083 then "l"
                elif . == 1052 then "M" elif . == 1084 then "m"
                elif . == 1053 then "N" elif . == 1085 then "n"
                elif . == 1054 then "O" elif . == 1086 then "o"
                elif . == 1055 then "P" elif . == 1087 then "p"
                elif . == 1056 then "R" elif . == 1088 then "r"
                elif . == 1057 then "S" elif . == 1089 then "s"
                elif . == 1058 then "T" elif . == 1090 then "t"
                elif . == 1059 then "U" elif . == 1091 then "u"
                elif . == 1060 then "F" elif . == 1092 then "f"
                elif . == 1061 then "Kh" elif . == 1093 then "kh"
                elif . == 1062 then "Ts" elif . == 1094 then "ts"
                elif . == 1063 then "Ch" elif . == 1095 then "ch"
                elif . == 1064 then "Sh" elif . == 1096 then "sh"
                elif . == 1065 then "Shch" elif . == 1097 then "shch"
                elif . == 1066 or . == 1068 then ""
                elif . == 1067 then "Y" elif . == 1099 then "y"
                elif . == 1069 then "E" elif . == 1101 then "e"
                elif . == 1070 then "Yu" elif . == 1102 then "yu"
                elif . == 1071 then "Ya" elif . == 1103 then "ya"
                else ""
                end
            )
            | join("");
        (.remarks // "") | transliterate
    ' "$input" \
        | sed -e 's/^_*//' -e 's/_*$//' -e 's/__*/_/g'
}
