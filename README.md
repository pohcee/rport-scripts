# rport-scripts

A group of bash helper scripts with integrated command line completion that target an [OpenRport](https://oss.openrport.io) server. Sometimes it's just better to do things via the CLI.

## Installation

Simply run the installer. It will check for prerequisites and guide you through the setup.

```bash
./install.sh
```

## Usage

### rport-clients

List all clients connected to the Rport server.

```
$ rport-clients
CLIENT_NAME       CLIENT_ID                                  HOSTNAME           HOST_USER  TUNNELS
client-01         e0668077-d9b8-40aa-b5e6-420f38b05637        10.2.20.10         admin      1
client-02         e0668077-d9b8-40aa-b5e6-420f38b05638        10.2.20.11         admin      0
```

### rport-status

Show the status of the Rport server.

```
$ rport-status
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

### rport-ssh

SSH into a client connected to the Rport server. You can also optionally execute a command on the remote host.

```
$ rport-ssh client-01
$ rport-ssh client-01 "ls -l /tmp"
```

### rport-scp

Securely copy files to/from a client connected to the Rport server.

```
$ rport-scp local-file.txt client-01:remote-file.txt
```

### rport-sshfs

Mount a remote directory from a client connected to the Rport server via SSHFS.

```
$ rport-sshfs client-01:/home/admin /mnt/remote
```

### rport-tunnel

Create a tunnel to a client connected to the Rport server.

```
$ rport-tunnel client-01 3389
```

## Contributing

Pull requests are welcome. Please open an issue first to discuss what you would like to change.

## License

Apache-2.0
