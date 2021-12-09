# OSS
These scripts are based on LFS and BLFS. There are changes in CFLAGS and some packages according to my need. These do not contain any tests.

## How are these scrips different than others?
The most magical part is versions. I have taken the version from the file name itself. So that whenever I update the packages I don't have to update the version number in the script as well. All I gotta do is change the version number in the download link and I am good to go. Consider the changelog for LFS and BLFS. They mention the updates in different way and in book process changes in different way. That way if there are changes in the process then I can update the script or esle I just
have to change the version number once in the downlond links page.

One small thing is that I just have to run the script all other configuration and every small nook and cranny is handled by the script. Network configuration and getting my application config from git repository and adding them to my home. Basically everything.

## BLFS Applications
Basically the quest was to build the firefox from the source. So each and every application was decided according to that. Most X Libraries are compiled. But they will not be in use because of Wayland. The final build will work on Wayland with Sway. I wont be including each and every package that has been compiled in the script but the top ones being:

- Firefox
- XFSprogs

- FFMPEG
- Pulseaudio
- Alsa
- OGG, Speex, FLAC, Opus
- Fdk-acc, Lame, Theora, libVpx, X264, X265, SDL2

- Mutt
- Neovim

- Sway
- Swaybg
- IBM Plex as fonts
- Foot
- Grim, Slurp
- Polkit
- DBUS
- Elogind, Seatd

- Rust
- LLVM, Clang
- NodeJS
- Python w/ Sqlite

- OpenSSH
- Fuse, SSHFS
- Luajit
- OpenVPN

## How to use the scripts?
Basically the start point is `install.sh`. There you have to mention the drive. Everything else the script will do automatically. Before hand you have to provide your kernel config in the static folder. That will be used to make your kernel.

### Changes for your system.
***If you don't know what you are doing then please don't run the scripts.*** Now if you want to have same applications and mentioned above and the basic LFS system then you have to provide the kernel config along with the boot partition type details. You can format your drive for the BIOS and UEFI in the `install.sh`. Then according to your boot type make changes in `3-blfs.sh`. Also I haven't used any other filesystem rather then XFS. So consider your system and bulid filesystem and
use it in the kernel accordingly.

CFLAGS are mentioned in every file so you have to change the flags in everyfile. Don't forget to change the MAKEFLAGS cores in every file.

## How much time this will take?
On my hardware i.e., AMD Ryzen 3400G with 16G RAM and a SSD it takes 5 hours to build the entire OS from scratch. The most time consuming ones are LLVM and Rust. Firefox with take about 50 minutes. Apart from that every other small packages will not take that much time. 3.5 hours for LLVM,Rust and Firefox. 1.5 for basic LFS and all other packages. A slight faster and a slight slower process can make huge diffrence in SBU.

**If somehow you are here I assume you know what you are doing. Do not run these scripts if you don't know what you are doing.**
