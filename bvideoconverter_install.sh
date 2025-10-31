#!/bin/bash

# Configuration
REPO_URL="https://repo.bittiainen.com"
KEY_FILE="msilvennoinen_bvc_public_key.asc"
LIST_FILE="bvideoconverter.list"
KEY_DEST="/usr/share/keyrings/bvideoconverter-key.asc"
LIST_DEST="/etc/apt/sources.list.d/bvideoconverter.list"
PACKAGE_NAME="bvideoconverter"
MINT_MIRROR="https://mirror.bahnhof.net/pub/linuxmint/packages"
UBUNTU_MIRROR="http://ftp.uninett.no/ubuntu"

# Define program categories
VIDEO_EDITORS="kdenlive openshot-qt shotcut"
SUBTITLE_EDITORS="gnome-subtitles gaupol subtitlecomposer"
PICTURE_VIEWERS="xviewer eog gpicview"
VIDEO_PLAYERS="celluloid vlc mpv"
PICTURE_EDITORS="gimp krita pinta"
SCREEN_CAPTURES="simplescreenrecorder recordmydesktop"
OTHER_PROGRAMS="flameshot"

# Initialize arrays to track failed installations
declare -A FAILED_CATEGORIES
declare -A INSTALLED_CATEGORIES

# Category translations
declare -A CATEGORY_NAMES_FI
declare -A CATEGORY_NAMES_SV
CATEGORY_NAMES_FI=(
    ["Video Editor"]="Videoeditori"
    ["Subtitle Editor"]="Tekstityseditori"
    ["Picture Viewer"]="Kuvien katseluohjelma"
    ["Video Player"]="Videosoitin"
    ["Picture Editor"]="Kuvien muokkausohjelma"
    ["Screen Capture"]="Näytön kaappaus"
    ["Other Programs"]="Muut ohjelmat"
)
CATEGORY_NAMES_SV=(
    ["Video Editor"]="Videoredigerare"
    ["Subtitle Editor"]="Undertextredigerare"
    ["Picture Viewer"]="Bildvisare"
    ["Video Player"]="Videospelare"
    ["Picture Editor"]="Bildredigerare"
    ["Screen Capture"]="Skärminspelning"
    ["Other Programs"]="Andra program"
)

# Check for required tools
for cmd in curl apt-get add-apt-repository dpkg grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is required but not installed."
        echo "Virhe: $cmd vaaditaan, mutta sitä ei ole asennettu."
        echo "Fel: $cmd krävs men är inte installerat."
        exit 1
    fi
done

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root (use sudo)."
    echo "Tämä skripti on suoritettava pääkäyttäjänä (käytä sudo)."
    echo "Detta skript måste köras som root (använd sudo)."
    exit 1
fi

# Detect system codename
CODENAME="unknown"
if [ -f /etc/os-release ]; then
    CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2 | tr -d '"')
fi
if [ "$CODENAME" = "unknown" ]; then
    echo "Warning: Could not detect system codename. Using 'jammy' as default."
    echo "Varoitus: Järjestelmän koodinimeä ei voitu tunnistaa. Käytetään 'jammy' oletuksena."
    echo "Varning: Kunde inte identifiera systemets kodnamn. Använder 'jammy' som standard."
    CODENAME="jammy"
fi

# Fix repository mirrors
echo "Configuring repositories for $CODENAME..."
echo "Määritetään arkistot koodinimelle $CODENAME..."
echo "Konfigurerar förråd för kodnamn $CODENAME..."
for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    if [ -f "$file" ]; then
        sed -i 's|http://mirrors.nic.funet.fi/linuxmint|'$MINT_MIRROR'|g' "$file"
        sed -i 's|http://packages.linuxmint.com|'$MINT_MIRROR'|g' "$file"
        sed -i 's|http://archive.ubuntu.com/ubuntu|'$UBUNTU_MIRROR'|g' "$file"
        sed -i 's|http://mint-mirror.mit.edu/linuxmint-packages|'$MINT_MIRROR'|g' "$file"
    fi
done

# Ensure Linux Mint and Ubuntu repositories are enabled, avoiding duplicates
if ! grep -r -q "$MINT_MIRROR.*$CODENAME.*main.*upstream.*import" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "Adding Linux Mint mirror for $CODENAME..."
    echo "Lisätään Linux Mintin peili koodinimelle $CODENAME..."
    echo "Lägger till Linux Mint spegel för $CODENAME..."
    echo "deb $MINT_MIRROR $CODENAME main upstream import" | tee /etc/apt/sources.list.d/mint-$CODENAME.list
