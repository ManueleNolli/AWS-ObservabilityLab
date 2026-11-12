"""HTTP layer: routes, request dependencies and error mapping."""

# Set on each module's router rather than when including it: only then is the
# prefix part of the route template that ends up in the metric labels.
API_PREFIX = "/api"
