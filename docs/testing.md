# Testing and Transfer Simulation

## NVIDIA acceptance sequence

Run in this order:

```bash
./scripts/preflight.sh nvidia
./scripts/build.sh nvidia
./scripts/start.sh nvidia
./scripts/test.sh nvidia
./scripts/stop.sh nvidia
./scripts/export.sh --with-images --with-models
```

The export command creates a compressed package and performs a real `docker save` of the required image set.

## Transfer simulation without disturbing foreign Docker resources

A safe simulation on the same daemon cannot fully prove a fresh-host import because `docker load` may find identical images already present. Do not delete existing images just to force that scenario.

Instead verify:

1. export archive exists;
2. archive SHA256 validates;
3. Docker image tar SHA256 validates;
4. `tar -tf` lists project contents;
5. import procedure is documented and can run on a separate Docker environment/future PC.

A true clean import test should be performed on another Docker environment rather than pruning or removing images from the brother's PC.