fi
if ! grep -r -q "$UBUNTU_MIRROR.*$CODENAME.*main.*universe.*multiverse.*restricted" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "Adding Ubuntu mirror for $CODENAME..."
    echo "Lisätään Ubuntun peili koodinimelle $CODENAME..."
    echo "Lägger till Ubuntu spegel för $CODENAME..."
    echo "deb $UBUNTU_MIRROR $CODENAME main universe multiverse restricted" | tee /etc/apt/sources.list.d/ubuntu-$CODENAME.list
fi

# Enable universe and multiverse repositories
echo "Enabling universe and multiverse repositories if not already enabled..."
echo "Otetaan käyttöön universe- ja multiverse-arkistot, jos ne eivät ole jo käytössä..."
echo "Aktiverar universe- och multiverse-förråd om de inte redan är aktiverade..."
if ! add-apt-repository -y universe; then
    echo "Warning: Failed to enable universe repository."
    echo "Varoitus: Universe-arkiston käyttöönotto epäonnistui."
    echo "Varning: Misslyckades med att aktivera universe-förrådet."
fi
if ! add-apt-repository -y multiverse; then
    echo "Warning: Failed to enable multiverse repository."
    echo "Varoitus: Multiverse-arkiston käyttöönotto epäonnistui."
    echo "Varning: Misslyckades med att aktivera multiverse-förrådet."
fi

# Enable 32-bit architecture for compatibility
echo "Enabling 32-bit architecture for compatibility..."
echo "Otetaan käyttöön 32-bittinen arkkitehtuuri yhteensopivuuden vuoksi..."
echo "Aktiverar 32-bitars arkitektur för kompatibilitet..."
dpkg --add-architecture i386 >/dev/null 2>&1 || {
    echo "Warning: Failed to enable 32-bit architecture."
    echo "Varoitus: 32-bittisen arkkitehtuurin käyttöönotto epäonnistui."
    echo "Varning: Misslyckades med att aktivera 32-bitars arkitektur."
}

# Update package cache after all repository changes
echo "Updating package cache after repository configuration..."
echo "Päivitetään pakettivälimuistia arkiston asetusten jälkeen..."
echo "Uppdaterar paketcache efter förrådskonfiguration..."
if ! apt-get update 2>/tmp/apt_error.log; then
    echo "Warning: Failed to update some repositories. See /tmp/apt_error.log for details."
    echo "Varoitus: Joidenkin arkistojen päivitys epäonnistui. Katso lisätiedot: /tmp/apt_error.log"
    echo "Varning: Misslyckades med att uppdatera vissa förråd. Se detaljer i /tmp/apt_error.log"
    if ! curl -fsSL "$REPO_URL/Packages" >/dev/null; then
        echo "Error: bvideoconverter repository ($REPO_URL) is not accessible."
        echo "Virhe: bvideoconverter-arkisto ($REPO_URL) ei ole saatavilla."
        echo "Fel: bvideoconverter-förrådet ($REPO_URL) är inte tillgängligt."
        exit 1
    fi
fi

# Download GPG key
echo "Downloading GPG key from $REPO_URL/$KEY_FILE..."
echo "Ladataan GPG-avain osoitteesta $REPO_URL/$KEY_FILE..."
echo "Laddar ner GPG-nyckel från $REPO_URL/$KEY_FILE..."
if ! curl -fsSL "$REPO_URL/$KEY_FILE" -o "$KEY_DEST"; then
    echo "Error: Failed to download GPG key from $REPO_URL/$KEY_FILE."
    echo "Virhe: GPG-avaimen lataaminen osoitteesta $REPO_URL/$KEY_FILE epäonnistui."
    echo "Fel: Misslyckades med att ladda ner GPG-nyckel från $REPO_URL/$KEY_FILE."
    exit 1
fi

# Set key permissions
chmod 644 "$KEY_DEST"

# Download and install .list file
echo "Downloading repository list from $REPO_URL/$LIST_FILE..."
echo "Ladataan arkiston lista osoitteesta $REPO_URL/$LIST_FILE..."
echo "Laddar ner förrådslista från $REPO_URL/$LIST_FILE..."
if ! curl -fsSL "$REPO_URL/$LIST_FILE" -o "$LIST_DEST"; then
    echo "Error: Failed to download repository list from $REPO_URL/$LIST_FILE."
    echo "Virhe: Arkiston listan lataaminen osoitteesta $REPO_URL/$LIST_FILE epäonnistui."
    echo "Fel: Misslyckades med att ladda ner förrådslista från $REPO_URL/$LIST_FILE."
    rm -f "$KEY_DEST"
    exit 1
