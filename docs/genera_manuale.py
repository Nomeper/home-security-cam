"""Genera il manuale d'uso PDF di Casa Sicura (app Android + visore PC)."""

from __future__ import annotations

from pathlib import Path

from fpdf import FPDF
from fpdf.enums import XPos, YPos
from fpdf.outline import OutlineSection

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(__file__).resolve().parent / "Manuale_uso_Casa_Sicura.pdf"

FONTS = Path(r"C:\Windows\Fonts")
VERSION = "1.0.1"
BUILD = "19"
WEB_BUILD = "19f"

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


class Manuale(FPDF):
    def __init__(self) -> None:
        super().__init__(format="A4", unit="mm")
        self.set_title("Casa Sicura — Manuale d'uso")
        self.set_author("Casa Sicura")
        self.set_creator("Casa Sicura")
        self.set_lang("it")
        self.set_auto_page_break(auto=True, margin=22)
        self.alias_nb_pages()
        self._chapter = ""
        self._cover = True
        self._toc = False

        self.add_font("UI", "", str(FONTS / "segoeui.ttf"))
        self.add_font("UI", "B", str(FONTS / "segoeuib.ttf"))
        self.add_font("UI", "I", str(FONTS / "segoeuii.ttf"))
        self.add_font("UISB", "", str(FONTS / "seguisb.ttf"))

    def header(self) -> None:
        if self._cover or self._toc:
            return
        self.set_font("UI", "", 8.5)
        self.set_text_color(*MUTED)
        self.set_xy(18, 10)
        self.cell(90, 6, "Casa Sicura  ·  Manuale d'uso", new_x=XPos.END, new_y=YPos.TOP)
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
        self.cell(87, 6, "Uso domestico  ·  versione %s" % VERSION, new_x=XPos.END, new_y=YPos.TOP)
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

        # Decorative camera mark
        cx, cy = 105, 78
        self.set_fill_color(*NAVY_2)
        self.rrect(cx - 22, cy - 18, 44, 36, 6)
        self.set_fill_color(*BLUE)
        self.circle(cx, cy - 1, 11.5, style="F")
        self.set_fill_color(*NAVY)
        self.circle(cx, cy - 1, 7.2, style="F")
        self.set_fill_color(*WHITE)
        self.circle(cx + 3.2, cy - 4.2, 1.7, style="F")
        self.set_fill_color(*BLUE)
        self.rect(cx - 6, cy - 22, 12, 5, style="F")

        self.set_xy(18, 118)
        self.set_font("UI", "", 11)
        self.set_text_color(*BLUE)
        self.cell(174, 7, "TELECAMERE DI CASA  ·  APP E VISORE PC", align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(4)
        self.set_font("UI", "B", 36)
        self.set_text_color(*WHITE)
        self.cell(174, 16, "Casa Sicura", align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font("UI", "", 18)
        self.set_text_color(186, 210, 240)
        self.cell(174, 10, "Manuale d'uso", align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        self.ln(10)
        self.set_draw_color(*BLUE)
        self.set_line_width(0.6)
        self.line(78, self.get_y(), 132, self.get_y())
        self.ln(10)

        self.set_font("UI", "", 11.5)
        self.set_text_color(210, 220, 232)
        self.multi_cell(
            174,
            6.2,
            "Come trasformare vecchi telefoni Android in telecamere\n"
            "e guardarli dal telefono o dal computer, in tempo reale.",
            align="C",
        )

        self.set_y(228)
        for label, value in (
            ("Versione app", "%s (build %s)" % (VERSION, BUILD)),
            ("Visore PC", "web-viewer  %s" % WEB_BUILD),
            ("Piattaforma", "Android 64-bit  +  browser Chrome/Edge"),
        ):
            self.set_font("UI", "", 9)
            self.set_text_color(140, 160, 185)
            self.cell(174, 5, label.upper(), align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.set_font("UISB", "", 11)
            self.set_text_color(*WHITE)
            self.cell(174, 6, value, align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.ln(2)

        self.set_xy(18, 283.5)
        self.set_font("UI", "B", 10)
        self.set_text_color(*NAVY)
        self.cell(174, 8, "Nessun abbonamento  ·  Nessun account cloud proprio  ·  Uso personale", align="C")
        self.set_auto_page_break(auto=True, margin=22)

    def toc_page(self) -> None:
        self._toc = True
        self.add_page()
        self._cover = False
        self.insert_toc_placeholder(self._render_toc, pages=1)

    def _render_toc(self, pdf: FPDF, outline: list[OutlineSection]) -> None:
        pdf._toc = True
        pdf.set_font("UI", "B", 22)
        pdf.set_text_color(*INK)
        pdf.set_xy(18, 28)
        pdf.cell(0, 12, "Indice", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        pdf.set_draw_color(*BLUE)
        pdf.set_line_width(1.1)
        pdf.line(18, pdf.get_y() + 0.5, 48, pdf.get_y() + 0.5)
        pdf.ln(12)
        for item in outline:
            if item.level != 0:
                continue
            y = pdf.get_y()
            pdf.set_font("UI", "", 11.2)
            pdf.set_text_color(*INK)
            title_w = pdf.get_string_width(item.name)
            page = str(item.page_number)
            link = pdf.add_link(page=item.page_number)
            pdf.set_xy(18, y)
            pdf.cell(title_w + 2, 9, item.name, link=link)
            pdf.set_draw_color(*LINE)
            pdf.set_line_width(0.25)
            dots_x = 20 + title_w
            pdf.line(dots_x, y + 6.4, 178, y + 6.4)
            pdf.set_xy(178, y)
            pdf.set_font("UI", "B", 11)
            pdf.set_text_color(*BLUE)
            pdf.cell(14, 9, page, align="R", link=link)
            pdf.ln(10)

    def draw_architecture(self) -> None:
        self.ensure(62)
        y = self.get_y()
        self.set_fill_color(*CHIP)
        self.rrect(18, y, 174, 56, 3)

        def box(x: float, by: float, w: float, h: float, title: str, sub: str, fill: tuple[int, int, int]) -> None:
            self.set_fill_color(*fill)
            self.rrect(x, by, w, h, 2)
            self.set_xy(x, by + 3.2)
            self.set_font("UI", "B", 8)
            self.set_text_color(*WHITE)
            self.cell(w, 4.2, title, align="C")
            self.set_xy(x, by + 8)
            self.set_font("UI", "", 7)
            self.cell(w, 4, sub, align="C")

        cam_y = y + 10
        for i, lab in enumerate(("CAM 1", "CAM 2", "CAM 3", "CAM 4", "CAM 5", "CAM 6")):
            box(24 + i * 27.4, cam_y, 24, 14, lab, "telefono", (46, 92, 150))

        self.set_draw_color(*BLUE)
        self.set_line_width(0.5)
        self.line(105, cam_y + 16, 105, y + 30)
        box(78, y + 28, 54, 14, "Agora  (internet)", "canale casa_sicura", BLUE)
        self.line(92, y + 42, 62, y + 46)
        self.line(118, y + 42, 148, y + 46)
        box(28, y + 44, 52, 8.5, "Visore telefono", "", GREEN)
        box(130, y + 44, 52, 8.5, "Visore PC (web)", "", (92, 64, 170))
        self.set_y(y + 60)


def build() -> Path:
    pdf = Manuale()
    pdf.cover()
    pdf.toc_page()

    pdf.chapter("1. Che cos'è Casa Sicura", new_page=False)
    pdf.p(
        "Casa Sicura è un’app per la casa: usi dei telefoni Android come telecamere "
        "e un altro telefono — oppure il computer — come visore. Il video arriva in "
        "tempo reale. Non c’è un tuo server, non serve Firebase e non paghi un "
        "abbonamento all’app: il collegamento passa dal servizio gratuito Agora, "
        "con un progetto di test che crei tu."
    )
    pdf.p(
        "Puoi collegare fino a sei telecamere (CAM 1–6). Restano pronte in rete, "
        "ma la fotocamera hardware si accende solo quando il visore le sceglie. "
        "Quando chiudi il visore, il sensore si spegne di nuovo: meno calore, meno "
        "batteria, meno “pallino verde” di Android se nessuna camera sta filmando."
    )
    pdf.callout(
        "ok",
        "Guida rapida",
        "1) Crea un progetto Agora di test e copia l’App ID.  "
        "2) Installa la stessa app su visore e telecamere.  "
        "3) Incolla l’App ID, la chiave di casa e scegli i ruoli (un visore, CAM 1–6 univoche).  "
        "4) Sul visore tocca le CAM da vedere — oppure sul PC doppio clic su avvia.bat.  "
        "5) Un visore alla volta: telefono oppure computer, non entrambi.",
    )
    pdf.h2("Cosa puoi fare")
    pdf.bullets(
        [
            "Guardare una o più stanze insieme, dal telefono o dal PC.",
            "Accendere il flash da remoto: LED sulla fotocamera posteriore, oppure "
            "schermo bianco a piena luce se è in uso la lente frontale.",
            "Passare da lente posteriore a frontale senza toccare la telecamera.",
            "Ascoltare l’audio ambientale di una camera e, se serve, parlare verso di essa.",
            "Vedere la percentuale di batteria di ogni telecamera sotto l’icona nel dock.",
            "Mettere la telecamera in Eco: schermo nero, il visore continua a vedere.",
        ]
    )
    pdf.callout(
        "info",
        "Un visore alla volta",
        "Non usare insieme il visore sul telefono e quello sul computer. "
        "L’ultimo che chiede il video “vince” e le telecamere possono spegnersi "
        "o accendersi in modo confuso. Chiudi l’uno prima di aprire l’altro.",
    )

    pdf.chapter("2. Cosa ti serve")
    pdf.h2("Telefoni telecamera e visore Android")
    pdf.bullets(
        [
            "Smartphone Android a 64 bit (processore arm64). I telefoni 32 bit "
            "non installano l’APK.",
            "Android 6 o successivo, fotocamera e microfono funzionanti, connessione "
            "a internet (Wi‑Fi o dati).",
            "L’APK Casa Sicura versione 1.0.1 build 19 o successiva, la stessa su "
            "visore e su tutte le telecamere.",
        ]
    )
    pdf.h2("Computer (visore PC)")
    pdf.bullets(
        [
            "Windows, cartella web-viewer del progetto, e Python (lo script di avvio "
            "alza un piccolo server locale).",
            "Chrome o Edge. Non usare la finestra browser interna di Cursor: WebRTC "
            "lì non funziona.",
            "Stesso App ID Agora e stessa chiave di casa dei telefoni. Il PC non usa la webcam: è solo un visore.",
        ]
    )
    pdf.h2("Account Agora")
    pdf.p(
        "Serve un progetto Agora in modalità Testing, senza token. Lo crei in pochi "
        "minuti sul sito agora.io, è gratuito e lo stesso codice (App ID) va incollato "
        "su ogni telefono e sul visore PC."
    )
    pdf.kv_table(
        [
            ("App", "Casa Sicura 1.0.1 (build 19)"),
            ("Visore PC", "web-viewer, build 19f"),
            ("Canale video", "casa_sicura (fisso, non lo scrivi tu sull’app)"),
            ("Telecamere", "Fino a 6, ruoli CAM 1 … CAM 6"),
            ("Backend proprio", "Nessuno"),
        ]
    )
    pdf.callout(
        "warn",
        "APK GitHub v1.0.1",
        "La scheda GitHub del tag v1.0.1 è vecchia: manca la griglia, i comandi "
        "dal visore e il comportamento attuale di Eco e standby. Installa l’APK "
        "locale aggiornato su visore e su tutte le camere.",
    )

    pdf.chapter("3. Crea l’App ID Agora (gratis)")
    pdf.p(
        "Senza questo codice visore e telecamere non si trovano. Usalo identico "
        "su tutti i dispositivi. Non copiare l’App Certificate: serve un progetto "
        "che accetti l’ingresso senza token."
    )
    pdf.numbered(
        [
            "Apri www.agora.io (dall’app, sotto il campo App ID, c’è già il link) "
            "e registrati alla console console.agora.io.",
            "Crea un progetto in modalità Testing (o “testing without token”, a "
            "seconda della lingua della console).",
            "Copia l’App ID: è una stringa lunga. Tienila per te come una password "
            "di casa: chi la possiede può entrare nel tuo canale.",
            "Lascia disabilitata l’App Certificate. Se la attivi, l’app attuale "
            "(token vuoto) non entra più.",
            "Scegli una chiave di casa (almeno 8 caratteri) e usala identica su "
            "ogni telefono e sul visore PC. Non è l’App ID: la inventi tu.",
        ]
    )
    pdf.callout(
        "ok",
        "Link nell’app",
        "Sulla prima schermata, sotto il campo App ID, il testo piccolo www.agora.io "
        "apre il sito nel browser predefinito del telefono. Sul visore PC il link "
        "si apre in una nuova scheda.",
    )
    pdf.callout(
        "warn",
        "Progetto di test",
        "Il piano Testing di Agora è pensato per prova e uso personale. Non è un "
        "impianto di allarme certificato né un servizio di videosorveglianza professionale. "
        "Internet deve essere disponibile su visore e telecamere nello stesso momento.",
    )

    pdf.chapter("4. Installazione e permessi")
    pdf.h2("Installare l’APK")
    pdf.numbered(
        [
            "Copia l’APK sul telefono (cavo, cartella condivisa, o il metodo che usi di solito).",
            "Apri il file e consenti l’installazione da origini sconosciute, se Android la chiede.",
            "Ripeti su ogni telefono: visore e tutte le telecamere devono avere la stessa versione.",
        ]
    )
    pdf.p(
        "L’APK pesa circa 120 MB e contiene solo le architetture 64 bit (telefoni) "
        "e x86_64 (emulatore). Su un telefono 32 bit l’installazione viene rifiutata."
    )
    pdf.h2("Permessi all’avvio")
    pdf.p(
        "Alla prima apertura l’app chiede subito tre permessi, prima ancora di "
        "scegliere il ruolo:"
    )
    pdf.bullets(
        [
            "Fotocamera — per filmare se il telefono diventa una CAM, e per il visore "
            "quando usi «Parla» non serve; va comunque concessa in avvio insieme alle altre.",
            "Microfono — per l’audio della telecamera e per parlare dal visore.",
            "Notifiche — Android le usa per l’indicatore persistente mentre una "
            "telecamera sta trasmettendo in background.",
        ]
    )
    pdf.p(
        "Non viene chiesto il Bluetooth né l’accesso ai «dispositivi vicini». "
        "Se neghi fotocamera o microfono, potrai ripristinarli da Impostazioni → App → "
        "Casa Sicura → Permessi."
    )
    pdf.callout(
        "info",
        "Notifica di trasmissione",
        "Quando una telecamera è selezionata dal visore e sta pubblicando il video, "
        "Android mostra una notifica persistente di servizio in primo piano. È voluto: "
        "indica che la fotocamera è in uso anche se premi Home o spegni lo schermo.",
    )

    pdf.chapter("5. Configurazione iniziale")
    pdf.h2("Schermata «Configurazione iniziale»")
    pdf.p(
        "Dopo lo splash (icona scudo su sfondo nero) comparono App ID e chiave di casa. "
        "Incolla il codice Agora, scegli una chiave di almeno 8 caratteri (la stessa "
        "su ogni telefono e sul PC) e premi SALVA E CONTINUA. Il pulsante si attiva "
        "quando entrambi i campi sono abbastanza lunghi; l’icona di incolla sulla destra "
        "legge gli appunti per l’App ID."
    )
    pdf.p(
        "App ID e chiave restano salvati sul telefono. Non devi reinserirli a ogni avvio, "
        "a meno che non usi «Reimposta App ID, chiave e ruolo»."
    )
    pdf.h2("Schermata «Scegli Ruolo»")
    pdf.p("Qui decidi a cosa serve quel telefono.")
    pdf.kv_table(
        [
            ("VISORE", "Monitora le telecamere in tempo reale. Un solo visore in casa."),
            ("CAM 1 … CAM 6", "Quel telefono diventa quella telecamera. Ogni numero una sola volta."),
            ("Reimposta App ID, chiave e ruolo", "Cancella codice Agora, chiave di casa, ruolo e nomi camere salvati su quel telefono."),
        ]
    )
    pdf.callout(
        "warn",
        "Numeri unici",
        "Due telefoni con lo stesso ruolo (due CAM 1) si pestano i piedi nel canale. "
        "Assegna CAM 1, CAM 2, CAM 3… in modo univoco. Il visore non è una telecamera.",
    )
    pdf.p(
        "Se il telefono è stato configurato come Device Owner (kiosk), salta la scelta "
        "del ruolo e va dritto a CAM 1. Vedi il capitolo sulla modalità kiosk."
    )

    pdf.chapter("6. Usare un telefono come telecamera")
    pdf.p(
        "Sulla telecamera i comandi restano sempre visibili: non spariscono da soli "
        "e un tocco non li nasconde. Così, anche da lontano, capisci se sta "
        "trasmettendo o è in attesa."
    )
    pdf.h2("Stati in alto a sinistra")
    pdf.kv_table(
        [
            ("IN ATTESA VISORE", "Il visore non è collegato. La fotocamera hardware è spenta (STANDBY)."),
            ("NON SELEZIONATA", "Il visore c’è, ma non ha scelto questa CAM. Sensore spento."),
            ("TRASMISSIONE ATTIVA", "Il visore ha selezionato questa CAM: sta filmando e mandando il video."),
            ("TELECAMERA DISCONNESSA", "Non è nel canale Agora (rete, App ID, o avvio ancora in corso)."),
        ]
    )
    pdf.h2("Pallino in alto a destra")
    pdf.p(
        "Verde: stanno passando dati video. Rosso: nessuna trasmissione in corso. "
        "È l’indicatore dell’app, distinto dal pallino verde di sistema di Android "
        "(fotocamera in uso), che può restare visibile finché il sensore è acceso."
    )
    pdf.h2("I tre pulsanti in basso")
    pdf.kv_table(
        [
            ("Frontale / Posteriore", "Cambia lente sul posto. Da visore puoi farlo anche a distanza."),
            ("Flash", "Posteriore: LED torcia. Frontale: lo schermo diventa bianco a luminosità massima."),
            ("Eco", "Schermo nero immediato. Il visore, se sta guardando, continua a vedere."),
        ]
    )
    pdf.h2("Standby (in attesa)")
    pdf.p(
        "Quando nessuno sta guardando questa camera, sullo schermo compare STANDBY e "
        "la scritta «Fotocamera spenta. Lo schermo si spegnerà fra 15s». Il conto "
        "alla rovescia parte da 15. Un tocco lo fa ripartire. Arrivati a 0 lo schermo "
        "diventa nero, senza menu né orario. In modalità kiosk l’app prova anche a "
        "spegnere il pannello."
    )
    pdf.p(
        "Appena il visore seleziona la camera, il sensore si accende e lo stato passa "
        "a TRASMISSIONE ATTIVA. Se il visore esce, torna IN ATTESA VISORE: non deve "
        "restare scritto TRASMISSIONE ATTIVA senza nessuno che guarda."
    )
    pdf.h2("Modalità Eco")
    pdf.p(
        "Eco serve quando la telecamera è in vista e non vuoi che lo schermo mostri "
        "l’inquadratura o i pulsanti. Premendo Eco:"
    )
    pdf.bullets(
        [
            "Lo schermo va subito nero: niente menu, niente preview, niente pallino dell’app.",
            "Se il visore ha selezionato la camera, il video verso di lui resta acceso.",
            "Il pallino verde di Android (fotocamera in uso, da Android 12 in su) può "
            "restare, perché il sensore sta ancora filmando.",
            "Per uscire: doppio tocco sullo schermo. Se il pannello è spento, premi il "
            "tasto di accensione e hai circa 15 secondi per il doppio tocco.",
        ]
    )
    pdf.callout(
        "info",
        "Flash e lente",
        "Se il flash è acceso e dal visore (o sul posto) passi da posteriore a frontale, "
        "il LED si spegne e diventa lo schermo bianco, e viceversa. Spegnendo il flash "
        "frontale si torna a Eco oppure alla schermata normale, a seconda di dov’eri.",
    )
    pdf.h2("Icona Esci")
    pdf.p(
        "L’icona di uscita in alto a destra riporta alla scelta del ruolo. Utile se "
        "hai sbagliato CAM. Sui telefoni in kiosk Device Owner questo percorso può "
        "non essere disponibile: quel telefono è dedicato alla telecamera."
    )

    pdf.chapter("7. Il visore sul telefono")
    pdf.p(
        "Scegli VISORE. Entri in MONITORAGGIO LIVE. All’inizio la scritta centrale è "
        "«Seleziona una o più camere»: finché non ne tocchi nessuna, nessuna telecamera "
        "accende il sensore."
    )
    pdf.h2("Menu a scomparsa")
    pdf.p(
        "Un tap sullo schermo mostra la barra in alto (stato, esci, pallino) e il dock "
        "in basso. Restano visibili. Un altro tap li nasconde. Il video sta sempre a "
        "schermo intero sotto i menu, senza ritaglio: se la camera gira in orizzontale "
        "o in verticale, l’immagine segue quell’orientamento (bande nere se serve)."
    )
    pdf.callout(
        "ok",
        "Visore senza camere",
        "Se non hai ancora selezionato nulla, la barra con Esci resta comunque "
        "raggiungibile. Se l’hai nascosta, un tap al centro dello schermo la fa "
        "riapparire: non resti bloccato.",
    )
    pdf.h2("Il dock delle camere")
    pdf.p(
        "In basso scorri le sei CAM. Un’icona chiara e un bordino indicano che quella "
        "telecamera è accesa in casa (connessa). Sotto il nome, quando è in linea, "
        "compare la batteria in percentuale (verde / arancio / rosso). Un puntino "
        "sull’icona video riassume la qualità di rete: verde buona, arancio media, "
        "rosso scarsa."
    )
    pdf.numbered(
        [
            "Tocca una CAM per aggiungerla alla griglia: parte la richiesta video e, "
            "se è in casa, in pochi secondi vedi l’immagine.",
            "Tocca di nuovo per toglierla: quella telecamera spegne il sensore.",
            "Tieni premuto per rinominarla (es. Ingresso, Cucina). Il nome resta su "
            "quel visore.",
        ]
    )
    pdf.h2("Flash, audio e lente (sulla singola CAM)")
    pdf.p(
        "I tre pulsantini sotto ogni chip si attivano solo se quella camera è "
        "connessa e selezionata nella griglia."
    )
    pdf.kv_table(
        [
            ("Flash", "Accende o spegne il flash di quella telecamera."),
            ("Audio (icona volume)", "Ascolti il microfono di quella stanza. Di default è spento."),
            ("Lente", "Passa tra fotocamera posteriore e frontale a caldo."),
        ]
    )
    pdf.h2("Parla")
    pdf.p(
        "Sotto i chip, il pulsante Parla accende il microfono del visore verso le "
        "camere che stai guardando. Mentre è attivo diventa «Parlando». Premilo di "
        "nuovo per spegnere. Serve almeno una camera selezionata e in linea; altrimenti "
        "il pulsante resta spento."
    )
    pdf.h2("Griglia")
    pdf.p(
        "Una camera sola occupa tutto lo schermo. Più camere si dividono lo spazio. "
        "In ogni riquadro compare il nome in basso a sinistra. Se la camera è stata "
        "chiesta ma il video non è ancora arrivato, vedi «In attesa di …» oppure un "
        "indicatore di caricamento."
    )

    pdf.chapter("8. Il visore sul computer (webapp)")
    pdf.p(
        "Il visore PC non è l’app Flutter nel browser: è una pagina locale nella "
        "cartella web-viewer. Usa lo stesso App ID, la stessa chiave di casa, lo stesso canale e gli stessi "
        "comandi dell’app. Il computer non pubblica la propria webcam."
    )
    pdf.h2("Avvio su Windows")
    pdf.numbered(
        [
            "Chiudi il visore sull’app Android, se era aperto.",
            "Chiudi l’eventuale finestra nera di un visore PC già avviato.",
            "Doppio clic su web-viewer\\avvia.bat.",
            "Si apre Chrome o Edge su http://localhost:8787/ (non su 127.0.0.1).",
            "Incolla l’App ID, la chiave di casa e premi Connetti.",
        ]
    )
    pdf.p(
        "Lo script libera la porta 8787 se un avvio precedente l’ha lasciata occupata. "
        "Se il visore è già in ascolto, apre solo il browser."
    )
    pdf.h3("Se il file .bat non parte")
    pdf.p("Da PowerShell, nella cartella web-viewer:")
    pdf.set_fill_color(*NAVY)
    pdf.set_text_color(*WHITE)
    pdf.set_font("UI", "", 9.2)
    pdf.ensure(28)
    x, y, w = pdf.l_margin, pdf.get_y(), pdf.epw
    pdf.rrect(x, y, w, 22, 2)
    pdf.set_xy(x + 5, y + 3)
    pdf.multi_cell(w - 10, 5.2, "powershell -ExecutionPolicy Bypass -File .\\avvia.ps1\n\noppure:\npython -m http.server 8787")
    pdf.set_y(y + 26)
    pdf.set_text_color(*INK)
    pdf.p(
        "Poi apri http://localhost:8787/ . Non aprire index.html con doppio clic "
        "(indirizzo file://): Agora WebRTC richiede http://localhost."
    )
    pdf.callout(
        "stop",
        "Non usare 127.0.0.1",
        "L’SDK Agora nel browser rifiuta 127.0.0.1. Lo script e la pagina reindirizzano "
        "verso localhost. Se incolli a mano l’indirizzo, scrivi localhost.",
    )
    pdf.h2("Schermata di ingresso")
    pdf.p(
        "Titolo «Visore PC», campi App ID Agora e chiave di casa, link www.agora.io, pulsante Connetti. "
        "Sotto è ricordato il canale fisso casa_sicura e l’invito a chiudere il visore "
        "sul telefono. Se il join si blocca oltre dieci secondi compare un avviso "
        "«Agora non risponde» con Riprova."
    )
    pdf.h2("Dopo Connetti: come sull’app")
    pdf.p(
        "Non c’è una seconda schermata di scelta. Restano la griglia e, in basso, "
        "tutte le CAM. Un clic sulla CAM la mette in diretta; un altro clic la toglie. "
        "Non serve uscire e rientrare."
    )
    pdf.kv_table(
        [
            ("Pallino", "Verde solo se arrivano fotogrammi da una camera selezionata; rosso se sei connesso ma non c’è video."),
            ("Disconnetti", "Esci dal canale e torni al login."),
            ("Flash / Audio / Post-Front", "Stessi comandi del telefono, sul chip della CAM."),
            ("Parla", "Chiede il microfono del browser. Diventa «Parlando» mentre è attivo."),
            ("Rinomina", "Clic destro sulla CAM: il nome resta solo su quel computer."),
        ]
    )
    pdf.p(
        "Il video è in modalità contain: se il telefono camera è in verticale vedi "
        "l’immagine verticale, se è in orizzontale la vedi orizzontale, anche se ruoti "
        "il telefono mentre stai guardando."
    )
    pdf.h2("Requisiti e limiti del visore PC")
    pdf.bullets(
        [
            "Internet necessario: al primo caricamento può servire l’SDK Agora.",
            "Telecamere con APK recente (griglia e comandi WATCH). L’APK GitHub v1.0.1 "
            "obsoleta non basta.",
            "Un visore alla volta. Il visore PC usa l’identificativo 101, il telefono "
            "visore il 100: se restano entrambi aperti i comandi si sovrappongono comunque.",
            "Se compare il messaggio di aprire Chrome o Edge e non la finestra di Cursor, "
            "segui quell’indicazione.",
        ]
    )
    pdf.draw_architecture()
    pdf.italic(
        "Schema: le sei telecamere restano nel canale; solo quelle scelte dal visore "
        "(telefono oppure PC) accendono la fotocamera e mandano il filmato."
    )

    pdf.chapter("9. Come lavorano insieme")
    pdf.h2("Accensione on demand")
    pdf.p(
        "Le telecamere entrano nel canale e aspettano. Non filmando a vuoto si risparmia "
        "batteria e si evita di lasciare la fotocamera accesa in una stanza vuota. "
        "Quando il visore seleziona una CAM, quella accende il sensore e pubblica. "
        "Quando la togli dalla griglia, o chiudi il visore, il sensore si spegne."
    )
    pdf.h2("Stesso App ID, stesso momento")
    pdf.p(
        "Visore e telecamere devono essere online insieme e con lo stesso App ID. "
        "Se cambi progetto Agora, aggiorna il codice su tutti i telefoni e sul PC "
        "(Reimposta App ID e ruolo sull’app, poi reinserisci)."
    )
    pdf.h2("Orientamento")
    pdf.p(
        "Puoi ruotare il telefono camera: il flusso diventa orizzontale o verticale e "
        "il visore (app e PC) adatta l’immagine senza tagliarla."
    )
    pdf.h2("Batteria")
    pdf.p(
        "Aprendo il visore le telecamere già in linea inviano subito la percentuale. "
        "La vedi sotto l’icona nel dock, non scritta sopra il video."
    )
    pdf.h2("Sfondo e blocco schermo (telecamera)")
    pdf.p(
        "Se quella CAM è selezionata dal visore, la trasmissione può continuare con "
        "lo schermo spento o l’app in background, grazie al servizio in primo piano "
        "e alla notifica. Se non è selezionata, il sensore resta spento."
    )

    pdf.chapter("10. Telecamera fissa (kiosk, facoltativo)")
    pdf.p(
        "Per un telefono che deve fare solo da telecamera, puoi configurarlo come "
        "Device Owner Android Enterprise con il QR nella cartella device-owner. "
        "Dopo il provisioning quel telefono parte come CAM 1, in modalità kiosk "
        "(lock task) una volta nel canale."
    )
    pdf.numbered(
        [
            "Il telefono deve essere nuovo o ripristinato ai dati di fabbrica.",
            "Durante la configurazione iniziale, tocca sei volte la schermata e inquadra "
            "il QR (provisioning-qr.png) a schermo intero sul PC.",
            "Serve rete mentre scarica l’APK indicato nel QR.",
            "Alla fine inserisci lo stesso App ID Agora e la stessa chiave di casa del visore.",
        ]
    )
    pdf.callout(
        "stop",
        "Uscita dal kiosk",
        "Nel modello attuale non c’è PIN, gesto segreto o comando da remoto per uscire. "
        "L’unico recupero è il ripristino dati di fabbrica secondo il produttore del "
        "telefono. Perdi app, App ID e configurazione; poi ripeti QR e App ID. "
        "Non usare un telefono che ti serve ancora come telefono quotidiano.",
    )
    pdf.callout(
        "warn",
        "QR e APK v1.0.0",
        "Non usare il QR o l’APK della versione 1.0.0. Per il kiosk usa il QR "
        "attuale in device-owner e, dopo l’installazione, allinea l’app alla build "
        "locale aggiornata se il QR punta ancora a un pacchetto GitHub vecchio.",
    )
    pdf.p(
        "Il visore quotidiano è un APK normale, senza Device Owner, sul telefono "
        "che tieni in tasca — oppure il visore PC."
    )

    pdf.chapter("11. Privacy e buone pratiche")
    pdf.bullets(
        [
            "Il video parte solo se il visore ha selezionato quella camera.",
            "L’audio della stanza parte solo se sul visore premi l’icona del volume "
            "di quella CAM.",
            "«Parla» usa il microfono del visore (o del browser) e solo verso le "
            "camere selezionate.",
            "Chi ha App ID e canale casa_sicura, ma non la chiave di casa, non decifra "
            "video né comandi. Non pubblicare App ID né chiave.",
            "L’app non usa un tuo account cloud: non c’è un pannello web aziendale "
            "da cui “spegnere” i telefoni. Il controllo è locale, sui dispositivi.",
            "Rispetta le persone in casa: avvisa se una stanza è ripresa, soprattutto "
            "con audio.",
        ]
    )
    pdf.p(
        "Il progetto Testing di Agora non è uno scrigno inviolabile. Per una casa "
        "è comodo e gratuito; non sostituisce un impianto certificato né una "
        "centrale d’allarme."
    )

    pdf.chapter("12. Problemi frequenti")
    pdf.kv_table(
        [
            ("Niente video", "Stesso App ID e stessa chiave? Telecamere e visore online? Hai toccato la CAM nel dock? Un solo visore aperto?"),
            ("Schermo nero dopo Connetti", "Chiave di casa diversa da un telefono. Reinseriscila identica su tutti."),
            ("Join fermo sul PC", "Apri Chrome/Edge su localhost, non Cursor e non 127.0.0.1. Premi Riprova se compare il banner."),
            ("file:// non va", "Non aprire l’HTML con doppio clic. Usa avvia.bat."),
            ("Installazione rifiutata", "Telefono 32 bit, o origini sconosciute disattivate. Serve Android 64 bit."),
            ("Flash frontale strano", "È normale: non c’è LED, si illumina lo schermo della CAM. OFF lo toglie."),
            ("Schermo camera nero", "Eco o standby a 0 secondi. Doppio tocco (Eco) o un tocco (standby) per rivedere i comandi."),
            ("Pallino Android verde in Eco", "Il sensore sta filmando per il visore. In standby a sensore spento quel pallino non c’è."),
            ("Due visori", "Chiudi telefono o PC. Lasciane uno solo."),
            ("Batteria assente", "La CAM deve essere in linea. Riapri il visore: all’ingresso chiede di nuovo i livelli."),
            ("Permessi negati", "Impostazioni Android → App → permessi fotocamera, microfono, notifiche."),
            ("Riconnessione in corso…", "Rete instabile. Attendi o verifica il Wi‑Fi; sull’errore grave c’è RIPROVA."),
            ("Parla non parte sul PC", "Il browser deve avere il microfono consentito per localhost."),
        ]
    )
    pdf.h2("Checklist di una sessione ok")
    pdf.numbered(
        [
            "Stesso App ID Agora e stessa chiave di casa su ogni telefono e sul PC.",
            "APK aggiornato su visore e su tutte le CAM.",
            "Ogni telecamera un ruolo diverso (CAM 1–6).",
            "Un solo visore aperto.",
            "Permessi concessi; telecamere in rete; visore che seleziona almeno una CAM.",
        ]
    )

    pdf.chapter("13. Limiti da tenere a mente")
    pdf.bullets(
        [
            "Solo Android per i telefoni. Non c’è app iPhone, né app Windows: sul PC "
            "usi la webapp locale.",
            "Fino a sei telecamere e un visore per volta.",
            "Serve internet. Non è un sistema solo LAN chiusa.",
            "Non è un allarme con sirena, cloud di registrazione o storico dei filmati: "
            "è visione in diretta.",
            "Il kiosk Device Owner è irreversibile senza factory reset.",
            "Agora Testing è adatto a casa e prove; per un uso commerciale servirebbero "
            "token, certificato e un backend che questa app, in questa versione, non usa.",
        ]
    )
    pdf.ln(4)
    pdf.callout(
        "info",
        "In sintesi",
        "Prepara l’App ID e la chiave di casa, installa la stessa app su visore e camere, scegli i ruoli, "
        "apri un solo visore (telefono o avvia.bat sul PC) e tocca le CAM che vuoi "
        "vedere. Flash, audio, lente e Parla stanno nel dock. Sulla telecamera, Eco "
        "nasconde lo schermo; lo standby spegne sensore e display quando nessuno guarda.",
    )
    pdf.ln(6)
    pdf.set_font("UI", "I", 9.5)
    pdf.set_text_color(*MUTED)
    pdf.multi_cell(
        0,
        5.2,
        "Manuale riferito all’app 1.0.1 build 19 e al visore PC 19f. "
        "Uso personale in ambito domestico. Non contiene password, App ID di esempio "
        "reali né istruzioni per accedere a dispositivi altrui.",
    )

    pdf.output(str(OUT))
    return OUT


if __name__ == "__main__":
    path = build()
    print(path)
    print(path.stat().st_size)
