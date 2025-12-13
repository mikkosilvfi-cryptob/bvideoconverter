#!/bin/bash
# BVideoconverter installer (bvideoconverter_install9.sh)
# Uses static mirror support from bvc-mirror-support package
# Languages: English / Suomi / Svenska
# BVideoconverter Installer Script
#
# Copyright (C) 2024 Mikko Silvennoinen
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this script. If not, see <https://www.gnu.org/licenses/>.

set -e

# ============================================================
# 0. Language selection (EN / FI / SV)
# ============================================================

echo "Select language / Valitse kieli / Välj språk:"
echo "  1) English"
echo "  2) Suomi"
echo "  3) Svenska"
read -r -p "Choice / Valinta / Val: " lang_choice

case "$lang_choice" in
    2) LANG_CODE="FI" ;;
    3) LANG_CODE="SV" ;;
    *) LANG_CODE="EN" ;;  # default English
esac

say() {
    local en="$1"
    local fi="$2"
    local sv="$3"
    case "$LANG_CODE" in
        FI) echo "$fi" ;;
        SV) echo "$sv" ;;
        *)  echo "$en" ;;
    esac
}

show_info_gui() {
    local msg="$1"
    if { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; } && command -v zenity >/dev/null 2>&1; then
        zenity --info --width=480 --title="BVideoconverter Installer" --text="$msg" 2>/dev/null || echo "$msg"
    elif { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; } && command -v yad >/dev/null 2>&1; then
        yad --info --width=480 --title="BVideoconverter Installer" --text="$msg" --button=OK 2>/dev/null || echo "$msg"
    else
        echo "$msg"
    fi
}

prompt_yn() {
    local q_en="$1"
    local q_fi="$2"
    local q_sv="$3"
    local answer c
    say "$q_en" "$q_fi" "$q_sv"
    read -r -p "> " answer
    c="${answer:0:1}"

    case "$LANG_CODE" in
        EN)
            [[ "$c" =~ [yY] ]] && return 0 || return 1
            ;;
        FI)
            [[ "$c" =~ [kK] ]] && return 0 || return 1  # k = kyllä
            ;;
        SV)
            [[ "$c" =~ [jJ] ]] && return 0 || return 1  # j = ja
            ;;
        *)
            [[ "$c" =~ [yY] ]] && return 0 || return 1
            ;;
    esac
}

# ============================================================
# 1. Basic checks (tools, root)
# ============================================================

REQUIRED_CMDS="curl apt-get add-apt-repository dpkg grep"
for cmd in $REQUIRED_CMDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        say \
"Error: $cmd is required but not installed." \
"Virhe: $cmd vaaditaan, mutta sitä ei ole asennettu." \
"Fel: $cmd krävs men är inte installerat."
        exit 1
    fi
done

if [ "$(id -u)" != "0" ]; then
    say \
"This script must be run as root (use sudo)." \
"Tämä skripti on suoritettava pääkäyttäjänä (käytä sudo)." \
"Detta skript måste köras som root (använd sudo)."
    exit 1
fi

# ============================================================
# 2. Configuration & distro info
# ============================================================

REPO_URL="https://repo.bittiainen.com"
KEY_FILE="msilvennoinen_bvc_public_key.asc"
LIST_FILE="bvideoconverter.list"
KEY_DEST="/usr/share/keyrings/bvideoconverter-key.asc"
LIST_DEST="/etc/apt/sources.list.d/bvideoconverter.list"
PACKAGE_NAME="bvideoconverter"

MINT_MIRROR="https://packages.linuxmint.com"
UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"
ORIG_MINT_MIRROR="https://mirror.bahnhof.net/pub/linuxmint/packages"
ORIG_UBUNTU_MIRROR="http://ftp.uninett.no/ubuntu"

BACKUP_DIR="/etc/apt/bvc-backups"
mkdir -p "$BACKUP_DIR"

. /etc/os-release 2>/dev/null || true
CODENAME=${VERSION_CODENAME:-$(lsb_release -c -s 2>/dev/null)}
CODENAME=${CODENAME,,}

