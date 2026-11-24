# Atlas website and server

This is the existing Holiday Tracker server and website source. The running deployment remains in `../holiday-tracker` outside this repository; copying this source here does not change that deployment.

The SQLite database, photos, backups and private import snapshots are intentionally excluded from Git. The server currently requires its `import/` directory even with an existing database because it reads the curated `places.json` file on each data request. To run a local copy, supply the corresponding private `import/` directory and set `HOLIDAY_DATA_DIR` to an isolated directory; do not point test runs at production data. `HOLIDAY_PHOTOS_DIR` can point to the source photographs. The existing deployment's Compose configuration and persistent paths must be reviewed before any migration.

Run `python3 -m unittest -v test_server.py` with the original private import data present. The server is unauthenticated and intended only for trusted private networks.

The repository's `compose.yaml` records the existing bind mounts and private network addresses and mounts the private import directory read-only. It has not been applied: the running service still uses the original project. The image includes empty seed files for new, isolated setups; never start against an existing database without its matching private import directory. Check `docker compose config`, backups and paths before any later deployment change.
