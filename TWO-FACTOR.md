# Using Two-factor authentication with LUKS and YubiKey
By [Zidmann](mailto:emmanuel.zidel@gmail.com) :bow:

## Global presentation
LUKS is usually used with a passphrase or a key file, but it can also be used with a Yubikey device : the user plugs his/her Yubikey, enters a passphrase which deciphers the partition or the container. It can be done when the computer boots or after.

## Projects
There are several projects to use Yubikey to decrypt LUKS partitions or containers :
* https://github.com/tfheen/ykfde
* https://github.com/flowolf/initramfs_ykfde/
* https://github.com/cornelinux/yubikey-luks
* https://github.com/dmitryd/kali-yubikey

In this documentation, we studied the project [yubikey-luks](https://github.com/cornelinux/yubikey-luks) provided by [Cornelius Kölbel](https://github.com/cornelinux) which can be used on Ubuntu/Debian distributions.

## How does it work ?
The solution consists in using the challenge response feature of the Yubikey.

That is the process :
1. the Yubikey stores an HMAC-SHA1 secret (by default in its slot 2)
2. the user types a passphrase
3. the passphrase is passed in the input of the Yubikey which returns a string in output (according to this passphrase and its own secret)
4. the Yubikey output string will be used as the real passphrase for the slot 7 of the LUKS volume (hard-coded)

## Caution
**!! WARNING !!** By safety, another slot should be used with a backup passphrase (long and hard to guess) or a key file if the Yubikey used is defective, lost or its secret key changed.

## Installation
```bash
# apt-get install yubikey-luks
```

This installation provides these commands :
* **yubikey-luks-enroll** command used to configure one of the LUKS slot
* **yubikey-luks-open** command used to open a LUKS volume
* **/etc/ykluks.cfg** configuration file used by the previous commands

## Configuration
### _Configure Yubikey-LUKS module_ ###
The configuration file **/etc/ykluks.cfg** most of the time contains these lines :
```bash
WELCOME_TEXT="Please insert yubikey and press enter or enter a valid passphrase"
CONCATENATE=0
HASH=0
```

Here a description of each attribute and what is its goal :
| Attribute | Description |
|--------|--------|
| WELCOME_TEXT | The prompt that appears when the LUKS password is needed to decrypt |
| CONCATENATE | Set to "1" if you want both your passphrase and Yubikey response be bundled together and writtent to key slot. |
| HASH | Set to "1" if you want to hash your passphrase with sha256. |
| YUBIKEY_LUKS_SLOT | The slot dedicated in the Yubikey for the HMAC-SHA1 challenge response |
| SUSPEND | Set this to "1" if you want to use Yubikey with suspend (default to 0) |

**!! WARNING !!** If you change this configuration file, then the result of the challenge-response output will change, then you will have to enroll again the partitions using this Yubikey.

### _Configure the Yubikey_ ###
To prepare the Yubikey and generate a key for the HMAC-SHA1 protocol, we use the command (with _YUBIKEY_LUKS_SLOT_ the value in **/etc/ykluks.cfg**) :
```bash
# ykpersonalize -<YUBIKEY_LUKS_SLOT> -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible
```

**!! WARNING !!** If you have already configured a slot for HMAC-SHA1 challenge-response mode, the command will overwrite the previous secret key and the access to the devices will become unrecoverable.

### _Configure the LUKS slot_ ###
To configure an empty slot to be decrypted with a password and the Yubikey :
```bash
yubikey-luks-enroll -d /dev/<partition> -s <slot>
```

If the slot is already used, to kill it before configuring it :
```bash
yubikey-luks-enroll -d /dev/<partition> -s <slot> -c
```

### _Configure the kernel_ ###
If a partition needs to be mounted in the boot of the computer, the file **/etc/crypptab** must be updated by adding the **keyscript** option :
```bash
<partition_name> UUID=<partition_uuid> none luks,keyscript=/usr/share/yubikey-luks/ykluks-keyscript
```

After updating the configuration file, it is necessary to update the kernels :
```bash
update-initramfs -k all -c
```

## Retro-engineering
The script **/usr/share/yubikey-luks/ykluks-keyscript** has been read to understand how it does work.

### _Step 1: loading variables and functions_ ###
* load the variables in the file **/etc/ykluks.cfg** 
* set a default welcome message
* check if the Yubikey device is plugged with the command **ykinfo** and store the state in **check_yubikey_present** variable
* define the **message** function
* load the library **/usr/share/initramfs-tools/scripts/functions**

### _Step 2: getting the user passphrase_ ###
* define the command **cryptkeyscript** which will get the passphrase (most of the time **askpass**)
* get the passphrase given by the user and store it in **PW** variable

### _Step 3: returning the final passphrase_ ###
* if the Yubikey is not plugged ("$check_yubikey_present" != "1"), return simply **PW** content
* otherwise, several steps :
  * if HASH=1, then the content of **PW** is hashed with __sha256sum__
  * the Yubikey is requested for a challenge-response with **ykchalresp** command, **PW** as an input and the store the output in **R** variable
  * if CONCATENATE=1, then the content of **R** is prefixed with **PW**
  * return of **R** final content

## Security aspect
The solutions to use LUKS with a Yubikey have a certain security risk: though LUKS passphrase is generated by the Yubikey, it is static.
Then, if somebody can save the key in some way, it can unlock LUKS partition without yubikey.

Rotating the Yubikey HMAC-SHA1 secret key and next the slot passphrase can not be conceivable because the other LUKS devices or partitions which use the Yubikey will no longer be opened.

## References
* https://doc.ubuntu-fr.org/plymouth
* https://en.wikipedia.org/wiki/HMAC
* https://askubuntu.com/questions/599825/yubikey-two-factor-authentication-full-disk-encryption-via-luks
* https://www.guyrutenberg.com/2022/02/17/unlock-luks-volume-with-a-yubikey/
* https://www.howtoforge.com/ubuntu-two-factor-authentication-with-yubikey-for-harddisk-encryption-with-luks
* https://qastack.fr/ubuntu/599825/yubikey-two-factor-authentication-full-disk-encryption-via-luks