say \
"Detected system codename: $CODENAME" \
"Havaittu järjestelmän koodinimi: $CODENAME" \
"Upptäckt systemkodnamn: $CODENAME"

DEBIAN_BASED=false
if [[ "$CODENAME" =~ ^(gigi|faye)$ ]]; then
    DEBIAN_BASED=true
    say \
"Detected Debian-based Linux Mint ($CODENAME)." \
"Havaittu Debian-pohjainen Linux Mint ($CODENAME)." \
"Upptäckte Debian-baserad Linux Mint ($CODENAME)."
fi

# Ubuntu base codename mapping
get_ubuntu_base_codename() {
    local mint="$1"
    case "$mint" in
        # Mint 21.x, 22.x + newer you added like zara, xia, wilma
        vera|vanessa|victoria|virginia|zara|xia|wilma)
            echo "jammy"
            ;;
        # Mint 20.x
        ulyana|ulyssa|uma|una)
            echo "focal"
            ;;
        # Mint 19.x
        tara|tessa|tina|tricia)
            echo "bionic"
            ;;
        # Mint 18.x
        sarah|serena|sonya|sylvia)
            echo "xenial"
            ;;
        # Mint 17.x
        qiana|rebecca|rafaela|rosa)
            echo "trusty"
            ;;
        # older: can be extended if needed
        *)
            echo ""
            ;;
    esac
}

UBUNTU_BASE=""
if ! $DEBIAN_BASED; then
    UBUNTU_BASE=$(get_ubuntu_base_codename "$CODENAME")
    if [ -n "$UBUNTU_BASE" ]; then
        say \
"Ubuntu base codename detected: $UBUNTU_BASE" \
"Havaittu Ubuntu-pohja: $UBUNTU_BASE" \
"Upptäckt Ubuntu-bas: $UBUNTU_BASE"
    else
        say \
"Could not determine Ubuntu base codename for this Mint release (no automatic repo repair)." \
"Ubuntun pohjakoodinimeä ei voitu tunnistaa tälle Mint-versiolle (ei automaattista arkistokorjausta)." \
"Kunde inte fastställa Ubuntu-baskodnamn för denna Mint-version (ingen automatisk förrådskorrigering)."
    fi
fi

# ============================================================
# 3. Load mirror config from static file (bvc-mirror-support)
# ============================================================

