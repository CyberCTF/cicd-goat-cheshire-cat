"""The Cheshire Cat's grin: it lingers after the rest of the cat has faded."""

from dataclasses import dataclass


@dataclass
class Grin:
    """Tracks how visible the cat is, from 1.0 (all there) down to 0.0 (vanished).

    "Well! I've often seen a cat without a grin," thought Alice, "but a grin
    without a cat! It's the most curious thing I ever saw in my life!"
    """

    visibility: float = 1.0

    def fade(self, amount: float) -> float:
        """Fade the cat by ``amount`` and return the visibility that remains."""
        if amount < 0:
            raise ValueError("a cat cannot fade by a negative amount")
        self.visibility = max(0.0, self.visibility - amount)
        return self.visibility

    def vanished(self) -> bool:
        """Return True once the cat is gone — but the grin remains."""
        return self.visibility <= 0.0

    def describe(self) -> str:
        """Return a human-readable account of what is still visible."""
        if self.vanished():
            return "only a grin remains"
        if self.visibility >= 1.0:
            return "the whole cat is here"
        return "the cat is fading, but still grinning"
