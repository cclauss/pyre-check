from typing import Any

class Environment:
    data: dict[str, Any]
    def __init__(self, config: dict[str, Any], prefix: str) -> None: ...
    def load(self) -> dict[str, Any]: ...