fi

# Set list permissions
chmod 644 "$LIST_DEST"

# Prompt for bvideoconverter installation
echo "Repository added successfully! Would you like to install $PACKAGE_NAME now? (y/n)"
echo "Arkisto lisätty onnistuneesti! Haluatko asentaa $PACKAGE_NAME nyt? (k/e)"
echo "Förråd tillagt! Vill du installera $PACKAGE_NAME nu? (j/n)"
read -p "Enter y/k/j for yes, n/e for no: " answer
if [ "$answer" = "y" ] || [ "$answer" = "k" ] || [ "$answer" = "j" ]; then
    echo "Installing $PACKAGE_NAME..."
    echo "Asennetaan $PACKAGE_NAME..."
    echo "Installerar $PACKAGE_NAME..."
    # Retry installation up to 3 times
    for attempt in {1..3}; do
        if apt-get install -y "$PACKAGE_NAME" 2>/tmp/bvideoconverter_install.log; then
            echo "Installation complete! Find BVideoconverter in the menu under 'Ääni & video' / 'Ljud & video'."
            echo "Asennus valmis! Löydät BVideomuunnin valikosta kohdasta 'Ääni & video'."
            echo "Installation slutförd! Hitta BVideoconverter i menyn under 'Ljud & video'."
            break
        else
            echo "Attempt $attempt: Failed to install $PACKAGE_NAME. See /tmp/bvideoconverter_install.log for details."
            echo "Yritys $attempt: $PACKAGE_NAME asennus epäonnistui. Katso lisätiedot: /tmp/bvideoconverter_install.log"
            echo "Försök $attempt: Misslyckades med att installera $PACKAGE_NAME. Se detaljer i /tmp/bvideoconverter_install.log"
            sleep 2
            if [ "$attempt" -eq 3 ]; then
                echo "Error: Failed to install $PACKAGE_NAME after 3 attempts. Check repository or network."
                echo "Virhe: $PACKAGE_NAME asennus epäonnistui kolmen yrityksen jälkeen. Tarkista arkisto tai verkko."
                echo "Fel: Misslyckades med att installera $PACKAGE_NAME efter 3 försök. Kontrollera förråd eller nätverk."
                rm -f "$KEY_DEST" "$LIST_DEST"
                exit 1
            fi
        fi
    done
else
    echo "Repository added. You can install $PACKAGE_NAME later with: sudo apt install $PACKAGE_NAME"
    echo "Arkisto lisätty. Voit asentaa $PACKAGE_NAME myöhemmin komennolla: sudo apt install $PACKAGE_NAME"
    echo "Förråd tillagt. Du kan installera $PACKAGE_NAME senare med: sudo apt install $PACKAGE_NAME"
fi

# Function to check if a program is installed
is_installed() {
    local pkg="$1"
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    return 1
}

# Function to try installing one program from a category
try_install_category() {
    local category_name="$1"
    local category_name_fi="$2"
    local category_name_sv="$3"
    local programs="$4"
    local installed=false
    for pkg in $programs; do
        if is_installed "$pkg"; then
            echo "$pkg is already installed for $category_name."
            echo "$pkg on jo asennettu kategoriaan $category_name_fi."
            echo "$pkg är redan installerat för $category_name_sv."
            INSTALLED_CATEGORIES["$category_name"]="$pkg"
            installed=true
            break
        fi
        if apt-cache policy "$pkg" | grep -q "Candidate: "; then
            echo "Attempting to install $pkg for $category_name via apt..."
            echo "Yritetään asentaa $pkg kategoriaan $category_name_fi apt:n kautta..."
            echo "Försöker installera $pkg för $category_name_sv via apt..."
            if apt-get install -y "$pkg" >/tmp/install_category.log 2>&1; then
                INSTALLED_CATEGORIES["$category_name"]="$pkg"
                installed=true
                break
            fi
        fi
    done
    if ! $installed; then
        FAILED_CATEGORIES["$category_name"]="$programs"
    fi
}

