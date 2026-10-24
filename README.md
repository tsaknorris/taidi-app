# Taidi App

*[In English (README.en.md)](README.en.md)*

Kun huone tai sovellusvalikko on sekaisin, se siivotaan. Ei "tidy up", vaan **Taidi App**.

Taidi App tekee Sailfish OS:n sovellusvalikosta (Lipstick) siistin ja helposti hallittavan:
1. **5×7 tiivis ruudukko** – kaikki sovellukset ja kansiot mahtuvat yhdelle ruudulle ilman kilometrien vierittämistä.
2. **Kansioiden hallinta yhdellä napautuksella** – ei enää sormella raahaamista ja ohi lipeämistä.
3. **Puhdas .patch-toteutus** – ei sisällä Jollan proprietary-koodia, vaan patchaa laitteen omat tiedostot turvallisesti.
4. **Komentorivityökalu (`taidi`)** – suoraan `applications.menu`:ta lukeva ja atomisesti muokkaava CLI-työkalu.

Testattu ja toimivaksi todettu Sailfish OS 5.2:lla (Jolla Phone 2026).

---

## Miten tämä toimii?

Vakio-Lipstickissä sovellusten ryhmittely kansioihin vaatii kuvakkeiden tarkkaa raahaamista toistensa päälle. Jos sovelluksia on 60+, valikon selaaminen ja järjestely on hidasta.

Taidi App tekee kaksi pientä QML-laajennusta ja antaa kätevän CLI-komennon:

- **Kansion sisällä:** Otsikon vieressä on **`+ Apps`** -nappi. Sitä painamalla aukeaa lista, josta sovelluksia voi lisätä kansioon tai poistaa siitä suorilla napautuksilla.
- **Päävalikossa:** Kun painat kuvaketta pitkään (muokkaustila), voit luoda uuden kansion yläpalkin napista tai napauttaa mitä tahansa sovellusta siirtääksesi sen suoraan valitsemaasi kansioon.
- **1 sovelluksen kansiot:** Korjaa vakio-Lipstickin ärsyttävän bugin, jossa kansio tuhoutuu automaattisesti jos sinne jää vain yksi sovellus.
- **Turvallinen patchaus:** Repossa ei ole Jollan omia QML-tiedostoja. Asennusohjelma tarkistaa tiedostot ensin (`--dry-run`), patchaa ne puhtaan Python-patcherin avulla (ei vaadi erillistä `patch`-pakettia) ja varmuuskopioi alkuperäiset `.taidi_orig`-päätteellä. Jos Lipstick ei käynnisty onnistuneesti, skripti palauttaa automaattisesti vanhat tiedostot heti.

---

## Asennus

### Suoraan puhelimessa (Terminal / SSH):

```bash
git clone https://github.com/tsaknorris/taidi-app.git
cd taidi-app
./scripts/install.sh
```

Skripti kysyy `devel-su`-salasanan patchien asentamista varten, säätää 5×7-ruudukon ja käynnistää Lipstickin uudelleen.

### Tietokoneelta SSH:n yli:

```bash
./scripts/deploy_remote.sh 192.168.2.15
```
*(Korvaa IP puhelimesi osoitteella: USB-tilan oletus on `192.168.2.15`, WLAN/Hotspot oman verkkosi mukaan).*

---

## Komentorivityökalu: `taidi`

`taidi` lukee ja muokkaa suoraan tiedostoa `~/.config/lipstick/applications.menu`. Se käyttää aina laitteen todellista nykytilaa ainoana totuuden lähteenään (single source of truth) ja kirjoittaa tiedoston atomisesti (`os.replace`), joten mikään manuaalinen muutos ei pyyhkiydy vahingossa.

```bash
# Näytä nykyinen tila ja kansioiden sovellukset
taidi status

# Järjestä sovellukset automaattisesti loogisiin oletuskansioihin (8 tärkeintä ylös + 9 kansiota)
taidi init-default

# Siirrä sovellus kansioon (löytää nimen tai .desktop-tiedoston perusteella)
taidi move "WhatsApp" "Social"
taidi move "DOOM" "Games"

# Siirrä sovellus takaisin pääruudukkoon
taidi move "WhatsApp" root

# Luo tai nimeä kansio
taidi create-folder "Pelit" icon-launcher-folder-11
taidi rename-folder "Pelit" "Games"

# Poista kansio (siirtää sen sovellukset takaisin pääruudukkoon, mikään ei katoa)
taidi delete-folder "Games"
```

---

## Palautus / Poisto (Uninstall)

Jos haluat palata takaisin täysin alkuperäiseen Sailfish OS -tilaan:

```bash
./scripts/uninstall.sh
```

Tämä kumoaa patchit (`patch -R`), palauttaa alkuperäiset tiedostot `.taidi_orig`-varmuuskopioista, nollaa ruudukon dconf-asetukset ja käynnistää Lipstickin.

Hätätilanteessa (jos UI ei jostain syystä nousisi):
```bash
devel-su cp -f /usr/share/lipstick-jolla-home-qt5/launcher/*.taidi_orig /usr/share/lipstick-jolla-home-qt5/launcher/
systemctl --user restart lipstick && systemctl --user start user-session.target post-user-session.target
```

---

## Rakenne

```
taidi-app/
├── bin/
│   └── taidi               # Päätyökalu (Python 3, muokkaa applications.menu:ta)
├── patches/
│   ├── LauncherGrid.patch  # 5x7 ruudukko, pikasiirto, muokkauspalkki
│   └── LauncherFolder.patch# Kansion sisäinen '+ Apps' valintalista
├── scripts/
│   ├── install.sh          # Asennusskripti (dry-run + auto-rollback)
│   ├── uninstall.sh        # Palautusskripti
│   ├── patcher.py          # Kevyt riippuvuudeton unified diff -patcheri
│   └── deploy_remote.sh    # SSH-asennus koneelta luuriin
├── LICENSE                 # MIT
└── README.md
```

---

## Lisenssi

MIT (c) 2026 tsaknorris.
Patchit on tarkoitettu sovellettavaksi Sailfish OS:n Lipstick-komponentteihin laitteella.
