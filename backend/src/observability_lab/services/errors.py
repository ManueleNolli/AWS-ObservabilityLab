"""Expected failures; the API layer maps each one to an HTTP status."""


class ServiceError(Exception):
    """Base class for failures that are part of normal operation."""


class InvalidCredentialsError(ServiceError):
    def __init__(self) -> None:
        super().__init__("Invalid credentials")


class PaymentProviderError(ServiceError):
    def __init__(self) -> None:
        super().__init__("Payment provider unavailable")
