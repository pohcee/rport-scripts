# procy-cli

The Procy command line: bash helper scripts with integrated command line completion that target a [Procy](https://procy.sh/docs/) server. Sometimes it's just better to do things via the CLI.

## Installation

Simply run the installer. It will check for prerequisites and guide you through the setup.

```bash
./install.sh
```

It links the `procy-*` commands into `~/.local/bin` and adds shell completion. Then set, in your shell profile:

```bash
export PROCY_HOST=procy.yourcompany.com        # the Procy server (API at https://$PROCY_HOST/api/v1)
export PROCY_CREDENTIALS=youruser:yourtoken    # API user and password or token
```

`./uninstall.sh` removes the commands and the completion again.

### Renamed from rport-scripts

These scripts used to be called `rport-*` (repository `rport-scripts`). The old names keep working:

- `rport-clients`, `rport-ssh`, `rport-scp`, `rport-rsync`, `rport-sshfs`, `rport-tunnel`, `rport-status` and
  `rport-metadata` are still installed, as deprecated wrappers that run the matching `procy-*` command with the same
  arguments and the same output. When run in a terminal they print a one-line deprecation notice on stderr; when
  stderr is not a terminal (scripts, CI) they print nothing extra.
- `RPORT_HOST` and `RPORT_CREDENTIALS` are still read when `PROCY_HOST` / `PROCY_CREDENTIALS` are not set.
  `PROCY_*` wins when both are set.

Please move scripts and profiles to the new names; the old ones will be removed in a future major release.

## Usage

### procy-clients

List all clients connected to the Procy server.

```
$ procy-clients
CLIENT_NAME       CLIENT_ID                                  STATUS   HOSTNAME    TUNNELS
client-01         e0668077-d9b8-40aa-b5e6-420f38b05637       online   10.2.20.10  1
client-02         e0668077-d9b8-40aa-b5e6-420f38b05638       offline  10.2.20.11  0

$ procy-clients --status=online
CLIENT_NAME       CLIENT_ID                                  STATUS   HOSTNAME    TUNNELS
client-01         e0668077-d9b8-40aa-b5e6-420f38b05637       online   10.2.20.10  1

$ procy-clients --status=offline
CLIENT_NAME       CLIENT_ID                                  STATUS   HOSTNAME    TUNNELS
client-02         e0668077-d9b8-40aa-b5e6-420f38b05638       offline  10.2.20.11  0
```

### procy-status

Show the status of the Procy server.

```
$ procy-status
{
  "id": "e0668077-d9b8-40aa-b5e6-420f38b05637",
  "name": "rport-server",
  "version": "0.9.5",
  "fingerprint": "SHA256:fingerprint",
  "clients": 2,
  "tunnels": 1,
  "started_at": "2024-01-24T15:40:47.921937256-06:00",
  "updated_at": "2024-01-24T15:40:47.921937256-06:00",
  "os": "linux",
  "os_arch": "amd64",
  "os_family": "ubuntu",
  "os_kernel": "5.15.0-1023-aws",
  "hostname": "rport-server",
  "cpu_count": 2,
  "total_ram": 4096,
  "free_space": 20480,
  "address": "10.2.20.10",
  "client_id": "e0668077-d9b8-40aa-b5e6-420f38b05637"
}
```

### procy-ssh

SSH into a client connected to the Procy server. You can also optionally execute a command on the remote host.

```
$ procy-ssh client-01
$ procy-ssh client-01 "ls -l /tmp"
```

### procy-scp

Securely copy files to/from a client connected to the Procy server.

```
$ procy-scp local-file.txt client-01:remote-file.txt
```

### procy-rsync

Synchronize files/directories to/from a client connected to the Procy server using rsync over SSH.

```
$ procy-rsync ./local-dir/ client-01:/remote/dir/
$ procy-rsync client-01:/remote/dir/ ./local-dir/
$ procy-rsync -d ./local-dir/ client-01:/remote/dir/
```

Use `-d` to delete files at the destination that are not present in the source (`rsync --delete`).

### procy-metadata

Show metadata (vault key/value pairs) for a client in JSON format.

```
$ procy-metadata client-01
{
  "ssh-user": "admin",
  "ssh-pass": "secret"
}
```

### procy-sshfs

Mount a remote directory from a client connected to the Procy server via SSHFS.

```
$ procy-sshfs client-01:/home/admin /mnt/remote
```

### procy-tunnel

Create a tunnel to a client connected to the Procy server. The optional second argument sets the remote port (default: `22`).

```
$ procy-tunnel client-01 3389
```

Pass a third argument to instead forward through the client to another host reachable on its network (e.g. a device on its LAN), rather than to the client itself:

```
$ procy-tunnel client-01 104 192.168.1.50
```

## Tests

```bash
npm test        # or: bash test/run.sh
```

The tests stub `curl`, `ssh` and friends, so they need no server; they need `bash` and `jq`.

## Contributing

Pull requests are welcome. Please open an issue first to discuss what you would like to change.

## License

Apache-2.0
