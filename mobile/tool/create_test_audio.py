import argparse
import math
import struct
import wave
from pathlib import Path


def create(directory):
    directory.mkdir(parents=True, exist_ok=True)
    for number, seconds in enumerate((60, 18, 12), 1):
        filename = directory / f"MusicAPP_Test_{number:02d}.wav"
        sample_rate = 16000
        with wave.open(str(filename), "wb") as audio:
            audio.setparams((1, 2, sample_rate, 0, "NONE", "not compressed"))
            audio.writeframes(b"".join(
                struct.pack("<h", int(1200 * math.sin(2 * math.pi * (220 + number * 110) * i / sample_rate)))
                for i in range(sample_rate * seconds)
            ))
        print(filename)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    create(parser.parse_args().output)
