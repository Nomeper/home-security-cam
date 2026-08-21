"""Genera il PDF «Cosa posso fare» — capacità dell'assistente Cursor."""

from __future__ import annotations

from pathlib import Path

from fpdf import FPDF
from fpdf.enums import XPos, YPos

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(__file__).resolve().parent / "Cosa_posso_fare.pdf"
ARTIFACTS = Path("/opt/cursor/artifacts/Cosa_posso_fare.pdf")

FONTS = Path("/usr/share/fonts/truetype/macos")
DATE = "21 agosto 2026"
MODEL = "Cursor Grok 4.6"

NAVY = (11, 18, 32)
NAVY_2 = (17, 28, 48)
INK = (24, 32, 44)
MUTED = (92, 102, 118)
BLUE = (62, 140, 232)
BLUE_SOFT = (232, 241, 252)
GREEN = (34, 150, 110)
GREEN_SOFT = (230, 245, 238)
AMBER = (186, 120, 12)
AMBER_SOFT = (255, 244, 224)
RED = (196, 64, 80)
RED_SOFT = (252, 232, 234)
LINE = (220, 226, 234)
WHITE = (255, 255, 255)
CHIP = (246, 248, 251)


class Guida(FPDF):
    def __init__(self) -> None:
        super().__init__(format="A4", unit="mm")
        self.set_title("Cosa posso fare — Assistente Cursor")
        self.set_author("Cursor Grok 4.6")
        self.set_creator("Cursor Cloud Agent")
        self.set_lang("it")
        self.set_auto_page_break(auto=True, margin=22)
        self.alias_nb_pages()
        self._chapter = ""
        self._cover = True
        self._toc = False

        self.add_font("UI", "", str(FONTS / "Inter-Regular.ttf"))
        self.add_font("UI", "B", str(FONTS / "Inter-Bold.ttf"))
        self.add_font("UI", "I", str(FONTS / "Inter-Italic.ttf"))
        self.add_font("UISB", "", str(FONTS / "Inter-SemiBold.ttf"))

    def header(self) -> None:
        if self._cover or self._toc:
            return
        self.set_font("UI", "", 8.5)
        self.set_text_color(*MUTED)
        self.set_xy(18, 10)
        self.cell(90, 6, "Cosa posso fare  ·  Assistente Cursor", new_x=XPos.END, new_y=YPos.TOP)
        self.set_xy(108, 10)
        self.cell(84, 6, self._chapter, align="R", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(*BLUE)
        self.set_line_width(0.45)
        self.line(18, 17.2, 192, 17.2)
        self.set_line_width(0.2)
        self.set_draw_color(*LINE)
        self.line(18, 18.1, 192, 18.1)
        self.set_y(24)

    def footer(self) -> None:
        if self._cover:
            return
        self.set_y(-14)
        self.set_draw_color(*LINE)
        self.set_line_width(0.2)
        self.line(18, self.get_y(), 192, self.get_y())
        self.set_y(-11)
        self.set_font("UI", "", 8)
        self.set_text_color(*MUTED)
        self.cell(87, 6, MODEL, new_x=XPos.END, new_y=YPos.TOP)
        self.cell(87, 6, str(self.page_no()), align="R")

    def chapter(self, title: str, new_page: bool = True) -> None:
        self._cover = False
        self._toc = False
        self._chapter = title
        if new_page:
            self.add_page()
        else:
            self.set_y(10)
            self.header()
        self.start_section(title)
        self.set_font("UI", "B", 18)
        self.set_text_color(*INK)
        self.cell(0, 10, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(*BLUE)
        self.set_line_width(1.1)
        self.line(18, self.get_y() + 0.4, 62, self.get_y() + 0.4)
        self.ln(8)

    def h2(self, title: str) -> None:
        self.ensure(22)
        self.set_font("UISB", "", 12.5)
        self.set_text_color(*INK)
        self.cell(0, 8, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(1.5)

    def h3(self, title: str) -> None:
        self.ensure(16)
        self.set_font("UI", "B", 11)
        self.set_text_color(*BLUE)
        self.cell(0, 7, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(0.8)

    def p(self, text: str) -> None:
        self.set_font("UI", "", 10.4)
        self.set_text_color(*INK)
        self.multi_cell(0, 5.5, text)
        self.ln(2.2)

    def italic(self, text: str) -> None:
        self.set_font("UI", "I", 10)
        self.set_text_color(*MUTED)
        self.multi_cell(0, 5.3, text)
        self.ln(2)

    def bullets(self, items: list[str]) -> None:
        for item in items:
            self.ensure(12)
            x = self.get_x()
            y = self.get_y()
            self.set_fill_color(*BLUE)
            self.circle(x + 1.6, y + 2.6, 0.95, style="F")
            self.set_xy(x + 6, y)
            self.set_font("UI", "", 10.3)
            self.set_text_color(*INK)
            self.multi_cell(self.epw - 6, 5.4, item)
            self.ln(1.1)
        self.ln(1.6)

    def numbered(self, items: list[str]) -> None:
        for i, item in enumerate(items, 1):
            self.ensure(16)
            x = self.get_x()
            y = self.get_y()
            self.set_fill_color(*BLUE)
            self.circle(x + 3.4, y + 3.3, 3.3, style="F")
            self.set_xy(x, y + 0.6)
            self.set_font("UI", "B", 8.2)
            self.set_text_color(*WHITE)
            self.cell(6.8, 5.4, str(i), align="C")
            self.set_xy(x + 10, y + 0.4)
            self.set_font("UI", "", 10.3)
            self.set_text_color(*INK)
            self.multi_cell(self.epw - 10, 5.4, item)
            self.ln(2.2)
        self.ln(1)

    def callout(self, kind: str, title: str, body: str) -> None:
        colors = {
            "info": (BLUE, BLUE_SOFT),
            "ok": (GREEN, GREEN_SOFT),
            "warn": (AMBER, AMBER_SOFT),
            "stop": (RED, RED_SOFT),
        }
        accent, bg = colors[kind]
        self.set_font("UI", "", 10)
        body_h = self.multi_cell(self.epw - 10, 5.2, body, dry_run=True, output="HEIGHT")
        h = 9 + body_h + 4
        self.ensure(h + 2)
        x, y, w = self.l_margin, self.get_y(), self.epw
        self.set_fill_color(*bg)
        self.set_draw_color(*bg)
        self.rrect(x, y, w, h, 2.2)
        self.set_fill_color(*accent)
        self.rect(x, y, 1.7, h, style="F")
        self.set_xy(x + 7, y + 2.4)
        self.set_font("UI", "B", 10)
        self.set_text_color(*accent)
        self.cell(0, 5.2, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_x(x + 7)
        self.set_font("UI", "", 10)
        self.set_text_color(*INK)
        self.multi_cell(w - 10, 5.2, body)
        self.set_y(y + h + 4)

    def kv_table(self, rows: list[tuple[str, str]]) -> None:
        col_w = (52, self.epw - 52)
        self.ensure(10 + 8 * len(rows))
        for i, (k, v) in enumerate(rows):
            bg = CHIP if i % 2 == 0 else WHITE
            self.set_fill_color(*bg)
            y0 = self.get_y()
            self.set_font("UI", "B", 9.6)
            self.set_text_color(*INK)
            kh = self.multi_cell(col_w[0], 5.4, k, dry_run=True, output="HEIGHT")
            self.set_font("UI", "", 9.6)
            vh = self.multi_cell(col_w[1], 5.4, v, dry_run=True, output="HEIGHT")
            row_h = max(kh, vh, 8) + 2
            self.rect(self.l_margin, y0, self.epw, row_h, style="F")
            self.set_xy(self.l_margin + 3, y0 + 1.4)
            self.set_font("UI", "B", 9.6)
            self.multi_cell(col_w[0] - 4, 5.4, k)
            self.set_xy(self.l_margin + col_w[0], y0 + 1.4)
            self.set_font("UI", "", 9.6)
            self.set_text_color(*INK)
            self.multi_cell(col_w[1] - 3, 5.4, v)
            self.set_y(y0 + row_h)
        self.ln(4)

    def card_grid(self, cards: list[tuple[str, str]]) -> None:
        gap = 4
        w = (self.epw - gap) / 2
        i = 0
        while i < len(cards):
            row = cards[i : i + 2]
            heights = []
            for title, body in row:
                self.set_font("UISB", "", 10.5)
                th = self.multi_cell(w - 12, 5.2, title, dry_run=True, output="HEIGHT")
                self.set_font("UI", "", 9.4)
                bh = self.multi_cell(w - 12, 5.0, body, dry_run=True, output="HEIGHT")
                heights.append(12 + th + bh + 4)
            h = max(heights)
            self.ensure(h + 2)
            y0 = self.get_y()
            for j, (title, body) in enumerate(row):
                x = self.l_margin + j * (w + gap)
                self.set_fill_color(*CHIP)
                self.rrect(x, y0, w, h, 2.4)
                self.set_fill_color(*BLUE)
                self.rect(x, y0, 2.0, h, style="F")
                self.set_xy(x + 7, y0 + 4)
                self.set_font("UISB", "", 10.5)
                self.set_text_color(*INK)
                self.multi_cell(w - 12, 5.2, title)
                self.set_x(x + 7)
                self.set_font("UI", "", 9.4)
                self.set_text_color(*MUTED)
                self.multi_cell(w - 12, 5.0, body)
            self.set_y(y0 + h + 4)
            i += 2

    def rrect(self, x: float, y: float, w: float, h: float, r: float = 2.5) -> None:
        self.rect(x, y, w, h, style="F", round_corners=True, corner_radius=r)

    def ensure(self, h: float) -> None:
        if self.get_y() + h > self.h - self.b_margin:
            self.add_page()

    def cover(self) -> None:
        self._cover = True
        self.set_auto_page_break(auto=False)
        self.add_page()
        self.set_fill_color(*NAVY)
        self.rect(0, 0, 210, 297, style="F")
        self.set_fill_color(*BLUE)
        self.rect(0, 0, 210, 7, style="F")
        self.rect(0, 278, 210, 19, style="F")

        self.set_xy(24, 36)
        self.set_font("UISB", "", 11)
        self.set_text_color(*BLUE)
        self.cell(0, 7, "CURSOR  ·  CLOUD AGENT")

        self.set_xy(24, 58)
        self.set_font("UI", "B", 34)
        self.set_text_color(*WHITE)
        self.multi_cell(162, 14, "Cosa posso fare")

        self.set_xy(24, 96)
        self.set_font("UI", "", 14)
        self.set_text_color(180, 196, 220)
        self.multi_cell(
            162,
            7.5,
            "Guida pratica alle capacità dell'assistente che lavora sul progetto Casa Sicura: codice, build, debug, documenti e limiti.",
        )

        y = 148
        facts = [
            ("Modello", MODEL),
            ("Ruolo", "Assistente di programmazione"),
            ("Progetto", "Casa Sicura  ·  home-security-cam"),
            ("Data", DATE),
        ]
        for label, value in facts:
            self.set_xy(24, y)
            self.set_font("UI", "", 9)
            self.set_text_color(140, 158, 184)
            self.cell(42, 7, label.upper())
            self.set_font("UISB", "", 12)
            self.set_text_color(*WHITE)
            self.cell(0, 7, value)
            y += 12

        self.set_xy(24, 284)
        self.set_font("UI", "", 9)
        self.set_text_color(*WHITE)
        self.cell(0, 6, "Uso personale  ·  non sostituisce il giudizio su sicurezza e privacy")

        self.set_auto_page_break(auto=True, margin=22)
        self._cover = False

    def toc_page(self) -> None:
        self._toc = True
        self.add_page()
        self.set_font("UI", "B", 18)
        self.set_text_color(*INK)
        self.cell(0, 10, "Indice", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_draw_color(*BLUE)
        self.set_line_width(1.1)
        self.line(18, self.get_y() + 0.4, 62, self.get_y() + 0.4)
        self.ln(10)

        items = [
            ("01", "Chi sono e come lavoro"),
            ("02", "Cosa so fare"),
            ("03", "Su Casa Sicura, in concreto"),
            ("04", "Come darmi un incarico"),
            ("05", "Cosa non faccio"),
            ("06", "Memoria tra una chat e l'altra"),
        ]
        for num, title in items:
            self.ensure(14)
            self.set_font("UISB", "", 11)
            self.set_text_color(*BLUE)
            self.cell(14, 9, num)
            self.set_font("UI", "", 12)
            self.set_text_color(*INK)
            self.cell(0, 9, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.ln(2)
        self._toc = False


def build() -> Path:
    pdf = Guida()
    pdf.cover()
    pdf.toc_page()

    pdf.chapter("1. Chi sono e come lavoro")
    pdf.p(
        "Sono Cursor Grok 4.6, un assistente di programmazione. In questa sessione lavoro come Cloud Agent: "
        "ho una macchina Linux con il repository del progetto, posso leggere e modificare i file, eseguire comandi "
        "nel terminale, cercare in rete e consegnarti file (come questo PDF)."
    )
    pdf.p(
        "Non sono l'app Casa Sicura e non sto «dentro» i telefoni. Sono lo strumento con cui puoi far scrivere, "
        "correggere, compilare e documentare il software. Tu decidi cosa va in produzione; io eseguo il lavoro tecnico."
    )
    pdf.kv_table(
        [
            ("Nome modello", MODEL),
            ("Ambiente", "Cloud Agent Cursor (Linux, repository clonato)"),
            ("Lingue", "Italiano e inglese; il codice segue lo stile del progetto"),
            ("Focus attuale", "App Android Flutter + visore PC HTML (Agora RTC)"),
            ("Memoria progetto", "File progress.md nella root del repository"),
        ]
    )
    pdf.callout(
        "info",
        "Lavoro sul codice, non sui dispositivi",
        "Posso preparare APK, QR Device Owner, script e manuali. Installare l'app sui telefoni, "
        "scansionare il QR e verificare il video dal vivo restano operazioni tue, sul hardware reale.",
    )

    pdf.chapter("2. Cosa so fare")
    pdf.p(
        "Le capacità sotto valgono in generale. Su Casa Sicura le uso già: Dart/Flutter, Kotlin Android, "
        "HTML/JavaScript del visore PC, Python per script e PDF, Git e GitHub."
    )

    pdf.h2("Sviluppo e modifica del codice")
    pdf.card_grid(
        [
            (
                "Scrivere e rifattorizzare",
                "Nuove schermate, servizi, comandi data stream, UI visore telefono e PC, pulizia del codice esistente.",
            ),
            (
                "Cercare nel progetto",
                "Trovo file, funzioni e chiamate in tutto il repository, non solo nella cartella che hai aperto.",
            ),
            (
                "Spiegare l'architettura",
                "Ruoli camera/visore, Agora, ECO, STANDBY, Device Owner, permessi: te li racconto in italiano chiaro.",
            ),
            (
                "Allineare i pezzi",
                "App Android, visore web, QR kiosk, README e progress.md restano coerenti tra loro.",
            ),
        ]
    )

    pdf.h2("Build, test e diagnostica")
    pdf.bullets(
        [
            "Compilare l'APK Android (release firmata, taglio ABI, analisi del peso).",
            "Eseguire test automatici e analizzare errori di compilazione o di lint.",
            "Leggere log, manifest, Gradle e configurazione Agora/Firebase (quest'ultima non usata nel client).",
            "Proporre e applicare correzioni a bug, regressioni UI e problemi di lifecycle Android.",
        ]
    )

    pdf.h2("Git, GitHub e documentazione")
    pdf.bullets(
        [
            "Commit e push sul branch di lavoro; le pull request le gestisce l'ambiente Cloud.",
            "Consultare release, CI e cronologia con GitHub in sola lettura (gh).",
            "Scrivere o aggiornare README, blueprint, privacy, manuali e questo tipo di PDF.",
            "Generare QR, note operative Device Owner e checklist di verifica sul campo.",
        ]
    )

    pdf.h2("File, ricerche e automazione")
    pdf.card_grid(
        [
            (
                "PDF e documenti",
                "Manuali, guide e report in PDF scaricabili, come il manuale d'uso e questo foglio.",
            ),
            (
                "Immagini",
                "Posso generare un'immagine se me lo chiedi esplicitamente (icone, mockup, diagrammi semplici).",
            ),
            (
                "Terminale",
                "Installo dipendenze, lancio script, confronto file, misuro dimensioni APK, verifico hash.",
            ),
            (
                "Ricerca in rete",
                "Documentazione Flutter, Agora, Android Enterprise, e notizie tecniche aggiornate.",
            ),
        ]
    )

    pdf.callout(
        "ok",
        "Posso consegnarti file da scaricare",
        "PDF, APK locali, script e immagini restano nel workspace (cartella docs/ o root). "
        "Da Cursor li scarichi dalla scheda file dell'agente o dal branch su GitHub.",
    )

    pdf.chapter("3. Su Casa Sicura, in concreto")
    pdf.p(
        "Sul repository home-security-cam ho già lavorato (e posso continuare) su queste aree. "
        "Lo stato vivo è in progress.md: partiamo da lì a ogni chat nuova."
    )
    pdf.kv_table(
        [
            ("App Android", "Flutter, ruoli camera e visore, permessi, ECO, STANDBY, flash, lente, batteria"),
            ("Streaming", "Agora RTC, canale casa_sicura, UID fissi, comandi WATCH / FLASH / LISTEN / LENS / BYE"),
            ("Visore PC", "web-viewer HTML, server locale, griglia CAM, dock come l'app"),
            ("Kiosk", "Device Owner, QR di provisioning, lock-task, recupero solo con factory reset"),
            ("Release", "APK arm64, GitHub Release, SHA-256, taglio estensioni Agora inutili"),
            ("Manuale", "docs/Manuale_uso_Casa_Sicura.pdf e relativo generatore Python"),
        ]
    )
    pdf.h2("Esempi di richieste che posso portare a termine")
    pdf.numbered(
        [
            "«Il visore PC non mostra il bottone lente: allinealo all'app e dimmi cosa è cambiato.»",
            "«Prepara un APK più leggero, senza rompere video e audio, e aggiorna progress.md.»",
            "«Riscrivi il capitolo Eco/STANDBY del manuale PDF e rigeneralo.»",
            "«Spiega perché il visore deve essere host e non audience, in una pagina per me.»",
            "«Il flash frontale deve tornare a Eco quando lo spengo: trova il bug e correggilo.»",
        ]
    )

    pdf.chapter("4. Come darmi un incarico")
    pdf.p(
        "Più l'obiettivo è concreto, più il risultato è utile. Non serve il gergo da programmatore: "
        "basta dire cosa deve succedere sullo schermo o sul telefono."
    )
    pdf.h2("Funziona bene")
    pdf.bullets(
        [
            "Un obiettivo per messaggio, o una lista numerata se sono più passi.",
            "Cosa vedi ora e cosa vorresti invece (es. «schermo bianco, ma voglio il LED»).",
            "Su quale dispositivo: camera, visore telefono, visore PC, o tutti.",
            "Se vuoi solo una spiegazione, o anche la modifica nel codice e un PDF/APK.",
        ]
    )
    pdf.h2("Meglio evitarlo")
    pdf.bullets(
        [
            "Dieci richieste diverse nello stesso messaggio, senza priorità.",
            "«Sistema tutto» senza dire cosa non va.",
            "Chiedere di «hackare» telefoni, bypassare kiosk di terzi, o copiare libri interi.",
        ]
    )
    pdf.callout(
        "info",
        "Chat nuova = @progress.md",
        "All'inizio di una conversazione nuova, indica progress.md («Parti da qui»). "
        "Così recupero versione app, QR, release GitHub e i test ancora da fare, senza ripartire da zero.",
    )

    pdf.chapter("5. Cosa non faccio")
    pdf.p(
        "Alcuni limiti sono tecnici (non ho le tue mani sui telefoni). Altri sono di sicurezza: "
        "non aiuto ad attaccare sistemi, a eludere protezioni o a fare cose illegali."
    )
    pdf.h2("Limiti pratici")
    pdf.bullets(
        [
            "Non installo l'APK sui tuoi telefoni e non scansiono il QR al posto tuo.",
            "Non vedo il video in diretta delle camere di casa: non sono collegato ad Agora sul campo.",
            "Il visore PC va provato in Chrome/Edge sul tuo computer, non nel browser interno di Cursor.",
            "Non sostituisco un avvocato, un medico o un perito di sicurezza fisica.",
            "Le librerie native Agora restano pesanti: posso tagliare moduli, non miracoli sul MB.",
        ]
    )
    pdf.h2("Cose che rifiuto")
    pdf.bullets(
        [
            "Exploit, malware, accesso non autorizzato, furto di credenziali.",
            "Aiuto a reati (truffe, phishing, droga, esplosivi, armi).",
            "Contenuti sessuali che coinvolgono minori.",
            "Copiare integralmente libri, canzoni o altro materiale protetto da copyright.",
        ]
    )
    pdf.callout(
        "warn",
        "Casa Sicura è un sistema di videosorveglianza domestica",
        "Posso migliorare l'app e il kiosk che tu controlli. Non aiuto a spiare persone all'insaputa, "
        "né a sbloccare un Device Owner su un telefono che non è tuo.",
    )
    pdf.callout(
        "stop",
        "Recupero kiosk",
        "Su una camera in Device Owner l'uscita controllata non c'è: serve il factory reset. "
        "Lo documento e lo spiego; non invento backdoor per aggirarlo.",
    )

    pdf.chapter("6. Memoria tra una chat e l'altra")
    pdf.p(
        "Ogni conversazione parte pulita. Quello che deve sopravvivere sta nel repository, soprattutto in progress.md: "
        "versione, release, cosa è fatto, cosa manca, problemi aperti."
    )
    pdf.h2("Cosa aggiorno io")
    pdf.bullets(
        [
            "progress.md dopo una modifica importante e a fine sessione.",
            "Il codice e i file di progetto che mi hai chiesto di cambiare.",
            "Manuali PDF se il comportamento dell'app è cambiato e me lo chiedi.",
        ]
    )
    pdf.h2("Cosa resta tuo")
    pdf.bullets(
        [
            "Installare e provare sui dispositivi reali.",
            "Account Agora, App ID, e la decisione di pubblicare una release GitHub.",
            "Confermare i test in checklist (video, flash, Eco, STANDBY, visore PC).",
        ]
    )
    pdf.italic(
        "Ultimo aggiornamento di questa guida: %s. Se le capacità dell'ambiente Cursor cambiano, "
        "si può rigenerare il PDF con docs/genera_capacita_assistente.py." % DATE
    )
    pdf.callout(
        "ok",
        "Prossimo passo tipico",
        "Dimmi un obiettivo («correggi X», «spiega Y», «genera Z») e lo eseguo sul repository. "
        "Per lo stato attuale dell'app, apri progress.md e parti da lì.",
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUT))
    ARTIFACTS.parent.mkdir(parents=True, exist_ok=True)
    ARTIFACTS.write_bytes(OUT.read_bytes())
    return OUT


if __name__ == "__main__":
    path = build()
    print(path)
    print("bytes", path.stat().st_size)
