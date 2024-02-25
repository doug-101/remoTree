---
# Usage
---
## Key Authentication
---

When editing host information, the Add Private Key button can be used to set
up key-based authentication.  The first option, Create on server, will use the
ssh-keygen command on the server to create the keys.  It will prompt for a key
passphrase - leave the field empty to skip the passphrase.  It will then
automatically add the public key to the "~/.ssh/authorized_keys" file on the
server and load the private key into remoTree.

The second option, Load from file, will load an existing private key from the
local file system.  It will assume that the public key has or will be copied
to the server manually.
