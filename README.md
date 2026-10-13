## ascii-apod

#### *only compatible with distros running KDE Plasma 6*

This program takes NASA's astronomy picture of the day (APOD), and uses korvexx's included ascii Wallpaper plugin (https://store.kde.org/p/2348111) to turn the apod into ascii art. 

The ascii-apod is then set to your lock screen and/or desktop, daily, updating every evening when NASA posts a new picture.

### first download 

go to the [latest release](https://github.com/nirvaanbn/ascii-apod/releases/latest), download the file called `apod`

### then install

```bash
cd the/folder/you/downloaded/it/to

chmod +x apod

./apod install
```

done!

### to update with the new apod every day run:

```bash
apod auto on
```

```bash
apod auto off   # turns updates off
```

### to save a png of the current art

```bash
apod save
```

### uninstall

```bash
apod uninstall
```

-------

### build from source (if you want)

needs Go 1.26.9 or newer:

```bash
git clone https://github.com/nirvaanbn/ascii-apod
cd ascii-apod
go run . install
```
