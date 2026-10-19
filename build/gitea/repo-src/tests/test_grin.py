import pytest

from cheshire.grin import Grin


def test_starts_whole():
    grin = Grin()
    assert grin.visibility == 1.0
    assert grin.vanished() is False
    assert grin.describe() == "the whole cat is here"


def test_fades_to_a_grin():
    grin = Grin(visibility=0.5)
    assert grin.fade(0.5) == 0.0
    assert grin.vanished() is True
    assert grin.describe() == "only a grin remains"


def test_partly_faded():
    grin = Grin()
    assert grin.fade(0.25) == 0.75
    assert grin.describe() == "the cat is fading, but still grinning"


def test_negative_fade_rejected():
    with pytest.raises(ValueError):
        Grin().fade(-0.1)
