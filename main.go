package main

import(
	"log"
	"os"
	"path/filepath"
)

func main() {
	home, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
	}
	dir := filepath.Join(home, ".local", "share", "apod")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Fatal(err)
	}
	if err := installPlugin(home); err != nil {
		log.Fatal(err)
	}
	if len(os.Args) > 1 {
		var done string
		switch os.Args[1] {
		case "save":
			err = saveCurrent(filepath.Join(home, "Pictures", "saved-apod-lockscreens"))
			done = "saved in ~/Pictures/saved-apod-lockscreens"
		case "install":
			err = install(home)
			done = "installed: lock screen set now. for daily updates run: apod auto on"
		case "uninstall":
			err = uninstall(home)
			done = "uninstalled. but the last one will stay as your lock screen until changed"
		case "auto":
			if len(os.Args) < 3 || (os.Args[2] != "on" && os.Args[2] != "off") {
				log.Fatal("use: apod auto on, or apod auto off")
			}
			err = auto(home, os.Args[2] == "on")
			done = "auto-update " + os.Args[2]
		default:
			log.Fatalf("unknown command %q, try 'save', 'install', 'auto on', 'auto off', or 'uninstall'", os.Args[1])
		}
		if err != nil {
			log.Fatal(err)
		}
		log.Print(done)
		
		return
	}
	it, err := BestFetchFunc()
	if err != nil {
		log.Fatal(err)
	}
	if it.HDURL == "" {
		log.Printf("%s has no picture today, keeping yesterday's (or most recent):", it.Title)
		return
	}
	name, err := fileName(it)
	if err != nil {
		log.Fatal(err)
	}
	file := filepath.Join(dir, name)

	if err := download(it.HDURL, file); err !=nil {
		log.Fatal(err)
	}
	if err := setLockScreen(file); err != nil {
		log.Fatal(err)
	}
	if err := cleanup(dir, file); err != nil {
		log.Fatal(err)
	}
	log.Printf("lock screen set to: %s", it.Title)
	
}