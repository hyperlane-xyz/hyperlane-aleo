# Warp

Warp is the core Hyperlane application for bridging tokens in and out of Aleo.
There might be multiple instances of this contract. Due to Aleo's architecture 
regarding namespaces and contracts, one needs to adjust the name of the program
for new deployments. This is automatically done when the deployment is made
via the Hyperlane CLI. In case of manual deployment one would need to change
`program hyp_native_template.aleo;` in the compiled `main.aleo` file.

## Hyp Native Template
This is the template for the HypNative implementation. This is used to interact
with the native currency of Aleo (i.e. the credits program).