# Attempt to install one program from each category
echo "Attempting to install recommended programs for video and image editing..."
echo "Yritetään asentaa suositeltuja ohjelmia video- ja kuvankäsittelyyn..."
echo "Försöker installera rekommenderade program för video- och bildbehandling..."
try_install_category "Video Editor" "${CATEGORY_NAMES_FI[Video Editor]}" "${CATEGORY_NAMES_SV[Video Editor]}" "$VIDEO_EDITORS"
try_install_category "Subtitle Editor" "${CATEGORY_NAMES_FI[Subtitle Editor]}" "${CATEGORY_NAMES_SV[Subtitle Editor]}" "$SUBTITLE_EDITORS"
try_install_category "Picture Viewer" "${CATEGORY_NAMES_FI[Picture Viewer]}" "${CATEGORY_NAMES_SV[Picture Viewer]}" "$PICTURE_VIEWERS"
try_install_category "Video Player" "${CATEGORY_NAMES_FI[Video Player]}" "${CATEGORY_NAMES_SV[Video Player]}" "$VIDEO_PLAYERS"
try_install_category "Picture Editor" "${CATEGORY_NAMES_FI[Picture Editor]}" "${CATEGORY_NAMES_SV[Picture Editor]}" "$PICTURE_EDITORS"
try_install_category "Screen Capture" "${CATEGORY_NAMES_FI[Screen Capture]}" "${CATEGORY_NAMES_SV[Screen Capture]}" "$SCREEN_CAPTURES"
try_install_category "Other Programs" "${CATEGORY_NAMES_FI[Other Programs]}" "${CATEGORY_NAMES_SV[Other Programs]}" "$OTHER_PROGRAMS"

# Install simplescreenrecorder-lib:i386 if simplescreenrecorder is installed
if [ -n "${INSTALLED_CATEGORIES[Screen Capture]}" ] && [[ "${INSTALLED_CATEGORIES[Screen Capture]}" == "simplescreenrecorder" ]]; then
    echo "Attempting to install simplescreenrecorder-lib:i386 for compatibility..."
    echo "Yritetään asentaa simplescreenrecorder-lib:i386 yhteensopivuuden vuoksi..."
    echo "Försöker installera simplescreenrecorder-lib:i386 för kompatibilitet..."
    apt-get install -y simplescreenrecorder-lib:i386 >/tmp/install_category.log 2>&1 || {
        echo "Warning: Failed to install simplescreenrecorder-lib:i386."
        echo "Varoitus: simplescreenrecorder-lib:i386 asennus epäonnistui."
        echo "Varning: Misslyckades med att installera simplescreenrecorder-lib:i386."
    }
fi

# Report installed and missing programs
echo "Installation summary:"
echo "Asennusyhteenveto:"
echo "Installationssammanfattning:"
for category in "${!INSTALLED_CATEGORIES[@]}"; do
    echo "Successfully installed ${INSTALLED_CATEGORIES[$category]} for $category."
    echo "Asennettu onnistuneesti ${INSTALLED_CATEGORIES[$category]} kategoriaan ${CATEGORY_NAMES_FI[$category]}."
    echo "Installerat ${INSTALLED_CATEGORIES[$category]} för ${CATEGORY_NAMES_SV[$category]}."
done

