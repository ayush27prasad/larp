"""Entry point for the sample project."""

from utils.strings import shout


def main() -> None:
    for line in ("hello", "from", "larp"):
        print(shout(line))


if __name__ == "__main__":
    main()
