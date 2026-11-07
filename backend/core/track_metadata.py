import re
import unicodedata

VIDEO_LABELS = {
    "official",
    "official video",
    "official music video",
    "official audio",
    "music video",
    "lyric video",
    "official lyric video",
    "lyrics",
    "lyric",
    "letra",
    "tradução",
    "traducao",
    "legendado",
    "legenda",
    "sub español",
    "sub esp",
    "sub english",
    "english subtitles",
    "audio",
    "áudio",
    "hd",
    "4k",
    "videoclipe oficial",
    "vídeo oficial",
    "letra e tradução",
}
VIDEO_TAG = re.compile(r"\s*(?:\(([^()]*)\)|\[([^\[\]]*)\])\s*$")
CHANNEL_SUFFIX = re.compile(r"(?:\s*[-–—]\s*topic|vevo)$", re.IGNORECASE)
SEPARATOR = re.compile(r"\s+[-–—]\s+")


def normalize(value):
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def clean_artist(value):
    return CHANNEL_SUFFIX.sub("", value.strip()).strip() or value.strip()


def _compact(value):
    return "".join(char for char in normalize(value) if char.isalnum())


def artist_key(value):
    return _compact(clean_artist(value))


def clean_title(value):
    value = unicodedata.normalize("NFKC", value).strip()
    while match := VIDEO_TAG.search(value):
        annotation = normalize(match.group(1) or match.group(2) or "")
        parts = re.split(r"\s*[/+|,&]\s*", annotation)
        if not all(part in VIDEO_LABELS for part in parts):
            break
        value = value[: match.start()].rstrip()
    return value


def title_key(title, artist):
    key = normalize(clean_title(title)).strip(" *~〜♪♫")
    if artist_key(artist) == "orangerange" and key in {"asterisk", "アスタリスク", "asutarisuku"}:
        return "asterisk"
    return key


def search_metadata(track):
    """Return a preferred identity and at most two searches without guessing by similarity."""
    title = clean_title(track["title"]) or track["title"]
    artist = clean_artist(track["artist"])
    album = track["album"]
    if normalize(album) in {"<unknown>", "álbum desconhecido"} or (
        album and normalize(album) in {normalize(track["title"]), normalize(track["artist"])}
    ):
        album = ""
    base = {**track, "title": title, "artist": artist, "album": album}
    sides = SEPARATOR.split(title)
    if len(sides) != 2 or not all(sides):
        return base, [base]
    left, right = (clean_title(side) for side in sides)
    if not left or not right:
        return base, [base]

    def pair(song, performer, *, keep_album=False):
        return {
            **base,
            "title": song,
            "artist": clean_artist(performer),
            "album": album if keep_album else "",
        }

    if artist_key(left) == artist_key(artist):
        match = pair(right, left, keep_album=True)
    elif artist_key(right) == artist_key(artist):
        match = pair(left, right, keep_album=True)
    elif left.isdecimal() != right.isdecimal():
        match = pair(left, right) if left.isdecimal() else pair(right, left)
    else:
        return base, [base, pair(right, left), pair(left, right)]
    return match, [match]
