"""Stub for Nous subscription managed-tool capabilities (BMB fork)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, Optional


@dataclass(frozen=True)
class NousFeatureState:
    key: str = ""
    label: str = ""
    included_by_default: bool = False
    available: bool = False
    active: bool = False
    managed_by_nous: bool = False
    direct_override: bool = False
    toolset_enabled: bool = False
    current_provider: str = ""
    explicit_configured: bool = False


@dataclass(frozen=True)
class NousSubscriptionFeatures:
    subscribed: bool = False
    nous_auth_present: bool = False
    provider_is_nous: bool = False
    features: Dict[str, NousFeatureState] = None

    def __post_init__(self):
        if self.features is None:
            object.__setattr__(self, "features", {})

    @property
    def web(self) -> NousFeatureState:
        return self.features.get("web", NousFeatureState())

    @property
    def image_gen(self) -> NousFeatureState:
        return self.features.get("image_gen", NousFeatureState())

    @property
    def tts(self) -> NousFeatureState:
        return self.features.get("tts", NousFeatureState())

    @property
    def browser(self) -> NousFeatureState:
        return self.features.get("browser", NousFeatureState())

    @property
    def modal(self) -> NousFeatureState:
        return self.features.get("modal", NousFeatureState())

    def items(self) -> Iterable[NousFeatureState]:
        ordered = ("web", "image_gen", "tts", "browser", "modal")
        for key in ordered:
            yield self.features.get(key, NousFeatureState())


def get_nous_subscription_features(config: Optional[Dict[str, object]] = None) -> NousSubscriptionFeatures:
    """Stub: returns default empty features (no Nous subscription in BMB fork)."""
    return NousSubscriptionFeatures(
        subscribed=False,
        nous_auth_present=False,
        provider_is_nous=False,
        features={},
    )


def apply_nous_managed_defaults(
    config: Dict[str, object],
    *,
    enabled_toolsets: Optional[Iterable[str]] = None,
) -> set[str]:
    """Stub: does nothing, returns empty set."""
    return set()