load_mirror_from_file() {
    local code="$1"
    local conf="/usr/local/share/bvideoconverter/distro_versions.conf"

    if [ -f "$conf" ]; then
        local MINT_VAL UBUNTU_VAL
        MINT_VAL=$(awk -F= -v s="[$code]" '$0==s{f=1;next}
                                           /^\[/{f=0}
                                           f && $1=="mint_mirror"{print $2}' "$conf")
        UBUNTU_VAL=$(awk -F= -v s="[$code]" '$0==s{f=1;next}
                                            /^\[/{f=0}
                                            f && $1=="ubuntu_mirror"{print $2}' "$conf")

        [ -n "$MINT_VAL" ] && MINT_MIRROR="$MINT_VAL"

        if ! $DEBIAN_BASED; then
            [ -n "$UBUNTU_VAL" ] && UBUNTU_MIRROR="$UBUNTU_VAL"
        else
            UBUNTU_MIRROR=""
        fi
    fi

    MINT_MIRROR=${MINT_MIRROR:-"$ORIG_MINT_MIRROR"}
    if ! $DEBIAN_BASED; then
        UBUNTU_MIRROR=${UBUNTU_MIRROR:-"$ORIG_UBUNTU_MIRROR"}
    else
        UBUNTU_MIRROR=""
    fi
}

load_mirror_from_file "$CODENAME"

say \
"Using Linux Mint mirror: $MINT_MIRROR" \
"Käytetään Linux Mint -peiliä: $MINT_MIRROR" \
"Använder Linux Mint-spegel: $MINT_MIRROR"

if ! $DEBIAN_BASED; then
    say \
"Using Ubuntu mirror: $UBUNTU_MIRROR" \
"Käytetään Ubuntu-peiliä: $UBUNTU_MIRROR" \
"Använder Ubuntu-spegel: $UBUNTU_MIRROR"
else
    say \
"No Ubuntu mirror used (Debian-based Mint)." \
"Ubuntu-peiliä ei käytetä (Debian-pohjainen Mint)." \
"Ubuntu-spegel används inte (Debian-baserad Mint)."
fi

# ============================================================
# 4. Detect package manager
# ============================================================

PM="unknown"
if command -v apt-get >/dev/null 2>&1; then
    PM="apt"
elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"
elif command -v zypper >/dev/null 2>&1; then
    PM="zypper"
fi

if [ "$PM" != "apt" ]; then
    MSG_EN="This installer is intended for Debian-based systems using APT (such as Linux Mint or Ubuntu).

Detected package manager: $PM

For best compatibility with BVideoconverter, Linux Mint is recommended.

If you still want to try installing the .deb package, you can use a conversion tool for your distribution."
    MSG_FI="Tämä asennusohjelma on tarkoitettu Debian-pohjaisille APT-järjestelmille (esim. Linux Mint tai Ubuntu).

Havaittu paketinhallinta: $PM

Parhaan yhteensopivuuden BVideomuuntimen kanssa saat Linux Mint -järjestelmällä.

Jos haluat silti yrittää asentaa .deb-paketin, voit käyttää jakelullesi sopivaa muunnostyökalua."
    MSG_SV="Detta installationsprogram är avsett för Debian-baserade system som använder APT (t.ex. Linux Mint eller Ubuntu).

Upptäckt pakethanterare: $PM

För bästa kompatibilitet med BVideoconverter rekommenderas Linux Mint.

Om du ändå vill försöka installera .deb-paketet kan du använda ett konverteringsverktyg för din distribution."

    case "$LANG_CODE" in
        FI) MSG="$MSG_FI" ;;
        SV) MSG="$MSG_SV" ;;
        *)  MSG="$MSG_EN" ;;
    esac
    show_info_gui "$MSG"
    exit 1
fi

# ============================================================
# 5. Auto-install bvc-mirror-support (if available)
# ============================================================

install_mirror_support() {
    if dpkg -l | grep -q "^ii  bvc-mirror-support "; then
        say \
"bvc-mirror-support is already installed." \
"bvc-mirror-support on jo asennettu." \
"bvc-mirror-support är redan installerat."
        return
    fi

    say \
"Installing bvc-mirror-support (mirror configuration enhancements)..." \
"Asennetaan bvc-mirror-support (peilisäätöjen parannuksia)..." \
"Installerar bvc-mirror-support (förbättrad spegelhantering)..."

    for attempt in 1 2 3; do
        if apt-get install -y bvc-mirror-support >/tmp/bvc_mirror_support.log 2>&1; then
            say \
"bvc-mirror-support installed successfully." \
"bvc-mirror-support asennettu onnistuneesti." \
"bvc-mirror-support installerades framgångsrikt."
            return
        fi
        sleep 2
    done

    say \
"Warning: bvc-mirror-support could not be installed. Continuing without it." \
"Varoitus: bvc-mirror-support -pakettia ei voitu asentaa. Jatketaan ilman sitä." \
"Varning: bvc-mirror-support kunde inte installeras. Fortsätter utan det."
}

install_mirror_support

# ============================================================
# 6. Auto-detect and optionally fix incorrect Ubuntu repo entries
# ============================================================

fix_ubuntu_repos() {

    # Skip on Debian-based Mint or unknown Ubuntu base
    if $DEBIAN_BASED || [ -z "$UBUNTU_BASE" ]; then
        return
    fi

    local any_fixed=false
    local files wrong_main=false wrong_sec=false ts

    files=(/etc/apt/sources.list /etc/apt/sources.list.d/*.list)
    ts=$(date +%Y%m%d%H%M%S)

    # Detect wrong entries
    for f in "${files[@]}"; do
        [ -f "$f" ] || continue
        if grep -qE "ubuntu" "$f"; then
            if grep -qE "ubuntu.*\b$CODENAME\b" "$f"; then
                wrong_main=true
            fi
            if grep -qE "ubuntu.*\b${CODENAME}-security\b" "$f"; then
                wrong_sec=true
            fi
        fi
    done

    # Fix main Ubuntu repos
    if $wrong_main; then
        if prompt_yn \
"Incorrect Ubuntu repository entries were found. Fix main Ubuntu mirrors to use '$UBUNTU_BASE' instead of '$CODENAME'? (y/n)" \
"Havaittiin virheellisiä Ubuntu-arkistorivejä. Korjataanko pääarkistot käyttämään '$UBUNTU_BASE' eikä '$CODENAME'? (k/e)" \
"Felaktiga Ubuntu-förrådsrader hittades. Korrigera huvudförråd att använda '$UBUNTU_BASE' istället för '$CODENAME'? (j/n)"; then

            for f in "${files[@]}"; do
                [ -f "$f" ] || continue
                if grep -qE "ubuntu.*\b$CODENAME\b" "$f"; then
                    cp "$f" "$BACKUP_DIR/$(basename "$f").main.$ts.bak"
                    sed -i -r "/ubuntu/s/\b$CODENAME\b/$UBUNTU_BASE/g" "$f"
                fi
            done

            any_fixed=true

            say \
"Main Ubuntu mirrors corrected to codename '$UBUNTU_BASE'." \
"Ubuntun pääarkistot korjattu koodinimeen '$UBUNTU_BASE'." \
"Huvudförråden för Ubuntu har korrigerats till kodnamn '$UBUNTU_BASE'."
        fi
    fi

    # Fix Ubuntu security repos
    if $wrong_sec; then
        if prompt_yn \
"Incorrect Ubuntu security repository entries were found. Fix security mirrors to use '$UBUNTU_BASE-security' instead of '$CODENAME-security'? (y/n)" \
"Havaittiin virheellisiä Ubuntu security -arkistorivejä. Korjataanko security-arkistot käyttämään '$UBUNTU_BASE-security' eikä '$CODENAME-security'? (k/e)" \
"Felaktiga Ubuntu security-förrådsrader hittades. Korrigera security-förråd att använda '$UBUNTU_BASE-security' istället för '$CODENAME-security'? (j/n)"; then

            for f in "${files[@]}"; do
                [ -f "$f" ] || continue
                if grep -qE "ubuntu.*\b${CODENAME}-security\b" "$f"; then
                    cp "$f" "$BACKUP_DIR/$(basename "$f").sec.$ts.bak"
                    sed -i -r "/ubuntu/s/\b${CODENAME}-security\b/${UBUNTU_BASE}-security/g" "$f"
                fi
            done

            any_fixed=true

            say \
"Ubuntu security mirrors corrected to '$UBUNTU_BASE-security'." \
"Ubuntun security-arkistot korjattu muotoon '$UBUNTU_BASE-security'." \
"Ubuntus security-förråd har korrigerats till '$UBUNTU_BASE-security'."
        fi
    fi

    if $any_fixed; then
        say \
"Any modified repository files were backed up to: /etc/apt/bvc-backups/" \
"Kaikki muokatut arkistotiedostot varmuuskopioitiin hakemistoon: /etc/apt/bvc-backups/" \
"Alla ändrade förrådsfiler säkerhetskopierades till: /etc/apt/bvc-backups/"
    fi
}

fix_ubuntu_repos

# ============================================================
# 7. Optional mirror tweak (Ubuntu-based Mint only)
# ============================================================

if ! $DEBIAN_BASED; then
    if prompt_yn \
"Do you want to optimize Linux Mint/Ubuntu mirrors for speed and compatibility? (y/n)" \
"Haluatko optimoida Linux Mint/Ubuntu -peilit nopeuden ja yhteensopivuuden vuoksi? (k/e)" \
"Vill du optimera Linux Mint/Ubuntu-spegelkällor för hastighet och kompatibilitet? (j/n)"; then

        say \
"Configuring mirrors..." \
"Määritetään peilejä..." \
"Konfigurerar speglar..."

        for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
            [ -f "$file" ] || continue
            sed -i "s|http://mirrors.nic.funet.fi/linuxmint|$MINT_MIRROR|g" "$file"
            sed -i "s|http://packages.linuxmint.com|$MINT_MIRROR|g" "$file"
            sed -i "s|http://archive.ubuntu.com/ubuntu|$UBUNTU_MIRROR|g" "$file"
            sed -i "s|http://mint-mirror.mit.edu/linuxmint-packages|$MINT_MIRROR|g" "$file"
        done
    fi
fi

# ============================================================
# 8. Enable repos & initial update
# ============================================================

say \
"Enabling universe and multiverse repositories if needed..." \
"Otetaan käyttöön universe- ja multiverse-arkistot tarvittaessa..." \
"Aktiverar universe- och multiverse-förråd om det behövs..."

add-apt-repository -y universe  >/dev/null 2>&1 || true
add-apt-repository -y multiverse >/dev/null 2>&1 || true

say \
"Enabling 32-bit architecture (i386) for compatibility..." \
"Otetaan käyttöön 32-bittinen arkkitehtuuri (i386) yhteensopivuuden vuoksi..." \
"Aktiverar 32-bitars arkitektur (i386) för kompatibilitet..."

dpkg --add-architecture i386 >/dev/null 2>&1 || true

say \
"Updating package lists (apt update)..." \
"Päivitetään pakettiluettelot (apt update)..." \
"Uppdaterar paketlistor (apt update)..."

if ! apt-get update; then
    say \
"Warning: some repositories failed to update, but continuing." \
"Varoitus: kaikkia arkistoja ei voitu päivittää, jatketaan silti." \
"Varning: vissa förråd kunde inte uppdateras, fortsätter ändå."
fi

# ============================================================
# 9. Add BVideoconverter repo and key
# ============================================================

say \
"Adding BVideoconverter repository and key..." \
"Lisätään BVideomuuntimen arkisto ja avain..." \
"Lägger till BVideoconverter-förråd och nyckel..."

if ! curl -fsSL "$REPO_URL/$KEY_FILE" -o "$KEY_DEST"; then
    say \
"Error: failed to download GPG key from $REPO_URL/$KEY_FILE." \
"Virhe: GPG-avaimen lataus epäonnistui osoitteesta $REPO_URL/$KEY_FILE." \
"Fel: misslyckades med att ladda ned GPG-nyckel från $REPO_URL/$KEY_FILE."
    exit 1
fi
chmod 644 "$KEY_DEST"

if ! curl -fsSL "$REPO_URL/$LIST_FILE" -o "$LIST_DEST"; then
    say \
"Error: failed to download repository list from $REPO_URL/$LIST_FILE." \
"Virhe: arkistolistan lataus epäonnistui osoitteesta $REPO_URL/$LIST_FILE." \
"Fel: misslyckades med att ladda ned förrådslistan från $REPO_URL/$LIST_FILE."
    rm -f "$KEY_DEST"
    exit 1
fi
chmod 644 "$LIST_DEST"

say \
"Repository added. Updating package lists..." \
"Arkisto lisätty. Päivitetään pakettiluettelot..." \
"Förråd tillagt. Uppdaterar paketlistor..."

apt-get update || true

# ============================================================
# 10. Offer to install BVideoconverter
# ============================================================

if prompt_yn \
"Do you want to install BVideoconverter now? (y/n)" \
"Haluatko asentaa BVideomuuntimen nyt? (k/e)" \
"Vill du installera BVideoconverter nu? (j/n)"; then

    say \
"Installing BVideoconverter..." \
"Asennetaan BVideomuunnin..." \
"Installerar BVideoconverter..."

    if apt-get install -y "$PACKAGE_NAME"; then
        MSG_EN="BVideoconverter installation complete.
You can find it under 'Sound & Video' in the menu."
        MSG_FI="BVideomuuntimen asennus valmis.
Löydät sen valikosta kohdasta 'Ääni & video'."
        MSG_SV="Installationen av BVideoconverter är klar.
Du hittar den i menyn under 'Ljud & video'."

        case "$LANG_CODE" in
            FI) MSG="$MSG_FI" ;;
            SV) MSG="$MSG_SV" ;;
            *)  MSG="$MSG_EN" ;;
        esac
        show_info_gui "$MSG"
    else
        say \
"Error: failed to install BVideoconverter." \
"Virhe: BVideomuuntimen asennus epäonnistui." \
"Fel: det gick inte att installera BVideoconverter."
    fi
else
    say \
"You can install BVideoconverter later with: sudo apt install bvideoconverter" \
"Voit asentaa BVideomuuntimen myöhemmin komennolla: sudo apt install bvideoconverter" \
"Du kan installera BVideoconverter senare med: sudo apt install bvideoconverter"
fi

# ============================================================
# 11. Helper applications (video editors, Flameshot, etc.)
# ============================================================

# Program categories
VIDEO_EDITORS="kdenlive openshot-qt shotcut"
SUBTITLE_EDITORS="gnome-subtitles gaupol subtitlecomposer"
PICTURE_VIEWERS="xviewer eog gpicview"
VIDEO_PLAYERS="celluloid vlc mpv"
PICTURE_EDITORS="gimp krita pinta"
SCREEN_CAPTURES="simplescreenrecorder recordmydesktop"
OTHER_PROGRAMS="flameshot"

declare -A INSTALLED_CATEGORIES
declare -A FAILED_CATEGORIES

declare -A CAT_EN=(
    ["Video Editor"]="Video editor"
    ["Subtitle Editor"]="Subtitle editor"
    ["Picture Viewer"]="Picture viewer"
    ["Video Player"]="Video player"
    ["Picture Editor"]="Picture editor"
    ["Screen Capture"]="Screen capture"
    ["Other Programs"]="Other programs"
)
declare -A CAT_FI=(
    ["Video Editor"]="Videoeditori"
    ["Subtitle Editor"]="Tekstityseditori"
    ["Picture Viewer"]="Kuvien katseluohjelma"
    ["Video Player"]="Videosoitin"
    ["Picture Editor"]="Kuvankäsittelyohjelma"
    ["Screen Capture"]="Näytönkaappausohjelma"
    ["Other Programs"]="Muut ohjelmat"
)
declare -A CAT_SV=(
    ["Video Editor"]="Videoredigerare"
    ["Subtitle Editor"]="Undertextredigerare"
    ["Picture Viewer"]="Bildvisare"
    ["Video Player"]="Videospelare"
    ["Picture Editor"]="Bildredigerare"
    ["Screen Capture"]="Skärminspelning"
    ["Other Programs"]="Andra program"
)

cat_name() {
    local cat="$1"
    case "$LANG_CODE" in
        FI) echo "${CAT_FI[$cat]}" ;;
        SV) echo "${CAT_SV[$cat]}" ;;
        *)  echo "${CAT_EN[$cat]}" ;;
    esac
}

is_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

is_flatpak_installed() {
    local pkg="$1"
    command -v flatpak >/dev/null 2>&1 || return 1
    flatpak list 2>/dev/null | awk '{print $1}' | grep -qx "$pkg"
}

# Refresh package list again to make sure all packages are visible
say \
"Refreshing package list before installing helper programs..." \
"Päivitetään pakettiluettelo ennen apuohjelmien asennusta..." \
"Uppdaterar paketlistan innan hjälpprogram installeras..."
apt-get update -o Acquire::Retries=3 >/dev/null 2>&1 || true

try_install_category() {
    local cat="$1"
    local programs="$2"
    local installed=false

    for pkg in $programs; do
        # APT already installed?
        if is_installed "$pkg"; then
            say \
"$pkg is already installed for category: $(cat_name "$cat")." \
"$pkg on jo asennettu kategoriaan: $(cat_name "$cat")." \
"$pkg är redan installerat för kategori: $(cat_name "$cat")."
            INSTALLED_CATEGORIES["$cat"]="$pkg"
            installed=true
            break
        fi

        # Flatpak installed?
        if is_flatpak_installed "$pkg"; then
            say \
"$pkg is already installed as a Flatpak for category: $(cat_name "$cat")." \
"$pkg on jo asennettu Flatpak-sovelluksena kategoriaan: $(cat_name "$cat")." \
"$pkg är redan installerat som Flatpak för kategori: $(cat_name "$cat")."
            INSTALLED_CATEGORIES["$cat"]="$pkg (Flatpak)"
            installed=true
            break
        fi

        # Try to install via apt
        if apt-get install -y "$pkg" >/tmp/install_category.log 2>&1; then
            if is_installed "$pkg"; then
                INSTALLED_CATEGORIES["$cat"]="$pkg"
                installed=true
                break
            fi
        fi
    done

    if ! $installed; then
        FAILED_CATEGORIES["$cat"]="$programs"
    fi
}

say \
"Installing recommended helper programs for video and image work (one from each category, when possible)..." \
"Asennetaan suositeltuja apuohjelmia video- ja kuvankäsittelyyn (yksi kustakin kategoriasta, jos mahdollista)..." \
"Installerar rekommenderade hjälpprogram för video- och bildhantering (ett från varje kategori när det är möjligt)..."

try_install_category "Video Editor"     "$VIDEO_EDITORS"
try_install_category "Subtitle Editor"  "$SUBTITLE_EDITORS"
try_install_category "Picture Viewer"   "$PICTURE_VIEWERS"
try_install_category "Video Player"     "$VIDEO_PLAYERS"
try_install_category "Picture Editor"   "$PICTURE_EDITORS"
try_install_category "Screen Capture"   "$SCREEN_CAPTURES"
try_install_category "Other Programs"   "$OTHER_PROGRAMS"

if [ "${INSTALLED_CATEGORIES[Screen Capture]}" = "simplescreenrecorder" ]; then
    say \
"Installing simplescreenrecorder-lib:i386 for compatibility..." \
"Asennetaan simplescreenrecorder-lib:i386 yhteensopivuuden vuoksi..." \
"Installerar simplescreenrecorder-lib:i386 för kompatibilitet..."
    apt-get install -y simplescreenrecorder-lib:i386 >/tmp/install_category.log 2>&1 || true
fi

say \
"Installation summary:" \
"Asennusyhteenveto:" \
"Installationssammanfattning:"

for cat in "${!INSTALLED_CATEGORIES[@]}"; do
    pkg="${INSTALLED_CATEGORIES[$cat]}"
    say \
"  $(cat_name "$cat"): $pkg installed." \
"  $(cat_name "$cat"): $pkg asennettu." \
"  $(cat_name "$cat"): $pkg installerat."
done

if [ "${#FAILED_CATEGORIES[@]}" -gt 0 ]; then
    say \
"The following categories could not be installed automatically:" \
"Seuraavia kategorioita ei voitu asentaa automaattisesti:" \
"Följande kategorier kunde inte installeras automatiskt:"
    for cat in "${!FAILED_CATEGORIES[@]}"; do
        pkgs="${FAILED_CATEGORIES[$cat]}"
        say \
"  $(cat_name "$cat"): tried: $pkgs" \
"  $(cat_name "$cat"): yritettiin: $pkgs" \
"  $(cat_name "$cat"): försökte: $pkgs"
    done
fi

say \
"All done. You can now start using BVideoconverter and the installed tools." \
"Valmista. Voit nyt alkaa käyttää BVideomuunninta ja asennettuja työkaluja." \
"Klart. Du kan nu börja använda BVideoconverter och de installerade verktygen."

exit 0


