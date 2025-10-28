# Hypertools

A lightweight CLI tool for interacting with the Aleo Hyperlane devnet.

## Commands

### fetch
For `fetch` it is required that a local devnet is running on `http://localhost:3030`
```shell
python3 hypertools.py fetch [event_id]
```
Fetches a dispatched Hyperlane message and converts it to its hexadecimal representation.

### process-warp
```shell
python3 hypertools.py process-warp
```
Generates an Aleo struct which can be used for the Leo CLI to pass. 
Use `--help` for changing content.

