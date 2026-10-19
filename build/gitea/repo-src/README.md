# cheshire

A tiny helper for Wonderland's scheduling service that tracks the Cheshire Cat's
vanishing grin — "a grin without a cat!" The cat fades, but the grin remains.

```python
from cheshire.grin import Grin

grin = Grin()
grin.fade(0.25)      # -> 0.75
grin.describe()      # -> "the cat is fading, but still grinning"
grin.fade(0.75)      # -> 0.0
grin.vanished()      # -> True
```

## Development

```bash
python3 -m venv venv && . venv/bin/activate
pytest
```

CI runs on Wonderland's Jenkins from the `Jenkinsfile` in this repository on every
branch and pull request. Per Wonderland policy, application builds run on the
dedicated `linux` build agents — not on the controller.