if [ ${#FAILED_CATEGORIES[@]} -gt 0 ]; then
    echo "The following categories could not be installed (no available programs):"
    echo "Seuraavia kategorioita ei voitu asentaa (ei saatavilla olevia ohjelmia):"
    echo "Följande kategorier kunde inte installeras (inga tillgängliga program):"
    for category in "${!FAILED_CATEGORIES[@]}"; do
        echo "$category: ${FAILED_CATEGORIES[$category]}"
        echo "To install manually, ensure 'universe' and 'multiverse' repositories are enabled and run:"
        echo "sudo apt update && sudo apt install ${FAILED_CATEGORIES[$category]}"
        if [ "$category" = "Video Editor" ]; then
            echo "Or download the AppImage from https://kdenlive.org/en/download/"
        fi
        if [ "$category" = "Picture Viewer" ]; then
            echo "For xviewer, ensure Linux Mint repositories are enabled: echo 'deb $MINT_MIRROR $CODENAME main upstream import' | sudo tee /etc/apt/sources.list.d/mint-$CODENAME.list && sudo apt update"
            echo "Or install eog/gpicview."
        fi
        if [ "$category" = "Subtitle Editor" ]; then
            echo "For subtitlecomposer, you may need a third-party PPA or install gnome-subtitles/gaupol."
            echo "Or download from: https://sourceforge.net/projects/gnome-subtitles/"
        fi
        if [ "$category" = "Screen Capture" ]; then
            echo "For simplescreenrecorder, ensure 32-bit support: sudo apt install simplescreenrecorder-lib:i386"
            echo "Or download from: https://sourceforge.net/projects/recordmydesktop/"
        fi
        echo "${CATEGORY_NAMES_FI[$category]}: ${FAILED_CATEGORIES[$category]}"
        echo "Asenna manuaalisesti varmistamalla, että 'universe' ja 'multiverse' arkistot ovat käytössä, ja suorita:"
        echo "sudo apt update && sudo apt install ${FAILED_CATEGORIES[$category]}"
        if [ "$category" = "Video Editor" ]; then
            echo "Tai lataa AppImage osoitteesta https://kdenlive.org/en/download/"
        fi
        if [ "$category" = "Picture Viewer" ]; then
            echo "Xviewerin osalta varmista Linux Mintin arkistot: echo 'deb $MINT_MIRROR $CODENAME main upstream import' | sudo tee /etc/apt/sources.list.d/mint-$CODENAME.list && sudo apt update"
            echo "Tai asenna eog/gpicview."
        fi
        if [ "$category" = "Subtitle Editor" ]; then
            echo "Subtitlecomposerin osalta saatat tarvita kolmannen osapuolen PPA:ta tai asentaa gnome-subtitles/gaupol."
            echo "Tai lataa osoitteesta: https://sourceforge.net/projects/gnome-subtitles/"
        fi
        if [ "$category" = "Screen Capture" ]; then
            echo "Simplescreenrecorderin osalta varmista 32-bittinen tuki: sudo apt install simplescreenrecorder-lib:i386"
            echo "Tai lataa osoitteesta: https://sourceforge.net/projects/recordmydesktop/"
        fi
        echo "${CATEGORY_NAMES_SV[$category]}: ${FAILED_CATEGORIES[$category]}"
        echo "För att installera manuellt, säkerställ att 'universe' och 'multiverse' förråd är aktiverade och kör:"
        echo "sudo apt update && sudo apt install ${FAILED_CATEGORIES[$category]}"
        if [ "$category" = "Video Editor" ]; then
            echo "Eller ladda ner AppImage från https://kdenlive.org/en/download/"
        fi
        if [ "$category" = "Picture Viewer" ]; then
            echo "För xviewer, säkerställ att Linux Mint-förråd är aktiverade: echo 'deb $MINT_MIRROR $CODENAME main upstream import' | sudo tee /etc/apt/sources.list.d/mint-$CODENAME.list && sudo apt update"
            echo "Eller installera eog/gpicview."
        fi
        if [ "$category" = "Subtitle Editor" ]; then
            echo "För subtitlecomposer, du kan behöva en tredjeparts-PPA eller installera gnome-subtitles/gaupol."
            echo "Eller ladda ner från: https://sourceforge.net/projects/gnome-subtitles/"
        fi
        if [ "$category" = "Screen Capture" ]; then
            echo "För simplescreenrecorder, säkerställ 32-bitars stöd: sudo apt install simplescreenrecorder-lib:i386"
            echo "Eller ladda ner från: https://sourceforge.net/projects/recordmydesktop/"
        fi
    done
    echo "To enable repositories: sudo add-apt-repository universe && sudo add-apt-repository multiverse && sudo apt update"
    echo "Ottaaksesi arkistot käyttöön: sudo add-apt-repository universe && sudo add-apt-repository multiverse && sudo apt update"
    echo "För att aktivera förråd: sudo add-apt-repository universe && sudo add-apt-repository multiverse && sudo apt update"
    echo "To ensure Linux Mint repositories: echo 'deb $MINT_MIRROR $CODENAME main upstream import' | sudo tee /etc/apt/sources.list.d/mint-$CODENAME.list && sudo apt update"
    echo "Varmista Linux Mintin arkistot: echo 'deb $MINT_MIRROR $CODENAME main upstream import' | sudo tee /etc/apt/sources.list.d/mint-$CODENAME.list && sudo apt update"
    echo "För att säkerställa Linux Mint-förråd: echo 'deb $MINT_MIRROR $CODENAME main upstream import' | sudo tee /etc/apt/sources.list.d/mint-$CODENAME.list && sudo apt update"
else
    echo "All recommended programs installed successfully."
    echo "Kaikki suositellut ohjelmat asennettu onnistuneesti."
    echo "Alla rekommenderade program installerades framgångsrikt."
fi

exit 0
