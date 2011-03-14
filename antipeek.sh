# antipeek.sh
# Ever accidently entered your password into a shell?
# With someone watching?
#
# Antipeek can help!
# It saves salted hashes of your secret password to ~/.antipeek
# and compares each entered bash command to this list.
# If you enter your password, it will clear the screen and remove
# the incident from the shell history.
#
# How to use it?
# Simply source this file.
# Then add your passwords by calling "antipeek_add_password <comment>"
#
# Stefan Tomanek <stefan.tomanek@wertarbyte.de>

ANTIPEEK_PWFILE=~/.antipeek

antipeek_cleanup() {
    if [ $ANTIPEEK_EXTDEBUG_ENABLED ]; then
        shopt -s extdebug
    else
        shopt -u extdebug
    fi
    PROMPT_COMMAND="$ANTIPEEK_OLD_PROMPT_COMMAND"
}

antipeek_password_encountered() {
    clear
    echo "== Antipeek Alert ==" >&2
    echo "You accidently entered your password: $*" >&2
    antipeek_pop_history
}

antipeek_pop_history() {
    local LAST=$(history | awk '{L=$1} END{print L}')
    history -d $LAST
}

antipeek_create_hash() {
    local SALT="$2"
    local STRING="$1"
    local HASHER=md5sum
    
    echo "${SALT}${STRING}" | $HASHER | cut -d" " -f1
}

antipeek_password_check() {
    if [ ! -e "$ANTIPEEK_PWFILE" ]; then
        return 0
    fi
    while read SALT HASH COMMENT; do
        #echo "Command: >$BASH_COMMAND<"
        local CMDHASH=$(antipeek_create_hash "$BASH_COMMAND" "$SALT")
        #echo $CMDHASH " = " $HASH
        if [ "$CMDHASH" = "$HASH" ]; then
            antipeek_password_encountered $COMMENT
            ANTIPEEK_EXTDEBUG_ENABLED=$(! shopt extdebug >/dev/null; echo $?)
            # install callback to reset extdebug
            ANTIPEEK_OLD_PROMPT_COMMAND="$PROMPT_COMMAND"
            PROMPT_COMMAND="antipeek_cleanup"
            shopt -s extdebug
            return 1
            #kill -INT $$
        fi
    done < "$ANTIPEEK_PWFILE"
}

antipeek_add_password() {
    local COMMENT="$*"
    read -sp "Secret: " PASS
    local SALT=$RANDOM
    local HASH=$(antipeek_create_hash "$PASS" "$SALT")
    echo "$SALT $HASH $COMMENT" >> "$ANTIPEEK_PWFILE"
    echo "" >&2
    #echo "Added Password >$PASS<"
}

trap antipeek_password_check DEBUG

echo "Antipeek loaded." >&2
if [ -r "$ANTIPEEK_PWFILE" ]; then
    echo "$(wc -l < $ANTIPEEK_PWFILE) passwords in $ANTIPEEK_PWFILE" >&2
fi
echo "Enter 'antipeek_add_password' to add additional secrets" >&2
