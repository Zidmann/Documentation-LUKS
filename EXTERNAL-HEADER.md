# Using an external header
By [Zidmann](mailto:emmanuel.zidel@gmail.com) :bow:

## Global presentation
When a storage (partition or container) is encrypted with LUKS, the header makes it identified by checking its volume header:
```bash
> cryptsetup isLuks -v /dev/<partition>
```

To avoid this situation, it is possible with the version 2 of LUKS (LUKS2) to detach the header from the encrypted content.
To do it, we use the same commands described in **[README.md](./README.md)** but we add the option **_--header_**.

Decrypting a LUKS content without the header of a container or partition is harder for an attacker.
Indeed, when an attacker has the header, it will try to find one of the passphrases used with the slots through the PBKDF algorithms to get the master key.
In the case the attacker has not the header, it will have to guess the master key, which is more complex (especially if two AES-256 keys are used consecutively).

## Useful commands
### _Create a new LUKS partition_
```bash
> cryptsetup luksFormat --verify-passphrase [--hash=<hash_algorithm>] --key-size <key_size> /dev/<partition> --header <header_path>
```
Instead of creating the header in the first sectors of the encrypted device, the header will be a file stored in the path **_<header_path>_**.
It can be stored on a separate filesystem or a separate raw device.

### _Mount a LUKS partition_
```bash
> cryptsetup luksOpen /dev/<partition> <partition_name> --header <header_path>
```

## Crypttab
A detached LUKS header is easy to obtain, however using the encrypted device requires more steps to mount it during the boot.
In this case, you must change the content of the file **/etc/crypptab** :

```
# <target_name> <source_device> <key_file> <options>
<partition_name> /dev/<partition> none luks,header=<header_path>
or
<partition_name> UUID=<partition_uuid> none luks,header=<header_path>
```

Next, you have to update the kernels :
```bash
> update-initramfs -k all -c
```

## References
* https://linuxconfig.org/how-to-use-luks-with-a-detached-header
