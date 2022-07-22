# Automatically mount a LUKS partition
By [Zidmann](mailto:emmanuel.zidel@gmail.com) :bow:

## Global presentation
**udev** the device manager for the Linux kernel is used to launch some scripts when a device is plugged or unplugged.
In the case of a LUKS device that can be used to open the LUKS partition and next mount it.

## Implementation
In the directory **[scripts/](./scripts)**, some scripts and configuration files were written to process a LUKS device when it is added or removed.

A **udev** rules (**99-local.rules**) call a service (**usb-luks-mount@.service**) if a USB device is added or removed (plugged or unplugged) to call a script (**luks-automount.sh**) which will :
* check if required parameters are well defined
* erase the unused directory in **/media**
* open/close the LUKS partition
* notify some users
* archive or delete old logs

The LUKS partition has no header here since an external header was used more discretion.

The header and the key used depends on the UUID of the partition.
When the device is plugged these files are searched :
* $HEADER_DIR/$UUID.header the LUKS header
* $KEY_DIR/$UUID.key the LUKS key

## Files and directories
### _Directories_
| Directory path | Description |
|--------|--------|
| /root/luks-automount/header | The directory where the LUKS headers are stored |
| /root/luks-automount/key | The directory where the LUKS keys are stored |
| /root/luks-automount/log | The directory where to store the log files |

### _Files_
| File path | Description |
|--------|--------|
| /etc/luks-automount/common.cfg | The configuration file |
| /etc/systemd/system/usb-luks-mount@.service | The service **usb-luks-mount** which calls **luks-automount.sh** script |
| /etc/udev/rules.d/99-local.rules | Udev rules to trigger the service **usb-luks-mount** |
| /usr/local/bin/luks-automount.sh | The script to open and mount the device |

## Useful commands
### _Read the udev events_ ###
```bash
> udevadm monitor --kernel --property --subsystem-match=usb
```

### _Reload udev_ and the services ###
When the scripts or the configuration are updated, launch :
```bash
# udevadm control --reload-rules
# systemctl daemon-reload
```
## Future improvements
In the future, the key will be downloaded from an external device like Bitwarden or Vault.

## References
* https://andreafortuna.org/2019/06/26/automount-usb-devices-on-linux-using-udev-and-systemd/
* https://fr.wikipedia.org/wiki/Udev
* https://doc.ubuntu-fr.org/udev
* https://forums.linuxmint.com/viewtopic.php?t=299969
* https://www.youtube.com/watch?v=nSI7M93uTEc
* https://unix.stackexchange.com/questions/620821/decrypt-luks-partition-by-a-script-in-udev-rules
